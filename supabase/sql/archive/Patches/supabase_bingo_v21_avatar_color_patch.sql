-- Avatar-9: paid color changes
-- Adds purchase_avatar_color(p_color_slot, p_color) RPC.
-- Cost: 25 XP per color change, always overwrites the previous color for that slot.
-- Valid slots: 'faceColor' (base face-silhouette tint).
-- avatar_data shape after this: { "head": "...", "acc": "...", "faceColor": "#rrggbb" }
-- No schema changes needed — avatar_data is already jsonb on student_profiles.

-- Migration guard
do $$
begin
  if exists (
    select 1 from public.schema_migrations where version = 'v21_avatar_color'
  ) then
    raise notice 'v21_avatar_color already applied, skipping';
    return;
  end if;
end;
$$;

-- =========================================================
-- 1. New RPC: purchase_avatar_color
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
  v_valid_slots text[] := array['faceColor'];
  v_cost        int    := 25;
  v_student_id  uuid;
  v_current_xp  int;
  v_avatar_data jsonb;
begin
  -- Validate slot
  if not (p_color_slot = any(v_valid_slots)) then
    return jsonb_build_object('ok', false, 'error', 'Ukjent fargeslot');
  end if;

  -- Validate hex color: must be #rrggbb or #rgb
  if p_color !~ '^#([0-9a-fA-F]{6}|[0-9a-fA-F]{3})$' then
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

  -- Fetch current XP and avatar_data
  select total_xp, coalesce(avatar_data, '{}'::jsonb)
  into v_current_xp, v_avatar_data
  from public.student_profiles
  where id = v_student_id;

  -- Check XP
  if v_current_xp < v_cost then
    return jsonb_build_object('ok', false, 'error', 'Ikke nok XP', 'total_xp', v_current_xp, 'needed', v_cost);
  end if;

  -- Merge color into avatar_data and deduct XP
  v_avatar_data := v_avatar_data || jsonb_build_object(p_color_slot, p_color);

  update public.student_profiles
  set total_xp    = total_xp - v_cost,
      avatar_data = v_avatar_data
  where id = v_student_id
  returning total_xp into v_current_xp;

  return jsonb_build_object(
    'ok',          true,
    'total_xp',    v_current_xp,
    'avatar_data', v_avatar_data
  );
end;
$$;

grant execute on function public.purchase_avatar_color(text, text) to authenticated, anon;

-- =========================================================
-- 2. Record migration
-- =========================================================

insert into public.schema_migrations (version) values ('v21_avatar_color')
on conflict (version) do nothing;
