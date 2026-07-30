-- V21: Avatar paid color changes
-- Adds purchase_avatar_color(p_color_slot, p_color) RPC.
-- Students pay 25 XP to change a named color slot in their avatar_data.
-- Initial allowed slot: 'skinColor' (the face silhouette tint).
-- White (#ffffff) is the default; resetting to white is handled client-side via
-- save_student_avatar and costs no XP — this RPC is for paid non-white colors.
--
-- avatar_data shape after this patch:
--   { "head": "head_basic", "acc": "acc_none", "skinColor": "#ffb4a0" }
--
-- No schema changes — avatar_data (jsonb) column already exists from v13.

create or replace function public.purchase_avatar_color(
  p_color_slot text,
  p_color      text
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_cost        constant integer := 25;
  v_student_id  uuid;
  v_current_xp  integer;
  v_current_av  jsonb;
  v_new_av      jsonb;
begin
  -- validate slot
  if not (p_color_slot = any(array['skinColor'])) then
    return jsonb_build_object('ok', false, 'error', 'Ugyldig fargetype');
  end if;

  -- validate hex color (#rrggbb)
  if p_color !~ '^#[0-9a-fA-F]{6}$' then
    return jsonb_build_object('ok', false, 'error', 'Ugyldig farge');
  end if;

  -- resolve student profile
  select id, total_xp, avatar_data
    into v_student_id, v_current_xp, v_current_av
    from public.student_profiles
   where auth_user_id = auth.uid()
   limit 1;

  if v_student_id is null then
    return jsonb_build_object('ok', false, 'error', 'Fant ikke elevprofil');
  end if;

  -- check XP balance
  if v_current_xp < v_cost then
    return jsonb_build_object('ok', false, 'error', 'Ikke nok XP');
  end if;

  -- merge color slot into avatar_data
  v_new_av := coalesce(v_current_av, '{}'::jsonb) || jsonb_build_object(p_color_slot, p_color);

  update public.student_profiles
     set total_xp    = total_xp - v_cost,
         avatar_data = v_new_av
   where id = v_student_id;

  return jsonb_build_object(
    'ok',         true,
    'total_xp',   v_current_xp - v_cost,
    'level',      floor((v_current_xp - v_cost)::numeric / 100) + 1,
    'avatar_data', v_new_av,
    'xp_spent',   v_cost
  );
end;
$$;

grant execute on function public.purchase_avatar_color(text, text) to authenticated;
