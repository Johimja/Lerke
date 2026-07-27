-- =========================================================
-- V21: Avatar paid color changes (Avatar-9)
-- =========================================================
-- New RPC purchase_avatar_color(p_color_slot, p_color):
--   Validates slot name ('skinColor' only for now) and hex format,
--   deducts 25 XP, merges the color key into avatar_data, and
--   returns the updated state in one transaction.
--   Reset to white/default (skinColor:null) is free and handled
--   client-side via the existing save_student_avatar RPC.
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
  v_total_xp    integer;
  v_avatar_data jsonb;
  v_cost        integer := 25;
begin
  -- Validate color slot name
  if p_color_slot not in ('skinColor') then
    return jsonb_build_object('ok', false, 'error', 'Ugyldig fargesport');
  end if;

  -- Validate hex color format (#rrggbb, case-insensitive)
  if p_color !~ '^#[0-9a-fA-F]{6}$' then
    return jsonb_build_object('ok', false, 'error', 'Ugyldig fargeformat');
  end if;

  -- Resolve student profile via auth link
  select sp.id, sp.total_xp, sp.avatar_data
  into v_student_id, v_total_xp, v_avatar_data
  from public.student_profiles sp
  join public.student_auth_links sal on sal.student_id = sp.id
  where sal.auth_user_id = auth.uid()
  limit 1;

  if not found then
    return jsonb_build_object('ok', false, 'error', 'Fant ikke elevprofil');
  end if;

  -- Check sufficient XP
  if v_total_xp < v_cost then
    return jsonb_build_object('ok', false, 'error', 'For lite XP');
  end if;

  -- Deduct XP and merge color into avatar_data
  v_total_xp    := v_total_xp - v_cost;
  v_avatar_data := coalesce(v_avatar_data, '{}'::jsonb) || jsonb_build_object(p_color_slot, p_color);

  update public.student_profiles
  set total_xp    = v_total_xp,
      avatar_data = v_avatar_data
  where id = v_student_id;

  return jsonb_build_object(
    'ok',          true,
    'total_xp',    v_total_xp,
    'level',       floor(v_total_xp::numeric / 100) + 1,
    'avatar_data', v_avatar_data,
    'xp_spent',    v_cost
  );
end;
$$;

grant execute on function public.purchase_avatar_color(text, text) to authenticated;
