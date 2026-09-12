-- ============================================================================
-- Balance Plus — Paso 10: Registro de síntomas e historial clínico
-- Pegar TODO en el SQL Editor y ejecutar UNA vez.
--
-- Dos cosas que se complementan:
--
--   1. El paciente registra cómo se ha sentido, con fechas y duración. Cada
--      síntoma tiene un nivel: leve se registra sin más, moderado sugiere
--      consultar, y de alarma indica suspender y acudir a urgencias.
--
--   2. El médico ve, al abrir la ficha, las consultas anteriores con sus
--      notas y lo que el paciente registró desde entonces. Como puede atender
--      un médico distinto cada vez, la continuidad depende de eso.
--
-- BORRADOR CLÍNICO: la lista de síntomas y su clasificación son una propuesta.
-- Revísala antes de usarla con pacientes reales.
-- ============================================================================


-- ----------------------------------------------------------------------------
-- 1. Catálogo de síntomas
-- ----------------------------------------------------------------------------
do $$ begin
  create type symptom_level as enum ('leve', 'moderado', 'alarma');
exception when duplicate_object then null; end $$;

create table if not exists public.symptoms (
  id          uuid primary key default gen_random_uuid(),
  nombre      text not null unique,
  descripcion text,                       -- cómo se le explica al paciente
  nivel       symptom_level not null,
  consejo     text,                       -- qué se le dice al registrarlo
  orden       int not null default 100,
  activo      boolean not null default true
);

alter table public.symptoms enable row level security;

drop policy if exists sym_select on public.symptoms;
create policy sym_select on public.symptoms
  for select to authenticated using ( activo or public.is_staff() );

drop policy if exists sym_admin on public.symptoms;
create policy sym_admin on public.symptoms
  for all to authenticated using ( public.is_staff() ) with check ( public.is_staff() );


-- ----------------------------------------------------------------------------
-- 2. Lo que registra el paciente
-- ----------------------------------------------------------------------------
create table if not exists public.symptom_logs (
  id           uuid primary key default gen_random_uuid(),
  patient_id   uuid not null references public.patients(id) on delete cascade,
  symptom_id   uuid not null references public.symptoms(id),
  desde        date not null,
  hasta        date,                      -- null = sigue presente
  intensidad   int check (intensidad between 1 and 3),  -- 1 leve, 2 media, 3 fuerte
  comentario   text,
  -- Se congela el nivel del momento, por si el catálogo cambia después
  nivel        symptom_level not null,
  revisado_por uuid references public.profiles(id),
  revisado_at  timestamptz,
  created_at   timestamptz not null default now()
);

create index if not exists idx_sym_patient on public.symptom_logs (patient_id, desde desc);
create index if not exists idx_sym_nivel   on public.symptom_logs (nivel, created_at desc);

alter table public.symptom_logs enable row level security;

-- El paciente ve y registra los suyos. Su médico tratante los ve. Staff todo.
drop policy if exists slog_select on public.symptom_logs;
create policy slog_select on public.symptom_logs
  for select to authenticated
  using (
    patient_id = public.my_patient_id()
    or public.is_assigned_medico(patient_id)
    or public.is_staff()
  );

drop policy if exists slog_insert on public.symptom_logs;
create policy slog_insert on public.symptom_logs
  for insert to authenticated
  with check ( patient_id = public.my_patient_id() );

drop policy if exists slog_update on public.symptom_logs;
create policy slog_update on public.symptom_logs
  for update to authenticated
  using (
    patient_id = public.my_patient_id()
    or public.is_assigned_medico(patient_id)
    or public.is_staff()
  );


