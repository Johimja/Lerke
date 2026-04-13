-- Lerke Bingo V1
-- Supabase SQL Editor ready
--
-- Use this file in Supabase SQL Editor.
-- Do not paste `supabase/sql/archive/supabase_bingo_v1_migration_draft.sql` directly.
--
-- Expectations before running:
-- 1. Run this in the correct Supabase project.
-- 2. `auth.users` must exist already. In Supabase, it does.
-- 3. This is intended for a fresh Bingo V1 setup, not a mature production migration chain.
-- 4. Student join/reroll/touch writes go through RPC functions, not direct table writes.
--
-- What this creates:
-- - activities
-- - teacher_profiles
-- - sessions
-- - session_rounds
-- - session_state
-- - session_events
-- - session_participants
-- - helper + RPC functions
-- - triggers, indexes, seed data, RLS policies

begin;

create extension if not exists pgcrypto;

-- =========================================================
-- Helpers
-- =========================================================

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create or replace function public.generate_join_code(code_length integer default 6)
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

create or replace function public.generate_nickname()
returns text
language plpgsql
as $$
declare
  adjectives text[] := array[
    'Rask','Stille','Modig','Klar','Lurig','Blid','Trygg','Snill',
    'Ivrig','Kvikk','Lys','Stolt','Fin','Rolig','Vennlig','Smart',
    'Vennlig','Koselig','Gjerrig','Masete','Sorte','Jule','Påske'
  ];
  nouns text[] := array[
    'Rev','Ugle','Bjørn','Falk','Ekorn','Ravn','Oter','Hare',
    'Lykt','Blyant','Bok','Stein','Hammer','Stjerne','Kompass','Pensel',
    'Kloss','Veske','Sekk','Hylle','Katt','Ark','Nese','Saks','Nisse'
  ];
begin
  return adjectives[1 + floor(random() * array_length(adjectives, 1))::integer]
    || ' ' ||
    nouns[1 + floor(random() * array_length(nouns, 1))::integer];
end;
$$;

-- =========================================================
-- Core tables
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
  approved_by uuid references auth.users(id),
  invite_key_used text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint teacher_approval_requires_teacher
    check (is_approved = false or is_teacher = true)
);

create table if not exists public.sessions (
  id uuid primary key default gen_random_uuid(),
  activity_slug text not null default 'bingo',
  created_by uuid not null references auth.users(id) on delete restrict,
  join_code text not null unique,
  title text,
  status text not null default 'draft',
  expires_at timestamptz not null default (now() + interval '24 hours'),
  settings jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint sessions_activity_slug_check
    check (activity_slug in ('bingo')),
  constraint sessions_status_check
    check (status in ('draft', 'live', 'ended', 'expired'))
);

create table if not exists public.session_rounds (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.sessions(id) on delete cascade,
  round_number integer not null,
  draw_sequence jsonb not null,
  created_at timestamptz not null default now(),
  unique (session_id, round_number),
  constraint session_rounds_round_number_check
    check (round_number > 0),
  constraint session_rounds_draw_sequence_array_check
    check (jsonb_typeof(draw_sequence) = 'array')
);

create table if not exists public.session_state (
  session_id uuid primary key references public.sessions(id) on delete cascade,
  phase text not null default 'setup',
  round_number integer not null default 1,
  draw_index integer not null default 0,
  current_draw jsonb,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint session_state_phase_check
    check (phase in ('setup', 'live_draw', 'round_complete', 'ended')),
  constraint session_state_round_number_check
    check (round_number > 0),
  constraint session_state_draw_index_check
    check (draw_index >= 0)
);

create table if not exists public.session_events (
  id bigint generated always as identity primary key,
  session_id uuid not null references public.sessions(id) on delete cascade,
  event_type text not null,
  actor_user_id uuid references auth.users(id) on delete set null,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  constraint session_events_event_type_check
    check (event_type in (
      'session_created',
      'session_started',
      'round_started',
      'draw_advanced',
      'round_reset',
      'round_completed',
      'session_ended',
      'student_joined'
    ))
);

