const assert = require('node:assert/strict');
const { test } = require('node:test');
const E = require('./load_engine')();
const loadMethods = require('./load_qml_methods');
const T0 = new Date(2026, 8, 30, 6, 0).getTime();

function bridge() {
  let now = T0;
  const root = Object.assign(E.createInitialState(), {
    stopwatchMode: 0, countdownMode: 1, intervalsMode: 2, alarmMode: 3, pomodoroMode: 4,
    isAlarmRinging: false, widgetInstances: [], configuredSettings: {},
    breakDismissed: false, completionBellsRemaining: 0,
    settingSaveRequested() {}, openPopoutRequested() {}, togglePopoutRequested() {}, closePopoutRequested() {}
  });
  const timer = { stop() {}, start() {}, restart() {} };
  const context = { root, Engine: E, Date: { now: () => now },
    alarmRingTimer: timer, completionBellTimer: timer, Quickshell: { execDetached() {} } };
  const methods = loadMethods('ClockworkState.qml', context);
  // IPC methods and root methods share names; the last definition is the root method.
  Object.assign(root, methods);
  return { root, context, setTime(value) { now = value; } };
}
function ipc(b) {
  // Restrict extraction to the actual IPC block so duplicate names cannot hide routing bugs.
  const fs = require('node:fs');
  const source = fs.readFileSync(require('node:path').join(__dirname, '..', 'ClockworkState.qml'), 'utf8');
  const start = source.indexOf('IpcHandler {');
  const end = source.indexOf('// Engine Bridge', start);
  // Utility supports a source override for the bounded block.
  return loadMethods('ClockworkState.qml', b.context, source.slice(start, end));
}
function widget(b, data) {
  const root = { timerState: b.root, pluginData: data,
    pluginService: {}, pluginId: 'dankClockwork' };
  Object.assign(root, loadMethods('ClockworkWidget.qml', { root, Engine: E }));
  return root;
}

test('unattached widgets cannot hydrate defaults before DMS supplies settings', () => {
  const b = bridge(); const w = widget(b, { countdownMinutes: 10 });
  w.pluginService = null;
  w.applyConfiguredSettings();
  assert.equal(b.root.countdownMinutes, 5);
  w.pluginService = {};
  w.applyConfiguredSettings();
  assert.equal(b.root.countdownMinutes, 10);
});

test('IPC stopwatch restarts both running and paused sessions', () => {
  const b = bridge(); const commands = ipc(b);
  commands.stopwatch(); b.setTime(T0 + 5000); commands.stopwatch();
  assert.equal(E.getElapsedMs(b.root, T0 + 5000), 0);
  b.setTime(T0 + 6000); b.root.pause(); b.setTime(T0 + 7000); commands.stopwatch();
  assert.equal(b.root.running, true);
  assert.equal(E.getElapsedMs(b.root, T0 + 7000), 0);
});

test('toggle dismisses a ringing alarm without arming tomorrow', () => {
  const b = bridge(); b.root.beginMode(3); b.root.setAlarmHour(7); b.root.start();
  b.setTime(T0 + 3600000); b.root.tick();
  assert.equal(b.root.isAlarmRinging, true);
  b.root.startPause();
  assert.equal(b.root.running, false);
  assert.equal(b.root.completed, false);
  assert.equal(b.root.isAlarmRinging, false);
  assert.equal(b.root.alarmTargetAt, 0);
});

for (const paused of [false, true]) {
  test('saved countdown defaults preserve ' + (paused ? 'paused' : 'running') + ' progress', () => {
    const b = bridge(); const w = widget(b, { countdownMinutes: 10 }); w.applyConfiguredSettings();
    b.root.beginMode(1); b.root.start(); b.setTime(T0 + 60000);
    if (paused) b.root.pause();
    w.pluginData = { countdownMinutes: 2, countdownSeconds: 30 }; w.applyConfiguredSettings();
    assert.equal(b.root.countdownMinutes, 10);
    assert.equal(E.getElapsedMs(b.root, T0 + 60000), 60000);
    assert.equal(b.root.running, !paused);
    b.root.reset();
    assert.equal(b.root.countdownMinutes, 2);
    assert.equal(b.root.countdownSeconds, 30);
    assert.equal(b.root.storedElapsedMs, 0);
  });
}

test('a new monitor preserves an IPC countdown and unrelated saved changes', () => {
  const b = bridge(); const data = { countdownMinutes: 5 }; widget(b, data).applyConfiguredSettings();
  ipc(b).countdown('10', '0'); b.setTime(T0 + 300000);
  widget(b, data).applyConfiguredSettings(); b.root.tick();
  assert.equal(b.root.countdownMinutes, 10);
  assert.equal(b.root.completed, false);
  assert.equal(E.getDisplayMs(b.root, T0 + 300000), 300000);
  const w = widget(b, { countdownMinutes: 5, alarmSound: 'bell.oga' }); w.applyConfiguredSettings();
  assert.equal(b.root.countdownMinutes, 10);
  assert.equal(b.root.alarmSound, 'bell.oga');
});

test('saved Pomodoro changes preserve the entire started session between phases', () => {
  const b = bridge(); const w = widget(b, {}); w.applyConfiguredSettings();
  b.root.beginMode(4); b.root.start(); b.root.skipPomodoroPhase(); b.root.skipPomodoroPhase();
  assert.equal(b.root.running, false);
  assert.equal(b.root.pomodoroCurrentCycle, 2);
  w.pluginData = { pomodoroWorkMinutes: 10, pomodoroCycles: 1 }; w.applyConfiguredSettings();
  assert.equal(b.root.pomodoroWorkMinutes, 25);
  assert.equal(b.root.pomodoroCycles, 4);
  assert.equal(b.root.pomodoroCurrentCycle, 2);
  assert.equal(b.root.pomodoroSessionStarted, true);
  b.root.reset();
  assert.equal(b.root.pomodoroWorkMinutes, 10);
  assert.equal(b.root.pomodoroCycles, 1);
});

test('completed countdown remains completed until reset applies pending defaults', () => {
  const b = bridge(); const w = widget(b, { countdownMinutes: 0, countdownSeconds: 1 });
  w.applyConfiguredSettings(); b.root.beginMode(1); b.root.start();
  b.setTime(T0 + 1000); b.root.tick();
  w.pluginData = { countdownMinutes: 2, countdownSeconds: 0 }; w.applyConfiguredSettings();
  assert.equal(b.root.completed, true);
  assert.equal(b.root.countdownMinutes, 0);
  b.root.reset(); assert.equal(b.root.countdownMinutes, 2);
});

test('widget ownership ignores bar position and hands over after removal', () => {
  const b = bridge(); const a = { isFirst: false }, c = { isFirst: false };
  b.root.registerWidget(a); b.root.registerWidget(c); b.root.registerWidget(a);
  assert.equal(b.root.widgetInstances.length, 2);
  assert.equal(b.root.widgetInstances[0], a);
  b.root.unregisterWidget(a);
  assert.equal(b.root.widgetInstances.length, 1);
  assert.equal(b.root.widgetInstances[0], c);
  b.root.unregisterWidget(c);
  assert.equal(b.root.widgetInstances.length, 0);
});
