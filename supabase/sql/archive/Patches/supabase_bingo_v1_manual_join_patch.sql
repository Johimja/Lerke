-- Lerio Bingo V1
-- Incremental patch: manual student join support
--
-- Adds a safe RPC for fetching joinable bingo session metadata
-- so students can enter a join code manually instead of only using QR.

begin;

create or replace function public.get_joinable_bingo_session(p_join_code text)
returns public.sessions
language plpgsql
security definer
set search_path = public
as $$
declare
  v_session public.sessions;
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

  return v_session;
end;
$$;

revoke all on function public.get_joinable_bingo_session(text) from public;
grant execute on function public.get_joinable_bingo_session(text) to authenticated;

commit;
