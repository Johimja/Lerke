# Supabase SQL Guide

## Install Paths

### Fresh install

For a brand new database, use:

- `supabase_bingo_fresh_install_v18.sql`
  - consolidated fresh-install setup
  - based on the old `server_initial_setup.sql` baseline plus the current v11-v18 feature set
  - intended to be free of project-specific secrets or personal data

### Existing database upgrade path

If you already have an older Lerke Bingo database, keep using the incremental patch chain:

1. `supabase_bingo_v1_sql_editor_ready.sql`
2. `supabase_student_accounts_v1_core_patch.sql`
3. `supabase_bingo_v2_strict_live_patch.sql`
4. `supabase_bingo_v3_join_stability_patch.sql`
5. `supabase_bingo_v4_session_lookup_fix.sql`
6. `supabase_bingo_v5_bingo_winner_state.sql`
7. `supabase_bingo_v6_podium.sql`
8. `supabase_bingo_v7_leaderboard.sql`
9. `supabase_bingo_v8_reactions.sql`
10. `supabase_bingo_v8_reactions_speed.sql`
11. `supabase_bingo_v9_fastest_stats.sql`
12. `supabase_bingo_v10_heartbeat.sql`
13. `supabase_bingo_v11_student_login_code.sql`
14. `supabase_bingo_v12_xp_levels.sql`
15. `supabase_bingo_v13_avatars.sql`
16. `supabase_bingo_v14_hall_of_fame.sql`
17. `supabase_bingo_v16_comeback_wildcard.sql`
18. `supabase_bingo_v17_avatar_shop.sql`
19. `supabase_bingo_v18_teaching_word_lists.sql`
20. `supabase_bingo_v18_avatar_faceshapes.sql`

### Historical files

- `server_initial_setup.sql`
  - older consolidated fresh-install baseline through roughly v10
  - useful as a historical source/reference, but superseded by `supabase_bingo_fresh_install_v18.sql`
- `archive/Patches/`
  - legacy one-off patches kept for reference only

## Notes

- The fresh-install file is for new environments.
- The numbered patch files remain the canonical upgrade path for existing environments.
- `supabase_bingo_v18_avatar_faceshapes.sql` must come after `supabase_bingo_v17_avatar_shop.sql` in the upgrade path because it replaces the avatar item cost catalogue to match `media/avatar_faceshapes.png`.
