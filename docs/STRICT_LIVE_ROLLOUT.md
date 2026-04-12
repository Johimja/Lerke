# Lerke Bingo Strict Live Rollout

Purpose
-------
- Turn Lerke Bingo into a teacher-authoritative live game.
- Use the existing `sessions`, `session_rounds`, `session_state`, and `session_participants` model as the base.
- Roll out in phases so the frontend can migrate without a full rewrite in one step.

Target Product Rules
--------------------
- Teacher controls the live state.
- One draw has one answer window.
- Students can answer once per draw.
- No retroactive answering after lock.
- Correct answers permanently mark the board.
- Wrong answers do not permanently mark the board.
- Timeout gives no mark.
- In strict live mode, student `Tøm` and `Nytt kort` are disabled.
- New board each round.
- Manual teacher advance first.

Execution Order
---------------
1. Run:
   - `supabase/sql/supabase_bingo_v1_sql_editor_ready.sql`
   - `supabase/sql/supabase_student_accounts_v1_core_patch.sql`
   - `supabase/sql/supabase_bingo_v2_strict_live_patch.sql`
2. Update `apps/bingo/student.html` to read strict live state and submit answers through RPC.
3. Update `apps/bingo/teacher.html` to drive rounds and draws through RPC.
4. Remove local-only student controls during joined strict sessions.
5. Add teacher overview metrics.

Phase 1
-------
Goal:
- strict live answering with persisted board and draw state

Backend
- add persisted participant boards per session/round
- add per-draw participant responses
- extend `session_state` with live timing fields
- add teacher RPCs:
  - `start_bingo_round`
  - `open_bingo_draw`
  - `lock_bingo_draw`
  - `complete_bingo_round`
- add participant RPCs:
  - `upsert_participant_board`
  - `submit_bingo_answer`
  - `get_bingo_live_state`

Frontend
- `apps/bingo/student.html`
  - poll live state
  - save board into backend
  - submit one answer per draw
  - disable `Tøm` and `Nytt kort` when joined strict live session
- `apps/bingo/teacher.html`
  - start round
  - open/lock draw
  - show teacher summary

Definition Of Done
------------------
- teacher starts a round
- teacher opens a draw
- student can answer only while open
- one answer per student per draw
- lock marks non-answers as timeout
- correct answer marks persisted board
- wrong answer stays temporary only
- bingo is detected from persisted marked cells

Phase 2
-------
- teacher-side answered/correct/timeout counts during live draw
- teacher-side bingo list and near-bingo signals
- cleaner round-complete and next-round flow

Phase 3
-------
- optional hard mode rules
- optional answer reveal controls
- optional account-linked progression and reporting
