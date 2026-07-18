-- ADRIA — تقسيم المخزون: مستودع + معرض.
-- stock_quantity = الإجمالي (زي ما هو). display_quantity = الكمية المعروضة في المحل.
-- المستودع = الإجمالي - المعروض. شغّله مرة واحدة.
alter table products add column if not exists display_quantity numeric default 0;
