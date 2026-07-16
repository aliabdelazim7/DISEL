-- ============================================================
-- تحديث نظام الخزينة والميزانية اليومية
-- ============================================================

-- 1. إضافة طريقة الدفع للجداول الأساسية
alter table orders add column if not exists payment_method text default 'cash';
alter table expenses add column if not exists payment_method text default 'cash';
alter table purchase_invoices add column if not exists payment_method text default 'cash';

-- 2. إضافة رصيد البداية للنظام في الإعدادات
alter table store_settings add column if not exists initial_balance numeric default 0;
