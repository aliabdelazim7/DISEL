-- ============================================================================
-- 31 — الموظف المسؤول لكل صنف + عمولات المبيعات
-- ============================================================================
-- قبل كده الكابتن كان بيتحدد للفاتورة كلها (orders.salespeople) والعمولة
-- بتتقسّم بالتساوي على كل الكباتن. دلوقتي كل صنف في الفاتورة ليه موظف مسؤول
-- لوحده، فالمبيعات والعمولة بتتنسب للي عمل الشغل فعلاً.
--
-- نوعان من العمولة:
--   • الخدمات  → نسبة % تلقائية من قيمة الخدمة (إعداد عام، افتراضي 10%)
--   • المنتجات → قيمة يدوية بالجنيه لكل قطعة، الأدمن بيكتبها ويأكّدها من
--                صفحة "مبيعات اليوم" (/admin/daily-sales)
-- ============================================================================

-- ── 1) الموظف المسؤول عن كل صنف ──────────────────────────────────────────────
-- on delete set null: لو الموظف اتمسح تفضل الفاتورة سليمة، والاسم محفوظ
-- في salesperson_name عشان التاريخ ما يضيعش.
alter table order_items add column if not exists salesperson_id uuid references employees(id) on delete set null;
alter table order_items add column if not exists salesperson_name text;

-- ── 2) عمولة المنتج اليدوية ─────────────────────────────────────────────────
-- commission_amount = القيمة لكل قطعة. الإجمالي = commission_amount × الكمية.
-- commission_confirmed = الأدمن ضغط "تأكيد"، وقبل كده ما بتتحسبش للموظف.
alter table order_items add column if not exists commission_amount numeric not null default 0;
alter table order_items add column if not exists commission_confirmed boolean not null default false;
alter table order_items add column if not exists commission_updated_at timestamptz;

-- نوع الصنف وقت البيع (منتج/خدمة) — متجمّد على السطر.
-- لو قريناه من products وقت العرض، مسح منتج أو تغيير نوعه بيعيد تصنيف كل
-- الفواتير القديمة بأثر رجعي وعمولة خدمات مؤكَّدة تنزل صفر من غير ما حد ياخد باله.
alter table order_items add column if not exists item_type text;

-- ── 3) أعمدة كانت في ملفات root منفصلة ──────────────────────────────────────
-- products.type كان في add_service_type_and_seed.sql و orders.salespeople كان في
-- add_multiple_salespeople.sql — الاتنين مش في db/ فمكانوش بيتولّدوا في
-- SETUP_DIESEL.sql، يعني أي داتابيز جديدة كانت هتطلع من غيرهم والتطبيق يقع.
-- بنضمنهم هنا (idempotent، مش هيأثر لو الأعمدة موجودة).
alter table products add column if not exists type text not null default 'product';
alter table orders add column if not exists salespeople jsonb not null default '[]'::jsonb;

-- ── 4) نسبة عمولة الخدمات (إعداد عام) ───────────────────────────────────────
alter table store_settings add column if not exists service_commission_rate numeric not null default 10;

-- ── 5) فهارس ────────────────────────────────────────────────────────────────
-- order_items كان بلا فهرس على order_id رغم إن كل قراءة بتعمل join عليه،
-- و orders بلا فهرس على created_at رغم إن صفحة مبيعات اليوم بتفلتر بيه.
create index if not exists idx_order_items_order_id on order_items(order_id);
create index if not exists idx_order_items_salesperson_id on order_items(salesperson_id);
create index if not exists idx_orders_created_at on orders(created_at);

-- ── 6) ترحيل الفواتير القديمة ───────────────────────────────────────────────
-- نوع الصنف بياتاخد من المنتج مرة واحدة، وبعدها بيفضل متجمّد على السطر.
update order_items oi
set item_type = coalesce(p.type, 'product')
from products p
where oi.product_id = p.id and oi.item_type is null;
update order_items set item_type = 'product' where item_type is null; -- منتجات متمسوحة

-- الأصناف القديمة ملهاش موظف. بنملاها من كابتن الفاتورة: لو كابتن واحد بس
-- (أو عمود salesperson_id القديم) ننسب كل أصناف الفاتورة ليه. الفواتير اللي
-- ليها أكتر من كابتن بنسيبها فاضية — مالناش طريقة نعرف مين عمل إيه، والأدمن
-- يقدر يظبطها من صفحة مبيعات اليوم.
--
-- ملاحظة: salespeople عمود jsonb ملوش FK، فممكن يكون فيه id موظف اتمسح أو
-- نص مش uuid. من غير الفلترة دي، صف واحد بايظ بيوقف الميجريشن كلها
-- (خطأ FK أو 22P02 على الكاست).
update order_items oi
set salesperson_id = (o.salespeople -> 0 ->> 'id')::uuid,
    salesperson_name = o.salespeople -> 0 ->> 'name'
from orders o
where oi.order_id = o.id
  and oi.salesperson_id is null
  and jsonb_array_length(coalesce(o.salespeople, '[]'::jsonb)) = 1
  and (o.salespeople -> 0 ->> 'id') ~ '^[0-9a-fA-F-]{36}$'
  and exists (select 1 from employees e where e.id = (o.salespeople -> 0 ->> 'id')::uuid);

update order_items oi
set salesperson_id = o.salesperson_id,
    salesperson_name = o.salesperson_name
from orders o
where oi.order_id = o.id
  and oi.salesperson_id is null
  and o.salesperson_id is not null
  and jsonb_array_length(coalesce(o.salespeople, '[]'::jsonb)) = 0
  and exists (select 1 from employees e where e.id = o.salesperson_id);
