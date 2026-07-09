-- =========================================================
-- Lerke Bingo v21 — Avatar paid color changes
-- =========================================================
-- Adds: purchase_avatar_color(p_color_slot, p_color)
--   Valid slots: 'headColor', 'accColor'
--   Cost: 25 XP per color change (free if same color as stored)
--   Updates avatar_data jsonb in student_profiles.
--   Returns: {ok, total_xp, avatar_data} or {ok: false, error}
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
  v_student_id    uuid;
  v_cost          int := 25;
  v_current_xp    int;
  v_avatar_data   jsonb;
  v_current_color text;
begin
  -- Validate slot
  if p_color_slot not in ('headColor', 'accColor') then
    return jsonb_build_object('ok', false, 'error', 'Ugyldig fargefelt');
  end if;

  -- Validate hex color format
  if p_color !~ '^#[0-9a-fA-F]{6}$' then
    return jsonb_build_object('ok', false, 'error', 'Ugyldig farge (bruk #RRGGBB)');
  end if;

  -- Resolve student from auth
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

  -- No charge if color unchanged
  v_current_color := v_avatar_data ->> p_color_slot;
  if v_current_color is not null and lower(v_current_color) = lower(p_color) then
    return jsonb_build_object(
      'ok',          true,
      'already_same', true,
      'total_xp',    v_current_xp,
      'avatar_data', v_avatar_data
    );
  end if;

  if v_current_xp < v_cost then
    return jsonb_build_object(
      'ok',      false,
      'error',   'Ikke nok XP',
      'total_xp', v_current_xp,
      'needed',  v_cost
    );
  end if;

  -- Deduct XP and update the color slot inside avatar_data
  update public.student_profiles
  set
    total_xp    = total_xp - v_cost,
    avatar_data = coalesce(avatar_data, '{}'::jsonb) || jsonb_build_object(p_color_slot, p_color)
  where id = v_student_id
  returning total_xp, avatar_data into v_current_xp, v_avatar_data;

  return jsonb_build_object(
    'ok',         true,
    'total_xp',   v_current_xp,
    'avatar_data', v_avatar_data,
    'xp_spent',   v_cost
  );
end;
$$;

grant execute on function public.purchase_avatar_color(text, text) to authenticated, anon;
