-- Lerke Bingo V2
-- Strict live gameplay patch
--
-- Run this after:
-- 1. supabase_bingo_v1_sql_editor_ready.sql
-- 2. supabase_student_accounts_v1_core_patch.sql
--
-- This patch extends the current Bingo V1 model with:
-- - authoritative lobby / round / draw states
-- - persisted participant boards per round
-- - one-response-per-draw enforcement
-- - teacher-controlled open / lock / complete flow

begin;

create or replace function public.is_participant_owner(target_participant_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.session_participants sp
    where sp.id = target_participant_id
      and sp.auth_user_id = auth.uid()
  );
$$;

create or replace function public.board_has_bingo(p_marked_cells jsonb)
returns boolean
language sql
immutable
as $$
  with marked as (
    select coalesce(array_agg(value::integer), array[]::integer[]) as arr
    from jsonb_array_elements_text(coalesce(p_marked_cells, '[]'::jsonb))
  ),
  lines(line) as (
    values
      (array[0,1,2,3,4]::integer[]),
      (array[5,6,7,8,9]::integer[]),
      (array[10,11,12,13,14]::integer[]),
      (array[15,16,17,18,19]::integer[]),
      (array[20,21,22,23,24]::integer[]),
      (array[0,5,10,15,20]::integer[]),
      (array[1,6,11,16,21]::integer[]),
      (array[2,7,12,17,22]::integer[]),
      (array[3,8,13,18,23]::integer[]),
      (array[4,9,14,19,24]::integer[]),
      (array[0,6,12,18,24]::integer[]),
      (array[4,8,12,16,20]::integer[])
  )
  select exists (
    select 1
    from lines, marked
    where (
      select bool_and(idx = any(marked.arr))
      from unnest(line) as idx
    )
  );
$$;

alter table public.session_state
  add column if not exists current_draw_opened_at timestamptz,
  add column if not exists current_draw_closes_at timestamptz,
  add column if not exists current_draw_locked_at timestamptz;

alter table public.session_state
  drop constraint if exists session_state_phase_check;

alter table public.session_state
  add constraint session_state_phase_check
    check (phase in (
      'setup',
      'live_draw',
      'lobby',
      'round_active',
      'draw_open',
      'draw_locked',
      'round_complete',
      'ended'
    ));

update public.session_state
set phase = 'lobby'
where phase = 'setup';

alter table public.session_events
  drop constraint if exists session_events_event_type_check;

alter table public.session_events
  add constraint session_events_event_type_check
    check (event_type in (
      'session_created',
      'session_started',
      'round_started',
      'draw_advanced',
      'draw_opened',
      'draw_locked',
      'answer_submitted',
      'board_saved',
      'round_reset',
      'round_completed',
      'session_ended',
      'student_joined'
    ));

create table if not exists public.participant_round_boards (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.sessions(id) on delete cascade,
  participant_id uuid not null references public.session_participants(id) on delete cascade,
  round_number integer not null,
  board_cells jsonb not null,
  marked_cells jsonb not null default '[]'::jsonb,
  has_bingo boolean not null default false,
  bingo_count integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (session_id, participant_id, round_number),
  constraint participant_round_boards_round_number_check
    check (round_number > 0),
  constraint participant_round_boards_cells_array_check
    check (jsonb_typeof(board_cells) = 'array' and jsonb_array_length(board_cells) = 25),
  constraint participant_round_boards_marked_array_check
    check (jsonb_typeof(marked_cells) = 'array'),
  constraint participant_round_boards_bingo_count_check
    check (bingo_count >= 0)
);

