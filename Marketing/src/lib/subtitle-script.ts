export interface SubtitleCue { start: number; end: number; text: string; }
export interface SubtitleResult { format: 'SRT' | 'WebVTT' | null; cues: SubtitleCue[]; error: string | null; }
export interface SubtitleOptions { captionBreaks: boolean; speakerNames: boolean; }
export const subtitleLimit = 300000;
export const subtitleFileLimit = 2 * 1024 * 1024;
export const subtitleExample = '1\n00:00:01,000 --> 00:00:04,000\nBefore you press record,\nchoose one idea.\n\n2\n00:00:04,500 --> 00:00:08,000\nWrite it in words\nyou would actually say.\n\n3\n00:00:08,500 --> 00:00:11,000\nTake a breath, look toward the lens,\nand begin.';
const timestamp = '(?:\\d{2,}:)?\\d{2}:\\d{2}[.,]\\d{3}';
const timingLine = new RegExp(`^(${timestamp})[ \\t]+-->[ \\t]+(${timestamp})(?:[ \\t]+[^\\n]*)?$`);

function seconds(value: string): number | null {
  const parts = value.replace(',', '.').split(':');
  const sec = Number(parts.pop());
  const min = Number(parts.pop());
  const hours = Number(parts.pop() ?? 0);
  const total = hours * 3600 + min * 60 + sec;
  return Number.isFinite(total) && min < 60 && sec < 60 ? total : null;
}

/** Parse blocks before extracting text, so numbers in spoken dialogue survive. */
export function parseSubtitles(source: string): SubtitleResult {
  const empty: SubtitleResult = { format: null, cues: [], error: null };
  if (!source.trim()) return empty;
  if (source.length > subtitleLimit) return { ...empty, error: 'These subtitles are too long. Convert up to 300,000 characters at a time.' };
  if (source.includes('\u0000') || source.includes('\ufffd')) return { ...empty, error: 'Some text could not be read. Save your subtitle file as UTF-8 and try again.' };
  const normalized = source.replace(/^\uFEFF/, '').replace(/\r\n?/g, '\n').trim();
  const blocks = normalized.split(/\n(?:[ \t]*\n)+/u);
  const result: SubtitleResult = { format: /^WEBVTT(?:[ \t]|\n|$)/.test(normalized) ? 'WebVTT' : null, cues: [], error: null };
  for (let index = 0; index < blocks.length; index++) {
    const lines = blocks[index].split('\n').map(line => line.trim());
    if (index === 0 && /^WEBVTT(?:[ \t]|$)/.test(lines[0])) {
      if (lines.slice(1).some(line => line.includes('-->'))) {
        result.error = 'Add a blank line after the WEBVTT header, before the first caption.';
        break;
      }
      continue;
    }
    if (/^(?:NOTE(?:[ \t].*)?|STYLE|REGION)$/.test(lines[0]) && result.format === 'WebVTT') continue;
    let position = 0;
    let match = timingLine.exec(lines[0]);
    if (!match && lines.length > 1 && !lines[0].includes('-->')) { position = 1; match = timingLine.exec(lines[1]); }
    const fail = () => { result.error = `Couldn’t read caption block ${index + 1}. Check its time range, caption text and blank lines between captions.`; };
    if (!match) { fail(); break; }
    const start = seconds(match[1]);
    const end = seconds(match[2]);
    const payload = lines.slice(position + 1).join('\n');
    if (start === null || end === null || end <= start || !payload || payload.includes('-->')) { fail(); break; }
    result.format ??= match[1].includes(',') ? 'SRT' : 'WebVTT';
    result.cues.push({ start, end, text: payload });
  }
  if (!result.error && !result.cues.length) result.error = 'No captions found. Paste SRT or WebVTT subtitles with time ranges and caption text.';
  return result;
}

const entities: Record<string, string> = { amp: '&', lt: '<', gt: '>', nbsp: ' ', quot: '"', apos: "'", lrm: '\u200e', rlm: '\u200f' };
function decodeEntities(text: string): string {
  return text.replace(/&(#x[\da-f]+|#\d+|amp|lt|gt|nbsp|quot|apos|lrm|rlm);/gi, (original, code: string) => {
    if (!code.startsWith('#')) return entities[code.toLowerCase()] ?? original;
    const point = code[1].toLowerCase() === 'x' ? parseInt(code.slice(2), 16) : Number(code.slice(1));
    return point > 0 && point <= 0x10ffff && !(point >= 0xd800 && point <= 0xdfff) ? String.fromCodePoint(point) : original;
  });
}

export function subtitleText(payload: string, speakerNames: boolean): string {
  return decodeEntities(payload
    .replace(/<v(?:\.[\w.-]+)*[ \t]+([^<>]+)>/gi, (_, name: string) => speakerNames ? `${name.trim()}: ` : '')
    .replace(/<\/v>/gi, ' ')
    .replace(new RegExp(`<${timestamp}>`, 'g'), '')
    .replace(/<br\s*\/?\s*>/gi, '\n')
    .replace(/<\/?(?:b|i|u|ruby|rt|c|lang|font)(?=[\s.>])[^>]*>/gi, ''))
    .replace(/\s+/gu, ' ').trim();
}

export function subtitlesToScript(result: SubtitleResult, options: SubtitleOptions): string {
  if (result.error) return '';
  return result.cues.map(cue => subtitleText(cue.text, options.speakerNames)).filter(Boolean).join(options.captionBreaks ? '\n\n' : ' ');
}

/** Decode without guessing legacy encodings or silently replacing characters. */
export function decodeSubtitleFile(bytes: ArrayBuffer): string {
  const start = new Uint8Array(bytes, 0, Math.min(2, bytes.byteLength));
  const encoding = start[0] === 0xff && start[1] === 0xfe ? 'utf-16le' : start[0] === 0xfe && start[1] === 0xff ? 'utf-16be' : 'utf-8';
  return new TextDecoder(encoding, { fatal: true }).decode(bytes);
}
