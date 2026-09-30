pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "ClockworkEngine.js" as Engine

Item {
    id: root

    // =========================================================================
    // Mode Constants
    // =========================================================================
    readonly property int stopwatchMode: 0
    readonly property int countdownMode: 1
    readonly property int intervalsMode: 2
    readonly property int alarmMode: 3
    readonly property int pomodoroMode: 4

    // =========================================================================
    // Engine State
    // Every property listed in Engine.STATE_KEYS must be declared here with the same name.
    // The engine owns the transitions; this singleton only mirrors its results.
    // =========================================================================
    property int mode: stopwatchMode
    property bool running: false
    property bool completed: false
    property double startedAt: 0
    property double storedElapsedMs: 0
    property double nowMs: Date.now()

    property int countdownMinutes: Engine.DEFAULTS.countdownMinutes
    property int countdownSeconds: Engine.DEFAULTS.countdownSeconds
    property bool countdownFullscreenEnabled: Engine.DEFAULTS.countdownFullscreenEnabled
    property string countdownMessage: Engine.DEFAULTS.countdownMessage

    property int intervalRounds: Engine.DEFAULTS.intervalRounds
    property int intervalMinutes: Engine.DEFAULTS.intervalMinutes
    property int intervalSeconds: Engine.DEFAULTS.intervalSeconds
    property int notifiedIntervals: 0

    property int alarmHour: Engine.DEFAULTS.alarmHour
    property int alarmMinute: Engine.DEFAULTS.alarmMinute
    property bool alarmUses12Hour: Engine.DEFAULTS.alarmUses12Hour
    property string alarmSound: Engine.DEFAULTS.alarmSound
    property string alarmMessage: Engine.DEFAULTS.alarmMessage
    property double alarmTargetAt: 0
    property int alarmTargetDurationMs: 0

    property int pomodoroWorkMinutes: Engine.DEFAULTS.pomodoroWorkMinutes
    property int pomodoroShortBreakMinutes: Engine.DEFAULTS.pomodoroShortBreakMinutes
    property int pomodoroCycles: Engine.DEFAULTS.pomodoroCycles
    property int pomodoroLongBreakMinutes: Engine.DEFAULTS.pomodoroLongBreakMinutes
    property string pomodoroPhaseKind: "focus"
    property int pomodoroCurrentCycle: 1
    property int pomodoroCompletedCycles: 0
    property bool pomodoroSessionStarted: false

    // =========================================================================
    // Shell-side State (not part of the engine)
    // =========================================================================
    property bool popoutOpen: false
    property bool isAlarmRinging: false
    property bool breakDismissed: false
    property int completionBellsRemaining: 0
    property string completionSoundFile: "complete.oga"
    property double alarmRingEndsAt: 0
    property var widgetInstances: []
    readonly property var hostWidget: widgetInstances.length ? widgetInstances[0] : null
    property var configuredSettings: ({})

    // Signals for host widget synchronization
    signal settingSaveRequested(string key, var value)
    signal openPopoutRequested()
    signal togglePopoutRequested()
    signal closePopoutRequested()

    // =========================================================================
    // Derived State
    // `snapshot` is rebuilt once per state change; every getter below reads it,
    // instead of each binding building its own 30-field object on every tick.
    // =========================================================================
    readonly property var snapshot: root.getEngineSnapshot()

    readonly property string displayText: Engine.getDisplayText(root.snapshot)
    readonly property string barTimeText: Engine.getBarTimeText(root.snapshot)
    readonly property string statusText: Engine.getStatusText(root.snapshot)
    readonly property real progress: Engine.getProgress(root.snapshot)
    readonly property string modeName: Engine.getModeName(root.mode)
    readonly property var pomodoroPhase: Engine.getPomodoroPhase(root.snapshot)
    readonly property int currentRound: Engine.getCurrentRound(root.snapshot)

    readonly property int alarmDisplayHour: Engine.convert24To12(root.alarmHour).displayHour
    readonly property string alarmMeridiem: Engine.convert24To12(root.alarmHour).meridiem
    readonly property string alarmSoundName: Engine.getAlarmSoundName(root.alarmSound)
    readonly property string alarmTimeText: Engine.getAlarmTimeText(root.snapshot)
    readonly property string intervalDurationText: Engine.pad2(root.intervalMinutes) + ":" + Engine.pad2(root.intervalSeconds)

    // UI affordances: switching modes discards progress, and Start is a no-op for a 00:00 target.
    readonly property bool canSwitchMode: Engine.canSwitchMode(root.snapshot)
    readonly property bool canStartPause: root.running || Engine.canStart(root.snapshot)

    // =========================================================================
    // Timers
    // =========================================================================
    Timer {
        id: tickTimer
        // ~30 fps is plenty for a centisecond readout; the bar only needs coarse updates.
        interval: (root.popoutOpen && root.mode === root.stopwatchMode) ? 33 : 250
        repeat: true
        running: root.running
        onTriggered: root.tick()
    }

    Timer {
        id: completionBellTimer
        interval: 600
        repeat: false
        onTriggered: root.playNextCompletionBell()
    }

    Timer {
        id: alarmRingTimer
        interval: 3000
        repeat: true
        onTriggered: {
            if (Date.now() >= root.alarmRingEndsAt) {
                root.stopAlarmRinging();
                return;
            }
            root.playSound(root.alarmSound);
        }
    }

    // =========================================================================
    // Unified IPC Interface (Singleton: guarantees single registration across monitors)
    //
    // Mode commands are idempotent "configure and (re)start": calling `countdown 10` while a
    // countdown runs restarts it at 10:00 instead of toggling it into a paused state.
    // Values passed over IPC are one-off: they are NOT written back to saved defaults.
    // =========================================================================
    IpcHandler {
        target: "dankClockwork"

        function stopwatch(): string {
            root.beginMode(root.stopwatchMode);
            root.start();
            return "CLOCKWORK_STOPWATCH_STARTED";
        }

        function countdown(minutes: string, seconds: string): string {
            const m = Engine.parseIntArg(minutes, NaN);
            const s = Engine.parseIntArg(seconds, 0);
            const total = m * 60 + s;
            const maxTotal = Engine.LIMITS.COUNTDOWN_MINUTES_MAX * 60 + Engine.LIMITS.COUNTDOWN_SECONDS_MAX;
            if (isNaN(total) || total <= 0 || total > maxTotal) {
                return "ERROR_INVALID_ARGUMENTS";
            }
            root.beginMode(root.countdownMode);
            // Seconds carry into minutes: `countdown 0 90` is 1:30.
            root.setCountdownMinutes(Math.floor(total / 60), false);
            root.setCountdownSeconds(total % 60, false);
            root.start();
            return "CLOCKWORK_COUNTDOWN_STARTED";
        }

        function intervals(rounds: string, minutes: string, seconds: string): string {
            const r = Engine.parseIntArg(rounds, NaN);
            const m = Engine.parseIntArg(minutes, 0);
            const s = Engine.parseIntArg(seconds, 0);
            if (isNaN(r) || isNaN(m) || isNaN(s) || r <= 0 || (m === 0 && s === 0)) {
                return "ERROR_INVALID_ARGUMENTS";
            }
            root.beginMode(root.intervalsMode);
            root.configureInterval(r, m, s);
            root.start();
            return "CLOCKWORK_INTERVALS_STARTED";
        }

        function alarm(hour: string, minute: string, message: string): string {
            const h = Engine.parseIntArg(hour, NaN);
            const m = Engine.parseIntArg(minute, 0);
            if (isNaN(h) || isNaN(m) || h > Engine.LIMITS.ALARM_HOUR_MAX || m > Engine.LIMITS.ALARM_MINUTE_MAX) {
                return "ERROR_INVALID_ARGUMENTS";
            }
            root.beginMode(root.alarmMode);
            root.setAlarmHour(h);
            root.setAlarmMinute(m);
            // Always reset the message so a previous call's text never leaks into this alarm.
            root.setAlarmMessage(message);
            root.start();
            return "CLOCKWORK_ALARM_ARMED";
        }

        function pomodoro(work: string, shortBreak: string, cycles: string, longBreak: string): string {
            const w = Engine.parseIntArg(work, root.pomodoroWorkMinutes);
            const sb = Engine.parseIntArg(shortBreak, root.pomodoroShortBreakMinutes);
            const c = Engine.parseIntArg(cycles, root.pomodoroCycles);
            const lb = Engine.parseIntArg(longBreak, root.pomodoroLongBreakMinutes);
            if (isNaN(w) || isNaN(sb) || isNaN(c) || isNaN(lb) || w <= 0 || sb <= 0 || c <= 0 || lb <= 0) {
                return "ERROR_INVALID_ARGUMENTS";
            }
            root.beginMode(root.pomodoroMode);
            root.configurePomodoro(w, sb, c, lb);
            root.start();
            return "CLOCKWORK_POMODORO_STARTED";
        }

        function start(): string {
            if (root.running) return "CLOCKWORK_ALREADY_RUNNING";
            root.start();
            return "CLOCKWORK_STARTED";
        }

        function pause(): string {
            if (!root.running) return "CLOCKWORK_ALREADY_PAUSED";
            root.pause();
            return "CLOCKWORK_PAUSED";
        }

        function toggle(): string {
            root.startPause();
            return root.running ? "CLOCKWORK_RUNNING" : "CLOCKWORK_PAUSED";
        }

        function reset(): string {
            root.reset();
            return "CLOCKWORK_RESET";
        }

        function skip(): string {
            if (root.mode !== root.pomodoroMode) return "ERROR_NOT_POMODORO";
            root.skipPomodoroPhase();
            return "CLOCKWORK_POMODORO_SKIPPED";
        }

        function status(): string {
            return JSON.stringify({
                mode: root.modeName,
                running: root.running,
                completed: root.completed,
                displayText: root.displayText,
                statusText: root.statusText,
                progress: root.progress
            });
        }

        function open(): string {
            root.openPopoutRequested();
            return "CLOCKWORK_POPOUT_OPENED";
        }

        function togglePopout(): string {
            root.togglePopoutRequested();
            return "CLOCKWORK_POPOUT_TOGGLED";
        }

        function close(): string {
            root.closePopoutRequested();
            return "CLOCKWORK_POPOUT_CLOSED";
        }
    }

    // =========================================================================
    // Engine Bridge
    // =========================================================================
    function getEngineSnapshot() {
        const snap = {};
        for (const key of Engine.STATE_KEYS) {
            snap[key] = root[key];
        }
        return snap;
    }

    function applyEngineState(s) {
        if (!s) return;
        for (const key of Engine.STATE_KEYS) {
            if (root[key] !== s[key]) root[key] = s[key];
        }
    }

    // Runs one engine transition and applies its state + side effects.
    function dispatch(result) {
        root.applyEngineState(result.state);
        root.processEvents(result.events);
    }

    // =========================================================================
    // Sound & Notification Bridges
    // =========================================================================
    function playSound(file) {
        const soundFile = file || "complete.oga";
        const soundPath = soundFile.startsWith("/")
            ? soundFile
            : "/usr/share/sounds/freedesktop/stereo/" + soundFile;
        Quickshell.execDetached(["pw-play", "--volume", "1.0", soundPath]);
    }

    function notify(body, title, isUrgent) {
        const args = ["notify-send", "-a", "DankClockwork"];
        if (isUrgent) {
            args.push("-u", "critical", "-c", "alarm");
        }
        args.push(title || "DankClockwork");
        if (body !== undefined && body !== null && String(body) !== "") {
            args.push(String(body));
        }
        Quickshell.execDetached(args);
    }

    function processEvents(events) {
        if (!events || !events.length) return;
        for (const ev of events) {
            if (ev.type === "sound") {
                if (root.completed && root.mode === root.alarmMode) {
                    root.startAlarmRinging();
                } else if (root.completed) {
                    root.playCompletionSequence(ev.file);
                } else {
                    root.playSound(ev.file);
                }
            } else if (ev.type === "notify") {
                root.notify(ev.body, ev.title, ev.urgent === true);
            }
        }
    }

    function startAlarmRinging() {
        alarmRingTimer.stop();
        root.isAlarmRinging = true;
        root.alarmRingEndsAt = Date.now() + 3 * 60 * 1000;
        root.playSound(root.alarmSound);
        alarmRingTimer.start();
    }

    function stopAlarmRinging() {
        alarmRingTimer.stop();
        root.isAlarmRinging = false;
        root.alarmRingEndsAt = 0;
    }

    function stopAllSounds() {
        root.stopAlarmRinging();
        completionBellTimer.stop();
        root.completionBellsRemaining = 0;
    }

    function dismissFullscreenBreak() {
        root.breakDismissed = true;
    }

    // Natural completion chimes; manual phase skips only notify.
    function playCompletionSequence(soundFile) {
        completionBellTimer.stop();
        root.completionSoundFile = soundFile || "complete.oga";
        root.completionBellsRemaining = 3;
        root.playNextCompletionBell();
    }

    function playNextCompletionBell() {
        if (root.completionBellsRemaining <= 0) return;
        root.playSound(root.completionSoundFile);
        root.completionBellsRemaining -= 1;
        if (root.completionBellsRemaining > 0) {
            completionBellTimer.restart();
        }
    }

    // =========================================================================
    // Core Actions
    // =========================================================================
    function tick() {
        root.nowMs = Date.now();
        if (!root.running || root.mode === root.stopwatchMode) return;
        root.dispatch(Engine.tick(root.getEngineSnapshot(), root.nowMs));
    }

    function startPause() {
        if (root.isAlarmRinging) {
            root.reset();
            return;
        }
        if (root.completed || (root.running && root.mode === root.alarmMode)) {
            root.stopAllSounds();
        }
        if (root.completed) root.reset();
        root.breakDismissed = false;
        root.dispatch(Engine.startPause(root.getEngineSnapshot(), Date.now()));
    }

    function start() {
        if (!root.running) root.startPause();
    }

    function pause() {
        // Pausing an armed alarm disarms it; make sure nothing keeps ringing.
        if (root.mode === root.alarmMode) root.stopAllSounds();
        root.dispatch(Engine.pause(root.getEngineSnapshot(), Date.now()));
    }

    function reset(restoreDefaults) {
        root.stopAllSounds();
        root.breakDismissed = false;
        root.dispatch(Engine.reset(root.getEngineSnapshot(), Date.now()));
        if (restoreDefaults !== false) root.applyConfiguredSettings(root.configuredSettings, true);
    }

    // Unconditional mode switch (used by IPC, which always wins).
    function selectMode(nextMode) {
        root.stopAllSounds();
        root.dispatch(Engine.selectMode(root.getEngineSnapshot(), nextMode, Date.now()));
        root.applyConfiguredSettings(root.configuredSettings, true);
    }

    // User-initiated mode switch (tabs / number keys). Refuses to silently discard a running or
    // paused session. Returns whether the switch happened.
    function requestMode(nextMode) {
        if (nextMode === root.mode) return true;
        if (!root.canSwitchMode) return false;
        root.selectMode(nextMode);
        return true;
    }

    // Switch to `nextMode` with a clean slate, ready to be configured and started.
    function beginMode(nextMode) {
        root.selectMode(nextMode);
        root.reset();
    }

    function skipPomodoroPhase() {
        root.dispatch(Engine.skipPomodoro(root.getEngineSnapshot(), Date.now()));
    }

    // Bar position is unrelated to ownership. Registration also supports host handover.
    function registerWidget(widget) {
        if (root.widgetInstances.indexOf(widget) !== -1) return;
        root.widgetInstances = root.widgetInstances.concat([widget]);
    }

    function unregisterWidget(widget) {
        root.widgetInstances = root.widgetInstances.filter(instance => instance !== widget);
    }

    // Saved durations are defaults for the next session; active/paused/completed sessions
    // keep their configuration. Sound, format and reminder preferences can change live.
    function applyConfiguredSettings(data, restoreDefaults) {
        const D = Engine.DEFAULTS;
        const table = [
            ["pomodoroWorkMinutes", D.pomodoroWorkMinutes, v => root.setPomodoroWorkMinutes(v, false), root.pomodoroMode],
            ["pomodoroShortBreakMinutes", D.pomodoroShortBreakMinutes, v => root.setPomodoroShortBreakMinutes(v, false), root.pomodoroMode],
            ["pomodoroLongBreakMinutes", D.pomodoroLongBreakMinutes, v => root.setPomodoroLongBreakMinutes(v, false), root.pomodoroMode],
            ["pomodoroCycles", D.pomodoroCycles, v => root.setPomodoroCycles(v, false), root.pomodoroMode],
            ["alarmUses12Hour", D.alarmUses12Hour, v => root.setAlarmUses12Hour(v, false)],
            ["alarmSound", D.alarmSound, v => root.setAlarmSound(v, false)],
            ["countdownFullscreenEnabled", D.countdownFullscreenEnabled, v => root.setCountdownFullscreenEnabled(v, false)],
            ["countdownMessage", D.countdownMessage, v => root.setCountdownMessage(v, false)],
            ["countdownMinutes", D.countdownMinutes, v => root.setCountdownMinutes(v, false), root.countdownMode],
            ["countdownSeconds", D.countdownSeconds, v => root.setCountdownSeconds(v, false), root.countdownMode]
        ];
        const previous = root.configuredSettings;
        const next = {};
        const protectedSession = root.completed || Engine.hasProgress(root.getEngineSnapshot());
        const pending = [];
        for (const [key, fallback, apply, sessionMode] of table) {
            const given = data ? data[key] : undefined;
            const value = (given === undefined || given === null || given === "") ? fallback : given;
            next[key] = value;
            if (sessionMode === root.mode && protectedSession) continue;
            if (previous[key] !== value || restoreDefaults === true) pending.push(() => apply(value));
        }
        // Publish before setters run: synchronous host signals must see the shared cache.
        root.configuredSettings = next;
        for (const apply of pending) apply();
    }

    // =========================================================================
    // Setters
    // Every setter validates, stores, optionally persists (`notifyHost !== false` and a host key),
    // and resets an idle timer of the affected mode so the display reflects the new value.
    // =========================================================================
    function commit(prop, value, hostKey, notifyHost, resetMode) {
        if (root[prop] === value) return false;
        root[prop] = value;
        if (hostKey && notifyHost !== false) root.settingSaveRequested(hostKey, value);
        if (resetMode !== undefined && !root.running && root.mode === resetMode) root.reset(false);
        return true;
    }

    // --- Countdown ---
    function setCountdownMinutes(value, notifyHost) {
        const L = Engine.LIMITS;
        root.commit("countdownMinutes", Engine.clampInt(value, L.COUNTDOWN_MINUTES_MIN, L.COUNTDOWN_MINUTES_MAX, 0),
            "countdownMinutes", notifyHost, root.countdownMode);
    }

    function setCountdownSeconds(value, notifyHost) {
        const L = Engine.LIMITS;
        root.commit("countdownSeconds", Engine.clampInt(value, L.COUNTDOWN_SECONDS_MIN, L.COUNTDOWN_SECONDS_MAX, 0),
            "countdownSeconds", notifyHost, root.countdownMode);
    }

    function setCountdownFullscreenEnabled(enabled, notifyHost) {
        root.commit("countdownFullscreenEnabled", Boolean(enabled), "countdownFullscreenEnabled", notifyHost);
    }

    function setCountdownMessage(message, notifyHost) {
        const cleaned = String(message || "").trim();
        root.commit("countdownMessage", cleaned === "" ? Engine.DEFAULTS.countdownMessage : cleaned,
            "countdownMessage", notifyHost);
    }

    // --- Alarm ---
    function setAlarmHour(value) {
        const L = Engine.LIMITS;
        root.commit("alarmHour", Engine.clampInt(value, L.ALARM_HOUR_MIN, L.ALARM_HOUR_MAX, 0), null, false, root.alarmMode);
    }

    function setAlarmMinute(value) {
        const L = Engine.LIMITS;
        root.commit("alarmMinute", Engine.clampInt(value, L.ALARM_MINUTE_MIN, L.ALARM_MINUTE_MAX, 0), null, false, root.alarmMode);
    }

    function setAlarmDisplayHour(value) {
        root.commit("alarmHour", Engine.convert12To24(value, root.alarmMeridiem), null, false, root.alarmMode);
    }

    function setAlarmMeridiem(value) {
        root.commit("alarmHour", Engine.convert12To24(root.alarmDisplayHour, value), null, false, root.alarmMode);
    }

    function setAlarmUses12Hour(enabled, notifyHost) {
        root.commit("alarmUses12Hour", Boolean(enabled), "alarmUses12Hour", notifyHost);
    }

    function setAlarmSound(value, notifyHost) {
        const next = Engine.ALARM_SOUNDS.indexOf(String(value || "")) === -1 ? Engine.ALARM_SOUNDS[0] : String(value);
        root.commit("alarmSound", next, "alarmSound", notifyHost);
    }

    function setAlarmMessage(message) {
        const cleaned = String(message || "").trim();
        root.alarmMessage = cleaned === "" ? Engine.DEFAULTS.alarmMessage : cleaned;
    }

    // --- Intervals ---
    // Applies rounds + duration atomically (one reset, never a 00:00 round).
    function configureInterval(rounds, minutes, seconds) {
        const L = Engine.LIMITS;
        const r = Engine.clampInt(rounds, L.INTERVAL_ROUNDS_MIN, L.INTERVAL_ROUNDS_MAX, 1);
        const m = Engine.clampInt(minutes, L.INTERVAL_MINUTES_MIN, L.INTERVAL_MINUTES_MAX, 0);
        let s = Engine.clampInt(seconds, L.INTERVAL_SECONDS_MIN, L.INTERVAL_SECONDS_MAX, 0);
        if (m === 0 && s === 0) s = 1;
        const changed = r !== root.intervalRounds || m !== root.intervalMinutes || s !== root.intervalSeconds;
        root.intervalRounds = r;
        root.intervalMinutes = m;
        root.intervalSeconds = s;
        if (changed && !root.running && root.mode === root.intervalsMode) root.reset(false);
    }

    function setIntervalRounds(value) {
        root.configureInterval(value, root.intervalMinutes, root.intervalSeconds);
    }

    function setIntervalMinutes(value) {
        root.configureInterval(root.intervalRounds, value, root.intervalSeconds);
    }

    function setIntervalSeconds(value) {
        root.configureInterval(root.intervalRounds, root.intervalMinutes, value);
    }

    // --- Pomodoro ---
    function setPomodoroWorkMinutes(value, notifyHost) {
        const L = Engine.LIMITS;
        root.commit("pomodoroWorkMinutes", Engine.clampInt(value, L.POMODORO_WORK_MIN, L.POMODORO_WORK_MAX, 1),
            "pomodoroWorkMinutes", notifyHost, root.pomodoroMode);
    }

    function setPomodoroShortBreakMinutes(value, notifyHost) {
        const L = Engine.LIMITS;
        root.commit("pomodoroShortBreakMinutes", Engine.clampInt(value, L.POMODORO_SHORT_BREAK_MIN, L.POMODORO_SHORT_BREAK_MAX, 1),
            "pomodoroShortBreakMinutes", notifyHost, root.pomodoroMode);
    }

    function setPomodoroLongBreakMinutes(value, notifyHost) {
        const L = Engine.LIMITS;
        root.commit("pomodoroLongBreakMinutes", Engine.clampInt(value, L.POMODORO_LONG_BREAK_MIN, L.POMODORO_LONG_BREAK_MAX, 1),
            "pomodoroLongBreakMinutes", notifyHost, root.pomodoroMode);
    }

    function setPomodoroCycles(value, notifyHost) {
        const L = Engine.LIMITS;
        root.commit("pomodoroCycles", Engine.clampInt(value, L.POMODORO_CYCLES_MIN, L.POMODORO_CYCLES_MAX, 1),
            "pomodoroCycles", notifyHost, root.pomodoroMode);
    }

    // One-off (non-persisted) Pomodoro configuration, used by IPC.
    function configurePomodoro(workMinutes, shortBreakMinutes, cycles, longBreakMinutes) {
        root.setPomodoroWorkMinutes(workMinutes, false);
        root.setPomodoroShortBreakMinutes(shortBreakMinutes, false);
        root.setPomodoroCycles(cycles, false);
        root.setPomodoroLongBreakMinutes(longBreakMinutes, false);
    }
}