create table if not exists public.session_participants (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.sessions(id) on delete cascade,
  auth_user_id uuid not null references auth.users(id) on delete cascade,
  display_name text not null,
  role text not null default 'student',
  client_token text not null,
  reroll_count integer not null default 0,
  joined_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  status text not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint session_participants_role_check
    check (role in ('student', 'observer')),
  constraint session_participants_status_check
    check (status in ('active', 'left', 'inactive')),
  constraint session_participants_reroll_count_check
    check (reroll_count >= 0 and reroll_count <= 3),
  unique (session_id, auth_user_id),
  unique (session_id, client_token)
);

-- =========================================================
-- Auth helpers
-- =========================================================

create or replace function public.is_session_teacher(target_session_id uuid)
returns boolean
language sql
stable
as $$
  select exists (
    select 1
    from public.sessions s
    join public.teacher_profiles tp on tp.user_id = s.created_by
    where s.id = target_session_id
      and s.created_by = auth.uid()
      and tp.is_teacher = true
      and tp.is_approved = true
  );
$$;

create or replace function public.is_teacher()
returns boolean
language sql
stable
as $$
  select exists (
    select 1
    from public.teacher_profiles tp
    where tp.user_id = auth.uid()
      and tp.is_teacher = true
      and tp.is_approved = true
  );
$$;

create or replace function public.is_session_participant(target_session_id uuid)
returns boolean
language sql
stable
as $$
  select exists (
    select 1
    from public.session_participants sp
    where sp.session_id = target_session_id
      and sp.auth_user_id = auth.uid()
      and sp.status in ('active', 'inactive')
  );
$$;

-- =========================================================
-- RPC functions
-- =========================================================

create or replace function public.request_teacher_access()
returns public.teacher_profiles
language plpgsql
security definer
set search_path = public
as $$
declare
  v_profile public.teacher_profiles;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  insert into public.teacher_profiles (
    user_id,
    is_teacher,
    is_approved
  )
  values (
    auth.uid(),
    true,
    false
  )
  on conflict (user_id) do update
    set is_teacher = true,
        updated_at = now()
  returning * into v_profile;

  return v_profile;
end;
$$;

create or replace function public.get_joinable_bingo_session(p_join_code text)
returns public.sessions
language plpgsql
security definer
set search_path = public
as $$
declare
  v_session public.sessions;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  select *
  into v_session
  from public.sessions s
  where s.join_code = upper(trim(p_join_code))
    and s.activity_slug = 'bingo'
    and s.status in ('draft', 'live')
    and s.expires_at > now()
  order by s.created_at desc
  limit 1;

  if not found then
    raise exception 'Session not found or not joinable';
  end if;

  return v_session;
end;
$$;

