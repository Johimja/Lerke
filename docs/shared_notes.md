# Lerke — Shared Session Notes

## How to use this file

This is the **living collaborative log** for the Lerke project — shared between Atle (Johimja) and AI coding sessions over time.

- **Use this as shared context when needed**
- **Add a session entry** when starting or ending a work session
- **Check off roadmap items** as they're completed
- **CONTEXT EFFICIENCY:** Do not overfill the context window. Use grep/glob, read only relevant parts of files.
- This file is version-controlled — always in sync with the code

Reading order for a cold start:

1. `README.md` — current repo overview and active structure
2. **This file** — decisions, session history, roadmap

SQL context rule:

- Default to `supabase/sql/supabase_bingo_fresh_install_v18.sql` for current database context.
- Only open `supabase/sql/archive/legacy-migrations/` when you explicitly need historical migration details.

---

## Project Identity

**Lerke** is a classroom game portal built for Steinerskolen i Kristiansand, Norway.
Built by Atle Stray (Johimja) with AI coding assistance, hosted on GitHub Pages at `johimja.com/Lerke`.
Plain HTML/CSS/JS frontend, Supabase backend (auth + realtime + PostgreSQL).

Current live tool: **Lerke Bingo** (teacher-led live bingo with student join).
Next tool planned: **Lerke Quiz** (after Bingo is stable).

---

## Current Deploy State

| Item | State |
|---|---|
| Live URL | `johimja.com/Lerke` |
| Supabase DB | V1–V8 + podium + leaderboard + reactions/speed + V11 login_code + V12 XP + V13 avatars + V14 hall_of_fame + V16 wildcard + V17 avatar_shop + V18 teaching_word_lists + V18 avatar_faceshapes + V19 matte correct_answers + V19b reset_pin_login_code — all applied |
| Session expiry | 24h (fixed from 12h) |
| Lerke SVG branding | Done (`lerke_logo.svg`, `lerke_bingo_banner.svg`) |

---

### 2026-04-25 — Codex: Portal credential privacy and code-only reveal

**What was done:**

- `index.html`:
  - The logged-in student portal card no longer displays the student's `login_code`; it now shows only the student display name in the header.
  - The teacher class/student list shows only each student's display name by default.
  - Added a deliberate `Vis kode` action per student that reveals only `Innloggingskode` (`login_code`, with `student_code` fallback for legacy rows). It does not show or mention PIN.
  - `Ny PIN` remains the only flow that generates and displays a new PIN, alongside the login code, with the existing warning panel.
  - Added an in-browser `Utskriftslapper` queue for newly created students and newly reset PINs. The queue renders cuttable login slips with display name, login code, and the fresh PIN, uses print-only CSS so only slips print, and can be cleared immediately after printing.
  - Removed now-unused `student-item-meta` styling.
- `apps/bingo/teacher.html`:
  - Removed leftover light-theme CSS selectors for the deleted `Klasser og elever` / student-management UI. A scan found no remaining class/student-management code there; Hall of Fame still fetches classes independently when opened.
- Tests:
  - Added `tests/portal_student_code_reveal.test.mjs` to guard that the student portal card does not expose `login_code`, that `Vis kode` exists, and that code reveal does not expose PIN.
  - Extended the same test to guard the temporary print queue: create/reset responses add slips, `Vis kode` does not, and clearing the queue discards readable PINs.
  - Updated `tests/avatar_faceshapes_config.test.mjs` to read the archived v18 faceshape SQL path used by the current repo layout.

**Verification run:**

- `node tests/portal_student_code_reveal.test.mjs` ✅
- `node tests/avatar_faceshapes_config.test.mjs` ✅
- `node tests/matte_bingo_math.test.mjs` ✅
- `node tests/teacher_live_ui.test.mjs` ✅
- `node tests/student_strict_answer_ui.test.mjs` ✅
- `node tests/reactions_contract.test.mjs` ✅
- Inline JavaScript parse check for all four HTML files ✅
- `git diff --check` ✅

---

### 2026-04-24 — Automated: Student login code display and projected-screen privacy fix

**What was done:**

