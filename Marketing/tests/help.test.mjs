import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { helpArticles, helpPath } from '../src/data/help.mjs';
import { locales, localizedPath, translatedRoutes } from '../src/i18n/config.mjs';
import { matchesHelpSearch } from '../src/lib/help-search.mjs';
import { parse } from 'parse5';

test('guide search handles accents, case, multiple terms, Japanese and Korean', () => {
  assert.ok(matchesHelpSearch('Exportación de vídeo MP4', 'VIDEO exportacion'));
  assert.ok(matchesHelpSearch('録画の中断と書き出し', '録画 中断'));
  assert.ok(matchesHelpSearch('영상 녹화 및 내보내기', '녹화'));
  assert.equal(matchesHelpSearch('Import a script', 'camera'), false);
});

test('every guide has translated navigation, headings, working section anchors and a local search index', async () => {
  for (const locale of locales) for (const article of helpArticles) {
    const route = helpPath(article.slug);
    assert.ok(translatedRoutes.includes(route));
    const html = await readFile(new URL(`../dist${localizedPath(route, locale)}index.html`, import.meta.url), 'utf8');
    const document = parse(html);
    const nodes = [];
    const walk = node => { nodes.push(node); (node.childNodes ?? []).forEach(walk); };
    walk(document);
    const attr = (node, key) => node.attrs?.find(a => a.name === key)?.value;
    for (const section of article.sections) {
      assert.ok(nodes.some(node => attr(node, 'id') === section.id), `${route} #${section.id}`);
    }
    assert.equal(nodes.filter(node => attr(node, 'data-search-result') !== undefined).length, helpArticles.length);
    for (const target of helpArticles) {
      assert.ok(nodes.some(node => node.tagName === 'a' && attr(node, 'href') === localizedPath(helpPath(target.slug), locale)));
    }
    const catalog = locale.code === 'en' ? {} : JSON.parse(await readFile(new URL(`../src/i18n/${locale.code}.json`, import.meta.url)));
    const h1 = nodes.find(node => node.tagName === 'h1');
    assert.equal(h1.childNodes[0].value, catalog[article.title] ?? article.title);
    assert.equal(nodes.filter(node => node.tagName === 'script' && !attr(node, 'src') && node.childNodes.length).length, 0, 'CSP: no inline scripts');
  }
});
