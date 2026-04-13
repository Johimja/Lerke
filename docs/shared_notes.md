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
| Supabase DB | V1 + student accounts + V2 strict live + V3 join stability — all applied |
| Session expiry | Fixed: 24h (was 12h) — applied via migration 2026-04-13 |
| Lerke SVG branding | Done (`lerke_logo.svg`, `lerke_bingo_banner.svg`) |
| Remaining lerio references | CSS vars in `index.html`, `media/leriobingo.jpg`, internal only |

---

## Session Log

### 2026-04-13 — Session 3: Session ID staleness bug — root cause found and fixed

**Root cause confirmed (from screenshot):**
- Teacher showed STATUS: Lobby, TRUKKET 0/25 (fresh session)
- Students showed "Runde 1 av 3, Trekket er låst" (old session state)
- Proved teacher and students were on DIFFERENT sessions despite same join code

**Why it happened — `liveSessionId` staleness in `student.html`:**

When a student visits a URL with `?type=glose&join=YH9LV&session=<OLD_UUID>` (e.g. from a bookmark or the QR code from a previous session), the initialization code goes directly to `initSupabaseJoin()` (skips the lookup that would refresh `liveSessionId`) because `currentType` is set. `join_bingo_session` uses the join code to find the CURRENT active session, but `liveSessionId` remained as the OLD UUID from the URL. So all subsequent state polls and heartbeats used the stale old UUID.

**Secondary issue — no ORDER BY in session lookup RPCs:**

Both `get_joinable_bingo_session` and `join_bingo_session` used `LIMIT 1` without `ORDER BY created_at DESC`. If two non-expired sessions have the same join code (possible due to the 24h window), they'd pick one randomly. Fixed to always use newest.

**What was fixed this session:**

- `apps/bingo/student.html`: After `join_bingo_session` succeeds, sync `liveSessionId` from `participantRecord.session_id` and update URL. Students now always poll the session they actually joined.
- `apps/bingo/teacher.html`: Lobby status now shows session UUID prefix `[xxxxxxxx]` and DB participant count from `teacher_summary.participant_count` — lets you spot session ID mismatch instantly.
- `supabase/sql/supabase_bingo_v1_sql_editor_ready.sql`: Added `ORDER BY s.created_at DESC` to `get_joinable_bingo_session`
- `supabase/sql/supabase_bingo_v3_join_stability_patch.sql`: Added `ORDER BY s.created_at DESC` to `join_bingo_session`
- `supabase/sql/supabase_bingo_v4_session_lookup_fix.sql`: **New standalone patch** — apply to live DB if needed
- **DB migration applied directly via Supabase MCP:** `fix_session_lookup_order_newest_first` ✅

**Next session should start with:**
- **Hard-refresh** both teacher and student browsers (clear stale URL caches)
- Teacher creates a fresh session → opens lobby → confirm `[xxxxxxxx]` UUID in lobby status
- Student joins via QR (fresh tab, no cached session param) → should appear in lobby list immediately
- Then test with a bookmarked/old URL — student should still join correctly and lobby should update

---

### 2026-04-13 — Session 6: Student mobile layout — all game info fits on screen

**What was fixed:**
- `apps/bingo/student.html`: In strict live mode, the page now adds `body.strict-live` which hides the title row, account panel, identity panel, session panel, and bingo count wrap via CSS. Padding reduced to 6px so the bingo card fills the screen.
- Card header redesigned: added compact live-right area (`card-name-tag`, `card-round-tag`, `card-score-tag`) that shows inside the dark card header — display name, round (R2/3), and bingo count.
- New `.live-strip` element between card header and grid: shows the current draw word prominently (green background when draw is open, grey when locked, plain when waiting). Replaces the separate subtitle/session panel for state feedback.
- `updateStrictPrompt` now writes to the live-strip instead of the page subtitle.
- `updateStrictSessionPanel` now updates the compact card-header badges in addition to the (hidden) session panel.
- `setStrictControlsDisabled(true)` adds the body class and shows/hides the card-header live elements.

**Resulting layout on phone:**
```
[BINGO]  [Blid Stjerne · R2/3 · 0]   ← compact card header
[Svar nå]  [STRENGTH]                ← live-strip (green = draw open)
[grid cells]
```
Everything fits on one phone screen. No scrolling needed during live play.

---

### 2026-04-13 — Session 5: Student card click feedback + countdown/history UI fixes

**What was fixed this session:**

- `apps/bingo/student.html`: `submitStrictAnswer` now uses `{data,error}` from `submit_bingo_answer` RPC return value. Cell is highlighted immediately on click (optimistic), then `applyMarkedCellsToGrid(data.marked_cells)` sets authoritative state from DB, and outcome ("Riktig!" / "Feil.") is shown instantly without waiting for next poll. On RPC error the optimistic highlight is reverted.
- `apps/bingo/teacher.html`: Removed `hidePromptDuringCountdown` logic — the current draw word is now always visible during the countdown window (previously the large countdown overlay blanked the word; the timer label `${remainingSeconds}s` already shows the seconds so the overlay was redundant). Fixed both strict and non-strict render paths.
- `apps/bingo/teacher.html`: Trekkhistorikk now shows newest draw at top — reversed the history array rendering in both `renderStrictTeacherLiveMode` and `renderLiveMode`, keeping correct draw numbers (`Trekk N`).

**Next session should start with:**
- Teacher opens draw → student sees the English word immediately while countdown runs → can find and click the Norwegian word on their card
- Card highlights immediately on click, "Riktig!" / "Feil." shows without delay
- Trekkhistorikk shows most recent draw at top, not bottom

