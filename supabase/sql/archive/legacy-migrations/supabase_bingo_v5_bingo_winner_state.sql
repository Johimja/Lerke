-- V5: Add bingo_winners array to get_bingo_live_state teacher_summary
-- This allows student clients to see winner names from other students' bingo,
-- enabling "Elev A fikk bingo!" on non-winning student screens.

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

  select coalesce(jsonb_agg(sp.display_name order by sp.display_name), '[]'::jsonb)
  into v_bingo_winner_names
  from public.participant_round_boards prb
  join public.session_participants sp on sp.id = prb.participant_id
  where prb.session_id = p_session_id
    and prb.round_number = coalesce(v_state.round_number, 0)
    and prb.has_bingo = true;

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
      'bingo_winners', v_bingo_winner_names
    )
  );
end;
$$;
