-- =========================================================
-- Lerke Bingo — Fresh Install v18
-- =========================================================
-- Consolidated for brand new Supabase installs.
-- Built from server_initial_setup.sql plus post-v10 feature patches.
-- Contains schema, policies, helper functions, and RPCs only.
-- No project-specific secrets, hostnames, or personal data should live here.
-- =========================================================

-- >>> BEGIN FILE: server_initial_setup.sql
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
-- <<< END FILE: server_initial_setup.sql

-- >>> BEGIN FILE: supabase_bingo_v11_student_login_code.sql
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
-- <<< END FILE: supabase_bingo_v11_student_login_code.sql

-- >>> BEGIN FILE: supabase_bingo_v12_xp_levels.sql
-- =========================================================
-- V12: XP and level system
-- =========================================================
-- Adds total_xp to student_profiles.
-- submit_bingo_answer awards XP to logged-in students:
--   +10 XP per correct answer
--   +50 XP when first bingo in a round is achieved
-- get_current_student_profile now returns total_xp and level.
-- Level = floor(total_xp / 100) + 1  (simple, predictable)
-- =========================================================

-- =========================================================
-- 1. Add total_xp column
-- =========================================================

alter table public.student_profiles
  add column if not exists total_xp integer not null default 0;

-- =========================================================
-- 2. Immutable helper: XP → level
-- =========================================================

create or replace function public.xp_to_level(p_xp integer)
returns integer
language sql
immutable
as $$
  select (p_xp / 100) + 1;
$$;

grant execute on function public.xp_to_level(integer) to authenticated, anon;

-- =========================================================
-- 3. Replace submit_bingo_answer to award XP
-- =========================================================