---

### 2026-04-13 — Session 4: Infinite recursion in RLS helper functions + draw timer too short

**Root cause confirmed (DB test showed "stack depth limit exceeded"):**

All four RLS helper functions (`is_session_teacher`, `is_session_participant`, `is_participant_owner`, `is_teacher`) were `SECURITY INVOKER`. When the teacher's client runs a direct query on `session_participants`:
1. PostgreSQL evaluates the `session_participants_teacher_select` RLS policy
2. The policy calls `is_session_teacher(session_id)`
3. `is_session_teacher` queries `sessions` (which has RLS)
4. The `sessions` RLS policy calls `is_session_teacher(id)` → **infinite recursion**
5. PostgreSQL hits stack depth limit, silently treats the policy as FALSE → 0 rows returned

This is why `refreshTeacherParticipantProgress()` always showed "Ingen elever er inne ennå" even when the DB confirmed participants existed (visible via security-definer RPCs which run as `postgres` and bypass this recursion).

**What was fixed:**

- **DB migration applied — `fix_rls_helper_functions_security_definer` ✅**
  - All 4 helper functions now have `SECURITY DEFINER` + `SET search_path = public`
  - SECURITY DEFINER means they run as `postgres` → bypass RLS on inner queries → no recursion
  - Verified: `is_session_teacher` now returns `true` and `participants_visible = 1` for teacher in auth context
- `supabase/sql/supabase_bingo_v1_sql_editor_ready.sql`: Updated `is_session_teacher`, `is_teacher`, `is_session_participant` to add SECURITY DEFINER
- `supabase/sql/supabase_bingo_v2_strict_live_patch.sql`: Updated `is_participant_owner` to add SECURITY DEFINER

**Draw timer default was 3 seconds — way too short:**
- Session settings showed `draw_duration_seconds: 3`. The draw window opened and closed before students could respond.
- `teacher.html` input changed: default `3` → `15`, min `0` → `5`, max `20` → `60`
- `getLiveCountdownSeconds()` updated to enforce `Math.max(5, Math.min(60, ...))`

**Next session should start with:**
- **Hard-refresh both teacher and student browsers**
- Teacher creates a FRESH session (new settings with 15s timer) → opens lobby
- Student joins → should appear in Elevoversikt immediately (RLS recursion fixed)
- Teacher opens a draw → student should have 15 seconds to click a cell
- Student clicking should register as an answer and highlight the cell

---

### 2026-04-13 — Session 2: Live draw diagnosis + frontend fixes

**What we found (full diagnosis via direct Supabase access):**

#### What was already fine (no action needed)
- V3 join stability patch: **already applied** — session-scoped `client_token` constraint in place, `lock_timeout = 1500ms` in `join_bingo_session` ✅
- Anonymous sign-in: **working** — 7 anonymous users created during testing ✅
- RLS policies: all correct for teacher and participant selects ✅

#### Actual Root Cause: 12-hour session expiry
- `sessions.expires_at` default was `now() + interval '12 hours'`
- `join_bingo_session` gates on `s.expires_at > now()` — expired sessions return "Session not found or not joinable"
- Students were authenticating successfully (anonymous sign-in worked) but then couldn't join because ALL sessions had already expired
- That's why they showed as "connected" (auth worked) but the join failed
- **Fixed: changed DB default to `now() + interval '24 hours'` via migration**

#### Secondary issue: Poll errors silently swallowed
- Student: `refreshStrictLiveState().catch(()=>{})` — poll failures dropped silently
- Teacher: `refreshTeacherParticipantProgress({silent:true}).catch(()=>{})` — same
- **Fixed: added error counters in frontend — shows "Mistet kontakten" after 3 consecutive failures**

**What was done this session:**
- **DB fix (applied directly):** `sessions.expires_at` default changed from 12h → 24h
- `supabase/sql/supabase_bingo_v1_sql_editor_ready.sql`: updated to match (12h → 24h)
- `apps/bingo/student.html`: poll error counter + visible "Mistet kontakten" message
- `apps/bingo/teacher.html`: poll error counter + sync status surfacing for participant list failures
- Discovered Supabase MCP access works — can query and migrate DB directly

**Next session should start with:**
- Create a fresh session from the teacher page (all old ones expired)
- Test a student join end-to-end with the new 24h window
- Then move on to the teacher live dashboard + phase-out of anonymous join

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
- [x] **V3 join stability patch** — already applied in DB ✅
- [x] **12-hour session expiry** — fixed, extended to 24 hours via DB migration ✅
  - `supabase_bingo_v1_sql_editor_ready.sql` updated to match
- [x] **Frontend: surface poll errors** — done (`student.html` + `teacher.html`)
  - Students now see "Mistet kontakten" after 3 consecutive poll failures
  - Teacher sync status now shows participant list failures instead of silent drop
- [ ] **Session ID staleness** — fixed ✅
  - `student.html`: `liveSessionId` synced from `participantRecord.session_id` after join
  - `join_bingo_session` + `get_joinable_bingo_session`: `ORDER BY created_at DESC` added and applied to live DB
  - Teacher lobby now shows `[sessionId prefix]` + DB participant count for diagnostics
- [ ] **End-to-end test** — needs verification with fresh browser tabs
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
4. `supabase/sql/supabase_bingo_v3_join_stability_patch.sql` ← applied ✅
5. `supabase/sql/supabase_bingo_v4_session_lookup_fix.sql` ← applied ✅ (ORDER BY fix)
