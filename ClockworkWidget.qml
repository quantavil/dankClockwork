import QtQuick
import Quickshell
import qs.Common
import qs.Widgets
import qs.Modules.Plugins
import "." as ClockworkCore

PluginComponent {
    id: root

    // Popout configuration
    popoutWidth: 460
    popoutHeight: 0

    readonly property var timerState: ClockworkCore.ClockworkState

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

    // Alarm pulsing state
    readonly property bool isAlarmRinging: timerState.isAlarmRinging
    readonly property bool isPomodoroBreak: timerState.mode === timerState.pomodoroMode
        && timerState.pomodoroSessionStarted
        && timerState.pomodoroPhaseKind !== "focus"

    // Urgent flashing cue for ringing alarm
    property bool pulseUrgent: false
    Timer {
        id: alarmPulseTimer
        interval: 500
        repeat: true
        running: root.isAlarmRinging
        onTriggered: root.pulseUrgent = !root.pulseUrgent
        onRunningChanged: if (!running) root.pulseUrgent = false
    }

    // Apply plugin settings on startup
    Component.onCompleted: {
        root.applyConfiguredSettings();
    }

    onPluginDataChanged: {
        root.applyConfiguredSettings();
    }

    function applyConfiguredSettings() {
        if (!timerState) return;
        timerState.configurePomodoro(
            root.defaultWorkMinutes,
            root.defaultShortBreakMinutes,
            root.defaultCycles,
            root.defaultLongBreakMinutes,
            root.defaultPomodoroSound,
            "#a6e3a1"
        );
        timerState.setAlarmUses12Hour(root.defaultAlarm12Hour, false);
        timerState.setAlarmSound(root.defaultAlarmSound, false);
        timerState.setCountdownFullscreenEnabled(root.defaultFullscreenBreak, false);
        timerState.setCountdownMessage(root.defaultCountdownMessage, false);
        timerState.setCountdownMinutes(root.defaultCountdownMinutes, false);
    }

    // Host persistence bridge
    function saveSetting(key, value) {
        if (pluginService && pluginId) {
            pluginService.savePluginData(pluginId, key, value);
        }
    }

    function isPopoutOpen(): bool {
        for (let i = 0; i < root.children.length; i++) {
            let ch = root.children[i];
            if (ch && ch.hasOwnProperty("shouldBeVisible")) {
                return ch.shouldBeVisible;
            }
        }
        return false;
    }

    function openPopout() {
        if (!isPopoutOpen()) {
            root.triggerPopout();
        }
    }

    Connections {
        target: root.timerState
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

    readonly property string barDisplayText: {
        if (timerState.mode === timerState.alarmMode && timerState.running)
            return timerState.alarmTimeText;
        if (timerState.barTimeText !== "")
            return timerState.barTimeText;
        return "";
    }

    function getPillColor() {
        if (root.isAlarmRinging) {
            return root.pulseUrgent ? Theme.error : Theme.surfaceText;
        }
        if (root.isPomodoroBreak) {
            return timerState.pomodoroBreakColor;
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
                acceptedButtons: Qt.MiddleButton | Qt.RightButton
                cursorShape: Qt.PointingHandCursor
                onClicked: mouse => {
                    if (mouse.button === Qt.MiddleButton) {
                        root.timerState.startPause();
                    } else if (mouse.button === Qt.RightButton) {
                        if (root.timerState.isAlarmRinging) {
                            root.timerState.reset();
                        } else if (root.timerState.running) {
                            root.timerState.pause();
                        } else {
                            root.timerState.reset();
                        }
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
                    size: Theme.iconSize - 6
                    color: root.getPillColor()
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                StyledText {
                    text: root.barDisplayText
                    font.pixelSize: 10
                    font.weight: root.timerState.running ? Font.Bold : Font.Normal
                    color: root.isAlarmRinging ? Theme.error : (root.timerState.running ? Theme.primary : Theme.surfaceText)
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: root.showBarText && text !== ""
                }
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.MiddleButton | Qt.RightButton
                cursorShape: Qt.PointingHandCursor
                onClicked: mouse => {
                    if (mouse.button === Qt.MiddleButton) {
                        root.timerState.startPause();
                    } else if (mouse.button === Qt.RightButton) {
                        if (root.timerState.isAlarmRinging) {
                            root.timerState.reset();
                        } else if (root.timerState.running) {
                            root.timerState.pause();
                        } else {
                            root.timerState.reset();
                        }
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

    // Fullscreen Countdown Break window instance
    ClockworkFullscreenBreak {
        id: fullscreenBreakWindow
        targetScreen: root.parentScreen || null
        active: root.timerState.countdownFullscreenEnabled
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
