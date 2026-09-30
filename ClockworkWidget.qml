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
    readonly property var timerState: ClockworkCore.ClockworkState

    property bool showBarText: pluginData.showBarText ?? true

    readonly property bool isAlarmRinging: timerState.isAlarmRinging
    readonly property bool isPomodoroBreak: timerState.mode === timerState.pomodoroMode
        && timerState.pomodoroSessionStarted
        && timerState.pomodoroPhaseKind !== "focus"

    // Alternates while an alarm rings so the pill flashes without relying on sound alone.
    property bool pulseUrgent: false

    readonly property bool isStateHost: timerState.hostWidget === root

    // Both fullscreen-break windows and the pill share one visibility rule.
    readonly property bool breakVisible: root.isStateHost
        && timerState.countdownFullscreenEnabled
        && timerState.mode === timerState.countdownMode
        && timerState.completed
        && !timerState.breakDismissed

    // =========================================================================
    // Popout Configuration
    // =========================================================================
    popoutWidth: Theme.fontSizeSmall * 35 + Theme.spacingXL + Theme.spacingL
    popoutHeight: 0 // Content-sized: ClockworkPopout is a Column and computes its own height.

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
        root.timerState.registerWidget(root);
        root.applyConfiguredSettings();
    }
    Component.onDestruction: root.timerState.unregisterWidget(root)
    onPluginDataChanged: root.applyConfiguredSettings()

    // Host persistence & IPC synchronization
    Connections {
        target: root.timerState
        // On multi-monitor setups, gate save delegation to the primary widget instance
        enabled: root.isStateHost

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
    // Settings <-> State
    // =========================================================================

    // Cache and session protection belong to the singleton, including during monitor hotplug.
    function applyConfiguredSettings() {
        if (!root.pluginService || !root.pluginId) return;
        root.timerState.applyConfiguredSettings(root.pluginData);
    }

    function saveSetting(key, value) {
        if (pluginService && pluginId) {
            pluginService.savePluginData(pluginId, key, value);
        }
    }

    // =========================================================================
    // Actions
    // =========================================================================
    function openPopout() {
        if (!root.timerState.popoutOpen) {
            root.triggerPopout();
        }
    }

    function handleMiddleClick() {
        root.timerState.startPause();
    }

    // Right-click: silence a ringing alarm, else pause a running timer, else reset.
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
        const s = root.timerState;
        switch (s.mode) {
        case s.stopwatchMode: return "timer";
        case s.countdownMode: return "hourglass_bottom";
        case s.intervalsMode: return "fitness_center";
        case s.alarmMode: return "alarm";
        case s.pomodoroMode: return s.pomodoroPhaseKind === "focus" ? "work" : "emoji_food_beverage";
        default: return "schedule";
        }
    }

    // One colour for icon and text so they never disagree (e.g. break phases, alarm pulse).
    function getPillColor() {
        if (root.isAlarmRinging) return root.pulseUrgent ? Theme.error : Theme.surfaceText;
        if (root.isPomodoroBreak) return Theme.secondary;
        if (root.timerState.running) return Theme.primary;
        return Theme.surfaceText;
    }

    // =========================================================================
    // Horizontal Bar Pill (top and bottom DankBar)
    // =========================================================================
    horizontalBarPill: Component {
        Item {
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
                    text: root.timerState.barTimeText
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: root.timerState.running ? Font.Bold : Font.Normal
                    // Fixed-width digits keep the pill from resizing (and shoving neighbours) every second.
                    font.family: Theme.monoFontFamily
                    color: root.getPillColor()
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.showBarText && text !== ""
                }
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.MiddleButton
                cursorShape: Qt.PointingHandCursor
                onClicked: root.handleMiddleClick()
            }
        }
    }

    // =========================================================================
    // Vertical Bar Pill (left and right DankBar)
    // =========================================================================
    verticalBarPill: Component {
        Item {
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
                    text: root.timerState.barTimeText
                    font.pixelSize: Math.max(10, Theme.fontSizeSmall - 2)
                    font.weight: root.timerState.running ? Font.Bold : Font.Normal
                    font.family: Theme.monoFontFamily
                    color: root.getPillColor()
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: root.showBarText && text !== ""
                }
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.MiddleButton
                cursorShape: Qt.PointingHandCursor
                onClicked: root.handleMiddleClick()
            }
        }
    }

    // =========================================================================
    // Popout Content Component
    // =========================================================================
    popoutContent: Component {
        ClockworkPopout {}
    }

    // Fullscreen countdown break: one overlay per screen so a break is visible on every monitor.
    // Only the primary widget instance creates them, so instances never fight over focus.
    Variants {
        model: root.isStateHost ? Quickshell.screens : []

        ClockworkFullscreenBreak {
            required property var modelData
            targetScreen: modelData
            active: root.breakVisible
            onCloseRequested: root.timerState.dismissFullscreenBreak()
            onToggleRequested: root.timerState.startPause()
            onResetRequested: root.timerState.reset()
        }
    }
}
