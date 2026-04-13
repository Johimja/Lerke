# Lerke — Shared Session Notes

## How to use this file

This is the **living collaborative log** for the Lerke project — shared between Atle (Johimja) and Claude.

- **Read this at the start of every session** (after `docs/recentmemory.txt`)
- **Add a session entry** when starting or ending a work session
- **Check off roadmap items** as they're completed
- **Log decisions** here so neither of us forgets why we chose something
- This file is version-controlled — it's always in sync with the code

Reading order for a cold start:
1. `docs/recentmemory.txt` — quick project orientation
2. **This file** — decisions, session history, roadmap
3. `README.md` — full project docs

---

## Project Identity

**Lerke** is a classroom game portal built for Steinerskolen i Kristiansand, Norway.
Built by Atle Stray (Johimja) with Claude (Anthropic), hosted on GitHub Pages at `johimja.com/Lerke`.
Plain HTML/CSS/JS frontend, Supabase backend (auth + realtime + PostgreSQL).

Current live tool: **Lerke Bingo** (teacher-led live bingo with student join).
Next tool planned: **Lerke Quiz** (after Bingo is stable).

---

## Current Deploy State

| Item | State |
|---|---|
| Live URL | `johimja.com/Lerke` |
| Old URLs | `johimja.com/lerio`, `johimja.com/bingo` — **offline** |
| Supabase DB | V1 + student accounts + V2 strict live patches applied |
| V3 join stability patch | **NOT YET APPLIED** — highest DB priority |
| Lerke SVG branding | Done (`lerke_logo.svg`, `lerke_bingo_banner.svg`) |
| Remaining lerio references | CSS vars in `index.html`, `media/leriobingo.jpg`, internal only |

---

## Session Log

### 2026-04-13 — Session 2: Live draw diagnosis + frontend fixes

**What we found (full diagnosis):**

#### Root Cause 1: V3 patch NOT applied — CRITICAL, breaks returning students
- The live DB still has the global constraint `session_participants_client_token_key` (unique client_token across ALL sessions)
- V1's `join_bingo_session` does a plain `INSERT` — no `ON CONFLICT`
- A student who joined session A with `client_token = "abc"` → tries to join session B (new day, new code) → `INSERT` fails with unique constraint violation
- `isRetryableJoinError` in `student.html` doesn't catch constraint violations (only timeouts/network), so it breaks early
- Recovery via `touchParticipant()` also fails (no participant for the new session yet)
- First-time students are fine; returning students fail to join
- **Fix: Apply `supabase/sql/supabase_bingo_v3_join_stability_patch.sql` in Supabase dashboard — Atle must do this**

#### Root Cause 2: No `lock_timeout` in V1 `join_bingo_session` — causes class-wide timeouts
- When 20–30 students all scan QR simultaneously, their INSERT transactions lock each other
- Without the `lock_timeout = '1500ms'` added in V3, Postgres uses its default (no limit)
- Students get "statement timeout" errors → 3 retries all fail → error shown
- **Fix: Same V3 patch fixes this**

#### Root Cause 3: Poll errors silently swallowed — issues invisible to users
- Student: `refreshStrictLiveState().catch(()=>{})` — ALL polling errors drop silently. If `get_bingo_live_state` RPC times out, the student sees no indicator at all.
- Teacher: `refreshTeacherParticipantProgress({silent:true}).catch(()=>{})` — if the participant list query fails, `teacherParticipantProgress` stays stale with no warning shown.
- Teacher polling loop: `refreshTeacherLiveState({silent:true}).catch(()=>{})` — a complete poll failure shows nothing.
- **Fix: Applied frontend changes (see below)**

#### Root Cause 4: `get_bingo_live_state` RPC complexity
- This function joins `sessions + session_state + session_participants + participant_round_boards + participant_draw_responses` in one call
- Polled every 2000ms (student) and 1500ms (teacher) — on free Supabase tier, occasional statement timeouts are expected
- With errors now visible (fix 3), we can at least see when this happens

**What was done this session:**
- `apps/bingo/student.html`: Added `strictLivePollErrorCount` tracker. After 3 consecutive poll failures, shows "Mistet kontakten med liveøkten. Prøver igjen… (error detail)" in the join note. Shows "Kontakten er gjenopprettet." when polling recovers. `touchParticipant` failures now shown immediately.
- `apps/bingo/teacher.html`: Added `teacherPollErrorCount` tracker. After 3 consecutive poll failures, sets sync status with error detail. Participant list query failures now surface in sync status instead of silently dropping.
- `docs/shared_notes.md` + `docs/recentmemory.txt`: Shared notes and roadmap live documents created.

**What Atle must do next (cannot be done in frontend):**
1. **Apply V3 join stability patch in Supabase dashboard** — paste the full content of `supabase/sql/supabase_bingo_v3_join_stability_patch.sql` into the SQL editor and run it
2. **Verify anonymous sign-in is enabled** in Supabase: Auth > Providers > Enable anonymous sign-ins (students use `signInAnonymously()`)

**Next session should start with:**
- Verify V3 patch has been applied
- Test a student join from scratch AND a second join (same browser/device) to confirm the constraint is gone
- Then check if the timeout errors during live draw are reduced

---

