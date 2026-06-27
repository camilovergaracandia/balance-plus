-- ============================================================================
-- Balance+ — Parche 02: corrige la tabla patients tras leer intake.html/portal.html
--
-- Aplica esto SOLO si ya ejecutaste BalancePlus_01_schema.sql (versión inicial)
-- en Supabase. Ajusta tipos y agrega columnas que faltaban. Es seguro sobre
-- una base vacía. Pegar en SQL Editor y ejecutar.
--
-- Si AÚN NO has ejecutado el schema 01, ignora este parche: el archivo
-- BalancePlus_01_schema.sql ya quedó corregido y basta con correr ese.
-- ============================================================================

-- 1. Agregar columnas faltantes (idempotente)
alter table public.patients add column if not exists rut text;
alter table public.patients add column if not exists condiciones_ninguna boolean default false;
alter table public.patients add column if not exists exclusiones_ninguna boolean default false;
alter table public.patients add column if not exists exclusion_marcada   boolean default false;

-- 2. rut: identificador único principal del paciente
do $$ begin
  alter table public.patients add constraint patients_rut_unique unique (rut);
exception when duplicate_object then null; end $$;

-- 3. Corregir tipos: fc y glp1 son TEXTO (etiquetas), no int/boolean
alter table public.patients
  alter column fc type text using fc::text;

alter table public.patients
  alter column glp1 type text using
    case when glp1 is null then null
         when glp1 = true then 'si'
         when glp1 = false then 'none'
         else glp1::text end;

-- 4. programas y otros_meds son BOOLEAN (intake los escribe como false), no array/texto
alter table public.patients
  alter column programas drop default;
alter table public.patients
  alter column programas type boolean using
    case when programas is null then false
         when programas::text in ('{}','') then false
         else true end;
alter table public.patients
  alter column programas set default false;

alter table public.patients
  alter column otros_meds drop default;
alter table public.patients
  alter column otros_meds type boolean using
    case when otros_meds is null then false
         when otros_meds::text in ('false','') then false
         else true end;
alter table public.patients
  alter column otros_meds set default false;

-- Nota: en una base vacía estos USING no tocan datos; quedan por consistencia
-- si llegaras a re-ejecutar con datos de prueba dentro.
