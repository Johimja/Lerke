-- =========================================================
-- V14: Student stats + class hall of fame
-- =========================================================
-- New RPCs:
--   get_student_stats() — returns rounds_played, rounds_won,
--       longest_win_streak, podium_count (top-3 finishes),
--       sessions_played for the logged-in student.
--   get_class_hall_of_fame(p_class_id) — teacher-facing leaderboard
--       for all students in a class, sorted by rounds_won desc.
-- No schema changes needed — uses existing tables.
-- =========================================================

-- =========================================================
-- 1. RPC: student fetches own lifetime stats
-- =========================================================

create or replace function public.get_student_stats()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_student_id uuid;
  v_rounds_played integer;
  v_rounds_won integer;
  v_podium_count integer;
  v_sessions_played integer;
  v_longest_streak integer;
begin
  -- Resolve student_id from auth session
  select student_id into v_student_id
  from public.student_auth_links
  where auth_user_id = auth.uid()
  limit 1;

  if v_student_id is null then
    raise exception 'Student profile not found';
  end if;

  -- Basic counts
  select
    count(*)::integer,
    count(*) filter (where prb.has_bingo = true)::integer
  into v_rounds_played, v_rounds_won
  from public.participant_round_boards prb
  join public.session_participants sp on sp.id = prb.participant_id
  where sp.student_profile_id = v_student_id;

  -- Top-3 (podium) count: rounds where bingo_at_draw_index is in top 3 for that session+round
  select count(*)::integer into v_podium_count
  from (
    select prb.id,
           rank() over (
             partition by prb.session_id, prb.round_number
             order by prb.bingo_at_draw_index asc nulls last
           ) as rnk
    from public.participant_round_boards prb
    join public.session_participants sp on sp.id = prb.participant_id
    where sp.student_profile_id = v_student_id
      and prb.has_bingo = true
      and prb.bingo_at_draw_index is not null
  ) sub
  where sub.rnk <= 3;

  -- Sessions played (distinct sessions)
  select count(distinct sp.session_id)::integer into v_sessions_played
  from public.session_participants sp
  where sp.student_profile_id = v_student_id;

  -- Longest win streak (consecutive rounds across all sessions, ordered chronologically)
  select coalesce(max(streak_len), 0)::integer into v_longest_streak
  from (
    select count(*) as streak_len
    from (
      select has_bingo,
             rn - row_number() over (partition by has_bingo order by rn) as grp
      from (
        select prb.has_bingo,
               row_number() over (
                 order by s.created_at, prb.round_number
               ) as rn
        from public.participant_round_boards prb
        join public.session_participants sp on sp.id = prb.participant_id
        join public.sessions s on s.id = prb.session_id
        where sp.student_profile_id = v_student_id
      ) ordered
    ) grouped
    where has_bingo = true
    group by grp
  ) streaks;

  return jsonb_build_object(
    'rounds_played',      v_rounds_played,
    'rounds_won',         v_rounds_won,
    'podium_count',       v_podium_count,
    'sessions_played',    v_sessions_played,
    'longest_win_streak', v_longest_streak
  );
end;
$$;

grant execute on function public.get_student_stats() to authenticated, anon;

-- =========================================================
-- 2. RPC: class hall of fame (teacher-facing)
-- =========================================================

create or replace function public.get_class_hall_of_fame(p_class_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_result jsonb;
begin
  select coalesce(jsonb_agg(row_data order by (row_data->>'rounds_won')::int desc, (row_data->>'total_xp')::int desc), '[]'::jsonb)
  into v_result
  from (
    select jsonb_build_object(
      'display_name',       sp.display_name,
      'total_xp',           coalesce(sp.total_xp, 0),
      'level',              public.xp_to_level(coalesce(sp.total_xp, 0)),
      'rounds_played',      coalesce(counts.rounds_played, 0),
      'rounds_won',         coalesce(counts.rounds_won, 0),
      'sessions_played',    coalesce(counts.sessions_played, 0),
      'avatar_data',        sp.avatar_data
    ) as row_data
    from public.student_profiles sp
    left join lateral (
      select
        count(prb.id)::int as rounds_played,
        count(prb.id) filter (where prb.has_bingo = true)::int as rounds_won,
        count(distinct part.session_id)::int as sessions_played
      from public.session_participants part
      join public.participant_round_boards prb on prb.participant_id = part.id
      where part.student_profile_id = sp.id
    ) counts on true
    where sp.class_id = p_class_id
      and sp.status = 'active'
  ) sub;

  return v_result;
end;
$$;

grant execute on function public.get_class_hall_of_fame(uuid) to authenticated, anon;
