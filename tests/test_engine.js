// tests/test_engine.js
// Automated test suite for ClockworkEngine.js
// Run via: node tests/test_engine.js

const assert = require('assert');
const fs = require('fs');
const Module = require('module');

// Transparently handle QML `.pragma library` directive in Node.js CommonJS loader
const originalJsLoader = Module._extensions['.js'];
Module._extensions['.js'] = function(module, filename) {
  let content = fs.readFileSync(filename, 'utf8');
  if (content.trimStart().startsWith('.pragma')) {
    content = content.replace(/^\s*\.pragma[^\r\n]*/m, '// .pragma library (handled for Node.js)');
  }
  module._compile(content, filename);
};

let Engine;
try {
  Engine = require('../ClockworkEngine.js');
} catch (err) {
  // Expected during initial RED phase before ClockworkEngine.js is implemented
  console.error('FAILED to load ClockworkEngine.js:', err.message);
  process.exit(1);
}

// Test Runner Infrastructure
let passed = 0;
let failed = 0;
const failures = [];

function test(name, fn) {
  try {
    fn();
    passed++;
    console.log(`  \x1b[32m✔\x1b[0m ${name}`);
  } catch (err) {
    failed++;
    failures.push({ name, err });
    console.log(`  \x1b[31m✖\x1b[0m ${name}`);
    console.log(`    \x1b[31m${err.message}\x1b[0m`);
    if (err.stack && !err.message) console.log(err.stack);
  }
}

function suite(name, fn) {
  console.log(`\n\x1b[1m\x1b[36m--- ${name} ---\x1b[0m`);
  fn();
}

// ============================================================================
// Test Suites
// ============================================================================

suite('1. Mode Constants & Enums', () => {
  test('Mode integer constants are correctly mapped', () => {
    assert.strictEqual(Engine.MODE_STOPWATCH, 0);
    assert.strictEqual(Engine.MODE_COUNTDOWN, 1);
    assert.strictEqual(Engine.MODE_INTERVALS, 2);
    assert.strictEqual(Engine.MODE_ALARM, 3);
    assert.strictEqual(Engine.MODE_POMODORO, 4);
  });

  test('MODES object provides bidirectional lookup', () => {
    assert.strictEqual(Engine.MODES.STOPWATCH, 0);
    assert.strictEqual(Engine.MODES.COUNTDOWN, 1);
    assert.strictEqual(Engine.MODES.INTERVALS, 2);
    assert.strictEqual(Engine.MODES.ALARM, 3);
    assert.strictEqual(Engine.MODES.POMODORO, 4);

    assert.strictEqual(Engine.MODES[0], 'STOPWATCH');
    assert.strictEqual(Engine.MODES[1], 'COUNTDOWN');
    assert.strictEqual(Engine.MODES[2], 'INTERVALS');
    assert.strictEqual(Engine.MODES[3], 'ALARM');
    assert.strictEqual(Engine.MODES[4], 'POMODORO');
  });

  test('ALARM_SOUNDS array contains expected freedesktop sound files', () => {
    assert.ok(Array.isArray(Engine.ALARM_SOUNDS));
    assert.strictEqual(Engine.ALARM_SOUNDS.length, 3);
    assert.strictEqual(Engine.ALARM_SOUNDS[0], 'alarm-clock-elapsed.oga');
    assert.strictEqual(Engine.ALARM_SOUNDS[1], 'bell.oga');
    assert.strictEqual(Engine.ALARM_SOUNDS[2], 'phone-incoming-call.oga');
  });
});

