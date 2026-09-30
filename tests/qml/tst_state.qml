import QtQuick
import QtTest
import Clockwork
import "../../ClockworkEngine.js" as Engine

TestCase {
    name: "ClockworkState"
    readonly property var state: ClockworkState

    SignalSpy {
        id: saveSpy
        target: ClockworkState
        signalName: "settingSaveRequested"
    }

    function init() {
        state.configuredSettings = {};
        state.widgetInstances = [];
        state.selectMode(state.stopwatchMode);
        state.reset();
        saveSpy.clear();
    }

    function cleanup() {
        state.reset();
        state.widgetInstances = [];
    }

    function ipc() {
        for (const child of state.children) {
            if (child.target === "dankClockwork") return child;
        }
        fail("Clockwork IPC handler was not registered");
    }

    function test_stopwatchRestart() {
        const commands = ipc();
        compare(commands.stopwatch(), "CLOCKWORK_STOPWATCH_STARTED");
        state.startedAt -= 5000;
        state.tick();
        verify(state.displayText !== "00:00.00");
        commands.stopwatch();
        compare(state.storedElapsedMs, 0);
        compare(state.displayText, "00:00.00");
        state.startedAt -= 5000;
        state.pause();
        verify(state.storedElapsedMs >= 5000);
        commands.stopwatch();
        compare(state.running, true);
        compare(state.storedElapsedMs, 0);
        compare(state.displayText, "00:00.00");
    }

    function test_alarmDismissal() {
        ipc().alarm("7", "0", "Wake up");
        state.dispatch(Engine.tick(state.getEngineSnapshot(), state.alarmTargetAt));
        compare(state.isAlarmRinging, true);
        ipc().toggle();
        compare(state.isAlarmRinging, false);
        compare(state.running, false);
        compare(state.completed, false);
        compare(state.alarmTargetAt, 0);
    }

    function test_savedDefaults_data() {
        return [{ tag: "running", pause: false }, { tag: "paused", pause: true }];
    }

    function test_savedDefaults(data) {
        state.applyConfiguredSettings({ countdownMinutes: 10 });
        ipc().countdown("10", "0");
        state.startedAt -= 60000;
        state.tick();
        if (data.pause) state.pause();
        const elapsed = state.storedElapsedMs;
        state.applyConfiguredSettings({ countdownMinutes: 2, countdownSeconds: 30 });
        compare(state.countdownMinutes, 10);
        compare(state.running, !data.pause);
        compare(state.storedElapsedMs, elapsed);
        compare(saveSpy.count, 0);
        state.reset();
        compare(state.countdownMinutes, 2);
        compare(state.countdownSeconds, 30);
        compare(state.displayText, "02:30");
    }

    function test_newMonitorHydration() {
        state.applyConfiguredSettings({ countdownMinutes: 5 });
        ipc().countdown("10", "0");
        state.startedAt -= 300000;
        state.applyConfiguredSettings({ countdownMinutes: 5 });
        state.tick();
        compare(state.completed, false);
        compare(state.countdownMinutes, 10);
        verify(state.progress >= 0.5 && state.progress < 0.51);
        compare(saveSpy.count, 0);
    }

    function test_pomodoroWaitingSession() {
        ipc().pomodoro("25", "5", "4", "15");
        state.skipPomodoroPhase();
        state.skipPomodoroPhase();
        compare(state.running, false);
        compare(state.pomodoroCurrentCycle, 2);
        state.applyConfiguredSettings({ pomodoroWorkMinutes: 10, pomodoroCycles: 1 });
        compare(state.pomodoroWorkMinutes, 25);
        compare(state.pomodoroCycles, 4);
        compare(state.pomodoroCurrentCycle, 2);
        compare(state.canSwitchMode, false);
        state.reset();
        compare(state.pomodoroWorkMinutes, 10);
        compare(state.pomodoroCycles, 1);
        compare(state.canSwitchMode, true);
    }

    function test_completedReminderSurvivesSettingsChange() {
        ipc().countdown("0", "1");
        state.startedAt -= 1000;
        state.tick();
        compare(state.completed, true);
        state.applyConfiguredSettings({ countdownMinutes: 2, countdownSeconds: 0 });
        compare(state.completed, true);
        compare(state.displayText, "00:00");
        state.startPause();
        compare(state.running, true);
        compare(state.countdownMinutes, 2);
        compare(state.displayText, "02:00");
    }

    function test_runningPomodoroKeepsAllPhaseDurations() {
        ipc().pomodoro("25", "5", "4", "15");
        state.applyConfiguredSettings({ pomodoroWorkMinutes: 10, pomodoroShortBreakMinutes: 2,
            pomodoroLongBreakMinutes: 8, pomodoroCycles: 1, pomodoroSound: false });
        compare(state.pomodoroWorkMinutes, 25);
        compare(state.pomodoroShortBreakMinutes, 5);
        compare(state.pomodoroLongBreakMinutes, 15);
        compare(state.pomodoroCycles, 4);
        state.skipPomodoroPhase();
        compare(state.displayText, "05:00");
        state.reset();
        compare(state.pomodoroWorkMinutes, 10);
        compare(state.pomodoroShortBreakMinutes, 2);
        compare(state.pomodoroLongBreakMinutes, 8);
        compare(state.pomodoroCycles, 1);
    }

    function test_hostBindingAndHandover() {
        const a = { isFirst: false }, b = { isFirst: false };
        state.registerWidget(a);
        state.registerWidget(b);
        state.registerWidget(a);
        compare(state.widgetInstances.length, 2);
        compare(state.hostWidget, a);
        state.unregisterWidget(a);
        compare(state.hostWidget, b);
        state.unregisterWidget(b);
        compare(state.hostWidget, null);
    }

    function test_zeroAndFalsePreferences() {
        state.applyConfiguredSettings({ countdownMinutes: 0, countdownSeconds: 30,
            countdownFullscreenEnabled: false });
        compare(state.countdownMinutes, 0);
        compare(state.displayText, "00:00.00"); // idle stopwatch is unaffected
        state.selectMode(state.countdownMode);
        compare(state.displayText, "00:30");
        compare(saveSpy.count, 0);
    }
}
