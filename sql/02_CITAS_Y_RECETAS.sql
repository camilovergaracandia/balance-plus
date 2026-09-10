-- ============================================================================
-- Balance Plus — Paso 2: Agenda, videoconsulta y recetas
-- Pegar TODO en el SQL Editor de Supabase y ejecutar UNA vez.
--
-- Modelo:
--   El paciente completa su evaluación y reserva una hora en Balance Plus.
--   El médico toma la hora desde su agenda, revisa la ficha en los minutos
--   previos, atiende por videollamada DENTRO de Balance Plus, deja su nota
--   clínica y sube el PDF de la receta que emitió en su propio sistema.
--
--   No se graba el video. Queda registro clínico: hora de inicio y término,
--   duración real, quién atendió y la nota del médico.
-- ============================================================================


-- ----------------------------------------------------------------------------
-- 1. Tipos
-- ----------------------------------------------------------------------------
do $$ begin
  create type appointment_status as enum
    ('reservada', 'confirmada', 'en_curso', 'atendida', 'cancelada', 'no_asistio');
exception when duplicate_object then null; end $$;


-- ----------------------------------------------------------------------------
-- 2. Configuración de la agenda
--    Una sola fila. Cámbiala cuando cierres el acuerdo con el proveedor:
--    no hay que tocar código, solo estos valores.
-- ----------------------------------------------------------------------------
create table if not exists public.consult_settings (
  id                 int primary key default 1 check (id = 1),
  duracion_min       int  not null default 20,   -- bloque total de la cita
  prep_min           int  not null default 5,    -- minutos de revisión previa
  hora_inicio        time not null default '09:00',
  hora_fin           time not null default '20:00',
  dias               int[] not null default '{1,2,3,4,5}',  -- 1=lunes … 7=domingo
  cupos_por_bloque   int  not null default 2,    -- médicos disponibles en paralelo
  anticipacion_horas int  not null default 2,    -- mínimo para reservar
  dias_max_futuro    int  not null default 30,   -- hasta cuándo se puede reservar
  precio_consulta    int  not null default 25000,
  moneda             text not null default 'CLP',
  updated_at         timestamptz not null default now()
);

insert into public.consult_settings (id) values (1) on conflict (id) do nothing;

alter table public.consult_settings enable row level security;

drop policy if exists cfg_select on public.consult_settings;
create policy cfg_select on public.consult_settings
  for select to authenticated using (true);

drop policy if exists cfg_update on public.consult_settings;
create policy cfg_update on public.consult_settings
  for update to authenticated using ( public.is_staff() );


-- ----------------------------------------------------------------------------
-- 3. Tabla de citas
-- ----------------------------------------------------------------------------
create table if not exists public.appointments (
  id            uuid primary key default gen_random_uuid(),
  patient_id    uuid not null references public.patients(id) on delete cascade,
  medico_id     uuid references public.profiles(id),   -- null hasta que un médico la toma
  inicio        timestamptz not null,
  duracion_min  int not null default 20,
  motivo        text not null default 'primera_consulta',  -- primera_consulta | control
  status        appointment_status not null default 'reservada',
  sala          text,          -- identificador de la sala de video
  -- registro clínico de la atención (no se graba video)
  inicio_real   timestamptz,
  fin_real      timestamptz,
  nota_clinica  text,
  precio        int,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

create index if not exists idx_appt_inicio  on public.appointments (inicio);
create index if not exists idx_appt_patient on public.appointments (patient_id);
create index if not exists idx_appt_medico  on public.appointments (medico_id);

alter table public.appointments enable row level security;

drop policy if exists appt_select on public.appointments;
create policy appt_select on public.appointments
  for select using (
    patient_id = public.my_patient_id()
    or medico_id = auth.uid()
    or public.is_staff()
  );

drop policy if exists appt_update on public.appointments;
create policy appt_update on public.appointments
  for update using ( medico_id = auth.uid() or public.is_staff() );


-- ----------------------------------------------------------------------------
-- 4. Recetas: archivo PDF y vínculo con la cita
-- ----------------------------------------------------------------------------
alter table public.prescriptions
  add column if not exists archivo_path    text,
  add column if not exists archivo_nombre  text,
  add column if not exists indicaciones    text,
  add column if not exists appointment_id  uuid references public.appointments(id);


-- ----------------------------------------------------------------------------
-- 5. Bucket privado para los PDF de recetas
--    Convención de ruta: {patient_id}/{archivo}.pdf
-- ----------------------------------------------------------------------------
insert into storage.buckets (id, name, public)
values ('recetas', 'recetas', false)
on conflict (id) do nothing;

drop policy if exists recetas_medico_sube on storage.objects;
create policy recetas_medico_sube on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'recetas'
    and ( public.is_assigned_medico( (storage.foldername(name))[1]::uuid )
          or public.is_staff() )
  );