suite('2. Formatting & String Utilities', () => {
  test('pad2 formats numbers with leading zeros', () => {
    assert.strictEqual(Engine.pad2(0), '00');
    assert.strictEqual(Engine.pad2(7), '07');
    assert.strictEqual(Engine.pad2(12), '12');
    assert.strictEqual(Engine.pad2(59), '59');
    assert.strictEqual(Engine.pad2(null), '00');
    assert.strictEqual(Engine.pad2(undefined), '00');
  });

  test('formatTime without centiseconds (MM:SS and H:MM:SS)', () => {
    assert.strictEqual(Engine.formatTime(0, false), '00:00');
    assert.strictEqual(Engine.formatTime(5000, false), '00:05');
    assert.strictEqual(Engine.formatTime(65000, false), '01:05');
    assert.strictEqual(Engine.formatTime(599000, false), '09:59');
    assert.strictEqual(Engine.formatTime(3600000, false), '1:00:00');
    assert.strictEqual(Engine.formatTime(3665000, false), '1:01:05');
    assert.strictEqual(Engine.formatTime(36000000, false), '10:00:00');
  });

  test('formatTime with centiseconds (MM:SS.cs and H:MM:SS.cs)', () => {
    assert.strictEqual(Engine.formatTime(0, true), '00:00.00');
    assert.strictEqual(Engine.formatTime(50, true), '00:00.05');
    assert.strictEqual(Engine.formatTime(1230, true), '00:01.23');
    assert.strictEqual(Engine.formatTime(65430, true), '01:05.43');
    assert.strictEqual(Engine.formatTime(3665430, true), '1:01:05.43');
  });

  test('formatTime handles negative or NaN gracefully', () => {
    assert.strictEqual(Engine.formatTime(-5000, false), '00:00');
    assert.strictEqual(Engine.formatTime(NaN, false), '00:00');
    assert.strictEqual(Engine.formatTime(null, true), '00:00.00');
  });

  test('formatTime ceiling mode for countdown displays', () => {
    // 4900ms remaining in ceiling mode should display 00:05 instead of 00:04
    assert.strictEqual(Engine.formatTime(4900, false, true), '00:05');
    assert.strictEqual(Engine.formatTime(4100, false, true), '00:05');
    assert.strictEqual(Engine.formatTime(4000, false, true), '00:04');
    assert.strictEqual(Engine.formatTime(4900, false, false), '00:04');
  });
});

suite('3. Sound Cycling', () => {
  test('cycleAlarmSound forward navigation', () => {
    assert.strictEqual(
      Engine.cycleAlarmSound('alarm-clock-elapsed.oga', 1),
      'bell.oga'
    );
    assert.strictEqual(
      Engine.cycleAlarmSound('bell.oga', 1),
      'phone-incoming-call.oga'
    );
    assert.strictEqual(
      Engine.cycleAlarmSound('phone-incoming-call.oga', 1),
      'alarm-clock-elapsed.oga'
    );
  });

  test('cycleAlarmSound backward navigation', () => {
    assert.strictEqual(
      Engine.cycleAlarmSound('alarm-clock-elapsed.oga', -1),
      'phone-incoming-call.oga'
    );
    assert.strictEqual(
      Engine.cycleAlarmSound('phone-incoming-call.oga', -1),
      'bell.oga'
    );
  });

  test('cycleAlarmSound defaults and unknown sound handling', () => {
    // Default direction is +1
    assert.strictEqual(
      Engine.cycleAlarmSound('bell.oga'),
      'phone-incoming-call.oga'
    );
    // Unknown sound falls back to valid sound
    assert.strictEqual(
      Engine.cycleAlarmSound('unknown.oga', 1),
      'bell.oga'
    );
  });
});