create or replace function public.create_bingo_session(
  p_title text,
  p_settings jsonb default '{}'::jsonb,
  p_rounds_data jsonb default '[]'::jsonb
)
returns public.sessions
language plpgsql
security definer
set search_path = public
as $$
declare
  v_session public.sessions;
  v_join_code text;
  v_round jsonb;
  v_round_number integer := 0;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  if not public.is_teacher() then
    raise exception 'Approved teacher required';
  end if;

  if jsonb_typeof(p_rounds_data) is distinct from 'array' then
    raise exception 'rounds_data must be a JSON array';
  end if;

  if jsonb_array_length(p_rounds_data) = 0 then
    raise exception 'At least one round is required';
  end if;

  loop
    v_join_code := public.generate_join_code();

    begin
      insert into public.sessions (
        activity_slug,
        created_by,
        join_code,
        title,
        status,
        settings
      )
      values (
        'bingo',
        auth.uid(),
        v_join_code,
        nullif(trim(p_title), ''),
        'live',
        coalesce(p_settings, '{}'::jsonb)
      )
      returning * into v_session;

      exit;
    exception
      when unique_violation then
        null;
    end;
  end loop;

  for v_round in
    select value
    from jsonb_array_elements(p_rounds_data)
  loop
    v_round_number := v_round_number + 1;

    if jsonb_typeof(v_round) is distinct from 'array' then
      raise exception 'Each round entry must be a JSON array';
    end if;

    insert into public.session_rounds (
      session_id,
      round_number,
      draw_sequence
    )
    values (
      v_session.id,
      v_round_number,
      v_round
    );
  end loop;

  insert into public.session_state (
    session_id,
    phase,
    round_number,
    draw_index,
    current_draw,
    updated_by
  )
  values (
    v_session.id,
    'setup',
    1,
    0,
    null,
    auth.uid()
  );

  insert into public.session_events (
    session_id,
    event_type,
    actor_user_id,
    payload
  )
  values (
    v_session.id,
    'session_created',
    auth.uid(),
    jsonb_build_object(
      'title', v_session.title,
      'join_code', v_session.join_code,
      'round_count', v_round_number
    )
  );

  return v_session;
end;
$$;

create or replace function public.join_bingo_session(
  p_join_code text,
  p_client_token text
)
returns public.session_participants
language plpgsql
security definer
set search_path = public
as $$
declare
  v_session public.sessions;
  v_participant public.session_participants;
  v_student_profile_id uuid;
  v_student_display_name text;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  select *
  into v_session
  from public.sessions s
  where s.join_code = upper(trim(p_join_code))
    and s.activity_slug = 'bingo'
    and s.status in ('draft', 'live')
    and s.expires_at > now()
  limit 1;

  if not found then
    raise exception 'Session not found or not joinable';
  end if;

  select sp.id, sp.display_name
  into v_student_profile_id, v_student_display_name
  from public.student_auth_links sal
  join public.student_profiles sp on sp.id = sal.student_id
  join public.classes c on c.id = sp.class_id
  where sal.auth_user_id = auth.uid()
    and sp.status = 'active'
    and c.status = 'active'
  limit 1;

  select *
  into v_participant
  from public.session_participants sp
  where sp.session_id = v_session.id
    and (
      sp.auth_user_id = auth.uid()
      or sp.client_token = p_client_token
    )
  order by case when sp.auth_user_id = auth.uid() then 0 else 1 end
  limit 1;

  if found then
    update public.session_participants
    set auth_user_id = auth.uid(),
        client_token = p_client_token,
        display_name = coalesce(v_student_display_name, display_name),
        student_profile_id = coalesce(v_student_profile_id, student_profile_id),
        last_seen_at = now(),
        status = 'active'
    where id = v_participant.id
    returning * into v_participant;

    return v_participant;
  end if;

  insert into public.session_participants (
    session_id,
    auth_user_id,
    student_profile_id,
    display_name,
    role,
    client_token,
    reroll_count,
    last_seen_at,
    status
  )
  values (
    v_session.id,
    auth.uid(),
    v_student_profile_id,
    coalesce(v_student_display_name, public.generate_nickname()),
    'student',
    p_client_token,
    0,
    now(),
    'active'
  )
  returning * into v_participant;

  insert into public.session_events (session_id, event_type, actor_user_id, payload)
  values (
    v_session.id,
    'student_joined',
    auth.uid(),
    jsonb_build_object(
      'participant_id', v_participant.id,
      'display_name', v_participant.display_name,
      'student_profile_id', v_participant.student_profile_id
    )
  );

  return v_participant;
end;
$$;

