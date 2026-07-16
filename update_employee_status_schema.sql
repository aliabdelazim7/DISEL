-- Add active/inactive status for employees.
-- Run this once in Supabase SQL Editor before using employee status filters.

alter table employees add column if not exists is_active boolean not null default true;

create index if not exists idx_employees_is_active on employees(is_active);
