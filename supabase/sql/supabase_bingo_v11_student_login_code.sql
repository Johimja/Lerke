-- =========================================================
-- V11: Student login_code — one-code login
-- =========================================================
-- Adds a globally unique 6-character login_code to each student
-- so they only need ONE code + PIN to log in (no class code, no
-- separate student code). Also adds student_change_pin() so
-- students can set their own PIN after first login.
-- =========================================================

-- =========================================================
-- 1. Generator function
-- =========================================================

create or replace function public.generate_login_code(code_length integer default 6)
returns text
language plpgsql
as $$
declare
  chars  text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  result text := '';
  i      integer;
begin
  for i in 1..code_length loop
    result := result || substr(chars, 1 + floor(random() * length(chars))::integer, 1);
  end loop;
  return result;
end;
$$;

-- =========================================================
-- 2. Add login_code column to student_profiles
-- =========================================================

alter table public.student_profiles
  add column if not exists login_code text unique;

-- =========================================================
-- 3. Backfill existing students
-- =========================================================

do $$
declare
  r      record;
  v_code text;
begin
  for r in select id from public.student_profiles where login_code is null loop
    loop
      v_code := public.generate_login_code();
      begin
        update public.student_profiles set login_code = v_code where id = r.id;
        exit;
      exception when unique_violation then
        null; -- try again
      end;
    end loop;
  end loop;
end;
$$;

-- Now enforce not null
alter table public.student_profiles
  alter column login_code set not null;

create index if not exists idx_student_profiles_login_code
  on public.student_profiles(login_code);

-- =========================================================
-- 4. create_student_profile — now generates login_code too
-- =========================================================

create or replace function public.create_student_profile(
  p_class_id    uuid,
  p_display_name text,
  p_first_name  text default null,
  p_last_name   text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_student    public.student_profiles;
  v_code       text;
  v_login_code text;
  v_pin        text;
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

  -- Generate unique student_code within the class
  loop
    v_code := public.generate_student_code();
    begin
      -- Generate unique global login_code
      loop
        v_login_code := public.generate_login_code();
        exit when not exists (
          select 1 from public.student_profiles where login_code = v_login_code
        );
      end loop;

      insert into public.student_profiles (
        class_id,
        display_name,
        first_name,
        last_name,
        student_code,
        login_code,
        status
      )
      values (
        p_class_id,
        trim(p_display_name),
        nullif(trim(p_first_name), ''),
        nullif(trim(p_last_name), ''),
        v_code,
        v_login_code,
        'active'
      )
      returning * into v_student;
      exit;
    exception when unique_violation then
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
    'student_id',   v_student.id,
    'display_name', v_student.display_name,
    'login_code',   v_student.login_code,
    'student_code', v_student.student_code,
    'pin',          v_pin
  );
end;
$$;

-- =========================================================
-- 5. get_current_student_profile — include login_code
-- =========================================================

create or replace function public.get_current_student_profile()
returns jsonb
language sql
security definer
set search_path = public
as $$
  select jsonb_build_object(
    'student_id',   sp.id,
    'display_name', sp.display_name,
    'login_code',   sp.login_code,
    'student_code', sp.student_code,
    'class_id',     c.id,
    'class_name',   c.name,
    'class_code',   c.class_code
  )
  from public.student_auth_links sal
  join public.student_profiles sp on sp.id = sal.student_id
  join public.classes          c  on c.id  = sp.class_id
  where sal.auth_user_id = auth.uid()
    and sp.status = 'active'
    and c.status  = 'active'
  limit 1;
$$;

-- =========================================================
-- 6. student_login_with_code — one code + PIN login
-- =========================================================

create or replace function public.student_login_with_code(
  p_login_code text,
  p_pin        text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_student     public.student_profiles;
  v_class       public.classes;
  v_credentials public.student_credentials;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  select sp.*
  into v_student
  from public.student_profiles sp
  where sp.login_code = upper(trim(p_login_code))
    and sp.status = 'active'
  limit 1;

  if not found then
    raise exception 'Ugyldig elevkode';
  end if;

  select c.*
  into v_class
  from public.classes c
  where c.id = v_student.class_id
    and c.status = 'active'
  limit 1;

  if not found then
    raise exception 'Klasse ikke aktiv';
  end if;

  select sc.*
  into v_credentials
  from public.student_credentials sc
  where sc.student_id = v_student.id
  limit 1;

  if not found then
    raise exception 'Ingen PIN funnet for denne eleven';
  end if;

  if v_credentials.pin_hash <> extensions.crypt(trim(p_pin), v_credentials.pin_hash) then
    raise exception 'Feil PIN';
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
    set student_id   = excluded.student_id,
        last_used_at = now();

  return jsonb_build_object(
    'student_id',    v_student.id,
    'display_name',  v_student.display_name,
    'login_code',    v_student.login_code,
    'student_code',  v_student.student_code,
    'class_id',      v_class.id,
    'class_name',    v_class.name,
    'class_code',    v_class.class_code,
    'must_reset_pin', v_credentials.must_reset_pin
  );
end;
$$;

-- =========================================================
-- 7. student_change_pin — student sets their own PIN
-- =========================================================

create or replace function public.student_change_pin(
  p_current_pin text,
  p_new_pin     text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_student_id  uuid;
  v_credentials public.student_credentials;
  v_new_hash    text;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  -- Find student linked to this session
  select sal.student_id
  into v_student_id
  from public.student_auth_links sal
  join public.student_profiles sp on sp.id = sal.student_id
  where sal.auth_user_id = auth.uid()
    and sp.status = 'active'
  limit 1;

  if not found then
    raise exception 'Ingen elevkonto funnet for denne økten';
  end if;

  select sc.*
  into v_credentials
  from public.student_credentials sc
  where sc.student_id = v_student_id
  limit 1;

  if not found then
    raise exception 'Ingen PIN funnet';
  end if;

  if v_credentials.pin_hash <> extensions.crypt(trim(p_current_pin), v_credentials.pin_hash) then
    raise exception 'Nåværende PIN er feil';
  end if;

  if length(trim(p_new_pin)) < 4 then
    raise exception 'Ny PIN må være minst 4 tegn';
  end if;

  v_new_hash := extensions.crypt(trim(p_new_pin), extensions.gen_salt('bf'));

  update public.student_credentials
  set pin_hash       = v_new_hash,
      must_reset_pin = false,
      updated_at     = now()
  where student_id = v_student_id;

  return jsonb_build_object('ok', true);
end;
$$;

-- =========================================================
-- 8. Permissions
-- =========================================================

revoke all on function public.generate_login_code(integer)          from public;
revoke all on function public.student_login_with_code(text, text)   from public;
revoke all on function public.student_change_pin(text, text)        from public;

grant execute on function public.generate_login_code(integer)        to authenticated;
grant execute on function public.student_login_with_code(text, text) to authenticated;
grant execute on function public.student_change_pin(text, text)      to authenticated;
