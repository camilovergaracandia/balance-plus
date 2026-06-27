-- ============================================================================
-- Balance+ — Parche 04: motor de elegibilidad en el SERVIDOR
--
-- Mueve las reglas de "¿es candidato GLP-1?" a una función de Postgres.
-- El navegador solo envía los datos y recibe el veredicto; las reglas
-- (umbrales, exclusiones) NO viajan al cliente → no son copiables.
--
-- Pegar en SQL Editor y ejecutar.
-- ============================================================================

create or replace function public.evaluate_eligibility(payload jsonb)
returns jsonb
language plpgsql
stable
security definer set search_path = public
as $$
declare
  v_bmi   numeric := nullif(payload->>'bmi','')::numeric;
  v_edad  int     := nullif(payload->>'edad','')::int;
  v_excl  boolean := coalesce((payload->>'excluyentes')::boolean, false);
  v_result text;
  v_motivo text;
begin
  if v_edad is not null and v_edad < 18 then
    v_result := 'no_candidato';      v_motivo := 'Menor de 18 años';
  elsif v_bmi is null then
    v_result := 'requiere_revision'; v_motivo := 'IMC no disponible';
  elsif v_bmi < 25 then
    v_result := 'no_candidato';      v_motivo := 'IMC bajo el umbral mínimo (25)';
  elsif v_excl then
    v_result := 'requiere_revision'; v_motivo := 'Requiere revisión médica por antecedentes';
  else
    v_result := 'candidato';         v_motivo := 'Cumple criterios iniciales';
  end if;

  return jsonb_build_object('result', v_result, 'motivo', v_motivo);
end $$;

-- La evaluación ocurre antes de crear la cuenta, así que también el rol anónimo
-- puede llamarla. Es una función pura: no lee ni escribe datos de pacientes.
grant execute on function public.evaluate_eligibility(jsonb) to anon, authenticated;
