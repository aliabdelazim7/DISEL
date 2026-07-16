-- إصلاح جدول المصروفات/الإيرادات (expenses)
-- المشكلة: الكود في useStore.ts (addExpense/updateExpense) بيحاول يحفظ أعمدة
-- غير موجودة في الجدول، فالـ insert بيفشل ولا تُحفظ المعاملة.
-- شغّل هذا السكربت في Supabase SQL Editor.

alter table expenses add column if not exists paid_cash      numeric default 0;
alter table expenses add column if not exists paid_visa      numeric default 0;
alter table expenses add column if not exists paid_wallet    numeric default 0;
alter table expenses add column if not exists paid_instapay  numeric default 0;
alter table expenses add column if not exists payment_method text;
alter table expenses add column if not exists car_id         uuid;

-- التأكد أن RLS تسمح بالإدخال (موجودة في السكيمة الأصلية، لكن للأمان):
alter table expenses enable row level security;
do $$
begin
  if not exists (
    select 1 from pg_policies
    where tablename = 'expenses' and policyname = 'allow all'
  ) then
    create policy "allow all" on expenses for all using (true) with check (true);
  end if;
end $$;
