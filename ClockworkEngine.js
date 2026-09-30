.pragma library

// ClockworkEngine.js
// Pure-JS State Engine & Core Calculation Logic for Clockwork
// Compatible with both QML (.pragma library) and Node.js (CommonJS module.exports)

// Mode Constants
const MODE_STOPWATCH = 0;
const MODE_COUNTDOWN = 1;
const MODE_INTERVALS = 2;
const MODE_ALARM = 3;
const MODE_POMODORO = 4;

const MODES = {
  STOPWATCH: 0,
  COUNTDOWN: 1,
  INTERVALS: 2,
  ALARM: 3,
  POMODORO: 4,
  0: "STOPWATCH",
  1: "COUNTDOWN",
  2: "INTERVALS",
  3: "ALARM",
  4: "POMODORO"
};

const ALARM_SOUNDS = [
  "alarm-clock-elapsed.oga",
  "bell.oga",
  "phone-incoming-call.oga"
];

const LIMITS = {
  POMODORO_WORK_MIN: 1,
  POMODORO_WORK_MAX: 120,
  POMODORO_SHORT_BREAK_MIN: 1,
  POMODORO_SHORT_BREAK_MAX: 60,
  POMODORO_LONG_BREAK_MIN: 1,
  POMODORO_LONG_BREAK_MAX: 60,
  POMODORO_CYCLES_MIN: 1,
  POMODORO_CYCLES_MAX: 12,
  INTERVAL_ROUNDS_MIN: 1,
  INTERVAL_ROUNDS_MAX: 99,
  INTERVAL_MINUTES_MIN: 0,
  INTERVAL_MINUTES_MAX: 59,
  INTERVAL_SECONDS_MIN: 0,
  INTERVAL_SECONDS_MAX: 59,
  COUNTDOWN_MINUTES_MIN: 0,
  COUNTDOWN_MINUTES_MAX: 999,
  COUNTDOWN_SECONDS_MIN: 0,
  COUNTDOWN_SECONDS_MAX: 59,
  ALARM_HOUR_MIN: 0,
  ALARM_HOUR_MAX: 23,
  ALARM_MINUTE_MIN: 0,
  ALARM_MINUTE_MAX: 59
};

// Single source of truth for every user-configurable default (engine, state, widget, settings).
const DEFAULTS = {
  countdownMinutes: 5,
  countdownSeconds: 0,
  countdownMessage: "Take a break",
  countdownFullscreenEnabled: false,
  intervalRounds: 8,
  intervalMinutes: 0,
  intervalSeconds: 30,
  alarmHour: 7,
  alarmMinute: 0,
  alarmUses12Hour: false,
  alarmSound: "alarm-clock-elapsed.oga",
  alarmMessage: "Alarm",
  pomodoroWorkMinutes: 25,
  pomodoroShortBreakMinutes: 5,
  pomodoroCycles: 4,
  pomodoroLongBreakMinutes: 15
};

const MODE_NAMES = ["Stopwatch", "Countdown", "Intervals", "Alarm", "Pomodoro"];

// ============================================================================
// Formatting & Number Utilities
// ============================================================================

function pad2(value) {
  let v = Math.floor(Number(value) || 0);
  if (v < 0) v = 0;
  return v < 10 ? "0" + v : String(v);
}

function formatTime(milliseconds, showCentiseconds, useCeil) {
  const safeMilliseconds = Math.max(0, Math.floor(Number(milliseconds) || 0));
  // Countdown-style displays round up so "00:01" is shown until the very last moment.
  const round = (useCeil && !showCentiseconds) ? Math.ceil : Math.floor;
  const totalSeconds = round(safeMilliseconds / 1000);

  const hours = Math.floor(totalSeconds / 3600);
  const minutes = Math.floor((totalSeconds % 3600) / 60);
  const seconds = totalSeconds % 60;
  const mm = pad2(minutes);
  const ss = pad2(seconds);
  const result = hours > 0 ? hours + ":" + mm + ":" + ss : mm + ":" + ss;

  if (!showCentiseconds) return result;

  const centiseconds = Math.floor((safeMilliseconds % 1000) / 10);
  return result + "." + pad2(centiseconds);
}

