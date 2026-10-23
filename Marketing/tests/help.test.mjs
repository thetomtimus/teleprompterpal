import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile, stat } from 'node:fs/promises';
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

test('every walkthrough ships its media with translated descriptions and user-controlled playback', async () => {
  const checkedAssets = new Set();
  const attr = (node, key) => node.attrs?.find(a => a.name === key)?.value;
  const descendants = node => [node, ...(node.childNodes ?? []).flatMap(descendants)];
  const text = node => descendants(node).filter(n => n.nodeName === '#text').map(n => n.value).join('');
  for (const locale of locales) for (const article of helpArticles) {
    const catalog = locale.code === 'en' ? {} : JSON.parse(await readFile(new URL(`../src/i18n/${locale.code}.json`, import.meta.url)));
    const html = await readFile(new URL(`../dist${localizedPath(helpPath(article.slug), locale)}index.html`, import.meta.url), 'utf8');
    const nodes = descendants(parse(html));
    for (const section of article.sections.filter(section => section.media)) {
      const { image, video, caption } = section.media;
      const context = `${locale.code}/${article.slug}#${section.id}`;
      const sectionNodes = descendants(nodes.find(node => attr(node, 'id') === section.id));
      const figure = sectionNodes.find(node => node.tagName === 'figure');
      assert.ok(figure, `${context}: illustration accompanies its instructions`);
      const mediaNodes = descendants(figure);
      const description = catalog[caption] ?? caption;
      if (locale.code !== 'en') assert.ok(catalog[caption], `${context}: translated caption`);
      assert.ok(text(mediaNodes.find(node => node.tagName === 'figcaption')).startsWith(description), context);
      if (video) {
        const player = mediaNodes.find(node => node.tagName === 'video');
        assert.equal(attr(player, 'poster'), image, context);
        assert.equal(attr(player, 'aria-label'), description, context);
        assert.equal(attr(player, 'preload'), 'none', `${context}: avoid fetching videos before play`);
        assert.notEqual(attr(player, 'controls'), undefined, context);
        assert.notEqual(attr(player, 'playsinline'), undefined, context);
        assert.equal(attr(player, 'autoplay'), undefined, `${context}: no unsolicited motion`);
        assert.ok(mediaNodes.some(node => node.tagName === 'source' && attr(node, 'src') === video && attr(node, 'type') === 'video/mp4'), context);
        assert.ok(mediaNodes.some(node => node.tagName === 'a' && attr(node, 'href') === video && text(node) === (catalog['Open the demonstration video'] ?? 'Open the demonstration video')), `${context}: accessible full-size fallback`);
      } else {
        assert.ok(mediaNodes.some(node => node.tagName === 'img' && attr(node, 'src') === image && attr(node, 'alt') === description), context);
        assert.ok(mediaNodes.some(node => node.tagName === 'a' && attr(node, 'href') === image), `${context}: full-size screenshot`);
      }
      for (const asset of [image, video].filter(Boolean)) if (!checkedAssets.has(asset)) {
        assert.ok((await stat(new URL(`../dist${asset}`, import.meta.url))).size > 0, `${context}: deployed asset exists`);
        checkedAssets.add(asset);
      }
    }
  }
});
