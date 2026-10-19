import { countWords, formatDuration, measuredWpm, sampleScript, speechSeconds, speedPassage, wordBudget } from '../lib/speech-time';

const form = document.querySelector<HTMLFormElement>('#speech-calculator');
if (form) {
  const input = (id: string) => document.getElementById(id) as HTMLInputElement;
  const element = (id: string) => document.getElementById(id)!;
  const button = (id: string) => document.getElementById(id) as HTMLButtonElement;
  const script = document.getElementById('speech-script') as HTMLTextAreaElement;
  const words = input('manual-words');
  const pace = input('speaking-pace');
  const pauses = input('pause-seconds');
  const minutes = input('target-minutes');
  const seconds = input('target-seconds');
  const numberFormat = new Intl.NumberFormat('en');
  let announcement: ReturnType<typeof setTimeout>;

  function validNumber(field: HTMLInputElement): number | null {
    const valid = field.value.trim() !== '' && field.validity.valid && Number.isFinite(field.valueAsNumber);
    field.setAttribute('aria-invalid', String(!valid));
    return valid ? field.valueAsNumber : null;
  }

  function update() {
    const scriptMode = form!.querySelector<HTMLInputElement>('[name="input-mode"]:checked')?.value !== 'count';
    const count = scriptMode ? countWords(script.value) : validNumber(words);
    const wpm = validNumber(pace);
    const pauseTime = validNumber(pauses);
    element('script-panel').hidden = !scriptMode;
    element('count-panel').hidden = scriptMode;
    element('script-word-count').textContent = `${numberFormat.format(countWords(script.value))} words`;
    button('clear-script').disabled = script.value.length === 0;
    form!.querySelectorAll<HTMLButtonElement>('[data-pace]').forEach(preset => preset.setAttribute('aria-pressed', String(Number(preset.dataset.pace) === wpm)));

    const ready = count !== null && count > 0 && wpm !== null && pauseTime !== null;
    element('speech-duration').textContent = ready ? formatDuration(speechSeconds(count, wpm, pauseTime)) : '—';
    element('duration-description').textContent = wpm === null ? 'Enter a speaking pace from 40 to 400 words/min.'
      : pauseTime === null ? 'Enter 0 to 3,600 whole seconds of extra pauses.'
      : !scriptMode && count === null ? 'Enter a whole word count from 1 to 1,000,000.'
      : !count ? 'Add a script or word count to see your estimate.'
      : `${numberFormat.format(count)} words at ${wpm} words/min${pauseTime ? ` + ${pauseTime} seconds of pauses` : ', with no extra pauses'}.`;

    const targetMinutes = validNumber(minutes);
    const targetSeconds = validNumber(seconds);
    const target = targetMinutes !== null && targetSeconds !== null ? targetMinutes * 60 + targetSeconds : null;
    const budget = target !== null && target > 0 && wpm !== null && pauseTime !== null ? wordBudget(target, wpm, pauseTime) : null;
    element('word-budget').textContent = budget !== null ? `${numberFormat.format(budget)} words` : '—';
    element('budget-description').textContent = wpm === null || pauseTime === null ? 'Check your speaking pace and extra pauses above.'
      : target === null || target === 0 ? 'Enter 0–180 whole minutes and 0–59 seconds. Choose a duration above zero.'
      : pauseTime >= target ? 'Your pauses use the whole time limit. Reduce pauses or add time.'
      : `At ${wpm} words/min, ${pauseTime ? `with ${pauseTime} seconds of extra pauses` : 'with no extra pauses'}.`;
    clearTimeout(announcement);
    announcement = setTimeout(() => {
      const durationFeedback = ready
        ? `Estimated speaking time: ${element('speech-duration').textContent}. ${element('duration-description').textContent}`
        : element('duration-description').textContent;
      const budgetFeedback = budget !== null
        ? `Target word budget: ${element('word-budget').textContent}. ${element('budget-description').textContent}`
        : `Target word budget unavailable. ${element('budget-description').textContent}`;
      // Independent planners announce only when their own feedback changes.
      if (element('calculator-status').textContent !== durationFeedback) element('calculator-status').textContent = durationFeedback;
      if (element('budget-status').textContent !== budgetFeedback) element('budget-status').textContent = budgetFeedback;
    }, 500);
  }

  form.addEventListener('submit', event => event.preventDefault());
  form.addEventListener('input', update);
  form.addEventListener('change', update);
  form.querySelectorAll<HTMLButtonElement>('[data-pace]').forEach(preset => preset.addEventListener('click', () => {
    pace.value = preset.dataset.pace!;
    update();
  }));
  button('load-sample').addEventListener('click', () => { script.value = sampleScript; update(); script.focus(); });
  button('clear-script').addEventListener('click', () => { script.value = ''; update(); script.focus(); });

  let startedAt: number | null = null;
  let timer: ReturnType<typeof setInterval> | undefined;
  let measuredPace: number | null = null;
  const start = button('start-speed-test');
  const finish = button('finish-speed-test');
  const reset = button('reset-speed-test');
  const apply = button('use-measured-pace');
  const passageWords = countWords(speedPassage);

  function stopTimer() {
    clearInterval(timer);
    timer = undefined;
    startedAt = null;
    start.hidden = false;
    finish.hidden = true;
  }
  start.addEventListener('click', () => {
    measuredPace = null;
    apply.hidden = true;
    startedAt = performance.now();
    start.hidden = true;
    finish.hidden = false;
    reset.hidden = false;
    element('speed-test-clock').textContent = '0:00';
    element('speed-test-status').textContent = 'Timer running. Read the full passage, then choose Finish reading.';
    timer = setInterval(() => {
      if (startedAt !== null) element('speed-test-clock').textContent = formatDuration((performance.now() - startedAt) / 1000);
    }, 250);
    finish.focus();
  });
  finish.addEventListener('click', () => {
    if (startedAt === null) return;
    const elapsed = (performance.now() - startedAt) / 1000;
    measuredPace = measuredWpm(passageWords, elapsed);
    stopTimer();
    element('speed-test-clock').textContent = formatDuration(elapsed);
    start.textContent = 'Try again';
    if (measuredPace < 40 || measuredPace > 400) {
      measuredPace = null;
      element('speed-test-status').textContent = 'That result is outside the calculator’s 40–400 words/min range. Try again and read the full passage from start to finish.';
      start.focus();
    } else {
      element('speed-test-status').textContent = `Your measured pace: ${measuredPace} words/min (${passageWords} words in ${formatDuration(elapsed)}). Try it with your own script, too.`;
      apply.hidden = false;
      apply.focus();
    }
  });
  reset.addEventListener('click', () => {
    stopTimer();
    measuredPace = null;
    apply.hidden = true;
    reset.hidden = true;
    start.textContent = 'Start reading';
    element('speed-test-clock').textContent = '0:00';
    element('speed-test-status').textContent = 'Read at your own pace. Natural breaths and pauses are part of the test.';
    start.focus();
  });
  apply.addEventListener('click', () => {
    if (measuredPace === null) return;
    pace.value = String(measuredPace);
    update();
    element('speed-test-status').textContent = `Using ${measuredPace} words/min in the calculator and word planner.`;
    pace.focus();
  });
  document.addEventListener('visibilitychange', () => {
    if (document.hidden && startedAt !== null) {
      stopTimer();
      element('speed-test-status').textContent = 'The test stopped because this tab was hidden. Return to the passage and start again.';
    }
  });
  window.addEventListener('pagehide', stopTimer);
  form.querySelector('fieldset')!.disabled = false;
  start.disabled = false;
  update();
}
