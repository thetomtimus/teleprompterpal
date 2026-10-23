import assert from 'node:assert/strict';
import test from 'node:test';
import { cleanScript, defaultCleanerOptions, paragraphCount } from '../src/lib/script-cleaner.ts';

test('joins PDF-style wrapped lines while retaining blank-line paragraphs', () => {
  assert.equal(cleanScript('  Hello   there.\r\nRead this aloud.\r\n  \r\n\r\nNext\rthought.  '), 'Hello there. Read this aloud.\n\nNext thought.');
  assert.equal(cleanScript('One\u2028two.\u2029Three.'), 'One two.\n\nThree.');
});

test('the one-paragraph option joins all lines and whitespace-only input stays empty', () => {
  assert.equal(cleanScript('One\n\nTwo.\n\n\nThree.', { ...defaultCleanerOptions, paragraphs: false }), 'One Two. Three.');
  assert.equal(cleanScript('  \n\t\r\n\u00a0'), '');
  assert.equal(paragraphCount(''), 0);
  assert.equal(paragraphCount('One.\n\nTwo.'), 2);
});

test('spacing cleanup is optional and preserves intentional punctuation and hyphens', () => {
  assert.equal(cleanScript('Keep\t\tthis\u00a0\u00a0space.  Don’t change 1,000.50 or co-\noperate.'), 'Keep this space. Don’t change 1,000.50 or co- operate.');
  assert.equal(cleanScript('  One   two\tthree.\nNext.  ', { ...defaultCleanerOptions, extraSpaces: false }), 'One   two\tthree. Next.');
});

test('all modes preserve non-whitespace content, including Unicode and HTML-like input', () => {
  const source = '<script>alert("x")</script>\n\nCafé  déjà\tvu.\n你好。안녕하세요!\nDon’t  re-write [pause] 12.50%.';
  for (const paragraphs of [true, false]) for (const extraSpaces of [true, false]) for (const readingChunks of [true, false]) {
    const result = cleanScript(source, { paragraphs, extraSpaces, readingChunks });
    assert.equal(result.replace(/\s/gu, ''), source.replace(/\s/gu, ''));
  }
});

test('reading chunks respect sentence boundaries and cap long sentences without losing words', () => {
  const source = `${'A short sentence. '.repeat(12)}${Array.from({ length: 90 }, (_, i) => `word${i}`).join(' ')}.`;
  const result = cleanScript(source, { ...defaultCleanerOptions, readingChunks: true });
  assert.equal(result.replace(/\s/gu, ''), source.replace(/\s/gu, ''));
  for (const block of result.split('\n\n')) assert.ok(block.split(/\s+/u).length <= 32);
  assert.equal(cleanScript('One.\n\nTwo.', { ...defaultCleanerOptions, readingChunks: true }), 'One.\n\nTwo.');
});

test('cleanup is idempotent and handles a full-sized pasted script', () => {
  const source = 'One   two\nthree.\n\n'.repeat(20000).slice(0, 300000);
  assert.equal(source.length, 300000);
  const cleaned = cleanScript(source);
  assert.equal(cleanScript(cleaned), cleaned);
  assert.equal(cleaned.replace(/\s/gu, ''), source.replace(/\s/gu, ''));
});
