-- Add employee leave balances, leave log, and incentives.
-- Run this once in Supabase SQL Editor before using employee vacations.

alter table employees add column if not exists annual_leave_balance numeric not null default 0;
alter table employees add column if not exists hire_date date default current_date;

alter table employee_transactions drop constraint if exists employee_transactions_type_check;
alter table employee_transactions
  add constraint employee_transactions_type_check
  check (type in ('salary', 'advance', 'incentive'));

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

alter table employee_leaves enable row level security;

drop policy if exists "allow all" on employee_leaves;
create policy "allow all" on employee_leaves for all using (true) with check (true);
