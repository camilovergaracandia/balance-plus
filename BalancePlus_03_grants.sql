-- ============================================================================
-- Balance+ — Parche 03: exponer SOLO las tablas necesarias a la Data API
--
-- Necesario porque desactivaste "Automatically expose new tables".
-- Da privilegios al rol `authenticated` (usuarios logueados). La RLS sigue
-- filtrando QUÉ filas ve/edita cada quien; esto solo habilita el intento.
--
-- `anon` (sin login) NO recibe nada: todo requiere sesión iniciada.
-- `audit_log` queda fuera a propósito: solo el servidor escribe en él.
--
-- Pegar en SQL Editor y ejecutar.
-- ============================================================================

grant usage on schema public to authenticated;

-- Perfil propio
grant select, update on public.profiles to authenticated;

-- Ficha del paciente (RLS: paciente lo suyo, médico asignados, staff todo)
grant select, insert, update on public.patients to authenticated;

-- Medicamentos (se reemplazan con delete+insert al guardar el intake)
grant select, insert, update, delete on public.medications to authenticated;

-- Historial de peso
grant select, insert, update, delete on public.weight_logs to authenticated;

-- Envíos de intake (el resultado de elegibilidad lo fija el servidor)
grant select, insert on public.intake_submissions to authenticated;

-- Recetas (RLS: solo médico asignado/staff escriben; paciente solo lee)
grant select, insert, update on public.prescriptions to authenticated;

-- Asignaciones médico↔paciente (RLS: staff escribe, médico ve las suyas)
grant select, insert, update, delete on public.provider_assignments to authenticated;

-- Consentimientos (registro inmutable: solo lectura + alta)
grant select, insert on public.consents to authenticated;

-- Funciones helper de rol (SECURITY DEFINER)
grant execute on function public.app_role()            to authenticated;
grant execute on function public.is_staff()            to authenticated;
grant execute on function public.is_assigned_medico(uuid) to authenticated;
grant execute on function public.my_patient_id()       to authenticated;

-- audit_log: SIN grants para authenticated/anon. Solo el servidor (service_role).
