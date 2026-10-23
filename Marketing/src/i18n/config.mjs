export const origin = 'https://teleprompterpal.com';
export const locales = [
  { code: 'en', path: '', name: 'English', short: 'EN', language: 'Language' },
  { code: 'es', path: 'es', name: 'Español', short: 'ES', language: 'Idioma' },
  { code: 'de', path: 'de', name: 'Deutsch', short: 'DE', language: 'Sprache' },
  { code: 'fr', path: 'fr', name: 'Français', short: 'FR', language: 'Langue' },
  { code: 'pt-BR', path: 'pt-br', name: 'Português (Brasil)', short: 'PT', language: 'Idioma' },
];
// Only complete, reviewed pages belong here. Never create English fallback URLs.
export const translatedRoutes = ['/', '/pricing/'];
export function localizedPath(route, locale) {
  return locale.path ? `/${locale.path}${route}` : route;
}
