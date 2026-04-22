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
| Supabase DB | V1–V8 + podium + leaderboard + reactions/speed + V11 login_code — all applied |
| Session expiry | 24h (fixed from 12h) |
| Lerke SVG branding | Done (`lerke_logo.svg`, `lerke_bingo_banner.svg`) |

---

### 2026-04-22 — Automated: Comeback wildcard (v16)

**What was done:**

- Created `supabase/sql/supabase_bingo_v16_comeback_wildcard.sql`:
  - New RPC `use_comeback_wildcard(p_session_id, p_cell_index)` — marks any cell on the student's current-round board without requiring a matching draw. No XP awarded. Returns updated `marked_cells`, `has_bingo`, `bingo_count`. Checks for bingo via existing `board_has_bingo()` helper.
- **Migration applied** ✅ (`v16_comeback_wildcard` via Supabase MCP, 2026-04-22).
- `apps/bingo/student.html`:
  - New variables: `WILDCARD_THRESHOLD=3`, `consecutiveMisses`, `wildcardAvailable`, `wildcardActive`, `wildcardRound`, `lastWildcardDrawKey`.
  - In `applyStrictLiveState`: after each draw resolves (`draw_locked` or `round_complete` phase, new draw key), checks response outcome. Wrong/timeout/no-response increments `consecutiveMisses`; correct resets it. When threshold reached → `wildcardAvailable=true`, shows notification.
  - New `#wildcard-wrap` / `#wildcard-btn` HTML element between session-panel and card-wrap.
  - `updateWildcardButton()`: shows/hides button, toggles `.active` class when activated.
  - `toggleWildcard()`: activates wildcard mode, changes button label to "Velg et felt å merke…".
  - `useWildcard(idx)`: calls `use_comeback_wildcard` RPC, applies marked cells, checks for bingo, resets all wildcard state.
  - `toggleCell()`: when `wildcardActive && wildcardAvailable`, routes cell tap to `useWildcard()` instead of normal answer submission.
  - CSS: pulsing gold border button, `.active` state (gold fill), light-mode overrides.

**Next task:** PWA support / mobile polish. Or Glosebingo content improvements (reuse saved teaching sets).

---

### 2026-04-22 — Automated: Class Hall of Fame modal on teacher screen (v15)

**What was done:**

- `apps/bingo/teacher.html`: Added "🏆 Hall of Fame" control card button to both the Glose and Matte sidebar panels.
- New `<div id="hall-of-fame-modal">` (setup-modal) with student ranking list.
- `openHallOfFame()`: calls `get_class_hall_of_fame(p_class_id)` with `selectedClassId`, renders all students ranked by wins. Each row shows: avatar circle (color + initial + accessory), display name, Nivå badge, XP, win count (gold), win %, longest streak 🔥, podium count 🏅. Top 3 get medal emojis.
- No SQL migration needed — uses v14 RPC already applied.

**Next task:** Comeback wildcard — one ⚡ free correct mark after being shut out of N draws. Or PWA support / mobile polish.

---

### 2026-04-20 — Automated: Session history / hall of fame (v14)

**What was done:**

- Created `supabase/sql/supabase_bingo_v14_hall_of_fame.sql`:
  - New RPC `get_student_stats()` — returns `rounds_played`, `rounds_won`, `longest_win_streak`, `podium_count` (top-3 finishes), `sessions_played` for the logged-in student. Uses gaps-and-islands window function for streak calculation.
  - New RPC `get_class_hall_of_fame(p_class_id)` — returns all active students in a class sorted by rounds_won desc, includes XP/level/avatar for teacher-facing use.
- `index.html`: Added collapsible "Min statistikk" `<details>` to student session card. `loadStudentStats()` fetches `get_student_stats()` on login and renders a 2-col grid: bingo rounds won, spill spilt, lengste vinnerrekke, pallplasseringer, win %.

**Migration applied** ✅ (`v14_hall_of_fame` via Supabase MCP, 2026-04-20).

**Next task:** Class hall of fame on teacher screen — show a leaderboard modal with all students' stats. Or Comeback wildcard (Tier 2).

---

### 2026-04-19 — Automated: Avatar creator (v13)

**What was done:**

- Created `supabase/sql/supabase_bingo_v13_avatars.sql`:
  - Added `avatar_data jsonb default null` to `student_profiles`.
  - New RPC `save_student_avatar(p_avatar_data)` — saves logged-in student's avatar.
  - New RPC `get_session_student_avatars(p_session_id)` — returns `{display_name: avatar_data}` map for teacher.
  - Updated `get_current_student_profile` to include `avatar_data`.
