-- ============================================================================
-- Balance Plus — Paso 6: Recetar por principio activo
-- Pegar TODO en el SQL Editor de Supabase y ejecutar UNA vez.
--
-- Por qué:
--   Hasta ahora el médico escribía el medicamento a mano y el sistema lo
--   comparaba con el catálogo por texto. Si escribía "Semaglutida 0,25 mg"
--   en vez de "Ozempic 0,25 mg", el paciente no podía comprar nada.
--
-- Cómo queda:
--   El médico receta un principio activo con su concentración. El paciente
--   ve todos los productos que corresponden a esa receta y elige por precio
--   o preferencia, como con cualquier genérico.
--   Si el médico tiene una razón clínica para fijar una marca, puede marcar
--   que no acepta sustitución y el paciente queda limitado a ese producto.
--
--   Las recetas anteriores, escritas a mano, siguen funcionando: el sistema
--   cae de vuelta a la comparación por texto cuando no hay principio activo.
-- ============================================================================


-- ----------------------------------------------------------------------------
-- 1. Principios activos
-- ----------------------------------------------------------------------------
create table if not exists public.active_ingredients (
  id         uuid primary key default gen_random_uuid(),
  nombre     text not null unique,        -- "Semaglutida"
  clase      text,                        -- "Agonista del receptor GLP-1"
  activo     boolean not null default true,
  created_at timestamptz not null default now()
);

alter table public.active_ingredients enable row level security;

drop policy if exists ing_select on public.active_ingredients;
create policy ing_select on public.active_ingredients
  for select to authenticated using ( activo or public.is_staff() );

drop policy if exists ing_admin on public.active_ingredients;
create policy ing_admin on public.active_ingredients
  for all to authenticated using ( public.is_staff() ) with check ( public.is_staff() );


-- ----------------------------------------------------------------------------
-- 2. Vademécum: los productos que existen en el mercado
--    Se llama drug_products porque "medications" ya existe: esa guarda los
--    medicamentos que el paciente declara tomar, y es otra cosa.
--    Lo mantiene Balance Plus, no las farmacias. El médico receta contra esto,
--    aunque una farmacia puntual no tenga stock.
-- ----------------------------------------------------------------------------
create table if not exists public.drug_products (
  id            uuid primary key default gen_random_uuid(),
  ingredient_id uuid not null references public.active_ingredients(id),
  nombre        text not null,             -- "Ozempic"
  laboratorio   text,
  concentracion numeric(10,3) not null,    -- 0.25
  unidad        text not null,             -- mg
  forma         text,                      -- "Lapicera precargada subcutánea"
  presentacion  text,                      -- "1,5 ml"
  activo        boolean not null default true,
  created_at    timestamptz not null default now(),
  unique (nombre, concentracion, unidad)
);

create index if not exists idx_prod_ing on public.drug_products (ingredient_id);

alter table public.drug_products enable row level security;

drop policy if exists dprod_select on public.drug_products;
create policy dprod_select on public.drug_products
  for select to authenticated using ( activo or public.is_staff() );

drop policy if exists dprod_admin on public.drug_products;
create policy dprod_admin on public.drug_products
  for all to authenticated using ( public.is_staff() ) with check ( public.is_staff() );


-- ----------------------------------------------------------------------------
-- 3. La receta pasa a apuntar al principio activo
-- ----------------------------------------------------------------------------
alter table public.prescriptions
  add column if not exists ingredient_id   uuid references public.active_ingredients(id),
  add column if not exists concentracion   numeric(10,3),
  add column if not exists unidad          text,
  add column if not exists drug_product_id   uuid references public.drug_products(id),
  add column if not exists sin_sustitucion boolean not null default false;

comment on column public.prescriptions.drug_product_id is
  'Producto exigido por el médico. Solo se usa cuando sin_sustitucion es verdadero.';


-- ----------------------------------------------------------------------------
-- 4. El producto de farmacia se cuelga del vademécum
-- ----------------------------------------------------------------------------
alter table public.pharmacy_products
  add column if not exists drug_product_id uuid references public.drug_products(id);


