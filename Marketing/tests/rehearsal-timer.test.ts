import assert from 'node:assert/strict';
import test from 'node:test';
import { createTimer, elapsedMilliseconds, finishTimer, pauseTimer, startTimer, timerClock, timerReading, timerSettings } from '../src/lib/rehearsal-timer.ts';

test('settings reject invalid, empty, fractional and out-of-range targets and warnings', () => {
  for (const values of [[NaN, 0, 0], [0, 0, 0], [-1, 0, 0], [1.5, 0, 0], [1, 60, 0], [180, 1, 0], [1, 0, 60], [1, 0, -1], [1, 0, 1.5]]) assert.ok(timerSettings(...values as [number, number, number]));
  assert.equal(timerSettings(0, 1, 0), null);
  assert.equal(timerSettings(180, 0, 60), null);
  assert.throws(() => createTimer(0, 0), RangeError);
});
test('timestamp timing catches up after delayed callbacks without counting ticks', () => {
  const timer = startTimer(createTimer(300, 60), 1000);
  assert.equal(elapsedMilliseconds(timer, 141234), 140234);
  assert.equal(timerReading(timer, 141234).clockSeconds, 160);
  assert.equal(timerReading(timer, 141234).elapsedSeconds, 140);
  assert.equal(elapsedMilliseconds(timer, 500), 0);
  assert.equal(startTimer(timer, 5000), timer);
});
test('pause and resume exclude every paused interval and finish freezes the result', () => {
  let timer = startTimer(createTimer(300, 60), 1000);
  timer = pauseTimer(timer, 3500);
  assert.equal(elapsedMilliseconds(timer, 100000), 2500);
  timer = startTimer(timer, 110000);
  timer = finishTimer(timer, 111500);
  assert.equal(timer.phase, 'finished');
  assert.equal(elapsedMilliseconds(timer, 999999), 4000);
  assert.equal(finishTimer(timer, 999999), timer);
  assert.equal(elapsedMilliseconds(startTimer(timer, 200000), 201000), 1000);
});
test('finish while paused retains only active delivery, and idle finish does nothing', () => {
  const ready = createTimer(60, 15);
  assert.equal(finishTimer(ready, 100), ready);
  const paused = pauseTimer(startTimer(ready, 1000), 4500);
  assert.equal(finishTimer(paused, 99999).elapsedMs, 3500);
});
test('warning and overtime change at exact thresholds, including a disabled warning', () => {
  const timer = startTimer(createTimer(300, 60), 1000);
  assert.equal(timerReading(timer, 240999).signal, 'safe');
  assert.equal(timerReading(timer, 241000).signal, 'warning');
  assert.equal(timerReading(timer, 300999).clockSeconds, 1);
  assert.deepEqual(timerReading(timer, 301000), { signal: 'over', elapsedSeconds: 300, clockSeconds: 0, over: true });
  assert.equal(timerReading(timer, 365250).clockSeconds, 64);
  assert.equal(timerReading(startTimer(createTimer(60, 0), 1000), 60999).signal, 'safe');
});
test('clock formats minute, hour and overtime values without wrapping hours', () => {
  assert.equal(timerClock(0), '0:00');
  assert.equal(timerClock(59.9), '0:59');
  assert.equal(timerClock(60), '1:00');
  assert.equal(timerClock(3600), '1:00:00');
  assert.equal(timerClock(10800), '3:00:00');
  assert.equal(timerClock(86401), '24:00:01');
});
