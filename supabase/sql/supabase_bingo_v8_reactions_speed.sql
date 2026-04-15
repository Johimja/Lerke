-- V8: Student reactions + speed tracking + host heartbeat
-- Adds draw_reactions table, send/get reaction RPCs, touch_session_heartbeat,
-- and expands get_bingo_live_state with fastest_participant and speed_leaderboard.
-- NOTE: send_bingo_reaction fixed in migration fix_send_bingo_reaction_column_name
--       (original had user_id instead of auth_user_id)

-- Step 1: draw_reactions table
create table if not exists public.draw_reactions (
  id            uuid primary key default gen_random_uuid(),
  session_id    uuid not null references public.sessions(id) on delete cascade,
  round_number  integer not null,
  draw_index    integer not null,
  participant_id uuid not null references public.session_participants(id) on delete cascade,
  emoji         text not null,
  reacted_at    timestamptz not null default now(),
  unique (session_id, round_number, draw_index, participant_id)
);

alter table public.draw_reactions enable row level security;

create policy "participants_upsert_own_reaction" on public.draw_reactions
  for all using (public.is_participant_owner(participant_id));

create policy "teacher_read_reactions" on public.draw_reactions
  for select using (public.is_session_teacher(session_id));

-- Step 2: last_heartbeat_at on sessions (if not already present)
alter table public.sessions
  add column if not exists last_heartbeat_at timestamptz;

