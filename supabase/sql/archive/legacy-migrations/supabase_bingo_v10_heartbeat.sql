-- V10: Session Heartbeat / Host Active Status
-- Adds last_heartbeat_at to sessions to track if the teacher is still connected.

begin;

-- 1. Add column to sessions
alter table public.sessions 
add column if not exists last_heartbeat_at timestamptz default now();

-- 2. Create heartbeat RPC
create or replace function public.touch_session_heartbeat(
  p_session_id uuid
)
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

grant execute on function public.touch_session_heartbeat(uuid) to authenticated;

-- 3. Update get_bingo_live_state to include host_active
create or replace function public.get_bingo_session_teacher(
  p_session_id uuid
)
returns jsonb
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

  if not public.is_session_teacher(p_session_id) then
    raise exception 'Session access required';
  end if;

  select *
  into v_session
  from public.sessions
  where id = p_session_id
  limit 1;

  return jsonb_build_object(
    'id', v_session.id,
    'title', v_session.title,
    'status', v_session.status,
    'join_code', v_session.join_code,
    'settings', v_session.settings
  );
end;
$$;

grant execute on function public.get_bingo_session_teacher(uuid) to authenticated;

-- 4. Update get_bingo_live_state to include host_active
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
  v_bingo_winner_names jsonb := '[]'::jsonb;
  v_bingo_podium jsonb := '[]'::jsonb;
  v_fastest_participant jsonb := null;
  v_speed_leaderboard jsonb := '[]'::jsonb;
  v_host_active boolean := false;
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

  -- Host is active if last heartbeat was within the last 20 seconds
  v_host_active := (v_session.last_heartbeat_at > (now() - interval '20 seconds'));

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

  -- fastest_participant
  select jsonb_build_object(
    'name', sp.display_name,
    'seconds', extract(epoch from (pdr.answered_at - v_state.current_draw_opened_at))
  )
  into v_fastest_participant
  from public.participant_draw_responses pdr
  join public.session_participants sp on sp.id = pdr.participant_id
  where pdr.session_id = p_session_id
    and pdr.round_number = coalesce(v_state.round_number, 0)
    and pdr.draw_index = coalesce(v_state.draw_index, 0)
    and pdr.correct = true
    and pdr.answered_at is not null
  order by pdr.answered_at asc
  limit 1;

  -- speed_leaderboard
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
    join public.session_events se on se.session_id = pdr.session_id
      and se.event_type = 'draw_opened'
      and (se.payload->>'round_number')::int = pdr.round_number
      and (se.payload->>'draw_index')::int = pdr.draw_index
    where pdr.session_id = p_session_id
      and pdr.round_number = coalesce(v_state.round_number, 0)
      and pdr.correct = true
      and pdr.answered_at is not null
    group by sp.display_name
    order by avg_seconds asc
    limit 3
  ) sub;

  select coalesce(jsonb_agg(sp.display_name order by prb.bingo_at_draw_index asc nulls last), '[]'::jsonb)
  into v_bingo_winner_names
  from public.participant_round_boards prb
  join public.session_participants sp on sp.id = prb.participant_id
  where prb.session_id = p_session_id
    and prb.round_number = coalesce(v_state.round_number, 0)
    and prb.has_bingo = true;

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
    where prb.session_id = p_session_id
      and prb.round_number = coalesce(v_state.round_number, 0)
      and prb.has_bingo = true
    order by prb.bingo_at_draw_index asc nulls last
    limit 3
  ) sub;

  return jsonb_build_object(
    'session', jsonb_build_object(
      'id', v_session.id,
      'title', v_session.title,
      'status', v_session.status,
      'join_code', v_session.join_code,
      'settings', v_session.settings,
      'host_active', v_host_active
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
      'bingo_count', v_bingo_count,
      'bingo_winners', v_bingo_winner_names,
      'bingo_podium', v_bingo_podium,
      'fastest_participant', v_fastest_participant,
      'speed_leaderboard', v_speed_leaderboard
    )
  );
end;
$$;

commit;
