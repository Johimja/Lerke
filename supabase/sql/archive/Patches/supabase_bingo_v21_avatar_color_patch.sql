-- Avatar-9: paid color changes (v21)
-- Adds: purchase_avatar_color(p_color_slot, p_color)
--   Validates slot name and hex color, deducts 25 XP, saves <slot>Color into avatar_data.
--   Returns jsonb {ok, total_xp, avatar_data} on success; {ok:false, error} on failure.
-- Color cost: 25 XP per save (overwriting the previous color charges again).
-- Supported slots: 'head' (face-shape silhouette color). More slots added in future layers.

create or replace function public.purchase_avatar_color(
  p_color_slot text,
  p_color text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid          uuid    := auth.uid();
  v_cost         integer := 25;
  v_student      student_profiles%rowtype;
  v_color_key    text;
  v_new_avatar   jsonb;
  v_new_xp       integer;
begin
  -- Validate slot
  if p_color_slot not in ('head') then
    return jsonb_build_object('ok', false, 'error', 'Ugyldig fargespalte: ' || coalesce(p_color_slot, ''));
  end if;

  -- Validate hex color: #rgb or #rrggbb
  if p_color is null or p_color !~ '^#([0-9a-fA-F]{3}|[0-9a-fA-F]{6})$' then
    return jsonb_build_object('ok', false, 'error', 'Ugyldig fargeformat');
  end if;

  -- Get student profile
  select * into v_student
  from   student_profiles
  where  auth_user_id = v_uid;

  if not found then
    return jsonb_build_object('ok', false, 'error', 'Elevprofil ikke funnet');
  end if;

  -- Check XP
  if coalesce(v_student.total_xp, 0) < v_cost then
    return jsonb_build_object('ok', false, 'error', 'Ikke nok XP (trenger 25)');
  end if;

  -- Build the key name: headColor, hairColor, etc.
  v_color_key  := p_color_slot || 'Color';
  v_new_avatar := coalesce(v_student.avatar_data, '{}'::jsonb)
                  || jsonb_build_object(v_color_key, p_color);
  v_new_xp     := coalesce(v_student.total_xp, 0) - v_cost;

  update student_profiles
  set    total_xp   = v_new_xp,
         avatar_data = v_new_avatar
  where  auth_user_id = v_uid;

  return jsonb_build_object(
    'ok',         true,
    'total_xp',   v_new_xp,
    'avatar_data', v_new_avatar
  );
end;
$$;

grant execute on function public.purchase_avatar_color(text, text) to authenticated;
