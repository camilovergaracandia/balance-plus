-- ============================================================================
-- Balance Plus — Paso 8: Medicamentos de soporte y texto libre
-- Pegar TODO en el SQL Editor y ejecutar UNA vez.
--
-- Dos cosas:
--   1. Amplía la lista con lo que se indica habitualmente para los efectos
--      adversos de los GLP-1: náuseas, vómitos, constipación, dolor.
--   2. Permite al médico escribir un medicamento a mano cuando no está en la
--      lista. Ese queda en la receta impresa, que es el documento legal y
--      sirve en cualquier farmacia, pero NO habilita compra por Balance Plus:
--      calzar textos con el catálogo es justamente lo que queríamos evitar.
--
-- BORRADOR: la lista de abajo es una propuesta. Revísala con criterio médico
-- y contra el registro del ISP antes de usarla con pacientes reales.
-- ============================================================================


-- ----------------------------------------------------------------------------
-- 1. El médico puede escribir un medicamento fuera de lista
-- ----------------------------------------------------------------------------
alter table public.prescriptions
  add column if not exists es_texto_libre boolean not null default false;

comment on column public.prescriptions.es_texto_libre is
  'Medicamento escrito a mano por el médico, fuera del vademécum. Vale en la '
  'receta impresa pero no habilita compra dentro de Balance Plus.';


-- ----------------------------------------------------------------------------
-- 2. Un medicamento escrito a mano nunca habilita compra
-- ----------------------------------------------------------------------------
create or replace function public.producto_sirve(p_prescription uuid, p_product uuid)
returns boolean
language plpgsql
stable
security definer set search_path = public
as $$
declare r public.prescriptions; p public.pharmacy_products; m public.drug_products;
begin
  select * into r from public.prescriptions where id = p_prescription;
  select * into p from public.pharmacy_products where id = p_product;
  if r.id is null or p.id is null then return false; end if;

  -- Escrito a mano: sirve como indicación, no como habilitación de compra
  if r.es_texto_libre then return false; end if;

  -- Receta antigua, anterior al vademécum: se compara por texto
  if r.ingredient_id is null then
    return public.mismo_medicamento(r.medicamento, p.nombre);
  end if;

  -- El médico exigió un producto concreto
  if r.sin_sustitucion then
    return p.drug_product_id is not null and p.drug_product_id = r.drug_product_id;
  end if;

  -- Cualquier producto con el mismo principio activo y concentración
  if p.drug_product_id is null then return false; end if;
  select * into m from public.drug_products where id = p.drug_product_id;
  return m.ingredient_id = r.ingredient_id
     and m.concentracion = r.concentracion
     and m.unidad = r.unidad;
end;
$$;

grant execute on function public.producto_sirve(uuid, uuid) to authenticated;


-- ----------------------------------------------------------------------------
-- 3. Principios activos de soporte
-- ----------------------------------------------------------------------------
insert into public.active_ingredients (nombre, clase) values
  ('Ondansetrón',            'Antiemético'),
  ('Metoclopramida',         'Antiemético / procinético'),
  ('Domperidona',            'Antiemético / procinético'),
  ('Paracetamol',            'Analgésico y antipirético'),
  ('Ibuprofeno',             'Antiinflamatorio no esteroidal'),
  ('Omeprazol',              'Inhibidor de la bomba de protones'),
  ('Polietilenglicol',       'Laxante osmótico'),
  ('Lactulosa',              'Laxante osmótico'),
  ('Bisacodilo',             'Laxante estimulante'),
  ('Sales de rehidratación', 'Rehidratación oral')
on conflict (nombre) do nothing;


-- ----------------------------------------------------------------------------
-- 4. Productos de soporte
-- ----------------------------------------------------------------------------
insert into public.drug_products (ingredient_id, nombre, laboratorio, concentracion, unidad, forma, presentacion)
select i.id, x.nombre, x.lab, x.conc, x.uni, x.forma, x.pres
  from (values
    ('Ondansetrón',    'Ondansetrón',       'Genérico',  4.0,  'mg',   'Comprimido dispersable oral', 'Caja de 10'),
    ('Ondansetrón',    'Ondansetrón',       'Genérico',  8.0,  'mg',   'Comprimido dispersable oral', 'Caja de 10'),
    ('Metoclopramida', 'Metoclopramida',    'Genérico',  10.0, 'mg',   'Comprimido oral',             'Caja de 20'),
    ('Domperidona',    'Domperidona',       'Genérico',  10.0, 'mg',   'Comprimido oral',             'Caja de 30'),
    ('Paracetamol',    'Paracetamol',       'Genérico',  500.0,'mg',   'Comprimido oral',             'Caja de 20'),
    ('Paracetamol',    'Paracetamol',       'Genérico',  1000.0,'mg',  'Comprimido oral',             'Caja de 16'),
    ('Ibuprofeno',     'Ibuprofeno',        'Genérico',  400.0,'mg',   'Comprimido oral',             'Caja de 20'),
    ('Omeprazol',      'Omeprazol',         'Genérico',  20.0, 'mg',   'Cápsula oral',                'Caja de 30'),
    ('Polietilenglicol','Polietilenglicol', 'Genérico',  17.0, 'g',    'Polvo para solución oral',    'Caja de 14 sobres'),
    ('Lactulosa',      'Lactulosa',         'Genérico',  65.0, 'g/100ml','Solución oral',             'Frasco 200 ml'),
    ('Bisacodilo',     'Bisacodilo',        'Genérico',  5.0,  'mg',   'Comprimido recubierto oral',  'Caja de 30'),
    ('Sales de rehidratación','Sales de rehidratación','Genérico', 1.0,'sobre','Polvo para solución oral','Caja de 8 sobres')
  ) as x(ing, nombre, lab, conc, uni, forma, pres)
  join public.active_ingredients i on i.nombre = x.ing
on conflict (nombre, concentracion, unidad) do nothing;


-- ----------------------------------------------------------------------------
-- 5. Qué se escribe a mano y con qué frecuencia
--    Sirve para ir sumando al vademécum lo que los médicos realmente recetan.
-- ----------------------------------------------------------------------------
create or replace function public.recetas_fuera_de_lista()
returns table (medicamento text, veces bigint, ultima timestamptz)
language sql
stable
security definer set search_path = public
as $$
  select r.medicamento, count(*), max(r.created_at)
    from public.prescriptions r
   where r.es_texto_libre and public.is_staff()
   group by r.medicamento
   order by count(*) desc, max(r.created_at) desc;
$$;

grant execute on function public.recetas_fuera_de_lista() to authenticated;


-- ----------------------------------------------------------------------------
-- 6. Cómo quedó la lista
-- ----------------------------------------------------------------------------
select i.clase,
       count(distinct i.id) as principios,
       count(d.id)          as presentaciones
  from public.active_ingredients i
  left join public.drug_products d on d.ingredient_id = i.id
 group by i.clase
 order by i.clase;
