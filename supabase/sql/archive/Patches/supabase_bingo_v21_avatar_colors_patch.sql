-- Lerke Bingo v21: paid avatar color changes
-- Adds purchase_avatar_color(p_color_slot, p_color) RPC
-- Valid slots: 'skinColor', 'accColor'
-- Valid colors: #rrggbb hex  |  null or '' = free reset to default (white sprite)
-- Cost: 25 XP per non-reset color save

set search_path = public;

-- =========================================================
-- purchase_avatar_color(p_color_slot text, p_color text)
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
  v_student_id   uuid;
  v_current_xp   int;
  v_avatar_data  jsonb;
  v_cost         int := 25;
begin
  -- Validate slot
  if p_color_slot not in ('skinColor', 'accColor') then
    return jsonb_build_object('ok', false, 'error', 'Ugyldig fargespor');
  end if;

  -- Validate hex color (null / empty string = free reset)
  if p_color is not null and p_color <> '' then
    if not (p_color ~* '^#[0-9a-f]{6}$') then
      return jsonb_build_object('ok', false, 'error', 'Ugyldig farge — bruk #rrggbb');
    end if;
  end if;

  -- Resolve student
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

  -- Reset color (free) — remove key from avatar_data
  if p_color is null or p_color = '' then
    update public.student_profiles
    set avatar_data = v_avatar_data - p_color_slot
    where id = v_student_id;
    return jsonb_build_object(
      'ok',        true,
      'total_xp',  v_current_xp,
      'avatar_data', v_avatar_data - p_color_slot,
      'xp_spent',  0
    );
  end if;

  -- Check XP
  if v_current_xp < v_cost then
    return jsonb_build_object('ok', false, 'error', 'Ikke nok XP (trenger ' || v_cost || ')');
  end if;

  -- Deduct XP and save color into avatar_data
  update public.student_profiles
  set total_xp    = total_xp - v_cost,
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
