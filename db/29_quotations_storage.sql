-- تخزين ملفات عروض الأسعار PDF لإرسالها كرابط تحميل في الواتساب.
-- ينشئ bucket عام اسمه «quotations» + صلاحيات رفع/قراءة تعمل بمفتاح anon.
-- شغّله مرة واحدة في Supabase → SQL Editor.

-- 1) الـ bucket العام (القراءة عبر الرابط العام بدون تسجيل دخول).
insert into storage.buckets (id, name, public)
values ('quotations', 'quotations', true)
on conflict (id) do update set public = true;

-- 2) صلاحيات storage.objects على هذا الـ bucket فقط (public = anon + authenticated).
do $$ begin
  -- رفع ملف جديد
  if not exists (select 1 from pg_policies where schemaname='storage' and tablename='objects' and policyname='quotations_insert') then
    execute 'create policy "quotations_insert" on storage.objects for insert to public with check (bucket_id = ''quotations'')';
  end if;
  -- استبدال ملف موجود (upsert)
  if not exists (select 1 from pg_policies where schemaname='storage' and tablename='objects' and policyname='quotations_update') then
    execute 'create policy "quotations_update" on storage.objects for update to public using (bucket_id = ''quotations'') with check (bucket_id = ''quotations'')';
  end if;
  -- قراءة (الـ bucket عام أصلاً، لكن نضيف السياسة احتياطاً)
  if not exists (select 1 from pg_policies where schemaname='storage' and tablename='objects' and policyname='quotations_read') then
    execute 'create policy "quotations_read" on storage.objects for select to public using (bucket_id = ''quotations'')';
  end if;
end $$;
