-- ============================================================================
-- DIESEL Barbershop — إعداد قاعدة البيانات كاملة من الصفر (ملف واحد)
-- شغّله مرة واحدة بالكامل في: Supabase → SQL Editor → New query → Run
-- ينشئ كل الجداول والدوال والأعمدة التي يحتاجها التطبيق، بصلاحيات RLS
-- مفتوحة (allow all) حتى يعمل التطبيق فورًا بمفتاح anon.
-- (لتشديد الأمان لاحقًا: شغّل db/secure_rls_migration.sql — راجع SECURITY_SETUP.md)
-- ============================================================================



-- ========================= 01_setup_adria.sql =========================
-- ============================================================
-- ADRIA — متجر ملابس | إعداد قاعدة البيانات من الصفر (نسخة فاضية)
-- ينشئ كل الجداول + تصنيفات ملابس فقط، بدون أي منتجات أو بيانات.
-- شغّله بالكامل مرة واحدة: Supabase > SQL Editor > New query > Run
-- ============================================================

create extension if not exists pgcrypto;
create extension if not exists "uuid-ossp";

-- ============================================================
-- 1) الجداول
-- ============================================================

create table if not exists store_settings (
  id uuid default gen_random_uuid() primary key,
  name text not null default 'ADRIA',
  currency text default 'ج.م',
  logo text default 'https://cdn-icons-png.flaticon.com/512/3531/3531849.png',
  tax_rate numeric default 0,
  theme_color text default '#4f46e5',
  address text default '',
  phone text default '',
  phone2 text default '',
  whatsapp_country_code text default '2',
  initial_balance numeric default 0,
  location_url text default ''
);

create table if not exists categories (
  id uuid default gen_random_uuid() primary key,
  name text not null,
  created_at timestamptz default now()
);

create table if not exists products (
  id uuid default gen_random_uuid() primary key,
  name text not null,
  barcode text unique,
  purchase_price numeric default 0,
  average_purchase_price numeric default 0,
  sale_price numeric default 0,
  discount_price numeric default 0,
  wholesale_price numeric default 0,
  half_wholesale_price numeric default 0,
  season text,
  stock_quantity numeric default 0,
  display_quantity numeric default 0,
  unit text not null default 'قطعة',
  category_id uuid references categories(id) on delete set null,
  is_hidden boolean default false,
  created_at timestamptz default now()
);

create table if not exists customers (
  id uuid default gen_random_uuid() primary key,
  custom_id text unique,
  name text not null default 'بدون اسم',
  phone text unique not null,
  card_number text,
  created_at timestamptz default now()
);

create table if not exists suppliers (
  id uuid default gen_random_uuid() primary key,
  name text not null,
  phone text,
  address text,
  created_at timestamptz default now()
);

create table if not exists car_subscriptions (
  id uuid primary key default gen_random_uuid(),
  car_number text not null,
  car_details text,
  customer_name text,
  customer_phone text,
  status text default 'active',
  subscription_duration_months integer,
  subscription_frequency_days integer,
  created_at timestamptz default now()
);

create table if not exists maintenance_appointments (
  id uuid primary key default gen_random_uuid(),
  subscription_id uuid not null references car_subscriptions(id) on delete cascade,
  appointment_date date not null,
  description text,
  report text,
  cost numeric default 0,
  status text default 'pending',
  is_reminded boolean default false,
  created_at timestamptz default now()
);

create table if not exists purchase_invoices (
  id uuid default gen_random_uuid() primary key,
  invoice_number text not null,
  supplier_id uuid references suppliers(id) on delete set null,
  total numeric not null default 0,
  paid_amount numeric default 0,
  paid_cash numeric default 0,
  paid_visa numeric default 0,
  paid_wallet numeric default 0,
  paid_instapay numeric default 0,
  payment_method text default 'cash',
  created_at timestamptz default now()
);

create table if not exists purchase_items (
  id uuid default gen_random_uuid() primary key,
  invoice_id uuid references purchase_invoices(id) on delete cascade,
  product_id uuid references products(id) on delete set null,
  quantity numeric not null default 1,
  purchase_price numeric not null default 0
);

create table if not exists orders (
  id text primary key,
  total numeric not null default 0,
  paid_amount numeric default 0,
  paid_cash numeric default 0,
  paid_visa numeric default 0,
  paid_wallet numeric default 0,
  paid_instapay numeric default 0,
  payment_method text default 'cash',
  refund_method text,
  type text default 'sale',
  customer_id uuid references customers(id) on delete set null,
  cashier_name text,
  car_id uuid references car_subscriptions(id) on delete set null,
  coupon_code text,
  discount_amount numeric default 0,
  is_deleted boolean not null default false,
  deleted_at timestamptz,
  deletion_reason text,
  notes text,
  created_at timestamptz default now()
);
create index if not exists idx_orders_is_deleted on orders(is_deleted);
create index if not exists idx_orders_deleted_at on orders(deleted_at);

