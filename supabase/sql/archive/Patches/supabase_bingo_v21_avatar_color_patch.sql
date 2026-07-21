-- =========================================================
-- Lerke Bingo — v21: Avatar paid color changes
-- RPC: purchase_avatar_color(p_color_slot, p_color)
-- Cost: 25 XP per color change.
-- Supported slot: 'skinColor' (base face shape color).
-- Updates avatar_data jsonb in-place (field merge).
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
  v_current_xp  int;
  v_cost        int := 25;
  v_new_avatar  jsonb;
begin
  if p_color_slot not in ('skinColor') then
    return jsonb_build_object('ok', false, 'error', 'Ugyldig fargeslott');
  end if;

  if p_color !~ '^#[0-9a-fA-F]{6}$' then
    return jsonb_build_object('ok', false, 'error', 'Ugyldig fargeformat');
  end if;

  select sal.student_id into v_student_id
  from public.student_auth_links sal
  where sal.auth_user_id = auth.uid()
  limit 1;

  if v_student_id is null then
    return jsonb_build_object('ok', false, 'error', 'Ikke innlogget');
  end if;

  select total_xp into v_current_xp
  from public.student_profiles
  where id = v_student_id;

  if v_current_xp < v_cost then
    return jsonb_build_object(
      'ok', false,
      'error', 'Ikke nok XP',
      'total_xp', v_current_xp,
      'needed', v_cost
    );
  end if;

  update public.student_profiles
  set total_xp   = total_xp - v_cost,
      avatar_data = coalesce(avatar_data, '{}'::jsonb)
                    || jsonb_build_object(p_color_slot, p_color)
  where id = v_student_id
  returning total_xp, avatar_data into v_current_xp, v_new_avatar;

  return jsonb_build_object(
    'ok',          true,
    'total_xp',    v_current_xp,
    'avatar_data', v_new_avatar,
    'xp_spent',    v_cost
  );
end;
$$;

grant execute on function public.purchase_avatar_color(text, text) to authenticated, anon;
