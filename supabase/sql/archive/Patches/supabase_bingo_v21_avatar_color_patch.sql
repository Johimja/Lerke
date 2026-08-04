-- =========================================================
-- V21: Paid avatar color changes
-- =========================================================
-- New RPC: purchase_avatar_color(p_color_slot text, p_color text)
--   Deducts 25 XP, merges the chosen color into avatar_data.
--   Valid slots: 'headColor', 'accColor'
--   p_color must match ^#[0-9a-fA-F]{6}$  (6-digit hex, case-insensitive)
--   Returns: {ok, total_xp, avatar_data, xp_spent}
-- =========================================================

create or replace function public.purchase_avatar_color(
  p_color_slot text,
  p_color      text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_student_id  uuid;
  v_xp          integer;
  v_avatar_data jsonb;
  v_cost constant integer := 25;
begin
  -- validate slot
  if p_color_slot not in ('headColor', 'accColor') then
    return jsonb_build_object('ok', false, 'error', 'Ugyldig fargeplass: ' || coalesce(p_color_slot, ''));
  end if;

  -- validate hex color (#rrggbb, case-insensitive)
  if p_color is null or p_color !~ '^#[0-9a-fA-F]{6}$' then
    return jsonb_build_object('ok', false, 'error', 'Ugyldig farge: ' || coalesce(p_color, ''));
  end if;

  -- resolve student
  select s.id, s.total_xp, s.avatar_data
  into v_student_id, v_xp, v_avatar_data
  from public.student_profiles s
  join public.student_auth_links l on l.student_id = s.id
  where l.auth_user_id = auth.uid()
  limit 1;

  if not found then
    return jsonb_build_object('ok', false, 'error', 'Elevprofil ikke funnet');
  end if;

  -- check XP
  if v_xp < v_cost then
    return jsonb_build_object('ok', false, 'error', 'Ikke nok XP (trenger ' || v_cost || ')');
  end if;

  -- deduct XP and merge color into avatar_data
  update public.student_profiles
  set
    total_xp    = total_xp - v_cost,
    avatar_data = coalesce(avatar_data, '{}'::jsonb)
                  || jsonb_build_object(p_color_slot, lower(p_color))
  where id = v_student_id
  returning total_xp, avatar_data into v_xp, v_avatar_data;

  return jsonb_build_object(
    'ok',          true,
    'total_xp',    v_xp,
    'avatar_data', v_avatar_data,
    'xp_spent',    v_cost
  );
end;
$$;

grant execute on function public.purchase_avatar_color(text, text) to authenticated, anon;
