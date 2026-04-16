# Lerke — Shared Session Notes

## How to use this file

This is the **living collaborative log** for the Lerke project — shared between Atle (Johimja) and Claude.

- **Read this at the start of every session** (after `docs/recentmemory.txt`)
- **Add a session entry** when starting or ending a work session
- **Check off roadmap items** as they're completed
- **CONTEXT EFFICIENCY:** Do not overfill the context window. Use grep/glob, read only relevant parts of files.
- This file is version-controlled — always in sync with the code

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
| Supabase DB | V1–V8 + podium + leaderboard + reactions/speed — all applied |
| Session expiry | 24h (fixed from 12h) |
| Lerke SVG branding | Done (`lerke_logo.svg`, `lerke_bingo_banner.svg`) |

---

### 2026-04-16 — Session 12: Teacher live mode crash fixes (full restore)

**Background:** A previous Gemini edit attempt introduced several fatal bugs into `teacher.html`. Several HTML elements were also deleted. The teacher live screen was completely broken.

**Root causes found and fixed:**

1. **`renderLiveMode` crashed when modal was closed** — `refreshTeacherLiveState()` calls `renderLiveMode()` directly, which ran before `openLiveMode()` showed the modal. `getElementById('live-kicker')` returned null → crash.
   - **Fix:** Guard at top of `renderLiveMode`: return early if `#live-modal` doesn't have class `'show'`.

2. **`resumeActiveSession` read non-existent `rounds_data`** — Gemini added code reading `teacherLiveState.session.rounds_data` which doesn't exist in the `get_bingo_live_state` API response. `liveRounds` was never populated on page reload.
   - **Fix:** Removed the reference. Reads `game_mode` from `settings` instead to set `liveLabel`.

3. **`drawIndexReachedRoundEnd` returned true when `totalDraws = 0`** — With empty `liveRounds` (recovery mode), `totalDraws = 0`, making `draw_index >= 0` always true. This caused "Fullfør runde" to show prematurely and `complete_bingo_round` to fire on the first button click.
   - **Fix:** Return `false` when `totalDraws <= 0` (unknown/recovery) — never prematurely end a round.

4. **`openLiveMode` button stuck as "Neste"** — HTML default for `#live-next-draw` is "Neste". In recovery mode `teacherLiveState` was already set before `openLiveMode`, so the pre-populate guard (`!teacherLiveState?.state`) skipped the correction.
   - **Fix:** Always pre-set button to "Åpne trekk" (strict render corrects it within 250ms).

5. **Missing HTML elements** — `live-round-label` and `live-answer` were deleted from the live modal HTML. Both are referenced extensively in JS render functions → TypeError on every render tick.
   - **Fix:** Restored both elements between the join-wrap and `live-stage`.