- `index.html`: Avatar display (colored circle with initial + accessory emoji) shown in student session card header alongside name. "Endre avatar" `<details>` picker with 6 color swatches and 4 accessories (none/👑/⭐/⚡). Saves immediately on selection. CSS classes: `.lerke-avatar`, `.avatar-header`, `.avatar-picker-colors`, `.avatar-acc-btn`.
- `apps/bingo/teacher.html`: `renderAvatarCircleT()` helper, `studentAvatarCache` (keyed by display_name), `fetchSessionAvatars()` called on each roster refresh. Avatar circle shown next to student name in live roster (Elevoversikt). Avatar shown in end-of-round podium above name.

**Migration applied** ✅ (`v13_avatars` via Supabase MCP, 2026-04-19).

**Next task:** Class hall of fame on teacher screen — show a leaderboard modal with all students' stats. Or Comeback wildcard (Tier 2).

---

### 2026-04-19 — Automated: XP and level system (v12)

**What was done:**

- Created `supabase/sql/supabase_bingo_v12_xp_levels.sql`:
  - Added `total_xp integer not null default 0` to `student_profiles`.
  - New helper `xp_to_level(p_xp)` → `floor(p_xp/100)+1` (level 1 = 0–99 XP, +1 level per 100 XP).
  - Replaced `submit_bingo_answer` to award XP to the linked student profile on each correct answer (+10 XP) and on first bingo in a round (+50 XP). XP is only awarded when `student_profile_id` is set (logged-in students). Returns `xp_gained`, `total_xp`, `level` in the response.
  - Replaced `get_current_student_profile` to include `total_xp` and `level`.
- `index.html`: Added XP bar + level badge (`Nivå N`) to student session card. Renders when student is logged in and `total_xp` is present.
- `apps/bingo/student.html`: Correct answer note now appends `+N XP` when `xp_gained > 0`.

**Migration applied** ✅ (`v12_xp_levels` via Supabase MCP, 2026-04-19).

**Next task:** Avatar creator in the portal (Tier 2) — pick body/color/accessory, shown in Elevoversikt and podium. Or continue with Session history / hall of fame.

---

### 2026-04-18 — Automated: lerio → lerke cleanup

**What was done:**

- Removed `window.LERIO_SUPABASE = window.LERKE_SUPABASE` backward-compat alias from `config/supabase-public-config.js` and `config/supabase-config.example.js`.
- Removed `||window.LERIO_SUPABASE` fallback from `SUPABASE_CONFIG` in `apps/bingo/student.html`, `apps/bingo/teacher.html`, and `index.html`.
- Removed stale README note about the alias.
- `media/leriobingo.jpg` was never present in the repo — nothing to rename.
- Roadmap item marked complete.

**Next task:** Start Tier 2 — **XP and level system** (correct answer, bingo, speed bonus; level badge in portal). Requires SQL migration and frontend changes.

---

### 2026-04-16 — Session 15: Day/night mode toggle across all pages

**What was shipped:**

- All 4 HTML pages (`index.html`, `apps/bingo/teacher.html`, `apps/bingo/student.html`, `apps/bingo-generator/index.html`) now have a 🌙/☀️ toggle button fixed in the lower-left corner.
- Theme follows system `prefers-color-scheme` on first visit; manual toggle persists in `localStorage` (`lerke-theme`) and carries across all pages.
- `index.html`: Dark/night theme uses a deep plum palette (`#15101f`–`#1a1428` backgrounds, `#1e1630` panels, `#e8e2f2` text, subtle purple borders). Accent colours (plum, green, gold) are unchanged. Hardcoded warm-paper backgrounds overridden via `[data-theme="dark"]` selectors.
- `teacher.html`, `student.html`, `bingo-generator/index.html`: These were already dark. New light/day mode uses the index.html warm-paper palette (`--bg:#f8f2e8`, panels `#fffaf2`). Live game modals and credential boxes intentionally remain dark in both modes.
- Theme init script sits in `<head>` (synchronous, after `<style>`) to avoid flash of unstyled content. Toggle JS added before `</body>`.
- Branch: `claude/add-night-mode-toggle-wsngP` — PR pending merge.

---

### 2026-04-16 — Session 14: Student email/password login path

**What was shipped:**

