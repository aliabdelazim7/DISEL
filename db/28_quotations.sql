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
