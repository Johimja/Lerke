import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';

const root = new URL('..', import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, '$1');
function read(p) { return readFileSync(join(root, p), 'utf8'); }

const indexHtml       = read('index.html');
const teacherHtml     = read('apps/bingo/teacher.html');
const patchSql        = read('supabase/sql/archive/Patches/supabase_bingo_v21_avatar_color_patch.sql');
const freshInstallSql = read('supabase/sql/supabase_bingo_fresh_install_v18.sql');

// ── SQL patch guards ─────────────────────────────────────
assert.match(patchSql, /purchase_avatar_color/, 'patch must define purchase_avatar_color');
assert.match(patchSql, /skinColor/, 'patch must allow skinColor slot');
assert.match(patchSql, /v_cost\s+constant integer := 25/, 'color-change cost must be 25 XP');
assert.match(patchSql, /#\[0-9a-fA-F\]\{6\}/, 'patch must validate hex-6 color format');
assert.match(patchSql, /grant execute on function public\.purchase_avatar_color/, 'must grant execute on RPC');

// fresh install must also include the RPC
assert.match(freshInstallSql, /purchase_avatar_color/, 'fresh install must include purchase_avatar_color');

// ── index.html guards ───────────────────────────────────
// Color palette defined
assert.match(indexHtml, /AVATAR_COLOR_PALETTE/, 'index.html must define AVATAR_COLOR_PALETTE');
// White is free entry
assert.match(indexHtml, /'#ffffff'.*free:true/, 'white must be marked free in palette');
// pendingAvatar includes skinColor
assert.match(indexHtml, /pendingAvatar=\{head:'head_basic',acc:'acc_none',skinColor:'#ffffff'\}/, 'pendingAvatar must default to skinColor:#ffffff');
// normalizeAvatarData returns skinColor
assert.match(indexHtml, /const skinColor=\(avatarData&&avatarData\.skinColor/, 'normalizeAvatarData must extract skinColor');
// _tintedLayerStyle helper exists
assert.match(indexHtml, /function _tintedLayerStyle/, 'index.html must define _tintedLayerStyle');
// renderAvatarCircle uses tinted layer
assert.match(indexHtml, /avatar-tinted-layer/, 'renderAvatarCircle must use avatar-tinted-layer');
// CSS mask defined
assert.match(indexHtml, /mask-image:url\('media\/avatar_faceshapes\.png'\)/, 'must define CSS mask for faceshapes');
// Farge tab in shop
assert.match(indexHtml, /setShopTab\('color'\).*Farge/, 'avatar shop must have Farge tab');
// purchase_avatar_color called
assert.match(indexHtml, /purchase_avatar_color/, 'index.html must call purchase_avatar_color RPC');
// hslToHex helper
assert.match(indexHtml, /function hslToHex/, 'index.html must define hslToHex');
// COLOR_COST = 25
assert.match(indexHtml, /COLOR_COST=25/, 'COLOR_COST must be 25');

// ── teacher.html guards ─────────────────────────────────
assert.match(teacherHtml, /t-avatar-tinted-layer/, 'teacher.html must use t-avatar-tinted-layer CSS');
assert.match(teacherHtml, /mask-image:url\('\.\.\/\.\.\/media\/avatar_faceshapes\.png'\)/, 'teacher.html must define CSS mask');
assert.match(teacherHtml, /avatarData\.skinColor/, 'renderAvatarCircleT must read skinColor from avatarData');

console.log('avatar_color_changes: all assertions passed ✓');