create table if not exists public.participant_draw_responses (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.sessions(id) on delete cascade,
  participant_id uuid not null references public.session_participants(id) on delete cascade,
  round_number integer not null,
  draw_index integer not null,
  selected_cell_index integer,
  selected_value text,
  response_outcome text not null,
  correct boolean not null default false,
  answered_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  unique (session_id, participant_id, round_number, draw_index),
  constraint participant_draw_responses_round_number_check
    check (round_number > 0),
  constraint participant_draw_responses_draw_index_check
    check (draw_index > 0),
  constraint participant_draw_responses_selected_cell_check
    check (
      selected_cell_index is null
      or (selected_cell_index >= 0 and selected_cell_index < 25)
    ),
  constraint participant_draw_responses_outcome_check
    check (response_outcome in ('correct', 'wrong', 'timeout'))
);

create index if not exists idx_participant_round_boards_session_round
  on public.participant_round_boards(session_id, round_number);

create index if not exists idx_participant_round_boards_participant
  on public.participant_round_boards(participant_id, round_number);

create index if not exists idx_participant_draw_responses_session_round_draw
  on public.participant_draw_responses(session_id, round_number, draw_index);

create index if not exists idx_participant_draw_responses_participant
  on public.participant_draw_responses(participant_id, round_number, draw_index);

drop trigger if exists trg_participant_round_boards_updated_at on public.participant_round_boards;
create trigger trg_participant_round_boards_updated_at
before update on public.participant_round_boards
for each row execute function public.set_updated_at();

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
  v_settings jsonb := coalesce(p_settings, '{}'::jsonb);
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

  v_settings := jsonb_set(v_settings, '{strict_live_mode}', 'true'::jsonb, true);

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
        'draft',
        v_settings
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
    current_draw_opened_at,
    current_draw_closes_at,
    current_draw_locked_at,
    updated_by
  )
  values (
    v_session.id,
    'lobby',
    1,
    0,
    null,
    null,
    null,
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
      'round_count', v_round_number,
      'strict_live_mode', true
    )
  );

  return v_session;
end;
$$;

create or replace function public.upsert_participant_board(
  p_session_id uuid,
  p_round_number integer,
  p_board_cells jsonb
)
returns public.participant_round_boards
language plpgsql
security definer
set search_path = public
as $$
declare
  v_participant public.session_participants;
  v_board public.participant_round_boards;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  if jsonb_typeof(p_board_cells) is distinct from 'array' or jsonb_array_length(p_board_cells) <> 25 then
    raise exception 'board_cells must be a JSON array with 25 entries';
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

  insert into public.participant_round_boards (
    session_id,
    participant_id,
    round_number,
    board_cells,
    marked_cells,
    has_bingo,
    bingo_count
  )
  values (
    p_session_id,
    v_participant.id,
    p_round_number,
    p_board_cells,
    '[]'::jsonb,
    false,
    0
  )
  on conflict (session_id, participant_id, round_number) do update
    set board_cells = excluded.board_cells,
        updated_at = now()
  returning * into v_board;

  insert into public.session_events (
    session_id,
    event_type,
    actor_user_id,
    payload
  )
  values (
    p_session_id,
    'board_saved',
    auth.uid(),
    jsonb_build_object(
      'participant_id', v_participant.id,
      'round_number', p_round_number
    )
  );

  return v_board;
end;
$$;

create or replace function public.start_bingo_round(
  p_session_id uuid,
  p_round_number integer default null
)
returns public.session_state
language plpgsql
security definer
set search_path = public
as $$
declare
  v_state public.session_state;
  v_round integer;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  if not public.is_session_teacher(p_session_id) then
    raise exception 'Session teacher access required';
  end if;

  select *
  into v_state
  from public.session_state
  where session_id = p_session_id
  limit 1;

  if not found then
    raise exception 'Session state not found';
  end if;

  v_round := coalesce(p_round_number, v_state.round_number);

  if not exists (
    select 1
    from public.session_rounds sr
    where sr.session_id = p_session_id
      and sr.round_number = v_round
  ) then
    raise exception 'Round not found';
  end if;

  update public.sessions
  set status = 'live'
  where id = p_session_id;

  update public.session_state
  set phase = 'round_active',
      round_number = v_round,
      draw_index = 0,
      current_draw = null,
      current_draw_opened_at = null,
      current_draw_closes_at = null,
      current_draw_locked_at = null,
      updated_by = auth.uid()
  where session_id = p_session_id
  returning * into v_state;

  insert into public.session_events (
    session_id,
    event_type,
    actor_user_id,
    payload
  )
  values (
    p_session_id,
    'round_started',
    auth.uid(),
    jsonb_build_object('round_number', v_round)
  );

  return v_state;