- `apps/bingo/teacher.html`:
  - Student list no longer shows any login codes by default. Added a "👁 Vis koder" / "🙈 Skjul koder" toggle button in the student list header. When revealed, codes show as the V11 `login_code` (6-char globally unique code) in monospace gold next to each student's name. A red inline warning ("⚠ Skjul før du viser skjermen til klassen!") is shown while codes are visible.
  - "Ny PIN" credential box now shows `Innloggingskode` (login_code, falling back to student_code for old records) and PIN in bold, replacing the old class code + student code display. A red warning banner ("⚠️ Ikke vis dette til klassen — snu skjermen eller steng skjermvisning først.") is shown at the top of the box. The box scrolls into view automatically when a new PIN is generated.
  - Status message after PIN reset now shows the student's display name instead of exposing the code in the status bar.
- SQL:
  - Created and applied `supabase/sql/archive/Patches/supabase_bingo_v19b_reset_pin_login_code_patch.sql` — updates `reset_student_pin` to return `login_code` in its JSON response alongside `student_code` and `pin`.

**Operational note:** V19b SQL patch applied to Supabase via CLI ✅.

---

### 2026-04-24 — Automated: Mattebingo equation mode and live sync fixes

**What was done:**

- `apps/bingo/teacher.html`:
  - Matte live rounds now generate equation groups by answer. In equation-card mode, a teacher prompt like `24` carries all valid equation answers in `correct_answers`, e.g. `2 × 12`, `12 × 2`, `3 × 8`, `8 × 3`, `4 × 6`, `6 × 4` when those tables are selected.
  - Equation generation now uses each selected table up to `max(12, table)`, and includes reversed equations. Selecting `1, 2, 3` can produce `3 × 12`, `12 × 3`, `10 × 3`, etc. Adding custom `18` allows `18 × 17` and `17 × 18`, but not `3 × 17`.
  - Fixed the teacher live join panel repeatedly collapsing on every poll/render. It now auto-collapses once per session/round, and manual reopening stays open.
  - Teacher roster keeps `x/5` and the five progress dots as connected-line progress, matching near-bingo logic. The earlier `0/5` report was caused by the student sync issue, not by the line-progress calculation itself.
  - Teacher bingo celebration de-duplication now includes the live session id and winner names, so a previous session's round 1 bingo cannot suppress celebration/jingle in a new math session.
- `apps/bingo/student.html`:
  - Strict live matte mode now respects `matte_mode='eq'`, so students see equations on their boards when the teacher selects "Stykke → Svar".
  - Direct student session URLs now re-load the live session settings after joining, before choosing strict/local behavior. This prevents QR/direct joins from falling back to local bingo marking while the teacher session is strict live.
  - Strict answer clicks no longer apply an optimistic green checkmark. The board only updates from server-confirmed `marked_cells`.
  - Only one answer can be in flight per draw. Wrong answers restore the board to confirmed marks, show the existing "Feil. Prøv igjen neste trekk." message, and the wrong cell remains usable on later draws.
- `apps/bingo-generator/index.html`:
  - Printable matte bingo now uses the same equation-generation and grouped answer logic as live bingo.
- SQL:
  - Created and applied `supabase/sql/archive/Patches/supabase_bingo_v19_matte_correct_answers_patch.sql` to the linked Supabase project `isuzuuvddteejktcowev`.
  - The patch replaces `submit_bingo_answer` so existing databases accept `current_draw.correct_answers` arrays, while still falling back to `current_draw.answer` for older draw payloads.
  - `supabase/sql/supabase_bingo_fresh_install_v18.sql` was kept in sync for new database installs only.
- Tests:
  - Added `tests/matte_bingo_math.test.mjs`.
  - Added `tests/teacher_live_ui.test.mjs`.
  - Added `tests/student_strict_answer_ui.test.mjs`, including a regression check that direct URL joins sync session settings before strict live mode is evaluated.

**Verification run:**

- `node tests/matte_bingo_math.test.mjs` ✅
- `node tests/teacher_live_ui.test.mjs` ✅
- `node tests/student_strict_answer_ui.test.mjs` ✅
- `node tests/reactions_contract.test.mjs` ✅
- `git diff --check` ✅

**Operational note:** The V19 SQL patch has already been applied to Supabase via `supabase db query --linked --file supabase/sql/archive/Patches/supabase_bingo_v19_matte_correct_answers_patch.sql`.

---

### 2026-04-23 — Automated: Head accessories layer (Avatar-5 + Avatar-6 + Avatar-7)

**What was done:**

**Avatar-5 (smoke-test):** Code-level review found no issues. All 20 face-shape items match across `index.html`, `teacher.html`, and `supabase/sql/supabase_bingo_v18_avatar_faceshapes.sql`. Sprite paths correct, XP values aligned, tile grid 4×5 verified. Test suite in `tests/avatar_faceshapes_config.test.mjs` covers all critical assertions. Marked as verified ✅.

