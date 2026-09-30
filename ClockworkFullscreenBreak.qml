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
    // The state singleton already trims the message and substitutes the default when it is empty.
    readonly property string message: ClockworkCore.ClockworkState.countdownMessage

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

    WlrLayershell.namespace: "dms:dankClockwork-break"
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
            if (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)) return;
            if (event.key === Qt.Key_Escape) {
                root.closeRequested();
            } else if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                root.toggleRequested();
            } else if (event.key === Qt.Key_R) {
                root.resetRequested();
            } else {
                return;
            }
            event.accepted = true;
        }

        // Top right close button
        DankActionButton {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: Theme.spacingXL
            iconName: "close"
            iconSize: Theme.iconSize
            iconColor: Theme.surfaceText
            tooltipText: I18n.trFor("dankClockwork", "Close (Esc)")
            onClicked: root.closeRequested()
        }

        // Centered Content
        Column {
            anchors.centerIn: parent
            spacing: Theme.spacingXL
            width: Math.min(parent.width - Theme.spacingXL * 4, Theme.fontSizeXLarge * 30)

            DankIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                name: "emoji_food_beverage"
                size: Theme.iconSizeLarge * 2
                color: Theme.primary
            }

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.message
                font.pixelSize: Theme.fontSizeMedium * 2
                font.weight: Font.Bold
                color: Theme.surfaceText
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                width: parent.width
            }

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: ClockworkCore.ClockworkState.displayText
                font.pixelSize: Theme.fontSizeXLarge * 3.6
                font.weight: Font.Bold
                font.family: Theme.monoFontFamily
                color: Theme.primary
                horizontalAlignment: Text.AlignHCenter
            }

            // Progress bar
            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(parent.width, Theme.fontSizeMedium * 30)
                height: Theme.spacingXS * 1.5
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
                        ? I18n.trFor("dankClockwork", "Pause")
                        : (ClockworkCore.ClockworkState.completed ? I18n.trFor("dankClockwork", "Restart") : I18n.trFor("dankClockwork", "Resume"))
                    iconName: ClockworkCore.ClockworkState.running ? "pause" : "play_arrow"
                    backgroundColor: Theme.primary
                    textColor: Theme.primaryText
                    onClicked: root.toggleRequested()
                }

                DankButton {
                    text: I18n.trFor("dankClockwork", "Reset")
                    iconName: "restart_alt"
                    backgroundColor: Theme.surfaceContainerHighest
                    textColor: Theme.surfaceText
                    onClicked: root.resetRequested()
                }

                DankButton {
                    text: I18n.trFor("dankClockwork", "Close")
                    iconName: "close"
                    backgroundColor: Theme.surfaceContainerHighest
                    textColor: Theme.surfaceText
                    onClicked: root.closeRequested()
                }
            }
        }
    }
}
