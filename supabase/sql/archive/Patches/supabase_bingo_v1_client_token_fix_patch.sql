-- Lerke Bingo V1
-- Incremental patch: make student rejoin robust across renewed anonymous auth sessions
--
-- Fixes duplicate key errors on session_participants.client_token when a browser/device
-- keeps the same local client token but gets a new anonymous auth user in Supabase.

begin;

alter table public.session_participants
  drop constraint if exists session_participants_client_token_key;

create or replace function public.join_bingo_session(
  p_join_code text,
  p_client_token text
)
returns public.session_participants
language plpgsql
security definer
set search_path = public
as $$
declare
  v_session public.sessions;
  v_participant public.session_participants;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  select *
  into v_session
  from public.sessions s
  where s.join_code = upper(trim(p_join_code))
    and s.activity_slug = 'bingo'
    and s.status in ('draft', 'live')
    and s.expires_at > now()
  limit 1;

  if not found then
    raise exception 'Session not found or not joinable';
  end if;

  select *
  into v_participant
  from public.session_participants sp
  where sp.session_id = v_session.id
    and (
      sp.auth_user_id = auth.uid()
      or sp.client_token = p_client_token
    )
  order by case when sp.auth_user_id = auth.uid() then 0 else 1 end
  limit 1;

  if found then
    update public.session_participants
    set auth_user_id = auth.uid(),
        client_token = p_client_token,
        last_seen_at = now(),
        status = 'active'
    where id = v_participant.id
    returning * into v_participant;

    return v_participant;
  end if;

  insert into public.session_participants (
    session_id,
    auth_user_id,
    display_name,
    role,
    client_token,
    reroll_count,
    last_seen_at,
    status
  )
  values (
    v_session.id,
    auth.uid(),
    public.generate_nickname(),
    'student',
    p_client_token,
    0,
    now(),
    'active'
  )
  returning * into v_participant;

  insert into public.session_events (session_id, event_type, actor_user_id, payload)
  values (
    v_session.id,
    'student_joined',
    auth.uid(),
    jsonb_build_object(
      'participant_id', v_participant.id,
      'display_name', v_participant.display_name
    )
  );

  return v_participant;
end;
$$;

revoke all on function public.join_bingo_session(text, text) from public;
grant execute on function public.join_bingo_session(text, text) to authenticated;

commit;
