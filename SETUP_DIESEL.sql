-- ============================================================================
-- DIESEL Barbershop — إعداد قاعدة البيانات كاملة من الصفر (ملف واحد)
-- شغّله مرة واحدة بالكامل في: Supabase → SQL Editor → New query → Run
--
-- ⚠️  الـ SQL لوحده مش كفاية — التطبيق بيسجّل دخول بـ Supabase Auth
--     (signInWithPassword)، فلازم تعمل مستخدم Auth بعد كده وإلا مش هتقدر تدخل:
--         node scripts/provision_auth_users.cjs
--     الترتيب الكامل في SECURITY_SETUP.md.
--
--  الجداول القديمة بتتعمل بصلاحيات RLS مفتوحة (allow all) عشان التطبيق يشتغل
--  فورًا، والجداول الأحدث (held_invoices / installments / quotations /
--  attendance) بتقفل نفسها على authenticated من أول لحظة — ودي شغالة عادي لأن
--  التطبيق بيدخل كـ authenticated.
--  لتشديد الباقي: شغّل db/secure_rls_migration.sql بعد ما تتأكد إن الدخول شغال.
--
-- ⚠️  مولّد آليًا — لا تعدّله بالإيد.
--     أضف ميجريشن في db/ ثم شغّل: node scripts/build_setup_sql.cjs
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


-- ========================= 00_fresh_setup_extras.sql =========================
-- =============================================================================
-- ADRIA — schema extras for a FRESH database.
-- Run this AFTER setup_new_database.sql. It adds every column/table the app
-- needs that the base file may be missing. Idempotent — safe to run again.
-- =============================================================================

-- Customers ------------------------------------------------------------------
alter table customers add column if not exists card_number text;

-- Products: units + fractional (weight) quantities -------------------------
alter table products add column if not exists unit text not null default 'قطعة';
alter table products alter column stock_quantity type numeric using stock_quantity::numeric;
alter table purchase_items alter column quantity type numeric using quantity::numeric;
alter table order_items alter column quantity type numeric using quantity::numeric;
alter table order_items alter column returned_quantity type numeric using returned_quantity::numeric;

-- Order items: refunded cash per item --------------------------------------
alter table order_items add column if not exists refunded_amount numeric default 0;
update order_items set refunded_amount = 0 where refunded_amount is null;

-- Orders: payment method, soft-delete, car link, refund method -------------
alter table orders add column if not exists payment_method text default 'cash';
alter table orders add column if not exists refund_method text;
alter table orders add column if not exists car_id uuid references car_subscriptions(id) on delete set null;
alter table orders add column if not exists is_deleted boolean not null default false;
alter table orders add column if not exists deleted_at timestamptz;
alter table orders add column if not exists deletion_reason text;
create index if not exists idx_orders_is_deleted on orders(is_deleted);
create index if not exists idx_orders_deleted_at on orders(deleted_at);

-- Store settings: opening balance ------------------------------------------
alter table store_settings add column if not exists initial_balance numeric default 0;
alter table store_settings add column if not exists allow_cashier_employee_advance boolean default false;

-- Purchase invoices: payment method ----------------------------------------
alter table purchase_invoices add column if not exists payment_method text default 'cash';

-- Expenses: payment split + car link ---------------------------------------
alter table expenses add column if not exists paid_cash      numeric default 0;
alter table expenses add column if not exists paid_visa      numeric default 0;
alter table expenses add column if not exists paid_wallet    numeric default 0;
alter table expenses add column if not exists paid_instapay  numeric default 0;
alter table expenses add column if not exists payment_method text default 'cash';
alter table expenses add column if not exists car_id uuid references car_subscriptions(id) on delete set null;

-- Car subscriptions: status + subscription terms ---------------------------
alter table car_subscriptions add column if not exists status text default 'active';
alter table car_subscriptions add column if not exists subscription_duration_months integer;
alter table car_subscriptions add column if not exists subscription_frequency_days integer;

-- Employees: phone, status, leave balance, hire date -----------------------
alter table employees add column if not exists phone text;
alter table employees add column if not exists is_active boolean not null default true;
alter table employees add column if not exists annual_leave_balance numeric not null default 0;
alter table employees add column if not exists hire_date date default current_date;
create index if not exists idx_employees_is_active on employees(is_active);

-- Employee transactions: deductions + incentive type -----------------------
alter table employee_transactions add column if not exists deductions numeric default 0;
alter table employee_transactions drop constraint if exists employee_transactions_type_check;
alter table employee_transactions
  add constraint employee_transactions_type_check
  check (type in ('salary', 'advance', 'incentive'));

