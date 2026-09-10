-- ============================================================================
-- Balance Plus — Paso 4: Solo se venden bajo receta los que la exigen
-- Pegar TODO en el SQL Editor de Supabase y ejecutar UNA vez.
--
-- Problema que corrige:
--   Hasta ahora un paciente podía agregar al pedido cualquier producto del
--   catálogo, aunque no se lo hubieran recetado. En medicamentos de venta
--   bajo receta eso no corresponde.
--
-- Cómo queda:
--   Cada producto declara si exige receta. Los que la exigen solo se pueden
--   comprar si el paciente tiene una receta suya para ese medicamento, con la
--   misma marca y la misma concentración. Insumos como agujas quedan libres.
--
--   La validación vive en la base de datos, no en la pantalla: aunque alguien
--   se salte la interfaz, el pedido se rechaza igual.
-- ============================================================================


-- ----------------------------------------------------------------------------
-- 1. Cada producto declara si exige receta
-- ----------------------------------------------------------------------------
alter table public.pharmacy_products
  add column if not exists requiere_receta boolean not null default true;

-- Los insumos no la exigen
update public.pharmacy_products
   set requiere_receta = false
 where requiere_receta
   and (nombre ilike '%aguja%' or nombre ilike '%jeringa%'
        or nombre ilike '%alcohol%' or nombre ilike '%algodon%'
        or nombre ilike '%contenedor%');


-- ----------------------------------------------------------------------------
-- 2. ¿Son el mismo medicamento?
--    Compara marca y concentración. "Ozempic 0,25 mg" NO es "Ozempic 0,5 mg".
--    Tolera mayúsculas, acentos, y la coma o el punto decimal.
-- ----------------------------------------------------------------------------
create or replace function public.mismo_medicamento(a text, b text)
returns boolean
language plpgsql
immutable
as $$
declare
  na text; nb text;
  marca_a text; marca_b text;
  ca text[]; cb text[];
begin
  if a is null or b is null then return false; end if;

  na := trim(regexp_replace(regexp_replace(
          replace(translate(lower(a), 'áéíóúüñ', 'aeiouun'), ',', '.'),
          '[^a-z0-9./]+', ' ', 'g'), '\s+', ' ', 'g'));
  nb := trim(regexp_replace(regexp_replace(
          replace(translate(lower(b), 'áéíóúüñ', 'aeiouun'), ',', '.'),
          '[^a-z0-9./]+', ' ', 'g'), '\s+', ' ', 'g'));

  marca_a := split_part(na, ' ', 1);
  marca_b := split_part(nb, ' ', 1);

  if length(marca_a) < 4 or length(marca_b) < 4 then return false; end if;
  if marca_a <> marca_b then return false; end if;

  ca := regexp_match(na, '([0-9]+(\.[0-9]+)?)\s*(mg|mcg|ml|g|ui)');
  cb := regexp_match(nb, '([0-9]+(\.[0-9]+)?)\s*(mg|mcg|ml|g|ui)');

  -- Ninguno declara concentración: basta con la marca
  if ca is null and cb is null then return true; end if;
  -- Solo uno la declara: no se puede afirmar que sean el mismo
  if ca is null or cb is null then return false; end if;

  return ca[1]::numeric = cb[1]::numeric and ca[3] = cb[3];
end;
$$;

grant execute on function public.mismo_medicamento(text, text) to authenticated;


-- ----------------------------------------------------------------------------
-- 3. Receta del paciente que respalda un producto, si existe
-- ----------------------------------------------------------------------------
create or replace function public.receta_para(p_patient uuid, p_nombre text)
returns uuid
language sql
stable
security definer set search_path = public
as $$
  select r.id
    from public.prescriptions r
   where r.patient_id = p_patient
     and r.archivo_path is not null
     and public.mismo_medicamento(r.medicamento, p_nombre)
   order by r.created_at desc
   limit 1;
$$;

grant execute on function public.receta_para(uuid, text) to authenticated;


-- ----------------------------------------------------------------------------
-- 4. Catálogo con la receta ya enlazada
--    La pantalla usa esto para saber qué puede comprar el paciente.
-- ----------------------------------------------------------------------------
create or replace function public.catalogo_farmacia(p_pharmacy uuid)
returns table (
  product_id      uuid,
  nombre          text,
  presentacion    text,
  laboratorio     text,
  precio          int,
  stock           int,
  requiere_receta boolean,
  prescription_id uuid,
  dosis           text,
  puede_comprar   boolean
)
language sql
stable
security definer set search_path = public
as $$
  select p.id, p.nombre, p.presentacion, p.laboratorio, p.precio, p.stock,
         p.requiere_receta,
         rx.id, rx.dosis,
         (not p.requiere_receta) or (rx.id is not null)
    from public.pharmacy_products p
    left join lateral (
      select r.id, r.dosis
        from public.prescriptions r
       where r.patient_id = public.my_patient_id()
         and r.archivo_path is not null
         and public.mismo_medicamento(r.medicamento, p.nombre)
       order by r.created_at desc
       limit 1
    ) rx on true
   where p.pharmacy_id = p_pharmacy
     and p.activo
   order by (not ((not p.requiere_receta) or (rx.id is not null))), p.nombre;
$$;

grant execute on function public.catalogo_farmacia(uuid) to authenticated;


