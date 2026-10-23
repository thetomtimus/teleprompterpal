import assert from 'node:assert/strict';
import test from 'node:test';
import { decodeSubtitleFile, parseSubtitles, subtitleExample, subtitlesToScript, subtitleText } from '../src/lib/subtitle-script.ts';
const options = { captionBreaks: false, speakerNames: false };

test('SRT extracts full dialogue, keeps spoken numbers and joins wrapped caption lines', () => {
  const parsed = parseSubtitles('\uFEFF1\r\n00:00:01,000 --> 00:00:04,000\r\n2026\r\nStart with one idea.\r\n\r\n2\r\n00:00:04,500 --> 00:00:08,000\r\nDon’t change 12.50% or well-written words.');
  assert.equal(parsed.error, null);
  assert.equal(parsed.format, 'SRT');
  assert.equal(parsed.cues.length, 2);
  assert.equal(subtitlesToScript(parsed, options), '2026 Start with one idea. Don’t change 12.50% or well-written words.');
  assert.match(subtitlesToScript(parsed, { ...options, captionBreaks: true }), /idea\.\n\nDon’t/);
});

test('WebVTT removes metadata, IDs, settings, inline timestamps and common markup', () => {
  const parsed = parseSubtitles('WEBVTT example\nLanguage: en\n\nNOTE private note\nIgnore this comment.\n\nSTYLE\n::cue { color: lime; }\n\nREGION\nid:bottom\n\nintro\n00:01.000 --> 00:04.000 align:start position:10%\n<v Alex><b>Hello</b> &amp; welcome.</v>\n\nnext\n00:00:04.500 --> 00:00:06.000\n<c.caption><00:00:05.000>Let’s begin.</c>');
  assert.equal(parsed.error, null);
  assert.equal(parsed.format, 'WebVTT');
  assert.equal(parsed.cues.length, 2);
  assert.equal(subtitlesToScript(parsed, options), 'Hello & welcome. Let’s begin.');
  assert.equal(subtitlesToScript(parsed, { ...options, speakerNames: true }), 'Alex: Hello & welcome. Let’s begin.');
});

test('preserves repetitions, overlap, Unicode and non-speech descriptions by default', () => {
  const parsed = parseSubtitles('1\n00:00:01,000 --> 00:00:04,000\n[Music] Café. 你好。안녕하세요.\n\n2\n00:00:02,000 --> 00:00:05,000\n[Music] Café. 你好。안녕하세요.');
  assert.equal(parsed.error, null);
  assert.equal(subtitlesToScript(parsed, options), '[Music] Café. 你好。안녕하세요. [Music] Café. 你好。안녕하세요.');
});

test('one invalid block withholds the whole export instead of silently dropping dialogue', () => {
  const valid = '1\n00:00:01,000 --> 00:00:04,000\nHello.';
  for (const broken of ['2\n00:00:99,000 --> 00:01:04,000\nBad seconds.', '2\n00:00:04,000 --> 00:00:01,000\nBackwards.', '2\n00:00:04,000 --> 00:00:04,000\nNo duration.', '2\nThis is not a time range.\nDo not drop this text.', '2\n00:00:04,000 --> 00:00:08,000']) {
    const parsed = parseSubtitles(valid + '\n\n' + broken);
    assert.ok(parsed.error);
    assert.equal(subtitlesToScript(parsed, options), '');
  }
  assert.ok(parseSubtitles(valid + '\n2\n00:00:04,500 --> 00:00:08,000\nMissing a blank line.').error);
});

test('rejects plain transcripts, empty headers, broken headers and unreadable encoded content', () => {
  assert.equal(parseSubtitles('').error, null);
  for (const source of ['Plain transcript without timecodes.', 'WEBVTT', 'WEBVTT\n00:01.000 --> 00:02.000\nHeader needs a blank line.', '\u0000text', 'text\ufffd']) assert.ok(parseSubtitles(source).error);
});

test('literal caption text stays inert and entities decode once', () => {
  const input = '<i>Hello</i><br>world &quot;yes&quot; &#x1F44B; &#233; &lt;b&gt;literal&lt;/b&gt; <img src=x onerror=alert(1)> &amp;lt;';
  assert.equal(subtitleText(input, false), 'Hello world "yes" 👋 é <b>literal</b> <img src=x onerror=alert(1)> &lt;');
  assert.equal(subtitleText('<v.first Alex>Hello</v><v Sam>Goodbye</v>', true), 'Alex: Hello Sam: Goodbye');
  assert.equal(subtitleText('A &#0; &#xD800; &#x110000;', false), 'A &#0; &#xD800; &#x110000;');
});

test('decodes UTF-8 and BOM-marked UTF-16 without guessing or replacing invalid bytes', () => {
  const utf8 = new TextEncoder().encode('Café 👋');
  assert.equal(decodeSubtitleFile(utf8.buffer), 'Café 👋');
  assert.equal(decodeSubtitleFile(new Uint8Array([0xff, 0xfe, 0x48, 0, 0x69, 0]).buffer), 'Hi');
  assert.equal(decodeSubtitleFile(new Uint8Array([0xfe, 0xff, 0, 0x48, 0, 0x69]).buffer), 'Hi');
  assert.throws(() => decodeSubtitleFile(new Uint8Array([0xc3, 0x28]).buffer));
});

test('example yields a complete useful script and input limit is enforced', () => {
  const parsed = parseSubtitles(subtitleExample);
  assert.equal(parsed.cues.length, 3);
  assert.equal(parsed.error, null);
  assert.equal(subtitlesToScript(parsed, options), 'Before you press record, choose one idea. Write it in words you would actually say. Take a breath, look toward the lens, and begin.');
  assert.ok(parseSubtitles('x'.repeat(300001)).error);
});

test('large valid subtitle files preserve every cue in source order', () => {
  const source = Array.from({ length: 4000 }, (_, i) => `${i + 1}\n00:00:01,000 --> 00:00:04,000\nLine ${i + 1}.`).join('\n\n');
  assert.ok(source.length < 300000);
  const parsed = parseSubtitles(source);
  assert.equal(parsed.error, null);
  assert.equal(parsed.cues.length, 4000);
  const output = subtitlesToScript(parsed, options);
  assert.ok(output.startsWith('Line 1. Line 2.'));
  assert.ok(output.endsWith('Line 3999. Line 4000.'));
});