-- ----------------------------------------------------------------------------
-- 3. Síntomas frecuentes con agonistas GLP-1
--    BORRADOR: revisar con criterio médico antes de usar con pacientes.
-- ----------------------------------------------------------------------------
insert into public.symptoms (nombre, descripcion, nivel, consejo, orden) values
  ('Náuseas',
   'Sensación de malestar estomacal o ganas de vomitar',
   'leve',
   'Son frecuentes al comenzar y al subir la dosis, y suelen ceder en unas semanas. Ayuda comer porciones pequeñas, evitar frituras y no acostarse justo después de comer.', 10),

  ('Vómitos ocasionales',
   'Vomitaste alguna vez, pero puedes seguir comiendo y tomando líquido',
   'leve',
   'Mantén la hidratación con sorbos frecuentes. Si aumentan o no logras retener líquidos, vuelve a registrarlo.', 20),

  ('Saciedad temprana',
   'Te llenas con muy poca comida',
   'leve',
   'Es el efecto esperado del medicamento. Cuida que igual alcances tu aporte de proteínas en el día.', 30),

  ('Constipación',
   'Menos deposiciones de lo habitual, sin dolor importante',
   'leve',
   'Aumenta el agua y la fibra, y mantén actividad física. Si pasan más de tres días sin deposiciones, vuelve a registrarlo.', 40),

  ('Diarrea',
   'Deposiciones líquidas más frecuentes de lo normal',
   'leve',
   'Hidrátate bien. Si es intensa o dura más de dos días, conviene que te evalúen.', 50),

  ('Reflujo o acidez',
   'Ardor en el pecho o sensación de que la comida vuelve',
   'leve',
   'Evita comidas abundantes y acostarte dentro de las dos horas siguientes a comer.', 60),

  ('Dolor de cabeza',
   'Cefalea sin otros síntomas',
   'leve',
   'Suele relacionarse con comer o beber menos. Cuida la hidratación y no te saltes comidas.', 70),

  ('Cansancio',
   'Fatiga o falta de energía',
   'leve',
   'Es frecuente al bajar la ingesta. Revisa que estés comiendo suficiente proteína y durmiendo bien.', 80),

  ('Vómitos que no ceden',
   'Llevas más de un día vomitando y te cuesta retener líquidos',
   'moderado',
   'Necesitas evaluación médica. Agenda una consulta y, mientras tanto, intenta hidratarte con sorbos pequeños y frecuentes.', 110),

  ('Náuseas que no mejoran',
   'Llevas más de una semana con náuseas que no ceden',
   'moderado',
   'Conviene que un médico evalúe si corresponde ajustar la dosis. Agenda una consulta.', 120),

  ('Constipación de varios días',
   'Más de tres días sin deposiciones, con molestia abdominal',
   'moderado',
   'Agenda una consulta para evaluarlo. No uses laxantes por tu cuenta sin indicación.', 130),

  ('Mareo al ponerte de pie',
   'Sensación de desmayo al levantarte',
   'moderado',
   'Puede indicar deshidratación o presión baja. Agenda una consulta e hidrátate bien mientras tanto.', 140),

  ('Palpitaciones',
   'Sensación de que el corazón late rápido o irregular',
   'moderado',
   'Conviene evaluarlo. Agenda una consulta.', 150),

  ('Dolor abdominal intenso',
   'Dolor fuerte en la boca del estómago, que puede irradiarse a la espalda',
   'alarma',
   'Suspende el medicamento y acude hoy a un servicio de urgencia. Este síntoma requiere descartar una inflamación del páncreas.', 200),

  ('Vómitos incoercibles',
   'No logras retener ningún líquido',
   'alarma',
   'Suspende el medicamento y acude hoy a un servicio de urgencia. Hay riesgo de deshidratación.', 210),

  ('Signos de deshidratación',
   'Boca muy seca, orinas muy poco u oscuro, mucha debilidad',
   'alarma',
   'Acude hoy a un servicio de urgencia.', 220),

  ('Coloración amarilla de piel u ojos',
   'Ictericia',
   'alarma',
   'Suspende el medicamento y acude hoy a un servicio de urgencia.', 230),

  ('Reacción alérgica',
   'Hinchazón de cara, labios o lengua, o dificultad para respirar',
   'alarma',
   'Suspende el medicamento y acude de inmediato a un servicio de urgencia o llama al 131.', 240)
on conflict (nombre) do nothing;


-- ----------------------------------------------------------------------------
-- 4. El paciente registra un síntoma
--    Devuelve el nivel y el consejo, para mostrárselo de inmediato.
-- ----------------------------------------------------------------------------
create or replace function public.registrar_sintoma(
  p_symptom    uuid,
  p_desde      date,
  p_hasta      date default null,
  p_intensidad int default null,
  p_comentario text default null)
returns table (nivel text, consejo text, nombre text)
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

  return query select v_sym.nivel::text, v_sym.consejo, v_sym.nombre;
end;
$$;

grant execute on function public.registrar_sintoma(uuid, date, date, int, text) to authenticated;


-- ----------------------------------------------------------------------------
-- 5. Lo que el paciente ha registrado
-- ----------------------------------------------------------------------------
create or replace function public.mis_sintomas()
returns table (
  log_id     uuid,
  nombre     text,
  nivel      text,
  desde      date,
  hasta      date,
  dias       int,
  intensidad int,
  comentario text,
  registrado timestamptz
)
language sql
stable
security definer set search_path = public
as $$
  select l.id, s.nombre, l.nivel::text, l.desde, l.hasta,
         (coalesce(l.hasta, current_date) - l.desde + 1)::int,
         l.intensidad, l.comentario, l.created_at
    from public.symptom_logs l
    join public.symptoms s on s.id = l.symptom_id
   where l.patient_id = public.my_patient_id()
   order by l.desde desc, l.created_at desc;
$$;

grant execute on function public.mis_sintomas() to authenticated;


-- ----------------------------------------------------------------------------
-- 6. El paciente marca que un síntoma ya cedió
-- ----------------------------------------------------------------------------
create or replace function public.cerrar_sintoma(p_log uuid, p_hasta date default null)
returns boolean
language plpgsql
security definer set search_path = public
as $$
begin
  update public.symptom_logs
     set hasta = coalesce(p_hasta, current_date)
   where id = p_log and patient_id = public.my_patient_id() and hasta is null;
  if not found then raise exception 'No se pudo actualizar ese registro'; end if;
  return true;
