-- Lerio
-- Student accounts / classes V1 incremental fix
--
-- Fixes pgcrypto function lookup inside security-definer RPCs that use:
--   set search_path = public
--
-- On Supabase, crypt/gen_salt are commonly exposed via the extensions schema,
-- so these calls must be schema-qualified.
--
-- Keep this only for databases that already applied an earlier core patch.
-- New rollouts should use `supabase_student_accounts_v1_core_patch.sql`.

begin;

create or replace function public.create_student_profile(
  p_class_id uuid,
  p_display_name text,
  p_first_name text default null,
  p_last_name text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_student public.student_profiles;
  v_code text;
  v_pin text;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  if not public.is_class_teacher(p_class_id) then
    raise exception 'Class teacher access required';
  end if;

  if nullif(trim(p_display_name), '') is null then
    raise exception 'Student display name is required';
  end if;

  loop
    v_code := public.generate_student_code();
    begin
      insert into public.student_profiles (
        class_id,
        display_name,
        first_name,
        last_name,
        student_code,
        status
      )
      values (
        p_class_id,
        trim(p_display_name),
        nullif(trim(p_first_name), ''),
        nullif(trim(p_last_name), ''),
        v_code,
        'active'
      )
      returning * into v_student;
      exit;
    exception
      when unique_violation then
        null;
    end;
  end loop;

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
  );

  return jsonb_build_object(
    'student_id', v_student.id,
    'display_name', v_student.display_name,
    'student_code', v_student.student_code,
    'pin', v_pin
  );
end;
$$;

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
    'student_id', v_student.id,
    'student_code', v_student.student_code,
    'pin', v_pin
  );
end;
$$;

create or replace function public.student_login_with_pin(
  p_class_code text,
  p_student_code text,
  p_pin text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_class public.classes;
  v_student public.student_profiles;
  v_credentials public.student_credentials;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  select *
  into v_class
  from public.classes c
  where c.class_code = upper(trim(p_class_code))
    and c.status = 'active'
  limit 1;

  if not found then
    raise exception 'Class not found';
  end if;

  select *
  into v_student
  from public.student_profiles sp
  where sp.class_id = v_class.id
    and sp.student_code = upper(trim(p_student_code))
    and sp.status = 'active'
  limit 1;

  if not found then
    raise exception 'Student not found';
  end if;

  select *
  into v_credentials
  from public.student_credentials sc
  where sc.student_id = v_student.id
  limit 1;

  if not found then
    raise exception 'Student credentials not found';
  end if;

  if v_credentials.pin_hash <> extensions.crypt(trim(p_pin), v_credentials.pin_hash) then
    raise exception 'Invalid PIN';
  end if;

  insert into public.student_auth_links (
    student_id,
    auth_user_id,
    created_at,
    last_used_at
  )
  values (
    v_student.id,
    auth.uid(),
    now(),
    now()
  )
  on conflict (auth_user_id) do update
    set student_id = excluded.student_id,
        last_used_at = now();

  return jsonb_build_object(
    'student_id', v_student.id,
    'display_name', v_student.display_name,
    'student_code', v_student.student_code,
    'class_id', v_class.id,
    'class_name', v_class.name,
    'class_code', v_class.class_code,
    'must_reset_pin', v_credentials.must_reset_pin
  );
end;
$$;

commit;
