-- ============================================================
-- Lerke Bingo v18 — Cloud-saved teaching word lists
-- Allows teachers to save/load word lists across sessions and devices.
-- ============================================================

-- Table: teacher_word_lists
create table if not exists teacher_word_lists (
  id          uuid        primary key default gen_random_uuid(),
  teacher_id  uuid        references auth.users(id) on delete cascade not null,
  name        text        not null,
  words       jsonb       not null,
  game_mode   text        not null default 'glose',
  times_used  integer     not null default 0,
  last_used_at timestamptz,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  unique(teacher_id, name)
);

alter table teacher_word_lists enable row level security;

drop policy if exists "teacher_word_lists_own" on teacher_word_lists;
create policy "teacher_word_lists_own" on teacher_word_lists
  for all
  using  (auth.uid() = teacher_id)
  with check (auth.uid() = teacher_id);

-- RPC: upsert a word list
create or replace function save_teacher_word_list(
  p_name      text,
  p_words     jsonb,
  p_game_mode text default 'glose'
)
returns jsonb
language plpgsql security definer
as $$
begin
  insert into teacher_word_lists (teacher_id, name, words, game_mode, updated_at)
  values (auth.uid(), p_name, p_words, p_game_mode, now())
  on conflict (teacher_id, name) do update
    set words      = excluded.words,
        game_mode  = excluded.game_mode,
        updated_at = now();
  return jsonb_build_object('ok', true);
end;
$$;

-- RPC: get all word lists for the current teacher
create or replace function get_teacher_word_lists()
returns table(
  name         text,
  words        jsonb,
  game_mode    text,
  times_used   integer,
  last_used_at timestamptz,
  updated_at   timestamptz
)
language plpgsql security definer
as $$
begin
  return query
  select
    wl.name,
    wl.words,
    wl.game_mode,
    wl.times_used,
    wl.last_used_at,
    wl.updated_at
  from teacher_word_lists wl
  where wl.teacher_id = auth.uid()
  order by wl.last_used_at desc nulls last, wl.updated_at desc;
end;
$$;

-- RPC: delete a word list by name
create or replace function delete_teacher_word_list(p_name text)
returns jsonb
language plpgsql security definer
as $$
begin
  delete from teacher_word_lists
  where teacher_id = auth.uid() and name = p_name;
  return jsonb_build_object('ok', true);
end;
$$;

-- RPC: mark a list as used (increment counter + set last_used_at)
create or replace function mark_teacher_word_list_used(p_name text)
returns void
language plpgsql security definer
as $$
begin
  update teacher_word_lists
  set times_used   = times_used + 1,
      last_used_at = now()
  where teacher_id = auth.uid() and name = p_name;
end;
$$;
