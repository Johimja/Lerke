// Avatar-9: paid color changes — tests
// Guards COLOR_PRESETS in index.html, the Farger tab, pickColor wiring,
// and the SQL patch for purchase_avatar_color.

import {readFileSync} from 'fs';
import path from 'path';

const root = path.resolve(import.meta.dirname,'..') ;
const indexHtml = readFileSync(path.join(root,'index.html'),'utf8');
const sqlPatch  = readFileSync(path.join(root,'supabase/sql/archive/Patches/supabase_bingo_v21_avatar_color_patch.sql'),'utf8');

let passed=0,failed=0;
function assert(cond,msg){if(cond){passed++;console.log('  ✓',msg);}else{failed++;console.error('  ✗',msg);}}

console.log('--- Avatar-9: COLOR_PRESETS ---');
const presetMatch=indexHtml.match(/const COLOR_PRESETS\s*=\s*\[([^\]]+)\]/s);
assert(presetMatch,'COLOR_PRESETS constant exists in index.html');
if(presetMatch){
  const presets=presetMatch[1].match(/#[0-9a-fA-F]{6}/g)||[];
  assert(presets.length===16,'COLOR_PRESETS has 16 color entries');
  presets.forEach(c=>assert(/^#[0-9a-fA-F]{6}$/.test(c),`${c} is a valid hex color`));
  assert(presets.includes('#43205c'),'Default Lerke plum (#43205c) is in presets');
}

console.log('\n--- Avatar-9: normalizeAvatarData includes bgColor ---');
assert(indexHtml.includes('bgColor'),'bgColor referenced in index.html');
assert(indexHtml.includes("normalizeAvatarData(avatarData){"),'normalizeAvatarData exists');
assert(/const bgColor=.*bgColor.*#43205c/.test(indexHtml),'normalizeAvatarData extracts bgColor with default #43205c');

console.log('\n--- Avatar-9: renderAvatarCircle uses bgColor ---');
assert(indexHtml.includes('background:${normalized.bgColor}'),'renderAvatarCircle applies bgColor as background');

console.log('\n--- Avatar-9: pendingAvatar default includes bgColor ---');
assert(indexHtml.includes("let pendingAvatar={head:'head_basic',acc:'acc_none',bgColor:'#43205c'}"),'pendingAvatar default includes bgColor');

console.log('\n--- Avatar-9: Farger tab in renderAvatarShop ---');
assert(indexHtml.includes("setShopTab('color')") && indexHtml.includes('>Farger<'),'Farger tab present in shop');
assert(indexHtml.includes('avatar-color-grid'),'Color grid HTML rendered in color tab');
assert(indexHtml.includes('avatar-color-swatch'),'Color swatches rendered');

console.log('\n--- Avatar-9: pickColor function ---');
assert(indexHtml.includes('async function pickColor(color){'),'pickColor async function exists');
assert(indexHtml.includes("purchase_avatar_color",),'pickColor calls purchase_avatar_color RPC');
assert(indexHtml.includes("p_color_slot:'bgColor'"),'purchase_avatar_color called with slot bgColor');
assert(indexHtml.includes('pendingAvatar.bgColor===color'),'pickColor skips no-op (same color guard)');

console.log('\n--- Avatar-9: CSS for color picker ---');
assert(indexHtml.includes('.avatar-color-grid{'),'CSS .avatar-color-grid defined');
assert(indexHtml.includes('.avatar-color-swatch{'),'CSS .avatar-color-swatch defined');
assert(indexHtml.includes('.avatar-color-swatch.selected{'),'CSS .avatar-color-swatch.selected defined');

console.log('\n--- Avatar-9: SQL patch ---');
assert(sqlPatch.includes('purchase_avatar_color'),'purchase_avatar_color RPC defined in SQL patch');
assert(sqlPatch.includes("COLOR_COST constant int := 25"),'COLOR_COST is 25 XP');
assert(sqlPatch.includes("p_color_slot not in ('bgColor')"),'bgColor slot validated');
assert(sqlPatch.includes("'^#[0-9a-fA-F]{6}$'"),'Hex color format validated in SQL');
assert(sqlPatch.includes('v_xp < COLOR_COST'),'XP balance checked before deducting');
assert(sqlPatch.includes('v_xp - COLOR_COST'),'XP deducted on success');
assert(sqlPatch.includes("jsonb_build_object(p_color_slot, p_color)"),'Color merged into avatar_data');
assert(sqlPatch.includes("grant execute on function public.purchase_avatar_color"),'GRANT applied');

console.log('\n--- Avatar-9: teacher.html bgColor support ---');
const teacherHtml=readFileSync(path.join(root,'apps/bingo/teacher.html'),'utf8');
assert(teacherHtml.includes('bgColor&&/^#[0-9a-fA-F]{6}$/'),'renderAvatarCircleT validates bgColor hex format');
assert(teacherHtml.includes('background:${bgColor}'),'renderAvatarCircleT applies bgColor to t-avatar-sprite');

console.log(`\n${passed+failed} checks: ${passed} passed, ${failed} failed`);
if(failed>0) process.exit(1);
