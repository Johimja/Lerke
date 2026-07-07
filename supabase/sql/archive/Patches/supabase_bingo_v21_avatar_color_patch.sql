-- =========================================================
-- V21: Paid avatar color changes
-- =========================================================
-- Adds purchase_avatar_color(p_color_slot, p_color) RPC.
-- Allows students to pay 25 XP to change the tint color of
-- their head/body silhouette (skinColor) or accessory layer
-- (accColor). Resetting to white (#ffffff) is free.
-- avatar_data field is updated in-place (merged).
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
  v_total_xp    int;
  v_avatar_data jsonb;
  v_cost        int     := 25;
  v_allowed     text[]  := array['skinColor','accColor'];
begin
  -- validate slot name
  if not (p_color_slot = any(v_allowed)) then
    return jsonb_build_object('ok', false, 'error', 'Ugyldig fargekategori');
  end if;

  -- validate #rrggbb hex format (case-insensitive)
  if p_color !~ '^#[0-9a-fA-F]{6}$' then
    return jsonb_build_object('ok', false, 'error', 'Ugyldig fargeformat — bruk #rrggbb');
  end if;

  -- find the logged-in student profile
  select sp.id, sp.total_xp, sp.avatar_data
  into   v_student_id, v_total_xp, v_avatar_data
  from   public.student_profiles sp
  join   public.student_auth_links sal on sal.student_id = sp.id
  where  sal.auth_user_id = auth.uid()
  limit  1;

  if v_student_id is null then
    return jsonb_build_object('ok', false, 'error', 'Ingen elevkonto funnet');
  end if;

  -- resetting to white (#ffffff) is free
  if lower(p_color) = '#ffffff' then
    v_avatar_data := coalesce(v_avatar_data, '{}'::jsonb)
                  || jsonb_build_object(p_color_slot, '#ffffff');
    update public.student_profiles
    set    avatar_data = v_avatar_data
    where  id = v_student_id;
    return jsonb_build_object('ok', true, 'total_xp', v_total_xp, 'avatar_data', v_avatar_data);
  end if;

  -- check XP balance
  if v_total_xp < v_cost then
    return jsonb_build_object('ok', false, 'error', 'Ikke nok XP');
  end if;

  -- deduct XP and persist color into avatar_data
  v_avatar_data := coalesce(v_avatar_data, '{}'::jsonb)
                || jsonb_build_object(p_color_slot, lower(p_color));

  update public.student_profiles
  set    total_xp   = total_xp - v_cost,
         avatar_data = v_avatar_data
  where  id = v_student_id;

  return jsonb_build_object(
    'ok',         true,
    'total_xp',   v_total_xp - v_cost,
    'avatar_data', v_avatar_data
  );
end;
$$;

grant execute on function public.purchase_avatar_color(text, text) to authenticated, anon;