suite('4. Alarm Calculations & 12h/24h Conversions', () => {
  test('12-hour and 24-hour conversions', () => {
    assert.deepStrictEqual(Engine.convert24To12(0), { displayHour: 12, meridiem: 'AM' });
    assert.deepStrictEqual(Engine.convert24To12(7), { displayHour: 7, meridiem: 'AM' });
    assert.deepStrictEqual(Engine.convert24To12(12), { displayHour: 12, meridiem: 'PM' });
    assert.deepStrictEqual(Engine.convert24To12(19), { displayHour: 7, meridiem: 'PM' });
    assert.deepStrictEqual(Engine.convert24To12(23), { displayHour: 11, meridiem: 'PM' });

    assert.strictEqual(Engine.convert12To24(12, 'AM'), 0);
    assert.strictEqual(Engine.convert12To24(7, 'AM'), 7);
    assert.strictEqual(Engine.convert12To24(12, 'PM'), 12);
    assert.strictEqual(Engine.convert12To24(7, 'PM'), 19);
    assert.strictEqual(Engine.convert12To24(11, 'PM'), 23);
  });

  test('computeAlarmTarget calculates next occurrence today if in future', () => {
    // Fixed now: 2026-09-17 08:00:00 local time
    const baseDate = new Date(2026, 8, 17, 8, 0, 0, 0);
    const nowMs = baseDate.getTime();

    // Alarm set for 09:30:00 today (1h 30m in future)
    const result = Engine.computeAlarmTarget(9, 30, nowMs);
    const expectedTarget = new Date(2026, 8, 17, 9, 30, 0, 0).getTime();

    assert.strictEqual(result.targetAt, expectedTarget);
    assert.strictEqual(result.durationMs, 90 * 60 * 1000);
  });

  test('computeAlarmTarget calculates next occurrence tomorrow if in past or right now', () => {
    // Fixed now: 2026-09-17 14:00:00 local time
    const baseDate = new Date(2026, 8, 17, 14, 0, 0, 0);
    const nowMs = baseDate.getTime();

    // Alarm set for 07:00:00 (past) -> triggers tomorrow 2026-09-18 07:00:00
    const pastResult = Engine.computeAlarmTarget(7, 0, nowMs);
    const expectedTomorrow = new Date(2026, 8, 18, 7, 0, 0, 0).getTime();
    assert.strictEqual(pastResult.targetAt, expectedTomorrow);
    assert.strictEqual(pastResult.durationMs, 17 * 3600 * 1000);

    // Alarm set for exactly 14:00:00 (target <= now) -> triggers tomorrow
    const exactResult = Engine.computeAlarmTarget(14, 0, nowMs);
    const expectedExactTomorrow = new Date(2026, 8, 18, 14, 0, 0, 0).getTime();
    assert.strictEqual(exactResult.targetAt, expectedExactTomorrow);
    assert.strictEqual(exactResult.durationMs, 24 * 3600 * 1000);
  });

  test('computeAlarmTarget supports 12h meridiem input', () => {
    const baseDate = new Date(2026, 8, 17, 10, 0, 0, 0);
    const nowMs = baseDate.getTime();

    // 2:00 PM today -> 14:00:00 (4 hours later)
    const result = Engine.computeAlarmTarget(2, 0, nowMs, 'PM');
    const expected = new Date(2026, 8, 17, 14, 0, 0, 0).getTime();
    assert.strictEqual(result.targetAt, expected);
    assert.strictEqual(result.durationMs, 4 * 3600 * 1000);
  });
});

suite('5. Stopwatch State Transitions', () => {
  test('Stopwatch start, elapsed time accumulation, pause, resume, reset', () => {
    let state = Engine.createInitialState({ mode: Engine.MODE_STOPWATCH });
    assert.strictEqual(state.running, false);
    assert.strictEqual(state.storedElapsedMs, 0);
    assert.strictEqual(Engine.getElapsedMs(state, 1000), 0);

    // 1. Start stopwatch at t = 1000
    let res = Engine.startPause(state, 1000);
    state = res.state;
    assert.strictEqual(state.running, true);
    assert.strictEqual(state.startedAt, 1000);
    assert.strictEqual(res.events.length, 0);

    // 2. Tick at t = 6000 (accumulated 5000ms)
    res = Engine.tick(state, 6000);
    state = res.state;
    assert.strictEqual(state.running, true);
    assert.strictEqual(Engine.getElapsedMs(state, 6000), 5000);
    assert.strictEqual(res.events.length, 0);

    // 3. Pause at t = 6000
    res = Engine.startPause(state, 6000);
    state = res.state;
    assert.strictEqual(state.running, false);
    assert.strictEqual(state.storedElapsedMs, 5000);

    // 4. Tick while paused at t = 9000 (elapsed remains 5000ms)
    res = Engine.tick(state, 9000);
    state = res.state;
    assert.strictEqual(state.running, false);
    assert.strictEqual(Engine.getElapsedMs(state, 9000), 5000);

    // 5. Resume at t = 10000
    res = Engine.startPause(state, 10000);
    state = res.state;
    assert.strictEqual(state.running, true);
    assert.strictEqual(state.startedAt, 10000);
    assert.strictEqual(state.storedElapsedMs, 5000);

    // 6. Tick at t = 13000 (5000 stored + 3000 = 8000ms)
    res = Engine.tick(state, 13000);
    state = res.state;
    assert.strictEqual(Engine.getElapsedMs(state, 13000), 8000);

    // 7. Reset
    res = Engine.reset(state, 13000);
    state = res.state;
    assert.strictEqual(state.running, false);
    assert.strictEqual(state.completed, false);
    assert.strictEqual(state.storedElapsedMs, 0);
    assert.strictEqual(Engine.getElapsedMs(state, 13000), 0);
  });
});

