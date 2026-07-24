-- Lerke Bingo — v21: avatar skin color purchase
-- Adds purchase_avatar_color(p_color_slot, p_color) RPC.
-- Validates slot ('skin') and hex color (#rrggbb), deducts 25 XP,
-- merges skinColor into avatar_data JSONB.
-- Returns {ok, total_xp, avatar_data, xp_spent} or {ok:false, error}.

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
  v_cost       int := 25;
  v_student_id uuid;
  v_current_xp int;
  v_avatar     jsonb;
begin
  if p_color_slot not in ('skin') then
    return jsonb_build_object('ok', false, 'error', 'Ugyldig fargesport');
  end if;

  if p_color !~ '^#[0-9a-fA-F]{6}$' then
    return jsonb_build_object('ok', false, 'error', 'Ugyldig hex-farge');
  end if;

  select sal.student_id into v_student_id
  from public.student_auth_links sal
  where sal.auth_user_id = auth.uid()
  limit 1;

  if v_student_id is null then
    return jsonb_build_object('ok', false, 'error', 'Ikke innlogget');
  end if;

  select total_xp, coalesce(avatar_data, '{}')
  into v_current_xp, v_avatar
  from public.student_profiles
  where id = v_student_id;

  if v_current_xp < v_cost then
    return jsonb_build_object('ok', false, 'error', 'Ikke nok XP', 'total_xp', v_current_xp, 'needed', v_cost);
  end if;

  update public.student_profiles
  set total_xp    = total_xp - v_cost,
      avatar_data = jsonb_set(
                      coalesce(avatar_data, '{}'),
                      array['skinColor'],
                      to_jsonb(p_color)
                    )
  where id = v_student_id
  returning total_xp, avatar_data into v_current_xp, v_avatar;

  return jsonb_build_object(
    'ok',          true,
    'total_xp',    v_current_xp,
    'avatar_data', v_avatar,
    'xp_spent',    v_cost
  );
end;
$$;

grant execute on function public.purchase_avatar_color(text, text) to authenticated, anon;
