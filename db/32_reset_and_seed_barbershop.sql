-- =============================================================================
-- DIESEL Barbershop — تصفير كامل + خدمات جديدة
-- شغّله في: Supabase → SQL Editor → New query → Run
--
-- ⚠️  لا رجوع بعد التنفيذ. خد Backup الأول من:
--     Supabase → Database → Backups
--
-- بيمسح:   الفواتير، بنود الفواتير، المصروفات، المشتريات، الأقساط، عروض الأسعار،
--          الجرد، التصنيع، التمويل، الشركاء، الادخار، رواتب/سلف الموظفين،
--          كل المنتجات، كل التصنيفات.
-- بيحتفظ:  الكاشيرية، المدراء، المحاسبين، الأدمن، الموظفين، الشركاء (الأشخاص)،
--          العملاء، الموردين، إعدادات المحل.
--          (مديونية العملاء بتتصفّر لوحدها لأنها محسوبة من الفواتير)
-- =============================================================================

begin;

-- ── (1) مسح كل الحركات المالية والفواتير ────────────────────────────────────
truncate table order_items, orders, expenses, purchase_items, purchase_invoices,
  employee_transactions, employee_leaves
  restart identity cascade;

do $$
begin
  if to_regclass('public.deleted_invoices')      is not null then truncate table deleted_invoices cascade; end if;
  if to_regclass('public.installments')          is not null then truncate table installments cascade; end if;
  if to_regclass('public.installment_plans')     is not null then truncate table installment_plans cascade; end if;
  if to_regclass('public.quotations')            is not null then truncate table quotations cascade; end if;
  if to_regclass('public.stock_adjustments')     is not null then truncate table stock_adjustments cascade; end if;
  if to_regclass('public.production_materials')  is not null then truncate table production_materials cascade; end if;
  if to_regclass('public.production_orders')     is not null then truncate table production_orders cascade; end if;
  if to_regclass('public.financing_transactions')is not null then truncate table financing_transactions cascade; end if;
  if to_regclass('public.financing_payments')    is not null then truncate table financing_payments cascade; end if;
  if to_regclass('public.financing_accounts')    is not null then truncate table financing_accounts cascade; end if;
  if to_regclass('public.partner_transactions')  is not null then truncate table partner_transactions cascade; end if;
  if to_regclass('public.savings_transactions')  is not null then truncate table savings_transactions cascade; end if;
  if to_regclass('public.product_suggestions')   is not null then truncate table product_suggestions cascade; end if;
  if to_regclass('public.cashier_notes')         is not null then truncate table cashier_notes cascade; end if;
  if to_regclass('public.otp_codes')             is not null then truncate table otp_codes cascade; end if;
  if to_regclass('public.materials')             is not null then truncate table materials cascade; end if;
  if to_regclass('public.car_subscriptions')     is not null then truncate table car_subscriptions cascade; end if;
  if to_regclass('public.maintenance_appointments') is not null then truncate table maintenance_appointments cascade; end if;
end $$;

-- صفّر عدّاد أرقام الفواتير ليبدأ من 1
update invoice_counter set current_value = 1;

-- ── (2) مسح الكتالوج القديم بالكامل ─────────────────────────────────────────
truncate table products restart identity cascade;
truncate table categories restart identity cascade;

-- ── (3) التأكد من وجود عمود النوع (منتج / خدمة) ─────────────────────────────
alter table products add column if not exists type text not null default 'product';

-- ── (4) التصنيفات الجديدة ───────────────────────────────────────────────────
insert into categories (name) values
  ('الشعر'),
  ('الدقن'),
  ('تنظيف البشرة'),
  ('فرد & بروتين'),
  ('واكس'),
  ('مساچ'),
  ('عروض');

-- ── (5) الخدمات ─────────────────────────────────────────────────────────────
--  ⬅️  عمود السعر كله 0 دلوقتي. عدّل الأرقام هنا قبل ما تشغّل السكربت،
--      أو سيبها 0 وحطّها بعدين من التطبيق: لوحة التحكم → المخزون → تعديل.
insert into products
  (name, type, sale_price, purchase_price, average_purchase_price,
   stock_quantity, display_quantity, unit, category_id)
select
  v.name, 'service', v.price, 0, 0, 1000000, 1000000, 'قطعة',
  (select id from categories where name = v.cat limit 1)
from (values
  -- ═══ الشعر ═══
  ('قص شعر',                    0, 'الشعر'),
  ('استشوار',                   0, 'الشعر'),
  ('صبغة شعر',                  0, 'الشعر'),
  ('حنة شعر',                   0, 'الشعر'),
  ('تشقير شعر',                 0, 'الشعر'),
  ('شعر سلفر',                  0, 'الشعر'),
  ('توبيك فراغات شعر',          0, 'الشعر'),
  ('شعر زيرو',                  0, 'الشعر'),
  ('حمام زيت',                  0, 'الشعر'),
  ('رنساچ شعر',                 0, 'الشعر'),

  -- ═══ الدقن ═══
  ('دقن',                       0, 'الدقن'),
  ('دقن بخار',                  0, 'الدقن'),
  ('تحديد دقن موس',             0, 'الدقن'),
  ('دقن زيرو',                  0, 'الدقن'),
  ('صبغة دقن',                  0, 'الدقن'),
  ('حنة دقن',                   0, 'الدقن'),
  ('فرد دقن',                   0, 'الدقن'),
  ('رنساچ دقن',                 0, 'الدقن'),

  -- ═══ تنظيف البشرة ═══
  ('تنظيف بشرة عادي',           0, 'تنظيف البشرة'),
  ('تنظيف بشرة هيدرو فشنال',    0, 'تنظيف البشرة'),

  -- ═══ فرد & بروتين ═══
  ('فرد شعر عادي',              0, 'فرد & بروتين'),
  ('فرد شعر مستورد',            0, 'فرد & بروتين'),
  ('بروتين شعر',                0, 'فرد & بروتين'),
  ('بروتين مستورد',             0, 'فرد & بروتين'),

  -- ═══ واكس ═══
  ('واكس أنف و الأذن',          0, 'واكس'),
  ('واكس وجه',                  0, 'واكس'),
  ('واكس كامل',                 0, 'واكس'),

  -- ═══ مساچ ═══
  ('جلسة مساچ جهازين 15 دقيقة VIP', 0, 'مساچ'),

  -- ═══ العروض ═══
  -- عرض التوفير  = قص شعر + دقن + حمام كريم + تنظيف بشرة عادي
  --                + جلسة مساچ 5 دقائق + استشوار
  ('عرض التوفير',               0, 'عروض'),
  -- عرض الديزل   = قص شعر + دقن + تنظيف قشرة + حمام زيت + واكس كامل
  --                + جلسة مساچ + تنظيف بشرة هيدرو فشنال + استشوار
  ('عرض الديزل',                0, 'عروض')
) as v(name, price, cat);

commit;

-- ── التحقق بعد التشغيل ──────────────────────────────────────────────────────
-- select c.name as التصنيف, count(p.id) as عدد_الخدمات
-- from categories c left join products p on p.category_id = c.id
-- group by c.name order by c.name;
--
-- select count(*) as الفواتير_المتبقية from orders;   -- المفروض 0
