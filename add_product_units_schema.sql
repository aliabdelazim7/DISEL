-- ─────────────────────────────────────────────────────────────
-- إضافة نظام الوحدات للمنتجات (قطعة / كيلو / جرام / لتر ... )
-- ودعم الكميات الكسرية (البيع بالوزن)
-- شغّل هذا الملف مرة واحدة على قاعدة بيانات Supabase
-- ─────────────────────────────────────────────────────────────

-- 1) عمود الوحدة على المنتجات (الافتراضي: قطعة)
alter table products
  add column if not exists unit text not null default 'قطعة';

-- 2) السماح بكميات كسرية (وزن) في المخزون والفواتير
--    تحويل أعمدة الكمية من integer إلى numeric
alter table products
  alter column stock_quantity type numeric using stock_quantity::numeric;

alter table purchase_items
  alter column quantity type numeric using quantity::numeric;

alter table order_items
  alter column quantity type numeric using quantity::numeric,
  alter column returned_quantity type numeric using returned_quantity::numeric;

-- تم. الآن يمكن تخزين كميات مثل 0.25 كيلو والخصم منها بدقة.