-- ----------------------------------------------------------------------------
-- 5. Principios activos y productos del mercado chileno
--    BORRADOR. Revísalo con criterio médico y con el registro del ISP antes
--    de usarlo con pacientes reales: pueden faltar productos, sobrar los que
--    no estén disponibles, o estar mal una concentración.
-- ----------------------------------------------------------------------------
insert into public.active_ingredients (nombre, clase) values
  ('Semaglutida',  'Agonista del receptor GLP-1'),
  ('Liraglutida',  'Agonista del receptor GLP-1'),
  ('Dulaglutida',  'Agonista del receptor GLP-1'),
  ('Tirzepatida',  'Agonista dual GIP/GLP-1'),
  ('Metformina',   'Biguanida')
on conflict (nombre) do nothing;

insert into public.drug_products (ingredient_id, nombre, laboratorio, concentracion, unidad, forma, presentacion)
select i.id, x.nombre, x.lab, x.conc, x.uni, x.forma, x.pres
  from (values
    ('Semaglutida', 'Ozempic', 'Novo Nordisk', 0.25, 'mg', 'Lapicera precargada subcutánea', '1,5 ml'),
    ('Semaglutida', 'Ozempic', 'Novo Nordisk', 0.5,  'mg', 'Lapicera precargada subcutánea', '1,5 ml'),
    ('Semaglutida', 'Ozempic', 'Novo Nordisk', 1.0,  'mg', 'Lapicera precargada subcutánea', '3 ml'),
    ('Semaglutida', 'Selfix',  'Laboratorios Chile', 0.25, 'mg', 'Lapicera precargada subcutánea', '1,5 ml'),
    ('Semaglutida', 'Selfix',  'Laboratorios Chile', 0.5,  'mg', 'Lapicera precargada subcutánea', '1,5 ml'),
    ('Semaglutida', 'Selfix',  'Laboratorios Chile', 1.0,  'mg', 'Lapicera precargada subcutánea', '3 ml'),
    ('Semaglutida', 'Wegovy',  'Novo Nordisk', 0.25, 'mg', 'Lapicera precargada subcutánea', '1,5 ml'),
    ('Semaglutida', 'Rybelsus','Novo Nordisk', 7.0,  'mg', 'Comprimido oral', 'Caja de 30'),
    ('Semaglutida', 'Rybelsus','Novo Nordisk', 14.0, 'mg', 'Comprimido oral', 'Caja de 30'),
    ('Liraglutida', 'Saxenda', 'Novo Nordisk', 6.0,  'mg/ml', 'Lapicera precargada subcutánea', '3 ml'),
    ('Liraglutida', 'Victoza', 'Novo Nordisk', 6.0,  'mg/ml', 'Lapicera precargada subcutánea', '3 ml'),
    ('Dulaglutida', 'Trulicity','Eli Lilly',   1.5,  'mg', 'Lapicera precargada subcutánea', '0,5 ml'),
    ('Tirzepatida', 'Mounjaro', 'Eli Lilly',   5.0,  'mg', 'Lapicera precargada subcutánea', '0,5 ml'),
    ('Metformina',  'Metformina','Genérico',   850.0,'mg', 'Comprimido oral', 'Caja de 30')
  ) as x(ing, nombre, lab, conc, uni, forma, pres)
  join public.active_ingredients i on i.nombre = x.ing
on conflict (nombre, concentracion, unidad) do nothing;


-- ----------------------------------------------------------------------------
-- 6. Enlazar los productos de farmacia que ya existen
-- ----------------------------------------------------------------------------
update public.pharmacy_products p
   set drug_product_id = m.id
  from public.drug_products m
 where p.drug_product_id is null
   and public.mismo_medicamento(p.nombre, m.nombre || ' ' || trim(to_char(m.concentracion,'FM999999.999')) || ' ' || m.unidad);


-- ----------------------------------------------------------------------------
-- 7. ¿Este producto sirve para esta receta?
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

  -- Receta antigua, escrita a mano: se compara por texto
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
-- 8. Receta del paciente que respalda un producto
-- ----------------------------------------------------------------------------
create or replace function public.receta_para_producto(p_patient uuid, p_product uuid)
returns uuid
language sql
stable
security definer set search_path = public
as $$
  select r.id
    from public.prescriptions r
   where r.patient_id = p_patient
     and r.archivo_path is not null
     and public.producto_sirve(r.id, p_product)
   order by r.created_at desc
   limit 1;
$$;

grant execute on function public.receta_para_producto(uuid, uuid) to authenticated;


