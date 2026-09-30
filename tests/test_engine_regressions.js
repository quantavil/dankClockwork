// Regression tests for the audit fixes. Run: node tests/test_engine_regressions.js
const assert = require("assert");
const E = require("./load_engine.js")();

let passed = 0;
let failed = 0;
function test(name, fn) {
  try {
    fn();
    passed++;
    console.log("  ok   " + name);
  } catch (err) {
    failed++;
    console.log("  FAIL " + name + "\n       " + err.message);
  }
}

const T0 = 1_700_000_000_000;
const make = (opts) => E.createInitialState(opts);
const run = (state, fn, now) => fn(state, now).state;

// ---------------------------------------------------------------------------
console.log("state factory / helpers");
test("createInitialState honours DEFAULTS and empty strings", () => {
  const s = make({ countdownMessage: "", alarmSound: "" });
  assert.strictEqual(s.countdownMessage, E.DEFAULTS.countdownMessage);
  assert.strictEqual(s.alarmSound, E.DEFAULTS.alarmSound);
});
test("clampInt floors, clamps and falls back on NaN", () => {
  assert.strictEqual(E.clampInt(5.9, 0, 10, 1), 5);
  assert.strictEqual(E.clampInt(-3, 0, 10, 1), 0);
  assert.strictEqual(E.clampInt(99, 0, 10, 1), 10);
  assert.strictEqual(E.clampInt("abc", 0, 10, 7), 7);
  assert.strictEqual(E.clampInt(0, 1, 10, 1), 1);
});
test("parseIntArg is strict", () => {
  assert.strictEqual(E.parseIntArg("25", NaN), 25);
  assert.strictEqual(E.parseIntArg(" 7 ", NaN), 7);
  assert.strictEqual(E.parseIntArg("", 3), 3);
  assert.strictEqual(E.parseIntArg(undefined, 3), 3);
  for (const bad of ["5abc", "-1", "1.5", "0x10", "abc"]) {
    assert.ok(Number.isNaN(E.parseIntArg(bad, 0)), bad);
  }
});
// ---------------------------------------------------------------------------
console.log("alarm");
function armedAlarm() {
  return run(make({ mode: E.MODE_ALARM, alarmHour: 23, alarmMinute: 59 }), E.startPause, T0);
}
test("pause() on an armed alarm disarms it (no paused-alarm limbo)", () => {
  const armed = armedAlarm();
  assert.strictEqual(armed.running, true);
  const after = run(armed, E.pause, T0 + 1000);
  assert.strictEqual(after.running, false);
  assert.strictEqual(after.storedElapsedMs, 0);
  assert.strictEqual(after.alarmTargetAt, 0);
  assert.strictEqual(E.getBarTimeText(after), "");
});
test("startPause() on an armed alarm still disarms", () => {
  const after = run(armedAlarm(), E.startPause, T0 + 1000);
  assert.strictEqual(after.running, false);
  assert.strictEqual(after.alarmTargetAt, 0);
});
test("alarm fires with an urgent notification and shows the alarm time", () => {
  const armed = armedAlarm();
  const res = E.tick(armed, armed.alarmTargetAt + 10);
  assert.strictEqual(res.state.completed, true);
  const note = res.events.find(e => e.type === "notify");
  assert.strictEqual(note.urgent, true);
  assert.strictEqual(E.getDisplayText(res.state, armed.alarmTargetAt + 10), "23:59");
  assert.strictEqual(E.getBarTimeText(res.state, armed.alarmTargetAt + 10), "23:59");
});
test("non-alarm notifications are not urgent", () => {
  const s = run(make({ mode: E.MODE_COUNTDOWN, countdownMinutes: 0, countdownSeconds: 1 }), E.startPause, T0);
  const res = E.tick(s, T0 + 2000);
  assert.ok(res.events.every(e => !e.urgent));
});
test("running alarm bar text is the target time, not a ticking countdown", () => {
  assert.strictEqual(E.getBarTimeText(armedAlarm(), T0 + 5000), "23:59");
});