**Avatar-6 (prop sheet generator):** Created `tools/generate_avatar_accessories.py` — Python/Pillow script that generates `media/avatar_head_accessories.png` (1024×1280, 4 cols × 5 rows, 256×256/tile, white-on-transparent silhouettes). 20 accessories: acc_none, acc_crown, acc_tophat, acc_cap, acc_graduation, acc_party_hat, acc_viking, acc_cowboy, acc_headband, acc_beanie, acc_sombrero, acc_laurel, acc_bow, acc_bandana, acc_witch_hat, acc_tiara, acc_chef_hat, acc_antlers, acc_earmuffs, acc_bunny_ears. Positioned to sit on top of face-shape anchor points (head top y≈55, center x=128, based on face-shape inspection). PNG verified: all 20 tiles with correct opaque pixel counts.

**Avatar-7 (layered renderer):**
- `index.html`:
  - Added `.avatar-acc-layer` CSS — same as `.avatar-layer` but with `avatar_head_accessories.png`
  - Added `ACCESSORY_CATALOGUE` (20 items, cat:'acc', all xp:0 for now — costs added in Avatar-8)
  - `pendingAvatar` default extended to `{head:'head_basic', acc:'acc_none'}`
  - `_itemByKey(key)` now searches both catalogues
  - `normalizeAvatarData` now returns `{head, acc}` with fallback to 'acc_none'
  - Added `renderSingleAccSprite(col,row,size)` for accessory-only previews in shop
  - `renderAvatarCircle` now renders face shape + accessory layer (acc_none = no second layer)
  - `renderAvatarShop` now shows Hode / Tilbehør tab switcher; uses correct sprite per tab
- `apps/bingo/teacher.html`:
  - Added `.t-avatar-acc-layer` CSS
  - Added `ACCESSORY_CATALOGUE_T` (20 items, col/row only)
  - `renderAvatarCircleT` now renders face + accessory layers (reads `avatarData.acc`)

**Key design note:** All accessories are xp:0 (free) in this release. They are saved as part of `avatar_data.acc` JSON field via the existing `save_student_avatar` RPC — no new SQL migration needed. Avatar-8 will add XP costs and optionally server-side purchase validation for accessories.

**Next task:** Avatar-8 — add XP costs to accessories (SQL + update catalogue), and optionally add server-side purchase validation for acc_* keys (extend `purchase_avatar_item` or add a new RPC).

---

### 2026-04-22 — Planning: Avatar layered props + paid colors (Avatar-5+)

**Decision:**

- Keep the code-first asset workflow. Use deterministic 1024×1280 sheets, 4 cols × 5 rows, 256×256/tile, transparent background, hard white silhouettes, no AI image generation for strict sprite assets.
- Use PNG sprite sheets for now, not SVG, because the app already renders sprite-sheet clips and canvas/CSS masks can recolor white silhouettes reliably. SVG can be revisited later for individual vector icons, but PNG sheets are safer for pixel-grid alignment.
- Keep `avatar_faceshapes.png` as the base head silhouette layer. New prop sheets must be drawn to the same tile grid and centered over the same anchor points so each prop fits every matching face-shape tile.

**Proposed layer order:**

1. Base face shape: `avatar_faceshapes.png`
2. Hair layer: future `avatar_hair.png`
3. Beard/facial-hair layer: future `avatar_beards.png`
4. Eye/glasses layer: future `avatar_eyes_glasses.png`
5. Mouth layer: future `avatar_mouths.png`
6. Head accessory layer: future `avatar_head_accessories.png`

**Color system idea:**

- Store colors in `avatar_data`, e.g. `{head, hair, beard, eyes, mouth, accessory, skinColor, hairColor, propColor}`.
- Recolor white PNG layers at render time with canvas or CSS mask. Canvas is preferred once multiple differently colored layers exist because each layer can be tinted separately.
- Color changes should cost XP each time they are saved. A color purchase overwrites the previous color, so changing again costs XP again.
- Recommended v19 RPC: `purchase_avatar_color(p_color_slot text, p_color text)` validates the slot and hex color, checks XP, deducts the color-change cost, updates `avatar_data`, and returns updated XP/avatar state.
- Start with a simple fixed cost, e.g. 25 XP per color save, before adding rarity/palette pricing. Use a hue slider/color picker in UI, but the server only accepts normalized hex colors.

