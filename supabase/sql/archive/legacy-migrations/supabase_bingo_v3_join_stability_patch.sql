-- Lerke Bingo V3
-- Join stability patch
--
-- Run this after:
-- 1. supabase_bingo_v1_sql_editor_ready.sql
-- 2. supabase_student_accounts_v1_core_patch.sql
-- 3. supabase_bingo_v2_strict_live_patch.sql
--
-- This patch hardens student join against duplicate/concurrent join attempts
-- by using conflict-safe upserts and a shorter lock timeout.

begin;

alter table public.session_participants
  drop constraint if exists session_participants_client_token_key;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'session_participants_session_id_client_token_key'
      and conrelid = 'public.session_participants'::regclass
  ) then
    alter table public.session_participants
      add constraint session_participants_session_id_client_token_key
      unique (session_id, client_token);
  end if;
end
$$;

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
  v_student_profile_id uuid;
  v_student_display_name text;
  v_existing_found boolean := false;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  if nullif(trim(p_client_token), '') is null then
    raise exception 'Client token required';
  end if;

  perform set_config('lock_timeout', '1500ms', true);

  select *
  into v_session
  from public.sessions s
  where s.join_code = upper(trim(p_join_code))
    and s.activity_slug = 'bingo'
    and s.status in ('draft', 'live')
    and s.expires_at > now()
  order by s.created_at desc
  limit 1;

  if not found then
    raise exception 'Session not found or not joinable';
  end if;

  select sp.id, sp.display_name
  into v_student_profile_id, v_student_display_name
  from public.student_auth_links sal
  join public.student_profiles sp on sp.id = sal.student_id
  join public.classes c on c.id = sp.class_id
  where sal.auth_user_id = auth.uid()
    and sp.status = 'active'
    and c.status = 'active'
  limit 1;

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
    v_existing_found := true;

    update public.session_participants
    set auth_user_id = auth.uid(),
        client_token = p_client_token,
        display_name = coalesce(v_student_display_name, display_name),
        student_profile_id = coalesce(v_student_profile_id, student_profile_id),
        last_seen_at = now(),
        status = 'active'
    where id = v_participant.id
    returning * into v_participant;

    return v_participant;
  end if;

  begin
    insert into public.session_participants (
      session_id,
      auth_user_id,
      student_profile_id,
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
      v_student_profile_id,
      coalesce(v_student_display_name, public.generate_nickname()),
      'student',
      p_client_token,
      0,
      now(),
      'active'
    )
    on conflict (session_id, auth_user_id) do update
      set client_token = excluded.client_token,
          display_name = coalesce(v_student_display_name, public.session_participants.display_name),
          student_profile_id = coalesce(v_student_profile_id, public.session_participants.student_profile_id),
          last_seen_at = now(),
          status = 'active'
    returning * into v_participant;
  exception
    when unique_violation then
      insert into public.session_participants (
        session_id,
        auth_user_id,
        student_profile_id,
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
        v_student_profile_id,
        coalesce(v_student_display_name, public.generate_nickname()),
        'student',
        p_client_token,
        0,
        now(),
        'active'
      )
      on conflict (session_id, client_token) do update
        set auth_user_id = auth.uid(),
            display_name = coalesce(v_student_display_name, public.session_participants.display_name),
            student_profile_id = coalesce(v_student_profile_id, public.session_participants.student_profile_id),
            last_seen_at = now(),
            status = 'active'
      returning * into v_participant;
  end;

  if v_participant.id is null then
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
  end if;

  if v_participant.id is null then
    raise exception 'Participant join is still being registered, please try again';
  end if;

  if not v_existing_found then
    insert into public.session_events (session_id, event_type, actor_user_id, payload)
    values (
      v_session.id,
      'student_joined',
      auth.uid(),
      jsonb_build_object(
        'participant_id', v_participant.id,
        'display_name', v_participant.display_name,
        'student_profile_id', v_participant.student_profile_id
      )
    );
  end if;

  return v_participant;
exception
  when lock_not_available or query_canceled then
    raise exception 'Join request is busy, please try again';
end;
$$;

commit;
