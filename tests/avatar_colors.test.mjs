import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';

const root = new URL('..', import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, '$1');

function read(relPath) {
  return readFileSync(join(root, relPath), 'utf8');
}

const indexHtml = read('index.html');
const teacherHtml = read('apps/bingo/teacher.html');
const patchSql = read('supabase/sql/archive/Patches/supabase_bingo_v21_avatar_colors_patch.sql');
const freshInstallSql = read('supabase/sql/supabase_bingo_fresh_install_v18.sql');

for (const [name, sql] of [
  ['supabase_bingo_v21_avatar_colors_patch.sql', patchSql],
  ['supabase_bingo_fresh_install_v18.sql', freshInstallSql],
]) {
  assert.match(sql, /create or replace function public\.purchase_avatar_color\(p_color_slot text, p_color text\)/, `${name} must define purchase_avatar_color`);
  assert.match(sql, /v_cost\s+constant int := 25;/, `${name} must charge a fixed 25 XP color cost`);
  assert.match(sql, /p_color !~ '\^#\[0-9a-fA-F\]\{6\}\$'/, `${name} must validate hex color format`);
  assert.match(sql, /grant execute on function public\.purchase_avatar_color\(text, text\) to authenticated, anon;/, `${name} must grant execute on purchase_avatar_color`);
}

// Frontend must render avatar layers as CSS masks (so a background-color can tint the white silhouette)
assert.match(indexHtml, /\.avatar-layer\{[^}]*mask-image:url\('media\/avatar_faceshapes\.png'\)/, 'index.html avatar-layer must use mask-image for recoloring');
assert.match(indexHtml, /\.avatar-acc-layer\{[^}]*mask-image:url\('media\/avatar_head_accessories\.png'\)/, 'index.html avatar-acc-layer must use mask-image for recoloring');
assert.match(teacherHtml, /\.t-avatar-layer\{[^}]*mask-image:url\('\.\.\/\.\.\/media\/avatar_faceshapes\.png'\)/, 'teacher.html t-avatar-layer must use mask-image for recoloring');
assert.match(teacherHtml, /\.t-avatar-acc-layer\{[^}]*mask-image:url\('\.\.\/\.\.\/media\/avatar_head_accessories\.png'\)/, 'teacher.html t-avatar-acc-layer must use mask-image for recoloring');

// index.html must wire up the color picker UI and purchase flow
assert.match(indexHtml, /function purchaseAvatarColor\(\)/, 'index.html must define purchaseAvatarColor');
assert.match(indexHtml, /supabaseClient\.rpc\('purchase_avatar_color',\{p_color_slot:slot,p_color:color\}\)/, 'index.html must call purchase_avatar_color RPC');
assert.match(indexHtml, /const AVATAR_COLOR_COST=25;/, 'index.html color cost must match server cost');
assert.match(indexHtml, /function normalizeAvatarData\(avatarData\)\{[\s\S]*?headColor[\s\S]*?accColor[\s\S]*?\}/, 'normalizeAvatarData must normalize headColor/accColor');

console.log('avatar_colors.test.mjs passed');
