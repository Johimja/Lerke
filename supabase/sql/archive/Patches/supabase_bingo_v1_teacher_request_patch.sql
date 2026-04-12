-- Lerke Bingo V1
-- Incremental patch: teacher approval request RPC

begin;

create or replace function public.request_teacher_access()
returns public.teacher_profiles
language plpgsql
security definer
set search_path = public
as $$
declare
  v_profile public.teacher_profiles;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  insert into public.teacher_profiles (
    user_id,
    is_teacher,
    is_approved
  )
  values (
    auth.uid(),
    true,
    false
  )
  on conflict (user_id) do update
    set is_teacher = true,
        updated_at = now()
  returning * into v_profile;

  return v_profile;
end;
$$;

revoke all on function public.request_teacher_access() from public;
grant execute on function public.request_teacher_access() to authenticated;

commit;
