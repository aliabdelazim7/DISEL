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
