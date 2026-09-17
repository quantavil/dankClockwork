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
  let totalSeconds;

  if (showCentiseconds) {
    totalSeconds = Math.floor(safeMilliseconds / 1000);
  } else if (useCeil) {
    totalSeconds = Math.ceil(safeMilliseconds / 1000);
  } else {
    totalSeconds = Math.floor(safeMilliseconds / 1000);
  }

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

// ============================================================================
// Sound Cycling
// ============================================================================

function cycleAlarmSound(currentSound, direction) {
  const dir = direction === undefined ? 1 : Number(direction) || 0;
  let index = ALARM_SOUNDS.indexOf(currentSound);
  if (index < 0) index = 0;
  let nextIndex = (index + dir) % ALARM_SOUNDS.length;
  if (nextIndex < 0) nextIndex += ALARM_SOUNDS.length;
  return ALARM_SOUNDS[nextIndex];
}

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
  return {
    mode: opt.mode !== undefined ? opt.mode : MODE_STOPWATCH,
    running: false,
    completed: false,
    startedAt: 0,
    storedElapsedMs: 0,
    nowMs: opt.nowMs || 0,

    // Countdown configuration
    countdownMinutes: opt.countdownMinutes !== undefined ? opt.countdownMinutes : 5,
    countdownSeconds: opt.countdownSeconds !== undefined ? opt.countdownSeconds : 0,
    countdownMessage: opt.countdownMessage || "Take a break",
    countdownFullscreenEnabled: Boolean(opt.countdownFullscreenEnabled),

    // Intervals configuration
    intervalRounds: opt.intervalRounds !== undefined ? opt.intervalRounds : 8,
    intervalMinutes: opt.intervalMinutes !== undefined ? opt.intervalMinutes : 0,
    intervalSeconds: opt.intervalSeconds !== undefined ? opt.intervalSeconds : 30,
    notifiedIntervals: 0,

    // Alarm configuration
    alarmHour: opt.alarmHour !== undefined ? opt.alarmHour : 7,
    alarmMinute: opt.alarmMinute !== undefined ? opt.alarmMinute : 0,
    alarmUses12Hour: Boolean(opt.alarmUses12Hour),
    alarmSound: opt.alarmSound || "alarm-clock-elapsed.oga",
    alarmMessage: opt.alarmMessage || "Alarm",
    alarmTargetAt: 0,
    alarmTargetDurationMs: 0,

    // Pomodoro configuration
    pomodoroWorkMinutes: opt.pomodoroWorkMinutes !== undefined ? opt.pomodoroWorkMinutes : 25,
    pomodoroShortBreakMinutes: opt.pomodoroShortBreakMinutes !== undefined ? opt.pomodoroShortBreakMinutes : 5,
    pomodoroCycles: opt.pomodoroCycles !== undefined ? opt.pomodoroCycles : 4,
    pomodoroLongBreakMinutes: opt.pomodoroLongBreakMinutes !== undefined ? opt.pomodoroLongBreakMinutes : 15,
    pomodoroSoundEnabled: opt.pomodoroSoundEnabled !== undefined ? Boolean(opt.pomodoroSoundEnabled) : true,
    pomodoroBreakColor: opt.pomodoroBreakColor || "",
    pomodoroPhaseKind: "focus", // "focus" | "short-break" | "long-break"
    pomodoroCurrentCycle: 1,
    pomodoroCompletedCycles: 0,
    pomodoroSessionStarted: false
  };
}

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
  if (mode === MODE_STOPWATCH) return "Stopwatch";
  if (mode === MODE_COUNTDOWN) return "Countdown";
  if (mode === MODE_INTERVALS) return "Intervals";
  if (mode === MODE_ALARM) return "Alarm";
  if (mode === MODE_POMODORO) return "Pomodoro";
  return "Timer";
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
  if (state.mode === MODE_ALARM && !state.running && state.storedElapsedMs === 0 && !state.completed) {
    return getAlarmTimeText(state);
  }
  const useCeil = state.mode !== MODE_STOPWATCH;
  return formatTime(getDisplayMs(state, nowMs), state.mode === MODE_STOPWATCH, useCeil);
}