end;
$$;

create or replace function public.open_bingo_draw(
  p_session_id uuid
)
returns public.session_state
language plpgsql
security definer
set search_path = public
as $$
declare
  v_state public.session_state;
  v_sequence jsonb;
  v_next_draw_index integer;
  v_draw jsonb;
  v_duration_seconds integer;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  if not public.is_session_teacher(p_session_id) then
    raise exception 'Session teacher access required';
  end if;

  select *
  into v_state
  from public.session_state
  where session_id = p_session_id
  limit 1;

  if not found then
    raise exception 'Session state not found';
  end if;

  if v_state.phase not in ('lobby', 'round_active', 'draw_locked') then
    raise exception 'Draw cannot be opened from current phase';
  end if;

  select draw_sequence
  into v_sequence
  from public.session_rounds
  where session_id = p_session_id
    and round_number = v_state.round_number
  limit 1;

  if v_sequence is null then
    raise exception 'Round sequence not found';
  end if;

  v_next_draw_index := v_state.draw_index + 1;

  if v_next_draw_index > jsonb_array_length(v_sequence) then
    raise exception 'No more draws left in this round';
  end if;

  v_draw := v_sequence -> (v_next_draw_index - 1);
  v_duration_seconds := greatest(1, least(60, coalesce(((
    select settings->>'draw_duration_seconds'
    from public.sessions
    where id = p_session_id
  )::integer), 5)));

  update public.sessions
  set status = 'live'
  where id = p_session_id;

  update public.session_state
  set phase = 'draw_open',
      draw_index = v_next_draw_index,
      current_draw = v_draw,
      current_draw_opened_at = now(),
      current_draw_closes_at = now() + make_interval(secs => v_duration_seconds),
      current_draw_locked_at = null,
      updated_by = auth.uid()
  where session_id = p_session_id
  returning * into v_state;

  insert into public.session_events (
    session_id,
    event_type,
    actor_user_id,
    payload
  )
  values (
    p_session_id,
    'draw_opened',
    auth.uid(),
    jsonb_build_object(
      'round_number', v_state.round_number,
      'draw_index', v_next_draw_index,
      'draw', v_draw,
      'draw_duration_seconds', v_duration_seconds
    )
  );

  return v_state;
end;
$$;

create or replace function public.lock_bingo_draw(
  p_session_id uuid
)
returns public.session_state
language plpgsql
security definer
set search_path = public
as $$
declare
  v_state public.session_state;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  if not public.is_session_teacher(p_session_id) then
    raise exception 'Session teacher access required';
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
    raise exception 'No open draw to lock';
  end if;

  insert into public.participant_draw_responses (
    session_id,
    participant_id,
    round_number,
    draw_index,
    response_outcome,
    correct,
    answered_at
  )
  select
    p_session_id,
    sp.id,
    v_state.round_number,
    v_state.draw_index,
    'timeout',
    false,
    now()
  from public.session_participants sp
  where sp.session_id = p_session_id
    and sp.status in ('active', 'inactive')
    and not exists (
      select 1
      from public.participant_draw_responses pdr
      where pdr.session_id = p_session_id
        and pdr.participant_id = sp.id
        and pdr.round_number = v_state.round_number
        and pdr.draw_index = v_state.draw_index
    );

  update public.session_state
  set phase = 'draw_locked',
      current_draw_locked_at = now(),
      updated_by = auth.uid()
  where session_id = p_session_id
  returning * into v_state;

  insert into public.session_events (
    session_id,
    event_type,
    actor_user_id,
    payload
  )
  values (
    p_session_id,
    'draw_locked',
    auth.uid(),
    jsonb_build_object(
      'round_number', v_state.round_number,
      'draw_index', v_state.draw_index
    )
  );

  return v_state;
