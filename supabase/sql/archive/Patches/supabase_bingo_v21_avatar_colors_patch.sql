-- =========================================================
-- V21: Paid avatar color changes (Avatar-9)
-- =========================================================
-- Avatars are rendered from white-on-transparent silhouette sheets
-- (avatar_faceshapes.png, avatar_head_accessories.png) using CSS masks,
-- so the head/accessory layers can be tinted with any color at render
-- time. This patch adds a server-validated RPC that charges XP each
-- time a student saves a new color for the head or accessory layer.
-- No schema changes — colors are stored as extra keys
-- (headColor/accColor) inside the existing avatar_data jsonb column.
-- =========================================================

create or replace function public.purchase_avatar_color(p_color_slot text, p_color text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_student_id  uuid;
  v_current_xp  int;
  v_avatar_data jsonb;
  v_cost        constant int := 25;
  v_data_key    text;
begin
  if p_color_slot not in ('head', 'acc') then
    return jsonb_build_object('ok', false, 'error', 'Ugyldig fargefelt');
  end if;

  if p_color !~ '^#[0-9a-fA-F]{6}$' then
    return jsonb_build_object('ok', false, 'error', 'Ugyldig farge');
  end if;

  v_data_key := case p_color_slot when 'head' then 'headColor' else 'accColor' end;

  select sal.student_id into v_student_id
  from public.student_auth_links sal
  where sal.auth_user_id = auth.uid()
  limit 1;

  if v_student_id is null then
    return jsonb_build_object('ok', false, 'error', 'Ikke innlogget');
  end if;

  select total_xp, coalesce(avatar_data, '{}'::jsonb)
  into v_current_xp, v_avatar_data
  from public.student_profiles
  where id = v_student_id;

  if v_current_xp < v_cost then
    return jsonb_build_object('ok', false, 'error', 'Ikke nok XP', 'total_xp', v_current_xp, 'needed', v_cost);
  end if;

  v_avatar_data := v_avatar_data || jsonb_build_object(v_data_key, lower(p_color));

  update public.student_profiles
  set total_xp    = total_xp - v_cost,
      avatar_data = v_avatar_data
  where id = v_student_id
  returning total_xp into v_current_xp;

  return jsonb_build_object(
    'ok',          true,
    'total_xp',    v_current_xp,
    'avatar_data', v_avatar_data,
    'xp_spent',    v_cost
  );
end;
$$;

grant execute on function public.purchase_avatar_color(text, text) to authenticated, anon;