create or replace function public.reroll_nickname(p_session_id uuid)
returns public.session_participants
language plpgsql
security definer
set search_path = public
as $$
declare
  v_participant public.session_participants;
  v_new_name text;
  v_attempts integer := 0;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  select *
  into v_participant
  from public.session_participants sp
  where sp.session_id = p_session_id
    and sp.auth_user_id = auth.uid()
  limit 1;

  if not found then
    raise exception 'Participant not found';
  end if;

  if v_participant.reroll_count >= 3 then
    raise exception 'Reroll limit reached';
  end if;

  loop
    v_new_name := public.generate_nickname();
    v_attempts := v_attempts + 1;
    exit when v_new_name <> v_participant.display_name or v_attempts >= 5;
  end loop;

  update public.session_participants
  set display_name = v_new_name,
      reroll_count = reroll_count + 1,
      last_seen_at = now(),
      status = 'active'
  where id = v_participant.id
  returning * into v_participant;

  return v_participant;
end;
$$;

create or replace function public.touch_participant(p_session_id uuid)
returns public.session_participants
language plpgsql
security definer
set search_path = public
as $$
declare
  v_participant public.session_participants;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  update public.session_participants
  set last_seen_at = now(),
      status = 'active'
  where session_id = p_session_id
    and auth_user_id = auth.uid()
  returning * into v_participant;

  if not found then
    raise exception 'Participant not found';
  end if;

  return v_participant;
end;
$$;

-- Reduce accidental execute exposure before explicit grants below.
revoke all on function public.request_teacher_access() from public;
revoke all on function public.get_joinable_bingo_session(text) from public;
revoke all on function public.create_bingo_session(text, jsonb, jsonb) from public;
revoke all on function public.join_bingo_session(text, text) from public;
revoke all on function public.reroll_nickname(uuid) from public;
revoke all on function public.touch_participant(uuid) from public;

-- =========================================================
-- Indexes
-- =========================================================

create index if not exists idx_sessions_created_by on public.sessions(created_by);
create index if not exists idx_sessions_join_code on public.sessions(join_code);
create index if not exists idx_sessions_status on public.sessions(status);
create index if not exists idx_sessions_expires_at on public.sessions(expires_at);
create index if not exists idx_session_rounds_session_round on public.session_rounds(session_id, round_number);
create index if not exists idx_session_events_session_created on public.session_events(session_id, created_at desc);
create index if not exists idx_session_participants_session on public.session_participants(session_id);
create index if not exists idx_session_participants_auth_user on public.session_participants(auth_user_id);
create index if not exists idx_session_participants_last_seen on public.session_participants(session_id, last_seen_at desc);

-- =========================================================
-- Triggers
-- =========================================================

drop trigger if exists trg_teacher_profiles_updated_at on public.teacher_profiles;
create trigger trg_teacher_profiles_updated_at
before update on public.teacher_profiles
for each row execute function public.set_updated_at();

drop trigger if exists trg_sessions_updated_at on public.sessions;
create trigger trg_sessions_updated_at
before update on public.sessions
for each row execute function public.set_updated_at();

drop trigger if exists trg_session_state_updated_at on public.session_state;
create trigger trg_session_state_updated_at
before update on public.session_state
for each row execute function public.set_updated_at();

drop trigger if exists trg_session_participants_updated_at on public.session_participants;
create trigger trg_session_participants_updated_at
before update on public.session_participants
for each row execute function public.set_updated_at();

-- =========================================================
-- Seed activity
-- =========================================================

insert into public.activities (slug, name)
values ('bingo', 'Lerke Bingo')
on conflict (slug) do nothing;

-- =========================================================
-- RLS
-- =========================================================

-- Current direction:
-- - teacher-first table permissions
-- - student writes only through RPC functions
-- - student reads are limited to own participation plus scoped session live data
--
-- This matches the current V1 plan with authenticated/anonymous student auth
-- and avoids broad direct table write access from the client.

alter table public.teacher_profiles enable row level security;
alter table public.sessions enable row level security;
alter table public.session_rounds enable row level security;
alter table public.session_state enable row level security;
alter table public.session_events enable row level security;
alter table public.session_participants enable row level security;

-- Teacher profiles

