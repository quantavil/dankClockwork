import QtQuick
import qs.Common
import qs.Widgets

// Shared control for tabs, actions and the fullscreen preference.
StyledRect {
    id: root

    property string text: ""
    property string iconName: ""
    property real iconSize: Theme.iconSizeSmall + Theme.spacingXXS
    property real fontSize: Theme.fontSizeSmall
    property bool bold: false
    property bool filled: false
    property bool tonal: false
    property bool danger: false
    property bool tab: false
    property bool quiet: false

    readonly property bool hovered: mouseArea.containsMouse
    readonly property color contentColor: root.danger ? Theme.error
        : root.tab ? (root.tonal ? Theme.primary : Theme.surfaceVariantText)
        : (root.filled ? Theme.primaryText : Theme.surfaceText)

    signal clicked()

    implicitHeight: Theme.fontSizeMedium + Theme.spacingM * 2
    radius: root.tab ? Theme.cornerRadius / 2 : Theme.cornerRadius
    opacity: root.enabled ? 1.0 : 0.38

    color: {
        if (root.danger) return Theme.withAlpha(Theme.error, 0.14);
        if (root.filled) return root.hovered ? Theme.withAlpha(Theme.primary, 0.88) : Theme.primary;
        if (root.tab) return root.hovered ? Theme.withAlpha(Theme.surfaceText, 0.06) : "transparent";
        if (root.tonal) return Theme.withAlpha(Theme.surfaceText, 0.1);
        if (root.quiet) return root.hovered ? Theme.withAlpha(Theme.surfaceText, 0.06) : "transparent";
        return root.hovered ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh;
    }

    Behavior on color {
        ColorAnimation { duration: 150 }
    }
    Behavior on opacity {
        NumberAnimation { duration: 100 }
    }

    Accessible.role: Accessible.Button
    Accessible.name: root.text
    Accessible.onPressAction: if (root.enabled) root.clicked()
    activeFocusOnTab: true
    Keys.onSpacePressed: root.clicked()
    Keys.onReturnPressed: root.clicked()
    Keys.onEnterPressed: root.clicked()

    border.width: activeFocus ? 1 : 0
    border.color: Theme.surfaceText

    Rectangle {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(horizontalContent.width, parent.width - Theme.spacingM * 2)
        height: Theme.spacingXXS
        radius: height / 2
        visible: root.tab && root.tonal
        color: Theme.primary
    }

    Row {
        id: horizontalContent
        anchors.centerIn: parent
        spacing: Theme.spacingXS

        DankIcon {
            id: icon
            visible: root.iconName !== ""
            name: root.iconName
            size: root.iconSize
            color: root.contentColor
            anchors.verticalCenter: parent.verticalCenter
        }

        StyledText {
            visible: root.text !== ""
            text: root.text
            font.pixelSize: root.fontSize
            font.weight: root.bold ? Font.Bold : Font.Normal
            color: root.contentColor
            elide: Text.ElideRight
            anchors.verticalCenter: parent.verticalCenter
            // Leave room for the icon and side padding so long labels elide instead of overflowing.
            width: Math.min(implicitWidth, Math.max(0, root.width - Theme.spacingS * 2
                - (icon.visible ? icon.width + parent.spacing : 0)))
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        enabled: root.enabled
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.clicked()
    }
}