create or replace function public.submit_bingo_answer(
  p_session_id uuid,
  p_selected_cell_index integer,
  p_selected_value text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_state        public.session_state;
  v_participant  public.session_participants;
  v_board        public.participant_round_boards;
  v_expected_answer text;
  v_correct      boolean;
  v_marked_cells jsonb;
  v_response     public.participant_draw_responses;
  v_xp_gained    integer := 0;
  v_new_total_xp integer;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  if p_selected_cell_index < 0 or p_selected_cell_index >= 25 then
    raise exception 'Selected cell index out of range';
  end if;

  select *
  into v_participant
  from public.session_participants sp
  where sp.session_id = p_session_id
    and sp.auth_user_id = auth.uid()
    and sp.status in ('active', 'inactive')
  limit 1;

  if not found then
    raise exception 'Participant not found';
  end if;

  select *
  into v_state
  from public.session_state
  where session_id = p_session_id
  limit 1;

  if not found then
    raise exception 'Session state not found';
  end if;

  if v_state.phase <> 'draw_open' then
    raise exception 'Draw is not open';
  end if;

  if v_state.current_draw_closes_at is not null and now() > v_state.current_draw_closes_at then
    raise exception 'Draw has already timed out';
  end if;

  select *
  into v_board
  from public.participant_round_boards prb
  where prb.session_id = p_session_id
    and prb.participant_id = v_participant.id
    and prb.round_number = v_state.round_number
  limit 1;

  if not found then
    raise exception 'Board not found for current round';
  end if;

  if exists (
    select 1
    from public.participant_draw_responses pdr
    where pdr.session_id = p_session_id
      and pdr.participant_id = v_participant.id
      and pdr.round_number = v_state.round_number
      and pdr.draw_index = v_state.draw_index
  ) then
    raise exception 'Answer already submitted for this draw';
  end if;

  if coalesce(v_board.board_cells ->> p_selected_cell_index, '') <> coalesce(p_selected_value, '') then
    raise exception 'Selected cell value does not match stored board';
  end if;

  v_expected_answer := coalesce(v_state.current_draw->>'answer', '');
  if jsonb_typeof(coalesce(v_state.current_draw->'correct_answers', 'null'::jsonb)) = 'array' then
    select exists (
      select 1
      from jsonb_array_elements_text(v_state.current_draw->'correct_answers') as allowed(value)
      where allowed.value = coalesce(p_selected_value, '')
    )
    into v_correct;
  else
    v_correct := coalesce(p_selected_value, '') = v_expected_answer;
  end if;

  insert into public.participant_draw_responses (
    session_id,
    participant_id,
    round_number,
    draw_index,
    selected_cell_index,
    selected_value,
    response_outcome,
    correct,
    answered_at
  )
  values (
    p_session_id,
    v_participant.id,
    v_state.round_number,
    v_state.draw_index,
    p_selected_cell_index,
    p_selected_value,
    case when v_correct then 'correct' else 'wrong' end,
    v_correct,
    now()
  )
  returning * into v_response;

  if v_correct then
    v_marked_cells := coalesce(v_board.marked_cells, '[]'::jsonb);

    if not (v_marked_cells @> jsonb_build_array(p_selected_cell_index)) then
      v_marked_cells := v_marked_cells || jsonb_build_array(p_selected_cell_index);
    end if;

    update public.participant_round_boards
    set marked_cells = v_marked_cells,
        has_bingo = public.board_has_bingo(v_marked_cells),
        bingo_count = case
          when public.board_has_bingo(v_marked_cells) and has_bingo = false then bingo_count + 1
          else bingo_count
        end,
        bingo_at_draw_index = case
          when public.board_has_bingo(v_marked_cells) and has_bingo = false then v_state.draw_index
          else bingo_at_draw_index
        end
    where id = v_board.id
    returning * into v_board;

    -- Award XP to linked student profile
    if v_participant.student_profile_id is not null then
      v_xp_gained := 10; -- correct answer XP
      -- Bonus XP for first bingo this round
      if v_board.has_bingo and v_board.bingo_count = 1 then
        v_xp_gained := v_xp_gained + 50;
      end if;
      update public.student_profiles
      set total_xp = total_xp + v_xp_gained
      where id = v_participant.student_profile_id
      returning total_xp into v_new_total_xp;
    end if;
  end if;

  insert into public.session_events (
    session_id,
    event_type,
    actor_user_id,
    payload
  )
  values (
    p_session_id,
    'answer_submitted',
    auth.uid(),
    jsonb_build_object(
      'participant_id', v_participant.id,
      'round_number', v_state.round_number,
      'draw_index', v_state.draw_index,
      'response_outcome', v_response.response_outcome,
      'correct', v_response.correct
    )
  );

  return jsonb_build_object(
    'response_outcome', v_response.response_outcome,
    'correct', v_response.correct,
    'round_number', v_state.round_number,
    'draw_index', v_state.draw_index,
    'marked_cells', coalesce(v_board.marked_cells, '[]'::jsonb),
    'has_bingo', coalesce(v_board.has_bingo, false),
    'bingo_count', coalesce(v_board.bingo_count, 0),
    'xp_gained', v_xp_gained,
    'total_xp', coalesce(v_new_total_xp, 0),
    'level', public.xp_to_level(coalesce(v_new_total_xp, 0))
  );
end;
$$;

-- =========================================================
-- 4. Replace get_current_student_profile to include XP + level
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
    'class_code',   c.class_code,
    'total_xp',     coalesce(sp.total_xp, 0),
    'level',        public.xp_to_level(coalesce(sp.total_xp, 0))
  )
  from public.student_auth_links sal
  join public.student_profiles sp on sp.id = sal.student_id
  join public.classes          c  on c.id  = sp.class_id
  where sal.auth_user_id = auth.uid()
    and sp.status = 'active'
    and c.status  = 'active'
  limit 1;
$$;

grant execute on function public.get_current_student_profile() to authenticated, anon;
-- <<< END FILE: supabase_bingo_v12_xp_levels.sql

-- >>> BEGIN FILE: supabase_bingo_v13_avatars.sql
-- =========================================================
-- V13: Student avatar system
-- =========================================================
-- Adds avatar_data (jsonb) to student_profiles.
-- avatar_data shape: { "color": "#hex", "accessory": "none|crown|star|lightning" }
-- New RPCs:
--   save_student_avatar(p_avatar_data) — student saves own avatar
--   get_session_student_avatars(p_session_id) — teacher fetches name→avatar map
-- get_current_student_profile updated to include avatar_data.
-- =========================================================

