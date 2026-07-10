-- =============================================================
-- Lerke Bingo — v21: Paid avatar color changes
-- =============================================================
-- Adds purchase_avatar_color(p_color_slot text, p_color text)
-- Valid slots: headColor, accColor
-- Cost: 25 XP per change (overwrites previous color).
-- Updates avatar_data jsonb in student_profiles.
-- Returns {ok, total_xp, avatar_data, xp_spent} on success.
-- =============================================================

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
  v_current_xp  int;
  v_avatar_data jsonb;
  v_cost        int := 25;
begin
  -- validate slot
  if p_color_slot not in ('headColor', 'accColor') then
    return jsonb_build_object('ok', false, 'error', 'Ugyldig fargespor');
  end if;

  -- validate hex color (#rrggbb, case-insensitive)
  if p_color !~ '^#[0-9a-fA-F]{6}$' then
    return jsonb_build_object('ok', false, 'error', 'Ugyldig farge');
  end if;

  -- resolve student via student_auth_links
  select sal.student_id into v_student_id
  from public.student_auth_links sal
  where sal.auth_user_id = auth.uid()
  limit 1;

  if v_student_id is null then
    return jsonb_build_object('ok', false, 'error', 'Ikke innlogget');
  end if;

  -- fetch current XP and avatar_data
  select total_xp, coalesce(avatar_data, '{}'::jsonb)
  into   v_current_xp, v_avatar_data
  from   public.student_profiles
  where  id = v_student_id;

  if v_current_xp < v_cost then
    return jsonb_build_object(
      'ok',       false,
      'error',    'Ikke nok XP',
      'total_xp', v_current_xp,
      'needed',   v_cost
    );
  end if;

  -- store normalized (lowercase) hex in avatar_data
  v_avatar_data := v_avatar_data || jsonb_build_object(p_color_slot, lower(p_color));

  update public.student_profiles
  set    total_xp    = total_xp - v_cost,
         avatar_data  = v_avatar_data,
         updated_at   = now()
  where  id = v_student_id
  returning total_xp into v_current_xp;

  return jsonb_build_object(
    'ok',          true,
    'total_xp',    v_current_xp,
    'avatar_data', v_avatar_data,
    'xp_spent',    v_cost
  );
end;
$$;

grant execute on function public.purchase_avatar_color(text, text) to authenticated, anon;
