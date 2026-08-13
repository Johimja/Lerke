-- Avatar-9: Paid skin color changes (v21)
-- Adds purchase_avatar_color(p_color_slot, p_color) RPC.
-- Cost: 25 XP per color change. Currently only 'skinColor' slot is supported.
-- Color is stored in avatar_data JSONB and round-trips via save_student_avatar / get_current_student_profile.
-- Already applied to Supabase project isuzuuvddteejktcowev.

create or replace function public.purchase_avatar_color(p_color_slot text, p_color text)
returns jsonb
language plpgsql
security definer
set search_path = 'public'
as $$
declare
  v_profile  student_profiles%rowtype;
  v_cost     int := 25;
  v_valid_slots text[] := array['skinColor'];
  v_avatar_data jsonb;
begin
  select sp.* into v_profile
  from student_profiles sp
  where sp.auth_user_id = auth.uid()
  limit 1;

  if not found then
    return jsonb_build_object('ok', false, 'error', 'Ingen elevprofil funnet');
  end if;

  if not (p_color_slot = any(v_valid_slots)) then
    return jsonb_build_object('ok', false, 'error', 'Ugyldig fargeplass');
  end if;

  if p_color !~ '^#[0-9a-fA-F]{6}$' then
    return jsonb_build_object('ok', false, 'error', 'Ugyldig fargeformat (forventet #rrggbb)');
  end if;

  if v_profile.total_xp < v_cost then
    return jsonb_build_object('ok', false, 'error', 'Ikke nok XP (trenger ' || v_cost || ' XP)');
  end if;

  v_avatar_data := coalesce(v_profile.avatar_data, '{}'::jsonb);
  v_avatar_data := jsonb_set(v_avatar_data, array[p_color_slot], to_jsonb(p_color));

  update student_profiles
  set total_xp    = total_xp - v_cost,
      avatar_data = v_avatar_data
  where id = v_profile.id;

  return jsonb_build_object(
    'ok',         true,
    'total_xp',   v_profile.total_xp - v_cost,
    'color_slot', p_color_slot,
    'color',      p_color
  );
end;
$$;

grant execute on function public.purchase_avatar_color(text, text) to authenticated, anon;
