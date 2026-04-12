# Lerke Bingo Network Plan

## Goal

Define a safe and realistic path from the current no-backend bingo app to a shared live classroom version where teacher and student devices participate in the same session.

This document is for planning, not implementation.

---

## Current State

Lerke Bingo currently runs fully client-side:

- teacher sets up a bingo session in `bingo-laerer.html`
- students open `bingo-elev.html` through QR
- game data is embedded in the URL
- no shared state exists between devices
- no backend, accounts, or persistent live sessions exist yet

This works well for static sessions, but not for:

- synchronized live draws
- teacher-controlled round flow across devices
- student presence
- shared progress or bingo reporting

---

## V1 Product Target

The first networked version should stay narrow:

- teacher starts a live session
- students join the same session via QR or join code
- teacher controls the active draw
- all connected students can see the same current draw
- students do not need accounts
- only teacher can control the session

V1 should not try to solve everything at once.

Out of scope for V1:

- student accounts
- class rosters
- long-term analytics
- complex teacher dashboard
- grading/integration with school systems

---

## Core Roles

### Teacher

Can:

- create session
- start and end rounds
- advance to next draw
- reset round
- view draw history
- optionally see simple student status later

Must be the only role allowed to control session state.

### Student

Can:

- join session
- receive live session state
- receive current draw and round data
- optionally send simple status updates later
- use a generated nickname only

Must not be allowed to:

- change session state
- impersonate teacher
- alter draw history

### Anonymous Visitor

Can:

- open the public landing page
- scan or enter a join code

Should not gain teacher privileges from URL data alone.

---

## Recommended Architecture

Recommended first backend stack:

- frontend: keep current HTML/JS structure initially
- backend/data/auth/realtime: Supabase

Why Supabase:

- PostgreSQL data model
- realtime support
- auth available if teacher login is added
- row-level security helps enforce permissions
- less operational burden than a custom websocket backend

Alternative options:

- Firebase: also viable, especially for realtime-first flow
- Custom Node/WebSocket server: more flexible, but more security and ops burden

Recommendation:

- choose Supabase for V1

---

## Security Model

This is the most important part.

### Principles

- teacher authority must be server-validated
- student role must be constrained server-side
- session identifiers must be unguessable internally
- joining a session must be easy for students but not grant control
- session data should expire automatically
- store minimal personal data

### Recommended Session Model

Each session has:

- internal strong `session_id` (UUID or equivalent)
- human-friendly short `join_code`
- `teacher_secret` or teacher ownership reference
- expiration timestamp
- current state fields

Students join using:

- QR code pointing to public join route
- and/or short join code

Teacher control uses:

- server-side teacher ownership
- or a teacher-only secret/token never exposed to student clients

Recommended V1 choice:

- students can join with QR or short code
- teachers use individual accounts
- teacher role is granted only after approval or invite-based activation
- sessions expire automatically after a short time window unless ended manually

### Hard Rules

- never trust `role=teacher` from the client
- never let students write to session control fields
- never expose teacher secret in QR or student-facing URLs
- never let student devices submit arbitrary session updates

---

## Suggested Data Model

Initial tables or collections:

### `sessions`

Fields:

- `id`
- `join_code`
- `game_type`
- `created_by`
- `status`
- `expires_at`
- `current_round`
- `current_draw_index`
- `current_draw_payload`
- `created_at`

### `session_rounds`

Fields:

- `id`
- `session_id`
- `round_number`
- `draw_sequence`

Stores the pre-generated draw list for each round.

### `session_events`

Fields:

- `id`
- `session_id`
- `event_type`
- `payload`
- `created_at`

Useful for:

- draw history
- debugging
- replaying session state if needed

### `session_participants`

Fields:

- `id`
- `session_id`
- `display_name` or anonymous label
- `role`
- `last_seen_at`
- `status`

V1 can keep this very light, or even delay it until after read-only sync works.

---

## Realtime Flow

### Teacher Flow

1. Teacher creates session from `bingo-laerer.html`
2. Backend stores session and generated round data
3. QR/join code points students to the live session
4. Teacher presses next draw
5. Backend updates current draw
6. Students receive update in realtime

### Student Flow

1. Student scans QR
2. Student joins session in `bingo-elev.html`
3. Student subscribes to session state
4. Current round and draw are shown live
5. Student card remains local, but live draw is shared

This split is good:

- board state can remain local at first
- draw state becomes shared

That makes V1 much easier.

---

## Phased Delivery Plan

### Phase A — Shared Draw Sync

Build only:

- teacher creates session
- student joins session
- teacher-controlled live draw sync
- round switching
- draw history sync

Do not build student reporting yet.

This should be the first backend milestone.

### Phase B — Student Presence

Add:

- connected student count
- simple active/inactive presence
- optional anonymous device labels

Still keep student permissions narrow.

### Phase C — Student Bingo Status

Add:

- student can report "I have bingo"
- teacher can see who has reported bingo

Important:

- this is informational only
- teacher should still verify manually if needed

### Phase D — Teacher Overview

Add:

- near-bingo indicators
- class overview
- progress summaries

Only after the earlier phases are stable.

---

## Privacy and School Safety

Recommended default posture:

- no student accounts in V1
- no full names required
- use generated nicknames instead of free-text names
- avoid storing personal data unless there is a clear need
- expire sessions automatically
- keep logs minimal

If later versions include class/student identity:

- define exactly what is stored
- define retention period
- define who can access it

---

## Risks

### Risk: Students manipulate session state

Mitigation:

- server-side authorization
- strict write permissions
- teacher-only control path

### Risk: Session takeover via shared links

Mitigation:

- separate join code from teacher control credentials
- never put teacher credentials in public URLs

### Risk: Too much complexity too early

Mitigation:

- build shared draw first
- keep local board state local in V1

### Risk: Operational overhead

Mitigation:

- use managed backend platform first

---

## Recommendation Summary

Best next architecture decision:

- build the first networked version on Supabase
- keep students anonymous in V1
- sync only session state and live draws first
- delay full dashboards and class management

Best next implementation goal after planning:

- a teacher-created live session where every student sees the same active draw in realtime

---

## Concrete Next Steps

1. Decide whether Supabase is accepted as backend choice.
2. Define exact teacher auth approach for V1.
3. Decide whether student join is QR-only or QR + short code.
4. Design the session schema in more technical detail.
5. Build a minimal prototype for shared draw sync only.
