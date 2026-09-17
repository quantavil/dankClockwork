import QtQuick
import Quickshell
import qs.Common
import qs.Widgets
import qs.Modules.Plugins
import "." as ClockworkCore

PluginComponent {
    id: root

    // =========================================================================
    // Properties & State
    // =========================================================================
    readonly property ClockworkCore.ClockworkState timerState: ClockworkCore.ClockworkState

    // Settings loaded from DMS PluginService
    property bool showBarText: pluginData.showBarText ?? true
    property int defaultWorkMinutes: pluginData.pomodoroWorkMinutes ? parseInt(pluginData.pomodoroWorkMinutes, 10) : 25
    property int defaultShortBreakMinutes: pluginData.pomodoroShortBreakMinutes ? parseInt(pluginData.pomodoroShortBreakMinutes, 10) : 5
    property int defaultLongBreakMinutes: pluginData.pomodoroLongBreakMinutes ? parseInt(pluginData.pomodoroLongBreakMinutes, 10) : 15
    property int defaultCycles: pluginData.pomodoroCycles ? parseInt(pluginData.pomodoroCycles, 10) : 4
    property bool defaultPomodoroSound: pluginData.pomodoroSound ?? true
    property bool defaultAlarm12Hour: pluginData.alarmUses12Hour ?? false
    property string defaultAlarmSound: pluginData.alarmSound || "alarm-clock-elapsed.oga"
    property bool defaultFullscreenBreak: pluginData.countdownFullscreenEnabled ?? false
    property string defaultCountdownMessage: pluginData.countdownMessage || "Take a break"
    property int defaultCountdownMinutes: pluginData.countdownMinutes ? parseInt(pluginData.countdownMinutes, 10) : 5
    property int defaultCountdownSeconds: pluginData.countdownSeconds ? parseInt(pluginData.countdownSeconds, 10) : 0

    // Alarm pulsing state
    readonly property bool isAlarmRinging: timerState.isAlarmRinging
    readonly property bool isPomodoroBreak: timerState.mode === timerState.pomodoroMode
        && timerState.pomodoroSessionStarted
        && timerState.pomodoroPhaseKind !== "focus"

    // Urgent flashing cue for ringing alarm
    property bool pulseUrgent: false

    readonly property string barDisplayText: {
        if (timerState.mode === timerState.alarmMode && timerState.running)
            return timerState.alarmTimeText;
        if (timerState.barTimeText !== "")
            return timerState.barTimeText;
        return "";
    }

    // =========================================================================
    // Popout Configuration
    // =========================================================================
    popoutWidth: 460
    popoutHeight: 0 // Dynamic height calculated via ClockworkPopout implicitHeight

    // Right-click support adhering to Fitts's Law screen-edge expansion (Trap 12)
    pillRightClickAction: (x, y, width, section, screen) => {
        root.handleRightClick();
    }

    // =========================================================================
    // Timers & Life-Cycle
    // =========================================================================
    Timer {
        id: alarmPulseTimer
        interval: 500
        repeat: true
        running: root.isAlarmRinging
        onTriggered: root.pulseUrgent = !root.pulseUrgent
        onRunningChanged: if (!running) root.pulseUrgent = false
    }

    Component.onCompleted: {
        root.applyConfiguredSettings();
    }

    onPluginDataChanged: {
        root.applyConfiguredSettings();
    }

    // Host persistence & IPC synchronization
    Connections {
        target: root.timerState
        // On multi-monitor setups, gate save delegation to the primary widget instance
        enabled: root.isFirst ?? true

        function onSettingSaveRequested(key, value) {
            root.saveSetting(key, value);
        }
        function onOpenPopoutRequested() {
            root.openPopout();
        }
        function onTogglePopoutRequested() {
            root.triggerPopout();
        }
        function onClosePopoutRequested() {
            root.closePopout();
        }
    }

    // =========================================================================
    // Helper Methods
    // =========================================================================
    function applyConfiguredSettings() {
        if (!timerState) return;
        timerState.configurePomodoro(
            root.defaultWorkMinutes,
            root.defaultShortBreakMinutes,
            root.defaultCycles,
            root.defaultLongBreakMinutes,
            root.defaultPomodoroSound,
            Theme.secondary
        );
        timerState.setAlarmUses12Hour(root.defaultAlarm12Hour, false);
        timerState.setAlarmSound(root.defaultAlarmSound, false);
        timerState.setCountdownFullscreenEnabled(root.defaultFullscreenBreak, false);
        timerState.setCountdownMessage(root.defaultCountdownMessage, false);
        timerState.setCountdownMinutes(root.defaultCountdownMinutes, false);
        timerState.setCountdownSeconds(root.defaultCountdownSeconds, false);
    }

    function saveSetting(key, value) {
        if (pluginService && pluginId) {
            pluginService.savePluginData(pluginId, key, value);
        }
    }

    function isPopoutOpen(): bool {
        return root.timerState.popoutOpen;
    }

    function openPopout() {
        if (!root.isPopoutOpen()) {
            root.triggerPopout();
        }
    }

    function handleMiddleClick() {
        root.timerState.startPause();
    }

    function handleRightClick() {
        if (root.timerState.isAlarmRinging) {
            root.timerState.reset();
        } else if (root.timerState.running) {
            root.timerState.pause();
        } else {
            root.timerState.reset();
        }
    }

    function getModeIcon() {
        if (timerState.mode === timerState.stopwatchMode) return "timer";
        if (timerState.mode === timerState.countdownMode) return "hourglass_bottom";
        if (timerState.mode === timerState.intervalsMode) return "fitness_center";
        if (timerState.mode === timerState.alarmMode) return "alarm";
        if (timerState.mode === timerState.pomodoroMode) {
            return (timerState.pomodoroPhaseKind === "focus") ? "work" : "emoji_food_beverage";
        }
        return "schedule";
    }

    function getPillColor() {
        if (root.isAlarmRinging) {
            return root.pulseUrgent ? Theme.error : Theme.surfaceText;
        }
        if (root.isPomodoroBreak) {
            return Theme.secondary;
        }
        if (timerState.running) {
            return Theme.primary;
        }
        return Theme.surfaceText;
    }

    // =========================================================================
    // Horizontal Bar Pill (for top and bottom DankBar)
    // =========================================================================
    horizontalBarPill: Component {
        Item {
            id: horizontalRoot
            implicitWidth: horizontalRow.implicitWidth
            implicitHeight: horizontalRow.implicitHeight

            Row {
                id: horizontalRow
                anchors.centerIn: parent
                spacing: Theme.spacingS

                DankIcon {
                    name: root.getModeIcon()
                    size: root.iconSize
                    color: root.getPillColor()
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    text: root.barDisplayText
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: root.timerState.running ? Font.Bold : Font.Normal
                    color: root.isAlarmRinging ? Theme.error : (root.timerState.running ? Theme.primary : Theme.surfaceText)
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.showBarText && text !== ""
                }
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.MiddleButton
                cursorShape: Qt.PointingHandCursor
                onClicked: mouse => {
                    if (mouse.button === Qt.MiddleButton) {
                        root.handleMiddleClick();
                    }
                }
            }
        }
    }

    // =========================================================================
    // Vertical Bar Pill (for left and right DankBar)
    // =========================================================================
    verticalBarPill: Component {
        Item {
            id: verticalRoot
            implicitWidth: verticalCol.implicitWidth
            implicitHeight: verticalCol.implicitHeight

            Column {
                id: verticalCol
                anchors.centerIn: parent
                spacing: Theme.spacingXS

                DankIcon {
                    name: root.getModeIcon()
                    size: root.iconSize
                    color: root.getPillColor()
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                StyledText {
                    text: root.barDisplayText
                    font.pixelSize: Math.max(10, Theme.fontSizeSmall - 2)
                    font.weight: root.timerState.running ? Font.Bold : Font.Normal
                    color: root.isAlarmRinging ? Theme.error : (root.timerState.running ? Theme.primary : Theme.surfaceText)
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: root.showBarText && text !== ""
                }
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.MiddleButton
                cursorShape: Qt.PointingHandCursor
                onClicked: mouse => {
                    if (mouse.button === Qt.MiddleButton) {
                        root.handleMiddleClick();
                    }
                }
            }
        }
    }

    // =========================================================================
    // Popout Content Component
    // =========================================================================
    popoutContent: Component {
        ClockworkPopout {
            id: popoutPanel
        }
    }

    // Fullscreen Countdown Break window instance (only active on primary instance to prevent multi-monitor focus fight)
    ClockworkFullscreenBreak {
        id: fullscreenBreakWindow
        targetScreen: root.parentScreen || null
        active: (root.isFirst ?? true)
            && root.timerState.countdownFullscreenEnabled
            && root.timerState.mode === root.timerState.countdownMode
            && root.timerState.completed
            && !root.timerState.breakDismissed
        onCloseRequested: {
            root.timerState.dismissFullscreenBreak();
        }
        onToggleRequested: {
            root.timerState.startPause();
        }
        onResetRequested: {
            root.timerState.reset();
        }
    }
}
