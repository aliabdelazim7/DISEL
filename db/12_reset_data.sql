-- =============================================================================
-- ADRIA — تصفير البيانات والبدء من جديد
-- شغّله في Supabase → SQL Editor.  ⚠️ لا رجوع بعد التنفيذ — خدي Backup لو محتاجة.
-- =============================================================================

-- ── القسم (1): مسح كل المعاملات المالية (الافتراضي) ──────────────────────────
-- بيمسح: الفواتير، بنود الفواتير، المصروفات/الإيرادات، المشتريات، الرواتب والسلف،
--        التمويل/السلف، التصنيع، الفواتير المحذوفة، سحوبات المدراء (مصروفات).
-- بيحتفظ بـ: الإعدادات، التصنيفات، المنتجات، العملاء، الموردين، المحاسبين،
--           الموظفين، المدراء، الكوبونات.  (مديونية العملاء/الموردين بتتصفّر تلقائياً
--           لأنها محسوبة من الفواتير.)
truncate table order_items, orders, expenses, purchase_items, purchase_invoices,
  employee_transactions, employee_leaves
  restart identity cascade;

do $$
begin
  if to_regclass('public.deleted_invoices') is not null then truncate table deleted_invoices cascade; end if;
  if to_regclass('public.financing_transactions') is not null then truncate table financing_transactions cascade; end if;
  if to_regclass('public.financing_payments') is not null then truncate table financing_payments cascade; end if;
  if to_regclass('public.financing_accounts') is not null then truncate table financing_accounts cascade; end if;
  if to_regclass('public.production_materials') is not null then truncate table production_materials cascade; end if;
  if to_regclass('public.production_orders') is not null then truncate table production_orders cascade; end if;
end $$;

-- صفّر عدّاد أرقام الفواتير ليبدأ من 1
update invoice_counter set current_value = 1;

-- (اختياري) صفّر كمية كل المنتجات في المخزون والعرض — شيلي علامتي التعليق لو عايزة:
-- update products set stock_quantity = 0, display_quantity = 0;


-- ── القسم (2): تصفير كامل (الكتالوج + العملاء + الموردين + الخامات) ───────────
-- ⚠️ شيلي علامة التعليق فقط لو عايزة تمسحي المنتجات والعملاء والموردين كمان وتبدئي
--    من شاشة فاضية تماماً (هيخليكي تعيدي إدخال كل المنتجات).
-- do $$
-- begin
--   if to_regclass('public.materials') is not null then truncate table materials cascade; end if;
--   truncate table products, customers, suppliers restart identity cascade;
--   -- truncate table categories cascade;  -- شيلي التعليق لو عايزة تمسحي التصنيفات كمان
-- end $$;