drop policy if exists recetas_lectura on storage.objects;
create policy recetas_lectura on storage.objects
  for select to authenticated
  using (
    bucket_id = 'recetas'
    and ( (storage.foldername(name))[1]::uuid = public.my_patient_id()
          or public.is_assigned_medico( (storage.foldername(name))[1]::uuid )
          or public.is_staff() )
  );

drop policy if exists recetas_medico_borra on storage.objects;
create policy recetas_medico_borra on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'recetas'
    and ( public.is_assigned_medico( (storage.foldername(name))[1]::uuid )
          or public.is_staff() )
  );


-- ----------------------------------------------------------------------------
-- 6. Horas disponibles
--    Se arma desde consult_settings. Al cambiar la configuración, cambian
--    las horas ofrecidas sin tocar nada más.
-- ----------------------------------------------------------------------------
create or replace function public.horarios_disponibles(p_desde date, p_hasta date)
returns table (inicio timestamptz, cupos int)
language plpgsql
stable
security definer set search_path = public
as $$
declare c public.consult_settings;
begin
  select * into c from public.consult_settings where id = 1;

  return query
  with grilla as (
    select generate_series(
             (p_desde::timestamp at time zone 'America/Santiago'),
             ((least(p_hasta, current_date + c.dias_max_futuro) + 1)::timestamp
                at time zone 'America/Santiago'),
             make_interval(mins => c.duracion_min)
           ) as t
  ),
  habiles as (
    select t from grilla
     where extract(isodow from (t at time zone 'America/Santiago'))::int = any(c.dias)
       and (t at time zone 'America/Santiago')::time >= c.hora_inicio
       and (t at time zone 'America/Santiago')::time <  c.hora_fin
       and t > now() + make_interval(hours => c.anticipacion_horas)
  ),
  conteo as (
    select h.t as bloque,
           c.cupos_por_bloque - coalesce((
             select count(*)::int from public.appointments a
              where a.inicio = h.t
                and a.status in ('reservada','confirmada','en_curso')), 0) as libres
      from habiles h
  )
  select conteo.bloque, conteo.libres
    from conteo
   where conteo.libres > 0
   order by conteo.bloque;
end;
$$;

revoke all on function public.horarios_disponibles(date, date) from public, anon;
grant execute on function public.horarios_disponibles(date, date) to authenticated;


-- ----------------------------------------------------------------------------
-- 7. El paciente reserva una hora
-- ----------------------------------------------------------------------------
create or replace function public.reservar_cita(
  p_inicio timestamptz, p_motivo text default 'primera_consulta')
returns uuid
language plpgsql
security definer set search_path = public
as $$
declare
  c         public.consult_settings;
  v_patient uuid;
  v_id      uuid;
  v_usados  int;
