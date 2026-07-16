-- ============================================================
-- سكريبت تصفير البيانات وإضافة منتجات قطع غيار سيارات
-- تحذير: هذا السكريبت سيقوم بحذف جميع البيانات الحالية!
-- ============================================================

-- 1. تصفير جميع الجداول (حذف البيانات)
truncate table order_items cascade;
truncate table orders cascade;
truncate table purchase_items cascade;
truncate table purchase_invoices cascade;
truncate table expenses cascade;
truncate table products cascade;
truncate table categories cascade;
truncate table customers cascade;
truncate table suppliers cascade;

-- 2. إعادة ضبط الـ Counter للفواتير
update invoice_counter set current_value = 1 where id = 1;

-- 3. إضافة فئات قطع الغيار
insert into categories (id, name) values 
  (gen_random_uuid(), 'فلاتر وزيوت'),
  (gen_random_uuid(), 'فرامل ونظام تعليق'),
  (gen_random_uuid(), 'كهرباء وبطاريات'),
  (gen_random_uuid(), 'محركات وميكانيكا');

-- 4. إضافة 12 منتج قطع غيار سيارات
-- ملاحظة: بنفترض إننا هنربطهم بأول فئة للتسهيل أو نوزعهم
with cat_list as (select id, name from categories)
insert into products (name, barcode, purchase_price, average_purchase_price, sale_price, stock_quantity, category_id)
values 
  ('تيل فرامل أمامي كوري', '1001', 450, 450, 650, 20, (select id from cat_list where name = 'فرامل ونظام تعليق')),
  ('فلتر زيت تويوتا أصلي', '1002', 120, 120, 180, 50, (select id from cat_list where name = 'فلاتر وزيوت')),
  ('طقم بوجيهات NGK ليزر', '1003', 350, 350, 480, 15, (select id from cat_list where name = 'كهرباء وبطاريات')),
  ('سير كاتينة دايكو', '1004', 280, 280, 420, 10, (select id from cat_list where name = 'محركات وميكانيكا')),
  ('مساعد خلفي KYB', '1005', 850, 850, 1100, 8, (select id from cat_list where name = 'فرامل ونظام تعليق')),
  ('بطارية كلورايد 70 أمبير', '1006', 1800, 1800, 2200, 5, (select id from cat_list where name = 'كهرباء وبطاريات')),
  ('طلمبة بنزين بوش', '1007', 650, 650, 950, 6, (select id from cat_list where name = 'محركات وميكانيكا')),
  ('فلتر هواء هيونداي', '1008', 150, 150, 220, 30, (select id from cat_list where name = 'فلاتر وزيوت')),
  ('طقم مقصات أمامي', '1009', 1400, 1400, 1900, 4, (select id from cat_list where name = 'فرامل ونظام تعليق')),
  ('رادياتير ألومنيوم', '1010', 950, 950, 1350, 3, (select id from cat_list where name = 'محركات وميكانيكا')),
  ('موبينة كهرباء ياباني', '1011', 550, 550, 780, 12, (select id from cat_list where name = 'كهرباء وبطاريات')),
  ('فانوس أمامي ليد', '1012', 1100, 1100, 1600, 4, (select id from cat_list where name = 'كهرباء وبطاريات'));