end;
$$;

create or replace function public.complete_bingo_round(
  p_session_id uuid
)
returns public.session_state
language plpgsql
security definer
set search_path = public
as $$
declare
  v_state public.session_state;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  if not public.is_session_teacher(p_session_id) then
    raise exception 'Session teacher access required';
  end if;

  update public.session_state
  set phase = 'round_complete',
      current_draw_locked_at = coalesce(current_draw_locked_at, now()),
      updated_by = auth.uid()
  where session_id = p_session_id
  returning * into v_state;

  if not found then
    raise exception 'Session state not found';
  end if;

  insert into public.session_events (
    session_id,
    event_type,
    actor_user_id,
    payload
  )
  values (
    p_session_id,
    'round_completed',
    auth.uid(),
    jsonb_build_object(
      'round_number', v_state.round_number
    )
  );

  return v_state;
end;
$$;

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
  v_state public.session_state;
  v_participant public.session_participants;
  v_board public.participant_round_boards;
  v_expected_answer text;
  v_correct boolean;
  v_marked_cells jsonb;
  v_response public.participant_draw_responses;
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
  v_correct := coalesce(p_selected_value, '') = v_expected_answer;

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
        end
    where id = v_board.id
    returning * into v_board;
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
    'bingo_count', coalesce(v_board.bingo_count, 0)
  );
end;
$$;

