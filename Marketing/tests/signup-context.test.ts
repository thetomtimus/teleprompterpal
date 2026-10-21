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

test('browser-camera guide arrival survives guide and pricing navigation before signup', () => {
  const storage = memoryStorage();
  signupPageContext('https://teleprompterpal.com/guides/record-video-with-script-iphone/?utm_source=freeteleprompteronline&utm_medium=referral&utm_campaign=camera_workflow&script=private-script#private-title', storage);
  signupPageContext('https://teleprompterpal.com/compare/bigvu-alternative/#pricing', storage);
  assert.deepEqual(signupPageContext('https://teleprompterpal.com/#app-updates', storage), {
    pageUri: 'https://teleprompterpal.com/?utm_source=free-teleprompter-online&utm_medium=referral&utm_campaign=free-guide-camera',
    pageName: 'Teleprompter Pal Product Updates',
  });
  assert.doesNotMatch(JSON.stringify([...storage.values]), /private|script|title|https/);
});

test('fresh direct visits stay direct and a new known referral replaces an earlier campaign', () => {
  const storage = memoryStorage();
  assert.equal(signupPageContext('https://teleprompterpal.com/', storage).pageUri, 'https://teleprompterpal.com/');
  signupPageContext('https://teleprompterpal.com/?utm_source=free-teleprompter-online&utm_medium=referral&utm_campaign=free-guide-zoom', storage);
  signupPageContext('https://teleprompterpal.com/guides/record-video-with-script-iphone/?utm_source=free-teleprompter-online&utm_medium=referral&utm_campaign=free-guide-camera', storage);
  assert.match(signupPageContext('https://teleprompterpal.com/', storage).pageUri, /utm_campaign=free-guide-camera$/);
});

test('legacy camera aliases require the exact published source, medium and campaign', () => {
  for (const href of [
    'https://teleprompterpal.com/?utm_source=freeteleprompteronline&utm_medium=email&utm_campaign=camera_workflow',
    'https://teleprompterpal.com/?utm_source=freeteleprompteronline&utm_medium=referral&utm_campaign=private-script',
    'https://teleprompterpal.com/?utm_source=unknown&utm_medium=referral&utm_campaign=camera_workflow',
  ]) assert.equal(signupPageContext(href).pageUri, 'https://teleprompterpal.com/');
});
