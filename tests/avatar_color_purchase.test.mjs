import assert from 'node:assert/strict';
import { readFileSync, existsSync } from 'node:fs';
import { join } from 'node:path';

const root = new URL('..', import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, '$1');
function read(p) { return readFileSync(join(root, p), 'utf8'); }

const indexHtml   = read('index.html');
const teacherHtml = read('apps/bingo/teacher.html');
const patchSql    = read('supabase/sql/archive/Patches/supabase_bingo_v21_avatar_color_patch.sql');

// ── SQL patch guards ────────────────────────────────────────────────────────

assert.match(patchSql, /purchase_avatar_color/, 'SQL must define purchase_avatar_color');
assert.match(patchSql, /p_color_slot.*text/, 'SQL must accept p_color_slot');
assert.match(patchSql, /p_color.*text/, 'SQL must accept p_color');
assert.match(patchSql, /skinColor/, 'SQL must accept skinColor slot');
assert.match(patchSql, /Ikke nok XP/, 'SQL must return Norwegian XP error');
assert.match(patchSql, /xp_spent/, 'SQL must return xp_spent in result');
// same-color guard: server skips charge when color unchanged
assert.match(patchSql, /xp_spent.*0/, 'SQL must return xp_spent:0 for no-op same-color case');

// ── index.html guards ───────────────────────────────────────────────────────

// pendingAvatar must include skinColor default
assert.match(indexHtml, /pendingAvatar=\{head:'head_basic',acc:'acc_none',skinColor:'#f5b88a'\}/,
  'pendingAvatar default must include skinColor');

// normalizeAvatarData must return skinColor
assert.match(indexHtml, /const skinColor=.*avatarData.*skinColor.*\|\|.*'#f5b88a'/,
  'normalizeAvatarData must extract skinColor with fallback');

// CSS mask approach for face layer (not background-image)
assert.match(indexHtml, /\.avatar-layer\{[^}]*mask-repeat:no-repeat/,
  '.avatar-layer must use mask-repeat (mask-based approach)');
assert.ok(!indexHtml.match(/\.avatar-layer\{[^}]*background-image:url\('media\/avatar_faceshapes/),
  '.avatar-layer must NOT hardcode background-image for faceshapes (uses mask now)');

// _maskStyle function must exist
assert.match(indexHtml, /function _maskStyle\(/, '_maskStyle function must be defined');
assert.match(indexHtml, /mask-image:url\('media\/avatar_faceshapes/, '_maskStyle must reference faceshapes sheet');

// renderAvatarCircle must use _maskStyle and skinColor
assert.match(indexHtml, /_maskStyle\(h\.col,h\.row,size\).*skinColor/s,
  'renderAvatarCircle must pass mask style and skinColor to head layer');

// renderSingleSprite must use _maskStyle
assert.match(indexHtml, /renderSingleSprite[\s\S]{0,300}_maskStyle/,
  'renderSingleSprite must use _maskStyle');

// COLOR_CHANGE_COST must be 25
assert.match(indexHtml, /COLOR_CHANGE_COST=25/, 'COLOR_CHANGE_COST must be 25');

// Color tab in shop
assert.match(indexHtml, /setShopTab\('color'\).*Farge/, 'shop must have Farge tab');
assert.match(indexHtml, /renderAvatarColorTab/, 'renderAvatarColorTab must be defined');
assert.match(indexHtml, /previewAvatarColor/, 'previewAvatarColor must be defined');
assert.match(indexHtml, /purchaseAvatarColor/, 'purchaseAvatarColor must be defined');
assert.match(indexHtml, /purchase_avatar_color/, 'index.html must call purchase_avatar_color RPC');

// previewSkinColor must not leak into pendingAvatar before purchase
assert.match(indexHtml, /previewSkinColor=null/, 'previewSkinColor reset to null must exist');

// Color presets defined
assert.match(indexHtml, /COLOR_PRESETS=\[/, 'COLOR_PRESETS array must be defined');

// ── teacher.html guards ─────────────────────────────────────────────────────

// CSS mask approach for teacher face layer
assert.match(teacherHtml, /\.t-avatar-layer\{[^}]*mask-repeat:no-repeat/,
  '.t-avatar-layer must use mask-repeat');
assert.ok(!teacherHtml.match(/\.t-avatar-layer\{[^}]*background-image:url\('.*avatar_faceshapes/),
  '.t-avatar-layer must NOT hardcode background-image for faceshapes');

// _tMaskStyle helper
assert.match(teacherHtml, /function _tMaskStyle\(/, '_tMaskStyle must be defined in teacher.html');
assert.match(teacherHtml, /mask-image:url\('.*media\/avatar_faceshapes/, '_tMaskStyle must reference faceshapes sheet');

// renderAvatarCircleT uses skinColor
assert.match(teacherHtml, /skinColor.*avatarData\.skinColor.*\|\|.*'#f5b88a'/,
  'renderAvatarCircleT must read skinColor with fallback');
assert.match(teacherHtml, /_tMaskStyle\(h\.col,h\.row,size\).*skinColor/s,
  'renderAvatarCircleT must use _tMaskStyle with skinColor');

console.log('avatar_color_purchase: all assertions passed');