create table if not exists invoice_counter (
  id int primary key default 1,
  current_value integer default 1,
  check (id = 1)
);
insert into invoice_counter (id, current_value) values (1, 1)
on conflict (id) do nothing;

create table if not exists order_items (
  id uuid default gen_random_uuid() primary key,
  order_id text references orders(id) on delete cascade,
  product_id uuid references products(id) on delete set null,
  product_name text not null,
  barcode text,
  quantity numeric default 1,
  returned_quantity numeric default 0,
  refunded_amount numeric default 0,
  sale_price numeric default 0,
  purchase_price numeric default 0
);

create table if not exists expenses (
  id uuid default gen_random_uuid() primary key,
  category text not null,
  amount numeric not null default 0,
  note text,
  payment_method text default 'cash',
  paid_cash numeric default 0,
  paid_visa numeric default 0,
  paid_wallet numeric default 0,
  paid_instapay numeric default 0,
  car_id uuid references car_subscriptions(id) on delete set null,
  created_at timestamptz default now()
);

create table if not exists financing_accounts (
  id uuid default gen_random_uuid() primary key,
  type text not null default 'loan',
  lender_name text not null,
  lender_phone text default '',
  lender_details text default '',
  description text default '',
  principal_amount numeric not null default 0,
  collection_amount numeric not null default 0,
  collection_date date not null,
  installment_count integer not null default 1,
  status text not null default 'open',
  created_at timestamptz default now()
);

create table if not exists financing_payments (
  id uuid default gen_random_uuid() primary key,
  account_id uuid references financing_accounts(id) on delete cascade,
  payment_type text not null,
  due_date date not null,
  amount numeric not null default 0,
  paid_amount numeric not null default 0,
  remaining_amount numeric not null default 0,
  status text not null default 'pending',
  paid_at timestamptz,
  expense_id uuid references expenses(id) on delete set null,
  note text,
  created_at timestamptz default now()
);

create table if not exists financing_transactions (
  id uuid default gen_random_uuid() primary key,
  account_id uuid references financing_accounts(id) on delete cascade,
  payment_id uuid references financing_payments(id) on delete cascade,
  transaction_type text not null,
  amount numeric not null default 0,
  remaining_after numeric not null default 0,
  payment_method text not null default 'cash',
  expense_id uuid references expenses(id) on delete set null,
  note text,
  created_at timestamptz default now()
);

create table if not exists cashiers (
  id uuid default gen_random_uuid() primary key,
  name text not null,
  password text,
  phone text,
  photo_url text,
  email text,
  created_at timestamptz default now()
);

create table if not exists employees (
  id uuid default gen_random_uuid() primary key,
  name text not null,
  job_title text,
  phone text,
  working_hours text,
  monthly_salary numeric default 0,
  annual_leave_balance numeric not null default 0,
  hire_date date default current_date,
  is_active boolean not null default true,
  cashier_id uuid,
  commission_rate numeric default 0,
  created_at timestamptz default now()
);
create index if not exists idx_employees_is_active on employees(is_active);

create table if not exists employee_transactions (
  id uuid default gen_random_uuid() primary key,
  employee_id uuid references employees(id) on delete cascade,
  amount numeric not null,
  type text check (type in ('salary', 'advance', 'incentive')),
  payment_method text default 'cash',
  paid_cash numeric default 0,
  paid_visa numeric default 0,
  paid_wallet numeric default 0,
  paid_instapay numeric default 0,
  deductions numeric default 0,
  month text,
  note text,
  created_at timestamptz default now()
);

create table if not exists employee_leaves (
  id uuid default gen_random_uuid() primary key,
  employee_id uuid references employees(id) on delete cascade,
  start_date date not null,
  end_date date not null,
  days_count numeric not null default 1,
  leave_type text not null check (leave_type in ('paid', 'unpaid')),
  deduction_amount numeric not null default 0,
  month text,
  note text,
  created_at timestamptz default now()
);
create index if not exists idx_employee_leaves_employee_id on employee_leaves(employee_id);
create index if not exists idx_employee_leaves_month on employee_leaves(month);
create index if not exists idx_employee_leaves_start_date on employee_leaves(start_date);

create table if not exists product_suggestions (
  id uuid default gen_random_uuid() primary key,
  name text not null,
  notes text,
  is_purchased boolean default false,
  created_at timestamptz default now()
);

create table if not exists cashier_notes (
  id uuid default gen_random_uuid() primary key,
  cashier_name text not null,
  note text not null,
  is_read boolean default false,
  created_at timestamptz default now()
);

