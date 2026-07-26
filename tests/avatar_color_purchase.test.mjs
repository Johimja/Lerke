import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';

const root = new URL('..', import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, '$1');
function read(relPath) { return readFileSync(join(root, relPath), 'utf8'); }

const indexHtml    = read('index.html');
const teacherHtml  = read('apps/bingo/teacher.html');
const patchSql     = read('supabase/sql/archive/Patches/supabase_bingo_v21_avatar_color_patch.sql');
const freshSql     = read('supabase/sql/supabase_bingo_fresh_install_v18.sql');

// ── SQL: purchase_avatar_color exists ────────────────────
assert.match(patchSql,  /create or replace function.*purchase_avatar_color/si, 'patch must define purchase_avatar_color');
assert.match(freshSql,  /purchase_avatar_color/i, 'fresh install must include purchase_avatar_color');

// ── SQL: valid slot and hex validation ────────────────────
assert.match(patchSql, /skinColor/, 'patch must list skinColor as valid slot');
assert.match(patchSql, /#\[0-9a-fA-F\]\{6\}/, 'patch must validate hex color format');

// ── SQL: cost is 25 XP ───────────────────────────────────
assert.match(patchSql, /v_cost\s+int\s*:=\s*25/, 'patch must charge 25 XP');

// ── SQL: merges into avatar_data ─────────────────────────
assert.match(patchSql, /avatar_data\s*=\s*v_new_avatar/, 'patch must update avatar_data column');

// ── index.html: pendingAvatar includes skinColor ─────────
assert.match(indexHtml, /pendingAvatar=\{head:'head_basic',acc:'acc_none',skinColor:'#[0-9a-fA-F]{6}'/, 'pendingAvatar must include skinColor default');

// ── index.html: normalizeAvatarData handles skinColor ────
assert.match(indexHtml, /normalizeAvatarData[\s\S]{0,300}skinColor/, 'normalizeAvatarData must handle skinColor');

// ── index.html: COLOR_SWATCHES defined ───────────────────
assert.match(indexHtml, /const COLOR_SWATCHES=\[/, 'index.html must define COLOR_SWATCHES');

// ── index.html: purchaseAvatarColor function ─────────────
assert.match(indexHtml, /async function purchaseAvatarColor/, 'index.html must define purchaseAvatarColor');
assert.match(indexHtml, /purchase_avatar_color/, 'index.html must call purchase_avatar_color RPC');

// ── index.html: color tab in shop ────────────────────────
assert.match(indexHtml, /setShopTab\('color'\)/, 'avatar shop must have a color tab');

// ── index.html: CSS mask approach for face shape layer ───
assert.match(indexHtml, /mask-image:url\('media\/avatar_faceshapes\.png'\)/, 'avatar-layer CSS must use mask-image for avatar_faceshapes');

// ── index.html: _maskStyle helper defined ────────────────
assert.match(indexHtml, /function _maskStyle\(/, 'index.html must define _maskStyle helper');

// ── teacher.html: skinColor applied ──────────────────────
assert.match(teacherHtml, /skinColor/, 'teacher.html renderAvatarCircleT must read skinColor');

// ── teacher.html: CSS mask for t-avatar-layer ────────────
assert.match(teacherHtml, /mask-image:url\('\.\.\/\.\.\/media\/avatar_faceshapes\.png'\)/, 't-avatar-layer must use mask-image');

// ── teacher.html: _tMaskStyle helper defined ─────────────
assert.match(teacherHtml, /function _tMaskStyle\(/, 'teacher.html must define _tMaskStyle helper');

console.log('avatar_color_purchase: all assertions passed ✓');