// Floors to an integer and clamps into [min, max]; non-numeric input becomes `fallback`.
function clampInt(value, min, max, fallback) {
  const n = Math.floor(Number(value));
  return Math.max(min, Math.min(max, isNaN(n) ? fallback : n));
}

// Strict non-negative integer parser for IPC text arguments.
// Missing/blank -> `fallback`; anything that is not purely digits ("5abc", "-1", "1.5") -> NaN.
function parseIntArg(text, fallback) {
  if (text === undefined || text === null) return fallback;
  const trimmed = String(text).trim();
  if (trimmed === "") return fallback;
  return /^\d+$/.test(trimmed) ? parseInt(trimmed, 10) : NaN;
}

// ============================================================================
// Sound Cycling
// ============================================================================

function getAlarmSoundName(soundFile) {
  if (soundFile === "bell.oga") return "Bell";
  if (soundFile === "phone-incoming-call.oga") return "Phone";
  return "Alarm clock";
}

// ============================================================================
// Alarm & 12h/24h Conversions
// ============================================================================

function convert24To12(hour24) {
  const h = Math.max(0, Math.min(23, Number(hour24) || 0));
  const displayHour = h % 12 === 0 ? 12 : h % 12;
  const meridiem = h >= 12 ? "PM" : "AM";
  return { displayHour: displayHour, meridiem: meridiem };
}

function convert12To24(displayHour, meridiem) {
  const h = Math.max(1, Math.min(12, Number(displayHour) || 12));
  const isPM = String(meridiem || "").toUpperCase() === "PM";
  return (h % 12) + (isPM ? 12 : 0);
}

function computeAlarmTarget(hour, minute, now, meridiem) {
  const nowMs = typeof now === "number" ? now : (now instanceof Date ? now.getTime() : Date.now());
  let targetHour = Number(hour) || 0;

  if (meridiem) {
    targetHour = convert12To24(targetHour, meridiem);
  }

  const targetDate = new Date(nowMs);
  targetDate.setHours(targetHour, Number(minute) || 0, 0, 0);

  if (targetDate.getTime() <= nowMs) {
    targetDate.setDate(targetDate.getDate() + 1);
  }

  const targetAt = targetDate.getTime();
  const durationMs = Math.max(1, targetAt - nowMs);

  return {
    targetAt: targetAt,
    durationMs: durationMs
  };
}

// ============================================================================
// State Factory
// ============================================================================

function createInitialState(options) {
  const opt = options || {};
  const state = {
    mode: opt.mode !== undefined ? opt.mode : MODE_STOPWATCH,
    running: false,
    completed: false,
    startedAt: 0,
    storedElapsedMs: 0,
    nowMs: opt.nowMs || 0,
    notifiedIntervals: 0,
    alarmTargetAt: 0,
    alarmTargetDurationMs: 0,
    pomodoroPhaseKind: "focus", // "focus" | "short-break" | "long-break"
    pomodoroCurrentCycle: 1,
    pomodoroCompletedCycles: 0,
    pomodoroSessionStarted: false
  };
  for (const key in DEFAULTS) {
    const fallback = DEFAULTS[key];
    const given = opt[key];
    if (typeof fallback === "string") state[key] = given || fallback;
    else if (typeof fallback === "boolean") state[key] = given !== undefined ? Boolean(given) : fallback;
    else state[key] = given !== undefined ? given : fallback;
  }
  return state;
}

// Every key of the engine state. The QML singleton uses this to build snapshots and to apply
// results generically, so adding a state field only requires touching this file + one QML property.
const STATE_KEYS = Object.keys(createInitialState());

// ============================================================================
// Computed Getters
// ============================================================================

function getElapsedMs(state, nowMs) {
  const now = typeof nowMs === "number" ? nowMs : (state.nowMs || Date.now());
  if (state.running) {
    const diff = Math.max(0, now - (state.startedAt || 0));
    return Math.max(0, Math.round((state.storedElapsedMs || 0) + diff));
  }
  return Math.max(0, Math.round(state.storedElapsedMs || 0));
}