drop policy if exists teacher_profiles_select_self on public.teacher_profiles;
create policy teacher_profiles_select_self
on public.teacher_profiles
for select
to authenticated
using (user_id = auth.uid());

drop policy if exists teacher_profiles_insert_self on public.teacher_profiles;
create policy teacher_profiles_insert_self
on public.teacher_profiles
for insert
to authenticated
with check (
  user_id = auth.uid()
  and is_teacher = false
  and is_approved = false
  and approved_at is null
  and approved_by is null
);

-- No self-update policy here.
-- Teacher approval fields should be changed only by service-role/admin flows.

-- Sessions

drop policy if exists sessions_teacher_select on public.sessions;
create policy sessions_teacher_select
on public.sessions
for select
to authenticated
using (public.is_session_teacher(id));

drop policy if exists sessions_teacher_insert on public.sessions;
create policy sessions_teacher_insert
on public.sessions
for insert
to authenticated
with check (
  created_by = auth.uid()
  and public.is_teacher()
);

drop policy if exists sessions_teacher_update on public.sessions;
create policy sessions_teacher_update
on public.sessions
for update
to authenticated
using (public.is_session_teacher(id))
with check (public.is_session_teacher(id));

-- Session rounds

drop policy if exists session_rounds_teacher_select on public.session_rounds;
create policy session_rounds_teacher_select
on public.session_rounds
for select
to authenticated
using (public.is_session_teacher(session_id));

drop policy if exists session_rounds_teacher_insert on public.session_rounds;
create policy session_rounds_teacher_insert
on public.session_rounds
for insert
to authenticated
with check (public.is_session_teacher(session_id));

drop policy if exists session_rounds_teacher_update on public.session_rounds;
create policy session_rounds_teacher_update
on public.session_rounds
for update
to authenticated
using (public.is_session_teacher(session_id))
with check (public.is_session_teacher(session_id));

-- Session state

drop policy if exists session_state_teacher_select on public.session_state;
create policy session_state_teacher_select
on public.session_state
for select
to authenticated
using (public.is_session_teacher(session_id));

drop policy if exists session_state_participant_select on public.session_state;
create policy session_state_participant_select
on public.session_state
for select
to authenticated
using (public.is_session_participant(session_id));

drop policy if exists session_state_teacher_insert on public.session_state;
create policy session_state_teacher_insert
on public.session_state
for insert
to authenticated
with check (public.is_session_teacher(session_id));

drop policy if exists session_state_teacher_update on public.session_state;
create policy session_state_teacher_update
on public.session_state
for update
to authenticated
using (public.is_session_teacher(session_id))
with check (public.is_session_teacher(session_id));

-- Session events

drop policy if exists session_events_teacher_select on public.session_events;
create policy session_events_teacher_select
on public.session_events
for select
to authenticated
using (public.is_session_teacher(session_id));

drop policy if exists session_events_participant_select on public.session_events;
create policy session_events_participant_select
on public.session_events
for select
to authenticated
using (public.is_session_participant(session_id));

drop policy if exists session_events_teacher_insert on public.session_events;
create policy session_events_teacher_insert
on public.session_events
for insert
to authenticated
with check (public.is_session_teacher(session_id));

-- Session participants

drop policy if exists session_participants_teacher_select on public.session_participants;
create policy session_participants_teacher_select
on public.session_participants
for select
to authenticated
using (public.is_session_teacher(session_id));

drop policy if exists session_participants_select_self on public.session_participants;
create policy session_participants_select_self
on public.session_participants
for select
to authenticated
using (auth_user_id = auth.uid());

grant execute on function public.request_teacher_access() to authenticated;
grant execute on function public.get_joinable_bingo_session(text) to authenticated;
grant execute on function public.create_bingo_session(text, jsonb, jsonb) to authenticated;
grant execute on function public.join_bingo_session(text, text) to authenticated;
grant execute on function public.reroll_nickname(uuid) to authenticated;
grant execute on function public.touch_participant(uuid) to authenticated;

commit;
