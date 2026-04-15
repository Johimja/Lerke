-- Lerke Bingo & Student Accounts
-- Consolidated Initial Setup (v1-v10)
-- 
-- Use this to set up a fresh Supabase database.
-- Includes: Teacher profiles, Classes, Student accounts, and Bingo Live mechanics.

begin;

-- =========================================================
-- EXTENSIONS & HELPERS
-- =========================================================
create extension if not exists pgcrypto;

create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create or replace function public.generate_code(code_length integer default 6)
returns text language plpgsql as $$
declare
  chars text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  result text := '';
begin
  for i in 1..code_length loop
    result := result || substr(chars, 1 + floor(random() * length(chars))::integer, 1);
  end loop;
  return result;
end;
$$;

-- =========================================================
-- CORE TABLES
-- =========================================================

create table if not exists public.activities (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  name text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.teacher_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  is_teacher boolean not null default false,
  is_approved boolean not null default false,
  approved_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.classes (
  id uuid primary key default gen_random_uuid(),
  teacher_user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  grade_label text,
  school_year text,
  class_code text not null unique,
  status text not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.student_profiles (
  id uuid primary key default gen_random_uuid(),
  class_id uuid not null references public.classes(id) on delete cascade,
  display_name text not null,
  first_name text,
  last_name text,
  student_code text not null,
  status text not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.student_credentials (
  student_id uuid primary key references public.student_profiles(id) on delete cascade,
  pin_hash text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.student_auth_links (
  student_id uuid not null references public.student_profiles(id) on delete cascade,
  auth_user_id uuid primary key references auth.users(id) on delete cascade,
  last_used_at timestamptz not null default now()
);

create table if not exists public.sessions (
  id uuid primary key default gen_random_uuid(),
  activity_slug text not null default 'bingo',
  created_by uuid not null references auth.users(id),
  join_code text not null unique,
  title text,
  status text not null default 'draft',
  settings jsonb not null default '{}'::jsonb,
  last_heartbeat_at timestamptz default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.session_rounds (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.sessions(id) on delete cascade,
  round_number integer not null,
  rounds_data jsonb not null,
  created_at timestamptz not null default now(),
  unique (session_id, round_number)
);

create table if not exists public.session_state (
  session_id uuid primary key references public.sessions(id) on delete cascade,
  phase text not null default 'setup',
  round_number integer not null default 1,
  draw_index integer not null default 0,
  current_draw jsonb,
  current_draw_opened_at timestamptz,
  current_draw_closes_at timestamptz,
  current_draw_locked_at timestamptz,
  updated_at timestamptz not null default now()
);

create table if not exists public.session_participants (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.sessions(id) on delete cascade,
  auth_user_id uuid not null references auth.users(id),
  student_profile_id uuid references public.student_profiles(id),
  display_name text not null,
  role text not null default 'student',
  status text not null default 'active',
  joined_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  unique (session_id, auth_user_id)
);

create table if not exists public.participant_round_boards (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.sessions(id) on delete cascade,
  participant_id uuid not null references public.session_participants(id) on delete cascade,
  round_number integer not null,
  board_cells jsonb not null,
  marked_cells integer[] not null default '{}',
  has_bingo boolean not null default false,
  bingo_at_draw_index integer,
  bingo_count integer not null default 0,
  updated_at timestamptz not null default now(),
  unique (session_id, participant_id, round_number)
);

create table if not exists public.participant_draw_responses (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.sessions(id) on delete cascade,
  participant_id uuid not null references public.session_participants(id) on delete cascade,
  round_number integer not null,
  draw_index integer not null,
  correct boolean not null,
  response_outcome text,
  selected_value text,
  selected_cell_index integer,
  answered_at timestamptz not null default now(),
  unique (session_id, participant_id, round_number, draw_index)
);

create table if not exists public.session_events (
  id bigint generated always as identity primary key,
  session_id uuid not null references public.sessions(id) on delete cascade,
  event_type text not null,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

-- =========================================================
-- AUTH & TEACHER HELPERS
-- =========================================================

create or replace function public.is_teacher()
returns boolean language sql stable security definer as $$
  select exists (
    select 1 from public.teacher_profiles
    where user_id = auth.uid() and is_teacher = true and is_approved = true
  );
$$;

create or replace function public.is_session_teacher(p_session_id uuid)
returns boolean language sql stable security definer as $$
  select exists (
    select 1 from public.sessions
    where id = p_session_id and created_by = auth.uid()
  );
$$;

create or replace function public.is_session_participant(p_session_id uuid)
returns boolean language sql stable security definer as $$
  select exists (
    select 1 from public.session_participants
    where session_id = p_session_id and auth_user_id = auth.uid()
  );
$$;

-- =========================================================
-- TEACHER RPCs
-- =========================================================

create or replace function public.create_bingo_session(
  p_title text,
  p_settings jsonb,
  p_rounds_data jsonb
) returns jsonb language plpgsql security definer as $$
declare
  v_session public.sessions;
  v_code text;
begin
  if not public.is_teacher() then raise exception 'Access denied'; end if;
  loop
    v_code := public.generate_code(6);
    begin
      insert into public.sessions (created_by, join_code, title, status, settings)
      values (auth.uid(), v_code, p_title, 'live', p_settings)
      returning * into v_session;
      exit;
    exception when unique_violation then null; end;
  end loop;

  insert into public.session_rounds (session_id, round_number, rounds_data)
  select v_session.id, (idx - 1) + 1, round_val
  from jsonb_array_elements(p_rounds_data) with ordinality as rounds(round_val, idx);

  insert into public.session_state (session_id, phase, round_number)
  values (v_session.id, 'lobby', 1);

  return jsonb_build_object('id', v_session.id, 'join_code', v_session.join_code, 'title', v_session.title);
end;
$$;

create or replace function public.touch_session_heartbeat(p_session_id uuid)
returns void language plpgsql security definer as $$
begin
  if not public.is_session_teacher(p_session_id) then raise exception 'Unauthorized'; end if;
  update public.sessions set last_heartbeat_at = now() where id = p_session_id;
end;
$$;

-- =========================================================
-- LIVE STATE RPC (V10 CORE)
-- =========================================================

create or replace function public.get_bingo_live_state(p_session_id uuid)
returns jsonb language plpgsql security definer as $$
declare
  v_session public.sessions;
  v_state public.session_state;
  v_participant public.session_participants;
  v_board public.participant_round_boards;
  v_response public.participant_draw_responses;
  v_teacher_summary jsonb;
begin
  select * into v_session from public.sessions where id = p_session_id;
  select * into v_state from public.session_state where session_id = p_session_id;
  select * into v_participant from public.session_participants where session_id = p_session_id and auth_user_id = auth.uid();
  
  if v_participant.id is not null then
    select * into v_board from public.participant_round_boards where session_id = p_session_id and participant_id = v_participant.id and round_number = v_state.round_number;
    select * into v_response from public.participant_draw_responses where session_id = p_session_id and participant_id = v_participant.id and round_number = v_state.round_number and draw_index = v_state.draw_index;
  end if;

  if public.is_session_teacher(p_session_id) then
    select jsonb_build_object(
      'participant_count', (select count(*) from public.session_participants where session_id = p_session_id),
      'bingo_count', (select count(*) from public.participant_round_boards where session_id = p_session_id and round_number = v_state.round_number and has_bingo = true)
    ) into v_teacher_summary;
  end if;

  return jsonb_build_object(
    'session', jsonb_build_object('id', v_session.id, 'join_code', v_session.join_code, 'title', v_session.title, 'host_active', (v_session.last_heartbeat_at > (now() - interval '20 seconds'))),
    'state', v_state,
    'board', v_board,
    'current_response', v_response,
    'teacher_summary', v_teacher_summary
  );
end;
$$;

-- =========================================================
-- TRIGGERS & RLS (MINIMAL)
-- =========================================================
create trigger trg_sessions_updated_at before update on public.sessions for each row execute function public.set_updated_at();

alter table public.teacher_profiles enable row level security;
create policy "Teachers see own profile" on public.teacher_profiles for select using (auth.uid() = user_id);

commit;
