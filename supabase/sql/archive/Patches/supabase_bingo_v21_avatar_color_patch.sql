-- =========================================================
-- V21: Paid avatar color changes (Avatar-9)
-- =========================================================
-- Adds `purchase_avatar_color(p_color_slot, p_color)` RPC.
-- Cost: 25 XP per color change (flat rate, no rarity).
-- Allowed slots: 'faceColor', 'accColor'.
-- The server writes directly into the avatar_data JSONB field
-- so the color persists alongside head/acc selection without
-- requiring a separate client-side `save_student_avatar` call.
-- No schema changes needed — avatar_data (jsonb) already exists
-- from V13. The client stores faceColor/accColor inside that field.
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
  v_current_xp  integer;
  v_avatar_data jsonb;
  v_cost        constant integer := 25;
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'error', 'Authentication required');
  end if;

  -- Validate slot
  if p_color_slot not in ('faceColor', 'accColor') then
    return jsonb_build_object('ok', false, 'error', 'Ugyldig fargeslot');
  end if;

  -- Validate hex color: must be exactly #RRGGBB
  if p_color !~ '^#[0-9A-Fa-f]{6}$' then
    return jsonb_build_object('ok', false, 'error', 'Ugyldig fargekode (bruk #RRGGBB)');
  end if;

  -- Resolve student
  select sp.id, coalesce(sp.total_xp, 0), coalesce(sp.avatar_data, '{}'::jsonb)
  into v_student_id, v_current_xp, v_avatar_data
  from public.student_auth_links sal
  join public.student_profiles sp on sp.id = sal.student_id
  where sal.auth_user_id = auth.uid()
    and sp.status = 'active'
  limit 1;

  if not found then
    return jsonb_build_object('ok', false, 'error', 'Elevprofil ikke funnet');
  end if;

  -- Check XP
  if v_current_xp < v_cost then
    return jsonb_build_object('ok', false, 'error', 'Ikke nok XP', 'total_xp', v_current_xp, 'needed', v_cost);
  end if;

  -- Deduct XP and merge color into avatar_data
  update public.student_profiles
  set total_xp   = total_xp - v_cost,
      avatar_data = coalesce(avatar_data, '{}'::jsonb) || jsonb_build_object(p_color_slot, lower(p_color))
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