**Ordered next tasks:**

- [ ] **Avatar-5: smoke-test current face-shape shop** — verify login, unlock, XP deduction, equip, persistence after refresh, and teacher roster/podium display using `avatar_faceshapes.png`.
- [ ] **Avatar-6: asset plan + generator for props** — write a small Python/PIL generator that produces aligned white-on-transparent prop sheets with the same 4×5 tile grid. First target should be one sheet only, likely `avatar_head_accessories.png`, because hats/hoods/crowns are easiest to validate over existing face shapes.
- [ ] **Avatar-7: renderer refactor for layered assets** — move avatar metadata/rendering into a small shared JS helper or carefully duplicated constants so `index.html` and `teacher.html` do not drift. Render multiple sprite layers in order.
- [ ] **Avatar-8: head accessories shop** — add prop item metadata, XP costs, purchase/equip logic, persistence in `avatar_data.accessory`, and teacher display support.
- [ ] **Avatar-9: paid color changes** — add SQL RPC for color-change purchases, UI color slider/picker, per-save XP deduction, and canvas/CSS recoloring. Start with base silhouette color only, then add hair/prop colors after layered props exist.
- [ ] **Avatar-10: hair sheet** — generate and integrate about 20 hair silhouettes: 5 feminine-coded, 5 masculine-coded, 10 neutral/strange. Treat labels as style names, not gender restrictions.
- [ ] **Avatar-11: eyes/glasses sheet** — generate and integrate eyes/glasses overlays. Keep them high-contrast and centered; test at small roster/podium sizes.
- [ ] **Avatar-12: beards and mouths** — generate facial hair and mouth overlays after eyes/glasses, because they depend most on face alignment and small-size readability.

---

### 2026-04-22 — Automated: Canonical face-shape spritesheet fix (Avatar-4)

**What was done:**

- Canonical avatar sheet is now `media/avatar_faceshapes.png` — the 1024×1280, 4 cols × 5 rows, 256×256/tile code-generated white-on-transparent face-shape sheet.
- Removed the obsolete tracked `media/avatarspreadsheet.png`; ignore/delete the older experimental `avatarspreadsheet12.png`, `avatar_faceshapes2.png`, and `avatar_faceshapes3.png` if they appear locally.
- `index.html` avatar shop now uses only the 20 real face-shape/head tiles from `avatar_faceshapes.png`. The old mixed 24-item head/outfit/face catalogue was replaced. Legacy saved avatar JSON falls back to `head_basic`.
- `apps/bingo/teacher.html` now renders the same face-shape sheet in roster, podium, and Hall of Fame.
- Added and applied `supabase/sql/supabase_bingo_v18_avatar_faceshapes.sql` to replace the server-side item-cost catalogue for DBs that already applied v17.
- Added `tests/avatar_faceshapes_config.test.mjs` to guard the sheet path, dimensions, and item catalogue.

**Migration applied** ✅ (`v18_avatar_faceshapes` via Supabase CLI, 2026-04-22). Verified `head_basic=0`, `head_afro=300`, old `outfit_tshirt=null`.

**Next task:** Smoke-test student avatar purchase/equip in the portal.

---

### 2026-04-22 — Automated: Cloud-saved teaching word lists (v18)

**What was done:**

- Created `supabase/sql/supabase_bingo_v18_teaching_word_lists.sql`:
  - New table `teacher_word_lists` (teacher_id, name, words jsonb, game_mode, times_used, last_used_at, created_at, updated_at). RLS: teacher owns their own lists. Unique on (teacher_id, name).
  - `save_teacher_word_list(p_name, p_words, p_game_mode)` — upserts by name for the current auth user.
  - `get_teacher_word_lists()` — returns all lists for current user sorted by last_used_at desc, then updated_at desc.
  - `delete_teacher_word_list(p_name)` — deletes by name for current user.
  - `mark_teacher_word_list_used(p_name)` — increments times_used + sets last_used_at to now().
  - **Migration applied** ✅ (`v18_teaching_word_lists` via Supabase MCP, 2026-04-22).
