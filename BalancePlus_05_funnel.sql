-- ============================================================================
-- Balance+ — Parche 05: conteo ANÓNIMO del embudo de elegibilidad
--
-- Registra cuántas personas son descalificadas o no completan, SIN guardar
-- ningún dato identificable (sin nombre, RUT, correo ni valores exactos).
-- Solo: etapa, resultado, motivo, banda gruesa de IMC y si es menor de edad.
--
-- El registro lo hace una función en el SERVIDOR (no se puede falsear desde
-- el cliente) y nadie puede leer la tabla salvo el rol staff.
--
-- Pegar en SQL Editor y ejecutar (después del 04_eligibility).
-- ============================================================================

create table if not exists public.eligibility_events (
  id          bigint generated always as identity primary key,
  etapa       text,                 -- 'descalificado' | 'resultado' | ...
  result      eligibility_result,   -- candidato | no_candidato | requiere_revision
  motivo      text,
  bmi_band    text,                 -- '<25' | '25-29' | '30-34' | '35-39' | '40+'
  menor_edad  boolean,
  created_at  timestamptz not null default now()
);

alter table public.eligibility_events enable row level security;

-- Solo staff puede leer estos conteos. Nadie inserta directamente:
-- la inserción ocurre solo dentro de la función SECURITY DEFINER de abajo.
drop policy if exists elig_events_select_staff on public.eligibility_events;
create policy elig_events_select_staff on public.eligibility_events
  for select using (public.is_staff());

-- Registra un evento anónimo y devuelve el veredicto (reusa evaluate_eligibility).
create or replace function public.log_eligibility(payload jsonb, etapa text default null)
returns jsonb
language plpgsql
volatile
security definer set search_path = public
as $$
declare
  v      jsonb   := public.evaluate_eligibility(payload);
  v_bmi  numeric := nullif(payload->>'bmi','')::numeric;
  v_edad int     := nullif(payload->>'edad','')::int;
  v_band text;
begin
  v_band := case
    when v_bmi is null then 'desconocido'
    when v_bmi < 25 then '<25'
    when v_bmi < 30 then '25-29'
    when v_bmi < 35 then '30-34'
    when v_bmi < 40 then '35-39'
    else '40+' end;

  insert into public.eligibility_events(etapa, result, motivo, bmi_band, menor_edad)
  values (etapa, (v->>'result')::eligibility_result, v->>'motivo', v_band, coalesce(v_edad < 18, false));

  return v;
end $$;

-- Se llama antes de crear la cuenta, así que también el rol anónimo puede usarla.
grant execute on function public.log_eligibility(jsonb, text) to anon, authenticated;