suite('6. Countdown State Transitions', () => {
  test('Countdown start, tick decrement, completion event', () => {
    // 5 minutes countdown = 300,000 ms
    let state = Engine.createInitialState({
      mode: Engine.MODE_COUNTDOWN,
      countdownMinutes: 5,
      countdownSeconds: 0,
      countdownMessage: 'Take a break'
    });

    assert.strictEqual(Engine.getTargetMs(state), 300000);
    assert.strictEqual(Engine.getDisplayMs(state, 0), 300000);

    // 1. Start at t = 1000
    let res = Engine.startPause(state, 1000);
    state = res.state;
    assert.strictEqual(state.running, true);

    // 2. Tick after 100s at t = 101000 -> 200,000 ms remaining
    res = Engine.tick(state, 101000);
    state = res.state;
    assert.strictEqual(state.running, true);
    assert.strictEqual(state.completed, false);
    assert.strictEqual(Engine.getElapsedMs(state, 101000), 100000);
    assert.strictEqual(Engine.getDisplayMs(state, 101000), 200000);
    assert.strictEqual(res.events.length, 0);

    // 3. Tick to completion at t = 301000 (300,000 ms elapsed)
    res = Engine.tick(state, 301000);
    state = res.state;
    assert.strictEqual(state.running, false);
    assert.strictEqual(state.completed, true);
    assert.strictEqual(state.storedElapsedMs, 300000);
    assert.strictEqual(Engine.getDisplayMs(state, 301000), 0);

    // Verify structured event payloads
    assert.strictEqual(res.events.length, 2);
    assert.deepStrictEqual(res.events[0], { type: 'sound', file: 'complete.oga' });
    assert.deepStrictEqual(res.events[1], {
      type: 'notify',
      title: 'Clockwork',
      body: 'Take a break'
    });

    // 4. Tick while completed does not re-emit events
    res = Engine.tick(state, 305000);
    state = res.state;
    assert.strictEqual(state.running, false);
    assert.strictEqual(res.events.length, 0);

    // 5. StartPause on completed resets and restarts
    res = Engine.startPause(state, 310000);
    state = res.state;
    assert.strictEqual(state.running, true);
    assert.strictEqual(state.completed, false);
    assert.strictEqual(state.storedElapsedMs, 0);
  });
});

suite('7. Intervals State Transitions', () => {
  test('Intervals round tracking and boundary events', () => {
    // 3 rounds of 10 seconds (10,000 ms) = 30,000 ms total
    let state = Engine.createInitialState({
      mode: Engine.MODE_INTERVALS,
      intervalRounds: 3,
      intervalMinutes: 0,
      intervalSeconds: 10
    });

    assert.strictEqual(Engine.getIntervalDurationMs(state), 10000);
    assert.strictEqual(Engine.getTargetMs(state), 30000);

    // Start at t = 0
    let res = Engine.startPause(state, 0);
    state = res.state;
    assert.strictEqual(state.running, true);

    // Round 1 in progress (t = 5000)
    res = Engine.tick(state, 5000);
    state = res.state;
    assert.strictEqual(Engine.getCurrentRound(state, 5000), 1);
    assert.strictEqual(res.events.length, 0);

    // Transition across round 1 boundary -> round 2 (t = 10000)
    res = Engine.tick(state, 10000);
    state = res.state;
    assert.strictEqual(Engine.getCurrentRound(state, 10000), 2);
    assert.strictEqual(state.notifiedIntervals, 1);
    assert.strictEqual(res.events.length, 2);
    assert.deepStrictEqual(res.events[0], { type: 'sound', file: 'complete.oga' });
    assert.deepStrictEqual(res.events[1], {
      type: 'notify',
      title: 'Clockwork',
      body: 'Round 1 complete · Round 2 starts now'
    });

    // Tick within round 2 (t = 15000) does NOT re-trigger boundary event
    res = Engine.tick(state, 15000);
    state = res.state;
    assert.strictEqual(Engine.getCurrentRound(state, 15000), 2);
    assert.strictEqual(res.events.length, 0);

    // Transition across round 2 boundary -> round 3 (t = 20000)
    res = Engine.tick(state, 20000);
    state = res.state;
    assert.strictEqual(Engine.getCurrentRound(state, 20000), 3);
    assert.strictEqual(state.notifiedIntervals, 2);
    assert.strictEqual(res.events.length, 2);
    assert.deepStrictEqual(res.events[1], {
      type: 'notify',
      title: 'Clockwork',
      body: 'Round 2 complete · Round 3 starts now'
    });

    // All rounds complete (t = 30000)
    res = Engine.tick(state, 30000);
    state = res.state;
    assert.strictEqual(state.running, false);
    assert.strictEqual(state.completed, true);
    assert.strictEqual(state.notifiedIntervals, 3);
    assert.strictEqual(res.events.length, 2);
    assert.deepStrictEqual(res.events[0], { type: 'sound', file: 'complete.oga' });
    assert.deepStrictEqual(res.events[1], {
      type: 'notify',
      title: 'Clockwork',
      body: 'All 3 rounds complete'
    });
  });
});

