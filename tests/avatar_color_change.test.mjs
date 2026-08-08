import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';

const root = new URL('..', import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, '$1');

function read(relPath) {
  return readFileSync(join(root, relPath), 'utf8');
}

const indexHtml = read('index.html');
const patchSql = read('supabase/sql/archive/Patches/supabase_bingo_v21_avatar_color_change.sql');
const freshInstallSql = read('supabase/sql/supabase_bingo_fresh_install_v18.sql');

// ── SQL patch guards ──────────────────────────────────────────────────
for (const [name, sql] of [
  ['v21 patch', patchSql],
  ['fresh install', freshInstallSql],
]) {
  assert.match(sql, /create or replace function public\.purchase_avatar_color/, `${name} must define purchase_avatar_color`);
  assert.match(sql, /'\^#\[0-9a-fA-F\]\{6\}\$'/, `${name} must validate hex color format`);
  assert.match(sql, /v_cost\s+int\s*:=\s*25/, `${name} must set color change cost to 25 XP`);
  assert.match(sql, /grant execute on function public\.purchase_avatar_color/, `${name} must grant execute on purchase_avatar_color`);
}

// ── index.html: color tab present ────────────────────────────────────
assert.match(indexHtml, /setShopTab\('farge'\)/, 'index.html must have Farge shop tab');
assert.match(indexHtml, />Farge</, 'index.html must label the Farge tab');

// ── index.html: purchaseColorChange function exists ───────────────────
assert.match(indexHtml, /async function purchaseColorChange\(\)/, 'index.html must define purchaseColorChange');
assert.match(indexHtml, /purchase_avatar_color/, 'index.html must call purchase_avatar_color RPC');

// ── index.html: previewAvatarColor and removeAvatarColor ─────────────
assert.match(indexHtml, /function previewAvatarColor\(/, 'index.html must define previewAvatarColor');
assert.match(indexHtml, /async function removeAvatarColor\(/, 'index.html must define removeAvatarColor');

// ── index.html: color field in pendingAvatar default ─────────────────
assert.match(indexHtml, /pendingAvatar=\{head:'head_basic',acc:'acc_none',color:null\}/, 'pendingAvatar must include color:null');

// ── index.html: normalizeAvatarData handles color ────────────────────
assert.match(indexHtml, /rawColor.*avatarData.*color/, 'normalizeAvatarData must handle color field');
assert.match(indexHtml, /\^#\[0-9a-fA-F\]\{6\}\$/, 'normalizeAvatarData must validate color hex');

// ── index.html: CSS mask layer for colored silhouette ────────────────
assert.match(indexHtml, /avatar-color-layer/, 'index.html must define .avatar-color-layer CSS class');
assert.match(indexHtml, /_colorMaskStyle/, 'index.html must define _colorMaskStyle helper');
assert.match(indexHtml, /mask-image/, 'index.html must use CSS mask-image for color layer');

// ── index.html: color removed for free ───────────────────────────────
assert.match(indexHtml, /removeAvatarColor/, 'color removal must be wired up in the UI');
assert.match(indexHtml, /Fjern farge \(gratis\)/, 'index.html must label color removal as free');

console.log('avatar_color_change: all assertions passed ✅');
