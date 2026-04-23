# Supabase SQL Guide

## Canonical Files

Use these as the main source-of-truth SQL files going forward:

- `supabase_bingo_v1_sql_editor_ready.sql`
  - fresh Bingo V1 setup
  - already includes the current `join_bingo_session()` student-account bridge
- `supabase_student_accounts_v1_core_patch.sql`
  - canonical student-accounts rollout patch for an existing Bingo V1 database
  - already includes the later RLS and crypto fixes
- `supabase_bingo_v2_strict_live_patch.sql`
  - strict live gameplay patch on top of Bingo V1 + student accounts
  - adds persisted boards, per-draw responses, and teacher-controlled draw state
- `supabase_bingo_v3_join_stability_patch.sql`
  - join stability patch for existing live Bingo databases
  - hardens `join_bingo_session()` against duplicate/concurrent anonymous join attempts

For the current normal setup path, think in this order:

1. `supabase_bingo_v1_sql_editor_ready.sql`
2. `supabase_student_accounts_v1_core_patch.sql`
3. `supabase_bingo_v2_strict_live_patch.sql`
4. `supabase_bingo_v3_join_stability_patch.sql`

Later feature patches are applied in numeric order. For the current avatar
shop, apply `supabase_bingo_v17_avatar_shop.sql` first, then
`supabase_bingo_v18_avatar_faceshapes.sql` so the live item-cost catalogue
matches `media/avatar_faceshapes.png`.
