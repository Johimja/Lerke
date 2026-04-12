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

## Archive

Historical patches and draft SQL now live in `supabase/sql/archive/`.

Structure:

- `archive/Drafts/`
  - early planning SQL and migration drafts
- `archive/Patches/`
  - one-off historical patch files that have since been baked into the canonical files above

Reference-only files currently archived there include:

- `supabase_bingo_v1_migration_draft.sql`
- `supabase_student_accounts_v1_draft.sql`
- `supabase_bingo_v1_student_account_join_patch.sql`
- `supabase_student_accounts_v1_rls_fix_patch.sql`
- `supabase_student_accounts_v1_crypto_fix_patch.sql`
- `supabase_bingo_v1_teacher_request_patch.sql`
- `supabase_bingo_v1_create_session_patch.sql`
- `supabase_bingo_v1_manual_join_patch.sql`
- `supabase_bingo_v1_client_token_fix_patch.sql`

These are reference material only, not recommended execution files.