- `index.html`: Added "Logg inn med e-post i stedet" toggle link below the student login_code + PIN form. Clicking it swaps to an email+password form (`student-login-email-form`). `portalStudentLoginEmail()` calls `supabaseClient.auth.signInWithPassword`; existing `refreshPortalAuthState` then calls `get_current_student_profile` to hydrate `currentStudentProfile`. If the email isn't linked to any student account, the session is signed out and the user gets a clear error. Toggle link in the email form goes back to code login.
- This closes the ⚠️ known limitation from Session 13 — email association is now a usable login path.

**Next task:** Phase out anonymous join (Tier 1) — require login for all students joining Bingo.

---

### 2026-04-16 — Session 13: Single-code login, speed podium, email association, glose generator, LM Studio

**What was shipped:**

**Speed Podium:**

- `apps/bingo/teacher.html`: End-of-round Speed Podium in the bingo celebration overlay — top 3 fastest responders from `speed_leaderboard` data already in the RPC. Icons ⚡/🔥/💨 with average time display.

**Single-code student login (V11):**

- `supabase/sql/supabase_bingo_v11_student_login_code.sql` (applied ✅): Adds `login_code` (6-char, globally unique) to `student_profiles`. Backfills all existing students. New RPCs: `student_login_with_code(p_login_code, p_pin)` replaces 3-field login; `student_change_pin(p_current_pin, p_new_pin)` for self-service PIN changes.
- `index.html`: Student login form simplified from **3 fields** (class code + student code + PIN) to **2 fields** (login_code + PIN). Teacher student list shows `login_code` prominently. "Bytt PIN" section added to student session card. Fixed `ensurePortalStudentSession` to not sign out email-linked student sessions.
- `apps/bingo/student.html`: Account meta now shows login_code instead of class+student codes.

**Email/password association:**

- `index.html`: Logged-in students can optionally link an email + password to their account via the portal. If already linked, the option is hidden and replaced with a password-reset form. Students who forget their email password can log in with login_code + PIN and reset from there. All done via Supabase SDK `updateUser` (no extra SQL).
- ⚠️ **Known limitation:** The email/password credentials are linked in Supabase Auth, but the portal does **not yet have a login form for students to use email+password**. Currently students can only enter via login_code + PIN. Email was added as a future upgrade path — the portal login flow still needs an "or log in with email" branch to make it usable. Add this before broadly advertising the feature.

**Glose generator (`apps/bingo-generator/index.html`):**

- Added full "⚡ Generer gloser" sidebar section with:
  - **Language dropdowns** — source and target language, 10 languages each (Norsk, Engelsk, Tysk, Spansk, Fransk, Italiensk, Portugisisk, Arabisk, Kinesisk, Japansk).
  - **Word-translate tab** — teacher types/pastes individual words, each gets translated via MyMemory free API (no key needed, no account, CORS-friendly: `api.mymemory.translated.net`). 250ms delay between calls to respect rate limits.
  - **Text-extract tab** — teacher pastes a full text; system extracts candidate words (4–18 chars, filtered against 100+ stop words across 6 languages), then either:
    - Sends to **MyMemory** for free translation word-by-word, or
    - Sends full text + word-count setting to an **LLM** that returns word pairs as JSON.
  - **Word count slider** — 3 to 30 pairs.
  - **Mode toggle** — "Til Norsk" / "Fra Norsk" (direction clarified).
  - Pairs are previewed and individually removable before being added to the active word list with duplicate detection.

**LLM providers for glose generation:**
Three providers selectable in a dropdown:

1. **MyMemory (free)** — no key, rate-limited, word-by-word.
2. **Anthropic (Claude Haiku)** — API key saved to `localStorage` in teacher's own browser. Routed via Supabase edge function `generate-glose` (deployed ✅ with `verify_jwt: false`). Model: `claude-haiku-4-5-20251001`.
3. **OpenAI (GPT-4o-mini)** — same as Anthropic, different endpoint. Both cloud keys are **never stored in Lerke's DB** — localStorage only, teacher pays their own bill.
4. **LM Studio (lokal)** — calls `http://localhost:1234` directly from the browser. Bypasses edge function entirely. Teacher can change the URL if port differs. "Hent modeller" button fetches available models via `GET /v1/models` and populates a select.

**LM Studio — settings the teacher must configure:**
> These settings are in LM Studio → Developer → Local Server → Server Settings:
>
> - **Enable CORS** ✅ — must be ON (browser sends cross-origin requests from `https://johimja.com`)
> - **Server Port** — default 1234. If changed, teacher must update the URL field in the glose generator.
> - **Serve on Local Network** — OFF is fine for the teacher's own machine. Turn ON if the school network should reach LM Studio from another device (e.g., teacher laptop → classroom display). Note: this does NOT help students reach it from their own devices unless all are on the same LAN and CORS + firewall allow it.
> - **Require Authentication** — leave OFF unless you know what you're doing (adding auth tokens would require extra UI in the generator).
> - LM Studio must have a model loaded and in READY state before generation works.

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
- [x] **Email/password association** — logged-in students can link an email + password to their account. Option hidden once linked. Password reset via login_code + PIN. ✅
- [ ] **Phase out anonymous join** — login required for all students