-- =========================================================
-- 1. Add avatar_data column
-- =========================================================

alter table public.student_profiles
  add column if not exists avatar_data jsonb default null;

-- =========================================================
-- 2. RPC: student saves own avatar
-- =========================================================

create or replace function public.save_student_avatar(p_avatar_data jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.student_profiles
  set avatar_data = p_avatar_data
  where id = (
    select student_id from public.student_auth_links
    where auth_user_id = auth.uid()
    limit 1
  );
  if not found then
    raise exception 'Student profile not found';
  end if;
  return jsonb_build_object('ok', true);
end;
$$;

grant execute on function public.save_student_avatar(jsonb) to authenticated, anon;

-- =========================================================
-- 3. RPC: teacher fetches avatars for all session participants
-- =========================================================

create or replace function public.get_session_student_avatars(p_session_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_result jsonb;
begin
  select jsonb_object_agg(sp.display_name, coalesce(sp.avatar_data, 'null'::jsonb))
  into v_result
  from public.session_participants part
  join public.student_profiles sp on sp.id = part.student_profile_id
  where part.session_id = p_session_id
    and part.student_profile_id is not null;
  return coalesce(v_result, '{}'::jsonb);
end;
$$;

grant execute on function public.get_session_student_avatars(uuid) to authenticated, anon;

-- =========================================================
-- 4. Update get_current_student_profile to include avatar_data
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
    'class_code',   c.class_code,
    'total_xp',     coalesce(sp.total_xp, 0),
    'level',        public.xp_to_level(coalesce(sp.total_xp, 0)),
    'avatar_data',  sp.avatar_data
  )
  from public.student_auth_links sal
  join public.student_profiles sp on sp.id = sal.student_id
  join public.classes          c  on c.id  = sp.class_id
  where sal.auth_user_id = auth.uid()
    and sp.status = 'active'
    and c.status  = 'active'
  limit 1;
$$;

grant execute on function public.get_current_student_profile() to authenticated, anon;
-- <<< END FILE: supabase_bingo_v13_avatars.sql

-- >>> BEGIN FILE: supabase_bingo_v14_hall_of_fame.sql
-- =========================================================
-- V14: Student stats + class hall of fame
-- =========================================================
-- New RPCs:
--   get_student_stats() — returns rounds_played, rounds_won,
--       longest_win_streak, podium_count (top-3 finishes),
--       sessions_played for the logged-in student.
--   get_class_hall_of_fame(p_class_id) — teacher-facing leaderboard
--       for all students in a class, sorted by rounds_won desc.
-- No schema changes needed — uses existing tables.
-- =========================================================

-- =========================================================
-- 1. RPC: student fetches own lifetime stats
-- =========================================================

create or replace function public.get_student_stats()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_student_id uuid;
  v_rounds_played integer;
  v_rounds_won integer;
  v_podium_count integer;
  v_sessions_played integer;
  v_longest_streak integer;
begin
  -- Resolve student_id from auth session
  select student_id into v_student_id
  from public.student_auth_links
  where auth_user_id = auth.uid()
  limit 1;

  if v_student_id is null then
    raise exception 'Student profile not found';
  end if;

  -- Basic counts
  select
    count(*)::integer,
    count(*) filter (where prb.has_bingo = true)::integer
  into v_rounds_played, v_rounds_won
  from public.participant_round_boards prb
  join public.session_participants sp on sp.id = prb.participant_id
  where sp.student_profile_id = v_student_id;

  -- Top-3 (podium) count: rounds where bingo_at_draw_index is in top 3 for that session+round
  select count(*)::integer into v_podium_count
  from (
    select prb.id,
           rank() over (
             partition by prb.session_id, prb.round_number
             order by prb.bingo_at_draw_index asc nulls last
           ) as rnk
    from public.participant_round_boards prb
    join public.session_participants sp on sp.id = prb.participant_id
    where sp.student_profile_id = v_student_id
      and prb.has_bingo = true
      and prb.bingo_at_draw_index is not null
  ) sub
  where sub.rnk <= 3;

  -- Sessions played (distinct sessions)
  select count(distinct sp.session_id)::integer into v_sessions_played
  from public.session_participants sp
  where sp.student_profile_id = v_student_id;

  -- Longest win streak (consecutive rounds across all sessions, ordered chronologically)
  select coalesce(max(streak_len), 0)::integer into v_longest_streak
  from (
    select count(*) as streak_len
    from (
      select has_bingo,
             rn - row_number() over (partition by has_bingo order by rn) as grp
      from (
        select prb.has_bingo,
               row_number() over (
                 order by s.created_at, prb.round_number
               ) as rn
        from public.participant_round_boards prb
        join public.session_participants sp on sp.id = prb.participant_id
        join public.sessions s on s.id = prb.session_id
        where sp.student_profile_id = v_student_id
      ) ordered
    ) grouped
    where has_bingo = true
    group by grp
  ) streaks;

  return jsonb_build_object(
    'rounds_played',      v_rounds_played,
    'rounds_won',         v_rounds_won,
    'podium_count',       v_podium_count,
    'sessions_played',    v_sessions_played,
    'longest_win_streak', v_longest_streak
  );
end;
$$;

grant execute on function public.get_student_stats() to authenticated, anon;

-- =========================================================
-- 2. RPC: class hall of fame (teacher-facing)
-- =========================================================

create or replace function public.get_class_hall_of_fame(p_class_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_result jsonb;
begin
  select coalesce(jsonb_agg(row_data order by (row_data->>'rounds_won')::int desc, (row_data->>'total_xp')::int desc), '[]'::jsonb)
  into v_result
  from (
    select jsonb_build_object(
      'display_name',       sp.display_name,
      'total_xp',           coalesce(sp.total_xp, 0),
      'level',              public.xp_to_level(coalesce(sp.total_xp, 0)),
      'rounds_played',      coalesce(counts.rounds_played, 0),
      'rounds_won',         coalesce(counts.rounds_won, 0),
      'sessions_played',    coalesce(counts.sessions_played, 0),
      'avatar_data',        sp.avatar_data
    ) as row_data
    from public.student_profiles sp
    left join lateral (
      select
        count(prb.id)::int as rounds_played,
        count(prb.id) filter (where prb.has_bingo = true)::int as rounds_won,
        count(distinct part.session_id)::int as sessions_played
      from public.session_participants part
      join public.participant_round_boards prb on prb.participant_id = part.id
      where part.student_profile_id = sp.id
    ) counts on true
    where sp.class_id = p_class_id
      and sp.status = 'active'
  ) sub;

  return v_result;
end;
$$;

grant execute on function public.get_class_hall_of_fame(uuid) to authenticated, anon;
-- <<< END FILE: supabase_bingo_v14_hall_of_fame.sql

-- >>> BEGIN FILE: supabase_bingo_v16_comeback_wildcard.sql
-- =========================================================
-- V16: Comeback wildcard
-- =========================================================
-- New RPC: use_comeback_wildcard(p_session_id, p_cell_index)
-- Marks any cell on the student's current-round board without
-- requiring a matching draw. No XP awarded. Returns updated
-- marked_cells, has_bingo, bingo_count.
-- The wildcard is granted and tracked client-side after 3
-- consecutive non-correct draws; this RPC just applies it.
-- =========================================================

create or replace function public.use_comeback_wildcard(
  p_session_id uuid,
  p_cell_index integer
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_participant  public.session_participants;
  v_state        public.session_state;
  v_board        public.participant_round_boards;
  v_marked_cells jsonb;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  if p_cell_index < 0 or p_cell_index >= 25 then
    raise exception 'Cell index out of range';
  end if;

  select *
  into v_participant
  from public.session_participants sp
  where sp.session_id = p_session_id
    and sp.auth_user_id = auth.uid()
    and sp.status in ('active', 'inactive')
  limit 1;

  if not found then
    raise exception 'Participant not found';
  end if;

  select *
  into v_state
  from public.session_state
  where session_id = p_session_id
  limit 1;

  if not found then
    raise exception 'Session state not found';
  end if;

  select *
  into v_board
  from public.participant_round_boards prb
  where prb.session_id = p_session_id
    and prb.participant_id = v_participant.id
    and prb.round_number = v_state.round_number
  limit 1;

  if not found then
    raise exception 'Board not found for current round';
  end if;

  v_marked_cells := coalesce(v_board.marked_cells, '[]'::jsonb);

  if not (v_marked_cells @> jsonb_build_array(p_cell_index)) then
    v_marked_cells := v_marked_cells || jsonb_build_array(p_cell_index);
  end if;

  update public.participant_round_boards
  set marked_cells = v_marked_cells,
      has_bingo = public.board_has_bingo(v_marked_cells),
      bingo_count = case
        when public.board_has_bingo(v_marked_cells) and has_bingo = false then bingo_count + 1
        else bingo_count
      end,
      bingo_at_draw_index = case
        when public.board_has_bingo(v_marked_cells) and has_bingo = false then v_state.draw_index
        else bingo_at_draw_index
      end
  where id = v_board.id
  returning * into v_board;

  return jsonb_build_object(
    'marked_cells', v_board.marked_cells,
    'has_bingo',    coalesce(v_board.has_bingo, false),
    'bingo_count',  coalesce(v_board.bingo_count, 0)
  );
end;
$$;

grant execute on function public.use_comeback_wildcard(uuid, integer) to authenticated, anon;
-- <<< END FILE: supabase_bingo_v16_comeback_wildcard.sql

-- >>> BEGIN FILE: supabase_bingo_v17_avatar_shop.sql
-- =========================================================
-- V17: Spritesheet avatar shop — XP-unlockable items
-- =========================================================
-- Spritesheet: /media/avatar_faceshapes.png (1024×1280, 4 cols × 5 rows, 256×256/cell)
-- Category: head / face-shape silhouettes
-- avatar_data shape changes to: { "head": "head_basic" }
-- New columns / RPCs:
--   unlocked_avatar_items text[]  — paid items purchased by this student
--   get_avatar_item_cost(p_item_key) — immutable helper, returns XP cost or null for invalid key
--   purchase_avatar_item(p_item_key) — deducts XP, adds to unlocked list
--   get_current_student_profile updated to include unlocked_avatar_items
-- =========================================================

-- =========================================================
-- 1. Add unlocked_avatar_items column
-- =========================================================

alter table public.student_profiles
  add column if not exists unlocked_avatar_items text[] default '{}';

-- =========================================================
-- 2. Immutable cost helper (used server-side for validation)
-- =========================================================

create or replace function public.get_avatar_item_cost(p_item_key text)
returns int
language sql
immutable
security definer
set search_path = public
as $$
  select case p_item_key
    when 'head_basic'          then 0
    when 'head_flat_top'       then 0
    when 'head_widows_peak'    then 50
    when 'head_crew'           then 50
    when 'head_bun'            then 75
    when 'head_bob'            then 75
    when 'head_long'           then 100
    when 'head_side_part'      then 100
    when 'head_wavy'           then 125
    when 'head_spiky'          then 125
    when 'head_afro'           then 300
    when 'head_pigtails'       then 150
    when 'head_full_beard'     then 175
    when 'head_goatee'         then 150
    when 'head_mohawk'         then 225
    when 'head_hat'            then 200
    when 'head_hood'           then 250
    when 'head_helmet'         then 275
    when 'head_cap'            then 175
    when 'head_flat_top_beard' then 300
    else null  -- invalid / unknown item
  end;
$$;

grant execute on function public.get_avatar_item_cost(text) to authenticated, anon;

-- =========================================================
-- 3. RPC: purchase (and unlock) an avatar item with XP
-- =========================================================

create or replace function public.purchase_avatar_item(p_item_key text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_student_id uuid;
  v_cost       int;
  v_current_xp int;
  v_unlocked   text[];
begin
  v_cost := public.get_avatar_item_cost(p_item_key);

  if v_cost is null then
    return jsonb_build_object('ok', false, 'error', 'Ugyldig gjenstand');
  end if;

  -- Free items are always available, nothing to purchase
  if v_cost = 0 then
    return jsonb_build_object('ok', true, 'free', true);
  end if;

  -- Resolve student
  select sal.student_id into v_student_id
  from public.student_auth_links sal
  where sal.auth_user_id = auth.uid()
  limit 1;

  if v_student_id is null then
    return jsonb_build_object('ok', false, 'error', 'Ikke innlogget');
  end if;

  select total_xp, coalesce(unlocked_avatar_items, '{}')
  into v_current_xp, v_unlocked
  from public.student_profiles
  where id = v_student_id;

  -- Already owned — no charge
  if p_item_key = any(v_unlocked) then
    return jsonb_build_object('ok', true, 'already_owned', true, 'total_xp', v_current_xp, 'unlocked_avatar_items', to_jsonb(v_unlocked));
  end if;

  if v_current_xp < v_cost then
    return jsonb_build_object('ok', false, 'error', 'Ikke nok XP', 'total_xp', v_current_xp, 'needed', v_cost);
  end if;

  update public.student_profiles
  set total_xp             = total_xp - v_cost,
      unlocked_avatar_items = array_append(coalesce(unlocked_avatar_items, '{}'), p_item_key)
  where id = v_student_id
  returning total_xp, unlocked_avatar_items into v_current_xp, v_unlocked;

  return jsonb_build_object(
    'ok',                   true,
    'total_xp',             v_current_xp,
    'unlocked_avatar_items', to_jsonb(v_unlocked),
    'xp_spent',             v_cost
  );
end;
$$;

grant execute on function public.purchase_avatar_item(text) to authenticated, anon;

-- =========================================================
-- 4. Update get_current_student_profile to include unlocked_avatar_items
-- =========================================================

create or replace function public.get_current_student_profile()
returns jsonb
language sql
security definer
set search_path = public
as $$
  select jsonb_build_object(
    'student_id',            sp.id,
    'display_name',          sp.display_name,
    'login_code',            sp.login_code,
    'student_code',          sp.student_code,
    'class_id',              c.id,
    'class_name',            c.name,
    'class_code',            c.class_code,
    'total_xp',              coalesce(sp.total_xp, 0),
    'level',                 public.xp_to_level(coalesce(sp.total_xp, 0)),
    'avatar_data',           sp.avatar_data,
    'unlocked_avatar_items', coalesce(sp.unlocked_avatar_items, '{}')
  )
  from public.student_auth_links sal
  join public.student_profiles sp on sp.id = sal.student_id
  join public.classes          c  on c.id  = sp.class_id
  where sal.auth_user_id = auth.uid()
    and sp.status = 'active'
    and c.status  = 'active'
  limit 1;
$$;

grant execute on function public.get_current_student_profile() to authenticated, anon;
-- <<< END FILE: supabase_bingo_v17_avatar_shop.sql

-- >>> BEGIN FILE: supabase_bingo_v18_teaching_word_lists.sql
-- ============================================================
-- Lerke Bingo v18 — Cloud-saved teaching word lists
-- Allows teachers to save/load word lists across sessions and devices.
-- ============================================================

-- Table: teacher_word_lists
create table if not exists teacher_word_lists (
  id          uuid        primary key default gen_random_uuid(),
  teacher_id  uuid        references auth.users(id) on delete cascade not null,
  name        text        not null,
  words       jsonb       not null,
  game_mode   text        not null default 'glose',
  times_used  integer     not null default 0,
  last_used_at timestamptz,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  unique(teacher_id, name)
);

alter table teacher_word_lists enable row level security;

drop policy if exists "teacher_word_lists_own" on teacher_word_lists;
create policy "teacher_word_lists_own" on teacher_word_lists
  for all
  using  (auth.uid() = teacher_id)
  with check (auth.uid() = teacher_id);

-- RPC: upsert a word list
create or replace function save_teacher_word_list(
  p_name      text,
  p_words     jsonb,
  p_game_mode text default 'glose'
)
returns jsonb
language plpgsql security definer
as $$
begin
  insert into teacher_word_lists (teacher_id, name, words, game_mode, updated_at)
  values (auth.uid(), p_name, p_words, p_game_mode, now())
  on conflict (teacher_id, name) do update
    set words      = excluded.words,
        game_mode  = excluded.game_mode,
        updated_at = now();
  return jsonb_build_object('ok', true);
end;
$$;

-- RPC: get all word lists for the current teacher
create or replace function get_teacher_word_lists()
returns table(
  name         text,
  words        jsonb,
  game_mode    text,
  times_used   integer,
  last_used_at timestamptz,
  updated_at   timestamptz
)
language plpgsql security definer
as $$
begin
  return query
  select
    wl.name,
    wl.words,
    wl.game_mode,
    wl.times_used,
    wl.last_used_at,
    wl.updated_at
  from teacher_word_lists wl
  where wl.teacher_id = auth.uid()
  order by wl.last_used_at desc nulls last, wl.updated_at desc;
end;
$$;

-- RPC: delete a word list by name
create or replace function delete_teacher_word_list(p_name text)
returns jsonb
language plpgsql security definer
as $$
begin
  delete from teacher_word_lists
  where teacher_id = auth.uid() and name = p_name;
  return jsonb_build_object('ok', true);
end;
$$;

-- RPC: mark a list as used (increment counter + set last_used_at)
create or replace function mark_teacher_word_list_used(p_name text)
returns void
language plpgsql security definer
as $$
begin
  update teacher_word_lists
  set times_used   = times_used + 1,
      last_used_at = now()
  where teacher_id = auth.uid() and name = p_name;
end;
$$;
-- <<< END FILE: supabase_bingo_v18_teaching_word_lists.sql

-- >>> BEGIN FILE: supabase_bingo_v18_avatar_faceshapes.sql
-- =========================================================
-- V18: Avatar face-shape sheet correction
-- =========================================================
-- Canonical spritesheet: /media/avatar_faceshapes.png
-- 1024×1280, 4 cols × 5 rows, 256×256/cell.
--
-- V17 introduced the XP avatar shop against an incorrect mixed sheet.
-- This patch keeps the same purchase RPC and unlocked_avatar_items column,
-- but replaces the server-side item catalogue with the 20 real face-shape
-- tile keys used by the frontend.
-- =========================================================

create or replace function public.get_avatar_item_cost(p_item_key text)
returns int
language sql
immutable
security definer
set search_path = public
as $$
  select case p_item_key
    -- ── Head / face-shape silhouettes ───────────────────────────────────
    when 'head_basic'          then 0
    when 'head_flat_top'       then 0
    when 'head_widows_peak'    then 50
    when 'head_crew'           then 50
    when 'head_bun'            then 75
    when 'head_bob'            then 75
    when 'head_long'           then 100
    when 'head_side_part'      then 100
    when 'head_wavy'           then 125
    when 'head_spiky'          then 125
    when 'head_afro'           then 300
    when 'head_pigtails'       then 150
    when 'head_full_beard'     then 175
    when 'head_goatee'         then 150
    when 'head_mohawk'         then 225
    when 'head_hat'            then 200
    when 'head_hood'           then 250
    when 'head_helmet'         then 275
    when 'head_cap'            then 175
    when 'head_flat_top_beard' then 300
    -- ── Head accessories (Avatar-8) ─────────────────────────────────────
    when 'acc_none'            then 0
    when 'acc_headband'        then 50
    when 'acc_bow'             then 50
    when 'acc_cap'             then 50
    when 'acc_bandana'         then 50
    when 'acc_party_hat'       then 75
    when 'acc_beanie'          then 75
    when 'acc_cowboy'          then 75
    when 'acc_graduation'      then 75
    when 'acc_earmuffs'        then 75
    when 'acc_chef_hat'        then 75
    when 'acc_tophat'          then 100
    when 'acc_sombrero'        then 100
    when 'acc_laurel'          then 100
    when 'acc_witch_hat'       then 100
    when 'acc_antlers'         then 100
    when 'acc_bunny_ears'      then 100
    when 'acc_crown'           then 150
    when 'acc_tiara'           then 150
    when 'acc_viking'          then 150
    else null
  end;
$$;

grant execute on function public.get_avatar_item_cost(text) to authenticated, anon;
-- <<< END FILE: supabase_bingo_v18_avatar_faceshapes.sql

