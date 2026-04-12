-- Lerke
-- Student accounts / classes V1 draft
--
-- Draft only.
-- Do not run this blindly in production.
-- This file is for architecture direction and schema discussion.

begin;

create extension if not exists pgcrypto;

-- =========================================================
-- Classes
-- =========================================================

create table if not exists public.classes (
  id uuid primary key default gen_random_uuid(),
  teacher_user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  grade_label text,
  school_year text,
  class_code text not null unique,
  status text not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint classes_status_check
    check (status in ('active', 'archived'))
);

create index if not exists idx_classes_teacher_user_id
  on public.classes(teacher_user_id);

create index if not exists idx_classes_class_code
  on public.classes(class_code);

-- =========================================================
-- Student profiles
-- =========================================================

create table if not exists public.student_profiles (
  id uuid primary key default gen_random_uuid(),
  class_id uuid not null references public.classes(id) on delete cascade,
  display_name text not null,
  first_name text,
  last_name text,
  student_code text not null,
  status text not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint student_profiles_status_check
    check (status in ('active', 'inactive'))
);

create unique index if not exists idx_student_profiles_class_student_code
  on public.student_profiles(class_id, student_code);

create index if not exists idx_student_profiles_class_id
  on public.student_profiles(class_id);

-- =========================================================
-- Student credentials
-- =========================================================

create table if not exists public.student_credentials (
  student_id uuid primary key references public.student_profiles(id) on delete cascade,
  pin_hash text,
  must_reset_pin boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- =========================================================
-- Optional student auth link
-- =========================================================

create table if not exists public.student_auth_links (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references public.student_profiles(id) on delete cascade,
  auth_user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  last_used_at timestamptz not null default now(),
  unique (student_id, auth_user_id),
  unique (auth_user_id)
);

create index if not exists idx_student_auth_links_student_id
  on public.student_auth_links(student_id);

-- =========================================================
-- Bridge to live session participants
-- =========================================================

alter table public.session_participants
  add column if not exists student_profile_id uuid references public.student_profiles(id) on delete set null;

create index if not exists idx_session_participants_student_profile_id
  on public.session_participants(student_profile_id);

-- =========================================================
-- Helpers
-- =========================================================

create or replace function public.generate_class_code(code_length integer default 6)
returns text
language plpgsql
as $$
declare
  chars text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  result text := '';
  i integer;
begin
  for i in 1..code_length loop
    result := result || substr(chars, 1 + floor(random() * length(chars))::integer, 1);
  end loop;
  return result;
end;
$$;

create or replace function public.generate_student_code(code_length integer default 5)
returns text
language plpgsql
as $$
declare
  chars text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  result text := '';
  i integer;
begin
  for i in 1..code_length loop
    result := result || substr(chars, 1 + floor(random() * length(chars))::integer, 1);
  end loop;
  return result;
end;
$$;

create or replace function public.generate_student_pin(pin_length integer default 4)
returns text
language plpgsql
as $$
declare
  chars text := '23456789';
  result text := '';
  i integer;
begin
  for i in 1..pin_length loop
    result := result || substr(chars, 1 + floor(random() * length(chars))::integer, 1);
  end loop;
  return result;
end;
$$;

create or replace function public.is_class_teacher(target_class_id uuid)
returns boolean
language sql
stable
as $$
  select exists (
    select 1
    from public.classes c
    join public.teacher_profiles tp on tp.user_id = c.teacher_user_id
    where c.id = target_class_id
      and c.teacher_user_id = auth.uid()
      and tp.is_teacher = true
      and tp.is_approved = true
  );
$$;

create or replace function public.create_class(
  p_name text,
  p_grade_label text default null,
  p_school_year text default null
)
returns public.classes
language plpgsql
security definer
set search_path = public
as $$
declare
  v_class public.classes;
  v_code text;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  if not public.is_teacher() then
    raise exception 'Approved teacher required';
  end if;

  loop
    v_code := public.generate_class_code();
    begin
      insert into public.classes (
        teacher_user_id,
        name,
        grade_label,
        school_year,
        class_code,
        status
      )
      values (
        auth.uid(),
        nullif(trim(p_name), ''),
        nullif(trim(p_grade_label), ''),
        nullif(trim(p_school_year), ''),
        v_code,
        'active'
      )
      returning * into v_class;
      exit;
    exception
      when unique_violation then
        null;
    end;
  end loop;

  return v_class;
end;
$$;

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
        nullif(trim(p_display_name), ''),
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
    crypt(v_pin, gen_salt('bf')),
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

create or replace function public.list_class_students(p_class_id uuid)
returns setof public.student_profiles
language sql
security definer
set search_path = public
as $$
  select sp.*
  from public.student_profiles sp
  where sp.class_id = p_class_id
    and public.is_class_teacher(p_class_id)
  order by sp.display_name asc, sp.created_at asc;
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
    crypt(v_pin, gen_salt('bf')),
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

  if v_credentials.pin_hash is null or v_credentials.pin_hash <> crypt(trim(p_pin), v_credentials.pin_hash) then
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

create or replace function public.get_current_student_profile()
returns jsonb
language sql
security definer
set search_path = public
as $$
  select jsonb_build_object(
    'student_id', sp.id,
    'display_name', sp.display_name,
    'student_code', sp.student_code,
    'class_id', c.id,
    'class_name', c.name,
    'class_code', c.class_code
  )
  from public.student_auth_links sal
  join public.student_profiles sp on sp.id = sal.student_id
  join public.classes c on c.id = sp.class_id
  where sal.auth_user_id = auth.uid()
    and sp.status = 'active'
    and c.status = 'active'
  limit 1;
$$;

-- =========================================================
-- Draft note
-- =========================================================

-- This draft intentionally does not include:
-- - final RLS policies
-- - final teacher UI implementation
-- 
-- This draft now assumes the chosen first student login model:
-- - class code + student code + PIN
-- while anonymous guest sessions remain supported separately.
--
-- Current draft RPC direction for student login:
-- - student first gets a technical auth session
-- - then calls `student_login_with_pin(...)`
-- - this links `auth.uid()` to a persistent `student_profiles` row
-- - `get_current_student_profile()` can restore learner context later
--
-- See docs/STUDENT_CLASS_SCHEMA_DRAFT.md for the product/architecture rationale.

rollback;
