-- =========================================================
-- V21: Paid avatar color changes (Avatar-9)
-- =========================================================
-- Adds purchase_avatar_color(p_color_slot, p_color) RPC.
-- Cost: 25 XP per color change. Only 'skinColor' is a valid
-- slot in this release — colors the face-shape silhouette layer.
-- Validates hex format, checks XP, deducts cost, patches avatar_data.
-- No schema changes — avatar_data jsonb column already exists from V13.
-- =========================================================

create or replace function public.purchase_avatar_color(
  p_color_slot text,
  p_color      text
)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_student_id  uuid;
  v_profile_id  uuid;
  v_current_xp  integer;
  v_cost        integer := 25;
  v_avatar_data jsonb;
  v_hex         text;
begin
  -- Validate slot (only skinColor for Avatar-9)
  if p_color_slot not in ('skinColor') then
    return json_build_object('ok', false, 'error', 'Ugyldig fargespor');
  end if;

  -- Validate hex color: must be exactly #rrggbb
  if p_color !~ '^#[0-9a-fA-F]{6}$' then
    return json_build_object('ok', false, 'error', 'Ugyldig fargeformat');
  end if;
  v_hex := lower(p_color);

  -- Resolve authenticated student
  v_student_id := auth.uid();
  if v_student_id is null then
    return json_build_object('ok', false, 'error', 'Ikke innlogget');
  end if;

  select id, total_xp, coalesce(avatar_data, '{}'::jsonb)
    into v_profile_id, v_current_xp, v_avatar_data
    from student_profiles
   where auth_id = v_student_id;

  if v_profile_id is null then
    return json_build_object('ok', false, 'error', 'Elevprofil ikke funnet');
  end if;

  -- Check XP balance
  if v_current_xp < v_cost then
    return json_build_object('ok', false, 'error', 'Ikke nok XP');
  end if;

  -- Deduct XP and patch the color slot in avatar_data
  update student_profiles
     set total_xp    = total_xp - v_cost,
         avatar_data = v_avatar_data || jsonb_build_object(p_color_slot, v_hex),
         updated_at  = now()
   where id = v_profile_id;

  return json_build_object(
    'ok',        true,
    'total_xp',  v_current_xp - v_cost,
    'level',     floor((v_current_xp - v_cost) / 100.0)::int + 1,
    'color_slot', p_color_slot,
    'color',     v_hex,
    'xp_spent',  v_cost
  );
end;
$$;

grant execute on function public.purchase_avatar_color(text, text) to authenticated;
