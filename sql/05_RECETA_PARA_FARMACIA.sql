-- ============================================================================
-- Balance Plus — Paso 5: La farmacia puede abrir la receta de sus pedidos
-- Pegar TODO en el SQL Editor de Supabase y ejecutar UNA vez.
--
-- Problema que corrige:
--   Al definir quién podía abrir los PDF de recetas quedaron incluidos el
--   paciente, su médico tratante y el equipo de Balance Plus, pero no la
--   farmacia. Como la farmacia está obligada a revisar la receta antes de
--   despachar, el botón "Ver receta" de su portal no funcionaba.
--
-- Cómo queda:
--   La farmacia puede abrir únicamente la receta adjunta a un pedido suyo
--   que ya esté pagado. No ve recetas de otros pacientes ni de pedidos
--   que todavía no se pagan.
-- ============================================================================

drop policy if exists recetas_farmacia on storage.objects;
create policy recetas_farmacia on storage.objects
  for select to authenticated
  using (
    bucket_id = 'recetas'
    and exists (
      select 1
        from public.orders o
       where o.archivo_path = storage.objects.name
         and o.pharmacy_id = public.mi_farmacia()
         and o.status <> 'pendiente_pago'
    )
  );