-- Cashiers: login email (for Supabase Auth) --------------------------------
alter table cashiers add column if not exists email text;


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


-- ========================= 26_product_image.sql =========================
-- صورة المنتج: تُخزَّن كـ Data URL مضغوط (ثمبنيل) وتظهر في الكاشير.
-- شغّله مرة واحدة في Supabase → SQL Editor قبل استخدام رفع الصور.
alter table products add column if not exists image_url text;


-- ========================= 27_installments.sql =========================
-- ═══════════════════════════════════════════════════════════════════════════
-- التقسيط: خطة تقسيط لكل فاتورة آجل + جدول دفعات (أقساط) بتواريخ استحقاق.
-- التحصيل بيمرّ على منطق «سداد أجل» الموجود (payInvoiceDebt) فيتحسب في المالية
-- والإحصائيات تلقائياً. الفايدة بتتضاف لإجمالي الفاتورة (إيراد).
-- شغّله مرة واحدة في Supabase → SQL Editor.
-- ═══════════════════════════════════════════════════════════════════════════

create table if not exists installment_plans (
  id uuid primary key default gen_random_uuid(),
  order_id text references orders(id) on delete cascade,
  customer_id uuid references customers(id) on delete set null,
  goods_total numeric not null default 0,      -- إجمالي البضاعة قبل الفايدة
  down_payment numeric not null default 0,      -- المقدم
  financed_amount numeric not null default 0,   -- الممول = goods_total − down_payment
  interest_type text not null default 'none',   -- 'none' | 'percent' | 'fixed'
  interest_value numeric not null default 0,    -- النسبة % أو المبلغ المُدخَل
  interest_amount numeric not null default 0,   -- الفايدة المحسوبة فعلياً
  total_due numeric not null default 0,         -- financed_amount + interest_amount = مجموع الأقساط
  installments_count int not null default 1,
  interval_type text not null default 'monthly',-- 'monthly' | 'quarterly' | 'custom'
  interval_days int,                            -- عدد الأيام لو interval_type='custom'
  status text not null default 'active',        -- 'active' | 'completed'
  note text,
  created_at timestamptz default now()
);

create table if not exists installments (
  id uuid primary key default gen_random_uuid(),
  plan_id uuid references installment_plans(id) on delete cascade,
  order_id text,
  customer_id uuid,
  seq int not null,                             -- رقم القسط (1..N)
  due_date date not null,                       -- تاريخ الاستحقاق
  amount numeric not null default 0,
  paid boolean not null default false,
  paid_amount numeric not null default 0,
  paid_at timestamptz,
  payment_order_id text,                        -- أوردر السداد اللي اتعمل عند التحصيل
  notified boolean not null default false,      -- اتبعت رسالة التذكير قبل يومين
  created_at timestamptz default now()
);

create index if not exists idx_installments_plan on installments(plan_id);
create index if not exists idx_installments_due on installments(due_date) where paid = false;
create index if not exists idx_installment_plans_customer on installment_plans(customer_id);

-- RLS + الصلاحيات (زي باقي جداول النظام: أي مستخدم مصادق له كل الصلاحيات).
do $$
declare t text;
begin
  foreach t in array array['installment_plans','installments'] loop
    execute format('alter table public.%I enable row level security;', t);
    execute format('grant all on public.%I to authenticated;', t);
    if not exists (select 1 from pg_policies where schemaname='public' and tablename=t and policyname='authenticated full access') then
      execute format('create policy "authenticated full access" on public.%I for all to authenticated using (true) with check (true);', t);
    end if;
  end loop;
end $$;


-- ========================= 28_quotations.sql =========================
-- عروض الأسعار (Quotations): تُنشأ من السلة بدون خصم مخزون ولا بيع.
-- تُحفظ وتُطبع كخطاب A4 بلوجو وبيانات الشركة وQR بتفاصيل العرض.
-- شغّله مرة واحدة في Supabase → SQL Editor.
create table if not exists quotations (
  id uuid primary key default gen_random_uuid(),
  quotation_number text,
  recipient_company text,
  recipient_phone text,
  intro_text text,          -- مقدمة الخطاب
  notes text,               -- ملاحظات
  execution_period text,    -- مدة التنفيذ
  items jsonb not null default '[]'::jsonb,  -- [{name, quantity, unit_price, total}]
  subtotal numeric not null default 0,
  discount numeric not null default 0,
  total numeric not null default 0,
  cashier_name text,
  created_at timestamptz default now()
);

create index if not exists idx_quotations_created on quotations(created_at desc);

