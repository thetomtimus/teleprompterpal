export interface CleanerOptions {
  paragraphs: boolean;
  extraSpaces: boolean;
  readingChunks: boolean;
}

export const defaultCleanerOptions: CleanerOptions = {
  paragraphs: true,
  extraSpaces: true,
  readingChunks: false,
};

export const cleanerExample = 'Before you press record,\nchoose   one idea you want\nyour audience to remember.\n\nWrite it in words you would actually say.\nRead your script aloud,   and leave\nyourself room to breathe.\n\nYou don’t need to rush.\nTake a breath, look toward the lens,\nand begin.';

/** Add paragraph breaks only. Never rewrite words or punctuation. */
function readingChunks(paragraph: string): string {
  const sentences = new Intl.Segmenter('en', { granularity: 'sentence' }).segment(paragraph);
  const chunks: string[] = [];
  let current = '';
  let length = 0;
  for (const sentence of sentences) {
    const words = sentence.segment.trim().split(/\s+/u);
    if (current && length + words.length > 32) {
      chunks.push(current);
      current = '';
      length = 0;
    }
    // A long sentence still needs a readable chunk, without removing any words.
    for (const word of words) {
      if (length === 32) {
        chunks.push(current);
        current = '';
        length = 0;
      }
      current += `${current ? ' ' : ''}${word}`;
      length++;
    }
  }
  if (current) chunks.push(current);
  return chunks.join('\n\n');
}

export function cleanScript(source: string, options: CleanerOptions = defaultCleanerOptions): string {
  const normalized = source.replace(/\r\n?/g, '\n').replace(/\u2028/g, '\n').replace(/\u2029/g, '\n\n');
  const lines = normalized.split('\n').map(line => {
    const trimmed = line.trim();
    return options.extraSpaces ? trimmed.replace(/[\t \u00a0\u202f]+/g, ' ') : trimmed;
  }).join('\n').trim();
  if (!lines) return '';
  const blocks = options.paragraphs ? lines.split(/\n(?:[\t \u00a0\u202f]*\n)+/u) : [lines];
  return blocks.map(block => {
    const joined = block.replace(/\n+/g, ' ');
    return options.readingChunks ? readingChunks(joined) : joined;
  }).join('\n\n');
}

export function paragraphCount(text: string): number {
  return text.trim() ? text.trim().split(/\n(?:[\t \u00a0\u202f]*\n)+/u).length : 0;
}