create or replace function public.get_bingo_live_state(
  p_session_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_session public.sessions;
  v_state public.session_state;
  v_participant public.session_participants;
  v_board public.participant_round_boards;
  v_response public.participant_draw_responses;
  v_participant_count integer := 0;
  v_total_answers integer := 0;
  v_correct_answers integer := 0;
  v_wrong_answers integer := 0;
  v_timeout_answers integer := 0;
  v_bingo_count integer := 0;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  if not public.is_session_teacher(p_session_id) and not public.is_session_participant(p_session_id) then
    raise exception 'Session access required';
  end if;

  select *
  into v_session
  from public.sessions
  where id = p_session_id
  limit 1;

  select *
  into v_state
  from public.session_state
  where session_id = p_session_id
  limit 1;

  select *
  into v_participant
  from public.session_participants
  where session_id = p_session_id
    and auth_user_id = auth.uid()
  limit 1;

  if found and v_state.round_number is not null then
    select *
    into v_board
    from public.participant_round_boards
    where session_id = p_session_id
      and participant_id = v_participant.id
      and round_number = v_state.round_number
    limit 1;

    select *
    into v_response
    from public.participant_draw_responses
    where session_id = p_session_id
      and participant_id = v_participant.id
      and round_number = v_state.round_number
      and draw_index = v_state.draw_index
    limit 1;
  end if;

  select count(*)
  into v_participant_count
  from public.session_participants
  where session_id = p_session_id
    and status in ('active', 'inactive');

  select
    count(*),
    count(*) filter (where correct = true),
    count(*) filter (where response_outcome = 'wrong'),
    count(*) filter (where response_outcome = 'timeout')
  into
    v_total_answers,
    v_correct_answers,
    v_wrong_answers,
    v_timeout_answers
  from public.participant_draw_responses
  where session_id = p_session_id
    and round_number = coalesce(v_state.round_number, 0)
    and draw_index = coalesce(v_state.draw_index, 0);

  select count(*)
  into v_bingo_count
  from public.participant_round_boards
  where session_id = p_session_id
    and round_number = coalesce(v_state.round_number, 0)
    and has_bingo = true;

  return jsonb_build_object(
    'session', jsonb_build_object(
      'id', v_session.id,
      'title', v_session.title,
      'status', v_session.status,
      'join_code', v_session.join_code,
      'settings', v_session.settings
    ),
    'state', jsonb_build_object(
      'phase', v_state.phase,
      'round_number', v_state.round_number,
      'draw_index', v_state.draw_index,
      'current_draw', v_state.current_draw,
      'current_draw_opened_at', v_state.current_draw_opened_at,
      'current_draw_closes_at', v_state.current_draw_closes_at,
      'current_draw_locked_at', v_state.current_draw_locked_at
    ),
    'participant', case
      when v_participant.id is null then null
      else jsonb_build_object(
        'id', v_participant.id,
        'display_name', v_participant.display_name,
        'role', v_participant.role,
        'status', v_participant.status
      )
    end,
    'board', case
      when v_board.id is null then null
      else jsonb_build_object(
        'round_number', v_board.round_number,
        'board_cells', v_board.board_cells,
        'marked_cells', v_board.marked_cells,
        'has_bingo', v_board.has_bingo,
        'bingo_count', v_board.bingo_count
      )
    end,
    'current_response', case
      when v_response.id is null then null
      else jsonb_build_object(
        'response_outcome', v_response.response_outcome,
        'correct', v_response.correct,
        'selected_cell_index', v_response.selected_cell_index,
        'selected_value', v_response.selected_value,
        'answered_at', v_response.answered_at
      )
    end,
    'teacher_summary', jsonb_build_object(
      'participant_count', v_participant_count,
      'total_answers', v_total_answers,
      'correct_answers', v_correct_answers,
      'wrong_answers', v_wrong_answers,
      'timeout_answers', v_timeout_answers,
      'bingo_count', v_bingo_count
    )
  );
end;
$$;

revoke all on function public.create_bingo_session(text, jsonb, jsonb) from public;
revoke all on function public.upsert_participant_board(uuid, integer, jsonb) from public;
revoke all on function public.start_bingo_round(uuid, integer) from public;
revoke all on function public.open_bingo_draw(uuid) from public;
revoke all on function public.lock_bingo_draw(uuid) from public;
revoke all on function public.complete_bingo_round(uuid) from public;
revoke all on function public.submit_bingo_answer(uuid, integer, text) from public;
revoke all on function public.get_bingo_live_state(uuid) from public;

grant execute on function public.create_bingo_session(text, jsonb, jsonb) to authenticated;
grant execute on function public.upsert_participant_board(uuid, integer, jsonb) to authenticated;
grant execute on function public.start_bingo_round(uuid, integer) to authenticated;
grant execute on function public.open_bingo_draw(uuid) to authenticated;
grant execute on function public.lock_bingo_draw(uuid) to authenticated;
grant execute on function public.complete_bingo_round(uuid) to authenticated;
grant execute on function public.submit_bingo_answer(uuid, integer, text) to authenticated;
grant execute on function public.get_bingo_live_state(uuid) to authenticated;

alter table public.participant_round_boards enable row level security;
alter table public.participant_draw_responses enable row level security;

drop policy if exists participant_round_boards_teacher_select on public.participant_round_boards;
create policy participant_round_boards_teacher_select
on public.participant_round_boards
for select
to authenticated
using (public.is_session_teacher(session_id));

drop policy if exists participant_round_boards_select_self on public.participant_round_boards;
create policy participant_round_boards_select_self
on public.participant_round_boards
for select
to authenticated
using (public.is_participant_owner(participant_id));

drop policy if exists participant_draw_responses_teacher_select on public.participant_draw_responses;
create policy participant_draw_responses_teacher_select
on public.participant_draw_responses
for select
to authenticated
using (public.is_session_teacher(session_id));

drop policy if exists participant_draw_responses_select_self on public.participant_draw_responses;
create policy participant_draw_responses_select_self
on public.participant_draw_responses
for select
to authenticated
using (public.is_participant_owner(participant_id));

commit;
