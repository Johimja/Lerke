-- =========================================================
-- V21: Avatar color customization (Avatar-9)
-- =========================================================
-- Adds paid color changes to the avatar system.
-- Colors stored in avatar_data JSONB: { ..., "skinColor": "#hex", "accColor": "#hex" }
-- Slots:
--   'skin' → skinColor  (face/silhouette tint)
--   'acc'  → accColor   (accessory/hat tint)
-- Cost: 25 XP per slot per save (changing again costs again).
-- No schema changes — avatar_data (v13) already accepts arbitrary JSONB.
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
  v_color_key   text;
  COLOR_COST    constant int := 25;
begin
  -- Validate color slot
  if p_color_slot not in ('skin', 'acc') then
    return jsonb_build_object('ok', false, 'error', 'Ugyldig fargespalte');
  end if;

  -- Validate hex color format (#RRGGBB only)
  if p_color !~ '^#[0-9a-fA-F]{6}$' then
    return jsonb_build_object('ok', false, 'error', 'Ugyldig fargeformat (bruk #RRGGBB)');
  end if;

  -- Resolve student_id via auth link
  select sal.student_id into v_student_id
  from public.student_auth_links sal
  where sal.auth_user_id = auth.uid()
  limit 1;

  if v_student_id is null then
    return jsonb_build_object('ok', false, 'error', 'Elevprofil ikke funnet');
  end if;

  -- Read current XP
  select total_xp into v_current_xp
  from public.student_profiles
  where id = v_student_id;

  if v_current_xp < COLOR_COST then
    return jsonb_build_object(
      'ok',    false,
      'error', 'Ikke nok XP (trenger ' || COLOR_COST || ' XP)'
    );
  end if;

  -- Map slot name to JSON key
  v_color_key := case p_color_slot
    when 'skin' then 'skinColor'
    when 'acc'  then 'accColor'
  end;

  -- Deduct XP and merge color into avatar_data atomically
  update public.student_profiles
  set total_xp   = total_xp - COLOR_COST,
      avatar_data = coalesce(avatar_data, '{}'::jsonb) || jsonb_build_object(v_color_key, p_color)
  where id = v_student_id
  returning total_xp, avatar_data into v_current_xp, v_avatar_data;

  return jsonb_build_object(
    'ok',          true,
    'total_xp',    v_current_xp,
    'avatar_data', v_avatar_data,
    'xp_spent',    COLOR_COST
  );
end;
$$;

grant execute on function public.purchase_avatar_color(text, text) to authenticated, anon;