function getIntervalDurationMs(state) {
  const mins = Math.max(0, state.intervalMinutes || 0);
  const secs = Math.max(0, state.intervalSeconds || 0);
  return Math.max(1000, mins * 60000 + secs * 1000);
}

function getPomodoroPhaseDurationMs(state) {
  const kind = state.pomodoroPhaseKind || "focus";
  if (kind === "long-break") {
    return Math.max(1, state.pomodoroLongBreakMinutes || 15) * 60000;
  }
  if (kind === "short-break") {
    return Math.max(1, state.pomodoroShortBreakMinutes || 5) * 60000;
  }
  return Math.max(1, state.pomodoroWorkMinutes || 25) * 60000;
}

function getTargetMs(state) {
  const mode = state.mode;
  if (mode === MODE_COUNTDOWN) {
    return Math.max(0, (state.countdownMinutes || 0) * 60000 + (state.countdownSeconds || 0) * 1000);
  }
  if (mode === MODE_INTERVALS) {
    return Math.max(1, state.intervalRounds || 1) * getIntervalDurationMs(state);
  }
  if (mode === MODE_ALARM) {
    return state.alarmTargetDurationMs || 0;
  }
  if (mode === MODE_POMODORO) {
    return getPomodoroPhaseDurationMs(state);
  }
  return 0; // MODE_STOPWATCH
}

function getCurrentRound(state, nowMs) {
  const elapsed = getElapsedMs(state, nowMs);
  const duration = getIntervalDurationMs(state);
  const rounds = Math.max(1, state.intervalRounds || 1);
  return Math.min(rounds, Math.floor(elapsed / duration) + 1);
}

function getPomodoroPhase(state, nowMs) {
  const kind = state.pomodoroPhaseKind || "focus";
  const cycle = state.pomodoroCurrentCycle || 1;
  const totalCycles = Math.max(1, state.pomodoroCycles || 4);
  const completedCycles = state.pomodoroCompletedCycles || 0;
  const duration = getPomodoroPhaseDurationMs(state);
  const elapsed = Math.min(duration, getElapsedMs(state, nowMs));
  const remaining = Math.max(0, duration - elapsed);

  let label = "";
  if (kind === "focus") {
    label = "Focus " + cycle + " of " + totalCycles;
  } else if (kind === "long-break") {
    label = "Long break";
  } else {
    label = "Short break · Cycle " + cycle + " of " + totalCycles;
  }

  return {
    index: completedCycles * 2 + (kind === "focus" ? 0 : 1),
    kind: kind,
    cycle: cycle,
    label: label,
    durationMs: duration,
    elapsedMs: elapsed,
    remainingMs: remaining
  };
}

function getDisplayMs(state, nowMs) {
  if (state.mode === MODE_STOPWATCH) {
    return getElapsedMs(state, nowMs);
  }
  if (state.mode === MODE_POMODORO) {
    return getPomodoroPhase(state, nowMs).remainingMs;
  }
  return Math.max(0, getTargetMs(state) - getElapsedMs(state, nowMs));
}

function getProgress(state, nowMs) {
  if (state.mode === MODE_STOPWATCH) {
    return 0;
  }
  if (state.mode === MODE_POMODORO) {
    const phase = getPomodoroPhase(state, nowMs);
    return phase.durationMs > 0 ? Math.min(1, phase.elapsedMs / phase.durationMs) : 0;
  }
  const target = getTargetMs(state);
  return target > 0 ? Math.min(1, getElapsedMs(state, nowMs) / target) : 0;
}

function getAlarmTimeText(state) {
  if (state.alarmUses12Hour) {
    const conv = convert24To12(state.alarmHour);
    return conv.displayHour + ":" + pad2(state.alarmMinute) + " " + conv.meridiem;
  }
  return pad2(state.alarmHour) + ":" + pad2(state.alarmMinute);
}

function getModeName(mode) {
  return MODE_NAMES[mode] || "Timer";
}

// True while a session has accumulated progress that a mode switch would silently discard.
function hasProgress(state) {
  return Boolean(state.running || state.storedElapsedMs > 0 ||
    (state.mode === MODE_POMODORO && state.pomodoroSessionStarted));
}

