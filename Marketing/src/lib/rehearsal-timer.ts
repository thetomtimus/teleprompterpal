export type TimerPhase = 'ready' | 'running' | 'paused' | 'finished';
export type TimerSignal = 'safe' | 'warning' | 'over';
export interface RehearsalTimer {
  phase: TimerPhase;
  targetSeconds: number;
  warningSeconds: number;
  elapsedMs: number;
  startedAt: number | null;
}

export function timerSettings(minutes: number, seconds: number, warning: number): string | null {
  if (!Number.isInteger(minutes) || minutes < 0 || minutes > 180
    || !Number.isInteger(seconds) || seconds < 0 || seconds > 59) return 'Enter 0–180 whole minutes and 0–59 seconds.';
  const target = minutes * 60 + seconds;
  if (target < 1 || target > 10800) return 'Choose a time limit between 1 second and 3 hours.';
  if (!Number.isInteger(warning) || warning < 0 || warning >= target) return 'Use a whole warning time below your time limit, or 0 for no warning.';
  return null;
}

export function createTimer(targetSeconds: number, warningSeconds: number): RehearsalTimer {
  const error = timerSettings(Math.floor(targetSeconds / 60), targetSeconds % 60, warningSeconds);
  if (error) throw new RangeError(error);
  return { phase: 'ready', targetSeconds, warningSeconds, elapsedMs: 0, startedAt: null };
}

// Timestamp differences catch up after delayed callbacks or a hidden tab.
export function elapsedMilliseconds(timer: RehearsalTimer, now: number): number {
  return timer.elapsedMs + (timer.startedAt === null ? 0 : Math.max(0, now - timer.startedAt));
}

export function startTimer(timer: RehearsalTimer, now: number): RehearsalTimer {
  if (timer.phase === 'running') return timer;
  return { ...timer, phase: 'running', elapsedMs: timer.phase === 'finished' ? 0 : timer.elapsedMs, startedAt: now };
}

export function pauseTimer(timer: RehearsalTimer, now: number): RehearsalTimer {
  return timer.phase !== 'running' ? timer : { ...timer, phase: 'paused', elapsedMs: elapsedMilliseconds(timer, now), startedAt: null };
}

export function finishTimer(timer: RehearsalTimer, now: number): RehearsalTimer {
  return timer.phase === 'ready' || timer.phase === 'finished' ? timer
    : { ...timer, phase: 'finished', elapsedMs: elapsedMilliseconds(timer, now), startedAt: null };
}

export function timerReading(timer: RehearsalTimer, now: number) {
  const elapsed = elapsedMilliseconds(timer, now);
  const remaining = timer.targetSeconds * 1000 - elapsed;
  const signal: TimerSignal = remaining <= 0 ? 'over'
    : timer.warningSeconds > 0 && remaining <= timer.warningSeconds * 1000 ? 'warning' : 'safe';
  return {
    signal,
    elapsedSeconds: Math.floor(elapsed / 1000),
    clockSeconds: remaining > 0 ? Math.ceil(remaining / 1000) : Math.max(0, Math.floor(-remaining / 1000)),
    over: remaining <= 0,
  };
}

export function timerClock(seconds: number): string {
  const whole = Math.max(0, Math.floor(seconds));
  const hours = Math.floor(whole / 3600);
  const minutes = Math.floor(whole / 60) % 60;
  const rest = String(whole % 60).padStart(2, '0');
  return hours ? `${hours}:${String(minutes).padStart(2, '0')}:${rest}` : `${minutes}:${rest}`;
}
