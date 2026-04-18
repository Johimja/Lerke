# Lerke 🎲

**A classroom game portal built for Educational Purposes**  
Current deploy path depends on the active host/domain setup.

License: source-available. Commercial use, redistribution, and hosted use require prior written permission from the copyright holder. See [LICENSE](LICENSE).

---

## What is this?

Lerke is a lightweight classroom game portal for Steinerskolen i Kristiansand. The current live tool is **Lerke Bingo**, with a teacher flow, a student flow, and a Supabase-backed live session model for login, approvals, session creation, student join, nicknames, and presence.

The app is still intentionally simple at the frontend level: mostly static HTML/CSS/JavaScript pages with a small Supabase backend layer behind the live Bingo flow. It originally started as a replacement for a broken Google Sheets bingo generator and has since grown into a broader Lerke portal.

There is now also an active next-step backend track for teacher-managed classes and student accounts using `class code + student code + PIN`, while anonymous live guest sessions are still intended to remain supported.

SQL execution guidance now lives in [supabase/sql/README.md](supabase/sql/README.md), so the main README does not have to duplicate which patch chain is current.

---

## File Structure

```text
lerke/
├── index.html                           # Portal landing page
├── apps/                                # Active app entry pages grouped by tool
├── config/                              # Shared frontend config files
├── media/                               # Active images/audio used by the live frontend
├── supabase/
│   └── sql/                             # Canonical SQL files and SQL guide
├── docs/                                # Active handoff note + archived references/prototypes/assets
└── README.md                            # This file
```

---

## Current Status

- `Lerke Bingo` is now the dedicated digital/live Bingo track.
- `Bingo Generator` is now split out as its own classic generator/print tool.
- `index.html` acts as the shared Lerke portal entry with:
  - teacher portal login
  - student portal login
  - app/tool launch tiles
  - direct routing into the real Bingo and Generator tools
- Teachers can:
  - create an account
  - request teacher access
  - be approved in Supabase
  - create live Bingo sessions
  - manage classes and student accounts from the portal
- Students can:
  - join by QR code
  - join by manual join code
  - get a generated nickname per session
  - reroll nickname within the session limit
  - log in through the student account portal with class code + student code + PIN
- Shared live session state is backed by Supabase.

Older planning notes and project history now live under [docs/archive/reference](docs/archive/reference).

---

## How to Use

### Teacher

1. Open the Lerke portal root on the current host and tap **Lerke Bingo** for the live version, or **Bingo Generator** for classic card generation
2. If needed, create a teacher account with **Lag konto**
3. Log in and use **Be om tilgang** to create a pending teacher profile
4. Approve the teacher in Supabase for now, then log in again
5. For the live version, choose **Glosebingo** or **Mattebingo**
6. Add/edit your word list or select multiplication tables
7. Set up the content and tap **Klargjør live-økt** to create the live session
8. Show students the QR code or join code
9. For printed/classic Bingo, use **Bingo Generator**

### Student

1. Scan the QR code from the teacher, or open `apps/bingo/student.html` and enter the join code
2. Join the live session and note your generated nickname
3. Tap **Prøv nytt navn** if you want a reroll and still have rerolls left
4. Tap cells to mark them as the teacher calls out words/equations
5. Get five in a row → BINGO!
6. For non-live sessions, rounds are managed automatically by the app. In live sessions, the teacher manages round transitions.

---

## Technical Notes

- **CONTEXT EFFICIENCY:** For AI agents working on this repo: Do not overfill the context window. Use surgical tools like grep/glob/read_file with line limits. Avoid reading entire large files unless absolutely necessary.
- Frontend is mostly plain HTML/CSS/JavaScript with no framework
- `index.html` now carries the shared portal login flows for teachers and students
- `apps/bingo/teacher.html` is the live-only teacher surface for Bingo setup, lobby, and draw flow
- `apps/bingo/student.html` is the student join page for live Bingo
- `apps/bingo-generator/index.html` contains the classic generator/print flow
- shared frontend config files now live in `config/`
- active images/audio now live in `media/`
- Live Bingo uses Supabase for auth, session state, join flow, and participant presence
- Student accounts use the teacher-managed class + student + PIN backend track
- `config/supabase-public-config.js` provides `window.LERKE_SUPABASE = { url, anonKey }`
- `config/supabase-public-config.js` is safe to deploy because it only contains the public project URL and publishable anon key
- Never put the Supabase `service_role` key in this repo or in frontend code
- **localStorage** is used for saved word lists in the classic generator (browser-specific, not synced)
- **QR data** is embedded in URL query string for the student join flow
- **Google Fonts** loaded via CDN (Raleway + Source Sans 3)
- **QR generation** via `api.qrserver.com` (requires internet)

---

## Possible Next Steps

### Best current paths forward

#### 1. Teacher live overview / dashboard

- [x] Show connected students during live play, not only in the lobby
- [x] Add teacher view of progress, near-BINGO boards, and round winners
- [x] Add clearer live controls for reset / next round / session state

#### 2. Glosebingo content improvements

- [ ] Add language selector for Glosebingo (e.g. Norwegian–German, Norwegian–French)
- [ ] Make it easier to reuse/import saved teaching sets across live sessions
- [ ] Consider a cleaner session setup summary before starting the live game

#### 3. Portal and account flow

- [ ] Continue refining teacher portal and student portal UX in `index.html`
- [ ] Expand student account / class management from "works" to more polished everyday workflow
- [ ] Decide how anonymous guest join and account-based join should coexist long term

#### 4. New Lerke tools

- [ ] **Quiz mode** — teacher creates multiple choice questions, students answer on their devices
- [ ] **Ordkjede** — sentence building game from vocabulary words
- [ ] Add clearer placeholder-to-real-tool rollout path in the portal tiles

#### 5. Product polish / platform

- [ ] PWA support — installable as app on phone home screen
- [ ] Optional leaderboard / round winner tracking
- [ ] Better mobile-first polish on teacher live screens

#### Already completed in this track

- [x] Split the classic generator flow out from `apps/bingo/teacher.html` into its own dedicated generator tool
- [x] Make Lerke Bingo digital/live-only on the teacher side
- [x] Keep Bingo Generator as a separate classic generator/print track
- [x] Move portal login flows into `index.html`
- [x] Mattebingo repetition / all-tables / custom-table improvements
- [x] Session naming, round tracking, and student progress indicator work

---

## Credits

Built by Atle Stray (Johimja) with assistance from Claude (Anthropic), Gemini (Google) & Codex (OpenAI) April 2026.

Hosted on GitHub Pages. Domain: johimja.com.