create table if not exists coupons (
  id uuid default gen_random_uuid() primary key,
  code text not null unique,
  discount_type text not null default 'percentage' check (discount_type in ('percentage','fixed')),
  discount_value numeric not null default 0,
  start_date timestamptz,
  end_date timestamptz,
  max_uses_per_customer integer,
  max_uses_total integer,
  used_count integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz default now()
);

-- ============================================================
-- 2) تفعيل RLS + سياسات مفتوحة (تُقفل لاحقاً بـ secure_rls_migration.sql)
-- ============================================================
do $$
declare t text;
begin
  foreach t in array array[
    'store_settings','categories','products','customers','suppliers',
    'car_subscriptions','maintenance_appointments','purchase_invoices','purchase_items',
    'orders','invoice_counter','order_items','expenses',
    'financing_accounts','financing_payments','financing_transactions',
    'cashiers','employees','employee_transactions','employee_leaves',
    'product_suggestions','cashier_notes','coupons'
  ]
  loop
    execute format('alter table %I enable row level security;', t);
    if not exists (
      select 1 from pg_policies where schemaname = 'public' and tablename = t and policyname = 'allow all'
    ) then
      execute format('create policy "allow all" on %I for all using (true) with check (true);', t);
    end if;
  end loop;
end $$;

do $$
begin
  begin execute 'alter publication supabase_realtime add table car_subscriptions'; exception when others then null; end;
  begin execute 'alter publication supabase_realtime add table maintenance_appointments'; exception when others then null; end;
end $$;

-- ============================================================
-- 3) بيانات أولية: إعدادات المتجر + تصنيفات ملابس فقط (بدون منتجات)
-- ============================================================

insert into store_settings (name, currency, tax_rate, theme_color, initial_balance)
select 'ADRIA', 'ج.م', 0, '#4f46e5', 0
where not exists (select 1 from store_settings);

insert into categories (name) values
  ('رجالي'),
  ('حريمي'),
  ('أطفالي'),
  ('أحذية'),
  ('شنط وإكسسوارات'),
  ('ملابس داخلية'),
  ('ملابس رياضية'),
  ('شتوي وجاكيتات')
on conflict do nothing;

-- ============================================================
-- تم. كل الجداول جاهزة + 8 تصنيفات ملابس، بدون أي منتجات.
-- ============================================================


-- ========================= 02_login_rpc.sql =========================
-- =============================================================================
-- POS LOGIN DATA RPC  (run AFTER secure_rls_migration.sql)
-- =============================================================================
-- After the RLS lockdown, the cashier login screen can no longer read the
-- `cashiers` table with the anon key — so the "choose your name" dropdown is
-- empty and cashiers cannot log in.
--
-- This SECURITY DEFINER function exposes ONLY what the login screen needs:
--   * basic store branding (name / logo / colour / currency)
--   * each cashier's id, name, and login email  (NO passwords)
-- It is the only cashier data anon can see. Safe to run more than once.
-- =============================================================================

create or replace function public.get_pos_login_data()
returns jsonb
language sql
security definer
set search_path = public
as $$
  select jsonb_build_object(
    'settings', (
      select jsonb_build_object(
        'name', s.name, 'currency', s.currency,
        'logo', s.logo, 'theme_color', s.theme_color
      )
      from store_settings s limit 1
    ),
    'cashiers', (
      select coalesce(
        jsonb_agg(jsonb_build_object('id', c.id, 'name', c.name, 'email', c.email)
                  order by c.created_at desc),
        '[]'::jsonb)
      from cashiers c
    )
  );
$$;

revoke all on function public.get_pos_login_data() from public;
grant execute on function public.get_pos_login_data() to anon, authenticated;


-- ========================= 03_refund_method.sql =========================
-- Stores the payment method the cashier used to refund a return
-- (cash / visa / wallet / instapay) so the treasury attributes the cash
-- outflow to the correct method. Safe, nullable, run once on each project.
alter table orders add column if not exists refund_method text;


-- ========================= 04_manufacturing.sql =========================
-- ============================================================
-- ADRIA — موديول التصنيع (خامات + أوامر تصنيع)
-- شغّله مرة واحدة على قاعدة البيانات.
-- ============================================================

-- لون المنتج (للملابس)
alter table products add column if not exists color text;

-- الخامات (أقمشة، خيوط، أزرار... إلخ)
create table if not exists materials (
  id uuid default gen_random_uuid() primary key,
  name text not null,
  unit text not null default 'متر',
  cost_per_unit numeric not null default 0,
  stock_quantity numeric not null default 0,
  created_at timestamptz default now()
);

