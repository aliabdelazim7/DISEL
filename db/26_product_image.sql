-- صورة المنتج: تُخزَّن كـ Data URL مضغوط (ثمبنيل) وتظهر في الكاشير.
-- شغّله مرة واحدة في Supabase → SQL Editor قبل استخدام رفع الصور.
alter table products add column if not exists image_url text;
