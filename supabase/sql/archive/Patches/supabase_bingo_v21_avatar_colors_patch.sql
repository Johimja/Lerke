-- =========================================================
-- V21: Paid avatar skin color changes (Avatar-9)
-- =========================================================
-- Students can now pay 25 XP to set a skin color on their face-shape
-- silhouette.  The color is stored in avatar_data.skinColor as a
-- standard 6-digit hex string (e.g. "#F1C27D").  Changing the color
-- again costs another 25 XP — there is no "ownership", only per-save cost.
--
-- No schema changes needed:
--   - avatar_data jsonb  was added in V13
--   - total_xp integer  was added in V12
--
-- The frontend renders the tinted face silhouette using a CSS mask
-- applied to a colored <span> — no canvas or server-side image work.
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
  v_current_xp  int;
  v_avatar_data jsonb;
  v_cost        int := 25;
begin
  -- Validate color slot (only skinColor supported in v21)
  if p_color_slot is distinct from 'skinColor' then
    return jsonb_build_object('ok', false, 'error', 'Ugyldig fargespor');
  end if;

  -- Validate hex color: exactly '#' followed by exactly 6 hex characters
  if p_color !~ '^#[0-9A-Fa-f]{6}$' then
    return jsonb_build_object('ok', false, 'error', 'Ugyldig fargeformat');
  end if;

  -- Resolve student via auth link
  select sal.student_id into v_student_id
  from public.student_auth_links sal
  where sal.auth_user_id = auth.uid()
  limit 1;

  if v_student_id is null then
    return jsonb_build_object('ok', false, 'error', 'Ikke innlogget');
  end if;

  -- Fetch current XP and avatar_data
  select total_xp, coalesce(avatar_data, '{}'::jsonb)
  into v_current_xp, v_avatar_data
  from public.student_profiles
  where id = v_student_id;

  if v_current_xp < v_cost then
    return jsonb_build_object(
      'ok',     false,
      'error',  'Ikke nok XP',
      'total_xp', v_current_xp,
      'needed', v_cost
    );
  end if;

  -- Deduct XP and merge color into avatar_data
  update public.student_profiles
  set total_xp    = total_xp - v_cost,
      avatar_data = coalesce(avatar_data, '{}'::jsonb) || jsonb_build_object(p_color_slot, p_color)
  where id = v_student_id
  returning total_xp, avatar_data into v_current_xp, v_avatar_data;

  return jsonb_build_object(
    'ok',          true,
    'total_xp',    v_current_xp,
    'avatar_data', v_avatar_data,
    'xp_spent',    v_cost
  );
end;
$$;

grant execute on function public.purchase_avatar_color(text, text) to authenticated, anon;
