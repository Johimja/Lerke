-- Lerke Bingo — v21 avatar color patch
-- Adds purchase_avatar_color(p_color_slot, p_color) RPC.
-- Cost: 25 XP per color change.
-- Supported slots: 'skinColor' (the face-shape silhouette fill color).
-- The RPC deducts XP and saves the color directly inside avatar_data jsonb.
-- Migration name: v21_avatar_color

create or replace function public.purchase_avatar_color(p_color_slot text, p_color text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_profile_id uuid;
  v_current_xp integer;
  v_avatar_data jsonb;
  v_cost constant integer := 25;
  v_valid_slots constant text[] := array['skinColor'];
begin
  -- validate slot
  if p_color_slot <> all(v_valid_slots) then
    return jsonb_build_object('ok', false, 'error', 'Ugyldig fargeslot');
  end if;

  -- validate hex color (#rrggbb)
  if p_color !~ '^#[0-9a-fA-F]{6}$' then
    return jsonb_build_object('ok', false, 'error', 'Ugyldig farge');
  end if;

  -- get authenticated student profile via auth link table
  select sp.id, sp.total_xp, coalesce(sp.avatar_data, '{}'::jsonb)
  into v_profile_id, v_current_xp, v_avatar_data
  from public.student_profiles sp
  join public.student_auth_links sal on sal.student_id = sp.id
  where sal.auth_user_id = auth.uid()
  limit 1;

  if v_profile_id is null then
    return jsonb_build_object('ok', false, 'error', 'Ingen elevprofil');
  end if;

  -- check XP
  if v_current_xp < v_cost then
    return jsonb_build_object('ok', false, 'error', 'Ikke nok XP', 'xp_needed', v_cost);
  end if;

  -- deduct XP and write color into avatar_data
  v_avatar_data := v_avatar_data || jsonb_build_object(p_color_slot, p_color);

  update public.student_profiles
  set total_xp   = total_xp - v_cost,
      avatar_data = v_avatar_data
  where id = v_profile_id;

  return jsonb_build_object(
    'ok',       true,
    'total_xp', v_current_xp - v_cost,
    'level',    floor((v_current_xp - v_cost)::numeric / 100) + 1,
    'xp_spent', v_cost
  );
end;
$$;

grant execute on function public.purchase_avatar_color(text, text) to authenticated;
