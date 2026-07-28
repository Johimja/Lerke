import assert from 'node:assert/strict';
import { readFileSync, existsSync } from 'node:fs';
import { join } from 'node:path';

const root = new URL('..', import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, '$1');

function read(relPath) {
  return readFileSync(join(root, relPath), 'utf8');
}

const indexHtml = read('index.html');
const teacherHtml = read('apps/bingo/teacher.html');
const patchSql = read('supabase/sql/archive/Patches/supabase_bingo_v21_avatar_colors_patch.sql');
const freshInstallSql = read('supabase/sql/supabase_bingo_fresh_install_v18.sql');

// SQL: purchase_avatar_color RPC must exist in both files
for (const [name, sql] of [['v21 patch', patchSql], ['fresh install', freshInstallSql]]) {
  assert.ok(sql.includes('purchase_avatar_color'), `${name} must define purchase_avatar_color`);
  assert.ok(sql.includes("p_color_slot not in ('skinColor','propColor')"), `${name} must validate slot`);
  assert.ok(sql.includes("p_color !~ '^#([0-9a-fA-F]{3}|[0-9a-fA-F]{6})$'"), `${name} must validate hex color`);
  assert.ok(sql.includes('v_cost    int := 25'), `${name} must set cost to 25 XP`);
  assert.ok(sql.includes("grant execute on function public.purchase_avatar_color"), `${name} must grant execute`);
}

// index.html: constants and color support
assert.ok(indexHtml.includes("const DEFAULT_SKIN='#d4956a'"), 'index.html must define DEFAULT_SKIN');
assert.ok(indexHtml.includes("const DEFAULT_PROP='#ffffff'"), 'index.html must define DEFAULT_PROP');
assert.ok(indexHtml.includes('const COLOR_RE='), 'index.html must define COLOR_RE regex');
assert.ok(indexHtml.includes('_layerColorStyle'), 'index.html must define _layerColorStyle');
assert.ok(indexHtml.includes('mask-image'), 'index.html _layerColorStyle must use CSS mask-image');

// normalizeAvatarData returns skinColor and propColor
assert.ok(indexHtml.includes('skinColor'), 'normalizeAvatarData must handle skinColor');
assert.ok(indexHtml.includes('propColor'), 'normalizeAvatarData must handle propColor');

// renderAvatarCircle uses the colored layer
assert.ok(indexHtml.includes("class=\"avatar-layer-c\""), 'renderAvatarCircle must use avatar-layer-c');
assert.ok(!indexHtml.match(/renderAvatarCircle[\s\S]{0,300}avatar-acc-layer/), 'renderAvatarCircle must not use old avatar-acc-layer class');

// Color shop tab
assert.ok(indexHtml.includes("setShopTab('color')"), 'shop must have a color tab');
assert.ok(indexHtml.includes('renderColorShopBody'), 'shop must render color body');
assert.ok(indexHtml.includes('purchaseAvatarColor'), 'index.html must define purchaseAvatarColor');

// Swatch presets: verify valid hex format
const swatchMatch = indexHtml.match(/const SKIN=\[(.*?)\]/);
assert.ok(swatchMatch, 'index.html must define SKIN swatches array');
const skinSwatches = swatchMatch[1].match(/'(#[^']+)'/g).map(s => s.replace(/'/g,''));
for (const c of skinSwatches) {
  assert.match(c, /^#[0-9a-fA-F]{3}([0-9a-fA-F]{3})?$/, `SKIN swatch ${c} must be valid hex`);
}

const propMatch = indexHtml.match(/const PROP=\[(.*?)\]/);
assert.ok(propMatch, 'index.html must define PROP swatches array');
const propSwatches = propMatch[1].match(/'(#[^']+)'/g).map(s => s.replace(/'/g,''));
for (const c of propSwatches) {
  assert.match(c, /^#[0-9a-fA-F]{3}([0-9a-fA-F]{3})?$/, `PROP swatch ${c} must be valid hex`);
}

// RPC call name must match SQL function name exactly
assert.ok(indexHtml.includes("'purchase_avatar_color'"), 'index.html must call purchase_avatar_color RPC by exact name');

// teacher.html: color rendering
assert.ok(teacherHtml.includes('_tLayerColorStyle'), 'teacher.html must define _tLayerColorStyle');
assert.ok(teacherHtml.includes("T_DEFAULT_SKIN='#d4956a'"), 'teacher.html must define T_DEFAULT_SKIN');
assert.ok(teacherHtml.includes("class=\"t-avatar-layer-c\""), 'renderAvatarCircleT must use t-avatar-layer-c');
assert.ok(teacherHtml.includes('mask-image'), 'teacher.html must use CSS mask-image for colored layers');

console.log('avatar_colors: all assertions passed ✓');