// Modes may be switched freely when idle or after completion; never while progress would be lost.
function canSwitchMode(state) {
  return state.completed || !hasProgress(state);
}

// False only when Start would be a silent no-op (e.g. a 00:00 countdown).
function canStart(state) {
  if (state.mode === MODE_STOPWATCH || state.mode === MODE_ALARM) return true;
  return getTargetMs(state) > 0;
}

function getStatusText(state, nowMs) {
  if (state.completed) {
    if (state.mode === MODE_INTERVALS) return "Workout complete";
    if (state.mode === MODE_ALARM) return "Alarm ringing";
    if (state.mode === MODE_POMODORO) return "Pomodoro complete";
    return "Time is up";
  }

  if (state.mode === MODE_ALARM) {
    return state.running ? "Armed for " + getAlarmTimeText(state) : "Ready";
  }

  if (state.mode === MODE_POMODORO) {
    const phase = getPomodoroPhase(state, nowMs);
    if (state.running) return phase.label;
    if (state.pomodoroSessionStarted) return "Paused · " + phase.label;
    return state.pomodoroCycles + " cycles · " + state.pomodoroWorkMinutes + " / " + state.pomodoroShortBreakMinutes + " min";
  }

  if (state.mode === MODE_INTERVALS) {
    const round = getCurrentRound(state, nowMs);
    const durationText = pad2(state.intervalMinutes) + ":" + pad2(state.intervalSeconds);
    return "Round " + round + " of " + state.intervalRounds + " · " + durationText;
  }

  if (state.running) {
    return state.mode === MODE_STOPWATCH ? "Counting up" : "Counting down";
  }

  if (state.storedElapsedMs > 0) {
    return "Paused";
  }

  return "Ready";
}

function getDisplayText(state, nowMs) {
  if (state.mode === MODE_ALARM && (state.completed || (!state.running && state.storedElapsedMs === 0))) {
    return getAlarmTimeText(state);
  }
  const useCeil = state.mode !== MODE_STOPWATCH;
  return formatTime(getDisplayMs(state, nowMs), state.mode === MODE_STOPWATCH, useCeil);
}

function getBarTimeText(state, nowMs) {
  if (state.mode === MODE_ALARM && (state.running || state.completed)) {
    return getAlarmTimeText(state);
  }
  if (state.completed || hasProgress(state)) {
    const useCeil = state.mode !== MODE_STOPWATCH;
    return formatTime(getDisplayMs(state, nowMs), false, useCeil);
  }
  return "";
}

// ============================================================================
// State Transitions
// ============================================================================

function startPause(state, nowMs) {
  const now = typeof nowMs === "number" ? nowMs : Date.now();
  let next = Object.assign({}, state);
  const events = [];

  if (next.running) {
    return pause(next, now);
  }

  if (next.completed) {
    next = reset(next, now).state;
  }

  if (next.mode === MODE_ALARM) {
    const target = computeAlarmTarget(next.alarmHour, next.alarmMinute, now);
    next.alarmTargetAt = target.targetAt;
    next.alarmTargetDurationMs = target.durationMs;
    next.storedElapsedMs = 0;
    next.completed = false;
  }

  if (next.mode !== MODE_STOPWATCH && getTargetMs(next) <= 0) {
    return { state: next, events: [] };
  }

  if (next.mode === MODE_POMODORO) {
    next.pomodoroSessionStarted = true;
  }

  next.nowMs = now;
  next.startedAt = now;
  next.running = true;
  next.completed = false;

  return { state: next, events: events };
}

function pause(state, nowMs) {
  const now = typeof nowMs === "number" ? nowMs : Date.now();
  const next = Object.assign({}, state);
  if (!next.running) {
    return { state: next, events: [] };
  }
  // An alarm has no meaningful paused state (its target is an absolute wall-clock time): disarm it.
  if (next.mode === MODE_ALARM) {
    return reset(next, now);
  }
  next.storedElapsedMs = getElapsedMs(next, now);
  next.running = false;
  next.nowMs = now;
  return { state: next, events: [] };
}

