-- Lerke Bingo V1
-- Incremental patch: create_bingo_session RPC
--
-- Use this if you have already run the main schema setup once
-- and only want to add the teacher-side session creation RPC.

begin;

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
        'live',
        coalesce(p_settings, '{}'::jsonb)
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
    updated_by
  )
  values (
    v_session.id,
    'setup',
    1,
    0,
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
      'round_count', v_round_number
    )
  );

  return v_session;
end;
$$;

revoke all on function public.create_bingo_session(text, jsonb, jsonb) from public;
grant execute on function public.create_bingo_session(text, jsonb, jsonb) to authenticated;

commit;
