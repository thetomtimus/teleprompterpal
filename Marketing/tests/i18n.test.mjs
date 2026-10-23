import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { extractStrings, validateCatalog, localizeHtml } from '../scripts/localize.mjs';
import { locales, origin, translatedRoutes, localizedPath } from '../src/i18n/config.mjs';

test('new or edited source copy blocks release until every translation exists', () => {
  assert.throws(() => validateCatalog({ 'Old offer': 'Antigua oferta' }, ['New offer'], 'es'), /missing translations/);
  assert.throws(() => validateCatalog({ 'New offer': '' }, ['New offer'], 'es'), /missing translations/);
});
test('translations cannot silently change commercial facts or insert markup', () => {
  assert.throws(() => validateCatalog({ '$59.99 per year.': '$19.99 al año.' }, ['$59.99 per year.'], 'es'), /protected/);
  assert.doesNotThrow(() => validateCatalog({ '$59.99 per year.': '$59.99 jährlich.' }, ['$59.99 per year.'], 'de'));
  assert.throws(() => validateCatalog({ Hello: '<img src=x>' }, ['Hello'], 'es'), /text, not HTML/);
});
test('extracts accessibility, SEO, and no-JS copy without translating executable code or language names', () => {
  const html = '<html><head><title>Hello</title><meta name="description" content="A description"></head><body><img alt="A picture"><button aria-label="Start">Go</button><noscript>Enable JavaScript</noscript><nav translate="no">Español</nav><script>const secret = "Code"</script></body></html>';
  assert.deepEqual(extractStrings(html).sort(), ['A description', 'A picture', 'Enable JavaScript', 'Go', 'Hello', 'Start'].sort());
});
test('localizes equivalent links, preserves untranslated routes and escaped text', async () => {
  const html = '<html><head><title>Hello</title><meta name="robots" content="noindex, nofollow"><link rel="canonical" href="https://teleprompterpal.com/"></head><body><a href="/pricing/#plans">Prices</a><a href="/guides/">Guides</a><p>Hello</p></body></html>';
  const result = await localizeHtml(html, '/', locales[1], { Hello: 'Hola & adiós', Prices: 'Precios', Guides: 'Guías', 'in English': 'en inglés' });
  assert.match(result, /href="\/es\/pricing\/#plans"/);
  assert.match(result, /href="\/guides\/" hreflang="en"/);
  assert.match(result, /Hola &amp; adiós/);
  assert.match(result, /name="robots" content="noindex, nofollow"/);
  assert.match(result, /hreflang="pt-BR" href="https:\/\/teleprompterpal.com\/pt-br\/"/);
});
test('shared screenshot links retain localized accessibility without an English-page suffix', async () => {
  const html = '<html><head><title>Hello</title></head><body><a href="/images/editor.webp" aria-label="Open image"><img alt="Editor"></a></body></html>';
  const result = await localizeHtml(html, '/help/', locales[1], { Hello: 'Hola', 'Open image': 'Abrir imagen', Editor: 'Editor', 'in English': 'en inglés' });
  assert.match(result, /aria-label="Abrir imagen"/);
  assert.doesNotMatch(result, /\(en inglés\)/);
});
test('all built locales have reciprocal equivalents, their own canonical, sitemap entry and both choosers', async () => {
  const sitemap = await readFile(new URL('../dist/sitemap.xml', import.meta.url), 'utf8');
  for (const route of translatedRoutes) for (const locale of locales) {
    const url = origin + localizedPath(route, locale);
    const html = await readFile(new URL(`../dist${localizedPath(route, locale)}index.html`, import.meta.url), 'utf8');
    assert.ok(html.includes(`<html lang="${locale.code}">`), url);
    assert.ok(html.includes(`rel="canonical" href="${url}"`), url);
    assert.ok(sitemap.includes(`<loc>${url}</loc>`), url);
    for (const alternate of locales) assert.ok(html.includes(`hreflang="${alternate.code}" href="${origin + localizedPath(route, alternate)}"`), url);
    assert.match(html, /class="language-chooser"/);
    assert.match(html, /class="footer-languages"/);
    if (locale.code !== 'en') {
      assert.match(html, /data-translated-messages=/);
      assert.doesNotMatch(html, />See pricing</);
      assert.doesNotMatch(html, /Currently in private beta/);
    }
  }
});
test('legal choosers share the handler and allow it through their CSP exactly once', async () => {
  for (const route of ['privacy', 'support']) {
    const html = await readFile(new URL(`../dist/${route}/index.html`, import.meta.url), 'utf8');
    const policy = /http-equiv="Content-Security-Policy" content="([^"]+)"/.exec(html)?.[1];
    assert.match(html, /class="legal-language-chooser" data-language-picker/);
    assert.match(html, /src="\/assets\/language-chooser.js"/);
    assert.equal(policy.match(/script-src/g).length, 1);
    assert.match(policy, /script-src 'self'(?:;| https:)/);
  }
});