suite('8. Alarm State Transitions', () => {
  test('Alarm arming, tick before target, firing at target, disarming', () => {
    const baseDate = new Date(2026, 8, 17, 8, 0, 0, 0);
    const nowMs = baseDate.getTime();

    // Alarm for 9:00:00 (1 hour = 3,600,000 ms)
    let state = Engine.createInitialState({
      mode: Engine.MODE_ALARM,
      alarmHour: 9,
      alarmMinute: 0,
      alarmSound: 'bell.oga',
      alarmMessage: 'Morning Standup'
    });

    // 1. Arm alarm at 8:00
    let res = Engine.startPause(state, nowMs);
    state = res.state;
    assert.strictEqual(state.running, true);
    assert.strictEqual(state.completed, false);
    assert.strictEqual(state.alarmTargetDurationMs, 3600000);

    // 2. Tick at 8:30 (halfway)
    res = Engine.tick(state, nowMs + 1800000);
    state = res.state;
    assert.strictEqual(state.running, true);
    assert.strictEqual(state.completed, false);
    assert.strictEqual(res.events.length, 0);

    // 3. Tick at 9:00 (firing)
    res = Engine.tick(state, nowMs + 3600000);
    state = res.state;
    assert.strictEqual(state.running, false);
    assert.strictEqual(state.completed, true);
    assert.strictEqual(res.events.length, 2);
    assert.deepStrictEqual(res.events[0], { type: 'sound', file: 'bell.oga' });
    assert.deepStrictEqual(res.events[1], {
      type: 'notify',
      title: 'Clockwork',
      body: 'Morning Standup'
    });

    // 4. Reset disarms and clears alarm state
    res = Engine.reset(state, nowMs + 3600000);
    state = res.state;
    assert.strictEqual(state.running, false);
    assert.strictEqual(state.completed, false);
    assert.strictEqual(state.alarmTargetAt, 0);
  });
});