function getBarTimeText(state, nowMs) {
  if (state.running || state.storedElapsedMs > 0 || state.completed ||
      (state.mode === MODE_POMODORO && state.pomodoroSessionStarted)) {
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
    if (next.mode === MODE_ALARM) {
      return reset(next, now);
    }
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
        title: "Clockwork",
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
        title: "Clockwork",
        body: "All " + next.intervalRounds + " rounds complete"
      });
    }
    return { state: next, events: events };
  }

  if (next.mode === MODE_POMODORO) {
    const phaseDuration = getPomodoroPhaseDurationMs(next);
    if (elapsed >= phaseDuration) {
      if (next.pomodoroPhaseKind === "focus") {
        next.pomodoroCompletedCycles = Math.min(next.pomodoroCycles, (next.pomodoroCompletedCycles || 0) + 1);
        const isLongBreak = next.pomodoroCompletedCycles >= next.pomodoroCycles;
        next.pomodoroPhaseKind = isLongBreak ? "long-break" : "short-break";
        next.pomodoroCurrentCycle = next.pomodoroCompletedCycles;
        next.storedElapsedMs = 0;
        next.startedAt = now;
        next.running = true; // Automatically start break
        next.completed = false;
        next.pomodoroSessionStarted = true;

        if (next.pomodoroSoundEnabled) {
          events.push({ type: "sound", file: "complete.oga" });
        }
        events.push({
          type: "notify",
          title: "Clockwork",
          body: isLongBreak
            ? "Focus " + next.pomodoroCompletedCycles + " complete · Long break starts now"
            : "Focus " + next.pomodoroCompletedCycles + " complete · Short break starts now"
        });
      } else if (next.pomodoroPhaseKind === "short-break") {
        next.pomodoroPhaseKind = "focus";
        next.pomodoroCurrentCycle = (next.pomodoroCompletedCycles || 0) + 1;
        next.storedElapsedMs = 0;
        next.startedAt = now;
        next.running = false; // Paused waiting for user to start focus
        next.completed = false;
        next.pomodoroSessionStarted = true;

        if (next.pomodoroSoundEnabled) {
          events.push({ type: "sound", file: "bell.oga" });
        }
        events.push({
          type: "notify",
          title: "Clockwork",
          body: "Break complete · Ready for focus " + next.pomodoroCurrentCycle
        });
      } else if (next.pomodoroPhaseKind === "long-break") {
        next.storedElapsedMs = phaseDuration;
        next.running = false;
        next.completed = true;
        next.pomodoroSessionStarted = true;

        if (next.pomodoroSoundEnabled) {
          events.push({ type: "sound", file: "bell.oga" });
        }
        events.push({
          type: "notify",
          title: "Clockwork",
          body: "All " + next.pomodoroCycles + " focus cycles complete"
        });
      }
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
        title: "Clockwork",
        body: next.alarmMessage || "Alarm"
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
      title: "Clockwork",
      body: next.countdownMessage || "Take a break"
    });
  }

  return { state: next, events: events };
}

function skipPomodoro(state, nowMs) {
  const now = typeof nowMs === "number" ? nowMs : Date.now();
  if (state.mode !== MODE_POMODORO || !state.pomodoroSessionStarted || state.completed) {
    return { state: state, events: [] };
  }

  let next = Object.assign({}, state);
  const events = [];

  if (next.pomodoroPhaseKind === "focus") {
    next.pomodoroCompletedCycles = Math.min(next.pomodoroCycles, (next.pomodoroCompletedCycles || 0) + 1);
    const isLongBreak = next.pomodoroCompletedCycles >= next.pomodoroCycles;
    next.pomodoroPhaseKind = isLongBreak ? "long-break" : "short-break";
    next.pomodoroCurrentCycle = next.pomodoroCompletedCycles;
    next.storedElapsedMs = 0;
    next.nowMs = now;
    next.startedAt = now;
    next.running = true; // Auto-start break
    next.completed = false;
    events.push({
      type: "notify",
      title: "Clockwork",
      body: isLongBreak
        ? "Focus skipped · Long break starts now"
        : "Focus skipped · Short break starts now"
    });
    return { state: next, events: events };
  }

  if (next.pomodoroPhaseKind === "short-break") {
    next.pomodoroPhaseKind = "focus";
    next.pomodoroCurrentCycle = (next.pomodoroCompletedCycles || 0) + 1;
    next.storedElapsedMs = 0;
    next.nowMs = now;
    next.startedAt = now;
    next.running = false; // Paused waiting for user
    next.completed = false;
    events.push({
      type: "notify",
      title: "Clockwork",
      body: "Break skipped · Ready for focus " + next.pomodoroCurrentCycle
    });
    return { state: next, events: events };
  }

  // long-break
  const phaseDuration = getPomodoroPhaseDurationMs(next);
  next.storedElapsedMs = phaseDuration;
  next.running = false;
  next.completed = true;
  events.push({
    type: "notify",
    title: "Clockwork",
    body: "All " + next.pomodoroCycles + " focus cycles complete"
  });

  return { state: next, events: events };
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

    pad2: pad2,
    formatTime: formatTime,
    cycleAlarmSound: cycleAlarmSound,
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
    getStatusText: getStatusText,
    getDisplayText: getDisplayText,
    getBarTimeText: getBarTimeText,

    startPause: startPause,
    pause: pause,
    reset: reset,
    selectMode: selectMode,
    tick: tick,
    skipPomodoro: skipPomodoro
  };
}
