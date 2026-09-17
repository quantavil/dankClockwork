import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Widgets
import "." as ClockworkCore

PanelWindow {
    id: root

    // =========================================================================
    // Properties
    // =========================================================================
    property var targetScreen: null
    property bool active: false
    property string message: (ClockworkCore.ClockworkState.countdownMessage && ClockworkCore.ClockworkState.countdownMessage.trim() !== "")
        ? ClockworkCore.ClockworkState.countdownMessage
        : I18n.trFor("clockwork", "Take a break")

    // =========================================================================
    // Signals
    // =========================================================================
    signal closeRequested()
    signal toggleRequested()
    signal resetRequested()

    // =========================================================================
    // Window Configuration
    // =========================================================================
    screen: targetScreen
    visible: active
    color: "transparent"

    WlrLayershell.namespace: "dms:clockwork-break"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.keyboardFocus: active ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    anchors {
        left: true
        right: true
        top: true
        bottom: true
    }

    onVisibleChanged: {
        if (visible) {
            Qt.callLater(() => {
                keyCatcher.forceActiveFocus();
            });
        }
    }

    // Material 3 translucent background
    Rectangle {
        id: backdrop
        anchors.fill: parent
        color: Theme.withAlpha(Theme.surface, 0.94)

        MouseArea {
            anchors.fill: parent
            onClicked: keyCatcher.forceActiveFocus()
        }
    }

    FocusScope {
        id: keyCatcher
        anchors.fill: parent
        focus: true

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                root.closeRequested();
                event.accepted = true;
            } else if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                root.toggleRequested();
                event.accepted = true;
            } else if (event.key === Qt.Key_R || event.text === "r" || event.text === "R") {
                root.resetRequested();
                event.accepted = true;
            }
        }

        // Top right close button
        DankActionButton {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: Theme.spacingXL
            iconName: "close"
            iconSize: 24
            iconColor: Theme.surfaceText
            tooltipText: I18n.trFor("clockwork", "Close (Esc)")
            onClicked: root.closeRequested()
        }

        // Centered Content
        Column {
            anchors.centerIn: parent
            spacing: Theme.spacingXL
            width: Math.min(parent.width - Theme.spacingXL * 4, 600)

            DankIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                name: "emoji_food_beverage"
                size: 64
                color: Theme.primary
            }

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.message
                font.pixelSize: 28
                font.weight: Font.Bold
                color: Theme.surfaceText
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                width: parent.width
            }

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: ClockworkCore.ClockworkState.displayText
                font.pixelSize: 72
                font.weight: Font.Bold
                color: Theme.primary
                horizontalAlignment: Text.AlignHCenter
            }

            // Progress bar
            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(parent.width, 420)
                height: 6
                visible: ClockworkCore.ClockworkState.progress > 0

                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: Theme.withAlpha(Theme.surfaceVariantText, 0.2)
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: Math.max(height, parent.width * Math.max(0, Math.min(1, ClockworkCore.ClockworkState.progress)))
                    radius: height / 2
                    color: Theme.primary

                    Behavior on width {
                        NumberAnimation {
                            duration: 100
                            easing.type: Easing.OutCubic
                        }
                    }
                }
            }

            // Quick actions
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.spacingM

                DankButton {
                    text: ClockworkCore.ClockworkState.running
                        ? I18n.trFor("clockwork", "Pause")
                        : (ClockworkCore.ClockworkState.completed ? I18n.trFor("clockwork", "Restart") : I18n.trFor("clockwork", "Resume"))
                    iconName: ClockworkCore.ClockworkState.running ? "pause" : "play_arrow"
                    backgroundColor: Theme.primary
                    textColor: Theme.primaryText
                    onClicked: root.toggleRequested()
                }

                DankButton {
                    text: I18n.trFor("clockwork", "Reset")
                    iconName: "restart_alt"
                    backgroundColor: Theme.surfaceContainerHighest
                    textColor: Theme.surfaceText
                    onClicked: root.resetRequested()
                }

                DankButton {
                    text: I18n.trFor("clockwork", "Close")
                    iconName: "close"
                    backgroundColor: Theme.surfaceContainerHighest
                    textColor: Theme.surfaceText
                    onClicked: root.closeRequested()
                }
            }
        }
    }
}
