import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';

const root = new URL('..', import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, '$1');

function read(relPath) {
  return readFileSync(join(root, relPath), 'utf8');
}

const indexHtml = read('index.html');
const teacherHtml = read('apps/bingo/teacher.html');
const sqlPatch = read('supabase/sql/archive/Patches/supabase_bingo_v21_avatar_color_patch.sql');
const freshInstall = read('supabase/sql/supabase_bingo_fresh_install_v18.sql');

// SQL: RPC exists, validates slot/format, fixed cost, free no-op on same color
assert.match(sqlPatch, /create or replace function public\.purchase_avatar_color\(p_color_slot text, p_color text\)/);
assert.match(sqlPatch, /v_cost\s+int := 25;/);
assert.match(sqlPatch, /p_color !~ '\^#\[0-9a-fA-F\]\{6\}\$'/);
assert.match(sqlPatch, /lower\(v_current_color\) = lower\(p_color\)/);
assert.match(sqlPatch, /grant execute on function public\.purchase_avatar_color\(text, text\) to authenticated, anon;/);

// Fresh-install file kept in sync
assert.match(freshInstall, /purchase_avatar_color\(p_color_slot text, p_color text\)/);

// index.html: mask-based recoloring of the head layer, color picker UI, purchase flow
assert.match(indexHtml, /-webkit-mask-image:url\('media\/avatar_faceshapes\.png'\)/);
assert.match(indexHtml, /function _headLayerStyle\(/);
assert.match(indexHtml, /const AVATAR_COLOR_PRESETS=\[/);
assert.match(indexHtml, /function renderAvatarColorPicker\(/);
assert.match(indexHtml, /async function chooseAvatarColor\(/);
assert.match(indexHtml, /supabaseClient\.rpc\('purchase_avatar_color',\{p_color_slot:'head',p_color:hex\}\)/);
// headColor must round-trip through normalizeAvatarData with a safe fallback
assert.match(indexHtml, /const headColor=\(avatarData&&\/\^#\[0-9a-fA-F\]\{6\}\$\/\.test\(avatarData\.headColor\)\)\?avatarData\.headColor:AVATAR_DEFAULT_HEAD_COLOR;/);

// teacher.html: roster/podium/Hall of Fame must render the student's chosen color too
assert.match(teacherHtml, /-webkit-mask-image:url\('\.\.\/\.\.\/media\/avatar_faceshapes\.png'\)/);
assert.match(teacherHtml, /function _tHeadLayerStyle\(/);
assert.match(teacherHtml, /_tHeadLayerStyle\(h\.col,h\.row,size,avatarData\.headColor\)/);