end;
$$;

grant execute on function public.cerrar_sintoma(uuid, date) to authenticated;


-- ----------------------------------------------------------------------------
-- 7. Historial clínico del paciente, para el médico
--    Las consultas anteriores con su nota y lo que se indicó en cada una.
-- ----------------------------------------------------------------------------
create or replace function public.historial_paciente(p_patient uuid)
returns table (
  cita_id      uuid,
  fecha        timestamptz,
  motivo       text,
  status       text,
  medico       text,
  nota_clinica text,
  control_semanas int,
  recetas      jsonb
)
language sql
stable
security definer set search_path = public
as $$
  select a.id, coalesce(a.fin_real, a.inicio), a.motivo, a.status::text,
         nullif(trim(coalesce(m.nombre,'') || ' ' || coalesce(m.apellido,'')), ''),
         a.nota_clinica, a.control_semanas,
         (select jsonb_agg(jsonb_build_object(
                   'medicamento', r.medicamento, 'dosis', r.dosis,
                   'sin_sustitucion', r.sin_sustitucion,
                   'es_texto_libre', r.es_texto_libre)
                 order by r.created_at)
            from public.prescriptions r where r.appointment_id = a.id)
    from public.appointments a
    left join public.profiles m on m.id = a.medico_id
   where a.patient_id = p_patient
     and a.status in ('atendida','no_asistio')
     and ( public.is_assigned_medico(p_patient) or public.is_staff() )
   order by coalesce(a.fin_real, a.inicio) desc;
$$;

grant execute on function public.historial_paciente(uuid) to authenticated;


-- ----------------------------------------------------------------------------
-- 8. Síntomas del paciente, para el médico
-- ----------------------------------------------------------------------------
create or replace function public.sintomas_de_paciente(p_patient uuid, p_dias int default 90)
returns table (
  log_id     uuid,
  nombre     text,
  nivel      text,
  desde      date,
  hasta      date,
  dias       int,
  intensidad int,
  comentario text,
  activo     boolean
)
language sql
stable
security definer set search_path = public
as $$
  select l.id, s.nombre, l.nivel::text, l.desde, l.hasta,
         (coalesce(l.hasta, current_date) - l.desde + 1)::int,
         l.intensidad, l.comentario, (l.hasta is null)
    from public.symptom_logs l
    join public.symptoms s on s.id = l.symptom_id
   where l.patient_id = p_patient
     and l.desde >= current_date - p_dias
     and ( public.is_assigned_medico(p_patient) or public.is_staff() )
   order by (l.hasta is null) desc, l.nivel desc, l.desde desc;
$$;

grant execute on function public.sintomas_de_paciente(uuid, int) to authenticated;


-- ----------------------------------------------------------------------------
-- 9. Síntomas de alarma sin revisar, para el equipo de Balance Plus
--    Alguien tiene que mirar esto: al pedir síntomas se asume el deber de
--    responder. Mientras no haya aviso automático, revísalo a diario.
-- ----------------------------------------------------------------------------
create or replace function public.alarmas_pendientes()
returns table (
  log_id     uuid,
  paciente   text,
  email      text,
  celular    text,
  sintoma    text,
  desde      date,
  comentario text,
  registrado timestamptz
)
language sql
stable
security definer set search_path = public
as $$
  select l.id,
         nullif(trim(coalesce(pr.nombre,'') || ' ' || coalesce(pr.apellido,'')), ''),
         pr.email, pr.celular, s.nombre, l.desde, l.comentario, l.created_at
    from public.symptom_logs l
    join public.symptoms s   on s.id  = l.symptom_id
    join public.patients p   on p.id  = l.patient_id
    join public.profiles pr  on pr.id = p.profile_id
   where l.nivel = 'alarma'
     and l.revisado_at is null
     and public.is_staff()
   order by l.created_at desc;
$$;

grant execute on function public.alarmas_pendientes() to authenticated;

create or replace function public.marcar_alarma_revisada(p_log uuid)
returns boolean
language plpgsql
security definer set search_path = public
as $$
begin
  if not (public.is_staff() or public.app_role() = 'medico') then
    raise exception 'Sin permisos';
  end if;
  update public.symptom_logs
     set revisado_por = auth.uid(), revisado_at = now()
   where id = p_log;
  if not found then raise exception 'Registro no encontrado'; end if;
  return true;
end;
$$;

grant execute on function public.marcar_alarma_revisada(uuid) to authenticated;


-- ----------------------------------------------------------------------------
-- 10. Cómo quedó el catálogo
-- ----------------------------------------------------------------------------
select nivel, count(*) as sintomas,
       string_agg(nombre, ' · ' order by orden) as lista
  from public.symptoms
 group by nivel
 order by nivel;