-- أوامر التصنيع (دفعة إنتاج)
create table if not exists production_orders (
  id uuid default gen_random_uuid() primary key,
  product_id uuid references products(id) on delete set null,
  product_name text not null,
  color text,
  code text,
  quantity numeric not null default 0,
  materials_cost numeric not null default 0,
  extra_costs numeric not null default 0,
  total_cost numeric not null default 0,
  cost_per_piece numeric not null default 0,
  sale_price numeric not null default 0,
  notes text,
  created_at timestamptz default now()
);

-- الخامات المستهلكة في كل أمر تصنيع
create table if not exists production_materials (
  id uuid default gen_random_uuid() primary key,
  production_id uuid references production_orders(id) on delete cascade,
  material_id uuid references materials(id) on delete set null,
  material_name text,
  quantity numeric not null default 0,
  cost numeric not null default 0
);

-- RLS مفتوح مؤقتاً (يُقفل بـ secure_rls_migration.sql لاحقاً)
do $$
declare t text;
begin
  foreach t in array array['materials','production_orders','production_materials']
  loop
    execute format('alter table %I enable row level security;', t);
    if not exists (
      select 1 from pg_policies where schemaname = 'public' and tablename = t and policyname = 'allow all'
    ) then
      execute format('create policy "allow all" on %I for all using (true) with check (true);', t);
    end if;
  end loop;
end $$;


-- ========================= 05_product_discount.sql =========================
-- ADRIA — سعر البيع بعد الخصم للمنتجات. شغّله مرة واحدة.
alter table products add column if not exists discount_price numeric default 0;


-- ========================= 06_inventory_locations.sql =========================
-- ADRIA — تقسيم المخزون: مستودع + معرض.
-- stock_quantity = الإجمالي (زي ما هو). display_quantity = الكمية المعروضة في المحل.
-- المستودع = الإجمالي - المعروض. شغّله مرة واحدة.
alter table products add column if not exists display_quantity numeric default 0;


-- ========================= 07_seasons_wholesale.sql =========================
-- ADRIA — تصنيف موسمي + أسعار الجملة. شغّله مرة واحدة.
alter table products add column if not exists season text;                       -- 'summer' / 'winter'
alter table products add column if not exists wholesale_price numeric default 0;      -- سعر الجملة
alter table products add column if not exists half_wholesale_price numeric default 0; -- سعر نص الجملة