suite('9. Pomodoro State Transitions & Skips', () => {
  test('Full Pomodoro cycle progression (focus -> short break -> focus -> long break -> finish)', () => {
    // 2 cycles: Focus 25m, Short break 5m, Long break 15m
    let state = Engine.createInitialState({
      mode: Engine.MODE_POMODORO,
      pomodoroWorkMinutes: 25,
      pomodoroShortBreakMinutes: 5,
      pomodoroLongBreakMinutes: 15,
      pomodoroCycles: 2,
      pomodoroSoundEnabled: true
    });

    const workMs = 25 * 60 * 1000;
    const shortBreakMs = 5 * 60 * 1000;
    const longBreakMs = 15 * 60 * 1000;

    let t = 1000;

    // 1. Start Focus 1
    let res = Engine.startPause(state, t);
    state = res.state;
    assert.strictEqual(state.running, true);
    assert.strictEqual(state.pomodoroPhaseKind, 'focus');
    assert.strictEqual(state.pomodoroCurrentCycle, 1);
    assert.strictEqual(state.pomodoroCompletedCycles, 0);

    let phase = Engine.getPomodoroPhase(state, t);
    assert.strictEqual(phase.kind, 'focus');
    assert.strictEqual(phase.cycle, 1);
    assert.strictEqual(phase.label, 'Focus 1 of 2');

    // 2. Complete Focus 1 at t + workMs
    t += workMs;
    res = Engine.tick(state, t);
    state = res.state;
    assert.strictEqual(state.pomodoroPhaseKind, 'short-break');
    assert.strictEqual(state.pomodoroCompletedCycles, 1);
    assert.strictEqual(state.pomodoroCurrentCycle, 1);
    assert.strictEqual(state.running, true); // Auto-starts break

    assert.strictEqual(res.events.length, 2);
    assert.deepStrictEqual(res.events[0], { type: 'sound', file: 'complete.oga' });
    assert.deepStrictEqual(res.events[1], {
      type: 'notify',
      title: 'Clockwork',
      body: 'Focus 1 complete · Short break starts now'
    });

    phase = Engine.getPomodoroPhase(state, t);
    assert.strictEqual(phase.kind, 'short-break');
    assert.strictEqual(phase.label, 'Short break · Cycle 1 of 2');

    // 3. Complete Short Break 1 at t + shortBreakMs
    t += shortBreakMs;
    res = Engine.tick(state, t);
    state = res.state;
    assert.strictEqual(state.pomodoroPhaseKind, 'focus');
    assert.strictEqual(state.pomodoroCurrentCycle, 2);
    assert.strictEqual(state.pomodoroCompletedCycles, 1);
    assert.strictEqual(state.running, false); // Pauses for user to be ready for next focus

    assert.strictEqual(res.events.length, 2);
    assert.deepStrictEqual(res.events[1], {
      type: 'notify',
      title: 'Clockwork',
      body: 'Break complete · Ready for focus 2'
    });

    // 4. Start Focus 2
    res = Engine.startPause(state, t);
    state = res.state;
    assert.strictEqual(state.running, true);

    // 5. Complete Focus 2 at t + workMs (reaches cycles: 2 -> triggers long break)
    t += workMs;
    res = Engine.tick(state, t);
    state = res.state;
    assert.strictEqual(state.pomodoroPhaseKind, 'long-break');
    assert.strictEqual(state.pomodoroCompletedCycles, 2);
    assert.strictEqual(state.running, true); // Auto-starts long break

    assert.strictEqual(res.events.length, 2);
    assert.deepStrictEqual(res.events[1], {
      type: 'notify',
      title: 'Clockwork',
      body: 'Focus 2 complete · Long break starts now'
    });

    phase = Engine.getPomodoroPhase(state, t);
    assert.strictEqual(phase.kind, 'long-break');
    assert.strictEqual(phase.label, 'Long break');

    // 6. Complete Long Break at t + longBreakMs
    t += longBreakMs;
    res = Engine.tick(state, t);
    state = res.state;
    assert.strictEqual(state.running, false);
    assert.strictEqual(state.completed, true);

    assert.strictEqual(res.events.length, 2);
    assert.deepStrictEqual(res.events[1], {
      type: 'notify',
      title: 'Clockwork',
      body: 'All 2 focus cycles complete'
    });
  });

  test('Pomodoro skip phase transitions', () => {
    let state = Engine.createInitialState({
      mode: Engine.MODE_POMODORO,
      pomodoroCycles: 3
    });

    // 1. Start Pomodoro
    let res = Engine.startPause(state, 1000);
    state = res.state;
    assert.strictEqual(state.pomodoroPhaseKind, 'focus');
    assert.strictEqual(state.pomodoroCurrentCycle, 1);
    assert.strictEqual(state.pomodoroCompletedCycles, 0);

    // 2. Skip Focus 1 -> transitions to short break, completedCycles = 1
    res = Engine.skipPomodoro(state, 2000);
    state = res.state;
    assert.strictEqual(state.pomodoroPhaseKind, 'short-break');
    assert.strictEqual(state.pomodoroCompletedCycles, 1);
    assert.strictEqual(state.pomodoroCurrentCycle, 1);
    assert.strictEqual(state.running, true); // Short break starts immediately
    assert.strictEqual(res.events.length, 1);
    assert.deepStrictEqual(res.events[0], {
      type: 'notify',
      title: 'Clockwork',
      body: 'Focus skipped · Short break starts now'
    });

    // 3. Skip Short Break 1 -> prepares focus 2 (completedCycles 1 + 1 = 2)
    res = Engine.skipPomodoro(state, 3000);
    state = res.state;
    assert.strictEqual(state.pomodoroPhaseKind, 'focus');
    assert.strictEqual(state.pomodoroCompletedCycles, 1);
    assert.strictEqual(state.pomodoroCurrentCycle, 2);
    assert.strictEqual(state.running, false); // Paused waiting for user
    assert.strictEqual(res.events.length, 1);
    assert.deepStrictEqual(res.events[0], {
      type: 'notify',
      title: 'Clockwork',
      body: 'Break skipped · Ready for focus 2'
    });

    // 4. Start Focus 2, then skip Focus 2 -> short break 2, completedCycles = 2
    res = Engine.startPause(state, 3500);
    state = res.state;
    res = Engine.skipPomodoro(state, 4000);
    state = res.state;
    assert.strictEqual(state.pomodoroPhaseKind, 'short-break');
    assert.strictEqual(state.pomodoroCompletedCycles, 2);

    // 5. Skip Short Break 2 -> prepares focus 3 (completedCycles 2 + 1 = 3)
    res = Engine.skipPomodoro(state, 4500);
    state = res.state;
    assert.strictEqual(state.pomodoroPhaseKind, 'focus');
    assert.strictEqual(state.pomodoroCompletedCycles, 2);
    assert.strictEqual(state.pomodoroCurrentCycle, 3);

    // 6. Start Focus 3, then skip Focus 3 -> reached cycle 3/3, so transitions to long break!
    res = Engine.startPause(state, 5000);
    state = res.state;
    res = Engine.skipPomodoro(state, 5500);
    state = res.state;
    assert.strictEqual(state.pomodoroPhaseKind, 'long-break');
    assert.strictEqual(state.pomodoroCompletedCycles, 3);
    assert.strictEqual(state.running, true);
    assert.strictEqual(res.events.length, 1);
    assert.deepStrictEqual(res.events[0], {
      type: 'notify',
      title: 'Clockwork',
      body: 'Focus skipped · Long break starts now'
    });

    // 7. Skip Long Break -> session completes naturally
    res = Engine.skipPomodoro(state, 6000);
    state = res.state;
    assert.strictEqual(state.running, false);
    assert.strictEqual(state.completed, true);
    assert.strictEqual(res.events.length, 1);
    assert.deepStrictEqual(res.events[0], {
      type: 'notify',
      title: 'Clockwork',
      body: 'All 3 focus cycles complete'
    });
  });
});

