import assert from 'node:assert/strict';
import test from 'node:test';
import { countWords, formatDuration, measuredWpm, speechSeconds, speedPassage, wordBudget } from '../src/lib/speech-time.ts';

test('counts spoken tokens across punctuation, whitespace, contractions and hyphenated words', () => {
  assert.equal(countWords(''), 0);
  assert.equal(countWords(' … — ! \n\t'), 0);
  assert.equal(countWords("You’re ready.\nDon't rush your well-written script!"), 7);
  assert.equal(countWords('A 1,000 word script costs $12.50.'), 6);
  assert.equal(countWords('Café déjà vu'), 3);
  assert.equal(countWords('Hello,world. One.two! Wait...what?'), 6);
  assert.equal(countWords('1,000 12.50 1,000,000'), 3);
});

test('calculates a script duration and adds explicit pauses once', () => {
  assert.equal(speechSeconds(300, 150), 120);
  assert.equal(speechSeconds(300, 150, 15), 135);
  assert.equal(speechSeconds(0, 150, 0), 0);
});

test('reverse budget rounds down, respects pauses and never returns a negative budget', () => {
  assert.equal(wordBudget(120, 150), 300);
  assert.equal(wordBudget(60, 150, 10), 125);
  assert.equal(wordBudget(1, 150), 2);
  assert.equal(wordBudget(15, 150, 30), 0);
  for (const duration of [1, 30, 59, 120, 3600]) {
    assert.ok(speechSeconds(wordBudget(duration, 137, 0), 137) <= duration);
  }
});

test('rejects invalid arithmetic rather than showing a plausible estimate', () => {
  for (const value of [NaN, Infinity, -1]) {
    assert.ok(Number.isNaN(speechSeconds(value, 150)));
    assert.ok(Number.isNaN(speechSeconds(150, value)));
    assert.ok(Number.isNaN(wordBudget(value, 150)));
    assert.ok(Number.isNaN(wordBudget(60, 150, value)));
  }
  assert.ok(Number.isNaN(speechSeconds(150, 0)));
  assert.ok(Number.isNaN(measuredWpm(100, 0)));
});

test('formats rounding boundaries, hours and invalid durations', () => {
  assert.equal(formatDuration(59.8), '1:00');
  assert.equal(formatDuration(3600), '1:00:00');
  assert.equal(formatDuration(3661.2), '1:01:01');
  assert.equal(formatDuration(NaN), '—');
});

test('speaking test uses the passage word count rather than assuming a fixed length', () => {
  assert.ok(countWords(speedPassage) >= 100);
  assert.equal(measuredWpm(countWords(speedPassage), countWords(speedPassage) / 150 * 60), 150);
});
