-- V6: Add bingo_at_draw_index to participant_round_boards + bingo_podium to get_bingo_live_state
-- This enables gold/silver/bronze podium ranking on the teacher celebration overlay.
-- bingo_at_draw_index records which draw triggered each student's first bingo this round.

-- Step 1: Add column
alter table public.participant_round_boards
  add column if not exists bingo_at_draw_index integer;

-- Step 2: Update submit_bingo_answer to capture bingo_at_draw_index on first bingo
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
        end,
        bingo_at_draw_index = case
          when public.board_has_bingo(v_marked_cells) and has_bingo = false then v_state.draw_index
          else bingo_at_draw_index
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

-- Step 3: Update get_bingo_live_state to include bingo_podium (top 3 by bingo_at_draw_index)
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

  -- bingo_winners: all winner names sorted by when they got bingo (chronological)
  select coalesce(jsonb_agg(sp.display_name order by prb.bingo_at_draw_index asc nulls last), '[]'::jsonb)
  into v_bingo_winner_names
  from public.participant_round_boards prb
  join public.session_participants sp on sp.id = prb.participant_id
  where prb.session_id = p_session_id
    and prb.round_number = coalesce(v_state.round_number, 0)
    and prb.has_bingo = true;

  -- bingo_podium: top 3 winners with draw_index for ranking display
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
      'bingo_podium', v_bingo_podium
    )
  );
end;
$$;
