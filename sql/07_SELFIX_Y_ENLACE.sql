-- ============================================================================
-- Balance Plus — Paso 7: Selfix en el catálogo de la farmacia de prueba
-- Pegar en el SQL Editor y ejecutar UNA vez.
--
-- Agrega Selfix al catálogo de la farmacia de prueba para que puedas ver
-- funcionando la elección entre marcas del mismo principio activo, y enlaza
-- los productos que ya estaban con el vademécum.
-- ============================================================================

-- Selfix, más barato que Ozempic, misma semaglutida
insert into public.pharmacy_products
  (pharmacy_id, nombre, presentacion, laboratorio, precio, stock, drug_product_id)
select f.id, 'Selfix ' ||
         trim(to_char(d.concentracion,'FM999999.999')) || ' ' || d.unidad,
       d.presentacion, d.laboratorio,
       case d.concentracion when 0.25 then 89990
                            when 0.5  then 99990
                            else 119990 end,
       10, d.id
  from public.pharmacies f
  join public.drug_products d on d.nombre = 'Selfix'
 where f.nombre = 'Farmacia de prueba Balance+'
   and not exists (
     select 1 from public.pharmacy_products p
      where p.pharmacy_id = f.id and p.drug_product_id = d.id);

-- Enlazar los productos que ya estaban cargados
update public.pharmacy_products p
   set drug_product_id = d.id
  from public.drug_products d
 where p.drug_product_id is null
   and public.mismo_medicamento(
         p.nombre,
         d.nombre || ' ' || trim(to_char(d.concentracion,'FM999999.999')) || ' ' || d.unidad);

-- Cómo quedó el catálogo
select p.nombre, p.precio, i.nombre as principio,
       (p.drug_product_id is not null) as enlazado
  from public.pharmacy_products p
  left join public.drug_products d on d.id = p.drug_product_id
  left join public.active_ingredients i on i.id = d.ingredient_id
 order by i.nombre nulls last, p.precio;