-- ========================= 08_public_invoice_prices.sql =========================
-- ADRIA — adds product sale_price + discount_price to the public-invoice RPC
-- so the e-invoice can show the price before & after discount. Run once.
create or replace function public.get_public_invoice(p_id text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_settings jsonb;
  v_order jsonb;
  v_customer_id uuid;
  v_customer_orders jsonb := '[]'::jsonb;
  v_appointment jsonb;
  v_subscription_id uuid;
  v_appointment_orders jsonb := '[]'::jsonb;
  v_purchase jsonb;
begin
  select jsonb_build_object(
           'name', s.name, 'currency', s.currency, 'logo', s.logo,
           'tax_rate', s.tax_rate, 'theme_color', s.theme_color,
           'address', s.address, 'phone', s.phone, 'phone2', s.phone2,
           'whatsapp_country_code', s.whatsapp_country_code,
           'initial_balance', s.initial_balance, 'location_url', s.location_url
         )
    into v_settings
  from store_settings s limit 1;

  select to_jsonb(o) || jsonb_build_object(
           'customers', (select to_jsonb(c) from customers c where c.id = o.customer_id),
           'order_items', (
             select coalesce(jsonb_agg(to_jsonb(oi) || jsonb_build_object(
                      'products', (select jsonb_build_object('name', p.name, 'sale_price', p.sale_price, 'discount_price', p.discount_price) from products p where p.id = oi.product_id)
                    )), '[]'::jsonb)
             from order_items oi where oi.order_id = o.id
           )
         ), o.customer_id
    into v_order, v_customer_id
  from orders o where o.id = p_id;

  if v_order is not null then
    if v_customer_id is not null then
      select coalesce(jsonb_agg(
               to_jsonb(o2) || jsonb_build_object(
                 'order_items', (
                   select coalesce(jsonb_agg(jsonb_build_object(
                            'quantity', oi.quantity, 'sale_price', oi.sale_price,
                            'returned_quantity', oi.returned_quantity, 'refunded_amount', oi.refunded_amount
                          )), '[]'::jsonb)
                   from order_items oi where oi.order_id = o2.id
                 )
               )
             ), '[]'::jsonb)
        into v_customer_orders
      from orders o2
      where o2.customer_id = v_customer_id and o2.is_deleted = false;
    end if;
    return jsonb_build_object('kind', 'order', 'settings', v_settings,
                             'order', v_order, 'customer_orders', v_customer_orders);
  end if;

  if to_regclass('public.maintenance_appointments') is not null then
    select to_jsonb(a) || jsonb_build_object(
             'car_subscriptions', (select to_jsonb(cs) from car_subscriptions cs where cs.id = a.subscription_id)
           ), a.subscription_id
      into v_appointment, v_subscription_id
    from maintenance_appointments a where a.id = p_id;
    if v_appointment is not null then
      select coalesce(jsonb_agg(
               to_jsonb(o) || jsonb_build_object(
                 'order_items', (
                   select coalesce(jsonb_agg(to_jsonb(oi) || jsonb_build_object(
                            'products', (select jsonb_build_object('name', p.name, 'sale_price', p.sale_price, 'discount_price', p.discount_price) from products p where p.id = oi.product_id)
                          )), '[]'::jsonb)
                   from order_items oi where oi.order_id = o.id
                 )
               )
             ), '[]'::jsonb)
        into v_appointment_orders
      from orders o where o.car_id = v_subscription_id and o.is_deleted = false;
      return jsonb_build_object('kind', 'maintenance', 'settings', v_settings,
                               'appointment', v_appointment, 'appointment_orders', v_appointment_orders);
    end if;
  end if;

  select to_jsonb(pi) || jsonb_build_object(
           'suppliers', (select to_jsonb(su) from suppliers su where su.id = pi.supplier_id),
           'purchase_items', (
             select coalesce(jsonb_agg(to_jsonb(it) || jsonb_build_object(
                      'products', (select jsonb_build_object('name', p.name, 'sale_price', p.sale_price, 'discount_price', p.discount_price) from products p where p.id = it.product_id)
                    )), '[]'::jsonb)
             from purchase_items it where it.invoice_id = pi.id
           )
         )
    into v_purchase
  from purchase_invoices pi
  where pi.id::text = p_id or pi.invoice_number::text = p_id limit 1;

  if v_purchase is not null then
    return jsonb_build_object('kind', 'purchase', 'settings', v_settings, 'purchase', v_purchase);
  end if;

  return null;
end;
$$;

revoke all on function public.get_public_invoice(text) from public;
grant execute on function public.get_public_invoice(text) to anon, authenticated;


-- ========================= 09_cashier_employee_commission.sql =========================
-- ADRIA — ربط الكاشير بملف موظف + عمولة المبيعات. شغّله مرة واحدة.
alter table employees add column if not exists cashier_id uuid;
alter table employees add column if not exists commission_rate numeric default 0;


-- ========================= 10_manager_withdrawals.sql =========================
-- ADRIA — قائمة المدراء (سحوبات المدير تُسجّل كمصروف category='سحب مدير'). شغّله مرة واحدة.
-- (آمن لإعادة التشغيل — يقفل الجدول على المستخدم المسجّل فقط.)
create table if not exists managers (
  id uuid default gen_random_uuid() primary key,
  name text not null,
  created_at timestamptz default now()
);

-- قفل الجدول على المستخدم المسجّل فقط (نفس سياسة باقي الجداول بعد التأمين).
alter table managers enable row level security;
drop policy if exists "allow all" on managers;
drop policy if exists "authenticated full access" on managers;
create policy "authenticated full access" on managers for all to authenticated using (true) with check (true);
revoke all on managers from anon;
grant all on managers to authenticated;


-- ========================= 11_fix_public_invoice_uuid.sql =========================
-- ADRIA — إصلاح فتح فاتورة الشراء من لينك التليجرام.
-- المشكلة: get_public_invoice كانت بتقارن maintenance_appointments.id (uuid) = p_id (text)
-- فبترمي خطأ "operator does not exist: uuid = text" مع أي id مش order → اللينك مبيفتحش.
-- الحل: cast كل المقارنات لـ ::text. شغّله مرة واحدة.
create or replace function public.get_public_invoice(p_id text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_settings jsonb;
  v_order jsonb;
  v_customer_id uuid;
  v_customer_orders jsonb := '[]'::jsonb;
  v_appointment jsonb;
  v_subscription_id uuid;
  v_appointment_orders jsonb := '[]'::jsonb;
  v_purchase jsonb;
begin
  select jsonb_build_object(
           'name', s.name, 'currency', s.currency, 'logo', s.logo,
           'tax_rate', s.tax_rate, 'theme_color', s.theme_color,
           'address', s.address, 'phone', s.phone, 'phone2', s.phone2,
           'whatsapp_country_code', s.whatsapp_country_code,
           'initial_balance', s.initial_balance, 'location_url', s.location_url
         )
    into v_settings
  from store_settings s
  limit 1;

  -- (a) Sale order
  select to_jsonb(o) || jsonb_build_object(
           'customers', (select to_jsonb(c) from customers c where c.id = o.customer_id),
           'order_items', (
             select coalesce(jsonb_agg(to_jsonb(oi) || jsonb_build_object(
                      'products', (select jsonb_build_object('name', p.name, 'sale_price', p.sale_price, 'discount_price', p.discount_price) from products p where p.id = oi.product_id)
                    )), '[]'::jsonb)
             from order_items oi where oi.order_id = o.id
           )
         ), o.customer_id
    into v_order, v_customer_id
  from orders o where o.id::text = p_id;

  if v_order is not null then
    if v_customer_id is not null then
      select coalesce(jsonb_agg(
               to_jsonb(o2) || jsonb_build_object(
                 'order_items', (
                   select coalesce(jsonb_agg(jsonb_build_object(
                            'quantity', oi.quantity, 'sale_price', oi.sale_price,
                            'returned_quantity', oi.returned_quantity, 'refunded_amount', oi.refunded_amount
                          )), '[]'::jsonb)
                   from order_items oi where oi.order_id = o2.id
                 )
               )
             ), '[]'::jsonb)
        into v_customer_orders
      from orders o2
      where o2.customer_id = v_customer_id and o2.is_deleted = false;
    end if;

    return jsonb_build_object('kind', 'order', 'settings', v_settings,
                             'order', v_order, 'customer_orders', v_customer_orders);
  end if;

  -- (b) Maintenance appointment
  if to_regclass('public.maintenance_appointments') is not null then
    select to_jsonb(a) || jsonb_build_object(
             'car_subscriptions', (select to_jsonb(cs) from car_subscriptions cs where cs.id = a.subscription_id)
           ), a.subscription_id
      into v_appointment, v_subscription_id
    from maintenance_appointments a where a.id::text = p_id;

    if v_appointment is not null then
      select coalesce(jsonb_agg(
               to_jsonb(o) || jsonb_build_object(
                 'order_items', (
                   select coalesce(jsonb_agg(to_jsonb(oi) || jsonb_build_object(
                            'products', (select jsonb_build_object('name', p.name, 'sale_price', p.sale_price, 'discount_price', p.discount_price) from products p where p.id = oi.product_id)
                          )), '[]'::jsonb)
                   from order_items oi where oi.order_id = o.id
                 )
               )
             ), '[]'::jsonb)
        into v_appointment_orders
      from orders o
      where o.car_id = v_subscription_id and o.is_deleted = false;

      return jsonb_build_object('kind', 'maintenance', 'settings', v_settings,
                               'appointment', v_appointment, 'appointment_orders', v_appointment_orders);
    end if;
  end if;

  -- (c) Purchase invoice (by id or invoice_number)
  select to_jsonb(pi) || jsonb_build_object(
           'suppliers', (select to_jsonb(su) from suppliers su where su.id = pi.supplier_id),
           'purchase_items', (
             select coalesce(jsonb_agg(to_jsonb(it) || jsonb_build_object(
                      'products', (select jsonb_build_object('name', p.name, 'sale_price', p.sale_price, 'discount_price', p.discount_price) from products p where p.id = it.product_id)
                    )), '[]'::jsonb)
             from purchase_items it where it.invoice_id = pi.id
           )
         )
    into v_purchase
  from purchase_invoices pi
  where pi.id::text = p_id or pi.invoice_number::text = p_id
  limit 1;

  if v_purchase is not null then
    return jsonb_build_object('kind', 'purchase', 'settings', v_settings, 'purchase', v_purchase);
  end if;

  return null;
end;
$$;

revoke all on function public.get_public_invoice(text) from public;
grant execute on function public.get_public_invoice(text) to anon, authenticated;


-- ========================= 13_manufacturing_supplier_factory.sql =========================
-- ADRIA — التصنيع: ربط الخامة بمورد + مخزن المصنع للمنتجات. شغّله مرة واحدة.
alter table materials add column if not exists supplier_id uuid;
alter table products add column if not exists factory_quantity numeric default 0;


-- ========================= 14_otp_and_salesperson.sql =========================
-- ADRIA — (1) رموز OTP لفواتير الجملة/نص الجملة  (2) الموظف البائع على الفاتورة
-- شغّله مرة واحدة.

-- (1) جدول رموز التحقق — تستخدمه دالة السيرفر فقط (service role). RLS مقفول للباقي.
create table if not exists otp_codes (
  id uuid default gen_random_uuid() primary key,
  code text not null,
  purpose text default 'wholesale',
  expires_at timestamptz not null,
  used boolean default false,
  created_at timestamptz default now()
);
alter table otp_codes enable row level security;
-- لا نضيف أي policy → anon/authenticated ممنوعين تماماً؛ السيرفر بمفتاح الخدمة فقط.

-- (2) الموظف البائع على الفاتورة (لحساب مبيعاته وأرباحه للعمولة)
alter table orders add column if not exists salesperson_id uuid;
alter table orders add column if not exists salesperson_name text;


-- ========================= 15_partners.sql =========================
-- ADRIA — موديول الشركاء: نسبة كل شريك + رصيد افتتاحي + إيداع/سحب لكل شريك. شغّله مرة واحدة.

create table if not exists partners (
  id uuid default gen_random_uuid() primary key,
  name text not null,
  share_percent numeric default 0,     -- نسبة الشريك في المؤسسة %
  opening_balance numeric default 0,   -- الرصيد الافتتاحي للشريك
  created_at timestamptz default now()
);

create table if not exists partner_transactions (
  id uuid default gen_random_uuid() primary key,
  partner_id uuid not null,
  partner_name text,
  type text not null,                  -- 'deposit' (إيداع) | 'withdraw' (سحب)
  amount numeric not null,
  treasury text default 'shop',        -- 'shop' (خزنة المحل) | 'main' (الخزنة الأساسية)
  method text default 'cash',          -- cash / visa / wallet / instapay
  note text,
  created_at timestamptz default now()
);

-- قفل الجدولين على المستخدم المسجّل فقط (نفس سياسة باقي الجداول).
do $$
declare t text;
begin
  foreach t in array array['partners','partner_transactions'] loop
    execute format('alter table public.%I enable row level security;', t);
    execute format('drop policy if exists "authenticated full access" on public.%I;', t);
    execute format('create policy "authenticated full access" on public.%I for all to authenticated using (true) with check (true);', t);
    execute format('revoke all on public.%I from anon;', t);
    execute format('grant all on public.%I to authenticated;', t);
  end loop;
end $$;


-- ========================= 16_savings.sql =========================
-- ADRIA — خزنة الادخار (منفصلة عن خزنة المحل). شغّله مرة واحدة.
create table if not exists savings_transactions (
  id uuid default gen_random_uuid() primary key,
  direction text not null,   -- 'in' (تحويل من المحل للادخار) | 'out' (تحويل من الادخار للمحل)
  amount numeric not null,
  method text default 'cash',-- cash / visa / wallet / instapay  (كل طريقة تنتقل بطريقتها)
  source text,               -- 'shop_transfer' | 'day_closing' | 'to_shop' | 'manual'
  note text,
  created_at timestamptz default now()
);
alter table savings_transactions enable row level security;
drop policy if exists "authenticated full access" on savings_transactions;
create policy "authenticated full access" on savings_transactions for all to authenticated using (true) with check (true);
revoke all on savings_transactions from anon;
grant all on savings_transactions to authenticated;


-- ========================= 17_exchange.sql =========================
-- ADRIA — بيانات الاستبدال على الفاتورة (الأصناف قبل/بعد + الفرق). شغّله مرة واحدة.
alter table orders add column if not exists exchange_data jsonb;


-- ========================= 18_stock_adjustments.sql =========================
-- ADRIA — سجل تسويات الجرد. شغّله مرة واحدة.
create table if not exists stock_adjustments (
  id uuid default gen_random_uuid() primary key,
  product_id uuid,
  product_name text,
  system_qty numeric,
  counted_qty numeric,
  diff numeric,            -- counted - system (سالب = عجز، موجب = زيادة)
  cost numeric default 0,  -- تكلفة الوحدة وقت الجرد
  note text,
  created_at timestamptz default now()
);
alter table stock_adjustments enable row level security;
drop policy if exists "authenticated full access" on stock_adjustments;
create policy "authenticated full access" on stock_adjustments for all to authenticated using (true) with check (true);
revoke all on stock_adjustments from anon;
grant all on stock_adjustments to authenticated;


-- ========================= 19_settings_extras.sql =========================
-- ADRIA — صلاحيات الكاشير + تسميات وسائل الدفع (المحافظ). شغّله مرة واحدة.
alter table store_settings add column if not exists cashier_permissions jsonb;
alter table store_settings add column if not exists payment_labels jsonb;


-- ========================= 20_admin_users.sql =========================
-- ADRIA — مستخدمو لوحة التحكم بصلاحيات. شغّله مرة واحدة.
create table if not exists admin_users (
  id uuid default gen_random_uuid() primary key,
  name text not null,
  password text,
  email text,
  permissions jsonb default '[]'::jsonb,  -- مصفوفة مسارات الصفحات المسموح بها
  created_at timestamptz default now()
);
alter table admin_users enable row level security;
drop policy if exists "authenticated full access" on admin_users;
create policy "authenticated full access" on admin_users for all to authenticated using (true) with check (true);
revoke all on admin_users from anon;
grant all on admin_users to authenticated;

-- قائمة الدخول (بدون كلمة السر) — يستخدمها anon في شاشة الدخول لاختيار المستخدم.
create or replace function public.get_admin_login_data()
returns jsonb language sql security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', id, 'name', name, 'email', email, 'permissions', permissions) order by name), '[]'::jsonb)
  from admin_users;
$$;
revoke all on function public.get_admin_login_data() from public;
grant execute on function public.get_admin_login_data() to anon, authenticated;


-- ========================= 21_show_profit.sql =========================
-- ADRIA — إظهار/إخفاء ربح الفاتورة في شاشة الكاشير. شغّله مرة واحدة.
alter table store_settings add column if not exists show_invoice_profit boolean default true;


-- ========================= 22_cashier_employee_advance.sql =========================
-- ADRIA — السماح للكاشير بصرف سلف للموظفين (تُخصم من راتب الشهر). شغّله مرة واحدة.
-- الافتراضي مغلق؛ يُفعّل من إعدادات النظام > صلاحيات الكاشير.
alter table store_settings add column if not exists allow_cashier_employee_advance boolean default false;


-- ========================= 23_qz_direct_printing.sql =========================
-- ADRIA — الطباعة المباشرة عبر QZ Tray.
-- لا حاجة لقاعدة البيانات: إعداد الطابعات أصبح محلياً على كل جهاز (localStorage)
-- لأن أسماء الطابعات تختلف من جهاز لآخر. هذا الملف مُبقى فارغاً للتوثيق فقط.
-- (لو سبق وأضفت الأعمدة qz_* فهي غير مستخدمة ولا ضرر منها.)


-- ========================= 24_payment_methods_5_6.sql =========================
-- ADRIA — طريقتا دفع إضافيتان (5 و6) لكل منهما حسابها الخاص في الخزنة.
-- يضيف عمودي المبلغ المدفوع لكل طريقة على كل الجداول المالية. شغّله مرة واحدة.
-- (الجداول التي تخزّن الطريقة كنص واحد مثل savings_transactions/partner_transactions
--  لا تحتاج أعمدة جديدة — تقبل القيم method5/method6 مباشرةً.)

-- إعدادات: تفعيل طرق الدفع الإضافية (التسميات تُخزّن في payment_labels الموجود مسبقاً)
alter table store_settings          add column if not exists payment_methods_enabled jsonb;

alter table orders                  add column if not exists paid_method5 numeric default 0;
alter table orders                  add column if not exists paid_method6 numeric default 0;

alter table expenses                add column if not exists paid_method5 numeric default 0;
alter table expenses                add column if not exists paid_method6 numeric default 0;

alter table purchase_invoices       add column if not exists paid_method5 numeric default 0;
alter table purchase_invoices       add column if not exists paid_method6 numeric default 0;

alter table employee_transactions   add column if not exists paid_method5 numeric default 0;
alter table employee_transactions   add column if not exists paid_method6 numeric default 0;

alter table financing_payments      add column if not exists paid_method5 numeric default 0;
alter table financing_payments      add column if not exists paid_method6 numeric default 0;

alter table financing_transactions  add column if not exists paid_method5 numeric default 0;
alter table financing_transactions  add column if not exists paid_method6 numeric default 0;


-- ========================= 25_held_invoices.sql =========================
-- =============================================================================
-- HELD / RESERVED INVOICES  (فواتير معلقة / محجوزة)
-- =============================================================================
--  A held invoice reserves stock without recording a sale. From the cashier the
--  staff can later either:
--    * تأكيد البيع  → load it back into the cart and complete a normal sale, or
--    * إرجاع للمخزون → cancel it and return the reserved quantities to stock.
--  Any held invoice not actioned within 7 days is automatically returned to
--  stock (client-side sweep on app load + a daily Vercel cron — see
--  /api/expire-held-invoices).
--
--  Stock is deducted from products.stock_quantity at the moment of holding and
--  added back on return/expiry, so the available quantity always reflects the
--  reservation.
--
--  This script is idempotent — safe to run more than once.
-- =============================================================================

create table if not exists public.held_invoices (
  id uuid primary key default gen_random_uuid(),
  customer_name text,
  customer_phone text,
  customer_custom_id text,
  items jsonb not null default '[]'::jsonb,
  total numeric not null default 0,
  invoice_type text not null default 'retail',
  salesperson_id uuid,
  salesperson_name text,
  cashier_name text,
  notes text,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '7 days')
);

create index if not exists idx_held_invoices_expires_at on public.held_invoices(expires_at);
create index if not exists idx_held_invoices_created_at on public.held_invoices(created_at);

-- RLS: authenticated staff only (matches secure_rls_migration.sql).
alter table public.held_invoices enable row level security;
drop policy if exists "allow all" on public.held_invoices;
drop policy if exists "authenticated full access" on public.held_invoices;
create policy "authenticated full access" on public.held_invoices
  for all to authenticated using (true) with check (true);
revoke all on public.held_invoices from anon;
grant all on public.held_invoices to authenticated;
