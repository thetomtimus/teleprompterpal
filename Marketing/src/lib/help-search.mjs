export function normalizeHelpSearch(value) {
  return value.normalize('NFKD').replace(/\p{M}/gu, '').toLocaleLowerCase().replace(/\s+/g, ' ').trim();
}
export function matchesHelpSearch(text, query) {
  const haystack = normalizeHelpSearch(text);
  return normalizeHelpSearch(query).split(' ').filter(Boolean).every(term => haystack.includes(term));
}
