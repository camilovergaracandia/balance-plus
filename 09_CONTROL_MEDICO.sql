-- ============================================================================
-- Balance Plus — Paso 9: Recordatorio de control médico
-- Pegar TODO en el SQL Editor y ejecutar UNA vez.
--
-- Cómo funciona:
--   Al cerrar la atención, el médico indica en cuántas semanas quiere volver
--   a ver al paciente. Es una decisión clínica suya, no una regla del sistema.
--   El portal del paciente le avisa cuando se acerca esa fecha y le ofrece
--   agendar su control.
--
--   El aviso habla de control médico, nunca de comprar medicamentos: es
--   seguimiento clínico, no publicidad de fármacos de venta bajo receta.
-- ============================================================================


-- ----------------------------------------------------------------------------
-- 1. El médico define cuándo quiere el próximo control
-- ----------------------------------------------------------------------------
alter table public.appointments
  add column if not exists control_semanas int;

comment on column public.appointments.control_semanas is
  'Semanas hasta el próximo control, indicadas por el médico al cerrar la atención.';


-- ----------------------------------------------------------------------------
-- 2. Cerrar la atención, ahora con el intervalo de control
-- ----------------------------------------------------------------------------
create or replace function public.cerrar_atencion(
  p_cita     uuid,
  p_nota     text default null,
  p_asistio  boolean default true,
  p_control  int default null)
returns boolean
language plpgsql
security definer set search_path = public
as $$
begin
  if p_control is not null and (p_control < 1 or p_control > 52) then
    raise exception 'El control debe estar entre 1 y 52 semanas';
  end if;

  update public.appointments
     set status          = case when p_asistio then 'atendida'::appointment_status
                                else 'no_asistio'::appointment_status end,
         fin_real        = case when p_asistio then now() else fin_real end,
         nota_clinica    = coalesce(p_nota, nota_clinica),
         control_semanas = case when p_asistio then p_control else control_semanas end,
         updated_at      = now()
   where id = p_cita
     and (medico_id = auth.uid() or public.is_staff());

  if not found then raise exception 'No puedes cerrar esta atencion'; end if;
  return true;
end;
$$;

grant execute on function public.cerrar_atencion(uuid, text, boolean, int) to authenticated;


-- ----------------------------------------------------------------------------
-- 3. ¿Le toca control al paciente?
--    Devuelve una fila solo si su médico indicó un control y todavía no hay
--    una hora futura agendada. Si ya agendó, no hay nada que recordarle.
-- ----------------------------------------------------------------------------
create or replace function public.mi_proximo_control()
returns table (
  fecha_control date,
  dias_restantes int,
  semanas        int,
  medico         text,
  ultima_consulta timestamptz
)
language sql
stable
security definer set search_path = public
as $$
  with ultima as (
    select a.*
      from public.appointments a
     where a.patient_id = public.my_patient_id()
       and a.status = 'atendida'
       and a.control_semanas is not null
     order by coalesce(a.fin_real, a.inicio) desc
     limit 1
  )
  select (coalesce(u.fin_real, u.inicio) + make_interval(weeks => u.control_semanas))::date,
         ((coalesce(u.fin_real, u.inicio) + make_interval(weeks => u.control_semanas))::date
            - current_date)::int,
         u.control_semanas,
         nullif(trim(coalesce(m.nombre,'') || ' ' || coalesce(m.apellido,'')), ''),
         coalesce(u.fin_real, u.inicio)
    from ultima u
    left join public.profiles m on m.id = u.medico_id
   where not exists (
     select 1 from public.appointments f
      where f.patient_id = public.my_patient_id()
        and f.status in ('reservada','confirmada','en_curso')
        and f.inicio > now()
   );
$$;

grant execute on function public.mi_proximo_control() to authenticated;


