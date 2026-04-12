# Lerio Student Account Model

## Purpose

This note describes the chosen next-step identity model for Lerio if the project moves beyond session-only live play and starts needing stable learner identity, progression data, and teacher-managed class structure.

The current anonymous Bingo join model is acceptable for fast classroom live sessions, but it is not strong enough as the long-term identity layer for persistent learner progress.

---

## Why This Is Needed

The current student model is:

- anonymous Supabase auth
- browser-local `client_token`
- session-scoped nickname

This works well for:

- quick live join
- low-friction classroom entry
- QR or code-based Bingo sessions

This is weak for:

- progress across days or weeks
- same student on a different device
- student history/statistics
- long-term classroom reports
- stable student identity independent of browser storage

---

## Chosen Direction

Use a teacher-managed lightweight student account model.

This is similar to many classroom tools:

- teacher has a real account
- teacher creates or manages a class
- teacher creates student identities
- each student gets a simple student code and PIN
- teacher can see or print these credentials
- students sign in with a lightweight login

This avoids requiring personal email accounts for younger students while still giving the system a stable learner identity.

---

## Identity Ladder

Lerio should likely support three identity levels over time:

### 1. Anonymous Session Identity

Use for:

- quick live join
- low-friction one-off classroom play
- Bingo V1 style sessions

Characteristics:

- anonymous auth
- local client token
- session-scoped nickname
- no strong assumption of long-term persistence

### 2. Lightweight Student Identity

Use for:

- classroom progression
- teacher-managed student access
- cross-session statistics
- stable recognition of the same learner

Characteristics:

- teacher-created student records
- simple student login
- no email requirement
- can work with codes, usernames, PINs, or printable credentials

### 3. Full Student Account Identity

Use only if later needed.

Characteristics:

- stronger self-managed student accounts
- potentially email-based auth
- more account management complexity

This should not be the default assumption for the next step.

---

## Proposed Lerio Structure

Likely future model:

- `teacher_profiles`
- `classes`
- `class_memberships`
- `student_profiles`
- `student_credentials` or equivalent login model

Conceptually:

- one teacher can manage one or more classes
- one class contains many students
- one student has a stable Lerio identity
- sessions and results can reference the student identity when needed

---

## Suggested Student Login Models

There are several viable simple login patterns in general, but Lerio should choose one concrete first model.

### Chosen First Model: Class Code + Student Code + PIN

Examples:

- class code: `7A24K`
- student code: `RAVN-42`
- pin: `1837`

Pros:

- simpler than normal passwords
- good for younger students
- easy to print and hand out

Cons:

- still needs a class login flow and reset tools
- class code keeps the login classroom-specific

---

## Recommended Next Practical Model

For Lerio, the chosen next-step model is:

- teacher creates class
- teacher creates student accounts
- each student gets:
  - display name
  - student code
  - short PIN
- teacher can view or print credentials

This gives:

- stable student identity
- simple classroom login
- progression-ready backend

without forcing email-based student accounts.

---

## How This Should Coexist With Anonymous Bingo

Do not delete the anonymous join model immediately.

Instead support both:

- `Guest / live mode`
- `Student account mode`

This allows:

- fast ad hoc play when needed
- stable logged-in learner identity when progression matters

For example:

- Bingo V1 live sessions can continue using anonymous guest join
- future progression-based tools can require student login
- later Bingo modes could optionally attach results to student accounts

---

## Data Ownership Principle

Important separation:

- auth identity is technical login identity
- student profile is learner identity
- session participant is session presence identity

Those should not be collapsed into one thing.

That means Lerio should keep separate concepts for:

- who is logged in
- which learner this is
- which session presence record is active right now

---

## Short-Term Recommendation

Keep current Bingo V1 as:

- teacher account
- student anonymous join
- session-scoped nickname

But plan the next backend design around:

- teacher-managed classes
- teacher-managed student accounts
- simple student login credentials
- stable learner-linked progress records

---

## Concrete Design Consequence

The first student account schema should be built around:

- `classes`
- `student_profiles`
- `student_credentials` with PIN hashing
- teacher-side RPCs for:
  - creating classes
  - adding students
  - listing class students
  - resetting student PINs

Anonymous session join must remain supported in parallel.

---

## Suggested Next Design Work

If this becomes the next major feature, the next step should be a schema/design draft for:

- classes
- student profiles
- student credentials / login
- teacher class management
- how live session participation can optionally connect to student accounts

That design should be done before implementing more progress-heavy student features.
