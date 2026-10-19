import assert from 'node:assert/strict';
import test from 'node:test';
import { signupPageContext } from '../src/lib/signup-context.ts';

function memoryStorage() {
  const values = new Map<string, string>();
  return { values, getItem: (key: string) => values.get(key) ?? null, setItem: (key: string, value: string) => { values.set(key, value); } };
}

test('known referral survives a same-tab return while user data stays out of context and storage', () => {
  const storage = memoryStorage();
  const context = signupPageContext('https://teleprompterpal.com/?utm_source=free-teleprompter-online&utm_medium=referral&utm_campaign=free-guide-zoom&email=private@example.com&script=private-words#private-title', storage);
  assert.equal(context.pageUri, 'https://teleprompterpal.com/?utm_source=free-teleprompter-online&utm_medium=referral&utm_campaign=free-guide-zoom');
  assert.deepEqual(signupPageContext('https://teleprompterpal.com/', storage), context);
  assert.doesNotMatch(JSON.stringify([context, [...storage.values]]), /private|@example/);
});

test('unknown campaigns and arbitrary paths are never forwarded', () => {
  for (const href of [
    'https://teleprompterpal.com/private-script/?utm_source=private&utm_medium=referral&utm_campaign=free-reader',
    'https://teleprompterpal.com/?utm_source=free-teleprompter-online&utm_medium=referral&utm_campaign=private-script',
    'https://teleprompterpal.com/?utm_source=free-teleprompter-online&utm_medium=private&utm_campaign=free-reader',
    'not a URL',
  ]) assert.equal(signupPageContext(href).pageUri, 'https://teleprompterpal.com/');
});

test('storage denial cannot block signup context or discard a valid incoming referral', () => {
  const denied = { getItem: () => { throw new Error('Denied'); }, setItem: () => { throw new Error('Denied'); } };
  assert.equal(signupPageContext('https://teleprompterpal.com/', denied).pageUri, 'https://teleprompterpal.com/');
  assert.match(signupPageContext('https://teleprompterpal.com/?utm_source=free-teleprompter-online&utm_medium=referral&utm_campaign=free-reader', denied).pageUri, /utm_campaign=free-reader/);
});

test('malformed or tampered saved values are ignored', () => {
  for (const value of ['{broken', '{"source":"private"}', '{"source":"free-teleprompter-online","medium":"referral","campaign":"private"}']) {
    assert.equal(signupPageContext('https://teleprompterpal.com/', { getItem: () => value, setItem: () => {} }).pageUri, 'https://teleprompterpal.com/');
  }
});
