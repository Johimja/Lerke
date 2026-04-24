import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import vm from 'node:vm';

const root = new URL('..', import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, '$1');

function read(relPath) {
  return readFileSync(join(root, relPath), 'utf8');
}

function extractFunction(source, name) {
  const start = source.indexOf(`function ${name}(`);
  assert.notEqual(start, -1, `${name} must exist`);
  let depth = 0;
  let end = -1;
  for (let i = start; i < source.length; i++) {
    if (source[i] === '{') depth++;
    if (source[i] === '}') {
      depth--;
      if (depth === 0) {
        end = i + 1;
        break;
      }
    }
  }
  assert.notEqual(end, -1, `${name} must have a complete function body`);
  return source.slice(start, end);
}

function loadBuildMatteFacts(relPath) {
  const source = read(relPath);
  const code = [
    extractFunction(source, 'getMatteMultiplierMax'),
    extractFunction(source, 'buildMatteFacts'),
    'buildMatteFacts;',
  ].join('\n');
  return vm.runInNewContext(code);
}

function loadBuildMatteAnswerGroups(relPath) {
  const source = read(relPath);
  const code = [
    extractFunction(source, 'getMatteMultiplierMax'),
    extractFunction(source, 'buildMatteFacts'),
    extractFunction(source, 'buildMatteAnswerGroups'),
    'buildMatteAnswerGroups;',
  ].join('\n');
  return vm.runInNewContext(code);
}

for (const relPath of [
  'apps/bingo/teacher.html',
  'apps/bingo/student.html',
  'apps/bingo-generator/index.html',
]) {
  const buildMatteFacts = loadBuildMatteFacts(relPath);

  const basicFacts = buildMatteFacts([1, 2, 3]);
  const basicEquations = new Set(basicFacts.map(f => f.eq));
  assert.ok(basicEquations.has('3 × 12'), `${relPath} must allow selected tables up to 12`);
  assert.ok(basicEquations.has('12 × 3'), `${relPath} must include reversed equations`);
  assert.ok(basicEquations.has('10 × 3'), `${relPath} must include high first factors for selected tables`);
  assert.ok(!basicEquations.has('3 × 13'), `${relPath} must not exceed 12 for built-in tables`);

  const customFacts = buildMatteFacts([3, 18]);
  const customEquations = new Set(customFacts.map(f => f.eq));
  assert.ok(customEquations.has('18 × 17'), `${relPath} must allow custom table factors up to the custom table`);
  assert.ok(customEquations.has('17 × 18'), `${relPath} must include reversed custom equations`);
  assert.ok(!customEquations.has('3 × 17'), `${relPath} must not let a low selected table inherit the custom max`);
}

const studentHtml = read('apps/bingo/student.html');
const teacherHtml = read('apps/bingo/teacher.html');
const generatorHtml = read('apps/bingo-generator/index.html');
const freshSql = read('supabase/sql/supabase_bingo_fresh_install_v18.sql');
const v19PatchSql = read('supabase/sql/archive/Patches/supabase_bingo_v19_matte_correct_answers_patch.sql');

for (const relPath of [
  'apps/bingo/teacher.html',
  'apps/bingo-generator/index.html',
]) {
  const buildMatteAnswerGroups = loadBuildMatteAnswerGroups(relPath);
  const group24 = buildMatteAnswerGroups([1, 2, 3, 4, 6, 8, 12]).find(group => group.ans === 24);
  assert.ok(group24, `${relPath} must group equations by answer`);
  assert.deepEqual(
    new Set(group24.equations),
    new Set(['2 × 12', '12 × 2', '3 × 8', '8 × 3', '4 × 6', '6 × 4']),
    `${relPath} must allow all selected equations for answer 24`
  );
}

assert.match(studentHtml, /mode:settings\.matte_mode\|\|'ans'/, 'student live setup must keep matte mode from session settings');
assert.match(studentHtml, /mode:initialMatteMode/, 'student URL setup must keep matte mode from QR links');
assert.match(studentHtml, /cardIsAnswer=cardData\.mode!=='eq'/, 'student card generation must switch between answer and equation cells');
assert.match(teacherHtml, /matteMode=\$\{encodeURIComponent\(matteMode\)\}/, 'teacher QR links must pass matte mode to students');
assert.match(teacherHtml, /correct_answers:cardIsAnswer\?\[String\(group\.ans\)\]:equations/, 'teacher live draws must carry all valid equation answers');
assert.match(generatorHtml, /buildMatteAnswerGroups\(tables\)/, 'print generator must group math calls by answer');
assert.match(freshSql, /jsonb_array_elements_text\(v_state\.current_draw->'correct_answers'\)/, 'SQL validation must accept multiple correct answers');
assert.match(v19PatchSql, /create or replace function public\.submit_bingo_answer\(/, 'V19 patch must replace submit_bingo_answer for existing databases');
assert.match(v19PatchSql, /jsonb_array_elements_text\(v_state\.current_draw->'correct_answers'\)/, 'V19 patch must accept multiple correct answers');