// ---------------------------------------------------------------------------
console.log("UI affordances");
test("canStart is false only for a 00:00 target", () => {
  assert.strictEqual(E.canStart(make({ mode: E.MODE_COUNTDOWN, countdownMinutes: 0, countdownSeconds: 0 })), false);
  assert.strictEqual(E.canStart(make({ mode: E.MODE_COUNTDOWN, countdownMinutes: 0, countdownSeconds: 5 })), true);
  assert.strictEqual(E.canStart(make({ mode: E.MODE_STOPWATCH })), true);
  assert.strictEqual(E.canStart(make({ mode: E.MODE_ALARM })), true);
  assert.strictEqual(E.canStart(make({ mode: E.MODE_POMODORO })), true);
});
test("canSwitchMode protects a session with progress", () => {
  const idle = make({ mode: E.MODE_STOPWATCH });
  assert.strictEqual(E.canSwitchMode(idle), true);
  const running = run(idle, E.startPause, T0);
  assert.strictEqual(E.canSwitchMode(running), false);
  const paused = run(running, E.pause, T0 + 3000);
  assert.strictEqual(E.canSwitchMode(paused), false, "paused with elapsed time must be protected");
  assert.strictEqual(E.canSwitchMode(run(paused, E.reset, T0 + 4000)), true);
});
test("canSwitchMode allows leaving a completed timer", () => {
  const s = run(make({ mode: E.MODE_COUNTDOWN, countdownMinutes: 0, countdownSeconds: 1 }), E.startPause, T0);
  const done = E.tick(s, T0 + 5000).state;
  assert.strictEqual(done.completed, true);
  assert.strictEqual(E.canSwitchMode(done), true);
});
test("canSwitchMode protects a started Pomodoro even between phases", () => {
  let s = run(make({ mode: E.MODE_POMODORO }), E.startPause, T0);
  s = run(s, E.skipPomodoro, T0 + 100);   // focus -> break
  s = run(s, E.skipPomodoro, T0 + 200);   // break -> focus (waiting)
  assert.strictEqual(s.running, false);
  assert.strictEqual(E.canSwitchMode(s), false);
});

// ---------------------------------------------------------------------------
console.log("pomodoro transitions (tick + skip share one implementation)");
function fastPomodoro(extra) {
  return make(Object.assign({ mode: E.MODE_POMODORO, pomodoroCycles: 2, pomodoroWorkMinutes: 1,
    pomodoroShortBreakMinutes: 1, pomodoroLongBreakMinutes: 1 }, extra));
}
test("natural phase transitions chime; manual skips do not", () => {
  const sounds = (res) => res.events.filter(e => e.type === "sound");
  const on = run(fastPomodoro(), E.startPause, T0);
  assert.strictEqual(sounds(E.tick(on, T0 + 61000)).length, 1);
  assert.strictEqual(sounds(E.skipPomodoro(on, T0 + 1000)).length, 0);
});
test("skip wording differs from natural completion", () => {
  const s = run(fastPomodoro(), E.startPause, T0);
  const skipped = E.skipPomodoro(s, T0 + 500).events.find(e => e.type === "notify").body;
  const natural = E.tick(s, T0 + 61000).events.find(e => e.type === "notify").body;
  assert.ok(skipped.startsWith("Focus skipped"));
  assert.ok(natural.startsWith("Focus 1 complete"));
});
test("skip keeps nowMs fresh (long-break branch used to leave it stale)", () => {
  let s = run(fastPomodoro({ pomodoroCycles: 1 }), E.startPause, T0);
  s = run(s, E.skipPomodoro, T0 + 100);            // -> long break
  const done = E.skipPomodoro(s, T0 + 9999).state; // skip the long break -> completed
  assert.strictEqual(done.completed, true);
  assert.strictEqual(done.nowMs, T0 + 9999);
});

console.log("\n" + passed + " passed, " + failed + " failed");
process.exit(failed ? 1 : 0);