do $$ begin
  execute 'alter table public.quotations enable row level security';
  execute 'grant all on public.quotations to authenticated';
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='quotations' and policyname='authenticated full access') then
    execute 'create policy "authenticated full access" on public.quotations for all to authenticated using (true) with check (true)';
  end if;
end $$;


-- ========================= 29_quotations_storage.sql =========================
-- تخزين ملفات عروض الأسعار PDF لإرسالها كرابط تحميل في الواتساب.
-- ينشئ bucket عام اسمه «quotations» + صلاحيات رفع/قراءة تعمل بمفتاح anon.
-- شغّله مرة واحدة في Supabase → SQL Editor.

-- 1) الـ bucket العام (القراءة عبر الرابط العام بدون تسجيل دخول).
insert into storage.buckets (id, name, public)
values ('quotations', 'quotations', true)
on conflict (id) do update set public = true;

-- 2) صلاحيات storage.objects على هذا الـ bucket فقط (public = anon + authenticated).
do $$ begin
  -- رفع ملف جديد
  if not exists (select 1 from pg_policies where schemaname='storage' and tablename='objects' and policyname='quotations_insert') then
    execute 'create policy "quotations_insert" on storage.objects for insert to public with check (bucket_id = ''quotations'')';
  end if;
  -- استبدال ملف موجود (upsert)
  if not exists (select 1 from pg_policies where schemaname='storage' and tablename='objects' and policyname='quotations_update') then
    execute 'create policy "quotations_update" on storage.objects for update to public using (bucket_id = ''quotations'') with check (bucket_id = ''quotations'')';
  end if;
  -- قراءة (الـ bucket عام أصلاً، لكن نضيف السياسة احتياطاً)
  if not exists (select 1 from pg_policies where schemaname='storage' and tablename='objects' and policyname='quotations_read') then
    execute 'create policy "quotations_read" on storage.objects for select to public using (bucket_id = ''quotations'')';
  end if;
end $$;


-- ========================= 30_attendance.sql =========================
-- =============================================================================
-- ATTENDANCE (تسجيل حضور وانصراف الموظفين)  — run AFTER secure_rls_migration.sql
-- =============================================================================
--  الفكرة:
--   * صفحة عامة منفصلة /attendance يستخدمها كل الموظفين (بدون تسجيل دخول للنظام).
--   * كل موظف يختار اسمه + يكتب رقمه السري (attendance_pin) ويسجّل حضور/انصراف.
--   * كل الكتابة تتم عبر دوال SECURITY DEFINER فقط (anon ماينفعش يكتب مباشرة).
--   * المدير (authenticated) يقرأ سجل الحضور من لوحة التحكم.
--
--  آمن للتشغيل أكثر من مرة (idempotent).
-- =============================================================================

-- 1) رقم سري لكل موظف لتسجيل الحضور
alter table employees add column if not exists attendance_pin text;

-- 2) جدول الحضور: صف واحد لكل موظف في اليوم (حضور + انصراف)
create table if not exists attendance (
  id uuid default gen_random_uuid() primary key,
  employee_id uuid references employees(id) on delete cascade,
  work_date date not null,
  check_in timestamptz,
  check_out timestamptz,
  created_at timestamptz default now(),
  unique (employee_id, work_date)
);

create index if not exists idx_attendance_employee on attendance(employee_id);
create index if not exists idx_attendance_work_date on attendance(work_date);

-- RLS: قراءة/إدارة للمصادَق عليهم فقط (المدير). الكتابة العامة عبر الدوال أدناه.
alter table attendance enable row level security;
drop policy if exists "authenticated full access" on attendance;
create policy "authenticated full access" on attendance
  for all to authenticated using (true) with check (true);
revoke all on attendance from anon;

-- ---------------------------------------------------------------------------
-- 3) قائمة الموظفين النشطين لصفحة الحضور (بدون كشف الرقم السري)
-- ---------------------------------------------------------------------------
create or replace function public.get_attendance_employees()
returns jsonb
language sql
security definer
set search_path = public
as $$
  select coalesce(
    jsonb_agg(
      jsonb_build_object('id', e.id, 'name', e.name, 'job_title', e.job_title)
      order by e.name
    ),
    '[]'::jsonb)
  from employees e
  where coalesce(e.is_active, true) = true;
$$;

revoke all on function public.get_attendance_employees() from public;
grant execute on function public.get_attendance_employees() to anon, authenticated;

-- ---------------------------------------------------------------------------
-- 4) حالة اليوم لموظف معيّن (لتفعيل/تعطيل زر الانصراف)
-- ---------------------------------------------------------------------------
create or replace function public.get_attendance_status(p_employee_id uuid)
returns jsonb
language sql
security definer
set search_path = public
as $$
  select coalesce(
    (select jsonb_build_object('check_in', a.check_in, 'check_out', a.check_out)
       from attendance a
      where a.employee_id = p_employee_id
        and a.work_date = (now() at time zone 'Africa/Cairo')::date),
    jsonb_build_object('check_in', null, 'check_out', null)
  );
