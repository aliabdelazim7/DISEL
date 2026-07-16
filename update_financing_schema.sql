-- ============================================================
-- Financing module: loans and associations
-- Run once in Supabase SQL Editor.
-- ============================================================

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

alter table financing_payments add column if not exists paid_amount numeric not null default 0;
alter table financing_payments add column if not exists remaining_amount numeric not null default 0;

update financing_payments
set remaining_amount = greatest(0, amount - coalesce(paid_amount, 0))
where remaining_amount = 0 and status <> 'paid';

alter table financing_accounts enable row level security;
alter table financing_payments enable row level security;
alter table financing_transactions enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'financing_accounts'
      and policyname = 'allow all'
  ) then
    create policy "allow all" on financing_accounts for all using (true) with check (true);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'financing_payments'
      and policyname = 'allow all'
  ) then
    create policy "allow all" on financing_payments for all using (true) with check (true);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'financing_transactions'
      and policyname = 'allow all'
  ) then
    create policy "allow all" on financing_transactions for all using (true) with check (true);
  end if;
end $$;
