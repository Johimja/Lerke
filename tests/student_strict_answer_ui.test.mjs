import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';

const root = new URL('..', import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, '$1');
const studentHtml = readFileSync(join(root, 'apps/bingo/student.html'), 'utf8');

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

const submitStrictAnswer = extractFunction(studentHtml, 'submitStrictAnswer');
const toggleCell = extractFunction(studentHtml, 'toggleCell');

assert.match(studentHtml, /let strictAnswerInFlight=false;/, 'strict mode must track an in-flight answer');
assert.match(studentHtml, /function normalizeMarkedCellIndices/, 'marked cells must be normalized from Supabase JSON');
assert.match(toggleCell, /strictAnswerInFlight/, 'strict cell clicks must be blocked while an answer is in flight');
assert.doesNotMatch(
  submitStrictAnswer,
  /cellEl\)\s*cellEl\.classList\.add\('marked'\)/,
  'strict answer submission must not show a correct checkmark before server confirmation'
);
assert.match(submitStrictAnswer, /data\?\.response_outcome==='correct'[\s\S]*applyMarkedCellsToGrid/, 'correct responses must apply server-confirmed marks');
assert.match(submitStrictAnswer, /response_outcome==='wrong'[\s\S]*applyMarkedCellsToGrid/, 'wrong responses must restore server-confirmed marks');