$$;

revoke all on function public.get_attendance_status(uuid) from public;
grant execute on function public.get_attendance_status(uuid) to anon, authenticated;

-- ---------------------------------------------------------------------------
-- 5) تسجيل حضور/انصراف — يتحقق من الرقم السري ويكتب الصف
--    p_action: 'check_in' | 'check_out'
-- ---------------------------------------------------------------------------
create or replace function public.record_attendance(
  p_employee_id uuid,
  p_pin text,
  p_action text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_emp    employees%rowtype;
  v_today  date := (now() at time zone 'Africa/Cairo')::date;
  v_now    timestamptz := now();
  v_row    attendance%rowtype;
begin
  select * into v_emp from employees where id = p_employee_id;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'not_found');
  end if;
  if coalesce(v_emp.is_active, true) = false then
    return jsonb_build_object('ok', false, 'error', 'inactive');
  end if;
  if coalesce(v_emp.attendance_pin, '') = '' then
    return jsonb_build_object('ok', false, 'error', 'no_pin');
  end if;
  if v_emp.attendance_pin <> p_pin then
    return jsonb_build_object('ok', false, 'error', 'wrong_pin');
  end if;

  select * into v_row from attendance
   where employee_id = p_employee_id and work_date = v_today;

  if p_action = 'check_in' then
    if found and v_row.check_in is not null then
      return jsonb_build_object('ok', false, 'error', 'already_checked_in',
        'name', v_emp.name, 'time', v_row.check_in);
    end if;
    if found then
      update attendance set check_in = v_now where id = v_row.id;
    else
      insert into attendance(employee_id, work_date, check_in)
        values (p_employee_id, v_today, v_now);
    end if;
    return jsonb_build_object('ok', true, 'action', 'check_in',
      'name', v_emp.name, 'time', v_now);

  elsif p_action = 'check_out' then
    if not found or v_row.check_in is null then
      return jsonb_build_object('ok', false, 'error', 'not_checked_in', 'name', v_emp.name);
    end if;
    if v_row.check_out is not null then
      return jsonb_build_object('ok', false, 'error', 'already_checked_out',
        'name', v_emp.name, 'time', v_row.check_out);
    end if;
    update attendance set check_out = v_now where id = v_row.id;
    return jsonb_build_object('ok', true, 'action', 'check_out',
      'name', v_emp.name, 'time', v_now);

  else
    return jsonb_build_object('ok', false, 'error', 'bad_action');
  end if;
end;
$$;

revoke all on function public.record_attendance(uuid, text, text) from public;
grant execute on function public.record_attendance(uuid, text, text) to anon, authenticated;


-- ========================= 31_item_salesperson_commissions.sql =========================
-- ============================================================================
-- 31 — الموظف المسؤول لكل صنف + عمولات المبيعات
-- ============================================================================
-- قبل كده الكابتن كان بيتحدد للفاتورة كلها (orders.salespeople) والعمولة
-- بتتقسّم بالتساوي على كل الكباتن. دلوقتي كل صنف في الفاتورة ليه موظف مسؤول
-- لوحده، فالمبيعات والعمولة بتتنسب للي عمل الشغل فعلاً.
--
-- نوعان من العمولة:
--   • الخدمات  → نسبة % تلقائية من قيمة الخدمة (إعداد عام، افتراضي 10%)
--   • المنتجات → قيمة يدوية بالجنيه لكل قطعة، الأدمن بيكتبها ويأكّدها من
--                صفحة "مبيعات اليوم" (/admin/daily-sales)
-- ============================================================================

-- ── 1) الموظف المسؤول عن كل صنف ──────────────────────────────────────────────
-- on delete set null: لو الموظف اتمسح تفضل الفاتورة سليمة، والاسم محفوظ
-- في salesperson_name عشان التاريخ ما يضيعش.
alter table order_items add column if not exists salesperson_id uuid references employees(id) on delete set null;
alter table order_items add column if not exists salesperson_name text;

-- ── 2) عمولة المنتج اليدوية ─────────────────────────────────────────────────
-- commission_amount = القيمة لكل قطعة. الإجمالي = commission_amount × الكمية.
-- commission_confirmed = الأدمن ضغط "تأكيد"، وقبل كده ما بتتحسبش للموظف.
alter table order_items add column if not exists commission_amount numeric not null default 0;
alter table order_items add column if not exists commission_confirmed boolean not null default false;
alter table order_items add column if not exists commission_updated_at timestamptz;

