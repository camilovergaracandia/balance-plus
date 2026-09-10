-- ============================================================================
-- Balance Plus — Paso 3: Farmacias, sucursales, catálogo y pedidos
-- Pegar TODO en el SQL Editor de Supabase y ejecutar UNA vez.
--
-- Modelo:
--   Cada farmacia con convenio tiene sucursales georreferenciadas y un
--   catálogo con precios. El paciente, con receta vigente, arma su pedido y
--   elige despacho a domicilio o retiro en la sucursal más cercana.
--   Paga en Balance Plus, que retiene su comisión y le muestra el pedido ya
--   pagado a la farmacia para que lo prepare.
--
--   El despacho corre por cuenta de la farmacia.
--   El paciente sigue el estado del pedido hasta la entrega, y su historial
--   guarda qué compró, en qué dosis y a qué precio.
-- ============================================================================


-- ----------------------------------------------------------------------------
-- 1. Tipos
-- ----------------------------------------------------------------------------
do $$ begin
  create type order_status as enum (
    'pendiente_pago',   -- creado, esperando pago
    'pagado',           -- pagado; recién aquí lo ve la farmacia
    'preparando',       -- la farmacia lo está preparando
    'listo_retiro',     -- disponible en la sucursal
    'en_despacho',      -- va en camino
    'entregado',
    'cancelado'
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type delivery_mode as enum ('retiro', 'despacho');
exception when duplicate_object then null; end $$;


-- ----------------------------------------------------------------------------
-- 2. Farmacias con convenio
-- ----------------------------------------------------------------------------
create table if not exists public.pharmacies (
  id             uuid primary key default gen_random_uuid(),
  nombre         text not null,
  rut            text,
  telefono       text,
  email          text,          -- adonde llega el aviso de pedido nuevo
  -- Comisión que retiene Balance Plus sobre el subtotal de productos
  comision_pct   numeric(5,2) not null default 15.00,
  hace_despacho  boolean not null default true,
  costo_despacho int not null default 0,
  comunas_despacho text[] not null default '{}',
  activa         boolean not null default true,
  created_at     timestamptz not null default now()
);

alter table public.pharmacies enable row level security;

drop policy if exists farm_select on public.pharmacies;
create policy farm_select on public.pharmacies
  for select to authenticated using ( activa or public.is_staff() );

drop policy if exists farm_admin on public.pharmacies;
create policy farm_admin on public.pharmacies
  for all to authenticated using ( public.is_staff() ) with check ( public.is_staff() );


-- ----------------------------------------------------------------------------
-- 3. Quién trabaja en cada farmacia
-- ----------------------------------------------------------------------------
create table if not exists public.pharmacy_staff (
  profile_id   uuid primary key references public.profiles(id) on delete cascade,
  pharmacy_id  uuid not null references public.pharmacies(id) on delete cascade,
  created_at   timestamptz not null default now()
);

alter table public.pharmacy_staff enable row level security;

drop policy if exists pstaff_select on public.pharmacy_staff;
create policy pstaff_select on public.pharmacy_staff
  for select to authenticated using ( profile_id = auth.uid() or public.is_staff() );

create or replace function public.mi_farmacia()
returns uuid
language sql
stable
security definer set search_path = public
as $$
  select pharmacy_id from public.pharmacy_staff where profile_id = auth.uid();
$$;

grant execute on function public.mi_farmacia() to authenticated;


-- ----------------------------------------------------------------------------
-- 4. Sucursales
--    Con coordenadas, para ordenarlas por cercanía al paciente.
-- ----------------------------------------------------------------------------
create table if not exists public.pharmacy_branches (
  id           uuid primary key default gen_random_uuid(),
  pharmacy_id  uuid not null references public.pharmacies(id) on delete cascade,
  nombre       text not null,
  direccion    text not null,
  comuna       text,
  region       text,
  telefono     text,
  lat          numeric(9,6),
  lng          numeric(9,6),
  horario      text,              -- "Lun a Vie 9:00–20:00 · Sáb 10:00–14:00"
  permite_retiro boolean not null default true,
  activa       boolean not null default true,
  created_at   timestamptz not null default now()
);

create index if not exists idx_suc_farmacia on public.pharmacy_branches (pharmacy_id);

alter table public.pharmacy_branches enable row level security;

drop policy if exists suc_select on public.pharmacy_branches;
create policy suc_select on public.pharmacy_branches
  for select to authenticated using ( activa or public.is_staff() );

drop policy if exists suc_admin on public.pharmacy_branches;
create policy suc_admin on public.pharmacy_branches
  for all to authenticated
  using ( pharmacy_id = public.mi_farmacia() or public.is_staff() )
  with check ( pharmacy_id = public.mi_farmacia() or public.is_staff() );


-- ----------------------------------------------------------------------------
-- 5. Catálogo de productos
-- ----------------------------------------------------------------------------
create table if not exists public.pharmacy_products (
  id           uuid primary key default gen_random_uuid(),
  pharmacy_id  uuid not null references public.pharmacies(id) on delete cascade,
  nombre       text not null,            -- "Ozempic 0,25 mg"
  presentacion text,                     -- "Lapicera precargada 1,5 ml"
  laboratorio  text,
  precio       int not null,             -- pesos, sin decimales
  stock        int,                      -- null = no se controla stock
  activo       boolean not null default true,
  updated_at   timestamptz not null default now(),
  created_at   timestamptz not null default now()
);

create index if not exists idx_prod_farmacia on public.pharmacy_products (pharmacy_id);

alter table public.pharmacy_products enable row level security;

drop policy if exists prod_select on public.pharmacy_products;
create policy prod_select on public.pharmacy_products
  for select to authenticated
  using ( activo or pharmacy_id = public.mi_farmacia() or public.is_staff() );

drop policy if exists prod_admin on public.pharmacy_products;
create policy prod_admin on public.pharmacy_products
  for all to authenticated
  using ( pharmacy_id = public.mi_farmacia() or public.is_staff() )
  with check ( pharmacy_id = public.mi_farmacia() or public.is_staff() );


-- ----------------------------------------------------------------------------
-- 6. Pedidos
-- ----------------------------------------------------------------------------
create table if not exists public.orders (
  id              uuid primary key default gen_random_uuid(),
  patient_id      uuid not null references public.patients(id) on delete cascade,
  pharmacy_id     uuid not null references public.pharmacies(id),
  branch_id       uuid references public.pharmacy_branches(id),  -- sucursal de retiro
  archivo_path    text,        -- receta que respalda el pedido
  modalidad       delivery_mode not null,
  -- Dirección solo si es despacho
  direccion       text,
  comuna          text,
  referencia      text,
  telefono        text,
  -- Montos congelados al crear el pedido
  subtotal        int not null,
  costo_despacho  int not null default 0,
  total           int not null,
  comision_pct    numeric(5,2) not null,
  comision_monto  int not null,           -- lo que retiene Balance Plus
  neto_farmacia   int not null,           -- lo que recibe la farmacia
  status          order_status not null default 'pendiente_pago',
  -- Seguimiento
  pagado_at       timestamptz,
  preparado_at    timestamptz,
  listo_at        timestamptz,
  despachado_at   timestamptz,
  entregado_at    timestamptz,
  nota_farmacia   text,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

create index if not exists idx_ord_patient  on public.orders (patient_id);
create index if not exists idx_ord_pharmacy on public.orders (pharmacy_id, status);

alter table public.orders enable row level security;

-- El paciente ve los suyos. La farmacia solo los pagados.
drop policy if exists ord_select on public.orders;
create policy ord_select on public.orders
  for select to authenticated
  using (
    patient_id = public.my_patient_id()
    or ( pharmacy_id = public.mi_farmacia() and status <> 'pendiente_pago' )
    or public.is_staff()
  );

drop policy if exists ord_update on public.orders;
create policy ord_update on public.orders
  for update to authenticated
  using ( pharmacy_id = public.mi_farmacia() or public.is_staff() );


create table if not exists public.order_items (
  id              uuid primary key default gen_random_uuid(),
  order_id        uuid not null references public.orders(id) on delete cascade,
  product_id      uuid references public.pharmacy_products(id),
  prescription_id uuid references public.prescriptions(id),
  nombre          text not null,   -- copia al momento de comprar
  dosis           text,            -- copia de la indicación del médico
  cantidad        int  not null default 1,
  precio_unitario int not null,
  created_at      timestamptz not null default now()
);

create index if not exists idx_item_order on public.order_items (order_id);

alter table public.order_items enable row level security;

drop policy if exists item_select on public.order_items;
create policy item_select on public.order_items
  for select to authenticated
  using ( exists (select 1 from public.orders o where o.id = order_id) );


-- ----------------------------------------------------------------------------
-- 7. Sucursales ordenadas por cercanía
--    Recibe la ubicación del paciente. Si no la entrega, devuelve todas
--    sin distancia. Fórmula de Haversine, sin extensiones.
-- ----------------------------------------------------------------------------
create or replace function public.sucursales_cercanas(
  p_lat numeric default null, p_lng numeric default null)
returns table (
  branch_id   uuid,
  pharmacy_id uuid,
  farmacia    text,
  nombre      text,
  direccion   text,
  comuna      text,
  telefono    text,
  horario     text,
  lat         numeric,
  lng         numeric,
  distancia_km numeric
)
language sql
stable
security definer set search_path = public
as $$
  select s.id, s.pharmacy_id, f.nombre, s.nombre, s.direccion, s.comuna,
         s.telefono, s.horario, s.lat, s.lng,
         case
           when p_lat is null or p_lng is null or s.lat is null or s.lng is null
           then null
           else round((
             6371 * acos(
               least(1, greatest(-1,
                 cos(radians(p_lat)) * cos(radians(s.lat)) *
                 cos(radians(s.lng) - radians(p_lng)) +
                 sin(radians(p_lat)) * sin(radians(s.lat))
               ))
             ))::numeric, 1)
         end
    from public.pharmacy_branches s
    join public.pharmacies f on f.id = s.pharmacy_id
   where s.activa and s.permite_retiro and f.activa
   order by 11 nulls last, s.nombre;
$$;

grant execute on function public.sucursales_cercanas(numeric, numeric) to authenticated;


-- ----------------------------------------------------------------------------
-- 8. Farmacias disponibles para el paciente
-- ----------------------------------------------------------------------------
create or replace function public.farmacias_disponibles()
returns table (
  pharmacy_id      uuid,
  nombre           text,
  hace_despacho    boolean,
  costo_despacho   int,
  comunas_despacho text[],
  sucursales       bigint,
  productos        bigint
)
language sql
stable
security definer set search_path = public
as $$
  select f.id, f.nombre, f.hace_despacho, f.costo_despacho, f.comunas_despacho,
         (select count(*) from public.pharmacy_branches s
           where s.pharmacy_id = f.id and s.activa),
         (select count(*) from public.pharmacy_products p
           where p.pharmacy_id = f.id and p.activo)
    from public.pharmacies f
   where f.activa and public.my_patient_id() is not null
   order by f.nombre;
$$;

grant execute on function public.farmacias_disponibles() to authenticated;


-- ----------------------------------------------------------------------------
-- 9. Medicamentos recetados al paciente
--    Sirve para que en la compra se vea qué le recetaron y en qué dosis.
-- ----------------------------------------------------------------------------
create or replace function public.mis_medicamentos_recetados()
returns table (
  prescription_id uuid,
  medicamento     text,
  dosis           text,
  indicaciones    text,
  emitida         timestamptz,
  archivo_path    text
)
language sql
stable
security definer set search_path = public
as $$
  select r.id, r.medicamento, r.dosis, r.indicaciones, r.created_at, r.archivo_path
    from public.prescriptions r
   where r.patient_id = public.my_patient_id()
   order by r.created_at desc;
$$;

grant execute on function public.mis_medicamentos_recetados() to authenticated;


-- ----------------------------------------------------------------------------
-- 10. El paciente crea su pedido
--     items: [{"product_id":"…","cantidad":1,"prescription_id":"…"}, …]
--     prescription_id es opcional; si viene, se copia la dosis al historial.
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

  -- Tiene que existir al menos una receta con archivo
  select archivo_path into v_archivo
    from public.prescriptions
   where patient_id = v_patient and archivo_path is not null
   order by created_at desc limit 1;

  if v_archivo is null then
    raise exception 'Necesitas una receta vigente para hacer un pedido';
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
    patient_id, pharmacy_id, branch_id, archivo_path, modalidad,
    direccion, comuna, referencia, telefono,
    subtotal, costo_despacho, total, comision_pct, comision_monto, neto_farmacia)
  values (
    v_patient, p_pharmacy,
    case when p_modalidad = 'retiro' then p_branch end,
    v_archivo, p_modalidad::delivery_mode,
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

    -- Dosis indicada por el médico, si el paciente vinculó la receta
    v_presc := nullif(it->>'prescription_id','')::uuid;
    v_dosis := null;
    if v_presc is not null then
      select r.dosis into v_dosis
        from public.prescriptions r
       where r.id = v_presc and r.patient_id = v_patient;
    end if;

    insert into public.order_items
      (order_id, product_id, prescription_id, nombre, dosis, cantidad, precio_unitario)
    values (v_order, prod.id, v_presc, prod.nombre, v_dosis, cant, prod.precio);

    v_sub := v_sub + prod.precio * cant;
  end loop;

  if v_sub = 0 then raise exception 'El pedido no tiene productos'; end if;

  v_com := round(v_sub * v_farm.comision_pct / 100.0);

  update public.orders
     set subtotal       = v_sub,
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
-- 11. Marcar un pedido como pagado
--     PROVISORIO: hoy lo llama el propio paciente para poder probar el flujo.
--     Cuando se integre Khipu o Transbank esto lo hará el webhook de la
--     pasarela, y hay que revocar el permiso al rol authenticated.
-- ----------------------------------------------------------------------------
create or replace function public.marcar_pagado(p_order uuid)
returns boolean
language plpgsql
security definer set search_path = public
as $$
begin
  update public.orders
     set status = 'pagado', pagado_at = now(), updated_at = now()
   where id = p_order
     and status = 'pendiente_pago'
     and ( patient_id = public.my_patient_id() or public.is_staff() );

  if not found then raise exception 'No se pudo registrar el pago'; end if;

  update public.pharmacy_products p
     set stock = p.stock - i.cantidad, updated_at = now()
    from public.order_items i
   where i.order_id = p_order and i.product_id = p.id and p.stock is not null;

  return true;
end;
$$;

grant execute on function public.marcar_pagado(uuid) to authenticated;


-- ----------------------------------------------------------------------------
-- 12. Bandeja de la farmacia
-- ----------------------------------------------------------------------------
create or replace function public.pedidos_farmacia(p_estado text default null)
returns table (
  order_id       uuid,
  creado         timestamptz,
  pagado         timestamptz,
  status         text,
  modalidad      text,
  sucursal       text,
  paciente       text,
  telefono       text,
  direccion      text,
  comuna         text,
  referencia     text,
  archivo_path   text,
  subtotal       int,
  costo_despacho int,
  total          int,
  neto_farmacia  int,
  nota_farmacia  text,
  items          jsonb
)
language sql
stable
security definer set search_path = public
as $$
  select o.id, o.created_at, o.pagado_at, o.status::text, o.modalidad::text,
         s.nombre,
         nullif(trim(coalesce(pr.nombre,'') || ' ' || coalesce(pr.apellido,'')), ''),
         coalesce(o.telefono, pr.celular),
         o.direccion, o.comuna, o.referencia, o.archivo_path,
         o.subtotal, o.costo_despacho, o.total, o.neto_farmacia, o.nota_farmacia,
         (select jsonb_agg(jsonb_build_object(
                   'nombre', i.nombre, 'dosis', i.dosis,
                   'cantidad', i.cantidad, 'precio', i.precio_unitario))
            from public.order_items i where i.order_id = o.id)
    from public.orders o
    join public.patients p  on p.id  = o.patient_id
    join public.profiles pr on pr.id = p.profile_id
    left join public.pharmacy_branches s on s.id = o.branch_id
   where o.pharmacy_id = public.mi_farmacia()
     and o.status <> 'pendiente_pago'
     and (p_estado is null or o.status::text = p_estado)
   order by o.pagado_at desc nulls last, o.created_at desc;
$$;

grant execute on function public.pedidos_farmacia(text) to authenticated;


-- ----------------------------------------------------------------------------
-- 13. La farmacia avanza el estado del pedido
-- ----------------------------------------------------------------------------
create or replace function public.avanzar_pedido(
  p_order uuid, p_status text, p_nota text default null)
returns boolean
language plpgsql
security definer set search_path = public
as $$
declare v_farm uuid;
begin
  v_farm := public.mi_farmacia();
  if v_farm is null and not public.is_staff() then
    raise exception 'Solo la farmacia puede actualizar el pedido';
  end if;

  if p_status not in ('preparando','listo_retiro','en_despacho','entregado','cancelado') then
    raise exception 'Estado no valido';
  end if;

  update public.orders
     set status        = p_status::order_status,
         preparado_at  = case when p_status = 'preparando'   then now() else preparado_at end,
         listo_at      = case when p_status = 'listo_retiro' then now() else listo_at end,
         despachado_at = case when p_status = 'en_despacho'  then now() else despachado_at end,
         entregado_at  = case when p_status = 'entregado'    then now() else entregado_at end,
         nota_farmacia = coalesce(p_nota, nota_farmacia),
         updated_at    = now()
   where id = p_order
     and (pharmacy_id = v_farm or public.is_staff())
     and status <> 'pendiente_pago';

  if not found then raise exception 'No puedes actualizar este pedido'; end if;
  return true;
end;
$$;

grant execute on function public.avanzar_pedido(uuid, text, text) to authenticated;


-- ----------------------------------------------------------------------------
-- 14. Pedidos del paciente, con seguimiento e historial
-- ----------------------------------------------------------------------------
create or replace function public.mis_pedidos()
returns table (
  order_id       uuid,
  creado         timestamptz,
  status         text,
  modalidad      text,
  farmacia       text,
  sucursal       text,
  sucursal_dir   text,
  sucursal_tel   text,
  sucursal_hor   text,
  direccion      text,
  subtotal       int,
  costo_despacho int,
  total          int,
  nota_farmacia  text,
  pagado_at      timestamptz,
  preparado_at   timestamptz,
  listo_at       timestamptz,
  despachado_at  timestamptz,
  entregado_at   timestamptz,
  items          jsonb
)
language sql
stable
security definer set search_path = public
as $$
  select o.id, o.created_at, o.status::text, o.modalidad::text,
         f.nombre, s.nombre, s.direccion, s.telefono, s.horario,
         o.direccion, o.subtotal, o.costo_despacho, o.total, o.nota_farmacia,
         o.pagado_at, o.preparado_at, o.listo_at, o.despachado_at, o.entregado_at,
         (select jsonb_agg(jsonb_build_object(
                   'nombre', i.nombre, 'dosis', i.dosis,
                   'cantidad', i.cantidad, 'precio', i.precio_unitario))
            from public.order_items i where i.order_id = o.id)
    from public.orders o
    join public.pharmacies f on f.id = o.pharmacy_id
    left join public.pharmacy_branches s on s.id = o.branch_id
   where o.patient_id = public.my_patient_id()
   order by o.created_at desc;
$$;

grant execute on function public.mis_pedidos() to authenticated;


-- ----------------------------------------------------------------------------
-- 15. Farmacia de prueba con tres sucursales, para probar el flujo hoy
--     Bórrala cuando cierres el convenio real.
-- ----------------------------------------------------------------------------
insert into public.pharmacies
  (nombre, telefono, email, comision_pct, hace_despacho, costo_despacho, comunas_despacho)
select 'Farmacia de prueba Balance+', '+56 2 2345 6789', 'contacto@ejemplo.cl',
       15.00, true, 3990,
       array['Providencia','Las Condes','Ñuñoa','Santiago','Vitacura','La Reina','Macul']
 where not exists (select 1 from public.pharmacies);

insert into public.pharmacy_branches
  (pharmacy_id, nombre, direccion, comuna, region, telefono, lat, lng, horario)
select f.id, x.nombre, x.dir, x.comuna, 'Metropolitana', x.tel, x.lat, x.lng, x.hor
  from public.pharmacies f
  cross join (values
    ('Sucursal Providencia', 'Av. Providencia 1234', 'Providencia', '+56 2 2345 6781',
     -33.425900, -70.616700, 'Lun a Vie 9:00–20:00 · Sáb 10:00–14:00'),
    ('Sucursal Las Condes',  'Av. Apoquindo 4500',  'Las Condes',  '+56 2 2345 6782',
     -33.412600, -70.573900, 'Lun a Vie 9:00–21:00 · Sáb 10:00–15:00'),
    ('Sucursal Ñuñoa',       'Av. Irarrázaval 3200','Ñuñoa',       '+56 2 2345 6783',
     -33.455300, -70.594600, 'Lun a Sáb 9:00–20:00')
  ) as x(nombre, dir, comuna, tel, lat, lng, hor)
 where f.nombre = 'Farmacia de prueba Balance+'
   and not exists (select 1 from public.pharmacy_branches);

insert into public.pharmacy_products (pharmacy_id, nombre, presentacion, laboratorio, precio, stock)
select f.id, x.nombre, x.presentacion, x.lab, x.precio, x.stock
  from public.pharmacies f
  cross join (values
    ('Ozempic 0,25 mg',      'Lapicera precargada 1,5 ml', 'Novo Nordisk', 149990, 12),
    ('Ozempic 0,5 mg',       'Lapicera precargada 1,5 ml', 'Novo Nordisk', 159990, 10),
    ('Ozempic 1 mg',         'Lapicera precargada 3 ml',   'Novo Nordisk', 189990,  8),
    ('Saxenda 6 mg/ml',      'Lapicera precargada 3 ml',   'Novo Nordisk', 129990,  6),
    ('Agujas NovoFine 32G',  'Caja de 100 unidades',       'Novo Nordisk',  24990, 40),
    ('Metformina 850 mg',    'Caja de 30 comprimidos',     'Genérico',       8990, 50)
  ) as x(nombre, presentacion, lab, precio, stock)
 where f.nombre = 'Farmacia de prueba Balance+'
   and not exists (select 1 from public.pharmacy_products);
