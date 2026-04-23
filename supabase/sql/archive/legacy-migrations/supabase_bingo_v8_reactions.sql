-- V8: Student draw reactions
-- One emoji reaction per student per draw (upsert).
-- Teacher sees reactions for the current draw in real-time via get_draw_reactions().

-- ── Table ──────────────────────────────────────────────────────────────────────
create table if not exists public.draw_reactions (
  id               uuid        primary key default gen_random_uuid(),
  session_id       uuid        not null references public.sessions(id) on delete cascade,
  round_number     int         not null default 1,
  draw_index       int         not null,
  participant_id   uuid        not null references public.session_participants(id) on delete cascade,
  emoji            text        not null check (emoji in ('🎉','😬','😤')),
  reacted_at       timestamptz not null default now(),
  unique (session_id, round_number, draw_index, participant_id)
);

alter table public.draw_reactions enable row level security;

-- Students can insert/update their own reactions
create policy "participants_upsert_own_reaction"
  on public.draw_reactions
  for all
  to authenticated
  using  (public.is_participant_owner(participant_id))
  with check (public.is_participant_owner(participant_id));

-- Teacher can read all reactions for sessions they own
create policy "teacher_read_reactions"
  on public.draw_reactions
  for select
  to authenticated
  using (public.is_session_teacher(session_id));

-- ── send_bingo_reaction ────────────────────────────────────────────────────────
create or replace function public.send_bingo_reaction(
  p_session_id   uuid,
  p_draw_index   int,
  p_round_number int,
  p_emoji        text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_participant_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;
  if p_emoji not in ('🎉','😬','😤') then
    raise exception 'Invalid emoji';
  end if;

  select id into v_participant_id
  from public.session_participants
  where session_id = p_session_id
    and user_id = auth.uid()
  limit 1;

  if v_participant_id is null then
    raise exception 'Not a participant of this session';
  end if;

  insert into public.draw_reactions(session_id, round_number, draw_index, participant_id, emoji)
  values (p_session_id, p_round_number, p_draw_index, v_participant_id, p_emoji)
  on conflict (session_id, round_number, draw_index, participant_id)
  do update set emoji = excluded.emoji, reacted_at = now();
end;
$$;

revoke all on function public.send_bingo_reaction(uuid, int, int, text) from public;
grant execute on function public.send_bingo_reaction(uuid, int, int, text) to authenticated;

-- ── get_draw_reactions ─────────────────────────────────────────────────────────
-- Returns [{name, emoji}] ordered by reacted_at for the current draw.
create or replace function public.get_draw_reactions(
  p_session_id   uuid,
  p_round_number int,
  p_draw_index   int
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_result jsonb;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;
  if not public.is_session_teacher(p_session_id) then
    raise exception 'Teacher access required';
  end if;

  select coalesce(
    jsonb_agg(
      jsonb_build_object('name', sp.display_name, 'emoji', dr.emoji)
      order by dr.reacted_at
    ),
    '[]'::jsonb
  )
  into v_result
  from public.draw_reactions dr
  join public.session_participants sp on sp.id = dr.participant_id
  where dr.session_id   = p_session_id
    and dr.round_number = p_round_number
    and dr.draw_index   = p_draw_index;

  return coalesce(v_result, '[]'::jsonb);
end;
$$;

revoke all on function public.get_draw_reactions(uuid, int, int) from public;
grant execute on function public.get_draw_reactions(uuid, int, int) to authenticated;