-- نوع الصنف وقت البيع (منتج/خدمة) — متجمّد على السطر.
-- لو قريناه من products وقت العرض، مسح منتج أو تغيير نوعه بيعيد تصنيف كل
-- الفواتير القديمة بأثر رجعي وعمولة خدمات مؤكَّدة تنزل صفر من غير ما حد ياخد باله.
alter table order_items add column if not exists item_type text;

-- ── 3) أعمدة كانت في ملفات root منفصلة ──────────────────────────────────────
-- products.type كان في add_service_type_and_seed.sql و orders.salespeople كان في
-- add_multiple_salespeople.sql — الاتنين مش في db/ فمكانوش بيتولّدوا في
-- SETUP_DIESEL.sql، يعني أي داتابيز جديدة كانت هتطلع من غيرهم والتطبيق يقع.
-- بنضمنهم هنا (idempotent، مش هيأثر لو الأعمدة موجودة).
alter table products add column if not exists type text not null default 'product';
alter table orders add column if not exists salespeople jsonb not null default '[]'::jsonb;

-- ── 4) نسبة عمولة الخدمات (إعداد عام) ───────────────────────────────────────
alter table store_settings add column if not exists service_commission_rate numeric not null default 10;

-- ── 5) فهارس ────────────────────────────────────────────────────────────────
-- order_items كان بلا فهرس على order_id رغم إن كل قراءة بتعمل join عليه،
-- و orders بلا فهرس على created_at رغم إن صفحة مبيعات اليوم بتفلتر بيه.
create index if not exists idx_order_items_order_id on order_items(order_id);
create index if not exists idx_order_items_salesperson_id on order_items(salesperson_id);
create index if not exists idx_orders_created_at on orders(created_at);

-- ── 6) ترحيل الفواتير القديمة ───────────────────────────────────────────────
-- نوع الصنف بياتاخد من المنتج مرة واحدة، وبعدها بيفضل متجمّد على السطر.
update order_items oi
set item_type = coalesce(p.type, 'product')
from products p
where oi.product_id = p.id and oi.item_type is null;
update order_items set item_type = 'product' where item_type is null; -- منتجات متمسوحة

-- الأصناف القديمة ملهاش موظف. بنملاها من كابتن الفاتورة: لو كابتن واحد بس
-- (أو عمود salesperson_id القديم) ننسب كل أصناف الفاتورة ليه. الفواتير اللي
-- ليها أكتر من كابتن بنسيبها فاضية — مالناش طريقة نعرف مين عمل إيه، والأدمن
-- يقدر يظبطها من صفحة مبيعات اليوم.
--
-- ملاحظة: salespeople عمود jsonb ملوش FK، فممكن يكون فيه id موظف اتمسح أو
-- نص مش uuid. من غير الفلترة دي، صف واحد بايظ بيوقف الميجريشن كلها
-- (خطأ FK أو 22P02 على الكاست).
update order_items oi
set salesperson_id = (o.salespeople -> 0 ->> 'id')::uuid,
    salesperson_name = o.salespeople -> 0 ->> 'name'
from orders o
where oi.order_id = o.id
  and oi.salesperson_id is null
  and jsonb_array_length(coalesce(o.salespeople, '[]'::jsonb)) = 1
  and (o.salespeople -> 0 ->> 'id') ~ '^[0-9a-fA-F-]{36}$'
  and exists (select 1 from employees e where e.id = (o.salespeople -> 0 ->> 'id')::uuid);

update order_items oi
set salesperson_id = o.salesperson_id,
    salesperson_name = o.salesperson_name
from orders o
where oi.order_id = o.id
  and oi.salesperson_id is null
  and o.salesperson_id is not null
  and jsonb_array_length(coalesce(o.salespeople, '[]'::jsonb)) = 0
  and exists (select 1 from employees e where e.id = o.salesperson_id);


-- ========================= 33_category_sort_order.sql =========================
-- ============================================================================
-- 33 — ترتيب التصنيفات
-- ============================================================================
-- التصنيفات كانت بتترتّب أبجدياً (.order('name'))، فترتيب المحل الطبيعي
-- (الشعر ← الدقن ← البشرة ← ... ← العروض) ما كانش ينفع يتحكم فيه.
-- العمود ده بيخلي الترتيب بإيد صاحب المحل، والأبجدي بيفضل بديل عند التساوي.
-- ============================================================================

alter table categories add column if not exists sort_order integer not null default 0;

create index if not exists idx_categories_sort_order on categories(sort_order, name);
