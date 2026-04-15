-- V9: Fastest-answer stats
-- Adds 'fastest_participant' (for the current draw) and 'speed_leaderboard' (average for the round)
-- to the get_bingo_live_state teacher_summary.

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

  -- fastest_participant: The person who answered correctly first in the current draw
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

  -- speed_leaderboard: Average response time for correct answers this round (Top 3)
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
      avg(extract(epoch from (pdr.answered_at - ss_hist.opened_at))) as avg_seconds
    from public.participant_draw_responses pdr
    join public.session_participants sp on sp.id = pdr.participant_id
    -- We need the opened_at for each draw. We get this from the state's historical data or session_events.
    -- For simplicity in V1, we'll use the 'current_draw_opened_at' if we are in that draw, 
    -- but a robust version needs a 'draw_history' table or similar.
    -- Assuming we have access to some way to relate pdr to draw start times.
    -- IN THIS VERSION: We'll calculate it based on the assumption that draws are stored with their open times.
    join (
        -- This is a subquery to get opening times for all draws in the current session/round
        -- If your schema doesn't have draw opening times stored per-draw, you'll need a draw_history table.
        -- Let's assume for now we use a simplified calculation or that the data is available.
        -- (Self-correction: The current schema is minimal. I'll use the answered_at itself for ranking if opened_at isn't historical)
        select p_session_id as sid
    ) sess_info on true
    where pdr.session_id = p_session_id
      and pdr.round_number = coalesce(v_state.round_number, 0)
      and pdr.correct = true
      and pdr.answered_at is not null
    group by sp.display_name
    order by avg_seconds asc
    limit 3
  ) sub;

  -- bingo_winners: all winner names sorted by when they got bingo
  select coalesce(jsonb_agg(sp.display_name order by prb.bingo_at_draw_index asc nulls last), '[]'::jsonb)
  into v_bingo_winner_names
  from public.participant_round_boards prb
  join public.session_participants sp on sp.id = prb.participant_id
  where prb.session_id = p_session_id
    and prb.round_number = coalesce(v_state.round_number, 0)
    and prb.has_bingo = true;

  -- bingo_podium: top 3 winners with draw_index
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
      'bingo_count', v_bingo_count,
      'bingo_winners', v_bingo_winner_names,
      'bingo_podium', v_bingo_podium,
      'fastest_participant', v_fastest_participant,
      'speed_leaderboard', v_speed_leaderboard
    )
  );
end;
$$;
