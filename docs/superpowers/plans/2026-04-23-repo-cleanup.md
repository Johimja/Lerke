# Repo Cleanup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Clean up repo hygiene by tightening ignore coverage, fixing stale documentation references, and providing a clean SQL path for fresh installs without personal project data baked into the setup flow.

**Architecture:** Keep the cleanup conservative: do not restructure application code beyond what the current audit proves is stale or redundant. Treat the SQL folder as a canonical migration source plus one new consolidated fresh-install artifact, and keep archived legacy patches clearly separated instead of deleting historical material.

**Tech Stack:** Static HTML/CSS/JS, Markdown docs, Supabase SQL migrations, Git ignore files.

---

### Task 1: Ignore Policy Audit

**Files:**
- Modify: `.gitignore`
- Create: `.claudeignore`
- Create: `.aiignore`

- [ ] **Step 1: Expand the tracked git ignore rules to cover known local/tooling artifacts**

Add ignore entries for local IDE/agent/runtime state that should not be committed:

```gitignore
# Local editor / agent state
.vs/
.vscode/
.idea/
.claude/settings.local.json
.claude/worktrees/
.claude/
.ai/

# Local environment / build output
supabase/.temp/
node_modules/
dist/
build/
.cache/
coverage/
tmp/
temp/
*.log
```

- [ ] **Step 2: Add `.claudeignore` with the same local-artifact boundaries**

Create `.claudeignore` so agent tooling skips generated/local folders:

```gitignore
.git/
.vs/
.vscode/
node_modules/
dist/
build/
.cache/
coverage/
supabase/.temp/
.claude/settings.local.json
```

- [ ] **Step 3: Add `.aiignore` with the same high-noise exclusions**

Create `.aiignore` to exclude non-source artifacts from AI tooling:

```gitignore
.git/
.vs/
.vscode/
node_modules/
dist/
build/
.cache/
coverage/
supabase/.temp/
```

- [ ] **Step 4: Verify the ignore files contain the intended entries**

Run: `Get-Content .gitignore; Get-Content .claudeignore; Get-Content .aiignore`

Expected: All three files exist and list only local/generated/tooling paths, not active source files.

### Task 2: Documentation Consistency Pass

**Files:**
- Modify: `README.md`
- Modify: `docs/shared_notes.md`

- [ ] **Step 1: Fix stale repo references in `README.md`**

Replace references to missing paths like `docs/archive/reference` with references that exist today, and update the setup wording to match the current teacher flow (`Start live-økt` / `Live-innstillinger`).

- [ ] **Step 2: Fix stale session-start instructions in `docs/shared_notes.md`**

Remove or rewrite references to nonexistent files like `docs/recentmemory.txt`, and add a short note that this file is historical/shared context and not a strict startup dependency.

- [ ] **Step 3: Add SQL install guidance summary to docs**

Document the distinction between:

```text
- canonical migration chain for upgrades
- consolidated fresh-install SQL for new databases
- archived legacy patches for historical reference only
```

- [ ] **Step 4: Verify docs no longer point to missing files**

Run: `Select-String -Path README.md,docs\\shared_notes.md,supabase\\sql\\README.md -Pattern 'recentmemory|docs/archive/reference'`

Expected: No results.

### Task 3: SQL Cleanup and Fresh-Install Consolidation

**Files:**
- Modify: `supabase/sql/README.md`
- Create: `supabase/sql/supabase_bingo_fresh_install_v18.sql`

- [ ] **Step 1: Build a clean fresh-install SQL artifact**

Create a new SQL file by consolidating the current fresh-install baseline plus later feature patches:

```text
base:  supabase_bingo_v1_sql_editor_ready.sql
then:  v11, v12, v13, v14, v16, v17, v18_teaching_word_lists, v18_avatar_faceshapes
```

The file must contain schema/functions/catalogue changes only and no environment-specific values, project refs, user rows, or manual operator data.

- [ ] **Step 2: Preserve the incremental migration chain**

Do not delete the existing migration files. Keep them as the upgrade path for already-provisioned databases.

- [ ] **Step 3: Update SQL README to explain both usage paths**

Add explicit sections for:

```text
- Fresh install: run `supabase_bingo_fresh_install_v18.sql`
- Existing DB upgrade: apply numbered patch chain in order
- Archive: historical only
```

- [ ] **Step 4: Verify the consolidated SQL is free of personal/environment-specific values**

Run: `Select-String -Path supabase\\sql\\supabase_bingo_fresh_install_v18.sql -Pattern 'johimja|isuzu|sb_publishable|service_role|postgresql://' -CaseSensitive:$false`

Expected: No results.

### Task 4: Cleanup Verification

**Files:**
- Review: `git diff --stat`

- [ ] **Step 1: Check the final changed-file set**

Run: `git status --short`

Expected: Only the intended cleanup/doc/ignore/SQL files plus any already-in-progress user-approved work.

- [ ] **Step 2: Check for stale references one more time**

Run: `Get-ChildItem -Recurse -File | Select-String -Pattern 'docs/archive/reference|docs/recentmemory.txt|avatarspreadsheet.png' -CaseSensitive:$false`

Expected: Only historical notes where the old asset/path is clearly marked as obsolete, not active instructions.

- [ ] **Step 3: Review the diff**

Run: `git diff -- .gitignore .claudeignore .aiignore README.md docs/shared_notes.md supabase/sql/README.md supabase/sql/supabase_bingo_fresh_install_v18.sql`

Expected: A narrow hygiene-focused diff with no accidental app-code regressions.