begin
  select * into c from public.consult_settings where id = 1;

  v_patient := public.my_patient_id();
  if v_patient is null then
    raise exception 'Solo un paciente registrado puede reservar horas';
  end if;

  if p_inicio <= now() + make_interval(hours => c.anticipacion_horas) then
    raise exception 'Debes reservar con al menos % horas de anticipacion', c.anticipacion_horas;
  end if;

  if exists (select 1 from public.appointments
              where patient_id = v_patient
                and status in ('reservada','confirmada','en_curso')
                and inicio > now()) then
    raise exception 'Ya tienes una hora agendada. Cancelala antes de reservar otra.';
  end if;

  select count(*) into v_usados
    from public.appointments
   where inicio = p_inicio and status in ('reservada','confirmada','en_curso');

  if v_usados >= c.cupos_por_bloque then
    raise exception 'Ese horario ya no esta disponible';
  end if;

  insert into public.appointments (patient_id, inicio, duracion_min, motivo, precio, sala)
  values (v_patient, p_inicio, c.duracion_min,
          coalesce(p_motivo,'primera_consulta'), c.precio_consulta,
          'bp-' || replace(gen_random_uuid()::text, '-', ''))
  returning id into v_id;

  return v_id;
end;
$$;

revoke all on function public.reservar_cita(timestamptz, text) from public, anon;
grant execute on function public.reservar_cita(timestamptz, text) to authenticated;


-- ----------------------------------------------------------------------------
-- 8. Cancelar una hora
-- ----------------------------------------------------------------------------
create or replace function public.cancelar_cita(p_cita uuid)
returns boolean
language plpgsql
security definer set search_path = public
as $$
begin
  update public.appointments
     set status = 'cancelada', updated_at = now()
   where id = p_cita
     and status in ('reservada','confirmada')
     and ( patient_id = public.my_patient_id()
           or medico_id = auth.uid()
           or public.is_staff() );

  if not found then raise exception 'No puedes cancelar esta hora'; end if;
  return true;
end;
$$;

revoke all on function public.cancelar_cita(uuid) from public, anon;
grant execute on function public.cancelar_cita(uuid) to authenticated;


-- ----------------------------------------------------------------------------
-- 9. Agenda del médico
--    Las citas del día: las suyas y las que aún no tienen médico.
-- ----------------------------------------------------------------------------
create or replace function public.agenda_medico(p_fecha date)
returns table (
  cita_id       uuid,
  inicio        timestamptz,
  duracion_min  int,
  status        text,
  motivo        text,
  sala          text,
  nota_clinica  text,
  inicio_real   timestamptz,
  fin_real      timestamptz,
  mia           boolean,
  patient_id    uuid,
  nombre        text,
  email         text,
  edad          int,
  sexo          text,
  peso_actual   numeric,
  peso_objetivo numeric,
  imc           numeric,
  elegibilidad  text,
  recetas       bigint
)
language sql
stable
security definer set search_path = public
as $$
  select
    a.id, a.inicio, a.duracion_min, a.status::text, a.motivo, a.sala,
    a.nota_clinica, a.inicio_real, a.fin_real,
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


-- ----------------------------------------------------------------------------
-- 10. El médico toma una hora
--     Queda como médico tratante: recién ahí puede ver la ficha clínica.
-- ----------------------------------------------------------------------------
create or replace function public.tomar_cita(p_cita uuid)
returns boolean
language plpgsql
security definer set search_path = public
as $$
declare v_patient uuid;
begin
  if public.app_role() not in ('medico','staff') then
    raise exception 'Solo un medico puede tomar citas';
  end if;

  select patient_id into v_patient
    from public.appointments
   where id = p_cita and (medico_id is null or medico_id = auth.uid());

  if v_patient is null then
    raise exception 'Esa hora ya fue tomada por otro medico';
  end if;

  update public.appointments
     set medico_id = auth.uid(), status = 'confirmada', updated_at = now()
   where id = p_cita;

  insert into public.provider_assignments (patient_id, medico_id)
  values (v_patient, auth.uid())
  on conflict do nothing;

  return true;
end;
$$;

