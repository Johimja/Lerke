# Supabase Bingo V1 Draft

## Goal

Translate the Lerke network plan into a concrete Supabase-oriented V1 design for Bingo.

This draft is intentionally narrow:

- live session creation
- student join
- teacher-controlled live draw sync
- round switching
- draw history

This draft does not try to solve all future Lerke activities yet.

---

## V1 Scope

The first backend-powered Bingo version should support:

- teacher creates a live bingo session
- session gets a strong internal ID and a short join code
- students join the session using QR or join code
- teacher advances draws
- all students receive current draw in realtime
- draw history is persisted

Not in scope for this draft:

- student accounts
- class roster management
- saved teacher libraries in backend
- student board sync
- advanced analytics

---

## Recommended Auth Model For V1

### Teacher

Use authenticated teacher accounts.

Recommended approach:

- Supabase Auth
- email + password
- password reset by email

Reason:

- teacher ownership should be tied to a real authenticated user
- teacher actions become much easier to secure with RLS

Recommended teacher approval model:

- user creates account normally
- account does not automatically become teacher
- teacher status is granted by:
  - invite key flow, or
  - admin/manual approval

Preferred V1 direction:

- email + password
- reset password support
- invite key or admin approval for teacher access

### Student

Do not require login in V1.

Use:

- anonymous join by QR and/or join code
- generated nickname only
- optional anonymous participant row

Reason:

- lower classroom friction
- less personal data
- easier rollout
- avoids vulgar or disruptive self-chosen names

---

## Minimum Tables

### 1. `activities`

Purpose:

- identify activity type

Suggested fields:

```sql
id uuid primary key default gen_random_uuid()
slug text unique not null
name text not null
created_at timestamptz not null default now()
```

V1 rows:

- `bingo`

This table is optional in a very narrow prototype, but useful if Lerke is meant to grow.

---

### 2. `sessions`

Purpose:

- main live classroom session

Suggested fields:

```sql
id uuid primary key default gen_random_uuid()
activity_slug text not null default 'bingo'
created_by uuid not null references auth.users(id)
join_code text not null unique
title text
status text not null default 'draft'
expires_at timestamptz
settings jsonb not null default '{}'::jsonb
created_at timestamptz not null default now()
updated_at timestamptz not null default now()
```

Suggested `status` values:

- `draft`
- `live`
- `ended`
- `expired`

Recommended expiry policy for V1:

- default expiry window: 12 hours from session creation
- teacher can end session manually earlier
- expired sessions become read-only or unavailable to new joins
- sessions should not stay joinable indefinitely

Suggested `settings` content for Bingo:

- game mode (`glose` / `matte`)
- glose direction
- table list
- round count
- session name

---

### 3. `session_rounds`

Purpose:

- store pre-generated draw sequences

Suggested fields:

```sql
id uuid primary key default gen_random_uuid()
session_id uuid not null references sessions(id) on delete cascade
round_number integer not null
draw_sequence jsonb not null
created_at timestamptz not null default now()
unique(session_id, round_number)
```

`draw_sequence` example:

```json
[
  { "prompt": "Where", "answer": "Hvor" },
  { "prompt": "Ordinary", "answer": "Vanlig" }
]
```

For matte:

```json
[
  { "prompt": "3 × 7", "answer": "= 21" },
  { "prompt": "18", "answer": "← 3 × 6" }
]
```

---

### 4. `session_state`

Purpose:

- current live state that teacher and students subscribe to

Suggested fields:

```sql
session_id uuid primary key references sessions(id) on delete cascade
phase text not null default 'setup'
round_number integer not null default 1
draw_index integer not null default 0
current_draw jsonb
updated_by uuid references auth.users(id)
updated_at timestamptz not null default now()
```

Suggested `phase` values:

- `setup`
- `live_draw`
- `round_complete`
- `ended`

`current_draw` example:

```json
{ "prompt": "Where", "answer": "Hvor" }
```

This table is the key realtime subscription target in V1.

---

### 5. `session_events`

Purpose:

- append-only event history

Suggested fields:

```sql
id bigint generated always as identity primary key
session_id uuid not null references sessions(id) on delete cascade
event_type text not null
actor_user_id uuid references auth.users(id)
payload jsonb not null default '{}'::jsonb
created_at timestamptz not null default now()
```

Suggested `event_type` values:

- `session_created`
- `session_started`
- `round_started`
- `draw_advanced`
- `round_reset`
- `round_completed`
- `session_ended`

This table is useful for:

- teacher history
- student history view
- debugging
- reconstructing what happened

---

### 6. `session_participants`

Purpose:

- track joined devices/users lightly

Suggested fields:

```sql
id uuid primary key default gen_random_uuid()
session_id uuid not null references sessions(id) on delete cascade
display_name text
role text not null default 'student'
client_token text not null unique
joined_at timestamptz not null default now()
last_seen_at timestamptz not null default now()
status text not null default 'active'
```

Suggested `role` values for V1:

- `student`
- `observer`

Teacher should not rely on this table for authority.
Teacher authority should come from `sessions.created_by`.

V1 nickname policy:

- assign generated nickname automatically on join
- no manual text entry
- allow up to 3 rerolls before join is finalized
- store final chosen generated nickname in `display_name`

---

## Minimum RLS Strategy

This is the important part.

---

### `sessions`

Teacher can:

- insert sessions where `created_by = auth.uid()`
- select their own sessions
- update their own sessions

Students should not read arbitrary sessions directly by broad query.

Safer approach:

- student uses a join flow through a server function or edge function
- function resolves join code to allowed session

---

### `session_rounds`

Teacher can:

