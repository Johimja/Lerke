import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';

const root = new URL('..', import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, '$1');

function read(relPath) {
  return readFileSync(join(root, relPath), 'utf8');
}

const indexHtml      = read('index.html');
const teacherHtml    = read('apps/bingo/teacher.html');
const patchSql       = read('supabase/sql/archive/Patches/supabase_bingo_v21_avatar_color_patch.sql');
const freshInstallSql= read('supabase/sql/supabase_bingo_fresh_install_v18.sql');

// SQL patch defines the RPC with correct cost and validation
assert.match(patchSql, /create or replace function public\.purchase_avatar_color/, 'patch must define purchase_avatar_color');
assert.match(patchSql, /'headColor'/, 'patch must accept headColor slot');
assert.match(patchSql, /'accColor'/, 'patch must accept accColor slot');
assert.match(patchSql, /\^\#\[0-9a-fA-F\]\{6\}\$/, 'patch must validate 6-digit hex color');
assert.match(patchSql, /v_cost constant integer := 25/, 'color change cost must be 25 XP');
assert.match(patchSql, /grant execute on function public\.purchase_avatar_color/, 'grant must exist in patch');

// Fresh install includes the color RPC
assert.match(freshInstallSql, /purchase_avatar_color/, 'fresh install must include purchase_avatar_color');
assert.match(freshInstallSql, /grant execute on function public\.purchase_avatar_color/, 'fresh install must grant purchase_avatar_color');

// index.html uses mask-image (not background-image) for both avatar layers
assert.match(indexHtml, /mask-image:url\('media\/avatar_faceshapes\.png'\)/, 'index.html must use mask-image for face shapes');
assert.match(indexHtml, /mask-image:url\('media\/avatar_head_accessories\.png'\)/, 'index.html must use mask-image for accessories');
assert.ok(!indexHtml.includes("background-image:url('media/avatar_faceshapes.png')"), 'index.html must not use background-image for faceshapes');
assert.ok(!indexHtml.includes("background-image:url('media/avatar_head_accessories.png')"), 'index.html must not use background-image for accessories');

// _spriteStyle accepts and outputs a color
assert.match(indexHtml, /function _spriteStyle\(col,row,size,color\)/, '_spriteStyle must accept color parameter');
assert.match(indexHtml, /background-color:\$\{color\|/, '_spriteStyle must output background-color');

// normalizeAvatarData includes headColor and accColor
assert.match(indexHtml, /const headColor=\(avatarData&&avatarData\.headColor\)\|\|'#e8c99a'/, 'normalizeAvatarData must include headColor default');
assert.match(indexHtml, /const accColor=\(avatarData&&avatarData\.accColor\)\|\|'#c8a86e'/, 'normalizeAvatarData must include accColor default');

// pendingAvatar default includes colors
assert.match(indexHtml, /let pendingAvatar=\{head:'head_basic',acc:'acc_none',headColor:'#e8c99a',accColor:'#c8a86e'\}/, 'pendingAvatar must include color defaults');

// index.html has Farger tab and color functions
assert.match(indexHtml, /setShopTab\('color'\)/, 'index.html must have color shop tab button');
assert.match(indexHtml, /function renderColorTab\(xp\)/, 'index.html must have renderColorTab function');
assert.match(indexHtml, /function previewAvatarColor\(slot,color\)/, 'index.html must have previewAvatarColor function');
assert.match(indexHtml, /async function purchaseColorChange\(slot\)/, 'index.html must have purchaseColorChange function');
assert.match(indexHtml, /purchase_avatar_color/, 'index.html must call purchase_avatar_color RPC');

// teacher.html uses mask-image for both layers
assert.match(teacherHtml, /mask-image:url\('\.\.\/\.\.\/media\/avatar_faceshapes\.png'\)/, 'teacher.html must use mask-image for face shapes');
assert.match(teacherHtml, /mask-image:url\('\.\.\/\.\.\/media\/avatar_head_accessories\.png'\)/, 'teacher.html must use mask-image for accessories');
assert.ok(!teacherHtml.includes("background-image:url('../../media/avatar_faceshapes.png')"), 'teacher.html must not use background-image for faceshapes');

// _tSpriteStyle accepts and outputs color
assert.match(teacherHtml, /function _tSpriteStyle\(col,row,size,color\)/, '_tSpriteStyle must accept color parameter');
assert.match(teacherHtml, /background-color:\$\{color\|/, '_tSpriteStyle must output background-color');

// renderAvatarCircleT reads headColor and accColor from avatarData
assert.match(teacherHtml, /headColor=\(avatarData&&avatarData\.headColor\)\|\|'#e8c99a'/, 'renderAvatarCircleT must read headColor');
assert.match(teacherHtml, /accColor=\(avatarData&&avatarData\.accColor\)\|\|'#c8a86e'/, 'renderAvatarCircleT must read accColor');

console.log('All Avatar-9 paid color change tests passed ✓');
