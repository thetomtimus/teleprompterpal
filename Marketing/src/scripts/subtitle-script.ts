import { decodeSubtitleFile, parseSubtitles, subtitleExample, subtitleFileLimit, subtitleLimit, subtitlesToScript, type SubtitleResult } from '../lib/subtitle-script';
import { countWords } from '../lib/speech-time';

const form = document.querySelector<HTMLFormElement>('#subtitle-converter');
if (form) {
  const source = form.querySelector<HTMLTextAreaElement>('#subtitle-source')!;
  const output = form.querySelector<HTMLTextAreaElement>('#subtitle-result')!;
  const fileInput = form.querySelector<HTMLInputElement>('#subtitle-file')!;
  const button = (id: string) => form!.querySelector<HTMLButtonElement>(`#${id}`)!;
  const element = (id: string) => form!.querySelector<HTMLElement>(`#${id}`)!;
  const copy = button('copy-subtitle-script');
  const download = button('download-subtitle-script');
  const status = element('subtitle-status');
  const error = element('subtitle-error');
  const format = new Intl.NumberFormat('en');
  let parsed: SubtitleResult = parseSubtitles('');
  let revision = 0;
  let announcement: ReturnType<typeof setTimeout>;
  let copying = false;

  function update(parse = false) {
    if (parse) parsed = parseSubtitles(source.value);
    output.value = subtitlesToScript(parsed, {
      captionBreaks: form!.querySelector<HTMLInputElement>('[name="caption-layout"]:checked')!.value === 'captions',
      speakerNames: form!.querySelector<HTMLInputElement>('#speaker-names')!.checked,
    });
    copy.disabled = !output.value || copying;
    download.disabled = !output.value;
    button('clear-subtitles').disabled = !source.value;
    source.setAttribute('aria-invalid', String(Boolean(parsed.error)));
    error.textContent = parsed.error ?? '';
    error.hidden = !parsed.error;
    element('subtitle-source-count').textContent = `${format.format(source.value.length)} / 300,000 characters`;
    element('subtitle-result-count').textContent = `${format.format(countWords(output.value))} words`;
    element('subtitle-summary').textContent = parsed.error ? 'Fix the subtitle input to create a complete script.'
      : !source.value.trim() ? 'Your script will appear here when captions are added.'
      : !output.value ? 'Captions were found, but they contain no readable text.'
      : `${format.format(parsed.cues.length)} ${parsed.format ?? ''} caption${parsed.cues.length === 1 ? '' : 's'} converted. Timestamps and cue numbers removed.`;
    copy.textContent = 'Copy script';
    clearTimeout(announcement);
    status.textContent = '';
    announcement = setTimeout(() => { status.textContent = parsed.error ? 'Check the subtitle input. Export is unavailable until it is corrected.' : output.value ? `Script ready. ${element('subtitle-result-count').textContent}.` : ''; }, 500);
  }
  function changed() {
    revision++;
    fileInput.value = '';
    element('subtitle-file-name').textContent = '';
    update(true);
  }
  function focusSource() { source.focus(); source.setSelectionRange(0, 0); source.scrollTop = 0; }
  form.addEventListener('submit', event => event.preventDefault());
  source.addEventListener('input', changed);
  form.querySelectorAll<HTMLInputElement>('[name="caption-layout"], #speaker-names').forEach(control => control.addEventListener('change', () => update()));
  button('load-subtitle-example').addEventListener('click', () => { source.value = subtitleExample; changed(); focusSource(); });
  button('clear-subtitles').addEventListener('click', () => { source.value = ''; changed(); focusSource(); });
  button('choose-subtitle-file').addEventListener('click', () => fileInput.click());
  fileInput.addEventListener('change', async () => {
    const file = fileInput.files?.[0];
    if (!file) return;
    const version = ++revision;
    clearTimeout(announcement);
    status.textContent = 'Reading your subtitle file…';
    try {
      if (!/\.(srt|vtt)$/i.test(file.name)) throw new Error('Choose an .srt or .vtt subtitle file.');
      if (file.size > subtitleFileLimit) throw new Error('That file is larger than 2 MB. Convert a smaller subtitle file.');
      let text: string;
      try { text = decodeSubtitleFile(await file.arrayBuffer()); }
      catch { throw new Error('The file’s text encoding could not be read. Save it as UTF-8 and try again.'); }
      if (version !== revision) return;
      if (text.length > subtitleLimit) throw new Error('That file exceeds 300,000 characters. Convert it in smaller sections.');
      source.value = text;
      update(true);
      element('subtitle-file-name').textContent = file.name;
      focusSource();
    } catch (cause) {
      if (version !== revision) return;
      status.textContent = `${cause instanceof Error ? cause.message : 'The file could not be read. Try choosing it again.'} ${source.value ? 'Your previous subtitles are still here.' : ''}`;
    } finally { if (version === revision) fileInput.value = ''; }
  });
  copy.addEventListener('click', async () => {
    const text = output.value;
    if (!text || copying) return;
    copying = true; copy.disabled = true; clearTimeout(announcement); status.textContent = '';
    try {
      await navigator.clipboard.writeText(text);
      if (text === output.value) { copy.textContent = 'Copied'; status.textContent = 'Script copied. Paste it into your editor or teleprompter.'; }
    } catch {
      output.focus(); output.select();
      status.textContent = 'Copy was unavailable. Your script is selected; use your device’s Copy command, or download the text file.';
    } finally { copying = false; copy.disabled = !output.value; }
  });
  download.addEventListener('click', () => {
    if (!output.value) return;
    const url = URL.createObjectURL(new Blob([output.value], { type: 'text/plain;charset=utf-8' }));
    const link = document.createElement('a'); link.href = url; link.download = 'subtitle-script.txt'; document.body.append(link); link.click(); link.remove();
    setTimeout(() => URL.revokeObjectURL(url), 1000);
    clearTimeout(announcement); status.textContent = 'Text file prepared. Check your downloads for subtitle-script.txt.';
  });
  form.querySelector<HTMLFieldSetElement>('fieldset')!.disabled = false;
  update();
}