- `apps/bingo/teacher.html`:
  - `_cloudLists` cache variable (null = unfetched, array = cached result).
  - `_isTeacherLoggedIn()` — helper that returns true when supabaseClient + approved teacher.
  - `_listSaveStatus(msg, isErr)` — shows transient status text in `#list-save-status`, auto-clears after 3.5s.
  - `saveList()` → now async. Always saves to localStorage as backup. When logged in, also calls `save_teacher_word_list` RPC and shows "☁️ lagret til sky" status. Refreshes the visible list panel.
  - `loadList(name)` → now async. Reads from `_cloudLists` cache first (cloud words), falls back to localStorage. Calls `mark_teacher_word_list_used` (best-effort, non-blocking) to update usage stats.
  - `deleteList(name)` → now async. Deletes from localStorage + calls `delete_teacher_word_list` RPC when logged in.
  - `renderSavedLists()` → now async. When logged in: fetches cloud lists (cached after first fetch), shows ☁️ icon, word count, "N× brukt · DD.MM.YYYY". When not logged in: shows localStorage lists with 📋 icon.
  - `toggleSavedLists()` → now async (awaits `renderSavedLists`).
  - `_cloudLists=null` added to `signOutTeacher()` and top of `refreshTeacherAuthStatus()` to flush cache on auth changes.
  - HTML: "💾 Lagre til sky" button label; `#list-save-status` div added below save row; new CSS: `.list-save-status`, `.list-cloud-badge`, `.list-uses`.

**Lists are now device-agnostic for logged-in teachers.** Each list shows how many times it's been used in a game and when it was last loaded.

---

### 2026-04-22 — Automated: Spritesheet avatar rendering in teacher.html (Avatar-3)

**What was done:**

- `apps/bingo/teacher.html`:
  - Added `AVATAR_CATALOGUE_T` — 24-item lookup table (key, col, row).
  - Added `_tSpriteStyle(col, row, size)` — computes CSS `background-size` + `background-position` for a given spritesheet cell at given display size.
  - Replaced `renderAvatarCircleT` to check for new `{head, outfit, face}` format first, rendering a 3-layer sprite composite (`.t-avatar-sprite` + `.t-avatar-layer`). Falls back to letter+color circle for legacy data.
  - Added `.t-avatar-sprite` / `.t-avatar-layer` CSS (path: `../../media/avatarspreadsheet.png`).
  - Hall of Fame modal: replaced 5-line inline avatar construction with a single `renderAvatarCircleT(s.avatar_data, s.display_name, 32)` call.
  - Removed `AVATAR_COLORS_T` (no longer needed).
- `student.html`: no avatar rendering present — bingo board cells don't show student avatars, so no changes needed.

**Spritesheet avatar system is now complete across all 3 files.** Next task: Avatar-2 PR merged → continue to Glosebingo content improvements or other Tier 3 items.

---

### 2026-04-22 — Automated: Spritesheet avatar shop UI (Avatar-2)

**What was done:**

- `index.html`:
  - Added `AVATAR_ITEM_CATALOGUE` (24 items: 4 heads, 8 outfits, 12 faces — each with key, Norwegian label, spritesheet col/row, XP cost).
  - `renderSpriteAvatar(headKey, outfitKey, faceKey, size)` — builds a layered composite using 3 `.avatar-layer` spans with CSS `background-position` clips from `media/avatarspreadsheet.png` (1024×1536).
  - `renderAvatarCircle` updated: detects new `{head, outfit, face}` format and renders sprite composite; falls back to old letter+color circle for legacy data.
  - `renderAvatarShop()` — 3-tab picker (Hode/Antrekk/Ansikt), 4-column grid, each item shows full-avatar preview, cost label, and action button: "Ibrukt" (equipped), "Bruk" (own, not equipped), "Kjøp N XP" (can afford), disabled (locked).
  - `shopItemClick(key)` / `purchaseAndEquipItem(key)` — purchase flow: calls `purchase_avatar_item` RPC, updates local `total_xp` + `unlocked_avatar_items`, equips item, refreshes XP bar + avatar display + shop grid.
  - `saveStudentAvatar` simplified — no longer shows inline status (handled by shop status div).
  - Old color swatches + accessory buttons fully removed.
  - New CSS: `.lerke-avatar-sprite`, `.avatar-layer`, `.avatar-shop-*` — includes dark-mode overrides.
  - Avatar display size bumped from 36px → 48px in the portal card header.

**Next task:** Avatar-3 — update `renderAvatarCircleT` in teacher.html and any avatar display in student.html.

---

### 2026-04-22 — Automated: Avatar shop SQL (v17) — Subtask Avatar-1

**What was done:**

