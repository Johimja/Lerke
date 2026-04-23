# Supabase SQL Guide

## Default Context

If you are reading SQL for normal repo context, start with:

- `supabase_bingo_fresh_install_v18.sql`

That file is the current canonical SQL snapshot for LLM/context purposes and for brand new installs.

Do **not** read the archived migration chain unless you are explicitly doing migration archaeology, diffing old behavior, or recovering an older database path.

## Install Paths

### Fresh install

For a brand new database, use:

- `supabase_bingo_fresh_install_v18.sql`
  - consolidated fresh-install setup
  - based on the old `server_initial_setup.sql` baseline plus the current v11-v18 feature set
  - intended to be free of project-specific secrets or personal data

### Existing database upgrade path

If you already have an older Lerke Bingo database and need the historical upgrade sequence, the old incremental patch chain now lives under:

- `archive/legacy-migrations/`

Ordered historical sequence:

1. `archive/legacy-migrations/supabase_bingo_v1_sql_editor_ready.sql`
2. `archive/legacy-migrations/supabase_student_accounts_v1_core_patch.sql`
3. `archive/legacy-migrations/supabase_bingo_v2_strict_live_patch.sql`
4. `archive/legacy-migrations/supabase_bingo_v3_join_stability_patch.sql`
5. `archive/legacy-migrations/supabase_bingo_v4_session_lookup_fix.sql`
6. `archive/legacy-migrations/supabase_bingo_v5_bingo_winner_state.sql`
7. `archive/legacy-migrations/supabase_bingo_v6_podium.sql`
8. `archive/legacy-migrations/supabase_bingo_v7_leaderboard.sql`
9. `archive/legacy-migrations/supabase_bingo_v8_reactions.sql`
10. `archive/legacy-migrations/supabase_bingo_v8_reactions_speed.sql`
11. `archive/legacy-migrations/supabase_bingo_v9_fastest_stats.sql`
12. `archive/legacy-migrations/supabase_bingo_v10_heartbeat.sql`
13. `archive/legacy-migrations/supabase_bingo_v11_student_login_code.sql`
14. `archive/legacy-migrations/supabase_bingo_v12_xp_levels.sql`
15. `archive/legacy-migrations/supabase_bingo_v13_avatars.sql`
16. `archive/legacy-migrations/supabase_bingo_v14_hall_of_fame.sql`
17. `archive/legacy-migrations/supabase_bingo_v16_comeback_wildcard.sql`
18. `archive/legacy-migrations/supabase_bingo_v17_avatar_shop.sql`
19. `archive/legacy-migrations/supabase_bingo_v18_teaching_word_lists.sql`
20. `archive/legacy-migrations/supabase_bingo_v18_avatar_faceshapes.sql`

### Historical files

- `archive/legacy-migrations/server_initial_setup.sql`
  - older consolidated fresh-install baseline through roughly v10
  - useful as a historical source/reference, but superseded by `supabase_bingo_fresh_install_v18.sql`
- `archive/Patches/`
  - legacy one-off patches kept for reference only

## Notes

- The fresh-install file is the default file to use for current SQL context.
- The archived numbered patch files are historical, not the default reading target.
- `archive/legacy-migrations/supabase_bingo_v18_avatar_faceshapes.sql` must come after `archive/legacy-migrations/supabase_bingo_v17_avatar_shop.sql` in the historical upgrade path because it replaces the avatar item cost catalogue to match `media/avatar_faceshapes.png`.
