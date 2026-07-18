import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';

const root = new URL('..', import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, '$1');
function read(p) { return readFileSync(join(root, p), 'utf8'); }

const indexHtml = read('index.html');
const teacherHtml = read('apps/bingo/teacher.html');
const patchSql = read('supabase/sql/archive/Patches/supabase_bingo_v21_avatar_color_patch.sql');
const freshSql = read('supabase/sql/supabase_bingo_fresh_install_v18.sql');

// ── index.html ───────────────────────────────────────────────
// COLOR_PALETTE exists with at least 12 entries
const paletteMatch = indexHtml.match(/const COLOR_PALETTE=\[([\s\S]*?)\];/);
assert.ok(paletteMatch, 'index.html must define COLOR_PALETTE');
const paletteEntries = (paletteMatch[1].match(/hex:/g) || []).length;
assert.ok(paletteEntries >= 12, `COLOR_PALETTE must have ≥12 colors, got ${paletteEntries}`);

// #ffffff (white) must be in the palette as the free/default
assert.ok(paletteMatch[1].includes("'#ffffff'"), 'COLOR_PALETTE must include #ffffff (free default)');

// pendingAvatar default includes silhouetteColor
assert.match(indexHtml, /let pendingAvatar=\{[^}]*silhouetteColor/, 'pendingAvatar default must include silhouetteColor');

// normalizeAvatarData returns silhouetteColor
assert.match(indexHtml, /normalizeAvatarData[\s\S]{0,300}silhouetteColor/, 'normalizeAvatarData must handle silhouetteColor');

// _maskSpriteStyle helper exists
assert.match(indexHtml, /function _maskSpriteStyle/, 'index.html must define _maskSpriteStyle');
assert.match(indexHtml, /mask-image/, 'index.html must use CSS mask-image for face shape layer');

// .avatar-layer now uses mask-image (not background-image for faceshapes)
assert.match(indexHtml, /\.avatar-layer\{[^}]*mask-image:url\('media\/avatar_faceshapes\.png'\)/, '.avatar-layer must use mask-image');
assert.ok(!indexHtml.match(/\.avatar-layer\{[^}]*background-image:url\('media\/avatar_faceshapes\.png'\)/), '.avatar-layer must NOT use background-image for faceshapes');

// pickAvatarColor function exists
assert.match(indexHtml, /async function pickAvatarColor/, 'index.html must define pickAvatarColor');
assert.match(indexHtml, /purchase_avatar_color/, 'pickAvatarColor must call purchase_avatar_color RPC');

// Color tab in shop
assert.match(indexHtml, /setShopTab\('color'\)/, 'avatar shop must have a Farger/color tab');

// ── teacher.html ─────────────────────────────────────────────
// t-avatar-mask-layer CSS class
assert.match(teacherHtml, /\.t-avatar-mask-layer\{[^}]*mask-image/, 'teacher.html must define .t-avatar-mask-layer with mask-image');

// _tMaskSpriteStyle helper
assert.match(teacherHtml, /function _tMaskSpriteStyle/, 'teacher.html must define _tMaskSpriteStyle');

// renderAvatarCircleT uses t-avatar-mask-layer
assert.match(teacherHtml, /t-avatar-mask-layer/, 'renderAvatarCircleT must use t-avatar-mask-layer');

// teacher reads silhouetteColor from avatarData
assert.match(teacherHtml, /silhouetteColor/, 'teacher.html must read silhouetteColor from avatarData');

// ── SQL ──────────────────────────────────────────────────────
for (const [label, sql] of [['patch', patchSql], ['fresh_install', freshSql]]) {
  assert.match(sql, /purchase_avatar_color/, `${label} must define purchase_avatar_color`);
  assert.match(sql, /'silhouetteColor'/, `${label} must validate silhouetteColor slot`);
  assert.match(sql, /#ffffff/, `${label} must treat #ffffff as free`);
  assert.match(sql, /v_cost\s+integer\s*:=\s*25/, `${label} must set color cost to 25 XP`);
  assert.match(sql, /grant execute on function public\.purchase_avatar_color/, `${label} must grant execute on purchase_avatar_color`);
}

console.log('avatar_color_changes: all assertions passed ✓');
