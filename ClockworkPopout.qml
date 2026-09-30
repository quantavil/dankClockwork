import QtQuick
import Quickshell
import qs.Common
import qs.Widgets
import qs.Modules.Plugins
import "." as ClockworkCore

PopoutComponent {
    id: root

    headerText: I18n.trFor("dankClockwork", "DankClockwork")
    detailsText: ""
    showCloseButton: true

    readonly property var timerState: ClockworkCore.ClockworkState
    readonly property bool isRunning: timerState.running
    readonly property bool isCompleted: timerState.completed
    readonly property int currentMode: timerState.mode
    readonly property bool isEditable: !isRunning && timerState.storedElapsedMs === 0 && !isCompleted

    readonly property bool isAlarmMode: currentMode === timerState.alarmMode
    readonly property bool isCountdownMode: currentMode === timerState.countdownMode
    readonly property bool isPomodoroMode: currentMode === timerState.pomodoroMode
    readonly property bool isPomodoroBreak: isPomodoroMode && timerState.pomodoroPhaseKind !== "focus"
    readonly property real timeFontSize: Theme.fontSizeXLarge * 2.1
    readonly property real actionHeight: Theme.fontSizeMedium * 2 + Theme.spacingL
    readonly property real skipWidth: Theme.fontSizeSmall * 5 + Theme.spacingL

    readonly property bool showSkip: isPomodoroMode && timerState.pomodoroSessionStarted && !isCompleted

    // Break phases use the secondary accent so they read differently from focus in light and dark.
    readonly property color accentColor: isPomodoroBreak ? Theme.secondary : Theme.primary

    readonly property var modeTabs: [
        { name: I18n.trFor("dankClockwork", "Stopwatch"), icon: "timer", mode: 0 },
        { name: I18n.trFor("dankClockwork", "Countdown"), icon: "hourglass_bottom", mode: 1 },
        { name: I18n.trFor("dankClockwork", "Intervals"), icon: "fitness_center", mode: 2 },
        { name: I18n.trFor("dankClockwork", "Alarm"), icon: "alarm", mode: 3 },
        { name: I18n.trFor("dankClockwork", "Pomodoro"), icon: "emoji_food_beverage", mode: 4 }
    ]

    // =========================================================================
    // Keyboard routing
    // =========================================================================
    focus: true
    Keys.enabled: true

    // DMS's popout host swallows key events unless the content declares it handles them.
    function attachKeyRouting() {
        if (root.parentPopout) {
            root.parentPopout.contentHandlesKeys = true;
        }
    }

    function focusSelf() {
        Qt.callLater(() => root.forceActiveFocus());
    }

    Component.onCompleted: {
        root.attachKeyRouting();
        root.focusSelf();
    }

    Component.onDestruction: {
        ClockworkCore.ClockworkState.popoutOpen = false;
    }

    onParentPopoutChanged: root.attachKeyRouting()

    // Any field that gives up focus (Enter / Escape / click-away) would otherwise leave the popout
    // with no focused item, silently disabling every keyboard shortcut. Reclaim focus centrally.
    Window.onActiveFocusItemChanged: {
        if (root.visible && !Window.activeFocusItem) {
            root.focusSelf();
        }
    }

    onVisibleChanged: {
        ClockworkCore.ClockworkState.popoutOpen = visible;
        if (visible) {
            root.attachKeyRouting();
            root.focusSelf();
        }
    }

    // True while a text field owns the keyboard, so typing "r" or pressing Space edits text
    // instead of triggering shortcuts. (Enter is propagated by TextInput, hence this check.)
    function isTextEditing() {
        const item = Window.activeFocusItem;
        return item && item !== root && typeof item.cursorPosition === "number";
    }

    function handleKey(event) {
        if (!event || event.accepted || root.isTextEditing()) return;

        // Leave Ctrl/Alt/Meta combos to the compositor and the rest of the shell.
        if (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)) return;

        const key = event.key;
        if (key >= Qt.Key_1 && key <= Qt.Key_5) {
            timerState.requestMode(key - Qt.Key_1);
        } else if (key === Qt.Key_Space || key === Qt.Key_Return || key === Qt.Key_Enter) {
            if (timerState.canStartPause) timerState.startPause();
        } else if (key === Qt.Key_R) {
            timerState.reset();
        } else if (key === Qt.Key_S && root.isPomodoroMode) {
            timerState.skipPomodoroPhase();
        } else if (key === Qt.Key_Escape) {
            if (typeof root.closePopout === "function") {
                root.closePopout();
            } else if (root.parentPopout && typeof root.parentPopout.close === "function") {
                root.parentPopout.close();
            } else {
                return;
            }
        } else {
            return;
        }
        event.accepted = true;
    }

    Keys.onPressed: event => root.handleKey(event)

    headerActions: Component {
        DankActionButton {
            iconName: "settings"
            iconSize: Theme.iconSizeSmall + Theme.spacingXXS
            tooltipText: I18n.trFor("dankClockwork", "Preferences")
            onClicked: {
                if (root.closePopout) root.closePopout();
                Quickshell.execDetached(["dms", "ipc", "call", "settings", "openWith", "plugins"]);
            }
        }
    }

    Column {
        id: mainContent
        objectName: "dankClockworkContent"
        width: parent.width
        topPadding: Theme.spacingS
        bottomPadding: Theme.spacingM
        leftPadding: Theme.spacingXS
        rightPadding: Theme.spacingXS
        spacing: Theme.spacingL

        Row {
            id: tabs
            width: mainContent.width - mainContent.leftPadding - mainContent.rightPadding
            spacing: Theme.spacingXS

            Repeater {
                model: root.modeTabs
                delegate: ClockworkChip {
                    required property var modelData
                    objectName: "dankClockworkTab" + modelData.mode
                    width: (tabs.width - tabs.spacing * (root.modeTabs.length - 1)) / root.modeTabs.length
                    height: Theme.fontSizeSmall + Theme.spacingL + Theme.spacingS
                    tab: true
                    tonal: root.currentMode === modelData.mode
                    text: modelData.name
                    fontSize: Theme.fontSizeSmall
                    bold: tonal
                    enabled: tonal || root.timerState.canSwitchMode
                    onClicked: root.timerState.requestMode(modelData.mode)
                }
            }
        }

        Rectangle {
            id: displayCard
            objectName: "dankClockworkDisplay"
            width: mainContent.width - mainContent.leftPadding - mainContent.rightPadding
            implicitHeight: statusLabel.y + statusLabel.height + Theme.spacingL
            height: implicitHeight
            radius: Theme.cornerRadius
            color: Theme.surfaceContainerHigh

            DankActionButton {
                objectName: "dankClockworkFullscreenToggle"
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: Theme.spacingS
                z: 1
                visible: root.isCountdownMode
                iconName: "fullscreen"
                iconSize: Theme.iconSizeSmall + Theme.spacingXXS
                iconColor: root.timerState.countdownFullscreenEnabled ? Theme.primary : Theme.surfaceVariantText
                backgroundColor: root.timerState.countdownFullscreenEnabled
                    ? Theme.withAlpha(Theme.primary, 0.12) : "transparent"
                tooltipText: root.timerState.countdownFullscreenEnabled
                    ? I18n.trFor("dankClockwork", "Fullscreen reminder enabled")
                    : I18n.trFor("dankClockwork", "Enable fullscreen reminder")
                Accessible.role: Accessible.CheckBox
                Accessible.name: I18n.trFor("dankClockwork", "Fullscreen reminder")
                Accessible.checked: root.timerState.countdownFullscreenEnabled
                onClicked: root.timerState.setCountdownFullscreenEnabled(!root.timerState.countdownFullscreenEnabled)
            }

            Item {
                id: timeArea
                anchors.top: parent.top
                anchors.topMargin: Theme.spacingM
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width - Theme.spacingXL
                height: Math.max(Theme.fontSizeXLarge * 3.6, timeEditor.implicitHeight, timeReadout.implicitHeight)

                Row {
                    id: timeEditor
                    anchors.centerIn: parent
                    spacing: Theme.spacingS
                    visible: (root.isCountdownMode || root.isAlarmMode) && root.isEditable

                    ClockworkTimeField {
                        objectName: "dankClockworkFirstTimeField"
                        fontSize: root.timeFontSize
                        value: root.isAlarmMode
                            ? (root.timerState.alarmUses12Hour ? root.timerState.alarmDisplayHour : root.timerState.alarmHour)
                            : root.timerState.countdownMinutes
                        from: root.isAlarmMode && root.timerState.alarmUses12Hour ? 1 : 0
                        to: root.isAlarmMode ? (root.timerState.alarmUses12Hour ? 12 : 23) : 999
                        onModified: val => {
                            if (root.isCountdownMode) root.timerState.setCountdownMinutes(val);
                            else if (root.timerState.alarmUses12Hour) root.timerState.setAlarmDisplayHour(val);
                            else root.timerState.setAlarmHour(val);
                        }
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: ":"
                        font.pixelSize: root.timeFontSize * 0.9
                        font.family: Theme.fontFamily
                        font.features: ({ "tnum": 1 })
                        font.italic: false
                        color: Theme.surfaceVariantText
                    }

                    ClockworkTimeField {
                        objectName: "dankClockworkSecondTimeField"
                        fontSize: root.timeFontSize
                        value: root.isAlarmMode ? root.timerState.alarmMinute : root.timerState.countdownSeconds
                        to: 59
                        onModified: val => {
                            if (root.isCountdownMode) root.timerState.setCountdownSeconds(val);
                            else root.timerState.setAlarmMinute(val);
                        }
                    }

                    ClockworkChip {
                        visible: root.isAlarmMode && root.timerState.alarmUses12Hour
                        anchors.verticalCenter: parent.verticalCenter
                        width: Theme.fontSizeSmall * 4
                        height: Theme.fontSizeSmall + Theme.spacingM + Theme.spacingS
                        text: root.timerState.alarmMeridiem
                        onClicked: root.timerState.setAlarmMeridiem(root.timerState.alarmMeridiem === "AM" ? "PM" : "AM")
                    }
                }

                StyledText {
                    id: timeReadout
                    anchors.centerIn: parent
                    visible: !((root.isCountdownMode || root.isAlarmMode) && root.isEditable)
                    text: root.timerState.displayText
                    font.pixelSize: Theme.fontSizeXLarge * (root.currentMode === root.timerState.stopwatchMode ? 2.1 : 2.3)
                    font.family: Theme.fontFamily
                    font.features: ({ "tnum": 1 })
                    font.italic: false
                    font.weight: Font.Medium
                    color: root.timerState.isAlarmRinging ? Theme.error : Theme.surfaceText
                }
            }

            StyledText {
                id: statusLabel
                x: Theme.spacingM
                y: timeArea.y + timeArea.height + Theme.spacingS
                width: parent.width - Theme.spacingM * 2
                height: Math.max(implicitHeight, Theme.fontSizeXLarge)
                horizontalAlignment: Text.AlignHCenter
                text: {
                    if (root.isAlarmMode && root.isEditable) return I18n.trFor("dankClockwork", "Next alarm · %1").arg(root.timerState.alarmSoundName);
                    if (root.isCountdownMode && root.isEditable) return root.timerState.countdownMessage;
                    return root.timerState.statusText;
                }
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
                elide: Text.ElideRight
            }

            Rectangle {
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Theme.spacingS
                x: Theme.spacingL
                width: parent.width - Theme.spacingL * 2
                height: Theme.spacingXS * 0.75
                radius: height / 2
                color: Theme.withAlpha(Theme.surfaceText, 0.1)
                visible: root.currentMode !== root.timerState.stopwatchMode
                    && (root.isRunning || root.isCompleted || root.timerState.storedElapsedMs > 0)
                Rectangle {
                    width: parent.width * root.timerState.progress
                    height: parent.height
                    radius: parent.radius
                    color: root.accentColor
                }
            }
        }

        Item {
            id: configuration
            objectName: "dankClockworkConfiguration"
            width: mainContent.width - mainContent.leftPadding - mainContent.rightPadding
            height: root.currentMode === root.timerState.intervalsMode && root.isEditable ? intervalControls.implicitHeight
                : root.isPomodoroMode && !root.timerState.pomodoroSessionStarted ? pomodoroControls.implicitHeight
                : 0
            visible: height > 0

            Row {
                id: intervalControls
                width: parent.width
                spacing: Theme.spacingS
                visible: root.currentMode === root.timerState.intervalsMode && root.isEditable
                ClockworkCompactField {
                    width: (configuration.width - Theme.spacingS * 2) / 3
                    label: I18n.trFor("dankClockwork", "Rounds")
                    value: root.timerState.intervalRounds
                    from: 1
                    to: 99
                    onModified: val => root.timerState.setIntervalRounds(val)
                }
                ClockworkCompactField {
                    width: (configuration.width - Theme.spacingS * 2) / 3
                    label: I18n.trFor("dankClockwork", "Minutes")
                    value: root.timerState.intervalMinutes
                    to: 59
                    onModified: val => root.timerState.setIntervalMinutes(val)
                }
                ClockworkCompactField {
                    width: (configuration.width - Theme.spacingS * 2) / 3
                    label: I18n.trFor("dankClockwork", "Seconds")
                    value: root.timerState.intervalSeconds
                    to: 59
                    onModified: val => root.timerState.setIntervalSeconds(val)
                }
            }

            Grid {
                id: pomodoroControls
                width: parent.width
                columns: 2
                spacing: Theme.spacingS
                visible: root.isPomodoroMode && !root.timerState.pomodoroSessionStarted
                ClockworkCompactField {
                    width: (configuration.width - Theme.spacingS) / 2
                    label: I18n.trFor("dankClockwork", "Focus · min")
                    value: root.timerState.pomodoroWorkMinutes
                    from: 1
                    to: 120
                    onModified: val => root.timerState.setPomodoroWorkMinutes(val)
                }
                ClockworkCompactField {
                    width: (configuration.width - Theme.spacingS) / 2
                    label: I18n.trFor("dankClockwork", "Short break · min")
                    value: root.timerState.pomodoroShortBreakMinutes
                    from: 1
                    to: 60
                    onModified: val => root.timerState.setPomodoroShortBreakMinutes(val)
                }
                ClockworkCompactField {
                    width: (configuration.width - Theme.spacingS) / 2
                    label: I18n.trFor("dankClockwork", "Long break · min")
                    value: root.timerState.pomodoroLongBreakMinutes
                    from: 1
                    to: 60
                    onModified: val => root.timerState.setPomodoroLongBreakMinutes(val)
                }
                ClockworkCompactField {
                    width: (configuration.width - Theme.spacingS) / 2
                    label: I18n.trFor("dankClockwork", "Focus sessions")
                    value: root.timerState.pomodoroCycles
                    from: 1
                    to: 12
                    onModified: val => root.timerState.setPomodoroCycles(val)
                }
            }


        }

        Row {
            id: actions
            objectName: "dankClockworkActions"
            width: mainContent.width - mainContent.leftPadding - mainContent.rightPadding
            height: root.actionHeight
            spacing: Theme.spacingS

            ClockworkChip {
                objectName: "dankClockworkMainAction"
                width: (actions.width - actions.spacing - (root.showSkip ? root.skipWidth + actions.spacing : 0)) / 2
                height: root.actionHeight
                filled: !root.timerState.isAlarmRinging
                danger: root.timerState.isAlarmRinging
                fontSize: Theme.fontSizeMedium
                bold: true
                enabled: root.timerState.isAlarmRinging || root.timerState.canStartPause
                iconName: root.isAlarmMode ? (root.isRunning || root.timerState.isAlarmRinging ? "alarm_off" : "alarm") : (root.isRunning ? "pause" : "play_arrow")
                text: {
                    if (root.timerState.isAlarmRinging) return I18n.trFor("dankClockwork", "Stop alarm");
                    if (root.isAlarmMode && root.isRunning) return I18n.trFor("dankClockwork", "Cancel alarm");
                    if (root.isRunning) return I18n.trFor("dankClockwork", "Pause");
                    if (root.isAlarmMode) return I18n.trFor("dankClockwork", "Set alarm");
                    if (root.isCompleted) return I18n.trFor("dankClockwork", "Restart");
                    if (root.timerState.storedElapsedMs > 0) return I18n.trFor("dankClockwork", "Resume");
                    if (root.isPomodoroMode && root.timerState.pomodoroSessionStarted) return I18n.trFor("dankClockwork", "Start focus");
                    return I18n.trFor("dankClockwork", "Start");
                }
                onClicked: root.timerState.startPause()
            }
            ClockworkChip {
                width: root.skipWidth
                height: root.actionHeight
                visible: root.showSkip
                text: I18n.trFor("dankClockwork", "Skip")
                onClicked: root.timerState.skipPomodoroPhase()
            }
            ClockworkChip {
                width: (actions.width - actions.spacing - (root.showSkip ? root.skipWidth + actions.spacing : 0)) / 2
                height: root.actionHeight
                iconName: "restart_alt"
                enabled: root.isRunning || root.isCompleted || root.timerState.storedElapsedMs > 0 || root.timerState.pomodoroSessionStarted
                text: I18n.trFor("dankClockwork", "Reset")
                onClicked: root.timerState.reset()
            }
        }
    }
}
