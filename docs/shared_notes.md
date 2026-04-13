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
