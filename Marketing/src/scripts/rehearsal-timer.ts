import { createTimer, finishTimer, pauseTimer, startTimer, timerClock, timerReading, timerSettings, type RehearsalTimer } from '../lib/rehearsal-timer';

const form = document.querySelector<HTMLFormElement>('#rehearsal-timer');
if (form) {
  const element = (id: string) => document.getElementById(id)!;
  const input = (id: string) => element(id) as HTMLInputElement;
  const button = (id: string) => element(id) as HTMLButtonElement;
  const minutes = input('rehearsal-minutes');
  const seconds = input('rehearsal-seconds');
  const warning = input('rehearsal-warning');
  const settings = element('rehearsal-settings') as HTMLFieldSetElement;
  const screen = element('rehearsal-screen');
  const primary = button('timer-start');
  const finish = button('timer-finish');
  const reset = button('timer-reset');
  const expand = button('timer-fullscreen');
  const error = element('timer-error');
  let timer: RehearsalTimer = createTimer(300, 60);
  let interval: ReturnType<typeof setInterval> | undefined;
  let lastAnnouncement = '';
  let focusView = false;
  let nativeFullscreen = false;
  const inertBefore = new Map<HTMLElement, boolean>();

  function announce(message: string) { element('timer-status').textContent = message; }

  function render(now = Date.now()) {
    if (timer.phase === 'ready' && !error.hidden) return;
    const reading = timerReading(timer, now);
    const signal = reading.signal;
    screen.dataset.signal = signal;
    const clock = timerClock(reading.clockSeconds);
    element('rehearsal-clock').textContent = clock;
    element('rehearsal-clock').dataset.long = String(clock.length > 5);
    element('clock-label').textContent = reading.over ? 'Over time' : 'Time remaining';
    const cue = signal === 'over' ? 'Time is up' : signal === 'warning' ? 'Wrap up' : 'On time';
    const state = timer.phase === 'ready' ? 'Ready' : timer.phase === 'paused' ? `Paused · ${cue}` : timer.phase === 'finished' ? `Finished · ${cue}` : cue;
    element('timer-cue').textContent = state;
    element('elapsed-time').textContent = timerClock(reading.elapsedSeconds);
    element('target-time').textContent = timerClock(timer.targetSeconds);
    element('warning-time').textContent = timer.warningSeconds ? `${timerClock(timer.warningSeconds)} left` : 'Off';
    primary.textContent = timer.phase === 'running' ? 'Pause' : timer.phase === 'paused' ? 'Resume' : timer.phase === 'finished' ? 'Start again' : 'Start timer';
    primary.setAttribute('aria-label', timer.phase === 'running' ? 'Pause timer' : timer.phase === 'paused' ? 'Resume timer' : timer.phase === 'finished' ? 'Start another rehearsal' : 'Start timer');
    finish.disabled = timer.phase === 'ready' || timer.phase === 'finished';
    reset.disabled = timer.phase === 'ready';
    settings.disabled = timer.phase !== 'ready';
    element('timer-settings-note').textContent = timer.phase === 'ready' ? 'Set your limit, then start speaking.' : 'Reset to change the time limit or warning.';
    element('timer-summary').textContent = timer.phase === 'finished'
      ? `Finished in ${timerClock(reading.elapsedSeconds)}. ${reading.over ? `${timerClock(reading.clockSeconds)} over` : `${timerClock(reading.clockSeconds)} under`} your target.`
      : timer.phase === 'paused' ? 'Paused. Your break won’t count toward the rehearsal.'
      : timer.phase === 'running' ? 'Keep speaking. The timer continues past zero.'
      : 'Press Start timer when you begin your delivery.';
    const key = `${timer.phase}:${signal}`;
    if (key !== lastAnnouncement) {
      lastAnnouncement = key;
      announce(timer.phase === 'ready' ? `Ready. Target ${timerClock(timer.targetSeconds)}.`
        : timer.phase === 'finished' ? element('timer-summary').textContent!
        : timer.phase === 'paused' ? `Timer paused. ${timerClock(reading.elapsedSeconds)} elapsed.`
        : `${state}. ${reading.over ? 'The timer is now counting over time.' : `${timerClock(reading.clockSeconds)} remaining.`}`);
    }
  }

  function configure() {
    if (timer.phase !== 'ready') return;
    const fields = [minutes, seconds, warning];
    const values = fields.map(field => field.value.trim() !== '' && field.validity.valid ? field.valueAsNumber : NaN);
    const problem = timerSettings(values[0], values[1], values[2]);
    const target = values[0] * 60 + values[1];
    fields.forEach((field, index) => {
      const invalid = !Number.isFinite(values[index]) || (index < 2
        ? Number.isFinite(target) && (target < 1 || target > 10800)
        : values[2] < 0 || Number.isFinite(target) && values[2] >= target);
      field.setAttribute('aria-invalid', String(invalid));
    });
    error.textContent = problem ?? '';
    error.hidden = !problem;
    primary.disabled = !!problem;
    form!.querySelectorAll<HTMLButtonElement>('[data-rehearsal-preset]').forEach(preset => preset.setAttribute('aria-pressed', String(!problem && Number(preset.dataset.rehearsalPreset) === values[0] * 60 + values[1])));
    if (problem) {
      element('rehearsal-clock').textContent = '—';
      element('clock-label').textContent = 'Check your time limit';
      element('timer-cue').textContent = 'Needs a change';
      screen.dataset.signal = 'invalid';
      announce(problem);
      return;
    }
    timer = createTimer(values[0] * 60 + values[1], values[2]);
    lastAnnouncement = '';
    render();
  }

  function transport() {
    if (primary.disabled) return;
    if (timer.phase === 'running') {
      timer = pauseTimer(timer, Date.now());
      clearInterval(interval);
      interval = undefined;
    } else {
      timer = startTimer(timer, Date.now());
      clearInterval(interval);
      interval = setInterval(() => render(), 100);
    }
    render();
  }
  form.addEventListener('submit', event => event.preventDefault());
  settings.addEventListener('input', configure);
  form.querySelectorAll<HTMLButtonElement>('[data-rehearsal-preset]').forEach(preset => preset.addEventListener('click', () => {
    const target = Number(preset.dataset.rehearsalPreset);
    minutes.value = String(target / 60);
    seconds.value = '0';
    warning.value = String(target === 60 ? 15 : target === 180 ? 30 : 60);
    configure();
  }));
  primary.addEventListener('click', transport);
  finish.addEventListener('click', () => {
    timer = finishTimer(timer, Date.now());
    clearInterval(interval);
    interval = undefined;
    render();
    primary.focus();
  });
  reset.addEventListener('click', () => {
    clearInterval(interval);
    interval = undefined;
    timer = createTimer(timer.targetSeconds, timer.warningSeconds);
    lastAnnouncement = '';
    render();
    primary.focus();
  });
  screen.addEventListener('keydown', event => {
    if (event.key === ' ' && event.target === screen) { event.preventDefault(); transport(); }
  });

  function closeFocusView() {
    focusView = false;
    nativeFullscreen = false;
    screen.classList.remove('is-focus-view');
    screen.removeAttribute('aria-modal');
    screen.setAttribute('role', 'region');
    document.body.classList.remove('timer-focus-open');
    for (const [node, wasInert] of inertBefore) node.inert = wasInert;
    inertBefore.clear();
    expand.textContent = document.fullscreenEnabled ? 'Fullscreen' : 'Focus view';
    expand.setAttribute('aria-pressed', 'false');
    expand.focus();
  }
  async function leaveFocusView() {
    if (document.fullscreenElement === screen) {
      try { await document.exitFullscreen(); } catch { /* The in-page view still has an exit. */ }
      if (document.fullscreenElement === screen) { announce('Use the browser’s fullscreen exit to return to the page.'); return; }
    }
    if (focusView) closeFocusView();
  }
  expand.addEventListener('click', async () => {
    if (focusView) { await leaveFocusView(); return; }
    focusView = true;
    screen.classList.add('is-focus-view');
    screen.setAttribute('role', 'dialog');
    screen.setAttribute('aria-modal', 'true');
    document.body.classList.add('timer-focus-open');
    let branch: HTMLElement = screen;
    while (branch.parentElement && branch.parentElement !== document.documentElement) {
      for (const sibling of branch.parentElement.children) {
        if (sibling !== branch && sibling instanceof HTMLElement) { inertBefore.set(sibling, sibling.inert); sibling.inert = true; }
      }
      branch = branch.parentElement;
    }
    expand.textContent = 'Exit focus view';
    expand.setAttribute('aria-pressed', 'true');
    primary.focus();
    if (document.fullscreenEnabled && screen.requestFullscreen) {
      try {
        await screen.requestFullscreen();
        if (!focusView) { await document.exitFullscreen(); return; }
        nativeFullscreen = true;
        expand.textContent = 'Exit fullscreen';
      } catch { announce('Fullscreen isn’t available here. The timer is open in focus view.'); }
    }
  });
  document.addEventListener('fullscreenchange', () => {
    if (nativeFullscreen && document.fullscreenElement !== screen && focusView) closeFocusView();
  });
  screen.addEventListener('keydown', event => {
    if (!focusView) return;
    if (event.key === 'Escape') { event.preventDefault(); void leaveFocusView(); }
    if (event.key === 'Tab') {
      const controls = Array.from(screen.querySelectorAll<HTMLButtonElement>('button:not(:disabled)'));
      const first = controls[0];
      const last = controls[controls.length - 1];
      if (event.shiftKey && document.activeElement === first) { event.preventDefault(); last.focus(); }
      else if (!event.shiftKey && document.activeElement === last) { event.preventDefault(); first.focus(); }
    }
  });
  document.addEventListener('visibilitychange', () => { if (!document.hidden) render(); });
  window.addEventListener('pagehide', () => {
    clearInterval(interval);
    interval = undefined;
    if (focusView) closeFocusView();
  });
  window.addEventListener('pageshow', () => {
    if (timer.phase === 'running') { clearInterval(interval); interval = setInterval(() => render(), 100); }
    render();
  });
  expand.disabled = false;
  expand.textContent = document.fullscreenEnabled ? 'Fullscreen' : 'Focus view';
  settings.disabled = false;
  configure();
}
