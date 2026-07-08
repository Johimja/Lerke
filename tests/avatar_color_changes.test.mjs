import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';

const root = new URL('..', import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, '$1');

function read(relPath) {
  return readFileSync(join(root, relPath), 'utf8');
}

const indexHtml    = read('index.html');
const teacherHtml  = read('apps/bingo/teacher.html');
const patchSql     = read('supabase/sql/archive/Patches/supabase_bingo_v21_avatar_color_patch.sql');
const freshSql     = read('supabase/sql/supabase_bingo_fresh_install_v18.sql');

// ── SQL: purchase_avatar_color function present and correct ──────────────────

for (const [name, sql] of [['patch', patchSql], ['fresh_install', freshSql]]) {
  assert.match(sql, /create or replace function public\.purchase_avatar_color/,
    `${name}: purchase_avatar_color must be defined`);
  assert.match(sql, /p_color_slot.*not in.*'skinColor'/,
    `${name}: must validate color slot`);
  assert.match(sql, /p_color.*!~.*#\[0-9a-fA-F\]\{6\}/,
    `${name}: must validate hex color format`);
  assert.match(sql, /v_cost\s+integer\s*:=\s*25/,
    `${name}: cost must be 25 XP`);
  assert.match(sql, /lower\(p_color\)\s*=\s*'#ffffff'/,
    `${name}: white must be free`);
  assert.match(sql, /p_color is null/,
    `${name}: null (reset) must be free`);
  assert.match(sql, /total_xp\s*-\s*v_cost/,
    `${name}: must deduct XP`);
  assert.match(sql, /grant execute on function public\.purchase_avatar_color/,
    `${name}: must grant execute`);
}

// ── index.html: SKIN_COLOR_PALETTE ──────────────────────────────────────────

const paletteMatch = indexHtml.match(/const SKIN_COLOR_PALETTE=\[([\s\S]*?)\];/);
assert.ok(paletteMatch, 'index.html must define SKIN_COLOR_PALETTE');

const paletteSrc = paletteMatch[1];
const colorEntries = [...paletteSrc.matchAll(/\{color:(null|'#[0-9a-fA-F]{6}')[^}]*xp:(\d+)/g)];
assert.ok(colorEntries.length >= 16, `palette must have at least 16 entries, got ${colorEntries.length}`);

// white/null entry must be free (xp:0)
const freeEntry = colorEntries.find(m => m[1] === 'null');
assert.ok(freeEntry, 'palette must include null (white/reset) entry');
assert.equal(Number(freeEntry[2]), 0, 'null/white entry must have xp:0');

// all non-null colors must be valid hex and cost 25 XP
for (const [, colorVal, xpVal] of colorEntries) {
  if (colorVal === 'null') continue;
  assert.match(colorVal, /^'#[0-9a-fA-F]{6}'$/, `palette color ${colorVal} must be valid hex`);
  assert.equal(Number(xpVal), 25, `palette color ${colorVal} must cost 25 XP`);
}

// ── index.html: CSS mask approach for .avatar-layer ─────────────────────────

assert.match(indexHtml, /\.avatar-layer\{[^}]*mask-image:url\('media\/avatar_faceshapes\.png'\)/,
  'index.html: .avatar-layer must use mask-image for avatar_faceshapes.png');
assert.match(indexHtml, /\.avatar-layer\{[^}]*background-color:var\(--avatar-skin-color/,
  'index.html: .avatar-layer must use --avatar-skin-color CSS variable');
assert.ok(!indexHtml.includes(".avatar-layer{position:absolute;top:0;left:0;width:100%;height:100%;background-image:url('media/avatar_faceshapes.png')"),
  'index.html: .avatar-layer must NOT use background-image for faceshapes (use mask instead)');

// ── index.html: _spriteMaskStyle function ───────────────────────────────────

assert.match(indexHtml, /function _spriteMaskStyle\(col,row,size\)/,
  'index.html must define _spriteMaskStyle');
assert.match(indexHtml, /mask-size/,
  'index.html _spriteMaskStyle must output mask-size');
assert.match(indexHtml, /mask-position/,
  'index.html _spriteMaskStyle must output mask-position');

// ── index.html: normalizeAvatarData includes skinColor ──────────────────────

assert.match(indexHtml, /normalizeAvatarData[\s\S]{0,400}skinColor/,
  'index.html normalizeAvatarData must handle skinColor');

// ── index.html: renderAvatarCircle applies skinColor ────────────────────────

assert.match(indexHtml, /skinStyle.*skinColor.*avatar-skin-color/,
  'index.html renderAvatarCircle must apply --avatar-skin-color when skinColor set');

// ── index.html: purchaseAvatarColor function ────────────────────────────────

assert.match(indexHtml, /async function purchaseAvatarColor\(color\)/,
  'index.html must define purchaseAvatarColor');
assert.match(indexHtml, /purchase_avatar_color.*p_color_slot.*skinColor/,
  'index.html purchaseAvatarColor must call purchase_avatar_color RPC');

// ── index.html: Farge shop tab ───────────────────────────────────────────────

assert.match(indexHtml, /setShopTab\('farge'\)/,
  'index.html shop must include a Farge tab');
assert.match(indexHtml, /renderColorSection/,
  'index.html must define renderColorSection');

// ── teacher.html: CSS mask for .t-avatar-layer ───────────────────────────────

assert.match(teacherHtml, /\.t-avatar-layer\{[^}]*mask-image:url\('\.\.\/\.\.\/media\/avatar_faceshapes\.png'\)/,
  'teacher.html: .t-avatar-layer must use mask-image');
assert.match(teacherHtml, /\.t-avatar-layer\{[^}]*background-color:var\(--avatar-skin-color/,
  'teacher.html: .t-avatar-layer must use --avatar-skin-color CSS variable');

// ── teacher.html: _tFaceMaskStyle and renderAvatarCircleT ────────────────────

assert.match(teacherHtml, /function _tFaceMaskStyle\(/,
  'teacher.html must define _tFaceMaskStyle');
assert.match(teacherHtml, /skinColor.*avatar-skin-color/,
  'teacher.html renderAvatarCircleT must apply skin color');

console.log('✓ avatar_color_changes: all assertions passed');
