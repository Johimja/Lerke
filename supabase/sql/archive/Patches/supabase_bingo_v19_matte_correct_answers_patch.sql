-- Lerke Bingo V19
-- Incremental patch: allow matte equation mode to accept multiple valid equations
--
-- Use this for existing databases that already have the live Bingo RPCs installed.
-- New databases should use the canonical fresh-install SQL snapshot instead.
--
-- The frontend can now send current_draw.correct_answers as a JSON array.
-- submit_bingo_answer accepts the clicked board value when it matches any value
-- in that array, and falls back to current_draw.answer for older draw payloads.

begin;

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

    if v_participant.student_profile_id is not null then
      v_xp_gained := 10;

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

revoke all on function public.submit_bingo_answer(uuid, integer, text) from public;
grant execute on function public.submit_bingo_answer(uuid, integer, text) to authenticated;

commit;