function reset(state, nowMs) {
  const now = typeof nowMs === "number" ? nowMs : Date.now();
  const next = Object.assign({}, state);
  next.running = false;
  next.completed = false;
  next.storedElapsedMs = 0;
  next.notifiedIntervals = 0;
  next.nowMs = now;
  next.startedAt = now;

  if (next.mode === MODE_ALARM) {
    next.alarmTargetAt = 0;
    next.alarmTargetDurationMs = 0;
  }

  if (next.mode === MODE_POMODORO) {
    next.pomodoroPhaseKind = "focus";
    next.pomodoroCurrentCycle = 1;
    next.pomodoroCompletedCycles = 0;
    next.pomodoroSessionStarted = false;
  }

  return { state: next, events: [] };
}

function selectMode(state, nextMode, nowMs) {
  const modeNum = Math.max(MODE_STOPWATCH, Math.min(MODE_POMODORO, Number(nextMode) || 0));
  if (modeNum === state.mode) {
    return { state: state, events: [] };
  }
  const next = Object.assign({}, state);
  next.mode = modeNum;
  return reset(next, nowMs);
}

function tick(state, nowMs) {
  const now = typeof nowMs === "number" ? nowMs : Date.now();
  const next = Object.assign({}, state);
  const events = [];
  next.nowMs = now;

  if (!next.running) {
    return { state: next, events: [] };
  }

  if (next.mode === MODE_STOPWATCH) {
    return { state: next, events: [] };
  }

  const elapsed = getElapsedMs(next, now);

  if (next.mode === MODE_INTERVALS) {
    const duration = getIntervalDurationMs(next);
    const passed = Math.min(next.intervalRounds, Math.floor(elapsed / duration));
    if (passed > (next.notifiedIntervals || 0) && passed < next.intervalRounds) {
      next.notifiedIntervals = passed;
      events.push({ type: "sound", file: "complete.oga" });
      events.push({
        type: "notify",
        title: "DankClockwork",
        body: "Round " + passed + " complete · Round " + (passed + 1) + " starts now"
      });
    }

    const totalTarget = Math.max(1, next.intervalRounds) * duration;
    if (elapsed >= totalTarget) {
      next.storedElapsedMs = totalTarget;
      next.running = false;
      next.completed = true;
      next.notifiedIntervals = next.intervalRounds;
      events.push({ type: "sound", file: "complete.oga" });
      events.push({
        type: "notify",
        title: "DankClockwork",
        body: "All " + next.intervalRounds + " rounds complete"
      });
    }
    return { state: next, events: events };
  }

  if (next.mode === MODE_POMODORO) {
    if (elapsed >= getPomodoroPhaseDurationMs(next)) {
      events.push.apply(events, advancePomodoro(next, now, false));
    }
    return { state: next, events: events };
  }

  if (next.mode === MODE_ALARM) {
    const alarmTarget = next.alarmTargetDurationMs || 0;
    if (elapsed >= alarmTarget || (next.alarmTargetAt > 0 && now >= next.alarmTargetAt)) {
      next.storedElapsedMs = alarmTarget;
      next.running = false;
      next.completed = true;
      events.push({ type: "sound", file: next.alarmSound || "alarm-clock-elapsed.oga" });
      events.push({
        type: "notify",
        title: "DankClockwork",
        body: next.alarmMessage || DEFAULTS.alarmMessage,
        urgent: true
      });
    }
    return { state: next, events: events };
  }

  // MODE_COUNTDOWN
  const countdownTarget = getTargetMs(next);
  if (elapsed >= countdownTarget) {
    next.storedElapsedMs = countdownTarget;
    next.running = false;
    next.completed = true;
    events.push({ type: "sound", file: "complete.oga" });
    events.push({
      type: "notify",
      title: "DankClockwork",
      body: next.countdownMessage || DEFAULTS.countdownMessage
    });
  }

  return { state: next, events: events };
}

function skipPomodoro(state, nowMs) {
  const now = typeof nowMs === "number" ? nowMs : Date.now();
  if (state.mode !== MODE_POMODORO || !state.pomodoroSessionStarted || state.completed) {
    return { state: state, events: [] };
  }
  const next = Object.assign({}, state);
  const events = advancePomodoro(next, now, true);
  return { state: next, events: events };
}