### 2026-04-13 — Session 1: Repo migration + planning

**What we discussed:**
- Repo just migrated from Johimja/Lerio → Johimja/Lerke
- Branding rename (Lerio → Lerke) is complete on public-facing surfaces
- SVG files done, in `index.html` at least — other HTML files need verification
- Live Bingo has issues: students say "connected" but don't appear in the live draw; timeout errors during active sessions
- Decided to phase out anonymous/guest join entirely — login required for all students
- Decided next tool after Bingo is stable: Quiz Mode (not Ordkjede)
- Deploy URL confirmed as `johimja.com/Lerke`; old paths offline

**Decisions made:**
1. Anonymous join → phase out. Student account + class/PIN is the only path forward.
2. Next tool = Quiz Mode (after Bingo works end-to-end)
3. Live draw communication bugs are the current blocker — fix before anything else
4. V3 join stability patch needs to be applied to the live Supabase DB

**What was done this session:**
- Created this file (`docs/shared_notes.md`)
- Updated `docs/recentmemory.txt` to reference this file
- Roadmap documented below

**Next session should start with:**
- Read `docs/recentmemory.txt` → this file
- Inspect `apps/bingo/student.html` and `apps/bingo/teacher.html` live draw polling logic
- Diagnose the student-not-appearing / timeout issue

---

## Open Questions

*(Add new questions here as they come up. Strike through or delete when resolved.)*

- None currently open — all major direction decisions made on 2026-04-13.

---

## Roadmap

### Tier 0 — Fix Live Bingo (Current Blocker)

- [x] **Diagnose live draw communication issues** — done (see Session 2 log above)
  - Root causes found: V3 patch not applied, lock_timeout missing, silent poll errors
- [ ] **Apply V3 join stability patch** to the live Supabase DB — **ATLE ACTION REQUIRED**
  - File: `supabase/sql/supabase_bingo_v3_join_stability_patch.sql`
  - Paste full content into Supabase SQL editor and run
  - Fixes: global `client_token` constraint → session-scoped, adds 1500ms `lock_timeout`
  - Also verify: Supabase → Auth → Providers → anonymous sign-in is enabled
- [x] **Frontend: surface poll errors** — done (`student.html` + `teacher.html`)
  - Students now see "Mistet kontakten" after 3 consecutive poll failures
  - Teacher sync status now shows participant list failures instead of silent drop
- [ ] **Verify Lerke branding in all HTML files**
  - `lerke_logo.svg` and `lerke_bingo_banner.svg` confirmed in `index.html`
  - Check: `apps/bingo/teacher.html`, `apps/bingo/student.html`, `apps/bingo-generator/index.html`

### Tier 1 — Complete Live Bingo

- [ ] **Phase out anonymous join** — login required for all students
  - Disable/remove guest code path in `apps/bingo/student.html`
  - Student portal login (`index.html`) is the only entry point
  - Update teacher-facing join instructions
- [ ] **Teacher live dashboard improvements** (`apps/bingo/teacher.html`)
  - Show connected students during live play (currently lobby-only)
  - Draw response counts, near-BINGO alerts, round winners
  - Clearer reset / next-round controls

### Tier 2 — Polish

- [ ] **Glosebingo content improvements**
  - Language selector (Norwegian–German, Norwegian–French)
  - Easier reuse/import of saved teaching sets across sessions
- [ ] **Portal UX polish** (`index.html`)
  - Refine teacher/student portal flows
  - Student class management → polished everyday workflow
- [ ] **Full lerio → lerke cleanup** (deploy URL: `johimja.com/Lerke`)
  - CSS variable names: `--lerio-*` → `--lerke-*` in `index.html`
  - Rename `media/leriobingo.jpg` → `media/lerkebingo.jpg`, update all references
  - Replace any `johimja.com/lerio` or `johimja.com/bingo` URL strings with `johimja.com/Lerke`

### Tier 3 — Next Tool

- [ ] **Lerke Quiz Mode**
  - Teacher creates multiple-choice questions; students answer on their devices
  - Add portal tile with rollout state

### Tier 4 — Platform Polish

- [ ] PWA support (installable on phone home screen)
- [ ] Optional leaderboard / round winner tracking
- [ ] Mobile-first polish on teacher live screens

---

## Architecture Quick Reference

| Layer | Detail |
|---|---|
| Frontend | Plain HTML/CSS/JS — no framework |
| Backend | Supabase (PostgreSQL + Auth + RLS + Realtime) |
| Config | `config/supabase-public-config.js` — public anon key only, safe to commit |
| Auth | Teacher: email/password + manual Supabase approval. Student: class code + student code + PIN |
| Live game | Polling via `get_bingo_live_state()` RPC; teacher drives state via `start_bingo_round`, `open_bingo_draw`, `lock_bingo_draw` |
| Deploy | GitHub Pages — `johimja.com/Lerke` |

**SQL patch chain (canonical execution order):**
1. `supabase/sql/supabase_bingo_v1_sql_editor_ready.sql`
2. `supabase/sql/supabase_student_accounts_v1_core_patch.sql`
3. `supabase/sql/supabase_bingo_v2_strict_live_patch.sql`
4. `supabase/sql/supabase_bingo_v3_join_stability_patch.sql` ← not yet applied to live DB
