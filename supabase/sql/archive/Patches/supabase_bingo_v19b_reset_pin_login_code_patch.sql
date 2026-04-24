-- =========================================================
-- V19b patch: reset_student_pin returns login_code
-- Apply to any DB that has v11+ (login_code column exists).
-- =========================================================

create or replace function public.reset_student_pin(p_student_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_student public.student_profiles;
  v_pin text;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  select *
  into v_student
  from public.student_profiles sp
  where sp.id = p_student_id
  limit 1;

  if not found then
    raise exception 'Student not found';
  end if;

  if not public.is_class_teacher(v_student.class_id) then
    raise exception 'Class teacher access required';
  end if;

  v_pin := public.generate_student_pin();

  insert into public.student_credentials (
    student_id,
    pin_hash,
    must_reset_pin
  )
  values (
    v_student.id,
    extensions.crypt(v_pin, extensions.gen_salt('bf')),
    false
  )
  on conflict (student_id) do update
    set pin_hash = excluded.pin_hash,
        must_reset_pin = excluded.must_reset_pin,
        updated_at = now();

  return jsonb_build_object(
    'student_id',   v_student.id,
    'login_code',   v_student.login_code,
    'student_code', v_student.student_code,
    'pin',          v_pin
  );
end;
$$;