suite('10. Status, Display Text & Progress Helpers', () => {
  test('getStatusText across modes and lifecycle states', () => {
    let s = Engine.createInitialState({ mode: Engine.MODE_STOPWATCH });
    assert.strictEqual(Engine.getStatusText(s), 'Ready');
    s.running = true;
    assert.strictEqual(Engine.getStatusText(s), 'Counting up');
    s.running = false;
    s.storedElapsedMs = 1000;
    assert.strictEqual(Engine.getStatusText(s), 'Paused');

    s = Engine.createInitialState({ mode: Engine.MODE_COUNTDOWN });
    assert.strictEqual(Engine.getStatusText(s), 'Ready');
    s.running = true;
    assert.strictEqual(Engine.getStatusText(s), 'Counting down');
    s.completed = true;
    assert.strictEqual(Engine.getStatusText(s), 'Time is up');

    s = Engine.createInitialState({ mode: Engine.MODE_INTERVALS, intervalRounds: 4, intervalMinutes: 1, intervalSeconds: 0 });
    assert.strictEqual(Engine.getStatusText(s), 'Round 1 of 4 · 01:00');
    s.completed = true;
    assert.strictEqual(Engine.getStatusText(s), 'Workout complete');

    s = Engine.createInitialState({ mode: Engine.MODE_ALARM, alarmHour: 7, alarmMinute: 30 });
    assert.strictEqual(Engine.getStatusText(s), 'Ready');
    s.running = true;
    assert.strictEqual(Engine.getStatusText(s), 'Armed for 07:30');
    s.completed = true;
    assert.strictEqual(Engine.getStatusText(s), 'Alarm ringing');

    s = Engine.createInitialState({ mode: Engine.MODE_POMODORO, pomodoroCycles: 4, pomodoroWorkMinutes: 25, pomodoroShortBreakMinutes: 5 });
    assert.strictEqual(Engine.getStatusText(s), '4 cycles · 25 / 5 min');
    s.pomodoroSessionStarted = true;
    s.running = true;
    assert.strictEqual(Engine.getStatusText(s), 'Focus 1 of 4');
    s.running = false;
    assert.strictEqual(Engine.getStatusText(s), 'Paused · Focus 1 of 4');
    s.completed = true;
    assert.strictEqual(Engine.getStatusText(s), 'Pomodoro complete');
  });

  test('getProgress calculations', () => {
    // Stopwatch progress is always 0
    let sw = Engine.createInitialState({ mode: Engine.MODE_STOPWATCH });
    assert.strictEqual(Engine.getProgress(sw, 0), 0);

    // Countdown progress
    let cd = Engine.createInitialState({ mode: Engine.MODE_COUNTDOWN, countdownMinutes: 1, countdownSeconds: 0 });
    cd.running = true;
    cd.startedAt = 0;
    assert.strictEqual(Engine.getProgress(cd, 30000), 0.5); // 30s / 60s
    assert.strictEqual(Engine.getProgress(cd, 60000), 1.0);
  });

  test('getDisplayText and getBarTimeText', () => {
    // Alarm display when armed vs idle
    let alarm = Engine.createInitialState({
      mode: Engine.MODE_ALARM,
      alarmHour: 14,
      alarmMinute: 30,
      alarmUses12Hour: true
    });
    // When idle and not started, displays target alarm time
    assert.strictEqual(Engine.getDisplayText(alarm, 0), '2:30 PM');
    // Bar text is empty when completely idle
    assert.strictEqual(Engine.getBarTimeText(alarm, 0), '');

    // When armed/running, displays countdown to alarm
    alarm.running = true;
    alarm.alarmTargetDurationMs = 3600000;
    alarm.startedAt = 0;
    assert.strictEqual(Engine.getDisplayText(alarm, 0), '1:00:00');
    assert.strictEqual(Engine.getBarTimeText(alarm, 0), '1:00:00');

    // Countdown bar text
    let cd = Engine.createInitialState({ mode: Engine.MODE_COUNTDOWN, countdownMinutes: 5 });
    assert.strictEqual(Engine.getBarTimeText(cd, 0), '');
    cd.running = true;
    cd.startedAt = 0;
    assert.strictEqual(Engine.getBarTimeText(cd, 60000), '04:00');
  });

  test('selectMode transitions and bounds checking', () => {
    let state = Engine.createInitialState({ mode: Engine.MODE_STOPWATCH });
    state.running = true;
    state.storedElapsedMs = 5000;

    // Selecting the same mode is a no-op (preserves running state)
    let res = Engine.selectMode(state, Engine.MODE_STOPWATCH);
    assert.strictEqual(res.state.mode, Engine.MODE_STOPWATCH);
    assert.strictEqual(res.state.running, true);

    // Switching mode resets state and updates mode
    res = Engine.selectMode(state, Engine.MODE_COUNTDOWN);
    assert.strictEqual(res.state.mode, Engine.MODE_COUNTDOWN);
    assert.strictEqual(res.state.running, false);
    assert.strictEqual(res.state.storedElapsedMs, 0);

    // Clamping invalid mode numbers
    res = Engine.selectMode(state, -5);
    assert.strictEqual(res.state.mode, Engine.MODE_STOPWATCH);
    res = Engine.selectMode(state, 99);
    assert.strictEqual(res.state.mode, Engine.MODE_POMODORO);
  });

  test('Pomodoro soundDisabled emits notifications without sound events', () => {
    let state = Engine.createInitialState({
      mode: Engine.MODE_POMODORO,
      pomodoroWorkMinutes: 25,
      pomodoroSoundEnabled: false
    });
    let res = Engine.startPause(state, 0);
    state = res.state;

    // Complete focus 1
    res = Engine.tick(state, 25 * 60 * 1000);
    assert.strictEqual(res.events.length, 1);
    assert.strictEqual(res.events[0].type, 'notify');
    assert.ok(!res.events.some(e => e.type === 'sound'));
  });
});

// ============================================================================
// Summary Report
// ============================================================================

console.log('\n========================================');
console.log(`TOTAL: ${passed + failed} | PASSED: \x1b[32m${passed}\x1b[0m | FAILED: \x1b[31m${failed}\x1b[0m`);
console.log('========================================');

if (failed > 0) {
  process.exit(1);
} else {
  process.exit(0);
}
