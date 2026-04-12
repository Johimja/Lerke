# Lerke Development History

This file keeps the longer phase-by-phase history that used to live in `README.md`.

## Legacy note

Scope in Lerke has changed a lot from the original Bingo repository. The notes below are mainly useful as project history and implementation context, not as the primary source of truth for current usage.

### Phase 1 — Reading the original file

- Imported a 3-sheet Excel file (`BINGO_GENERATOR.xlsx`) with broken Google Sheets formatting
- Sheets: `Glose bingo ark`, `Matte bingo ark`, `Gloser Generator`
- Extracted 16 Norwegian/English word pairs and multiplication table data

### Phase 2 — First web version

- Rebuilt as a single `bingo.html` file to replace the spreadsheet
- Two tabs: **Glosebingo** (vocabulary) and **Mattebingo** (multiplication)
- Glosebingo: 4×4 grid, checkerboard dark/light pattern
- Mattebingo: 5×5 grid with GRATIS center cell
- Configurable number of cards (1–36)
- Generate button randomizes all cards

### Phase 3 — Teacher call lists

- Added configurable number of **rounds** (each round = new shuffled reading list)
- Two print buttons: **Skriv ut elevkort** (student cards) and **Skriv ut lærerark** (teacher sheet)
- Teacher sheet opens in a new window — clean print layout with numbered call grid
- Each item shows the word/equation + answer for easy verification
- Designed to eliminate accusations of favoritism — fully randomized

### Phase 4 — Matte improvements

- Added **modus toggle** for Mattebingo:
  - *Svar → Stykke*: card shows answer, teacher reads equation
  - *Stykke → Svar*: card shows equation, teacher reads answer
- Extended multiplication tables from 1–10 to **1–12**
- Table selector grid changed to 6 columns to fit 12 buttons
- GRATIS cell now appears at a **random position** on each card (was always center)

### Phase 5 — Hosting on GitHub Pages

- Originally deployed to `johimja.com/bingo` via GitHub Pages (repo: `Johimja/bingo`)
- Public repo required for free GitHub Pages
- Fixed JavaScript timing bug where table toggle buttons failed to render in real browsers (moved from JS-generated to hardcoded HTML)
- Fixed `null addEventListener` crash on QR modal at page load
- Removed auto-generation of Mattebingo on startup (was triggering "not enough unique answers" alert with default 1- and 10-times tables)

### Phase 6 — Glosebingo upgrade to 5×5

- Glosebingo upgraded from **4×4 to 5×5** (25 cells) to match Mattebingo
- Word **reuse logic**: if fewer than 25 word pairs, the pool repeats to fill the grid — minimum 5 words required
- Default word list expanded from 16 to **25 pairs** including: Freedom/Frihet, History/Historie, Language/Språk, Society/Samfunn, Change/Endring, Power/Makt, Between/Mellom, Almost/Nesten, Together/Sammen

### Phase 7 — Word list manager

- Added full **ordliste management** in the Glosebingo sidebar:
  - **💾 Lagre**: save named list to browser localStorage
  - **📂 Lagrede lister**: browse, load, and delete saved lists
  - **⬇️ Eksporter**: download list as `.json` file with timestamp (`bingo_gloser_DDMMYYYY_HHMM.json`)
  - **⬆️ Importer**: load a `.json` file from device
- Export/import enables sharing lists between teachers and devices
- localStorage persists between sessions on the same device/browser

### Phase 8 — QR code with embedded data

- QR code now encodes the **full game data** into the URL:
  - Glosebingo: `bingo-elev.html?type=glose&mode=no&data=Word1|Ord1;Word2|Ord2...`
  - Mattebingo: `bingo-elev.html?type=matte&tables=2,3,5,7`
- Uses [api.qrserver.com](https://api.qrserver.com) to generate QR image
- Students scan → browser decodes URL → generates correct card automatically

### Phase 9 — Student card (`bingo-elev.html`)

- Dedicated mobile-optimized student page
- Reads game data from URL parameters
- Features:
  - Random 5×5 bingo card based on teacher's word list or tables
  - Tap cells to mark them
  - BINGO banner with animation when five in a row is detected
  - **Tøm** for next round on same card
  - **Nytt kort** for a new random card
  - GRATIS cell auto-marked

### Phase 10 — Lerke portal (`index.html`)

- New landing page at `johimja.com/lerke`
- Portal-style landing page for launching classroom tools
- "Lerke" branding as the main portal identity
- Placeholder cards for future games

### Phase 11 — Student card improvements

- Progress indicator below the card
- Session name in URL and card header

### Phase 12 — QR modal session naming

- QR modal got a session name field
- Session name embedded in QR URL
- QR code regenerated with debounce while typing

### Phase 13 — Responsive layout overhaul

- Fluid sidebar
- Sticky desktop sidebar
- Fluid cards grid
- Better spacing and overflow handling
- Improved long-word handling

### Phase 14 — Mobile sidebar and button fixes

- Fixed sticky sidebar overlap on mobile
- Fixed overflow issues for import/export/list buttons

### Phase 15 — 4 cards per A4 print layout

- Print layout upgraded from 2 cards per page to **4 cards per A4 (2×2)**
- Kept per-card break protection while allowing the grid to flow across pages

### Phase 16 — Supabase session scaffolding

- Added first-pass Supabase wiring for future shared live sessions
- `bingo-laerer.html` can now:
  - sign in a teacher with Supabase email/password
  - create a teacher account from the UI
  - request teacher approval through RPC
  - create a live Bingo session in the database when generating cards
  - include `session` + `join` data in the QR URL when live session creation succeeds
- `bingo-elev.html` can now:
  - sign in anonymously with Supabase
  - join a live Bingo session by QR or manual join code
  - call `join_bingo_session(...)` through RPC
  - call `reroll_nickname(...)` through RPC
  - keep `last_seen_at` fresh through `touch_participant(...)`

### Next planned direction after Phase 16

- Live draw mode in `bingo-laerer.html`
- Digital-only bingo flow
- Shared session updates between teacher and student devices
- Live teacher overview of student status and progress