-- ----------------------------------------------------------------------------
-- 9. Catálogo del paciente, ahora por principio activo
-- ----------------------------------------------------------------------------
drop function if exists public.catalogo_farmacia(uuid);
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
  principio       text,
  puede_comprar   boolean
)
language sql
stable
security definer set search_path = public
as $$
  select p.id, p.nombre, p.presentacion, p.laboratorio, p.precio, p.stock,
         p.requiere_receta,
         rx.id, rx.dosis,
         i.nombre,
         (not p.requiere_receta) or (rx.id is not null)
    from public.pharmacy_products p
    left join public.drug_products m       on m.id = p.drug_product_id
    left join public.active_ingredients i on i.id = m.ingredient_id
    left join lateral (
      select r.id, r.dosis
        from public.prescriptions r
       where r.patient_id = public.my_patient_id()
         and r.archivo_path is not null
         and public.producto_sirve(r.id, p.id)
       order by r.created_at desc
       limit 1
    ) rx on true
   where p.pharmacy_id = p_pharmacy
     and p.activo
   order by (not ((not p.requiere_receta) or (rx.id is not null))),
            i.nombre nulls last, p.precio;
$$;

grant execute on function public.catalogo_farmacia(uuid) to authenticated;


-- ----------------------------------------------------------------------------
-- 10. Crear pedido, validando contra el principio activo
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
  v_patient uuid; v_farm public.pharmacies; v_order uuid;
  v_sub int := 0; v_envio int := 0; v_com int;
  v_archivo text; v_dosis text; v_presc uuid;
  it jsonb; prod public.pharmacy_products; cant int;
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

    v_presc := null; v_dosis := null;

    if prod.requiere_receta then
      v_presc := public.receta_para_producto(v_patient, prod.id);
      if v_presc is null then
        raise exception 'No tienes una receta vigente que cubra %. Agenda una consulta para que un medico la evalue.', prod.nombre;
      end if;
      select r.dosis into v_dosis from public.prescriptions r where r.id = v_presc;
    end if;

    insert into public.order_items
      (order_id, product_id, prescription_id, nombre, dosis, cantidad, precio_unitario)
    values (v_order, prod.id, v_presc, prod.nombre, v_dosis, cant, prod.precio);

    v_sub := v_sub + prod.precio * cant;
  end loop;

  if v_sub = 0 then raise exception 'El pedido no tiene productos'; end if;

  select r.archivo_path into v_archivo
    from public.order_items i
    join public.prescriptions r on r.id = i.prescription_id
   where i.order_id = v_order
   order by i.created_at limit 1;

  v_com := round(v_sub * v_farm.comision_pct / 100.0);

  update public.orders
     set archivo_path = v_archivo, subtotal = v_sub, total = v_sub + v_envio,
         comision_monto = v_com, neto_farmacia = v_sub - v_com + v_envio,
         updated_at = now()
   where id = v_order;

  return v_order;
end;
$$;

grant execute on function public.crear_pedido(uuid, jsonb, text, uuid, text, text, text, text) to authenticated;


-- ----------------------------------------------------------------------------
-- 11. Lista de principios activos para el médico
-- ----------------------------------------------------------------------------
create or replace function public.vademecum()
returns table (
  ingredient_id uuid,
  principio     text,
  clase         text,
  concentracion numeric,
  unidad        text,
  forma         text,
  productos     jsonb
)
language sql
stable
security definer set search_path = public
as $$
  select i.id, i.nombre, i.clase, m.concentracion, m.unidad,
         min(m.forma),
         jsonb_agg(jsonb_build_object(
           'drug_product_id', m.id, 'nombre', m.nombre, 'laboratorio', m.laboratorio)
           order by m.nombre)
    from public.active_ingredients i
    join public.drug_products m on m.ingredient_id = i.id and m.activo
   where i.activo
   group by i.id, i.nombre, i.clase, m.concentracion, m.unidad
   order by i.nombre, m.concentracion;
$$;

grant execute on function public.vademecum() to authenticated;


-- ----------------------------------------------------------------------------
-- 12. Comprobación
-- ----------------------------------------------------------------------------
select i.nombre as principio,
       count(distinct m.id) as productos,
       string_agg(distinct m.nombre, ', ' order by m.nombre) as marcas
  from public.active_ingredients i
  left join public.drug_products m on m.ingredient_id = i.id
 group by i.nombre
 order by i.nombre;