6. **Invisible text** — `live-title` and `live-answer` were `color:var(--muted)` (#7c8099) on a `#141926` background — near-zero contrast.
   - **Fix:** `live-title` → `#9bacc7`, `live-answer` → `#8c94b3`.

7. **`getTeacherRoundDrawTotal` always returned 0 in recovery** — `liveRounds` is empty on reload.
   - **Fix:** Falls back to `settings.draws_per_round` (new field stored in session settings on creation).

8. **`draws_per_round` not stored** — New sessions now include `draws_per_round` in the `settings` JSONB so recovery mode can display correct draw totals.

**Result:** Teacher live mode is fully functional. Confirmed working: "ÅPNE TREKK" → countdown → "LÅS TREKK (11)" → history builds → "RUNDE 1 AV 3" visible. ✅

---

### 2026-04-15 — Session 11: Authentication, account management, teacher UI polish

**What was shipped:**
- `apps/bingo/student.html`: "Logg inn med elevkode" link, "Bytt bruker" link, `signOutStudent()` and `escapeHtml()`.
- `apps/bingo/teacher.html`: Restored large glowing join code, auto-collapse join box on first draw, Live Ticker with 20+ gamified messages, larger countdown timer when join box is collapsed.
- `supabase/sql/supabase_bingo_v8_reactions_speed.sql`: `draw_reactions` table, `send_bingo_reaction` (fixed wrong column `user_id` → `auth_user_id`), `get_draw_reactions`, `touch_session_heartbeat`, `get_bingo_live_state` updated with `fastest_participant`, `speed_leaderboard`, `host_active`.

---

### 2026-04-15 — Session 10: Near-bingo alert + student manual controls removed

**What was shipped:**
- `apps/bingo/teacher.html`: Near-bingo alert — Elevoversikt highlights students who need 1 more correct answer; `⚡ 1 til!` badge and orange border on their row; alert banner lists their names.
- `apps/bingo/student.html`: Removed "Tøm" and "Nytt kort" buttons; teacher manages rounds in strict live mode.

---

## Open Questions

- None currently open.

---

## Roadmap

### Tier 0 — Fix Live Bingo

- [x] **Diagnose live draw communication issues** ✅
- [x] **V3 join stability patch** ✅
- [x] **12-hour session expiry** → extended to 24h ✅
- [x] **Frontend: surface poll errors** ✅
- [x] **Session ID staleness** — `liveSessionId` synced from `participantRecord.session_id`; `ORDER BY created_at DESC` on session lookup RPCs ✅
- [x] **End-to-end test** — confirmed working 2026-04-16 ✅
- [x] **Verify Lerke branding in all HTML files** — check `apps/bingo/teacher.html`, `student.html`, `apps/bingo-generator/index.html`

### Tier 1 — Bingo: Engagement Extras

- [x] **End-of-round podium** — gold/silver/bronze by `bingo_at_draw_index` ✅
- [x] **Student leaderboard** — collapsible Poengtavle after each round ✅
- [x] **Bingo banner F5 repeat fix** — sessionStorage guard, auto-dismiss on new round, game-over message ✅
- [x] **Near-bingo alert on teacher screen** ✅
- [x] **Fastest-answer stat per draw** ✅
- [x] **Live Reaction Feed** — 🎉 😬 😤 one-tap emoji, flashes on teacher screen ✅
- [x] **UI & Gamification** — glowing join code, auto-collapse, Live Ticker ✅
- [x] **End-of-round Speed Podium** — displayed in bingo celebration overlay, top 3 by avg response time ✅
- [x] **Single-code student login** — `login_code` (6-char, globally unique) replaces class code + student code. Login is now: one code + PIN. Students can also change their own PIN. SQL: v11. ✅
- [ ] **Phase out anonymous join** — login required for all students

### Tier 2 — Identity & Progression

- [ ] **Avatar creator in the portal** — pick body/color/accessory, shown in Elevoversikt and podium
- [ ] **XP and level system** — correct answer, bingo, speed bonus; level badge in portal
- [ ] **Session history / hall of fame** — most wins per student, longest win streak
- [ ] **Comeback wildcard** — one ⚡ gratis kryss after being shut out of N draws

### Tier 3 — Content & Modes

- [ ] **Glosebingo content improvements** — language selector, reuse saved teaching sets
- [ ] **Custom winning patterns** — diagonal only, T-form, full card
- [ ] **Team mode** — student pairs share a board

### Tier 4 — Next Tool

- [ ] **Lerke Quiz Mode** — multiple-choice questions, avatar + XP carries over

### Tier 5 — Platform Polish

- [ ] PWA support (installable on phone home screen)
- [ ] Mobile-first polish on teacher live screens
- [ ] **Full lerio → lerke cleanup** — CSS var names, rename `media/leriobingo.jpg`

---

## Architecture Quick Reference

| Layer | Detail |
|---|---|
| Frontend | Plain HTML/CSS/JS — no framework |
| Backend | Supabase (PostgreSQL + Auth + RLS) |
| Config | `config/supabase-public-config.js` — public anon key only, safe to commit |
| Auth | Teacher: email/password + manual Supabase approval. Student: class code + student code + PIN |
| Live game | Polling via `get_bingo_live_state()` RPC every 1.5s; teacher drives state via `start_bingo_round`, `open_bingo_draw`, `lock_bingo_draw` |
| Deploy | GitHub Pages — `johimja.com/Lerke` |

**SQL patch chain (canonical execution order):**
1. `supabase/sql/supabase_bingo_v1_sql_editor_ready.sql`
2. `supabase/sql/supabase_student_accounts_v1_core_patch.sql`
3. `supabase/sql/supabase_bingo_v2_strict_live_patch.sql`
4. `supabase/sql/supabase_bingo_v3_join_stability_patch.sql` ✅ applied
5. `supabase/sql/supabase_bingo_v4_session_lookup_fix.sql` ✅ applied
6. `supabase/sql/supabase_bingo_v5_bingo_winner_state.sql` ✅ applied
7. `supabase/sql/supabase_bingo_v6_podium.sql` ✅ applied
8. `supabase/sql/supabase_bingo_v7_leaderboard.sql` ✅ applied
9. `supabase/sql/supabase_bingo_v8_reactions_speed.sql` ✅ applied
10. `supabase/sql/supabase_bingo_v11_student_login_code.sql` — **apply next**