### Tier 2 — Identity & Progression

- [x] **Avatar creator in the portal** — color + accessory picker, shown in portal card, Elevoversikt, and podium; SQL v13 ✅
- [x] **XP and level system** — correct answer (+10 XP), bingo (+50 XP); level badge + XP bar in portal; SQL v12 (apply in Supabase) ✅
- [x] **Session history / hall of fame** — most wins per student, longest win streak, podium count, win %, shown in student portal "Min statistikk" section; SQL v14 ✅
- [x] **Class Hall of Fame on teacher screen** — 🏆 modal with all students ranked by wins, avatar, XP/level, win %, streak, podium count; v15 ✅
- [x] **Comeback wildcard** — one ⚡ gratis kryss after 3 consecutive non-correct draws; SQL v16 ✅

### Tier 3 — Content & Modes

- [x] **Glose generator** — "⚡ Generer gloser" in bingo-generator sidebar. Language pair dropdowns (10 langs), word-translate tab (MyMemory free API), text-extract tab (MyMemory word-by-word or LLM). LLM providers: Anthropic Claude Haiku, OpenAI GPT-4o-mini (teacher's own key in localStorage, routed via edge function), LM Studio local API (direct browser→localhost, no edge function). Mode buttons: "Til Norsk" / "Fra Norsk". ✅
- [x] **Glose generator in Lerke Bingo teacher.html** — The full "⚡ Generer nye gloser" section (language pair dropdowns, "Oversett ord" tab via MyMemory, "Fra tekst" tab with Simple/LLM mode, LM Studio support) is now embedded inside the Listebank → Ordlister modal in `apps/bingo/teacher.html`. Generated word pairs are added directly to the active word list with duplicate detection. All styles and light/dark mode support included. ✅
- [x] **Student email/password login path** — "Logg inn med e-post i stedet" toggle added to student login form. `portalStudentLoginEmail()` calls `signInWithPassword`; `refreshPortalAuthState` picks up student profile via `get_current_student_profile`. If email isn't linked to a student account, signs out and shows an error. ✅
- [ ] **Priority: If possible! Use the spritesheet avatarspreadsheet.png in folder /media to create custom Avatar design posibilities for the students, make sure that each individual head, outfit and accessory are correctly separated and added in the customize window. Students use gained XP to unlock the different items available, like Alien head (300xp), deduct this xp from their total, and only apply and affirm change if they can afford it at purchase time. Must be memory peristent to individual user. (split this task into multiple separate subortinate tasks if needed, in this file. Just do one at a time. If you change this task, then edit this file and update with the new task list before finishing.
- [ ] - [ ] **Glosebingo content improvements** — reuse saved teaching sets across sessions
- [ ] **Custom winning patterns** — diagonal only, T-form, full card
- [ ] **Team mode** — student pairs share a board

### Tier 4 — Next Tool

- [ ] **Lerke Quiz Mode** — multiple-choice questions, avatar + XP carries over

### Tier 5 — Platform Polish

- [ ] PWA support (installable on phone home screen)
- [ ] Mobile-first polish on teacher live screens
- [x] **Full lerio → lerke cleanup** — removed `window.LERIO_SUPABASE` backward-compat alias from config files and HTML fallbacks; `leriobingo.jpg` never existed ✅

---

## Architecture Quick Reference

| Layer | Detail |
|---|---|
| Frontend | Plain HTML/CSS/JS — no framework |
| Backend | Supabase (PostgreSQL + Auth + RLS) |
| Config | `config/supabase-public-config.js` — public anon key only, safe to commit |
| Auth | Teacher: email/password + manual Supabase approval. Student: `login_code` (6-char) + PIN. Optional email/password upgrade via portal. |
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
10. `supabase/sql/supabase_bingo_v11_student_login_code.sql` ✅ applied
11. `supabase/sql/supabase_bingo_v12_xp_levels.sql` ✅ applied
12. `supabase/sql/supabase_bingo_v13_avatars.sql` ✅ applied
13. `supabase/sql/supabase_bingo_v14_hall_of_fame.sql` ✅ applied
14. `supabase/sql/supabase_bingo_v16_comeback_wildcard.sql` ✅ applied
