pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
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
    // Core Reactive State
    // =========================================================================
    property int mode: stopwatchMode
    property bool running: false
    property bool completed: false
    property double startedAt: 0
    property double storedElapsedMs: 0
    property double nowMs: Date.now()
    property bool popoutOpen: false
    property bool isAlarmRinging: false
    property bool breakDismissed: false

    // Signals for host widget synchronization
    signal settingSaveRequested(string key, var value)
    signal openPopoutRequested()
    signal togglePopoutRequested()
    signal closePopoutRequested()

    // Internal notification and sound tracking
    property int notifiedIntervals: 0
    property int completionBellsRemaining: 0
    property string completionSoundFile: "complete.oga"
    property double alarmRingEndsAt: 0

    // =========================================================================
    // Countdown Mode Properties
    // =========================================================================
    property int countdownMinutes: 5
    property int countdownSeconds: 0
    property bool countdownFullscreenEnabled: false
    property string countdownMessage: "Take a break"

    // =========================================================================
    // Alarm Mode Properties
    // =========================================================================
    property int alarmHour: 7
    property int alarmMinute: 0
    property bool alarmUses12Hour: false
    property string alarmSound: "alarm-clock-elapsed.oga"
    property string alarmMessage: "Alarm"
    property double alarmTargetAt: 0
    property int alarmTargetDurationMs: 0

    readonly property int alarmDisplayHour: alarmUses12Hour
        ? Engine.convert24To12(alarmHour).displayHour
        : alarmHour
    readonly property string alarmMeridiem: Engine.convert24To12(alarmHour).meridiem
    readonly property string alarmSoundName: Engine.getAlarmSoundName(alarmSound)
    readonly property string alarmTimeText: Engine.getAlarmTimeText(root.getEngineSnapshot())

    // =========================================================================
    // Intervals Mode Properties
    // =========================================================================
    property int intervalRounds: 8
    property int intervalMinutes: 0
    property int intervalSeconds: 30

    readonly property string intervalDurationText: Engine.pad2(intervalMinutes) + ":" + Engine.pad2(intervalSeconds)
    readonly property int currentRound: Engine.getCurrentRound(root.getEngineSnapshot(), nowMs)

    // =========================================================================
    // Pomodoro Mode Properties
    // =========================================================================
    property int pomodoroWorkMinutes: 25
    property int pomodoroShortBreakMinutes: 5
    property int pomodoroCycles: 4
    property int pomodoroLongBreakMinutes: 15
    property bool pomodoroSoundEnabled: true
    property color pomodoroBreakColor: Theme.secondary
    property string pomodoroPhaseKind: "focus"
    property int pomodoroCurrentCycle: 1
    property int pomodoroCompletedCycles: 0
    property bool pomodoroSessionStarted: false

    readonly property var pomodoroPhase: Engine.getPomodoroPhase(root.getEngineSnapshot(), nowMs)

    // =========================================================================
    // Computed Properties Delegating to Pure Engine Snapshot (DMS Rule 2)
    // =========================================================================
    readonly property string displayText: Engine.getDisplayText(root.getEngineSnapshot(), nowMs)
    readonly property string barTimeText: Engine.getBarTimeText(root.getEngineSnapshot(), nowMs)
    readonly property string statusText: Engine.getStatusText(root.getEngineSnapshot(), nowMs)
    readonly property real progress: Engine.getProgress(root.getEngineSnapshot(), nowMs)
    readonly property string modeName: Engine.getModeName(root.mode)

    // =========================================================================
    // Timers
    // =========================================================================
    Timer {
        id: tickTimer
        interval: (root.popoutOpen && root.mode === root.stopwatchMode) ? 20 : 250
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
    // =========================================================================
    IpcHandler {
        target: "clockwork"

        function stopwatch(): string {
            root.selectMode(root.stopwatchMode);
            root.startPause();
            return "CLOCKWORK_STOPWATCH_STARTED";
        }

        function countdown(minutes: string, seconds: string): string {
            const m = parseInt(minutes, 10);
            const s = (seconds !== undefined && seconds !== "") ? parseInt(seconds, 10) : 0;
            if (isNaN(m) || isNaN(s) || (m === 0 && s === 0) || m < 0 || s < 0) {
                return "ERROR_INVALID_ARGUMENTS";
            }
            root.selectMode(root.countdownMode);
            root.setCountdownMinutes(m);
            root.setCountdownSeconds(s);
            root.startPause();
            return "CLOCKWORK_COUNTDOWN_STARTED";
        }

        function intervals(rounds: string, minutes: string, seconds: string): string {
            const r = parseInt(rounds, 10);
            const m = (minutes !== undefined && minutes !== "") ? parseInt(minutes, 10) : 0;
            const s = (seconds !== undefined && seconds !== "") ? parseInt(seconds, 10) : 0;
            if (isNaN(r) || isNaN(m) || isNaN(s) || r <= 0 || (m === 0 && s === 0)) {
                return "ERROR_INVALID_ARGUMENTS";
            }
            root.selectMode(root.intervalsMode);
            root.setIntervalRounds(r);
            root.setIntervalMinutes(m);
            root.setIntervalSeconds(s);
            root.startPause();
            return "CLOCKWORK_INTERVALS_STARTED";
        }

        function alarm(hour: string, minute: string, message: string): string {
            const h = parseInt(hour, 10);
            const m = (minute !== undefined && minute !== "") ? parseInt(minute, 10) : 0;
            if (isNaN(h) || isNaN(m) || h < 0 || h > 23 || m < 0 || m > 59) {
                return "ERROR_INVALID_ARGUMENTS";
            }
            root.selectMode(root.alarmMode);
            root.setAlarmHour(h);
            root.setAlarmMinute(m);
            if (typeof message !== "undefined" && message !== "") {
                root.setAlarmMessage(message);
            }
            root.startPause();
            return "CLOCKWORK_ALARM_ARMED";
        }

        function pomodoro(work: string, shortBreak: string, cycles: string, longBreak: string): string {
            const w = (work !== undefined && work !== "") ? parseInt(work, 10) : root.pomodoroWorkMinutes;
            const sb = (shortBreak !== undefined && shortBreak !== "") ? parseInt(shortBreak, 10) : root.pomodoroShortBreakMinutes;
            const c = (cycles !== undefined && cycles !== "") ? parseInt(cycles, 10) : root.pomodoroCycles;
            const lb = (longBreak !== undefined && longBreak !== "") ? parseInt(longBreak, 10) : root.pomodoroLongBreakMinutes;
            if (isNaN(w) || isNaN(sb) || isNaN(c) || isNaN(lb) || w <= 0 || sb <= 0 || c <= 0 || lb <= 0) {
                return "ERROR_INVALID_ARGUMENTS";
            }
            root.selectMode(root.pomodoroMode);
            root.setPomodoroWorkMinutes(w);
            root.setPomodoroShortBreakMinutes(sb);
            root.setPomodoroCycles(c);
            root.setPomodoroLongBreakMinutes(lb);
            root.startPause();
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
    // Internal State Snapshot & Synchronization Helpers
    // =========================================================================
    function getEngineSnapshot() {
        return {
            mode: root.mode,
            running: root.running,
            completed: root.completed,
            startedAt: root.startedAt,
            storedElapsedMs: root.storedElapsedMs,
            nowMs: root.nowMs,

            countdownMinutes: root.countdownMinutes,
            countdownSeconds: root.countdownSeconds,
            countdownMessage: root.countdownMessage,
            countdownFullscreenEnabled: root.countdownFullscreenEnabled,

            intervalRounds: root.intervalRounds,
            intervalMinutes: root.intervalMinutes,
            intervalSeconds: root.intervalSeconds,
            notifiedIntervals: root.notifiedIntervals,

            alarmHour: root.alarmHour,
            alarmMinute: root.alarmMinute,
            alarmUses12Hour: root.alarmUses12Hour,
            alarmSound: root.alarmSound,
            alarmMessage: root.alarmMessage,
            alarmTargetAt: root.alarmTargetAt,
            alarmTargetDurationMs: root.alarmTargetDurationMs,

            pomodoroWorkMinutes: root.pomodoroWorkMinutes,
            pomodoroShortBreakMinutes: root.pomodoroShortBreakMinutes,
            pomodoroCycles: root.pomodoroCycles,
            pomodoroLongBreakMinutes: root.pomodoroLongBreakMinutes,
            pomodoroSoundEnabled: root.pomodoroSoundEnabled,
            pomodoroBreakColor: root.pomodoroBreakColor,
            pomodoroPhaseKind: root.pomodoroPhaseKind,
            pomodoroCurrentCycle: root.pomodoroCurrentCycle,
            pomodoroCompletedCycles: root.pomodoroCompletedCycles,
            pomodoroSessionStarted: root.pomodoroSessionStarted
        };
    }

    function applyEngineState(s) {
        if (!s) return;
        if (root.mode !== s.mode) root.mode = s.mode;
        if (root.running !== s.running) root.running = s.running;
        if (root.completed !== s.completed) root.completed = s.completed;
        if (root.startedAt !== s.startedAt) root.startedAt = s.startedAt;
        if (root.storedElapsedMs !== s.storedElapsedMs) root.storedElapsedMs = s.storedElapsedMs;
        if (root.nowMs !== s.nowMs) root.nowMs = s.nowMs;

        if (root.countdownMinutes !== s.countdownMinutes) root.countdownMinutes = s.countdownMinutes;
        if (root.countdownSeconds !== s.countdownSeconds) root.countdownSeconds = s.countdownSeconds;
        if (root.countdownMessage !== s.countdownMessage) root.countdownMessage = s.countdownMessage;
        if (root.countdownFullscreenEnabled !== s.countdownFullscreenEnabled) root.countdownFullscreenEnabled = s.countdownFullscreenEnabled;

        if (root.intervalRounds !== s.intervalRounds) root.intervalRounds = s.intervalRounds;
        if (root.intervalMinutes !== s.intervalMinutes) root.intervalMinutes = s.intervalMinutes;
        if (root.intervalSeconds !== s.intervalSeconds) root.intervalSeconds = s.intervalSeconds;
        if (root.notifiedIntervals !== s.notifiedIntervals) root.notifiedIntervals = s.notifiedIntervals;

        if (root.alarmHour !== s.alarmHour) root.alarmHour = s.alarmHour;
        if (root.alarmMinute !== s.alarmMinute) root.alarmMinute = s.alarmMinute;
        if (root.alarmUses12Hour !== s.alarmUses12Hour) root.alarmUses12Hour = s.alarmUses12Hour;
        if (root.alarmSound !== s.alarmSound) root.alarmSound = s.alarmSound;
        if (root.alarmMessage !== s.alarmMessage) root.alarmMessage = s.alarmMessage;
        if (root.alarmTargetAt !== s.alarmTargetAt) root.alarmTargetAt = s.alarmTargetAt;
        if (root.alarmTargetDurationMs !== s.alarmTargetDurationMs) root.alarmTargetDurationMs = s.alarmTargetDurationMs;

        if (root.pomodoroWorkMinutes !== s.pomodoroWorkMinutes) root.pomodoroWorkMinutes = s.pomodoroWorkMinutes;
        if (root.pomodoroShortBreakMinutes !== s.pomodoroShortBreakMinutes) root.pomodoroShortBreakMinutes = s.pomodoroShortBreakMinutes;
        if (root.pomodoroCycles !== s.pomodoroCycles) root.pomodoroCycles = s.pomodoroCycles;
        if (root.pomodoroLongBreakMinutes !== s.pomodoroLongBreakMinutes) root.pomodoroLongBreakMinutes = s.pomodoroLongBreakMinutes;
        if (root.pomodoroSoundEnabled !== s.pomodoroSoundEnabled) root.pomodoroSoundEnabled = s.pomodoroSoundEnabled;
        if (root.pomodoroBreakColor !== s.pomodoroBreakColor) root.pomodoroBreakColor = s.pomodoroBreakColor;
        if (root.pomodoroPhaseKind !== s.pomodoroPhaseKind) root.pomodoroPhaseKind = s.pomodoroPhaseKind;
        if (root.pomodoroCurrentCycle !== s.pomodoroCurrentCycle) root.pomodoroCurrentCycle = s.pomodoroCurrentCycle;
        if (root.pomodoroCompletedCycles !== s.pomodoroCompletedCycles) root.pomodoroCompletedCycles = s.pomodoroCompletedCycles;
        if (root.pomodoroSessionStarted !== s.pomodoroSessionStarted) root.pomodoroSessionStarted = s.pomodoroSessionStarted;
    }

    // =========================================================================
    // Sound & Notification Bridges
    // =========================================================================
    function playSound(file) {
        const soundFile = file || "complete.oga";
        const soundPath = soundFile.startsWith("/")
            ? soundFile
            : "/usr/share/sounds/freedesktop/stereo/" + soundFile;
        Quickshell.execDetached([
            "pw-play",
            "--volume", "1.0",
            soundPath
        ]);
    }

    function notify(body, title, isUrgent) {
        const appTitle = title || "Clockwork";
        const message = body !== undefined && body !== null ? String(body) : "";
        const args = ["notify-send", "-a", "Clockwork"];
        if (isUrgent || (root.mode === root.alarmMode && root.completed)) {
            args.push("-u", "critical", "-c", "alarm");
        }
        args.push(appTitle);
        if (message !== "") {
            args.push(message);
        }
        Quickshell.execDetached(args);
    }

    function processEvents(events) {
        if (!events || !events.length) return;
        for (let i = 0; i < events.length; ++i) {
            const ev = events[i];
            if (ev.type === "sound") {
                if (root.completed) {
                    if (root.mode === root.alarmMode) {
                        root.startAlarmRinging();
                    } else {
                        root.playCompletionSequence(ev.file || "complete.oga");
                    }
                } else {
                    root.playSound(ev.file);
                }
            } else if (ev.type === "notify") {
                root.notify(ev.body, ev.title, root.mode === root.alarmMode && root.completed);
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

    function dismissFullscreenBreak() {
        root.breakDismissed = true;
    }

    function playCompletionSequence(soundFile) {
        if (root.mode === root.pomodoroMode && !root.pomodoroSoundEnabled) return;
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
    // Core Action Methods
    // =========================================================================
    function tick() {
        root.nowMs = Date.now();
        if (!root.running || root.mode === root.stopwatchMode) {
            return;
        }
        const res = Engine.tick(root.getEngineSnapshot(), root.nowMs);
        root.applyEngineState(res.state);
        root.processEvents(res.events);
    }

    function startPause() {
        if (root.completed || (root.running && root.mode === root.alarmMode)) {
            root.stopAlarmRinging();
            completionBellTimer.stop();
            root.completionBellsRemaining = 0;
        }
        root.breakDismissed = false;
        const res = Engine.startPause(root.getEngineSnapshot(), Date.now());
        root.applyEngineState(res.state);
        root.processEvents(res.events);
    }

    function pause() {
        const res = Engine.pause(root.getEngineSnapshot(), Date.now());
        root.applyEngineState(res.state);
        root.processEvents(res.events);
    }

    function reset() {
        root.stopAlarmRinging();
        completionBellTimer.stop();
        root.completionBellsRemaining = 0;
        root.breakDismissed = false;
        const res = Engine.reset(root.getEngineSnapshot(), Date.now());
        root.applyEngineState(res.state);
        root.processEvents(res.events);
    }

    function selectMode(nextMode) {
        root.stopAlarmRinging();
        completionBellTimer.stop();
        root.completionBellsRemaining = 0;
        const res = Engine.selectMode(root.getEngineSnapshot(), nextMode, Date.now());
        root.applyEngineState(res.state);
        root.processEvents(res.events);
    }

    function skipPomodoroPhase() {
        const res = Engine.skipPomodoro(root.getEngineSnapshot(), Date.now());
        root.applyEngineState(res.state);
        root.processEvents(res.events);
    }

    function start() {
        if (!root.running) root.startPause();
    }

    // =========================================================================
    // Setters & Mutators
    // =========================================================================
    function setCountdownMinutes(value, notifyHost) {
        const v = Math.max(Engine.LIMITS.COUNTDOWN_MINUTES_MIN, Math.min(Engine.LIMITS.COUNTDOWN_MINUTES_MAX, Number(value) || 0));
        if (root.countdownMinutes === v) return;
        root.countdownMinutes = v;
        if (notifyHost === undefined || notifyHost) root.settingSaveRequested("countdownMinutes", v);
        if (!root.running && root.mode === root.countdownMode) root.reset();
    }

    function setCountdownSeconds(value, notifyHost) {
        const v = Math.max(Engine.LIMITS.COUNTDOWN_SECONDS_MIN, Math.min(Engine.LIMITS.COUNTDOWN_SECONDS_MAX, Number(value) || 0));
        if (root.countdownSeconds === v) return;
        root.countdownSeconds = v;
        if (notifyHost === undefined || notifyHost) root.settingSaveRequested("countdownSeconds", v);
        if (!root.running && root.mode === root.countdownMode) root.reset();
    }

    function setCountdownFullscreenEnabled(enabled, notifyHost) {
        const b = Boolean(enabled);
        if (root.countdownFullscreenEnabled === b) return;
        root.countdownFullscreenEnabled = b;
        if (notifyHost === undefined || notifyHost) root.settingSaveRequested("countdownFullscreenEnabled", b);
    }

    function setCountdownMessage(message, notifyHost) {
        const cleaned = String(message || "").trim();
        const msg = cleaned === "" ? "Take a break" : cleaned;
        if (root.countdownMessage === msg) return;
        root.countdownMessage = msg;
        if (notifyHost === undefined || notifyHost) root.settingSaveRequested("countdownMessage", msg);
    }

    function setAlarmHour(value) {
        const v = Math.max(Engine.LIMITS.ALARM_HOUR_MIN, Math.min(Engine.LIMITS.ALARM_HOUR_MAX, Number(value) || 0));
        if (root.alarmHour === v) return;
        root.alarmHour = v;
        if (!root.running && root.mode === root.alarmMode) root.reset();
    }

    function setAlarmMinute(value) {
        const v = Math.max(Engine.LIMITS.ALARM_MINUTE_MIN, Math.min(Engine.LIMITS.ALARM_MINUTE_MAX, Number(value) || 0));
        if (root.alarmMinute === v) return;
        root.alarmMinute = v;
        if (!root.running && root.mode === root.alarmMode) root.reset();
    }

    function setAlarmDisplayHour(value) {
        const v = Engine.convert12To24(value, root.alarmMeridiem);
        if (root.alarmHour === v) return;
        root.alarmHour = v;
        if (!root.running && root.mode === root.alarmMode) root.reset();
    }

    function setAlarmMeridiem(value) {
        const v = Engine.convert12To24(root.alarmDisplayHour, value);
        if (root.alarmHour === v) return;
        root.alarmHour = v;
        if (!root.running && root.mode === root.alarmMode) root.reset();
    }

    function setAlarmUses12Hour(enabled, notifyHost) {
        const b = Boolean(enabled);
        if (root.alarmUses12Hour === b) return;
        root.alarmUses12Hour = b;
        if (notifyHost === undefined || notifyHost) root.settingSaveRequested("alarmUses12Hour", b);
    }

    function setAlarmSound(value, notifyHost) {
        let next = String(value || "");
        if (Engine.ALARM_SOUNDS.indexOf(next) === -1) {
            next = Engine.ALARM_SOUNDS[0];
        }
        if (root.alarmSound === next) return;
        root.alarmSound = next;
        if (notifyHost === undefined || notifyHost) root.settingSaveRequested("alarmSound", next);
    }

    function cycleAlarmSound(direction, notifyHost) {
        const dir = direction === undefined ? 1 : Number(direction) || 0;
        const next = Engine.cycleAlarmSound(root.alarmSound, dir);
        if (root.alarmSound === next) return;
        root.alarmSound = next;
        if (notifyHost === undefined || notifyHost) root.settingSaveRequested("alarmSound", next);
    }

    function setAlarmMessage(message) {
        const cleaned = String(message || "").trim();
        root.alarmMessage = cleaned === "" ? "Alarm" : cleaned;
    }

    function setIntervalRounds(value) {
        const v = Math.max(Engine.LIMITS.INTERVAL_ROUNDS_MIN, Math.min(Engine.LIMITS.INTERVAL_ROUNDS_MAX, Number(value) || 1));
        if (root.intervalRounds === v) return;
        root.intervalRounds = v;
        if (!root.running && root.mode === root.intervalsMode) root.reset();
    }

    function setIntervalMinutes(value) {
        const v = Math.max(Engine.LIMITS.INTERVAL_MINUTES_MIN, Math.min(Engine.LIMITS.INTERVAL_MINUTES_MAX, Number(value) || 0));
        let s = root.intervalSeconds;
        if (v === 0 && s === 0) s = 1;
        const changed = (root.intervalMinutes !== v || root.intervalSeconds !== s);
        root.intervalMinutes = v;
        root.intervalSeconds = s;
        if (changed && !root.running && root.mode === root.intervalsMode) root.reset();
    }

    function setIntervalSeconds(value) {
        const v = Math.max(Engine.LIMITS.INTERVAL_SECONDS_MIN, Math.min(Engine.LIMITS.INTERVAL_SECONDS_MAX, Number(value) || 0));
        let m = root.intervalMinutes;
        if (m === 0 && v === 0) v = 1;
        const changed = (root.intervalSeconds !== v || root.intervalMinutes !== m);
        root.intervalSeconds = v;
        root.intervalMinutes = m;
        if (changed && !root.running && root.mode === root.intervalsMode) root.reset();
    }

    function setPomodoroWorkMinutes(value, notifyHost) {
        const v = Math.max(Engine.LIMITS.POMODORO_WORK_MIN, Math.min(Engine.LIMITS.POMODORO_WORK_MAX, Number(value) || 1));
        if (root.pomodoroWorkMinutes === v) return;
        root.pomodoroWorkMinutes = v;
        if (notifyHost === undefined || notifyHost) root.settingSaveRequested("pomodoroWorkMinutes", v);
        if (!root.running && root.mode === root.pomodoroMode) root.reset();
    }

    function setPomodoroShortBreakMinutes(value, notifyHost) {
        const v = Math.max(Engine.LIMITS.POMODORO_SHORT_BREAK_MIN, Math.min(Engine.LIMITS.POMODORO_SHORT_BREAK_MAX, Number(value) || 1));
        if (root.pomodoroShortBreakMinutes === v) return;
        root.pomodoroShortBreakMinutes = v;
        if (notifyHost === undefined || notifyHost) root.settingSaveRequested("pomodoroShortBreakMinutes", v);
        if (!root.running && root.mode === root.pomodoroMode) root.reset();
    }

    function setPomodoroCycles(value, notifyHost) {
        const v = Math.max(Engine.LIMITS.POMODORO_CYCLES_MIN, Math.min(Engine.LIMITS.POMODORO_CYCLES_MAX, Number(value) || 1));
        if (root.pomodoroCycles === v) return;
        root.pomodoroCycles = v;
        if (notifyHost === undefined || notifyHost) root.settingSaveRequested("pomodoroCycles", v);
        if (!root.running && root.mode === root.pomodoroMode) root.reset();
    }

    function setPomodoroLongBreakMinutes(value, notifyHost) {
        const v = Math.max(Engine.LIMITS.POMODORO_LONG_BREAK_MIN, Math.min(Engine.LIMITS.POMODORO_LONG_BREAK_MAX, Number(value) || 1));
        if (root.pomodoroLongBreakMinutes === v) return;
        root.pomodoroLongBreakMinutes = v;
        if (notifyHost === undefined || notifyHost) root.settingSaveRequested("pomodoroLongBreakMinutes", v);
        if (!root.running && root.mode === root.pomodoroMode) root.reset();
    }

    function setPomodoroSoundEnabled(enabled, notifyHost) {
        const b = Boolean(enabled);
        if (root.pomodoroSoundEnabled === b) return;
        root.pomodoroSoundEnabled = b;
        if (notifyHost === undefined || notifyHost) root.settingSaveRequested("pomodoroSound", b);
    }

    function configurePomodoro(workMinutes, shortBreakMinutes, cycles, longBreakMinutes, soundEnabled, breakColor) {
        const nextWork = Math.max(Engine.LIMITS.POMODORO_WORK_MIN, Math.min(Engine.LIMITS.POMODORO_WORK_MAX, Number(workMinutes) || 1));
        const nextShort = Math.max(Engine.LIMITS.POMODORO_SHORT_BREAK_MIN, Math.min(Engine.LIMITS.POMODORO_SHORT_BREAK_MAX, Number(shortBreakMinutes) || 1));
        const nextCycles = Math.max(Engine.LIMITS.POMODORO_CYCLES_MIN, Math.min(Engine.LIMITS.POMODORO_CYCLES_MAX, Number(cycles) || 1));
        const nextLong = Math.max(Engine.LIMITS.POMODORO_LONG_BREAK_MIN, Math.min(Engine.LIMITS.POMODORO_LONG_BREAK_MAX, Number(longBreakMinutes) || 1));
        const changed = nextWork !== root.pomodoroWorkMinutes
            || nextShort !== root.pomodoroShortBreakMinutes
            || nextCycles !== root.pomodoroCycles
            || nextLong !== root.pomodoroLongBreakMinutes;

        root.pomodoroWorkMinutes = nextWork;
        root.pomodoroShortBreakMinutes = nextShort;
        root.pomodoroCycles = nextCycles;
        root.pomodoroLongBreakMinutes = nextLong;
        if (soundEnabled !== undefined) root.pomodoroSoundEnabled = Boolean(soundEnabled);
        if (breakColor !== undefined) root.pomodoroBreakColor = breakColor;
        if (changed && !root.running && root.mode === root.pomodoroMode) root.reset();
    }
}
