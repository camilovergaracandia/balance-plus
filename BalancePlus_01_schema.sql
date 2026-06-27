-- ============================================================================
-- Balance+ — Esquema de base de datos + Seguridad por fila (RLS)
-- Fase 1 de la salida a producción.
--
-- Cómo usar: pegar TODO este archivo en el SQL Editor de Supabase y ejecutar.
-- Es idempotente en lo razonable (usa IF NOT EXISTS / CREATE OR REPLACE).
--
-- ⚠️ BORRADOR DE PRIMERA VERSIÓN. Basado en los campos documentados de
--    `bp_profile` en el PROJECT_BRIEF. Revísalo antes de producción:
--    los nombres/campos clínicos exactos deben validarse contra intake.html
--    y con criterio médico/legal. No es definitivo.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 0. Extensiones y tipos
-- ----------------------------------------------------------------------------
create extension if not exists "pgcrypto";  -- para gen_random_uuid()

do $$ begin
  create type user_role as enum ('paciente', 'medico', 'farmacia', 'staff');
exception when duplicate_object then null; end $$;

do $$ begin
  create type eligibility_result as enum ('candidato', 'no_candidato', 'requiere_revision');
exception when duplicate_object then null; end $$;

do $$ begin
  create type prescription_status as enum ('borrador', 'emitida', 'despachada', 'anulada');
exception when duplicate_object then null; end $$;


-- ----------------------------------------------------------------------------
-- 1. profiles — 1:1 con auth.users. Define el ROL de cada usuario.
-- ----------------------------------------------------------------------------
create table if not exists public.profiles (
  id          uuid primary key references auth.users(id) on delete cascade,
  role        user_role not null default 'paciente',
  nombre      text,
  apellido    text,
  email       text,
  celular     text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

-- Crea automáticamente un profile cuando se registra un usuario en Auth.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, email)
  values (new.id, new.email)
  on conflict (id) do nothing;
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();


