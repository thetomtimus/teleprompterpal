import { cleanerExample, cleanScript, paragraphCount } from '../lib/script-cleaner';
import { countWords } from '../lib/speech-time';

const form = document.querySelector<HTMLFormElement>('#script-cleaner');
if (form) {
  const source = form.querySelector<HTMLTextAreaElement>('#original-script')!;
  const result = form.querySelector<HTMLTextAreaElement>('#cleaned-script')!;
  const fields = form.querySelector<HTMLFieldSetElement>('fieldset')!;
  const getButton = (id: string) => form.querySelector<HTMLButtonElement>(`#${id}`)!;
  const getText = (id: string) => form.querySelector<HTMLElement>(`#${id}`)!;
  const copy = getButton('copy-cleaned');
  const download = getButton('download-cleaned');
  const clear = getButton('clear-original');
  const status = getText('cleaner-status');
  const numberFormat = new Intl.NumberFormat('en');
  let announcement: ReturnType<typeof setTimeout>;
  let copyInProgress = false;

  const counted = (n: number, noun: string) => `${numberFormat.format(n)} ${noun}${n === 1 ? '' : 's'}`;

  function update() {
    const paragraphs = form!.querySelector<HTMLInputElement>('[name="paragraph-mode"]:checked')!.value === 'keep';
    const extraSpaces = form!.querySelector<HTMLInputElement>('#clean-spaces')!.checked;
    const readingChunks = form!.querySelector<HTMLInputElement>('#reading-chunks')!.checked;
    result.value = cleanScript(source.value, { paragraphs, extraSpaces, readingChunks });
    const ready = result.value.length > 0;
    copy.disabled = !ready || copyInProgress;
    download.disabled = !ready;
    clear.disabled = source.value.length === 0;
    getText('original-count').textContent = counted(countWords(source.value), 'word');
    getText('original-limit').textContent = `${numberFormat.format(source.value.length)} / 300,000 characters`;
    getText('cleaned-count').textContent = `${counted(countWords(result.value), 'word')} · ${counted(paragraphCount(result.value), 'paragraph')}`;
    getText('cleaner-summary').textContent = !ready ? 'Your cleaned script will appear here as you type.'
      : result.value === source.value ? 'Your script is already clean with these settings.'
      : readingChunks ? 'Line breaks and spacing cleaned. Short reading chunks added.'
      : paragraphs ? 'Unwanted line breaks joined. Paragraphs kept.'
      : 'Line breaks joined into one paragraph.';
    getText('chunk-help').hidden = !readingChunks;
    getText('input-limit-help').hidden = source.value.length < 300000;
    copy.textContent = 'Copy script';
    clearTimeout(announcement);
    status.textContent = '';
    announcement = setTimeout(() => {
      status.textContent = ready ? `Cleaned script ready. ${getText('cleaned-count').textContent}.` : '';
    }, 500);
  }

  form.addEventListener('submit', event => event.preventDefault());
  form.addEventListener('input', update);
  form.addEventListener('change', update);
  getButton('load-cleaner-example').addEventListener('click', () => {
    source.value = cleanerExample;
    update();
    source.focus();
    source.setSelectionRange(0, 0);
    source.scrollTop = 0;
  });
  clear.addEventListener('click', () => {
    source.value = '';
    update();
    source.focus();
  });
  copy.addEventListener('click', async () => {
    const text = result.value;
    if (!text || copyInProgress) return;
    copyInProgress = true;
    copy.disabled = true;
    clearTimeout(announcement);
    status.textContent = '';
    try {
      await navigator.clipboard.writeText(text);
      if (result.value === text) {
        copy.textContent = 'Copied';
        status.textContent = 'Cleaned script copied. Paste it into your editor or teleprompter.';
      }
    } catch {
      result.focus();
      result.select();
      status.textContent = 'Copy was unavailable. Your cleaned script is selected; use your device’s Copy command, or download the text file.';
    } finally {
      copyInProgress = false;
      copy.disabled = !result.value;
    }
  });
  download.addEventListener('click', () => {
    if (!result.value) return;
    const url = URL.createObjectURL(new Blob([result.value], { type: 'text/plain;charset=utf-8' }));
    const link = document.createElement('a');
    link.href = url;
    link.download = 'cleaned-script.txt';
    document.body.append(link);
    link.click();
    link.remove();
    setTimeout(() => URL.revokeObjectURL(url), 1000);
    clearTimeout(announcement);
    status.textContent = 'Text file prepared. Check your browser’s downloads for cleaned-script.txt.';
  });

  fields.disabled = false;
  update();
}