-- ----------------------------------------------------------------------------
-- 5. Crear pedido, ahora exigiendo receta donde corresponde
-- ----------------------------------------------------------------------------
create or replace function public.crear_pedido(
  p_pharmacy   uuid,
  p_items      jsonb,
  p_modalidad  text,
  p_branch     uuid default null,
  p_direccion  text default null,
  p_comuna     text default null,
  p_referencia text default null,
  p_telefono   text default null
)
returns uuid
language plpgsql
security definer set search_path = public
as $$
declare
  v_patient uuid;
  v_farm    public.pharmacies;
  v_order   uuid;
  v_sub     int := 0;
  v_envio   int := 0;
  v_com     int;
  v_archivo text;
  v_dosis   text;
  v_presc   uuid;
  it        jsonb;
  prod      public.pharmacy_products;
  cant      int;
begin
  v_patient := public.my_patient_id();
  if v_patient is null then
    raise exception 'Solo un paciente registrado puede pedir';
  end if;

  select * into v_farm from public.pharmacies where id = p_pharmacy and activa;
  if v_farm.id is null then raise exception 'Farmacia no disponible'; end if;

  if p_modalidad = 'despacho' then
    if not v_farm.hace_despacho then
      raise exception 'Esta farmacia no hace despacho a domicilio';
    end if;
    if coalesce(trim(p_direccion),'') = '' then
      raise exception 'Falta la direccion de despacho';
    end if;
    if array_length(v_farm.comunas_despacho, 1) is not null
       and coalesce(p_comuna,'') <> ''
       and not (p_comuna = any(v_farm.comunas_despacho)) then
      raise exception 'Esta farmacia no despacha a %', p_comuna;
    end if;
    v_envio := v_farm.costo_despacho;

  elsif p_modalidad = 'retiro' then
    if p_branch is null then
      raise exception 'Elige la sucursal donde vas a retirar';
    end if;
    if not exists (select 1 from public.pharmacy_branches
                    where id = p_branch and pharmacy_id = p_pharmacy
                      and activa and permite_retiro) then
      raise exception 'Esa sucursal no esta disponible para retiro';
    end if;
  else
    raise exception 'Modalidad no valida';
  end if;

  insert into public.orders (
    patient_id, pharmacy_id, branch_id, modalidad,
    direccion, comuna, referencia, telefono,
    subtotal, costo_despacho, total, comision_pct, comision_monto, neto_farmacia)
  values (
    v_patient, p_pharmacy,
    case when p_modalidad = 'retiro' then p_branch end,
    p_modalidad::delivery_mode,
    p_direccion, p_comuna, p_referencia, p_telefono,
    0, v_envio, 0, v_farm.comision_pct, 0, 0)
  returning id into v_order;

  for it in select * from jsonb_array_elements(p_items) loop
    select * into prod
      from public.pharmacy_products
     where id = (it->>'product_id')::uuid
       and pharmacy_id = p_pharmacy and activo;

    if prod.id is null then
      raise exception 'Producto no disponible en esta farmacia';
    end if;

    cant := greatest(coalesce((it->>'cantidad')::int, 1), 1);

    if prod.stock is not null and prod.stock < cant then
      raise exception 'Sin stock suficiente de %', prod.nombre;
    end if;

    -- Aquí está el control: si el producto exige receta, tiene que existir
    -- una receta de este paciente para ese mismo medicamento y concentración.
    v_presc := null;
    v_dosis := null;

    if prod.requiere_receta then
      v_presc := public.receta_para(v_patient, prod.nombre);
      if v_presc is null then
        raise exception 'No tienes una receta vigente para %. Agenda una consulta para que un medico la evalue.', prod.nombre;
      end if;
      select r.dosis into v_dosis from public.prescriptions r where r.id = v_presc;
    end if;

    insert into public.order_items
      (order_id, product_id, prescription_id, nombre, dosis, cantidad, precio_unitario)
    values (v_order, prod.id, v_presc, prod.nombre, v_dosis, cant, prod.precio);

    v_sub := v_sub + prod.precio * cant;
  end loop;

  if v_sub = 0 then raise exception 'El pedido no tiene productos'; end if;

  -- La receta que se adjunta al pedido es la del primer producto que la exigió
  select r.archivo_path into v_archivo
    from public.order_items i
    join public.prescriptions r on r.id = i.prescription_id
   where i.order_id = v_order
   order by i.created_at
   limit 1;

  v_com := round(v_sub * v_farm.comision_pct / 100.0);

  update public.orders
     set archivo_path   = v_archivo,
         subtotal       = v_sub,
         total          = v_sub + v_envio,
         comision_monto = v_com,
         neto_farmacia  = v_sub - v_com + v_envio,
         updated_at     = now()
   where id = v_order;

  return v_order;
end;
$$;

grant execute on function public.crear_pedido(uuid, jsonb, text, uuid, text, text, text, text) to authenticated;


-- ----------------------------------------------------------------------------
-- 6. Comprobación rápida
--    Debe dar: verdadero, falso, falso, falso, verdadero
-- ----------------------------------------------------------------------------
select public.mismo_medicamento('Ozempic 0,25 mg', 'Ozempic 0,25 mg') as igual_ok,
       public.mismo_medicamento('Ozempic 0,25 mg', 'Ozempic 0,5 mg')  as distinta_dosis,
       public.mismo_medicamento('Ozempic 0,25 mg', 'Ozempic 1 mg')    as distinta_dosis2,
       public.mismo_medicamento('Ozempic 0,25 mg', 'Saxenda 6 mg/ml') as otra_marca,
       public.mismo_medicamento('ozempic 0.25mg',  'Ozempic 0,25 mg') as formato_distinto;