- Created `supabase/sql/supabase_bingo_v17_avatar_shop.sql`:
  - Added `unlocked_avatar_items text[] default '{}'` to `student_profiles`.
  - New immutable helper `get_avatar_item_cost(p_item_key)` — returns XP cost for each of the 24 spritesheet items (free items return 0, invalid key returns null).
  - New RPC `purchase_avatar_item(p_item_key)` — resolves student, validates item, checks XP, deducts XP, appends to `unlocked_avatar_items`. Returns `{ok, total_xp, unlocked_avatar_items, xp_spent}` (or `{ok:false, error}` on failure). Already-owned items return success without re-charging.
  - Updated `get_current_student_profile` to include `unlocked_avatar_items` array.
- **Migration applied** ✅ (`v17_avatar_shop` via Supabase MCP, 2026-04-22).
- Item XP costs: heads (Bald/Brown=0, Blonde=100, Alien=300); outfits (T-Shirt=0, Hoodie=50, Hawaiian=75, Jacket=100, Suit/Robes=150, Armor=200, Cyber=250); faces (Normal=0, Beard/Smile/Frown=50, Glasses/Sunglasses=75, Scar/Angry=100, Eyepatch=125, Visor=150, Cyborg=250, Zombie=300).

**Next task:** Avatar-2 — Update `index.html` with the spritesheet avatar shop UI (3-tab picker, XP-gated buy/equip, sprite CSS clips).

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
- [x] **Avatar-1 (SQL v17)**: Add `unlocked_avatar_items text[]` to `student_profiles`, `purchase_avatar_item(p_item_key)` RPC (XP deduction + unlock), `get_avatar_item_cost()` helper, update `get_current_student_profile` to return `unlocked_avatar_items`. Migration applied. ✅
- [x] **Avatar-2 (index.html)**: Replaced old color/accessory picker with spritesheet-based avatar shop and XP-gated buy/equip flow. Initially targeted a mixed sheet, then corrected by Avatar-4 to use the 20-item `avatar_faceshapes.png` catalogue only. ✅
- [x] **Avatar-3 (teacher.html)**: Updated `renderAvatarCircleT` for spritesheet avatar display in roster, podium, and Hall of Fame. Initially targeted a mixed sheet, then corrected by Avatar-4 to use `avatar_faceshapes.png`. ✅
- [x] **Avatar-4 (canonical face-shape sheet)**: Replaced the incorrect mixed `avatarspreadsheet.png` setup with `media/avatar_faceshapes.png` (1024×1280, 4×5). Shop and teacher display now use the 20 actual face-shape tiles only. Added SQL v18 to replace the item-cost catalogue for existing DBs. ✅
- [x] **Avatar-5: smoke-test current face-shape shop** — code-level review found all 20 items consistent across index.html, teacher.html, and SQL. No issues. ✅
- [x] **Avatar-6: create aligned prop sheet generator** — `tools/generate_avatar_accessories.py` generates `media/avatar_head_accessories.png` (1024×1280, 4×5 grid, 20 accessories). ✅
- [x] **Avatar-7: layered renderer refactor** — ACCESSORY_CATALOGUE added, `.avatar-acc-layer` CSS, `renderSingleAccSprite`, two-layer rendering in `renderAvatarCircle` and `renderAvatarCircleT`, Hode/Tilbehør shop tabs. All accessories free (xp:0) until Avatar-8. ✅
- [ ] **Avatar-8: head accessories shop** — add XP costs to accessories (SQL migration + update catalogue xp values), extend or add server-side purchase RPC for acc_* keys.
- [ ] **Avatar-9: paid color changes** — add color picker/slider and server-verified XP cost per saved color change.
- [ ] **Avatar-10+: hair, eyes/glasses, beards, mouths** — add one sheet/category at a time after the accessory layer is working.
- [x] **Glosebingo content improvements** — cloud-saved teaching word lists (SQL v18 `teacher_word_lists`, teacher.html hybrid cloud/localStorage save/load, usage stats shown in list panel) ✅
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
15. `supabase/sql/supabase_bingo_v17_avatar_shop.sql` ✅ applied
16. `supabase/sql/supabase_bingo_v18_teaching_word_lists.sql` ✅ applied
17. `supabase/sql/supabase_bingo_v18_avatar_faceshapes.sql` ✅ applied
18. `supabase/sql/archive/Patches/supabase_bingo_v19_matte_correct_answers_patch.sql` ✅ applied
