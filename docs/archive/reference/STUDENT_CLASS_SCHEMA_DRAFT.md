# Lerio Class And Student Schema Draft

## Purpose

This note turns the student account idea into a concrete first backend draft.

It is not the final implementation plan. The goal is to define a stable direction before building teacher-managed classes, student logins, and progress-linked activity data.

---

## Recommended First Scope

The first persistent learner model should include:

- teacher-owned classes
- teacher-managed student records
- simple student login credentials
- optional connection between a live session participant and a persistent student

This keeps the current anonymous Bingo flow intact while opening a path toward stable identity and progress data.

---

## Core Tables

### `classes`

Represents a teacher-owned classroom group.

Suggested fields:

- `id`
- `teacher_user_id`
- `name`
- `grade_label`
- `school_year`
- `class_code`
- `status`
- `created_at`
- `updated_at`

Notes:

- `teacher_user_id` should point to the approved teacher account
- `class_code` can later be used for simple student entry
- `status` should support at least `active` and `archived`

---

### `student_profiles`

Represents a persistent learner identity.

Suggested fields:

- `id`
- `class_id`
- `display_name`
- `first_name`
- `last_name`
- `student_code`
- `status`
- `created_at`
- `updated_at`

Notes:

- `display_name` is the classroom-facing name
- `student_code` should be printable and easy to read
- `status` should support at least `active` and `inactive`

---

### `student_credentials`

Stores login material for lightweight student auth.

Suggested fields:

- `student_id`
- `pin_hash`
- `must_reset_pin`
- `created_at`
- `updated_at`

Notes:

- store only hashes, never plaintext
- this first model should use PIN only

---

### `student_sessions` or `student_auth_links`

Optional mapping from technical auth identity to persistent student profile.

Suggested fields:

- `id`
- `student_id`
- `auth_user_id`
- `created_at`
- `last_used_at`

Notes:

- useful if Lerio uses Supabase Auth also for students
- keeps technical auth separate from learner identity

---

## Chosen First Login Model

The chosen first model is:

- teacher creates class
- teacher creates student records
- system generates:
  - `class_code`
  - `student_code`
  - short PIN
- teacher can print or view credentials
- student logs in with:
  - class code
  - student code
  - PIN

Why this model:

- low friction
- no email requirement
- strong enough for persistent identity
- works well in classrooms with younger learners

---

## Relationship To Current Bingo Model

Current live Bingo should not be blocked by this work.

Recommended coexistence:

- anonymous guest join remains available
- persistent student login becomes an optional stronger mode

That means a future Bingo session could support:

- `join_mode = guest`
- `join_mode = class_student`
- `join_mode = either`

---

## Session Participation Upgrade Path

Current `session_participants` is session-scoped only.

A likely next step is to add:

- `student_profile_id uuid references public.student_profiles(id)`

This field should stay nullable.

That allows:

- anonymous participants for guest mode
- linked participants for persistent student mode

This is a key compatibility bridge.

---

## Teacher Workflow

Expected teacher workflow:

1. Teacher creates a class
2. Teacher adds students manually or from a bulk list
3. Lerio generates student codes / PINs
4. Teacher views or prints credentials
5. Students log in with lightweight credentials
6. Activities can optionally store progress against `student_profiles`

---

## Student Workflow

Expected student workflow:

1. Student opens Lerio
2. Student chooses student login
3. Student enters:
   - class code
   - student code
   - PIN
4. Student becomes linked to a stable learner identity
5. Activity sessions and progress can now be tied to that learner

Technical first-pass interpretation:

1. client gets a technical auth session
2. client calls a login RPC with:
   - `class_code`
   - `student_code`
   - `pin`
3. backend links the current `auth.uid()` to the matching `student_profiles` row
4. client can later restore learner context from that auth link

---

## Security Notes

- teacher should only manage classes they own
- teacher should only see students in their own classes
- student credentials must be hashed
- student lookups must not expose entire school-wide student lists
- class code alone should not grant full access
- class code should be combined with student-specific credentials

---

## Suggested SQL Direction

First implementation pass should likely create:

- `classes`
- `student_profiles`
- `student_credentials`
- helper functions for teacher-side management

Examples:

- `create_class(...)`
- `create_student_profile(...)`
- `reset_student_pin(...)`
- `list_class_students(...)`
- `is_class_teacher(...)`
- `student_login_with_pin(...)`
- `get_current_student_profile()`

Student login itself can be designed in a second pass once the data model is stable, but the schema should already assume:

- class code + student code + PIN
- anonymous guest join remains supported separately

---

## Recommended Next Implementation Order

1. Draft SQL schema
2. Add teacher-side class/student management RPCs
4. Build simple teacher UI for classes and student lists
5. Add student login UI
6. Link session participation to `student_profile_id`
7. Only then start attaching progress data

---

## Current Recommendation

Do not build progress-heavy student features on top of anonymous-only identity.

Build the class/student data model first, then attach future progress to persistent student identities.
