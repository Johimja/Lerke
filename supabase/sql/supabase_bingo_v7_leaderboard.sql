-- V7: get_session_leaderboard RPC
-- Returns per-participant stats for a session, ranked by bingo count then correct answers.
-- Callable by any authenticated session participant or teacher.

create or replace function public.get_session_leaderboard(p_session_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_result jsonb;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  if not public.is_session_teacher(p_session_id) and not public.is_session_participant(p_session_id) then
    raise exception 'Session access required';
  end if;

  select coalesce(
    jsonb_agg(
      row_data
      order by (row_data->>'bingo_total')::int desc,
               (row_data->>'correct_total')::int desc,
               row_data->>'name'
    ),
    '[]'::jsonb
  )
  into v_result
  from (
    select jsonb_build_object(
      'name', sp.display_name,
      'bingo_total', coalesce((
        select sum(prb.bingo_count)
        from public.participant_round_boards prb
        where prb.participant_id = sp.id
          and prb.session_id = p_session_id
      ), 0),
      'correct_total', coalesce((
        select count(*)
        from public.participant_draw_responses pdr
        where pdr.participant_id = sp.id
          and pdr.session_id = p_session_id
          and pdr.correct = true
      ), 0),
      'total_answers', coalesce((
        select count(*)
        from public.participant_draw_responses pdr
        where pdr.participant_id = sp.id
          and pdr.session_id = p_session_id
      ), 0),
      'fastest_bingo_draw', (
        select min(prb.bingo_at_draw_index)
        from public.participant_round_boards prb
        where prb.participant_id = sp.id
          and prb.session_id = p_session_id
          and prb.has_bingo = true
      )
    ) as row_data
    from public.session_participants sp
    where sp.session_id = p_session_id
      and sp.status in ('active', 'inactive')
  ) sub;

  return v_result;
end;
$$;

revoke all on function public.get_session_leaderboard(uuid) from public;
grant execute on function public.get_session_leaderboard(uuid) to authenticated;
