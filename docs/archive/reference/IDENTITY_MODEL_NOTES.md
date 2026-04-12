# Lerio Identity Model Notes

## Goal

Describe how Lerio should think about identity over time without breaking privacy boundaries or coupling session behavior too tightly to permanent user identity.

This note is forward-looking.

It does not replace the current Bingo V1 model.

---

## Key Principle

Session identity and long-term identity must not be the same thing.

That means:

- a student can have one temporary nickname in one session
- a different nickname in another session
- and still later have persistent progress in Lerio if that feature is introduced

This separation is important for:

- privacy
- flexibility
- future progress tracking
- avoiding over-linking classroom activity data to raw account identity

---

## Important V1 Rule

For Bingo V1:

- `display_name`
- `reroll_count`
- `client_token`
- presence/status fields

must belong to the session participant layer, not to `auth.users`.

In other words:

- nickname is session-scoped
- reroll count is session-scoped
- participant presence is session-scoped

This is the correct behavior because a student should be able to be:

- `Sprellende Stein` in one bingo session
- `Lille Loff` in another

without those names becoming their permanent identity.

---

## What Should NOT Live On `auth.users`

These should not be stored as stable account identity fields:

- current session nickname
- reroll count
- room-specific nickname history
- session presence
- session-specific role in a classroom activity

Reason:

- those values belong to a single room/session context
- they should not persist as global identity attributes
- storing them on the auth profile would create the wrong coupling

---

## Recommended Identity Layers

Lerio should eventually think in three layers.

### 1. Auth Identity

This is the technical account identity.

Examples:

- teacher user account in Supabase Auth
- possible future student account
- anonymous auth identity

Purpose:

- authentication
- security
- access control

This layer should stay minimal.

---

### 2. Lerio Identity

This is the long-term internal identity used for progress or participation across sessions if Lerio later grows into that.

Purpose:

- longitudinal progress
- activity summaries
- linking different sessions safely

This should ideally be:

- pseudonymous
- not directly exposed everywhere
- separate from raw auth metadata when possible

---

### 3. Session Identity

This is the identity used inside one specific live room/session.

Examples:

- generated nickname
- reroll count
- active/inactive state
- participant role in that room

This is where Bingo V1 currently lives.

---

## Current Bingo V1 Interpretation

For the current Supabase Bingo draft:

- `auth.users` gives the authenticated identity
- `session_participants` gives the per-session identity

That means:

- one auth user may appear in multiple sessions
- each session row may have a different nickname
- each session row may have its own reroll count
- presence is independent per session

This is good and should be preserved.

---

## Why This Matters For Future Progress

Later, if Lerio adds progress tracking, the system can evolve like this:

- session nickname remains temporary
- progress links to a more stable internal learner identity
- classroom session data stays separate from long-term learner profile data

That allows:

- flexible nicknames per session
- persistent progress over time
- less direct leakage of identity into raw activity tables

---

## Example Model

### Session layer

`session_participants`

- `id`
- `session_id`
- `auth_user_id`
- `display_name`
- `reroll_count`
- `status`
- `last_seen_at`

This is correct for Bingo V1.

### Future persistent layer

Possible future table:

`learner_profiles`

- `id`
- `auth_user_id` or controlled mapping reference
- `public_alias`
- `created_at`

Possible future progress table:

`learner_progress`

- `learner_id`
- `activity_slug`
- `metric_type`
- `metric_value`
- `updated_at`

This keeps progress separate from session nicknames.

---

## Practical Rule Going Forward

Whenever Lerio adds a new feature, ask:

"Is this value temporary for one room, or stable across time?"

If temporary:

- store it on the session layer

If stable:

- consider a separate internal profile/progress layer

Do not put session behavior onto global auth identity unless there is a very strong reason.

---

## Recommendation Summary

For Bingo V1 and beyond:

- keep nickname and reroll data in `session_participants`
- do not store session nickname on `auth.users`
- allow nickname to change per room/session
- reserve long-term identity for a later, more deliberate learner model

This keeps Lerio flexible, safer, and easier to expand later.

