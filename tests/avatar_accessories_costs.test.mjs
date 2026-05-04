import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';

const root = new URL('..', import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, '$1');
const indexHtml = readFileSync(join(root, 'index.html'), 'utf8');
const patchSql  = readFileSync(join(root, 'supabase/sql/archive/Patches/supabase_bingo_v20_avatar8_accessory_costs.sql'), 'utf8');

// Extract ACCESSORY_CATALOGUE from index.html
const m = indexHtml.match(/const ACCESSORY_CATALOGUE=\[([\s\S]*?)\];/);
assert.ok(m, 'ACCESSORY_CATALOGUE must be defined in index.html');
const catalogue = eval('[' + m[1] + ']');

// 20 items total
assert.equal(catalogue.length, 20, 'catalogue must have 20 accessory items');

// All have required fields
for (const item of catalogue) {
  assert.ok(item.key,         `${item.key}: must have key`);
  assert.ok(item.cat === 'acc', `${item.key}: cat must be 'acc'`);
  assert.ok(typeof item.xp === 'number', `${item.key}: xp must be a number`);
  assert.ok(item.xp >= 0,    `${item.key}: xp must be >= 0`);
}

// acc_none and acc_headband are free
assert.equal(catalogue.find(i => i.key === 'acc_none').xp,     0);
assert.equal(catalogue.find(i => i.key === 'acc_headband').xp,  0);

// Premium accessories cost XP
assert.ok(catalogue.find(i => i.key === 'acc_crown').xp    > 0, 'crown must cost XP');
assert.ok(catalogue.find(i => i.key === 'acc_viking').xp   > 0, 'viking must cost XP');
assert.ok(catalogue.find(i => i.key === 'acc_witch_hat').xp > 0, 'witch_hat must cost XP');

// SQL patch references every acc_* key from the catalogue
for (const item of catalogue) {
  if (item.key === 'acc_none' || item.key === 'acc_headband') continue; // 0-cost free items still appear
  assert.match(patchSql, new RegExp(`when '${item.key}'`), `SQL patch must include cost for ${item.key}`);
}

// SQL patch includes acc_none and acc_headband as free
assert.match(patchSql, /when 'acc_none'\s+then 0/);
assert.match(patchSql, /when 'acc_headband'\s+then 0/);

// No old-format xp:0 comment in ACCESSORY_CATALOGUE (avatar-7 artefact)
assert.doesNotMatch(indexHtml, /All accessories are free in this layer/);

console.log('avatar_accessories_costs: all assertions passed ✓');
