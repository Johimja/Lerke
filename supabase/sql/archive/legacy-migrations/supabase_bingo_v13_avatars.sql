-- =========================================================
-- V13: Student avatar system
-- =========================================================
-- Adds avatar_data (jsonb) to student_profiles.
-- avatar_data shape: { "color": "#hex", "accessory": "none|crown|star|lightning" }
-- New RPCs:
--   save_student_avatar(p_avatar_data) — student saves own avatar
--   get_session_student_avatars(p_session_id) — teacher fetches name→avatar map
-- get_current_student_profile updated to include avatar_data.
-- =========================================================

-- =========================================================
-- 1. Add avatar_data column
-- =========================================================

alter table public.student_profiles
  add column if not exists avatar_data jsonb default null;

-- =========================================================
-- 2. RPC: student saves own avatar
-- =========================================================

create or replace function public.save_student_avatar(p_avatar_data jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.student_profiles
  set avatar_data = p_avatar_data
  where id = (
    select student_id from public.student_auth_links
    where auth_user_id = auth.uid()
    limit 1
  );
  if not found then
    raise exception 'Student profile not found';
  end if;
  return jsonb_build_object('ok', true);
end;
$$;

grant execute on function public.save_student_avatar(jsonb) to authenticated, anon;

-- =========================================================
-- 3. RPC: teacher fetches avatars for all session participants
-- =========================================================

create or replace function public.get_session_student_avatars(p_session_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_result jsonb;
begin
  select jsonb_object_agg(sp.display_name, coalesce(sp.avatar_data, 'null'::jsonb))
  into v_result
  from public.session_participants part
  join public.student_profiles sp on sp.id = part.student_profile_id
  where part.session_id = p_session_id
    and part.student_profile_id is not null;
  return coalesce(v_result, '{}'::jsonb);
end;
$$;

grant execute on function public.get_session_student_avatars(uuid) to authenticated, anon;

-- =========================================================
-- 4. Update get_current_student_profile to include avatar_data
-- =========================================================

create or replace function public.get_current_student_profile()
returns jsonb
language sql
security definer
set search_path = public
as $$
  select jsonb_build_object(
    'student_id',   sp.id,
    'display_name', sp.display_name,
    'login_code',   sp.login_code,
    'student_code', sp.student_code,
    'class_id',     c.id,
    'class_name',   c.name,
    'class_code',   c.class_code,
    'total_xp',     coalesce(sp.total_xp, 0),
    'level',        public.xp_to_level(coalesce(sp.total_xp, 0)),
    'avatar_data',  sp.avatar_data
  )
  from public.student_auth_links sal
  join public.student_profiles sp on sp.id = sal.student_id
  join public.classes          c  on c.id  = sp.class_id
  where sal.auth_user_id = auth.uid()
    and sp.status = 'active'
    and c.status  = 'active'
  limit 1;
$$;

grant execute on function public.get_current_student_profile() to authenticated, anon;
