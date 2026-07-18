-- =============================================================================
-- ATTENDANCE (تسجيل حضور وانصراف الموظفين)  — run AFTER secure_rls_migration.sql
-- =============================================================================
--  الفكرة:
--   * صفحة عامة منفصلة /attendance يستخدمها كل الموظفين (بدون تسجيل دخول للنظام).
--   * كل موظف يختار اسمه + يكتب رقمه السري (attendance_pin) ويسجّل حضور/انصراف.
--   * كل الكتابة تتم عبر دوال SECURITY DEFINER فقط (anon ماينفعش يكتب مباشرة).
--   * المدير (authenticated) يقرأ سجل الحضور من لوحة التحكم.
--
--  آمن للتشغيل أكثر من مرة (idempotent).
-- =============================================================================

-- 1) رقم سري لكل موظف لتسجيل الحضور
alter table employees add column if not exists attendance_pin text;

-- 2) جدول الحضور: صف واحد لكل موظف في اليوم (حضور + انصراف)
create table if not exists attendance (
  id uuid default gen_random_uuid() primary key,
  employee_id uuid references employees(id) on delete cascade,
  work_date date not null,
  check_in timestamptz,
  check_out timestamptz,
  created_at timestamptz default now(),
  unique (employee_id, work_date)
);

create index if not exists idx_attendance_employee on attendance(employee_id);
create index if not exists idx_attendance_work_date on attendance(work_date);

-- RLS: قراءة/إدارة للمصادَق عليهم فقط (المدير). الكتابة العامة عبر الدوال أدناه.
alter table attendance enable row level security;
drop policy if exists "authenticated full access" on attendance;
create policy "authenticated full access" on attendance
  for all to authenticated using (true) with check (true);
revoke all on attendance from anon;

-- ---------------------------------------------------------------------------
-- 3) قائمة الموظفين النشطين لصفحة الحضور (بدون كشف الرقم السري)
-- ---------------------------------------------------------------------------
create or replace function public.get_attendance_employees()
returns jsonb
language sql
security definer
set search_path = public
as $$
  select coalesce(
    jsonb_agg(
      jsonb_build_object('id', e.id, 'name', e.name, 'job_title', e.job_title)
      order by e.name
    ),
    '[]'::jsonb)
  from employees e
  where coalesce(e.is_active, true) = true;
$$;

revoke all on function public.get_attendance_employees() from public;
grant execute on function public.get_attendance_employees() to anon, authenticated;

-- ---------------------------------------------------------------------------
-- 4) حالة اليوم لموظف معيّن (لتفعيل/تعطيل زر الانصراف)
-- ---------------------------------------------------------------------------
create or replace function public.get_attendance_status(p_employee_id uuid)
returns jsonb
language sql
security definer
set search_path = public
as $$
  select coalesce(
    (select jsonb_build_object('check_in', a.check_in, 'check_out', a.check_out)
       from attendance a
      where a.employee_id = p_employee_id
        and a.work_date = (now() at time zone 'Africa/Cairo')::date),
    jsonb_build_object('check_in', null, 'check_out', null)
  );
$$;

revoke all on function public.get_attendance_status(uuid) from public;
grant execute on function public.get_attendance_status(uuid) to anon, authenticated;

-- ---------------------------------------------------------------------------
-- 5) تسجيل حضور/انصراف — يتحقق من الرقم السري ويكتب الصف
--    p_action: 'check_in' | 'check_out'
-- ---------------------------------------------------------------------------
create or replace function public.record_attendance(
  p_employee_id uuid,
  p_pin text,
  p_action text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_emp    employees%rowtype;
  v_today  date := (now() at time zone 'Africa/Cairo')::date;
  v_now    timestamptz := now();
  v_row    attendance%rowtype;
begin
  select * into v_emp from employees where id = p_employee_id;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'not_found');
  end if;
  if coalesce(v_emp.is_active, true) = false then
    return jsonb_build_object('ok', false, 'error', 'inactive');
  end if;
  if coalesce(v_emp.attendance_pin, '') = '' then
    return jsonb_build_object('ok', false, 'error', 'no_pin');
  end if;
  if v_emp.attendance_pin <> p_pin then
    return jsonb_build_object('ok', false, 'error', 'wrong_pin');
  end if;

  select * into v_row from attendance
   where employee_id = p_employee_id and work_date = v_today;

  if p_action = 'check_in' then
    if found and v_row.check_in is not null then
      return jsonb_build_object('ok', false, 'error', 'already_checked_in',
        'name', v_emp.name, 'time', v_row.check_in);
    end if;
    if found then
      update attendance set check_in = v_now where id = v_row.id;
    else
      insert into attendance(employee_id, work_date, check_in)
        values (p_employee_id, v_today, v_now);
    end if;
    return jsonb_build_object('ok', true, 'action', 'check_in',
      'name', v_emp.name, 'time', v_now);

  elsif p_action = 'check_out' then
    if not found or v_row.check_in is null then
      return jsonb_build_object('ok', false, 'error', 'not_checked_in', 'name', v_emp.name);
    end if;
    if v_row.check_out is not null then
      return jsonb_build_object('ok', false, 'error', 'already_checked_out',
        'name', v_emp.name, 'time', v_row.check_out);
    end if;
    update attendance set check_out = v_now where id = v_row.id;
    return jsonb_build_object('ok', true, 'action', 'check_out',
      'name', v_emp.name, 'time', v_now);

  else
    return jsonb_build_object('ok', false, 'error', 'bad_action');
  end if;
end;
$$;

revoke all on function public.record_attendance(uuid, text, text) from public;
grant execute on function public.record_attendance(uuid, text, text) to anon, authenticated;
