// tests/avatar_color_purchase.test.mjs
// Guards for Avatar-9: paid color changes via hue slider + purchase_avatar_color RPC.

import fs from 'fs';
import path from 'path';

const root = process.cwd();
const indexHtml = fs.readFileSync(path.join(root, 'index.html'), 'utf8');
const teacherHtml = fs.readFileSync(path.join(root, 'apps/bingo/teacher.html'), 'utf8');

let passed = 0, failed = 0;
function check(label, condition) {
  if (condition) { console.log(`  ✓ ${label}`); passed++; }
  else { console.error(`  ✗ ${label}`); failed++; }
}

console.log('\n=== Avatar-9: paid color changes ===\n');

// --- CSS: avatar layers use mask-image (not background-image) ---
console.log('CSS rendering (mask-image approach):');
check('index.html .avatar-layer uses mask-image for faceshapes',
  indexHtml.includes("mask-image:url('media/avatar_faceshapes.png')")
);
check('index.html .avatar-acc-layer uses mask-image for accessories',
  indexHtml.includes("mask-image:url('media/avatar_head_accessories.png')")
);
check('index.html .avatar-layer does NOT use background-image for faceshapes',
  !(/\.avatar-layer\{[^}]*background-image:url\('media\/avatar_faceshapes/.test(indexHtml))
);
check('teacher.html .t-avatar-layer uses mask-image',
  teacherHtml.includes("mask-image:url('../../media/avatar_faceshapes.png')")
);
check('teacher.html .t-avatar-layer does NOT use background-image',
  !(/\.t-avatar-layer\{[^}]*background-image/.test(teacherHtml))
);

// --- JS: color helpers ---
console.log('\nJS color helpers:');
check('index.html has hueToHex function', indexHtml.includes('function hueToHex('));
check('index.html has hexToHue function', indexHtml.includes('function hexToHue('));
check('index.html has hue2rgb helper', indexHtml.includes('function hue2rgb('));

// --- JS: normalizeAvatarData includes color fields ---
console.log('\nnormalizeAvatarData:');
check('index.html normalizeAvatarData extracts silhouetteColor',
  indexHtml.includes('silhouetteColor') && indexHtml.includes('normalizeAvatarData')
);
check('index.html normalizeAvatarData extracts accColor',
  indexHtml.includes('accColor') && indexHtml.includes('normalizeAvatarData')
);
check('index.html validates hex with /^#[0-9a-fA-F]{6}$/',
  indexHtml.includes('^#[0-9a-fA-F]{6}$')
);

// --- JS: renderAvatarCircle passes color to _spriteStyle ---
console.log('\nrenderAvatarCircle:');
check('index.html renderAvatarCircle passes silhouetteColor to _spriteStyle',
  indexHtml.includes('_spriteStyle(h.col,h.row,size,normalized.silhouetteColor)')
);
check('teacher.html renderAvatarCircleT passes silhouetteColor to _tSpriteStyle',
  teacherHtml.includes('_tSpriteStyle(h.col,h.row,size,silhouetteColor)')
);

// --- JS: color tab in shop ---
console.log('\nAvatar shop color tab:');
check('index.html has Farge tab button',
  indexHtml.includes("setShopTab('color')")
);
check('index.html has renderColorTab function',
  indexHtml.includes('function renderColorTab(')
);
check('index.html color tab has face hue slider',
  indexHtml.includes('face-hue-slider')
);
check('index.html color tab has acc hue slider',
  indexHtml.includes('acc-hue-slider')
);
check('index.html has onFaceHueChange handler',
  indexHtml.includes('function onFaceHueChange(')
);
check('index.html has onAccHueChange handler',
  indexHtml.includes('function onAccHueChange(')
);

// --- JS: purchaseAvatarColor ---
console.log('\npurchaseAvatarColor function:');
check('index.html has purchaseAvatarColor function',
  indexHtml.includes('async function purchaseAvatarColor(')
);
check('index.html calls purchase_avatar_color RPC',
  indexHtml.includes("rpc('purchase_avatar_color'")
);
check('index.html updates pendingAvatar after purchase',
  indexHtml.includes('pendingAvatar={...pendingAvatar,[slot]:hexColor}')
);
check('index.html updates XP bar after purchase',
  indexHtml.includes('updateXPBar()') && indexHtml.includes('purchaseAvatarColor')
);

// --- SQL patch file ---
console.log('\nSQL patch:');
const patchPath = path.join(root, 'supabase/sql/archive/Patches/supabase_bingo_v21_avatar_color_patch.sql');
const patchExists = fs.existsSync(patchPath);
check('v21 patch file exists', patchExists);
if (patchExists) {
  const sql = fs.readFileSync(patchPath, 'utf8');
  check('v21 defines purchase_avatar_color', sql.includes('purchase_avatar_color'));
  check('v21 validates hex color with regex', sql.includes("#[0-9a-fA-F]{6}"));
  check('v21 costs 25 XP', sql.includes('v_cost        integer := 25') || sql.includes('v_cost integer := 25'));
  check('v21 allows silhouetteColor slot', sql.includes("'silhouetteColor'"));
  check('v21 allows accColor slot', sql.includes("'accColor'"));
  check('v21 grants to authenticated', sql.includes('to authenticated'));
  check('v21 returns ok:true on success', /'ok',\s+true/.test(sql));
  check('v21 returns ok:false on bad slot', sql.includes("'ok', false"));
}

// --- Fresh install SQL includes v21 ---
console.log('\nFresh install SQL:');
const freshSql = fs.readFileSync(path.join(root, 'supabase/sql/supabase_bingo_fresh_install_v18.sql'), 'utf8');
check('fresh install includes purchase_avatar_color', freshSql.includes('purchase_avatar_color'));

console.log(`\n${passed} passed, ${failed} failed`);
if (failed > 0) process.exit(1);
