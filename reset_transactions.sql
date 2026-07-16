-- سكريبت تنظيف قاعدة البيانات من المعاملات المالية والفواتير
-- هذا السكريبت سيحذف كل الحركات (فواتير بيع، شراء، مصاريف، معاملات موظفين، إلخ)
-- مع الاحتفاظ بـ: المنتجات (والكميات الحالية فيها)، العملاء، الموردين، التصنيفات، الموظفين، وإعدادات المتجر

-- 1. مسح تفاصيل الفواتير (لأنها مرتبطة بالفواتير نفسها)
TRUNCATE TABLE order_items CASCADE;
TRUNCATE TABLE purchase_items CASCADE;

-- 2. مسح الفواتير الأساسية
TRUNCATE TABLE orders CASCADE;
TRUNCATE TABLE purchase_invoices CASCADE;

-- 3. مسح المصروفات
TRUNCATE TABLE expenses CASCADE;

-- 4. مسح حركات الموظفين
TRUNCATE TABLE employee_transactions CASCADE;
TRUNCATE TABLE employee_leaves CASCADE;

-- 5. مسح الحركات المالية للتمويل (مع الاحتفاظ بالحسابات التمويلية نفسها إن وجدت)
TRUNCATE TABLE financing_transactions CASCADE;
TRUNCATE TABLE financing_payments CASCADE;

-- 6. تصفير عداد الفواتير ليبدأ من رقم 1 مرة أخرى
UPDATE invoice_counter SET current_value = 1 WHERE id = 1;

-- ملاحظة: الـ CASCADE ستقوم بحذف أي سجلات مرتبطة بشكل تلقائي (إذا كانت هناك قيود)
-- المنتجات والكميات (المخزون)، العملاء، الموردين لن تتأثر بهذا السكريبت.
