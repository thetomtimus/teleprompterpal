/** Local estimates for scripts written with spaces between words. */
export function countWords(text: string): number {
  return text.match(/\p{N}+(?:[.,]\p{N}+)+|[\p{L}\p{N}]+(?:['’\-‐‑][\p{L}\p{N}]+)*/gu)?.length ?? 0;
}

export function speechSeconds(words: number, wpm: number, pauseSeconds = 0): number {
  if (!Number.isFinite(words) || words < 0 || !Number.isFinite(wpm) || wpm <= 0
    || !Number.isFinite(pauseSeconds) || pauseSeconds < 0) return NaN;
  return words / wpm * 60 + pauseSeconds;
}

export function wordBudget(seconds: number, wpm: number, pauseSeconds = 0): number {
  if (!Number.isFinite(seconds) || seconds < 0 || !Number.isFinite(wpm) || wpm <= 0
    || !Number.isFinite(pauseSeconds) || pauseSeconds < 0) return NaN;
  return Math.floor(Math.max(0, seconds - pauseSeconds) / 60 * wpm);
}

export function measuredWpm(words: number, seconds: number): number {
  if (!Number.isFinite(words) || words <= 0 || !Number.isFinite(seconds) || seconds <= 0) return NaN;
  return Math.round(words / seconds * 60);
}

/** Round once before splitting, so 59.8 seconds becomes 1:00, never 0:60. */
export function formatDuration(seconds: number): string {
  if (!Number.isFinite(seconds) || seconds < 0) return '—';
  const rounded = Math.round(seconds);
  const hours = Math.floor(rounded / 3600);
  const minutes = Math.floor(rounded / 60) % 60;
  const remainder = String(rounded % 60).padStart(2, '0');
  return hours ? `${hours}:${String(minutes).padStart(2, '0')}:${remainder}` : `${minutes}:${remainder}`;
}

export const speedPassage = 'Before you press record, take a moment to decide what you want your audience to remember. A clear video begins with one useful idea. Write it in words you would actually say to a friend. Read the script aloud, and listen for any sentence that feels awkward. Shorten it, then try again. Leave yourself room to breathe between thoughts. You do not need to rush through every line or fill every silence. Look toward the lens, let your voice settle, and speak at a comfortable pace. The goal is to help someone understand your idea, one natural sentence at a time.';

export const sampleScript = 'A good video starts before you press record.\n\nChoose one idea you want your audience to remember. Write it in your own words, then read it aloud. If a sentence feels awkward, shorten it. If you need a breath, leave room for one.\n\nYou do not need to memorize the whole script. You need to know what you mean and give yourself time to say it.\n\nTake a breath, look toward the lens, and begin.';