-- ----------------------------------------------------------------------------
-- 4. Controles próximos, para el equipo de Balance Plus
--    Sirve para saber a quién le toca control y hacer seguimiento.
-- ----------------------------------------------------------------------------
create or replace function public.controles_pendientes(p_dias int default 14)
returns table (
  patient_id     uuid,
  paciente       text,
  email          text,
  fecha_control  date,
  dias_restantes int,
  medico         text
)
language sql
stable
security definer set search_path = public
as $$
  with ultima as (
    select distinct on (a.patient_id) a.*
      from public.appointments a
     where a.status = 'atendida' and a.control_semanas is not null
     order by a.patient_id, coalesce(a.fin_real, a.inicio) desc
  )
  select u.patient_id,
         nullif(trim(coalesce(pr.nombre,'') || ' ' || coalesce(pr.apellido,'')), ''),
         pr.email,
         (coalesce(u.fin_real, u.inicio) + make_interval(weeks => u.control_semanas))::date,
         ((coalesce(u.fin_real, u.inicio) + make_interval(weeks => u.control_semanas))::date
            - current_date)::int,
         nullif(trim(coalesce(m.nombre,'') || ' ' || coalesce(m.apellido,'')), '')
    from ultima u
    join public.patients p   on p.id  = u.patient_id
    join public.profiles pr  on pr.id = p.profile_id
    left join public.profiles m on m.id = u.medico_id
   where public.is_staff()
     and not exists (
       select 1 from public.appointments f
        where f.patient_id = u.patient_id
          and f.status in ('reservada','confirmada','en_curso')
          and f.inicio > now())
     and (coalesce(u.fin_real, u.inicio) + make_interval(weeks => u.control_semanas))::date
           <= current_date + p_dias
   order by 4;
$$;

grant execute on function public.controles_pendientes(int) to authenticated;


-- ----------------------------------------------------------------------------
-- 5. La agenda del médico devuelve el control indicado
--    Así, al reabrir una ficha ya cerrada, el médico ve lo que definió.
-- ----------------------------------------------------------------------------
drop function if exists public.agenda_medico(date);
create or replace function public.agenda_medico(p_fecha date)
returns table (
  cita_id         uuid,
  inicio          timestamptz,
  duracion_min    int,
  status          text,
  motivo          text,
  sala            text,
  nota_clinica    text,
  inicio_real     timestamptz,
  fin_real        timestamptz,
  control_semanas int,
  mia             boolean,
  patient_id      uuid,
  nombre          text,
  email           text,
  edad            int,
  sexo            text,
  peso_actual     numeric,
  peso_objetivo   numeric,
  imc             numeric,
  elegibilidad    text,
  recetas         bigint
)
language sql
stable
security definer set search_path = public
as $$
  select
    a.id, a.inicio, a.duracion_min, a.status::text, a.motivo, a.sala,
    a.nota_clinica, a.inicio_real, a.fin_real, a.control_semanas,
    (a.medico_id = auth.uid()),
    p.id,
    nullif(trim(coalesce(pr.nombre,'') || ' ' || coalesce(pr.apellido,'')), ''),
    pr.email,
    coalesce(p.edad, case when p.fecha_nacimiento is not null
                          then date_part('year', age(p.fecha_nacimiento))::int end),
    p.sexo, p.peso_actual, p.peso_objetivo,
    coalesce(p.bmi,
      case when p.estatura is not null and p.estatura > 0 and p.peso_actual is not null
           then round((p.peso_actual / power(p.estatura / 100.0, 2))::numeric, 1) end),
    coalesce((select s.result::text from public.intake_submissions s
               where s.patient_id = p.id order by s.submitted_at desc limit 1), 'sin evaluar'),
    (select count(*) from public.prescriptions rx where rx.patient_id = p.id)
  from public.appointments a
  join public.patients p  on p.id  = a.patient_id
  join public.profiles pr on pr.id = p.profile_id
  where public.app_role() in ('medico','staff')
    and a.status <> 'cancelada'
    and (a.inicio at time zone 'America/Santiago')::date = p_fecha
    and (a.medico_id = auth.uid() or a.medico_id is null)
  order by a.inicio;
$$;

revoke all on function public.agenda_medico(date) from public, anon;
grant execute on function public.agenda_medico(date) to authenticated;
