-- ============================================================================
-- 35 — إصلاح الانصراف في الورديات اللي بتعدّي نص الليل
-- ============================================================================
-- المشكلة:
--   الانصراف كان بيدوّر على صف بتاريخ النهاردة بس. الحلاق يسجّل حضور 8 مساءً
--   يوم 20، وينصرف 1 صباحاً — والتاريخ بقى يوم 21 — فمفيش صف، والدالة ترجع
--   'not_checked_in' والموظف يشوف «لم تسجّل حضور اليوم بعد» ومايقدرش ينصرف
--   خالص. اليوم بتاعه يفضل مفتوح من غير انصراف.
--
-- الحل:
--   لو مفيش صف مفتوح النهاردة، ندوّر على آخر وردية مفتوحة (فيها حضور وملهاش
--   انصراف) بدأت من مدة معقولة. المدة 16 ساعة: بتغطي أطول وردية ليلية، وفي
--   نفس الوقت مابتقفلش يوم قديم نسي الموظف ينصرف فيه ورجع تاني يوم بالليل.
--
--   نفس المنطق في get_attendance_status عشان الشاشة تعرض «سجّل انصراف»
--   مش «سجّل حضور» بعد نص الليل.
--
-- آمن للتشغيل أكثر من مرة.
-- ============================================================================

-- أقصى مدة وردية مفتوحة ينفع نقفلها بأثر رجعي
-- (لو وردية طالت أكتر من كده، المدير يظبطها بإيده)
create or replace function public.attendance_open_shift(p_employee_id uuid)
returns attendance
language sql
stable
security definer
set search_path = public
as $$
  select a.*
    from attendance a
   where a.employee_id = p_employee_id
     and a.check_in is not null
     and a.check_out is null
     and a.check_in >= now() - interval '16 hours'
   order by a.check_in desc
   limit 1;
$$;

revoke all on function public.attendance_open_shift(uuid) from public;
grant execute on function public.attendance_open_shift(uuid) to anon, authenticated;

-- ---------------------------------------------------------------------------
-- حالة اليوم — بترجّع الوردية المفتوحة لو الموظف لسه شغال من امبارح
-- ---------------------------------------------------------------------------
create or replace function public.get_attendance_status(p_employee_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_today date := (now() at time zone 'Africa/Cairo')::date;
  v_row   attendance%rowtype;
begin
  select * into v_row from attendance
   where employee_id = p_employee_id and work_date = v_today;

  -- مفيش صف النهاردة؟ يمكن يكون لسه في وردية ليلية مفتوحة من امبارح
  if not found or v_row.check_in is null then
    select * into v_row from public.attendance_open_shift(p_employee_id);
  end if;

  if not found then
    return jsonb_build_object('check_in', null, 'check_out', null);
  end if;

  return jsonb_build_object(
    'check_in',  v_row.check_in,
    'check_out', v_row.check_out,
    -- عشان الشاشة تنبّه إن دي وردية امبارح
    'work_date', v_row.work_date
  );
end;
$$;

revoke all on function public.get_attendance_status(uuid) from public;
grant execute on function public.get_attendance_status(uuid) to anon, authenticated;

-- ---------------------------------------------------------------------------
-- تسجيل حضور/انصراف
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
  v_found  boolean;
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
  v_found := found;

  if p_action = 'check_in' then
    -- لسه في وردية مفتوحة من امبارح؟ يبقى لازم ينصرف منها الأول،
    -- وإلا اليوم القديم يفضل مفتوح للأبد.
    if not v_found then
      declare v_open attendance%rowtype;
      begin
        select * into v_open from public.attendance_open_shift(p_employee_id);
        if found and v_open.work_date < v_today then
          return jsonb_build_object('ok', false, 'error', 'shift_still_open',
            'name', v_emp.name, 'time', v_open.check_in);
        end if;
      end;
    end if;

    if v_found and v_row.check_in is not null then
      return jsonb_build_object('ok', false, 'error', 'already_checked_in',
        'name', v_emp.name, 'time', v_row.check_in);
    end if;
    if v_found then
      update attendance set check_in = v_now where id = v_row.id;
    else
      insert into attendance(employee_id, work_date, check_in)
        values (p_employee_id, v_today, v_now);
    end if;
    return jsonb_build_object('ok', true, 'action', 'check_in',
      'name', v_emp.name, 'time', v_now);

  elsif p_action = 'check_out' then
    -- ⬅️ الإصلاح: لو مفيش صف النهاردة، دوّر على وردية امبارح المفتوحة
    if not v_found or v_row.check_in is null then
      select * into v_row from public.attendance_open_shift(p_employee_id);
      v_found := found;
    end if;

    -- لسه مفيش؟ يمكن يكون سجّل انصراف الوردية الليلية من شوية وبيحاول تاني.
    -- من غير الجزء ده الرسالة بتطلع «لم تسجّل حضور» وهي غلط ومحيّرة.
    if not v_found or v_row.check_in is null then
      select * into v_row from attendance
       where employee_id = p_employee_id
         and check_out is not null
         and check_out >= now() - interval '16 hours'
       order by check_out desc
       limit 1;
      if found then
        return jsonb_build_object('ok', false, 'error', 'already_checked_out',
          'name', v_emp.name, 'time', v_row.check_out);
      end if;
      return jsonb_build_object('ok', false, 'error', 'not_checked_in', 'name', v_emp.name);
    end if;
    if v_row.check_out is not null then
      return jsonb_build_object('ok', false, 'error', 'already_checked_out',
        'name', v_emp.name, 'time', v_row.check_out);
    end if;

    update attendance set check_out = v_now where id = v_row.id;
    return jsonb_build_object('ok', true, 'action', 'check_out',
      'name', v_emp.name, 'time', v_now,
      'work_date', v_row.work_date);

  else
    return jsonb_build_object('ok', false, 'error', 'bad_action');
  end if;
end;
$$;

revoke all on function public.record_attendance(uuid, text, text) from public;
grant execute on function public.record_attendance(uuid, text, text) to anon, authenticated;

-- ── التحقق ──────────────────────────────────────────────────────────────────
-- أيام مفتوحة (حضور بلا انصراف) — المفروض تقل بعد الإصلاح:
-- select e.name, a.work_date, a.check_in
-- from attendance a join employees e on e.id = a.employee_id
-- where a.check_in is not null and a.check_out is null
-- order by a.work_date desc;