-- Step 3: touch_session_heartbeat — teacher keeps session "alive" indicator
create or replace function public.touch_session_heartbeat(p_session_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_session_teacher(p_session_id) then
    raise exception 'Only the teacher can update the heartbeat';
  end if;

  update public.sessions
  set last_heartbeat_at = now()
  where id = p_session_id;
end;
$$;

revoke all on function public.touch_session_heartbeat(uuid) from public;
grant execute on function public.touch_session_heartbeat(uuid) to authenticated;

-- Step 4: send_bingo_reaction — student sends an emoji reaction for the current draw
create or replace function public.send_bingo_reaction(
  p_session_id  uuid,
  p_draw_index  integer,
  p_round_number integer,
  p_emoji       text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_participant_id uuid;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if p_emoji not in ('🎉','😬','😤') then raise exception 'Invalid emoji'; end if;

  select id into v_participant_id
  from public.session_participants
  where session_id = p_session_id
    and auth_user_id = auth.uid()
  limit 1;

  if v_participant_id is null then raise exception 'Not a participant of this session'; end if;

  insert into public.draw_reactions(session_id, round_number, draw_index, participant_id, emoji)
  values (p_session_id, p_round_number, p_draw_index, v_participant_id, p_emoji)
  on conflict (session_id, round_number, draw_index, participant_id)
  do update set emoji = excluded.emoji, reacted_at = now();
end;
$$;

revoke all on function public.send_bingo_reaction(uuid, integer, integer, text) from public;
grant execute on function public.send_bingo_reaction(uuid, integer, integer, text) to authenticated;

-- Step 5: get_draw_reactions — teacher fetches reactions for a specific draw
create or replace function public.get_draw_reactions(
  p_session_id  uuid,
  p_round_number integer,
  p_draw_index  integer
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_result jsonb;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if not public.is_session_teacher(p_session_id) then raise exception 'Teacher access required'; end if;

  select coalesce(
    jsonb_agg(
      jsonb_build_object('name', sp.display_name, 'emoji', dr.emoji)
      order by dr.reacted_at
    ),
    '[]'::jsonb
  )
  into v_result
  from public.draw_reactions dr
  join public.session_participants sp on sp.id = dr.participant_id
  where dr.session_id    = p_session_id
    and dr.round_number  = p_round_number
    and dr.draw_index    = p_draw_index;

  return coalesce(v_result, '[]'::jsonb);
end;
$$;

revoke all on function public.get_draw_reactions(uuid, integer, integer) from public;
grant execute on function public.get_draw_reactions(uuid, integer, integer) to authenticated;

-- Step 6: Update get_bingo_live_state to include fastest_participant,
--         speed_leaderboard (top 3 by avg response time), and host_active.
create or replace function public.get_bingo_live_state(p_session_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_session              public.sessions;
  v_state                public.session_state;
  v_participant          public.session_participants;
  v_board                public.participant_round_boards;
  v_response             public.participant_draw_responses;
  v_participant_count    integer := 0;
  v_total_answers        integer := 0;
  v_correct_answers      integer := 0;
  v_wrong_answers        integer := 0;
  v_timeout_answers      integer := 0;
  v_bingo_count          integer := 0;
  v_bingo_winner_names   jsonb := '[]'::jsonb;
  v_bingo_podium         jsonb := '[]'::jsonb;
  v_fastest_participant  jsonb := null;
  v_speed_leaderboard    jsonb := '[]'::jsonb;
  v_host_active          boolean := false;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  if not public.is_session_teacher(p_session_id) and not public.is_session_participant(p_session_id) then
    raise exception 'Session access required';
  end if;

  select * into v_session from public.sessions where id = p_session_id limit 1;

  -- Host active = teacher heartbeat within last 20 seconds
  v_host_active := (v_session.last_heartbeat_at > (now() - interval '20 seconds'));

  select * into v_state from public.session_state where session_id = p_session_id limit 1;

  select * into v_participant
  from public.session_participants
  where session_id = p_session_id and auth_user_id = auth.uid()
  limit 1;

  if found and v_state.round_number is not null then
    select * into v_board
    from public.participant_round_boards
    where session_id = p_session_id
      and participant_id = v_participant.id
      and round_number = v_state.round_number
    limit 1;

    select * into v_response
    from public.participant_draw_responses
    where session_id = p_session_id
      and participant_id = v_participant.id
      and round_number = v_state.round_number
      and draw_index = v_state.draw_index
    limit 1;
  end if;

  select count(*) into v_participant_count
  from public.session_participants
  where session_id = p_session_id and status in ('active', 'inactive');

  select
    count(*),
    count(*) filter (where correct = true),
    count(*) filter (where response_outcome = 'wrong'),
    count(*) filter (where response_outcome = 'timeout')
  into v_total_answers, v_correct_answers, v_wrong_answers, v_timeout_answers
  from public.participant_draw_responses
  where session_id = p_session_id
    and round_number = coalesce(v_state.round_number, 0)
    and draw_index   = coalesce(v_state.draw_index, 0);

  select count(*) into v_bingo_count
  from public.participant_round_boards
  where session_id = p_session_id
    and round_number = coalesce(v_state.round_number, 0)
    and has_bingo = true;

  -- Fastest correct answer this draw
  select jsonb_build_object(
    'name', sp.display_name,
    'seconds', extract(epoch from (pdr.answered_at - v_state.current_draw_opened_at))
  )
  into v_fastest_participant
  from public.participant_draw_responses pdr
  join public.session_participants sp on sp.id = pdr.participant_id
  where pdr.session_id = p_session_id
    and pdr.round_number = coalesce(v_state.round_number, 0)
    and pdr.draw_index   = coalesce(v_state.draw_index, 0)
    and pdr.correct = true
    and pdr.answered_at is not null
  order by pdr.answered_at asc
  limit 1;

  -- Top 3 by average response time across the whole round
  select coalesce(
    jsonb_agg(
      jsonb_build_object('name', sub.display_name, 'avg_seconds', sub.avg_seconds)
      order by sub.avg_seconds asc
    ),
    '[]'::jsonb
  )
  into v_speed_leaderboard
  from (
    select
      sp.display_name,
      avg(extract(epoch from (pdr.answered_at - se.created_at))) as avg_seconds
    from public.participant_draw_responses pdr
    join public.session_participants sp on sp.id = pdr.participant_id
    join public.session_events se
      on  se.session_id  = pdr.session_id
      and se.event_type  = 'draw_opened'
      and (se.payload->>'round_number')::int = pdr.round_number
      and (se.payload->>'draw_index')::int   = pdr.draw_index
    where pdr.session_id    = p_session_id
      and pdr.round_number  = coalesce(v_state.round_number, 0)
      and pdr.correct = true
      and pdr.answered_at is not null
    group by sp.display_name
    order by avg_seconds asc
    limit 3
  ) sub;

  -- bingo_winners: all who have bingo, ordered by when they got it
  select coalesce(jsonb_agg(sp.display_name order by prb.bingo_at_draw_index asc nulls last), '[]'::jsonb)
  into v_bingo_winner_names
  from public.participant_round_boards prb
  join public.session_participants sp on sp.id = prb.participant_id
  where prb.session_id   = p_session_id
    and prb.round_number = coalesce(v_state.round_number, 0)
    and prb.has_bingo = true;

  -- bingo_podium: top 3 for medal display
  select coalesce(
    jsonb_agg(
      jsonb_build_object('name', sub.display_name, 'draw_index', sub.bingo_at_draw_index)
      order by sub.bingo_at_draw_index asc nulls last
    ),
    '[]'::jsonb
  )
  into v_bingo_podium
  from (
    select sp.display_name, prb.bingo_at_draw_index
    from public.participant_round_boards prb
    join public.session_participants sp on sp.id = prb.participant_id
    where prb.session_id   = p_session_id
      and prb.round_number = coalesce(v_state.round_number, 0)
      and prb.has_bingo = true
    order by prb.bingo_at_draw_index asc nulls last
    limit 3
  ) sub;

  return jsonb_build_object(
    'session', jsonb_build_object(
      'id',          v_session.id,
      'title',       v_session.title,
      'status',      v_session.status,
      'join_code',   v_session.join_code,
      'settings',    v_session.settings,
      'host_active', v_host_active
    ),
    'state', jsonb_build_object(
      'phase',                    v_state.phase,
      'round_number',             v_state.round_number,
      'draw_index',               v_state.draw_index,
      'current_draw',             v_state.current_draw,
      'current_draw_opened_at',   v_state.current_draw_opened_at,
      'current_draw_closes_at',   v_state.current_draw_closes_at,
      'current_draw_locked_at',   v_state.current_draw_locked_at
    ),
    'participant', case
      when v_participant.id is null then null
      else jsonb_build_object(
        'id',           v_participant.id,
        'display_name', v_participant.display_name,
        'role',         v_participant.role,
        'status',       v_participant.status
      )
    end,
    'board', case
      when v_board.id is null then null
      else jsonb_build_object(
        'round_number', v_board.round_number,
        'board_cells',  v_board.board_cells,
        'marked_cells', v_board.marked_cells,
        'has_bingo',    v_board.has_bingo,
        'bingo_count',  v_board.bingo_count
      )
    end,
    'current_response', case
      when v_response.id is null then null
      else jsonb_build_object(
        'response_outcome',  v_response.response_outcome,
        'correct',           v_response.correct,
        'selected_cell_index', v_response.selected_cell_index,
        'selected_value',    v_response.selected_value,
        'answered_at',       v_response.answered_at
      )
    end,
    'teacher_summary', jsonb_build_object(
      'participant_count',   v_participant_count,
      'total_answers',       v_total_answers,
      'correct_answers',     v_correct_answers,
      'wrong_answers',       v_wrong_answers,
      'timeout_answers',     v_timeout_answers,
      'bingo_count',         v_bingo_count,
      'bingo_winners',       v_bingo_winner_names,
      'bingo_podium',        v_bingo_podium,
      'fastest_participant', v_fastest_participant,
      'speed_leaderboard',   v_speed_leaderboard
    )
  );
end;
$$;
