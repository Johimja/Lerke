-- =========================================================
-- V21: Paid avatar skin-color changes (Avatar-9)
-- =========================================================
-- Adds purchase_avatar_color(p_color_slot, p_color) RPC.
-- Fixed cost: 25 XP per color change.
-- Validates slot ('skin') and hex color format (#rrggbb).
-- Does NOT update avatar_data — the client calls save_student_avatar
-- immediately after to persist the new color alongside head/acc.
-- Returns {ok, total_xp, xp_spent} or {ok:false, error}.
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
  v_student_id uuid;
  v_current_xp int;
  v_color_cost constant int := 25;
begin
  -- Validate slot
  if p_color_slot not in ('skin') then
    return jsonb_build_object('ok', false, 'error', 'Ugyldig fargespor');
  end if;

  -- Validate hex color (#rrggbb)
  if p_color is null or p_color !~ '^#[0-9a-fA-F]{6}$' then
    return jsonb_build_object('ok', false, 'error', 'Ugyldig farge');
  end if;

  -- Resolve student via auth link
  select sal.student_id into v_student_id
  from public.student_auth_links sal
  where sal.auth_user_id = auth.uid()
  limit 1;

  if v_student_id is null then
    return jsonb_build_object('ok', false, 'error', 'Ikke innlogget');
  end if;

  -- Get current XP
  select total_xp into v_current_xp
  from public.student_profiles
  where id = v_student_id;

  if v_current_xp < v_color_cost then
    return jsonb_build_object('ok', false, 'error', 'Ikke nok XP', 'total_xp', v_current_xp);
  end if;

  -- Deduct XP
  update public.student_profiles
  set total_xp = total_xp - v_color_cost
  where id = v_student_id
  returning total_xp into v_current_xp;

  return jsonb_build_object(
    'ok',       true,
    'total_xp', v_current_xp,
    'xp_spent', v_color_cost
  );
end;
$$;

grant execute on function public.purchase_avatar_color(text, text) to authenticated, anon;
