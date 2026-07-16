-- Add the actual refunded cash amount per returned invoice item.
-- Run this once in Supabase SQL Editor if older databases only have returned_quantity.

alter table order_items
add column if not exists refunded_amount numeric default 0;

update order_items
set refunded_amount = 0
where refunded_amount is null;
