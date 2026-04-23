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
