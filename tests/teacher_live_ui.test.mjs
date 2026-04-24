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

const teacherHtml = read('apps/bingo/teacher.html');

const progressCode = [
  extractFunction(teacherHtml, 'normalizeMarkedCells'),
  extractFunction(teacherHtml, 'getMarkedCellCount'),
  extractFunction(teacherHtml, 'getBestLineProgress'),
  '({ normalizeMarkedCells, getMarkedCellCount, getBestLineProgress });',
].join('\n');
const progress = vm.runInNewContext(progressCode);

assert.deepEqual(Array.from(progress.normalizeMarkedCells([2, '4', 'x', 4])), [2, 4, 4]);
assert.deepEqual(Array.from(progress.normalizeMarkedCells('[1, 7, 12]')), [1, 7, 12]);
assert.deepEqual(Array.from(progress.normalizeMarkedCells('not json')), []);
assert.equal(progress.getMarkedCellCount([1, 7]), 2);
assert.equal(progress.getBestLineProgress([1, 7]), 1, 'two marks in different lines are not necessarily 2/5 near bingo');
assert.equal(progress.getBestLineProgress([0, 1]), 2, 'connected marks in a line should show 2/5 progress');

assert.match(teacherHtml, /const progress=board\?\.has_bingo \? 5 : getBestLineProgress\(markedCells\)/, 'roster must calculate connected-line progress');
assert.match(teacherHtml, /const meta=item\.hasBingo\?'Bingo':isNearBingo\?'[^']*':`\$\{item\.progress\}\/5`/, 'roster meta must display connected-line progress');
assert.match(teacherHtml, /let liveJoinAutoCollapsedKey=''/, 'auto-collapse must be keyed so manual reopening survives polling');
assert.match(teacherHtml, /setLiveJoinCollapsed\(true\)/, 'auto-collapse should use idempotent collapse instead of toggling repeatedly');
assert.doesNotMatch(
  extractFunction(teacherHtml, 'renderStrictTeacherLiveMode'),
  /toggleLiveJoin\(\)/,
  'strict render loop must not toggle join info every poll'
);