- insert and update rows for sessions they own
- read rows for sessions they own

Students:

- may read rounds only for joined session if you want full client-side access
- but safer V1 approach is to let students read only `session_state` and `session_events`

Recommendation:

- do not expose full round sequences to students if not needed

That reduces cheating and overexposure.

---

### `session_state`

Teacher can:

- update state for sessions they own

Students can:

- read state for joined session

Students must not:

- update `session_state`

This is the most important rule.

---

### `session_events`

Teacher can:

- insert control events for sessions they own
- read events for sessions they own

Students can:

- read events for joined session

Students should not:

- insert global control events

---

### `session_participants`

Students can:

- insert a participant row for themselves with a generated `client_token`
- update only their own participant row via that token

Teacher can:

- read participant rows for own sessions

Recommendation:

- if using anonymous students, access to their participant row should go through a generated client token, not teacher credentials and not a fake role field

---

## Recommended Join Flow

V1 should not let the browser directly query by join code and then self-assign permissions.

Recommended flow:

1. Teacher creates session.
2. Teacher receives:
   - public `join_code`
   - session QR link
3. Student opens join link or enters join code.
4. A server-side function verifies that the session exists and is joinable.
5. The function returns:
   - session id
   - limited readable state
   - student client token or participant token
6. Student subscribes to allowed realtime channels for that session.

This flow is safer than trusting public client logic alone.

---

## Recommended Realtime Subscriptions

For students:

- subscribe to `session_state` for one session
- optionally subscribe to `session_events` for one session

For teacher:

- subscribe to `session_state`
- subscribe to `session_events`
- optionally subscribe to `session_participants`

For V1, `session_state` is the key shared object.

---

## Suggested SQL Structure

This is not final migration SQL, but close to implementation shape.

```sql
create table sessions (
  id uuid primary key default gen_random_uuid(),
  activity_slug text not null default 'bingo',
  created_by uuid not null references auth.users(id),
  join_code text not null unique,
  title text,
  status text not null default 'draft',
  expires_at timestamptz,
  settings jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table session_rounds (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references sessions(id) on delete cascade,
  round_number integer not null,
  draw_sequence jsonb not null,
  created_at timestamptz not null default now(),
  unique (session_id, round_number)
);

create table session_state (
  session_id uuid primary key references sessions(id) on delete cascade,
  phase text not null default 'setup',
  round_number integer not null default 1,
  draw_index integer not null default 0,
  current_draw jsonb,
  updated_by uuid references auth.users(id),
  updated_at timestamptz not null default now()
);

create table session_events (
  id bigint generated always as identity primary key,
  session_id uuid not null references sessions(id) on delete cascade,
  event_type text not null,
  actor_user_id uuid references auth.users(id),
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table session_participants (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references sessions(id) on delete cascade,
  display_name text,
  role text not null default 'student',
  client_token text not null unique,
  joined_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  status text not null default 'active'
);
```

---

## Suggested Edge Functions

Recommended small server-side functions:

### `create_bingo_session`

Input:

- title
- settings
- round data

Does:

- creates session
- generates join code
- writes session rounds
- initializes session state
- writes first event

### `join_bingo_session`

Input:

- join code
- optional reroll request count / generated nickname choice

Does:

- validates session status and expiry
- creates participant row with generated nickname
- returns limited session context

### `advance_bingo_draw`

Input:

- session id

Does:

- verifies teacher ownership
- reads current round sequence
- advances draw index
- updates session state
- writes event

### `set_bingo_round`

Input:

- session id
- round number

Does:

- verifies teacher ownership
- resets draw index/current draw
- updates session state
- writes event

---

## Frontend Mapping

### `bingo-laerer.html`

Will eventually need to:

- authenticate teacher
- create session in Supabase
- publish round data
- subscribe to `session_state`
- call `advance_bingo_draw`
- call `set_bingo_round`

Current repo status:

- initial teacher sign-in scaffolding is now added in the HTML
- generate flow now attempts to create a session, rounds, state, and first event
- QR builder now includes session metadata when a live session exists

### `bingo-elev.html`

Will eventually need to:

- join session by code/link
- receive a participant token
- subscribe to `session_state`
- render current live draw

Current repo status:

- initial anonymous sign-in scaffolding is now added in the HTML
- join flow now calls `join_bingo_session(...)`
- heartbeat now calls `touch_participant(...)`

Important:

- the student board can remain local in V1
- only the live draw needs to be shared first

---

## V1 Build Order

1. Create teacher auth.
2. Create the four main tables:
   - `sessions`
   - `session_rounds`
   - `session_state`
   - `session_events`
3. Add `session_participants`.
4. Implement join flow.
5. Implement teacher live draw controls through backend functions.
6. Connect realtime updates to teacher and student UIs.

---

## Open Decisions

These still need to be decided before implementation:

1. Teacher login method:
   - email/password
   - reset password by email
   - Google sign-in later optional

2. Student join method:
   - QR + short code

3. Session expiry:
   - fixed expiry window

Recommended V1 choice:

- 12-hour expiry from creation
- manual end still allowed

4. Whether students should see full history or only current draw in V1

5. Exact nickname generator format:
   - adjective + animal
   - adjective + object

Recommended V1 choice:

- adjective + animal or object

Examples:

- Rask Rev
- Stille Ugle
- Modig Lykt
- Klar Blyant

---

## Recommendation Summary

Best practical V1 direction:

- authenticated teachers
- teacher approval via invite key or admin flag
- anonymous students
- QR + code student join
- session-based live draw sync
- teacher-only control updates
- student board remains local at first

This is the smallest useful backend version of Lerke Bingo.
