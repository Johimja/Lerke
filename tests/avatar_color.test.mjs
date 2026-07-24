// tests/avatar_color.test.mjs
// Avatar-9: skin color picker, purchase_avatar_color RPC, CSS mask rendering

import {readFileSync} from 'fs';
import {fileURLToPath} from 'url';
import {dirname,join} from 'path';

const __dir=dirname(fileURLToPath(import.meta.url));
const idx=readFileSync(join(__dir,'../index.html'),'utf8');
const tch=readFileSync(join(__dir,'../apps/bingo/teacher.html'),'utf8');
const sql=readFileSync(join(__dir,'../supabase/sql/archive/Patches/supabase_bingo_v21_avatar_color_patch.sql'),'utf8');
const fresh=readFileSync(join(__dir,'../supabase/sql/supabase_bingo_fresh_install_v18.sql'),'utf8');

let passed=0,failed=0;
function ok(label,cond){
  if(cond){console.log(`  ✓ ${label}`);passed++;}
  else{console.error(`  ✗ ${label}`);failed++;}
}

console.log('\nAvatar-9: skin color (index.html)');

// normalizeAvatarData returns skinColor
ok('normalizeAvatarData returns skinColor field',idx.includes("const skinColor=/^#[0-9a-fA-F]{6}$/.test(rawColor)?rawColor:'#c8a882'"));

// pendingAvatar default includes skinColor
ok('pendingAvatar default has skinColor #c8a882',idx.includes("skinColor:'#c8a882'"));

// _skinLayerStyle function exists with mask-image
ok('_skinLayerStyle function defined',idx.includes('function _skinLayerStyle(col,row,size,color)'));
ok('_skinLayerStyle uses mask-image',idx.includes("mask-image:url('media/avatar_faceshapes.png')"));
ok('_skinLayerStyle uses background color param',idx.includes('`background:${color};'));

// CSS class for skin layer
ok('.avatar-skin-layer CSS defined',idx.includes('.avatar-skin-layer{'));
ok('.avatar-skin-layer uses mask-repeat',idx.includes('mask-repeat:no-repeat}'));

// renderAvatarCircle uses skin layer
ok('renderAvatarCircle uses avatar-skin-layer',idx.includes('"avatar-skin-layer"'));
ok('renderAvatarCircle passes normalized.skinColor to _skinLayerStyle',idx.includes('_skinLayerStyle(h.col,h.row,size,normalized.skinColor)'));

// renderSingleSprite uses skin layer for previews
ok('renderSingleSprite uses _skinLayerStyle',idx.includes('_skinLayerStyle(col,row,size,color)'));

// Farge tab in shop
ok('setShopTab supports color tab',idx.includes("setShopTab('color')"));
ok('Farge tab rendered in shop tabs',idx.includes('>Farge<'));
ok('color picker input rendered in Farge tab',idx.includes('type="color"'));
ok('avatar-color-hint text present',idx.includes('Forhåndsvisning er gratis'));
ok('Kjøp farge 25 XP button present',idx.includes('Kjøp farge 25 XP'));

// onSkinColorInput function
ok('onSkinColorInput function defined',idx.includes('function onSkinColorInput(color)'));
ok('onSkinColorInput updates pendingAvatar.skinColor',idx.includes('pendingAvatar={...pendingAvatar,skinColor:color}'));

// purchaseAvatarColor function
ok('purchaseAvatarColor function defined',idx.includes('async function purchaseAvatarColor(slot,color)'));
ok('purchaseAvatarColor calls purchase_avatar_color RPC',idx.includes("'purchase_avatar_color'"));

console.log('\nAvatar-9: skin color (teacher.html)');

ok('_tSkinLayerStyle function defined in teacher',tch.includes('function _tSkinLayerStyle(col,row,size,color)'));
ok('_tSkinLayerStyle uses ../../media mask path',tch.includes("mask-image:url('../../media/avatar_faceshapes.png')"));
ok('.t-avatar-skin-layer CSS defined',tch.includes('.t-avatar-skin-layer{'));
ok('renderAvatarCircleT uses t-avatar-skin-layer',tch.includes('"t-avatar-skin-layer"'));
ok('renderAvatarCircleT validates skinColor hex',tch.includes('/^#[0-9a-fA-F]{6}$/.test(rawColor)'));

console.log('\nAvatar-9: SQL patch');

ok('SQL patch has purchase_avatar_color function',sql.includes('create or replace function public.purchase_avatar_color'));
ok('SQL validates skin slot',sql.includes("p_color_slot not in ('skin')"));
ok('SQL validates hex format',sql.includes("'^#[0-9a-fA-F]{6}$'"));
ok('SQL deducts 25 XP',sql.includes('v_cost       int := 25'));
ok('SQL uses jsonb_set for skinColor',sql.includes("array['skinColor']"));
ok('SQL grants execute to authenticated',sql.includes('grant execute on function public.purchase_avatar_color'));

ok('Fresh install includes v21 purchase_avatar_color',fresh.includes('create or replace function public.purchase_avatar_color'));
ok('Fresh install includes v21 section marker',fresh.includes('supabase_bingo_v21_avatar_color_patch.sql'));

console.log(`\n${passed} passed, ${failed} failed`);
if(failed>0) process.exit(1);
