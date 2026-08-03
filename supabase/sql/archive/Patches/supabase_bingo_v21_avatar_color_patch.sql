-- supabase_bingo_v21_avatar_color_patch.sql
-- Avatar-9: Paid color changes.
-- Adds purchase_avatar_color(p_color_slot, p_color) RPC.
-- Cost: 25 XP per color change. No charge if same color as current.
-- Initially supports slot 'baseColor' only.
-- avatar_data already persisted via existing save_student_avatar RPC —
-- this RPC deducts XP and writes the new color directly to avatar_data.

-- ─── Migration record ────────────────────────────────────────────────────────
insert into public.schema_migrations(version) values('v21_avatar_color')
on conflict do nothing;

-- ─── RPC: purchase_avatar_color ──────────────────────────────────────────────
create or replace function public.purchase_avatar_color(
  p_color_slot text,
  p_color      text
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid          uuid := auth.uid();
  v_profile      student_profiles%rowtype;
  v_cost         int  := 25;
  v_allowed_slots text[] := array['baseColor'];
  v_new_avatar   jsonb;
begin
  -- validate slot
  if not (p_color_slot = any(v_allowed_slots)) then
    return jsonb_build_object('ok', false, 'error', 'Ugyldig fargeslot');
  end if;

  -- validate hex color: exactly #rrggbb
  if p_color !~ '^#[0-9a-fA-F]{6}$' then
    return jsonb_build_object('ok', false, 'error', 'Ugyldig farge');
  end if;

  -- look up profile
  select * into v_profile
  from student_profiles
  where auth_user_id = v_uid
    and is_active = true
  limit 1;

  if not found then
    return jsonb_build_object('ok', false, 'error', 'Profil ikke funnet');
  end if;

  -- same color → free (no XP charge)
  if coalesce(v_profile.avatar_data ->> p_color_slot, '') = p_color then
    return jsonb_build_object(
      'ok',        true,
      'xp_spent',  0,
      'total_xp',  v_profile.total_xp,
      'avatar_data', v_profile.avatar_data
    );
  end if;

  -- check XP
  if v_profile.total_xp < v_cost then
    return jsonb_build_object('ok', false, 'error', 'Ikke nok XP');
  end if;

  -- build updated avatar_data
  v_new_avatar := coalesce(v_profile.avatar_data, '{}'::jsonb)
                  || jsonb_build_object(p_color_slot, p_color);

  -- deduct XP and persist color
  update student_profiles
  set total_xp  = total_xp - v_cost,
      avatar_data = v_new_avatar,
      updated_at  = now()
  where id = v_profile.id;

  return jsonb_build_object(
    'ok',         true,
    'xp_spent',   v_cost,
    'total_xp',   v_profile.total_xp - v_cost,
    'avatar_data', v_new_avatar
  );
end;
$$;

grant execute on function public.purchase_avatar_color(text, text) to authenticated;
