-- ============================================================================
-- Balance Plus — Paso 11: Ajustes al registro de síntomas
-- Pegar TODO en el SQL Editor y ejecutar UNA vez.
--
-- Tres cambios, a partir de criterio clínico:
--
--   1. Se separa la reacción alérgica en dos. Una hinchazón de labios sin
--      compromiso respiratorio no es lo mismo que una vía aérea comprometida.
--   2. El 131 queda solo para el caso con riesgo de shock anafiláctico.
--      Usarlo en todo hace que el aviso pierda credibilidad.
--   3. El resto de los síntomas de alarma indica acudir hoy a urgencias,
--      sin número de emergencia.
-- ============================================================================


-- ----------------------------------------------------------------------------
-- 1. Distinguir si el síntoma requiere llamar al 131
-- ----------------------------------------------------------------------------
alter table public.symptoms
  add column if not exists emergencia boolean not null default false;

comment on column public.symptoms.emergencia is
  'Riesgo vital inmediato: se muestra el 131. Reservado para compromiso de '
  'vía aérea o respiratorio. El resto de los síntomas de alarma indica acudir '
  'hoy a urgencias, sin número de emergencia.';


-- ----------------------------------------------------------------------------
-- 2. Reacción alérgica: se separa según haya o no compromiso respiratorio
-- ----------------------------------------------------------------------------
update public.symptoms
   set nombre      = 'Reacción alérgica en la piel',
       descripcion = 'Ronchas, picazón intensa o hinchazón de labios o párpados, respirando bien',
       consejo     = 'Suspende el medicamento y acude hoy a un servicio de urgencia para que te evalúen. Si aparece dificultad para respirar o se te hincha la lengua o la garganta, llama de inmediato al 131.',
       emergencia  = false
 where nombre = 'Reacción alérgica';

insert into public.symptoms (nombre, descripcion, nivel, consejo, orden, emergencia) values
  ('Dificultad para respirar o hinchazón de lengua o garganta',
   'Te falta el aire, sientes la garganta cerrada o se te hinchó la lengua',
   'alarma',
   'Llama ahora al 131 (SAMU) o acude de inmediato al servicio de urgencia más cercano. No esperes a que mejore ni conduzcas tú mismo.',
   250, true)
on conflict (nombre) do update
   set descripcion = excluded.descripcion,
       consejo     = excluded.consejo,
       emergencia  = excluded.emergencia;


-- ----------------------------------------------------------------------------
-- 3. El resto de los síntomas de alarma: sin 131
-- ----------------------------------------------------------------------------
update public.symptoms
   set consejo = replace(consejo,
         ' Si te falta el aire o te sientes muy mal, llama al 131 (SAMU).', '')
 where nivel = 'alarma' and not emergencia;

update public.symptoms
   set consejo = 'Suspende el medicamento y acude de inmediato a un servicio de urgencia. Si te falta el aire, llama al 131.'
 where nombre = 'Reacción alérgica'
   and consejo like '%131%'
   and emergencia = false;


-- ----------------------------------------------------------------------------
-- 4. El catálogo entrega la marca de emergencia
-- ----------------------------------------------------------------------------
drop function if exists public.registrar_sintoma(uuid, date, date, int, text);
create or replace function public.registrar_sintoma(
  p_symptom    uuid,
  p_desde      date,
  p_hasta      date default null,
  p_intensidad int default null,
  p_comentario text default null)
returns table (nivel text, consejo text, nombre text, emergencia boolean)
language plpgsql
security definer set search_path = public
as $$
declare v_patient uuid; v_sym public.symptoms;
begin
  v_patient := public.my_patient_id();
  if v_patient is null then
    raise exception 'Solo un paciente registrado puede anotar sintomas';
  end if;

  select * into v_sym from public.symptoms where id = p_symptom and activo;
  if v_sym.id is null then raise exception 'Sintoma no valido'; end if;

  if p_desde > current_date then
    raise exception 'La fecha no puede ser futura';
  end if;
  if p_hasta is not null and p_hasta < p_desde then
    raise exception 'La fecha de termino no puede ser anterior al inicio';
  end if;

  insert into public.symptom_logs
    (patient_id, symptom_id, desde, hasta, intensidad, comentario, nivel)
  values
    (v_patient, p_symptom, p_desde, p_hasta, p_intensidad, nullif(trim(p_comentario),''), v_sym.nivel);

  return query select v_sym.nivel::text, v_sym.consejo, v_sym.nombre, v_sym.emergencia;
end;
$$;

grant execute on function public.registrar_sintoma(uuid, date, date, int, text) to authenticated;


-- ----------------------------------------------------------------------------
-- 5. Cómo quedaron los de alarma
-- ----------------------------------------------------------------------------
select nombre,
       case when emergencia then 'Llamar al 131' else 'Urgencia hoy' end as indicacion,
       consejo
  from public.symptoms
 where nivel = 'alarma'
 order by orden;
