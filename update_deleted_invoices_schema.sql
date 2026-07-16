-- Add soft-delete fields for sales invoices.
-- Run this once in Supabase SQL Editor before deleting invoices from the app.

alter table orders add column if not exists is_deleted boolean not null default false;
alter table orders add column if not exists deleted_at timestamptz;
alter table orders add column if not exists deletion_reason text;

create index if not exists idx_orders_is_deleted on orders(is_deleted);
create index if not exists idx_orders_deleted_at on orders(deleted_at);
