import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins
import "." as ClockworkCore
import "ClockworkEngine.js" as Engine

PopoutComponent {
    id: root

    headerText: "Clockwork"
    detailsText: ClockworkCore.ClockworkState.statusText
    showCloseButton: true

    readonly property var timerState: ClockworkCore.ClockworkState
    readonly property bool isRunning: timerState.running
    readonly property bool isCompleted: timerState.completed
    readonly property int currentMode: timerState.mode
    readonly property bool isEditable: !isRunning && timerState.storedElapsedMs === 0 && !isCompleted

    // Key handling on the root popout
    focus: true
    Keys.enabled: true

    function hookParentKeys() {
        if (root.parentPopout) {
            root.parentPopout.contentHandlesKeys = true;
        }
        var p = root.parent;
        while (p) {
            if (p.Keys) {
                var fw = p.Keys.forwardTo || [];
                var contains = false;
                for (var i = 0; i < fw.length; i++) {
                    if (fw[i] === root) {
                        contains = true;
                        break;
                    }
                }
                if (!contains) {
                    p.Keys.forwardTo = [root].concat(fw);
                }
            }
            p = p.parent;
        }
    }

    Component.onCompleted: {
        hookParentKeys();
        Qt.callLater(() => {
            hookParentKeys();
            root.forceActiveFocus();
        });
    }

    Component.onDestruction: {
        ClockworkCore.ClockworkState.popoutOpen = false;
        var p = root.parent;
        while (p) {
            if (p.Keys && p.Keys.forwardTo) {
                var fw = p.Keys.forwardTo;
                p.Keys.forwardTo = fw.filter(item => item !== root);
            }
            p = p.parent;
        }
    }

    onParentChanged: {
        hookParentKeys();
    }

    onParentPopoutChanged: {
        hookParentKeys();
    }

    onVisibleChanged: {
        ClockworkCore.ClockworkState.popoutOpen = visible;
        if (visible) {
            hookParentKeys();
            Qt.callLater(() => {
                hookParentKeys();
                root.forceActiveFocus();
            });
        }
    }

    function handleKey(event) {
        if (!event) return;

        // Do not intercept standard typing if a text input currently has active focus
        var focusedItem = Window.activeFocusItem;
        if (focusedItem && focusedItem !== root &&
            (focusedItem.hasOwnProperty("inputMethodHints") || focusedItem.hasOwnProperty("cursorPosition"))) {
            return;
        }

        // Mode switching via numbers 1-5 (top row, keypad, or character)
        if (event.key >= Qt.Key_1 && event.key <= Qt.Key_5) {
            timerState.selectMode(event.key - Qt.Key_1);
            event.accepted = true;
            return;
        }
        if (event.text >= "1" && event.text <= "5") {
            var modeIndex = parseInt(event.text, 10) - 1;
            if (modeIndex >= 0 && modeIndex <= 4) {
                timerState.selectMode(modeIndex);
                event.accepted = true;
                return;
            }
        }

        // Space or Return/Enter toggles start/pause
        if (event.key === Qt.Key_Space || event.text === " " || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            timerState.startPause();
            event.accepted = true;
            return;
        }

        // 'R' / 'r' resets
        if (event.key === Qt.Key_R || event.text === "r" || event.text === "R") {
            timerState.reset();
            event.accepted = true;
            return;
        }

        // 'S' / 's' skips pomodoro phase
        if (event.key === Qt.Key_S || event.text === "s" || event.text === "S") {
            if (timerState.mode === timerState.pomodoroMode) {
                timerState.skipPomodoroPhase();
                event.accepted = true;
                return;
            }
        }

        // Escape closes popout
        if (event.key === Qt.Key_Escape) {
            if (typeof root.closePopout === "function") {
                root.closePopout();
                event.accepted = true;
                return;
            } else if (root.parentPopout && typeof root.parentPopout.close === "function") {
                root.parentPopout.close();
                event.accepted = true;
                return;
            }
        }
    }

    Keys.onPressed: event => {
        root.handleKey(event);
    }

    Column {
        id: mainColumn
        width: parent.width
        spacing: Theme.spacingM

        // =====================================================================
        // 1. Mode Selector Tabs (Material 3 Filter Chips)
        // =====================================================================
        Row {
            id: modeTabsRow
            width: parent.width
            spacing: Theme.spacingXS

            Repeater {
                model: [
                    { name: "Stopwatch", icon: "timer", mode: 0 },
                    { name: "Countdown", icon: "hourglass_bottom", mode: 1 },
                    { name: "Intervals", icon: "fitness_center", mode: 2 },
                    { name: "Alarm", icon: "alarm", mode: 3 },
                    { name: "Pomodoro", icon: "emoji_food_beverage", mode: 4 }
                ]

                delegate: StyledRect {
                    id: tabChip
                    readonly property bool isSelected: root.currentMode === modelData.mode
                    readonly property bool isHovered: tabMouseArea.containsMouse

                    width: (modeTabsRow.width - (Theme.spacingXS * 4)) / 5
                    height: 36
                    radius: Theme.cornerRadiusSmall
                    color: isSelected ? Theme.primary : (isHovered ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh)

                    Behavior on color {
                        ColorAnimation { duration: 150 }
                    }

                    Row {
                        anchors.centerIn: parent
                        spacing: 4

                        DankIcon {
                            name: modelData.icon
                            size: 16
                            color: tabChip.isSelected ? Theme.primaryText : Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: modelData.name
                            font.pixelSize: 11
                            font.weight: tabChip.isSelected ? Font.Bold : Font.Normal
                            color: tabChip.isSelected ? Theme.primaryText : Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                            elide: Text.ElideRight
                        }
                    }

                    MouseArea {
                        id: tabMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.timerState.selectMode(modelData.mode);
                        }
                    }
                }
            }
        }

        // =====================================================================
        // 2. Large Time Display & Interactive Input Card
        // =====================================================================
        StyledRect {
            id: displayCard
            width: parent.width
            height: 140
            radius: Theme.cornerRadius
            color: Theme.surfaceContainerHigh

            border.color: (root.currentMode === root.timerState.alarmMode && root.timerState.isAlarmRinging) ? Theme.error : "transparent"
            border.width: (root.currentMode === root.timerState.alarmMode && root.timerState.isAlarmRinging) ? 2 : 0

            Column {
                anchors.centerIn: parent
                spacing: Theme.spacingXS

                // Live Active Timer Display
                Item {
                    id: timerContainer
                    width: displayCard.width - 32
                    height: 64

                    // CASE A: Large editable fields for IDLE Countdown
                    Row {
                        anchors.centerIn: parent
                        spacing: 8
                        visible: root.currentMode === root.timerState.countdownMode && root.isEditable

                        ClockworkTimeField {
                            value: root.timerState.countdownMinutes
                            from: 0
                            to: 999
                            onModified: val => root.timerState.setCountdownMinutes(val)
                        }

                        StyledText {
                            text: ":"
                            font.pixelSize: 36
                            font.weight: Font.Bold
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        ClockworkTimeField {
                            value: root.timerState.countdownSeconds
                            from: 0
                            to: 59
                            onModified: val => root.timerState.setCountdownSeconds(val)
                        }
                    }

                    // CASE B: Large editable fields for IDLE Alarm
                    Row {
                        anchors.centerIn: parent
                        spacing: 8
                        visible: root.currentMode === root.timerState.alarmMode && root.isEditable

                        ClockworkTimeField {
                            value: root.timerState.alarmUses12Hour ? root.timerState.alarmDisplayHour : root.timerState.alarmHour
                            from: root.timerState.alarmUses12Hour ? 1 : 0
                            to: root.timerState.alarmUses12Hour ? 12 : 23
                            onModified: val => {
                                if (root.timerState.alarmUses12Hour) {
                                    root.timerState.setAlarmDisplayHour(val);
                                } else {
                                    root.timerState.setAlarmHour(val);
                                }
                            }
                        }

                        StyledText {
                            text: ":"
                            font.pixelSize: 36
                            font.weight: Font.Bold
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        ClockworkTimeField {
                            value: root.timerState.alarmMinute
                            from: 0
                            to: 59
                            onModified: val => root.timerState.setAlarmMinute(val)
                        }

                        // AM/PM Toggle Chip (for 12-hour mode)
                        StyledRect {
                            visible: root.timerState.alarmUses12Hour
                            width: 44
                            height: 38
                            radius: Theme.cornerRadiusSmall
                            color: amPmArea.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerLow
                            anchors.verticalCenter: parent.verticalCenter

                            StyledText {
                                anchors.centerIn: parent
                                text: root.timerState.alarmMeridiem
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Font.Bold
                                color: Theme.primary
                            }

                            MouseArea {
                                id: amPmArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.timerState.setAlarmMeridiem(root.timerState.alarmMeridiem === "AM" ? "PM" : "AM");
                                }
                            }
                        }
                    }

                    // CASE C: Active / Running / Stopwatch / Intervals / Pomodoro Display
                    StyledText {
                        anchors.centerIn: parent
                        visible: !( (root.currentMode === root.timerState.countdownMode || root.currentMode === root.timerState.alarmMode) && root.isEditable )
                        text: root.timerState.displayText
                        font.pixelSize: 44
                        font.weight: Font.Bold
                        color: {
                            if (root.currentMode === root.timerState.pomodoroMode && root.timerState.pomodoroPhaseKind !== "focus")
                                return root.timerState.pomodoroBreakColor;
                            if (root.currentMode === root.timerState.alarmMode && root.isCompleted)
                                return Theme.error;
                            if (root.isRunning)
                                return Theme.primary;
                            return Theme.surfaceText;
                        }
                    }
                }

                // Subtitle / Cycle status below timer
                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: {
                        if (root.currentMode === root.timerState.intervalsMode) {
                            return "Round " + root.timerState.currentRound + " of " + root.timerState.intervalRounds + " • " + root.timerState.intervalDurationText;
                        }
                        if (root.currentMode === root.timerState.pomodoroMode) {
                            return root.timerState.pomodoroPhase.label;
                        }
                        if (root.currentMode === root.timerState.alarmMode) {
                            return root.isRunning ? ("Armed for " + root.timerState.alarmTimeText) : "One-shot Alarm";
                        }
                        if (root.currentMode === root.timerState.countdownMode) {
                            return root.timerState.countdownMessage;
                        }
                        return "Count-up timer";
                    }
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                }

                // Mini horizontal progress line
                Item {
                    width: displayCard.width - 48
                    height: 4
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: root.currentMode !== root.timerState.stopwatchMode

                    Rectangle {
                        anchors.fill: parent
                        radius: 2
                        color: Theme.surfaceContainerHighest
                    }

                    Rectangle {
                        height: parent.height
                        width: parent.width * Math.max(0, Math.min(1, root.timerState.progress))
                        radius: 2
                        color: {
                            if (root.currentMode === root.timerState.pomodoroMode && root.timerState.pomodoroPhaseKind !== "focus")
                                return root.timerState.pomodoroBreakColor;
                            return Theme.primary;
                        }
                    }
                }
            }
        }

        // =====================================================================
        // 3. Mode-Specific Controls & Sub-Settings
        // =====================================================================

        // --- INTERVALS CONTROLS ---
        Row {
            width: parent.width
            spacing: Theme.spacingS
            visible: root.currentMode === root.timerState.intervalsMode && !root.timerState.running && !root.timerState.completed

            ClockworkCompactField {
                width: (parent.width - (Theme.spacingS * 2)) / 3
                label: "Rounds"
                value: root.timerState.intervalRounds
                from: Engine.LIMITS.INTERVAL_ROUNDS_MIN
                to: Engine.LIMITS.INTERVAL_ROUNDS_MAX
                onModified: val => root.timerState.setIntervalRounds(val)
            }

            ClockworkCompactField {
                width: (parent.width - (Theme.spacingS * 2)) / 3
                label: "Minutes"
                value: root.timerState.intervalMinutes
                from: Engine.LIMITS.INTERVAL_MINUTES_MIN
                to: Engine.LIMITS.INTERVAL_MINUTES_MAX
                onModified: val => root.timerState.setIntervalMinutes(val)
            }

            ClockworkCompactField {
                width: (parent.width - (Theme.spacingS * 2)) / 3
                label: "Seconds"
                value: root.timerState.intervalSeconds
                from: Engine.LIMITS.INTERVAL_SECONDS_MIN
                to: Engine.LIMITS.INTERVAL_SECONDS_MAX
                onModified: val => root.timerState.setIntervalSeconds(val)
            }
        }

        // --- POMODORO CONTROLS ---
        Grid {
            width: parent.width
            columns: 2
            spacing: Theme.spacingS
            visible: root.currentMode === root.timerState.pomodoroMode && !root.timerState.pomodoroSessionStarted

            ClockworkCompactField {
                width: (parent.width - Theme.spacingS) / 2
                label: "Work Duration (min)"
                value: root.timerState.pomodoroWorkMinutes
                from: Engine.LIMITS.POMODORO_WORK_MIN
                to: Engine.LIMITS.POMODORO_WORK_MAX
                onModified: val => root.timerState.setPomodoroWorkMinutes(val)
            }

            ClockworkCompactField {
                width: (parent.width - Theme.spacingS) / 2
                label: "Short Break (min)"
                value: root.timerState.pomodoroShortBreakMinutes
                from: Engine.LIMITS.POMODORO_SHORT_BREAK_MIN
                to: Engine.LIMITS.POMODORO_SHORT_BREAK_MAX
                onModified: val => root.timerState.setPomodoroShortBreakMinutes(val)
            }

            ClockworkCompactField {
                width: (parent.width - Theme.spacingS) / 2
                label: "Long Break (min)"
                value: root.timerState.pomodoroLongBreakMinutes
                from: Engine.LIMITS.POMODORO_LONG_BREAK_MIN
                to: Engine.LIMITS.POMODORO_LONG_BREAK_MAX
                onModified: val => root.timerState.setPomodoroLongBreakMinutes(val)
            }

            ClockworkCompactField {
                width: (parent.width - Theme.spacingS) / 2
                label: "Cycles per Round"
                value: root.timerState.pomodoroCycles
                from: Engine.LIMITS.POMODORO_CYCLES_MIN
                to: Engine.LIMITS.POMODORO_CYCLES_MAX
                onModified: val => root.timerState.setPomodoroCycles(val)
            }
        }

        // --- COUNTDOWN OPTIONS ---
        Row {
            width: parent.width
            spacing: Theme.spacingM
            visible: root.currentMode === root.timerState.countdownMode

            // Fullscreen Break Toggle Chip
            StyledRect {
                width: (parent.width - Theme.spacingM) * 0.45
                height: 38
                radius: Theme.cornerRadiusSmall
                color: root.timerState.countdownFullscreenEnabled ? Theme.primaryContainer : Theme.surfaceContainerHigh

                Row {
                    anchors.centerIn: parent
                    spacing: 6

                    DankIcon {
                        name: "fullscreen"
                        size: 18
                        color: root.timerState.countdownFullscreenEnabled ? Theme.primary : Theme.surfaceText
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    StyledText {
                        text: "Fullscreen Break"
                        font.pixelSize: Theme.fontSizeSmall
                        color: root.timerState.countdownFullscreenEnabled ? Theme.primary : Theme.surfaceText
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.timerState.setCountdownFullscreenEnabled(!root.timerState.countdownFullscreenEnabled)
                }
            }

            // Message Editor
            StyledRect {
                width: (parent.width - Theme.spacingM) * 0.55
                height: 38
                radius: Theme.cornerRadiusSmall
                color: Theme.surfaceContainerHigh

                TextInput {
                    id: countdownMessageInput
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    verticalAlignment: Text.AlignVCenter
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceText
                    text: root.timerState.countdownMessage
                    maximumLength: 60
                    selectByMouse: true
                    onEditingFinished: root.timerState.setCountdownMessage(text)
                }
            }
        }

        // --- ALARM OPTIONS ---
        Row {
            width: parent.width
            spacing: Theme.spacingM
            visible: root.currentMode === root.timerState.alarmMode

            // 12-Hour Mode Toggle
            StyledRect {
                width: (parent.width - Theme.spacingM) * 0.4
                height: 38
                radius: Theme.cornerRadiusSmall
                color: root.timerState.alarmUses12Hour ? Theme.primaryContainer : Theme.surfaceContainerHigh

                Row {
                    anchors.centerIn: parent
                    spacing: 6

                    DankIcon {
                        name: "schedule"
                        size: 18
                        color: root.timerState.alarmUses12Hour ? Theme.primary : Theme.surfaceText
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    StyledText {
                        text: "12-Hour Format"
                        font.pixelSize: Theme.fontSizeSmall
                        color: root.timerState.alarmUses12Hour ? Theme.primary : Theme.surfaceText
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.timerState.setAlarmUses12Hour(!root.timerState.alarmUses12Hour)
                }
            }

            // Sound Cycler Button
            StyledRect {
                width: (parent.width - Theme.spacingM) * 0.6
                height: 38
                radius: Theme.cornerRadiusSmall
                color: soundArea.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh

                Row {
                    anchors.centerIn: parent
                    spacing: 6

                    DankIcon {
                        name: "volume_up"
                        size: 18
                        color: Theme.primary
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    StyledText {
                        text: "Sound: " + root.timerState.alarmSoundName
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceText
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: soundArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.timerState.cycleAlarmSound(1)
                }
            }
        }

        // =====================================================================
        // 4. Quick Action Buttons (Start, Pause, Reset, Skip)
        // =====================================================================
        Row {
            width: parent.width
            spacing: Theme.spacingM

            // Main Primary Action: Start / Pause / Set Alarm
            StyledRect {
                id: mainActionButton
                width: (root.currentMode === root.timerState.pomodoroMode && root.timerState.pomodoroSessionStarted)
                    ? (parent.width - (Theme.spacingM * 2)) / 3
                    : (parent.width - Theme.spacingM) / 2
                height: 42
                radius: Theme.cornerRadius
                color: playMouseArea.containsMouse ? Qt.darker(Theme.primary, 1.1) : Theme.primary

                Row {
                    anchors.centerIn: parent
                    spacing: 8

                    DankIcon {
                        name: root.isRunning ? "pause" : "play_arrow"
                        size: 20
                        color: Theme.primaryText
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    StyledText {
                        text: {
                            if (root.isRunning) return "Pause";
                            if (root.currentMode === root.timerState.alarmMode) return "Set Alarm";
                            return "Start";
                        }
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Font.Bold
                        color: Theme.primaryText
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: playMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.timerState.startPause()
                }
            }

            // Skip Button (Pomodoro only)
            StyledRect {
                visible: root.currentMode === root.timerState.pomodoroMode && root.timerState.pomodoroSessionStarted
                width: (parent.width - (Theme.spacingM * 2)) / 3
                height: 42
                radius: Theme.cornerRadius
                color: skipMouseArea.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh

                Row {
                    anchors.centerIn: parent
                    spacing: 6

                    DankIcon {
                        name: "skip_next"
                        size: 20
                        color: Theme.surfaceText
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    StyledText {
                        text: "Skip"
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.surfaceText
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: skipMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.timerState.skipPomodoroPhase()
                }
            }

            // Reset Action
            StyledRect {
                id: resetActionButton
                width: (root.currentMode === root.timerState.pomodoroMode && root.timerState.pomodoroSessionStarted)
                    ? (parent.width - (Theme.spacingM * 2)) / 3
                    : (parent.width - Theme.spacingM) / 2
                height: 42
                radius: Theme.cornerRadius
                color: resetMouseArea.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh

                Row {
                    anchors.centerIn: parent
                    spacing: 8

                    DankIcon {
                        name: "restart_alt"
                        size: 20
                        color: Theme.surfaceText
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    StyledText {
                        text: "Reset"
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.surfaceText
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: resetMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.timerState.reset()
                }
            }
        }
    }
}
