import assert from 'node:assert/strict';
import { readFileSync, existsSync } from 'node:fs';
import { join } from 'node:path';

const root = new URL('..', import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, '$1');

function read(relPath) {
  return readFileSync(join(root, relPath), 'utf8');
}

function pngSize(relPath) {
  const buf = readFileSync(join(root, relPath));
  assert.equal(buf.toString('ascii', 1, 4), 'PNG', `${relPath} must be a PNG`);
  return { width: buf.readUInt32BE(16), height: buf.readUInt32BE(20) };
}

const indexHtml = read('index.html');
const sqlPatch = read('supabase/sql/archive/Patches/supabase_bingo_v20_avatar_accessories.sql');

// --- PNG sheet ---
assert.ok(
  existsSync(join(root, 'media/avatar_head_accessories.png')),
  'avatar_head_accessories.png must exist'
);
assert.deepEqual(pngSize('media/avatar_head_accessories.png'), { width: 1024, height: 1280 });

// --- ACCESSORY_CATALOGUE present in index.html ---
assert.match(indexHtml, /const ACCESSORY_CATALOGUE=\[/, 'ACCESSORY_CATALOGUE must be defined');

// Extract the catalogue array text
const catalogueMatch = indexHtml.match(/const ACCESSORY_CATALOGUE=\[([\s\S]*?)\];/);
assert.ok(catalogueMatch, 'ACCESSORY_CATALOGUE array must be extractable');

// Parse items from the catalogue block
const catalogueBlock = catalogueMatch[1];
const items = [...catalogueBlock.matchAll(/\{key:'([^']+)'[^}]*xp:(\d+)[^}]*\}/g)]
  .map(m => ({ key: m[1], xp: parseInt(m[2], 10) }));

assert.equal(items.length, 20, 'ACCESSORY_CATALOGUE must have exactly 20 items');

// acc_none is always free
const none = items.find(i => i.key === 'acc_none');
assert.ok(none, 'acc_none must be in catalogue');
assert.equal(none.xp, 0, 'acc_none must be free');

// Premium items have correct XP costs
const crown = items.find(i => i.key === 'acc_crown');
assert.ok(crown, 'acc_crown must be in catalogue');
assert.equal(crown.xp, 200, 'acc_crown must cost 200 XP');

const viking = items.find(i => i.key === 'acc_viking');
assert.ok(viking, 'acc_viking must be in catalogue');
assert.equal(viking.xp, 150, 'acc_viking must cost 150 XP');

const tiara = items.find(i => i.key === 'acc_tiara');
assert.ok(tiara, 'acc_tiara must be in catalogue');
assert.equal(tiara.xp, 150, 'acc_tiara must cost 150 XP');

// No item with xp:0 other than acc_none (all others must cost XP)
const freePaidItems = items.filter(i => i.key !== 'acc_none' && i.xp === 0);
assert.equal(freePaidItems.length, 0, 'No accessory other than acc_none should be free');

// --- SQL patch covers all acc_* keys from the catalogue ---
for (const item of items) {
  if (item.key === 'acc_none') continue; // acc_none handled as xp:0 in SQL
  assert.match(
    sqlPatch,
    new RegExp(`when '${item.key}'\\s+then \\d+`),
    `SQL patch must define cost for ${item.key}`
  );
}

// acc_none in SQL returns 0
assert.match(sqlPatch, /when 'acc_none'\s+then 0/, 'SQL must set acc_none cost to 0');

// purchase_avatar_item is not redefined (it already works via get_avatar_item_cost)
assert.doesNotMatch(sqlPatch, /create.*function.*purchase_avatar_item/i,
  'v20 patch must not redefine purchase_avatar_item (already works via get_avatar_item_cost)');

// --- avatar-acc-layer CSS present in index.html ---
assert.match(indexHtml, /avatar-acc-layer/, 'index.html must have avatar-acc-layer CSS class');
assert.match(indexHtml, /avatar_head_accessories\.png/, 'index.html must reference avatar_head_accessories.png');

// --- Tilbehør tab present in shop ---
assert.match(indexHtml, /Tilbehør/, 'index.html shop must have Tilbehør tab');
assert.match(indexHtml, /setShopTab\('acc'\)/, 'index.html must have setShopTab acc call');

console.log('avatar_accessories_shop: all assertions passed ✓');
