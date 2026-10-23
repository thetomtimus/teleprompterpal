import { readFile, writeFile, mkdir } from 'node:fs/promises';
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { parse, parseFragment, serialize } from 'parse5';
import QRCode from 'qrcode';
import { locales, origin, translatedRoutes, localizedPath } from '../src/i18n/config.mjs';

const root = fileURLToPath(new URL('..', import.meta.url));
const catalogDirectory = resolve(root, 'src/i18n');
const attributes = new Set(['alt', 'title', 'aria-label', 'placeholder']);
const metadata = new Set(['description', 'og:title', 'og:description', 'og:image:alt', 'twitter:title', 'twitter:description', 'twitter:image:alt']);
const unchanged = new Set(['teleprompter', 'pal', 'Pro', 'Teleprompter Pal', 'you@example.com']);
export const normalize = value => value.replace(/\s+/g, ' ').trim();
const translatable = value => /[A-Za-z]/.test(value) && !unchanged.has(normalize(value));
const attr = (node, name) => node.attrs?.find(item => item.name === name)?.value;
function set(node, name, value) {
  const existing = node.attrs?.find(item => item.name === name);
  if (existing) existing.value = value;
  else (node.attrs ??= []).push({ name, value });
}
function walk(node, callback, blocked = false) {
  blocked ||= ['script', 'style', 'svg'].includes(node.tagName) || attr(node, 'translate') === 'no';
  callback(node, blocked);
  for (const child of node.childNodes ?? []) walk(child, callback, blocked);
}
function slots(document, callback) {
  walk(document, (node, blocked) => {
    if (blocked) return;
    if (node.nodeName === '#text' && translatable(node.value)) callback(node.value, value => { node.value = value; });
    for (const item of node.attrs ?? []) {
      if (attributes.has(item.name) && translatable(item.value)) callback(item.value, value => { item.value = value; });
      if (node.tagName === 'meta' && item.name === 'content' && metadata.has(attr(node, 'name') ?? attr(node, 'property'))) callback(item.value, value => { item.value = value; });
    }
  });
}
export function extractStrings(html) {
  const strings = new Set();
  slots(parse(html, { scriptingEnabled: false }), value => strings.add(normalize(value)));
  return [...strings];
}
async function dynamicMessages() {
  const messages = new Set();
  for (const path of ['src/pages/index.astro', 'src/pages/pricing.astro', 'src/components/EarlyAccessForm.astro']) {
    const source = await readFile(resolve(root, path), 'utf8');
    for (const match of source.matchAll(/\bt\('((?:\\.|[^'\\])*)'\)/g)) {
      // The message format permits literal apostrophes and escaped newlines only.
      messages.add(normalize(match[1].replace(/\\n/g, '\n').replace(/\\'/g, "'")));
    }
  }
  return [...messages];
}
export function validateCatalog(catalog, required, locale) {
  const missing = required.filter(key => typeof catalog[key] !== 'string' || !catalog[key].trim());
  if (missing.length) throw new Error(`${locale}: ${missing.length} missing translations. Run npm run translations:extract and update src/i18n/${locale}.json. First missing: ${missing.slice(0, 5).join(' | ')}`);
  for (const key of required) {
    if (/<\/?[a-z][^>]*>/i.test(catalog[key])) throw new Error(`${locale}: translations must be text, not HTML: ${key}`);
    const protectedTokens = key.match(/\$\d+(?:[.,]\d+)*|\b\d+(?:\.\d+)?%|\bMP4\b|Teleprompter Pal/g) ?? [];
    for (const token of protectedTokens) if (!catalog[key].includes(token)) throw new Error(`${locale}: translation changed protected product/price token ${token}: ${key}`);
  }
}
export async function localizeHtml(html, route, locale, catalog, messages = []) {
  const document = parse(html, { scriptingEnabled: false });
  const t = source => {
    const key = normalize(source);
    if (!translatable(key)) return source;
    if (!catalog[key]) throw new Error(`Missing ${locale.code} translation: ${key}`);
    return source.replace(/\S[\s\S]*\S|\S/, () => catalog[key]);
  };
  if (locale.code !== 'en') slots(document, (source, write) => write(t(source)));
  let head, body;
  const qrNodes = [];
  walk(document, node => {
    if (node.tagName === 'head') head = node;
    if (node.tagName === 'body') body = node;
    if (node.tagName === 'html') set(node, 'lang', locale.code);
    if (node.tagName === 'link' && attr(node, 'rel') === 'canonical') set(node, 'href', origin + localizedPath(route, locale));
    if (node.tagName === 'meta' && attr(node, 'property') === 'og:url') set(node, 'content', origin + localizedPath(route, locale));
    if (locale.code !== 'en' && node.tagName === 'meta' && attr(node, 'name') === 'msvalidate.01') node.parentNode.childNodes = node.parentNode.childNodes.filter(item => item !== node);
    if (attr(node, 'data-language-summary') !== undefined) set(node, 'aria-label', `${locale.language}: ${locale.name}`);
    if (attr(node, 'data-language-nav') !== undefined) set(node, 'aria-label', locale.language);
    if (attr(node, 'data-language-short') !== undefined) node.childNodes = parseFragment(locale.short).childNodes;
    if (attr(node, 'data-language-label') !== undefined) node.childNodes = parseFragment(locale.language).childNodes;
    const languageCode = attr(node, 'data-language-code');
    if (languageCode) {
      node.attrs = node.attrs.filter(item => item.name !== 'aria-current');
      if (languageCode === locale.code) set(node, 'aria-current', 'true');
      const check = node.childNodes?.find(child => attr(child, 'class') === 'language-selected');
      if (check) check.childNodes = languageCode === locale.code
        ? parseFragment('<svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true"><path d="m5 12 4 4L19 6"/></svg>').childNodes : [];
    }
    if (attr(node, 'data-localized-qr') !== undefined) qrNodes.push(node);
    if (locale.code !== 'en' && node.tagName === 'a' && !languageCode) {
      const href = attr(node, 'href');
      if (!href || href.startsWith('#') || href.startsWith('mailto:')) return;
      const url = new URL(href, origin);
      if (url.origin === origin && translatedRoutes.includes(url.pathname)) set(node, 'href', localizedPath(url.pathname, locale) + url.search + url.hash);
      else if (url.origin === origin || url.hostname === 'freeteleprompteronline.com') {
        set(node, 'hreflang', 'en');
        const compact = attr(node.parentNode, 'class') === 'desktop-nav';
        set(node, 'title', catalog['in English']);
        const suffix = compact ? ' (EN)' : ` (${catalog['in English']})`;
        // Keep the label in one text run: text-link uses inline-flex around its icon.
        const lastText = node.childNodes.filter(child => child.nodeName === '#text').at(-1);
        if (lastText) lastText.value = lastText.value.trimEnd() + suffix + ' ';
        else node.childNodes.push({ nodeName: '#text', value: suffix, parentNode: node });
      }
    }
  });
  if (!head || !body) throw new Error('Expected a complete HTML document');
  const alternateMarkup = locales.map(item => `<link rel="alternate" hreflang="${item.code}" href="${origin + localizedPath(route, item)}">`).join('')
    + `<link rel="alternate" hreflang="x-default" href="${origin + route}">`;
  head.childNodes.push(...parseFragment(alternateMarkup).childNodes);
  if (locale.code !== 'en') {
    const holder = parseFragment('<div hidden data-translated-messages></div>').childNodes[0];
    set(holder, 'data-translated-messages', JSON.stringify(Object.fromEntries(messages.map(key => [key, catalog[key]]))));
    body.childNodes.push(holder);
    const svg = await QRCode.toString(origin + localizedPath('/pricing/', locale), { type: 'svg', errorCorrectionLevel: 'M', margin: 3, width: 168, color: { dark: '#0f0f0f', light: '#ffffff' } });
    for (const node of qrNodes) node.childNodes = parseFragment(svg).childNodes;
  }
  return serialize(document);
}
export async function buildTranslations({ extractOnly = false } = {}) {
  const pages = new Map();
  const required = new Set(['in English']);
  for (const route of translatedRoutes) {
    const html = await readFile(resolve(root, `dist${route}index.html`), 'utf8');
    pages.set(route, html);
    extractStrings(html).forEach(key => required.add(key));
  }
  const messages = await dynamicMessages();
  messages.forEach(key => required.add(key));
  const keys = [...required];
  if (extractOnly) {
    await mkdir(resolve(root, '.translations'), { recursive: true });
    const pending = {};
    for (const locale of locales.slice(1)) {
      const catalog = JSON.parse(await readFile(resolve(catalogDirectory, `${locale.code}.json`), 'utf8').catch(() => '{}'));
      pending[locale.code] = keys.filter(key => !catalog[key]);
    }
    await writeFile(resolve(root, '.translations/source.json'), JSON.stringify({ routes: translatedRoutes, keys, dynamic: messages, pending }, null, 2) + '\n');
    console.log(`Extracted ${keys.length} source strings to .translations/source.json. Missing: ${Object.entries(pending).map(([code, list]) => `${code} ${list.length}`).join(', ')}`);
    return;
  }
  const catalogs = new Map([['en', {}]]);
  for (const locale of locales.slice(1)) {
    const catalog = JSON.parse(await readFile(resolve(catalogDirectory, `${locale.code}.json`), 'utf8'));
    validateCatalog(catalog, keys, locale.code);
    catalogs.set(locale.code, catalog);
  }
  for (const [route, html] of pages) for (const locale of locales) {
    const directory = resolve(root, `dist${localizedPath(route, locale)}`);
    await mkdir(directory, { recursive: true });
    await writeFile(resolve(directory, 'index.html'), await localizeHtml(html, route, locale, catalogs.get(locale.code), messages));
  }
  console.log(`Published translations: ${translatedRoutes.length} pages × ${locales.length} locales; ${keys.length} checked strings.`);
}
if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) await buildTranslations({ extractOnly: process.argv.includes('--extract') });