revoke all on function public.tomar_cita(uuid) from public, anon;
grant execute on function public.tomar_cita(uuid) to authenticated;


-- ----------------------------------------------------------------------------
-- 11. Registro de la atención
--     Marca inicio y término reales de la videollamada y guarda la nota.
-- ----------------------------------------------------------------------------
create or replace function public.iniciar_atencion(p_cita uuid)
returns boolean
language plpgsql
security definer set search_path = public
as $$
begin
  update public.appointments
     set status      = 'en_curso',
         inicio_real = coalesce(inicio_real, now()),
         updated_at  = now()
   where id = p_cita and medico_id = auth.uid();
  if not found then raise exception 'No eres el medico de esta hora'; end if;
  return true;
end;
$$;

create or replace function public.cerrar_atencion(
  p_cita uuid, p_nota text default null, p_asistio boolean default true)
returns boolean
language plpgsql
security definer set search_path = public
as $$
begin
  update public.appointments
     set status       = case when p_asistio then 'atendida'::appointment_status
                             else 'no_asistio'::appointment_status end,
         fin_real     = case when p_asistio then now() else fin_real end,
         nota_clinica = coalesce(p_nota, nota_clinica),
         updated_at   = now()
   where id = p_cita and (medico_id = auth.uid() or public.is_staff());
  if not found then raise exception 'No puedes cerrar esta atencion'; end if;
  return true;
end;
$$;

create or replace function public.guardar_nota(p_cita uuid, p_nota text)
returns boolean
language plpgsql
security definer set search_path = public
as $$
begin
  update public.appointments
     set nota_clinica = p_nota, updated_at = now()
   where id = p_cita and (medico_id = auth.uid() or public.is_staff());
  if not found then raise exception 'No puedes editar esta ficha'; end if;
  return true;
end;
$$;

revoke all on function public.iniciar_atencion(uuid) from public, anon;
revoke all on function public.cerrar_atencion(uuid, text, boolean) from public, anon;
revoke all on function public.guardar_nota(uuid, text) from public, anon;
grant execute on function public.iniciar_atencion(uuid) to authenticated;
grant execute on function public.cerrar_atencion(uuid, text, boolean) to authenticated;
grant execute on function public.guardar_nota(uuid, text) to authenticated;


-- ----------------------------------------------------------------------------
-- 12. Ficha de intake del paciente (solo su médico tratante o staff)
-- ----------------------------------------------------------------------------
create or replace function public.intake_de_paciente(p_patient uuid)
returns jsonb
language sql
stable
security definer set search_path = public
as $$
  select to_jsonb(s)
    from public.intake_submissions s
   where s.patient_id = p_patient
     and ( public.is_assigned_medico(p_patient) or public.is_staff() )
   order by s.submitted_at desc
   limit 1;
$$;

revoke all on function public.intake_de_paciente(uuid) from public, anon;
grant execute on function public.intake_de_paciente(uuid) to authenticated;


-- ----------------------------------------------------------------------------
-- 13. Citas del paciente (para su portal)
--     La sala solo se entrega cuando la hora ya tiene médico asignado.
-- ----------------------------------------------------------------------------
create or replace function public.mis_citas()
returns table (
  cita_id      uuid,
  inicio       timestamptz,
  duracion_min int,
  status       text,
  motivo       text,
  sala         text,
  precio       int,
  medico       text
)
language sql
stable
security definer set search_path = public
as $$
  select a.id, a.inicio, a.duracion_min, a.status::text, a.motivo,
         case when a.status in ('confirmada','en_curso') then a.sala else null end,
         a.precio,
         nullif(trim(coalesce(m.nombre,'') || ' ' || coalesce(m.apellido,'')), '')
    from public.appointments a
    left join public.profiles m on m.id = a.medico_id
   where a.patient_id = public.my_patient_id()
   order by a.inicio desc;
$$;

revoke all on function public.mis_citas() from public, anon;
grant execute on function public.mis_citas() to authenticated;
