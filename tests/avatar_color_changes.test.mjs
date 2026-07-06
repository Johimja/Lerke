import assert from 'node:assert/strict';
import { readFileSync, existsSync } from 'node:fs';
import { join } from 'node:path';

const root = new URL('..', import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, '$1');

function read(relPath) {
  return readFileSync(join(root, relPath), 'utf8');
}

const indexHtml   = read('index.html');
const teacherHtml = read('apps/bingo/teacher.html');
const patchSql    = read('supabase/sql/archive/Patches/supabase_bingo_v21_avatar_color_patch.sql');
const freshSql    = read('supabase/sql/supabase_bingo_fresh_install_v18.sql');

// ── SQL patch ────────────────────────────────────────────────
assert.ok(existsSync(join(root, 'supabase/sql/archive/Patches/supabase_bingo_v21_avatar_color_patch.sql')),
  'v21 color patch file must exist');

for (const [label, sql] of [['v21 patch', patchSql], ['fresh install', freshSql]]) {
  assert.match(sql, /purchase_avatar_color/, `${label} must define purchase_avatar_color`);
  assert.match(sql, /skinColor.*accColor|accColor.*skinColor|p_color_slot.*in.*skinColor/s,
    `${label} must validate skinColor and accColor slots`);
  assert.match(sql, /#\[0-9a-fA-F\]\{6\}|\^#\[0-9a-fA-F\]\{6\}\$/, `${label} must validate hex color`);
  assert.match(sql, /v_color_cost.*constant integer := 25|integer := 25/, `${label} must set 25 XP cost`);
  assert.match(sql, /grant execute on function public\.purchase_avatar_color/, `${label} must grant execute`);
}

// ── index.html ───────────────────────────────────────────────
assert.match(indexHtml, /normalizeAvatarData/, 'index.html must define normalizeAvatarData');
assert.match(indexHtml, /skinColor.*accColor|accColor.*skinColor/s,
  'normalizeAvatarData must handle skinColor and accColor');

// normalizeAvatarData must fall back to #ffffff for invalid hex
assert.match(indexHtml, /_hexRe/, 'index.html must define _hexRe for hex validation');
assert.match(indexHtml, /\^#\[0-9a-fA-F\]\{6\}\$/, 'index.html must include hex pattern');

// pendingAvatar default must include color slots
const pendingMatch = indexHtml.match(/let pendingAvatar=\{([^}]+)\}/);
assert.ok(pendingMatch, 'index.html must declare pendingAvatar');
assert.ok(pendingMatch[1].includes('skinColor'), 'pendingAvatar default must include skinColor');
assert.ok(pendingMatch[1].includes('accColor'),  'pendingAvatar default must include accColor');

// Mask-based CSS classes must exist
assert.match(indexHtml, /\.avatar-layer-c\{[^}]*mask-image/, 'index.html must define .avatar-layer-c with mask');
assert.match(indexHtml, /\.avatar-acc-layer-c\{[^}]*mask-image/, 'index.html must define .avatar-acc-layer-c with mask');

// _maskStyle helper
assert.match(indexHtml, /function _maskStyle\(/, 'index.html must define _maskStyle');
assert.match(indexHtml, /mask-size.*mask-position/s, 'index.html _maskStyle must set mask-size and mask-position');

// renderAvatarCircle must use the tinted layers
assert.match(indexHtml, /avatar-layer-c.*background-color/s, 'renderAvatarCircle must use avatar-layer-c with background-color');

// Farger tab must be in shop
assert.match(indexHtml, /setShopTab\('color'\).*Farger|Farger.*setShopTab\('color'\)/,
  'index.html shop must have a Farger tab');

// Color picker UI
assert.match(indexHtml, /type="color"/, 'index.html must include color pickers');
assert.match(indexHtml, /previewAvatarColor\(/, 'index.html must define previewAvatarColor');
assert.match(indexHtml, /saveAvatarColor\(/, 'index.html must define saveAvatarColor');
assert.match(indexHtml, /purchase_avatar_color/, 'index.html must call purchase_avatar_color RPC');

// ── teacher.html ─────────────────────────────────────────────
assert.match(teacherHtml, /\.t-avatar-layer-c\{[^}]*mask-image/,
  'teacher.html must define .t-avatar-layer-c with mask');
assert.match(teacherHtml, /\.t-avatar-acc-layer-c\{[^}]*mask-image/,
  'teacher.html must define .t-avatar-acc-layer-c with mask');
assert.match(teacherHtml, /function _tMaskStyle\(/, 'teacher.html must define _tMaskStyle');
assert.match(teacherHtml, /t-avatar-layer-c.*background-color/s,
  'renderAvatarCircleT must use t-avatar-layer-c with background-color');
assert.match(teacherHtml, /skinColor.*accColor|accColor.*skinColor/s,
  'teacher.html renderAvatarCircleT must read skinColor and accColor');

console.log('avatar_color_changes: all assertions passed');
