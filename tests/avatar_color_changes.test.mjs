// tests/avatar_color_changes.test.mjs
// Guards Avatar-9 (paid color changes) consistency across index.html, teacher.html, and the SQL patch.

import {readFileSync} from 'node:fs';
import {fileURLToPath} from 'node:url';
import {dirname,join} from 'node:path';

const __dir=dirname(fileURLToPath(import.meta.url));
const root=join(__dir,'..');
const indexHtml=readFileSync(join(root,'index.html'),'utf8');
const teacherHtml=readFileSync(join(root,'apps/bingo/teacher.html'),'utf8');
const patchSql=readFileSync(join(root,'supabase/sql/archive/Patches/supabase_bingo_v21_paid_color_changes_patch.sql'),'utf8');
const freshSql=readFileSync(join(root,'supabase/sql/supabase_bingo_fresh_install_v18.sql'),'utf8');

let pass=0,fail=0;
function ok(label,cond){
  if(cond){console.log('  ✅',label);pass++;}
  else{console.error('  ❌',label);fail++;}
}

// ── index.html checks ───────────────────────────────────────────────────────
console.log('\nindex.html');

ok('DEFAULT_SKIN constant defined',indexHtml.includes("const DEFAULT_SKIN='#e8c89a'"));
ok('DEFAULT_ACC constant defined',indexHtml.includes("const DEFAULT_ACC='#d4a857'"));
ok('pendingAvatar includes skinColor',indexHtml.includes('skinColor:DEFAULT_SKIN'));
ok('pendingAvatar includes accColor',indexHtml.includes('accColor:DEFAULT_ACC'));
ok('normalizeAvatarData returns skinColor',indexHtml.includes('const skinColor=(avatarData&&avatarData.skinColor)||DEFAULT_SKIN'));
ok('normalizeAvatarData returns accColor',indexHtml.includes('const accColor=(avatarData&&avatarData.accColor)||DEFAULT_ACC'));
ok('SKIN_COLORS array defined',indexHtml.includes('const SKIN_COLORS=['));
ok('ACC_COLORS array defined',indexHtml.includes('const ACC_COLORS=['));
ok('COLOR_CHANGE_COST=25',indexHtml.includes('const COLOR_CHANGE_COST=25'));
ok('renderColorTab function exists',indexHtml.includes('function renderColorTab('));
ok('selectAvatarColor function exists',indexHtml.includes('async function selectAvatarColor('));
ok('purchaseAvatarColor function exists',indexHtml.includes('async function purchaseAvatarColor('));
ok('purchase_avatar_color RPC called',indexHtml.includes("'purchase_avatar_color'"));
ok('Farge tab added to shop',indexHtml.includes('setShopTab(\'color\')'));
ok('avatar-layer uses mask-image not background-image',
  indexHtml.includes('mask-image:url(\'media/avatar_faceshapes.png\')') &&
  !indexHtml.includes('.avatar-layer{position:absolute;top:0;left:0;width:100%;height:100%;background-image:url(\'media/avatar_faceshapes.png\')'));
ok('avatar-acc-layer uses mask-image not background-image',
  indexHtml.includes('mask-image:url(\'media/avatar_head_accessories.png\')'));
ok('SKIN_COLORS includes default #e8c89a',indexHtml.includes("hex:'#e8c89a'"));
ok('ACC_COLORS includes default #d4a857',indexHtml.includes("hex:'#d4a857'"));
ok('renderAvatarCircle uses skinColor from normalized',indexHtml.includes('normalized.skinColor'));
ok('renderAvatarCircle uses accColor from normalized',indexHtml.includes('normalized.accColor'));
ok('renderSingleSprite accepts color param',indexHtml.includes('function renderSingleSprite(col,row,size,color)'));
ok('renderSingleAccSprite accepts color param',indexHtml.includes('function renderSingleAccSprite(col,row,size,color)'));

// SKIN_COLORS has 10 entries
const skinMatch=indexHtml.match(/const SKIN_COLORS=\[([\s\S]*?)\];/);
ok('SKIN_COLORS has 10 entries',skinMatch&&(skinMatch[0].match(/hex:/g)||[]).length===10);

// ACC_COLORS has 10 entries
const accMatch=indexHtml.match(/const ACC_COLORS=\[([\s\S]*?)\];/);
ok('ACC_COLORS has 10 entries',accMatch&&(accMatch[0].match(/hex:/g)||[]).length===10);

// ── teacher.html checks ─────────────────────────────────────────────────────
console.log('\nteacher.html');

ok('t-avatar-layer uses mask-image not background-image',
  teacherHtml.includes("mask-image:url('../../media/avatar_faceshapes.png')") &&
  !teacherHtml.includes(".t-avatar-layer{position:absolute;top:0;left:0;width:100%;height:100%;background-image"));
ok('t-avatar-acc-layer uses mask-image not background-image',
  teacherHtml.includes("mask-image:url('../../media/avatar_head_accessories.png')"));
ok('renderAvatarCircleT reads skinColor from avatarData',teacherHtml.includes('avatarData.skinColor'));
ok('renderAvatarCircleT reads accColor from avatarData',teacherHtml.includes('avatarData.accColor'));
ok('renderAvatarCircleT applies skinColor to t-avatar-layer',
  teacherHtml.includes('background-color:${skinColor}'));
ok('renderAvatarCircleT applies accColor to t-avatar-acc-layer',
  teacherHtml.includes('background-color:${accColor}'));

// ── SQL patch checks ─────────────────────────────────────────────────────────
console.log('\nSQL patch (v21)');

ok('purchase_avatar_color function created',patchSql.includes('create or replace function public.purchase_avatar_color'));
ok('cost is 25 XP',patchSql.includes('v_cost         integer := 25'));
ok('validates skinColor and accColor slots',patchSql.includes("array['skinColor','accColor']"));
ok('validates hex color format',patchSql.includes("'^#([0-9a-fA-F]{3}|[0-9a-fA-F]{6})$'"));
ok('checks insufficient_xp',patchSql.includes("'insufficient_xp'"));
ok('deducts XP on update',patchSql.includes('total_xp - v_cost'));
ok('updates avatar_data jsonb',patchSql.includes('avatar_data = v_avatar_data'));
ok('returns ok:true on success',patchSql.includes("'ok',          true"));
ok('returns xp_spent',patchSql.includes("'xp_spent',    v_cost"));
ok('grant to authenticated',patchSql.includes('grant execute on function public.purchase_avatar_color'));

// ── Fresh install SQL checks ─────────────────────────────────────────────────
console.log('\nFresh install SQL');

ok('purchase_avatar_color in fresh install',freshSql.includes('create or replace function public.purchase_avatar_color'));
ok('fresh install v21 marker present',freshSql.includes('supabase_bingo_v21_paid_color_changes_patch.sql'));

// ── Summary ──────────────────────────────────────────────────────────────────
console.log(`\n${pass+fail} checks: ${pass} passed, ${fail} failed`);
if(fail>0) process.exit(1);