-- ----------------------------------------------------------------------------
-- 2. patients — la ficha del paciente (lo que hoy es bp_profile)
-- ----------------------------------------------------------------------------
create table if not exists public.patients (
  id              uuid primary key default gen_random_uuid(),
  profile_id      uuid not null unique references public.profiles(id) on delete cascade,
  -- identificador principal del paciente (validación módulo 11 en el servidor)
  rut             text unique,
  -- demográficos
  region          text,
  inscripcion     text,            -- fecha de inscripción dd/mm/aa
  sexo            text,            -- "Femenino" / "Masculino"
  edad            int,
  fecha_nacimiento date,
  -- antropometría / signos
  estatura        numeric,         -- cm
  peso_inicial    numeric,         -- kg
  peso_actual     numeric,         -- kg
  peso_objetivo   numeric,         -- kg
  bmi             numeric,
  pa              text,            -- etiqueta de presión arterial (ej. "130–139 mmHg — Hipertensión I")
  fc              text,            -- etiqueta de frecuencia cardíaca (ej. "60–100 lpm — Normal")
  -- banderas clínicas (de intake)
  opioides        boolean,
  opioide_tipo    text,
  cirugia         boolean,
  cirugia_tipo    text,
  rx              boolean,
  glp1            text,            -- uso previo de GLP-1: "none" u otro valor
  otros_meds      boolean default false,
  programas       boolean default false,
  -- conjuntos (respuestas múltiples del intake)
  condiciones          text[] default '{}',
  condiciones_ninguna  boolean default false,
  exclusiones          text[] default '{}',
  exclusiones_ninguna  boolean default false,
  excluyentes          boolean default false,
  exclusion_marcada    boolean default false,  -- marca interna: marcó una exclusión en algún momento
  -- overrides manuales del médico (jsonb _updates: cond/meds), prevalecen sobre lo estructurado
  medico_updates  jsonb default '{}'::jsonb,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

create index if not exists idx_patients_profile on public.patients(profile_id);


-- ----------------------------------------------------------------------------
-- 3. medications — medicamentos[] estructurados del paciente
-- ----------------------------------------------------------------------------
create table if not exists public.medications (
  id          uuid primary key default gen_random_uuid(),
  patient_id  uuid not null references public.patients(id) on delete cascade,
  nombre      text not null,
  cantidad    text,
  frecuencia  text,
  created_at  timestamptz not null default now()
);
create index if not exists idx_medications_patient on public.medications(patient_id);


-- ----------------------------------------------------------------------------
-- 4. intake_submissions — cada envío del cuestionario + resultado
--    El resultado lo escribe la Edge Function de elegibilidad (Fase 4),
--    NUNCA el cliente.
-- ----------------------------------------------------------------------------
create table if not exists public.intake_submissions (
  id            uuid primary key default gen_random_uuid(),
  patient_id    uuid not null references public.patients(id) on delete cascade,
  submitted_at  timestamptz not null default now(),
  result        eligibility_result,
  intake_data   jsonb not null default '{}'::jsonb  -- respuestas crudas de los 6 pasos
);
create index if not exists idx_intake_patient on public.intake_submissions(patient_id);


-- ----------------------------------------------------------------------------
-- 5. weight_logs — historial de peso (hoy bp_wlog)
-- ----------------------------------------------------------------------------
create table if not exists public.weight_logs (
  id          uuid primary key default gen_random_uuid(),
  patient_id  uuid not null references public.patients(id) on delete cascade,
  logged_at   timestamptz not null default now(),
  weight      numeric not null,   -- kg
  note        text
);
create index if not exists idx_weight_patient on public.weight_logs(patient_id);


-- ----------------------------------------------------------------------------
-- 6. providers + asignaciones (qué médico atiende a qué paciente)
--    Necesario para que la RLS limite al médico a SUS pacientes.
-- ----------------------------------------------------------------------------
create table if not exists public.provider_assignments (
  patient_id  uuid not null references public.patients(id) on delete cascade,
  medico_id   uuid not null references public.profiles(id) on delete cascade,
  assigned_at timestamptz not null default now(),
  primary key (patient_id, medico_id)
);
create index if not exists idx_assign_medico on public.provider_assignments(medico_id);


-- ----------------------------------------------------------------------------
-- 7. prescriptions — recetas emitidas
-- ----------------------------------------------------------------------------
create table if not exists public.prescriptions (
  id            uuid primary key default gen_random_uuid(),
  patient_id    uuid not null references public.patients(id) on delete cascade,
  medico_id     uuid references public.profiles(id),
  medicamento   text not null,
  dosis         text,
  status        prescription_status not null default 'borrador',
  issued_at     timestamptz,
  created_at    timestamptz not null default now()
);
create index if not exists idx_rx_patient on public.prescriptions(patient_id);


-- ----------------------------------------------------------------------------
-- 8. consents — consentimientos firmados (valor legal, Ley 20.584/21.719)
-- ----------------------------------------------------------------------------
create table if not exists public.consents (
  id            uuid primary key default gen_random_uuid(),
  profile_id    uuid not null references public.profiles(id) on delete cascade,
  documento     text not null,   -- ej. "06a_Telemedicina"
  version       text not null,
  doc_hash      text not null,   -- hash del texto exacto firmado
  signed_at     timestamptz not null default now(),
  ip            inet
);
create index if not exists idx_consents_profile on public.consents(profile_id);


-- ----------------------------------------------------------------------------
-- 9. audit_log — registro de accesos (obligatorio para datos de salud)
--    Se escribe desde Edge Functions / triggers con service_role.
-- ----------------------------------------------------------------------------
create table if not exists public.audit_log (
  id          bigint generated always as identity primary key,
  actor_id    uuid,
  action      text not null,        -- 'read' | 'write' | 'login' | ...
  table_name  text,
  record_id   text,
  at          timestamptz not null default now(),
  metadata    jsonb default '{}'::jsonb
);
create index if not exists idx_audit_actor on public.audit_log(actor_id);
create index if not exists idx_audit_at on public.audit_log(at);


-- ============================================================================
-- 10. FUNCIONES HELPER DE ROL (SECURITY DEFINER para evitar recursión en RLS)
-- ============================================================================

-- Devuelve el rol del usuario actual sin disparar RLS sobre profiles.
create or replace function public.app_role()
returns user_role
language sql
stable
security definer set search_path = public
as $$
  select role from public.profiles where id = auth.uid();
$$;

-- ¿El usuario actual es staff?
create or replace function public.is_staff()
returns boolean
language sql
stable
security definer set search_path = public
as $$
  select coalesce(public.app_role() = 'staff', false);
$$;

-- ¿El médico actual tiene asignado a este paciente?
create or replace function public.is_assigned_medico(p_patient uuid)
returns boolean
language sql
stable
security definer set search_path = public
as $$
  select exists (
    select 1 from public.provider_assignments
    where patient_id = p_patient and medico_id = auth.uid()
  );
$$;

-- patient_id del usuario paciente actual (o null).
create or replace function public.my_patient_id()
returns uuid
language sql
stable
security definer set search_path = public
as $$
  select id from public.patients where profile_id = auth.uid();
$$;


-- ============================================================================
-- 11. ACTIVAR RLS EN TODAS LAS TABLAS
-- ============================================================================
alter table public.profiles             enable row level security;
alter table public.patients             enable row level security;
alter table public.medications          enable row level security;
alter table public.intake_submissions   enable row level security;
alter table public.weight_logs          enable row level security;
alter table public.provider_assignments enable row level security;
alter table public.prescriptions        enable row level security;
alter table public.consents             enable row level security;
alter table public.audit_log            enable row level security;


-- ============================================================================
-- 12. POLÍTICAS RLS
--    Regla general:
--      - paciente  → solo SUS datos
--      - medico    → solo pacientes asignados
--      - staff     → todo
--    (farmacia se modela más adelante, en la fase de despacho)
-- ============================================================================

-- --- profiles -------------------------------------------------------------
drop policy if exists profiles_select_self on public.profiles;
create policy profiles_select_self on public.profiles
  for select using ( id = auth.uid() or public.is_staff() );

drop policy if exists profiles_update_self on public.profiles;
create policy profiles_update_self on public.profiles
  for update using ( id = auth.uid() )
  with check ( id = auth.uid() and role = (select role from public.profiles where id = auth.uid()) );
  -- ↑ el usuario NO puede auto-ascenderse de rol; cambiar rol queda para staff/servidor.

-- --- patients -------------------------------------------------------------
drop policy if exists patients_select on public.patients;
create policy patients_select on public.patients
  for select using (
    profile_id = auth.uid()
    or public.is_assigned_medico(id)
    or public.is_staff()
  );

drop policy if exists patients_insert_self on public.patients;
create policy patients_insert_self on public.patients
  for insert with check ( profile_id = auth.uid() );

drop policy if exists patients_update on public.patients;
create policy patients_update on public.patients
  for update using (
    profile_id = auth.uid()
    or public.is_assigned_medico(id)
    or public.is_staff()
  );

-- --- medications ----------------------------------------------------------
drop policy if exists meds_all on public.medications;
create policy meds_all on public.medications
  for all using (
    patient_id = public.my_patient_id()
    or public.is_assigned_medico(patient_id)
    or public.is_staff()
  )
  with check (
    patient_id = public.my_patient_id()
    or public.is_assigned_medico(patient_id)
    or public.is_staff()
  );

-- --- intake_submissions ---------------------------------------------------
-- El paciente puede insertar y leer; el RESULTADO de elegibilidad lo fija
-- el servidor (Edge Function con service_role, que ignora RLS).
drop policy if exists intake_select on public.intake_submissions;
create policy intake_select on public.intake_submissions
  for select using (
    patient_id = public.my_patient_id()
    or public.is_assigned_medico(patient_id)
    or public.is_staff()
  );

drop policy if exists intake_insert on public.intake_submissions;
create policy intake_insert on public.intake_submissions
  for insert with check ( patient_id = public.my_patient_id() );

-- --- weight_logs ----------------------------------------------------------
drop policy if exists wlog_all on public.weight_logs;
create policy wlog_all on public.weight_logs
  for all using (
    patient_id = public.my_patient_id()
    or public.is_assigned_medico(patient_id)
    or public.is_staff()
  )
  with check (
    patient_id = public.my_patient_id()
    or public.is_assigned_medico(patient_id)
    or public.is_staff()
  );

-- --- provider_assignments -------------------------------------------------
-- Solo staff gestiona asignaciones; el médico puede ver las suyas.
drop policy if exists assign_select on public.provider_assignments;
create policy assign_select on public.provider_assignments
  for select using ( medico_id = auth.uid() or public.is_staff() );

drop policy if exists assign_write_staff on public.provider_assignments;
create policy assign_write_staff on public.provider_assignments
  for all using ( public.is_staff() ) with check ( public.is_staff() );

-- --- prescriptions --------------------------------------------------------
drop policy if exists rx_select on public.prescriptions;
create policy rx_select on public.prescriptions
  for select using (
    patient_id = public.my_patient_id()
    or public.is_assigned_medico(patient_id)
    or public.is_staff()
  );

-- Solo el médico asignado (o staff) crea/edita recetas.
drop policy if exists rx_write on public.prescriptions;
create policy rx_write on public.prescriptions
  for all using ( public.is_assigned_medico(patient_id) or public.is_staff() )
  with check ( public.is_assigned_medico(patient_id) or public.is_staff() );

-- --- consents -------------------------------------------------------------
drop policy if exists consents_select on public.consents;
create policy consents_select on public.consents
  for select using ( profile_id = auth.uid() or public.is_staff() );

drop policy if exists consents_insert_self on public.consents;
create policy consents_insert_self on public.consents
  for insert with check ( profile_id = auth.uid() );
-- (los consentimientos no se editan ni borran: son registro inmutable)

-- --- audit_log ------------------------------------------------------------
-- Nadie escribe ni lee con clave anónima; solo staff lee. Inserción = servidor.
drop policy if exists audit_select_staff on public.audit_log;
create policy audit_select_staff on public.audit_log
  for select using ( public.is_staff() );


-- ============================================================================
-- FIN. Próximo paso (Fase 2): conectar Supabase Auth desde el frontend y
-- reescribir portal.html para leer/escribir estas tablas vía API autenticada.
-- ============================================================================