// Moves a Pomodoro state (mutated in place) to its next phase and returns the resulting events.
// Focus -> break auto-starts; break -> focus waits for the user; the long break ends the session.
// `skipped` = the user pressed Skip (different wording, and no chime).
function advancePomodoro(next, now, skipped) {
  const events = [];
  const chime = function (file) {
    if (!skipped) events.push({ type: "sound", file: file });
  };
  const notify = function (body) {
    events.push({ type: "notify", title: "DankClockwork", body: body });
  };

  next.nowMs = now;
  next.pomodoroSessionStarted = true;

  if (next.pomodoroPhaseKind === "focus") {
    next.pomodoroCompletedCycles = Math.min(next.pomodoroCycles, (next.pomodoroCompletedCycles || 0) + 1);
    const isLongBreak = next.pomodoroCompletedCycles >= next.pomodoroCycles;
    next.pomodoroPhaseKind = isLongBreak ? "long-break" : "short-break";
    next.pomodoroCurrentCycle = next.pomodoroCompletedCycles;
    next.storedElapsedMs = 0;
    next.startedAt = now;
    next.running = true;
    next.completed = false;
    chime("complete.oga");
    notify((skipped ? "Focus skipped" : "Focus " + next.pomodoroCompletedCycles + " complete") +
      " \u00b7 " + (isLongBreak ? "Long" : "Short") + " break starts now");
  } else if (next.pomodoroPhaseKind === "short-break") {
    next.pomodoroPhaseKind = "focus";
    next.pomodoroCurrentCycle = (next.pomodoroCompletedCycles || 0) + 1;
    next.storedElapsedMs = 0;
    next.startedAt = now;
    next.running = false;
    next.completed = false;
    chime("bell.oga");
    notify((skipped ? "Break skipped" : "Break complete") + " \u00b7 Ready for focus " + next.pomodoroCurrentCycle);
  } else {
    next.storedElapsedMs = getPomodoroPhaseDurationMs(next);
    next.running = false;
    next.completed = true;
    chime("bell.oga");
    notify("All " + next.pomodoroCycles + " focus cycles complete");
  }
  return events;
}

// ============================================================================
// CommonJS Export Bridge (for Node.js testing and external scripting)
// ============================================================================

if (typeof module !== "undefined" && module.exports) {
  module.exports = {
    MODE_STOPWATCH: MODE_STOPWATCH,
    MODE_COUNTDOWN: MODE_COUNTDOWN,
    MODE_INTERVALS: MODE_INTERVALS,
    MODE_ALARM: MODE_ALARM,
    MODE_POMODORO: MODE_POMODORO,
    MODES: MODES,
    ALARM_SOUNDS: ALARM_SOUNDS,
    LIMITS: LIMITS,
    DEFAULTS: DEFAULTS,
    STATE_KEYS: STATE_KEYS,

    pad2: pad2,
    clampInt: clampInt,
    parseIntArg: parseIntArg,
    formatTime: formatTime,
    getAlarmSoundName: getAlarmSoundName,

    convert24To12: convert24To12,
    convert12To24: convert12To24,
    computeAlarmTarget: computeAlarmTarget,

    createInitialState: createInitialState,
    getElapsedMs: getElapsedMs,
    getIntervalDurationMs: getIntervalDurationMs,
    getPomodoroPhaseDurationMs: getPomodoroPhaseDurationMs,
    getTargetMs: getTargetMs,
    getCurrentRound: getCurrentRound,
    getPomodoroPhase: getPomodoroPhase,
    getDisplayMs: getDisplayMs,
    getProgress: getProgress,
    getAlarmTimeText: getAlarmTimeText,
    getModeName: getModeName,
    hasProgress: hasProgress,
    canSwitchMode: canSwitchMode,
    canStart: canStart,
    getStatusText: getStatusText,
    getDisplayText: getDisplayText,
    getBarTimeText: getBarTimeText,

    startPause: startPause,
    pause: pause,
    reset: reset,
    selectMode: selectMode,
    tick: tick,
    skipPomodoro: skipPomodoro,
    advancePomodoro: advancePomodoro
  };
}
