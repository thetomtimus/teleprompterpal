import { helpArticles, helpPath } from '../data/help.mjs';
export const origin = 'https://teleprompterpal.com';
export const locales = [
  { code: 'en', path: '', name: 'English', short: 'EN', language: 'Language' },
  { code: 'es', path: 'es', name: 'Español', short: 'ES', language: 'Idioma' },
  { code: 'de', path: 'de', name: 'Deutsch', short: 'DE', language: 'Sprache' },
  { code: 'fr', path: 'fr', name: 'Français', short: 'FR', language: 'Langue' },
  { code: 'pt-BR', path: 'pt-br', name: 'Português (Brasil)', short: 'PT', language: 'Idioma' },
  { code: 'ja', path: 'ja', name: '日本語', short: 'JA', language: '言語' },
  { code: 'ko', path: 'ko', name: '한국어', short: 'KO', language: '언어' },
];
// Only complete, reviewed pages belong here. Never create English fallback URLs.
export const translatedRoutes = ['/', '/pricing/', '/help/', ...helpArticles.map(article => helpPath(article.slug))];
export function localizedPath(route, locale) {
  return locale.path ? `/${locale.path}${route}` : route;
}
