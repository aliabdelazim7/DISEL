-- =============================================================================
-- DIESEL Barbershop — تصفير كامل + كتالوج الخدمات النهائي
-- شغّله في: Supabase → SQL Editor → New query → Run
--
-- ⚠️  لا رجوع بعد التنفيذ. خد Backup الأول من:
--     Supabase → Database → Backups
--
-- بيمسح:   كل المنتجات والخدمات والتصنيفات، كل العملاء، كل الفواتير وبنودها،
--          المصروفات، المشتريات، الأقساط، عروض الأسعار، الجرد، التصنيع،
--          التمويل، الشركاء (الحركات)، الادخار، رواتب وسلف الموظفين.
-- بيحتفظ:  الكاشيرية، المدراء، الأدمن، الموظفين (الأشخاص)، الموردين،
--          إعدادات المحل (منها نسبة عمولة الخدمات).
--
-- ⚠️  لازم تشغّل الأول (لو ما اشتغلوش قبل كده):
--        db/31_item_salesperson_commissions.sql
--        db/33_category_sort_order.sql
-- =============================================================================

begin;

-- ── (1) الحركات المالية والفواتير ───────────────────────────────────────────
truncate table order_items, orders, expenses, purchase_items, purchase_invoices,
  employee_transactions, employee_leaves
  restart identity cascade;

do $$
begin
  if to_regclass('public.deleted_invoices')      is not null then truncate table deleted_invoices cascade; end if;
  if to_regclass('public.held_invoices')         is not null then truncate table held_invoices cascade; end if;
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
  if to_regclass('public.coupons')               is not null then truncate table coupons cascade; end if;
  if to_regclass('public.car_subscriptions')     is not null then truncate table car_subscriptions cascade; end if;
  if to_regclass('public.maintenance_appointments') is not null then truncate table maintenance_appointments cascade; end if;
end $$;

-- أرقام الفواتير تبدأ من 1 من جديد
update invoice_counter set current_value = 1;

-- ── (2) العملاء ─────────────────────────────────────────────────────────────
-- (مديونياتهم اتصفّرت لوحدها مع مسح الفواتير)
truncate table customers restart identity cascade;

-- ── (3) الكتالوج القديم بالكامل ─────────────────────────────────────────────
truncate table products restart identity cascade;
truncate table categories restart identity cascade;

-- ── (4) الأعمدة المطلوبة (لو السكربتات السابقة ما اشتغلتش) ──────────────────
alter table products   add column if not exists type text not null default 'product';
alter table categories add column if not exists sort_order integer not null default 0;

-- ── (5) التصنيفات — بترتيب المحل مش أبجدي ───────────────────────────────────
insert into categories (name, sort_order) values
  ('خانة الشعر',    1),
  ('دقن',           2),
  ('تنظيف البشرة',  3),
  ('فرد & بروتين',  4),
  ('واكس',          5),
  ('جلسة مساچ',     6),
  ('عروض',          7);

-- ── (6) الخدمات ─────────────────────────────────────────────────────────────
--  ⬅️  كل الأسعار 0. حطّها من: لوحة التحكم → المخزون → تعديل
--      (أو عدّل الأرقام هنا قبل ما تشغّل السكربت).
--
--  الخدمة مالهاش مخزون ولا سعر شراء — بتتحط بمخزون وهمي كبير عشان ما "تخلصش"،
--  والتطبيق بيخفي عنها حقول الكمية وبيستبعدها من المشتريات والجرد.
insert into products
  (name, type, sale_price, purchase_price, average_purchase_price,
   stock_quantity, display_quantity, unit, category_id)
select
  v.name, 'service', v.price, 0, 0, 1000000, 1000000, 'قطعة',
  (select id from categories where name = v.cat limit 1)
from (values
  -- ═══ خانة الشعر ═══
  ('قص شعر',                        0, 'خانة الشعر'),
  ('استشوار',                       0, 'خانة الشعر'),
  ('صبغة شعر',                      0, 'خانة الشعر'),
  ('حنة شعر',                       0, 'خانة الشعر'),
  ('تشقير شعر',                     0, 'خانة الشعر'),
  ('شعر سلفر',                      0, 'خانة الشعر'),
  ('توبيك فراغات شعر',              0, 'خانة الشعر'),
  ('شعر زيرو',                      0, 'خانة الشعر'),
  ('حمام زيت',                      0, 'خانة الشعر'),
  ('رنساچ شعر',                     0, 'خانة الشعر'),

  -- ═══ دقن ═══
  ('دقن',                           0, 'دقن'),
  ('دقن بخار',                      0, 'دقن'),
  ('تحديد دقن موس',                 0, 'دقن'),
  ('دقن زيرو',                      0, 'دقن'),
  ('صبغة دقن',                      0, 'دقن'),
  ('حنة دقن',                       0, 'دقن'),
  ('فرد دقن',                       0, 'دقن'),
  ('رنساچ دقن',                     0, 'دقن'),

  -- ═══ تنظيف البشرة ═══
  ('تنظيف بشرة عادي',               0, 'تنظيف البشرة'),
  ('تنظيف بشرة هيدرو فشنال',        0, 'تنظيف البشرة'),

  -- ═══ فرد & بروتين ═══
  ('فرد شعر عادي',                  0, 'فرد & بروتين'),
  ('فرد شعر مستورد',                0, 'فرد & بروتين'),
  ('بروتين شعر',                    0, 'فرد & بروتين'),
  ('بروتين مستورد',                 0, 'فرد & بروتين'),

  -- ═══ واكس ═══
  ('واكس أنف و الأذن',              0, 'واكس'),
  ('واكس وجه',                      0, 'واكس'),
  ('واكس كامل',                     0, 'واكس'),

  -- ═══ جلسة مساچ ═══
  ('جلسة مساچ جهازين 15 دقيقة VIP', 0, 'جلسة مساچ'),

  -- ═══ عروض ═══
  -- العرض بيتباع كصنف واحد بسعر واحد، والمحتويات في اسم الصنف نفسه عشان
  -- الكاشير يعرف بيبيع إيه، والموظف المسؤول واحد على العرض كله.
  ('عرض التوفير (قص شعر + دقن + حمام كريم + تنظيف بشرة عادي + مساچ 5 دقائق + استشوار)',
                                    0, 'عروض'),
  ('عرض الديزل (قص شعر + دقن + تنظيف قشرة + حمام زيت + واكس كامل + مساچ + تنظيف بشرة هيدرو فشنال + استشوار)',
                                    0, 'عروض')
) as v(name, price, cat);

commit;

-- ── التحقق بعد التشغيل ──────────────────────────────────────────────────────
-- select c.sort_order as الترتيب, c.name as التصنيف, count(p.id) as عدد_الخدمات
-- from categories c left join products p on p.category_id = c.id
-- group by c.sort_order, c.name order by c.sort_order;
--   المفروض: 1 خانة الشعر=10 | 2 دقن=8 | 3 تنظيف البشرة=2 | 4 فرد & بروتين=4
--            5 واكس=3 | 6 جلسة مساچ=1 | 7 عروض=2      (الإجمالي 30 خدمة)
--
-- select count(*) from orders;     -- 0
-- select count(*) from customers;  -- 0
-- select count(*) from products where type <> 'service';  -- 0
