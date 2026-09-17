import QtQuick
import qs.Common
import qs.Widgets

Column {
    id: root

    // =========================================================================
    // Component Properties
    // =========================================================================
    property string label: ""
    property int value: 0
    property int from: 0
    property int to: 999

    // =========================================================================
    // Signals
    // =========================================================================
    signal modified(int newValue)
    signal editingFinished()

    // =========================================================================
    // Layout Settings
    // =========================================================================
    spacing: Theme.spacingXS

    readonly property bool isVisualActive: editor.activeFocus

    // =========================================================================
    // Label
    // =========================================================================
    StyledText {
        id: labelDisplay
        width: root.width > 0 ? root.width : stepperBox.implicitWidth
        visible: root.label !== ""
        text: root.label
        font.pixelSize: Theme.fontSizeSmall
        color: root.isVisualActive ? Theme.primary : Theme.surfaceVariantText
        elide: Text.ElideRight
    }

    // =========================================================================
    // Stepper Box
    // =========================================================================
    StyledRect {
        id: stepperBox
        width: root.width > 0 ? root.width : stepperBox.implicitWidth
        implicitWidth: 120
        implicitHeight: Math.max(34, Math.round(Theme.fontSizeMedium * 2.3))
        height: stepperBox.implicitHeight
        radius: Theme.cornerRadiusSmall
        color: Theme.surfaceContainerHigh
        border.color: root.isVisualActive ? Theme.primary : "transparent"
        border.width: root.isVisualActive ? 1.5 : 0

        Behavior on border.color {
            ColorAnimation { duration: 150 }
        }

        // Mouse scroll adjustment
        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            enabled: root.enabled
            onWheel: event => {
                if (event.angleDelta.y > 0) {
                    root.stepUp();
                } else if (event.angleDelta.y < 0) {
                    root.stepDown();
                }
            }
        }

        // Minus Button
        Item {
            id: minusButton
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: parent.height
            opacity: (root.enabled && root.value > root.from) ? 1.0 : 0.38

            Rectangle {
                id: minusHover
                anchors.fill: parent
                anchors.margins: 2
                radius: Math.max(2, stepperBox.radius - 2)
                color: Theme.surfaceText
                opacity: minusArea.pressed ? 0.12 : (minusArea.containsMouse ? 0.08 : 0)
                Behavior on opacity { NumberAnimation { duration: 100 } }
            }

            DankIcon {
                anchors.centerIn: parent
                name: "remove"
                size: Theme.iconSizeSmall
                color: (root.enabled && root.value > root.from) ? Theme.surfaceText : Theme.surfaceVariantText
            }

            MouseArea {
                id: minusArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: (root.enabled && root.value > root.from) ? Qt.PointingHandCursor : Qt.ArrowCursor
                enabled: root.enabled && root.value > root.from

                onPressed: root.startStepping(root.stepDown)
                onReleased: root.stopStepping()
                onCanceled: root.stopStepping()
            }
        }

        // Center Value Display & Text Input
        Item {
            id: centerArea
            anchors.left: minusButton.right
            anchors.right: plusButton.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            clip: true

            StyledText {
                id: valueDisplay
                anchors.centerIn: parent
                visible: !editor.activeFocus
                text: String(root.value)
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Bold
                color: root.isVisualActive ? Theme.primary : Theme.surfaceText
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }

            TextInput {
                id: editor
                anchors.fill: parent
                visible: activeFocus
                text: String(root.value)
                font.pixelSize: Theme.fontSizeMedium
                font.family: Theme.fontFamily
                font.weight: Font.Bold
                color: root.isVisualActive ? Theme.primary : Theme.surfaceText
                selectionColor: Theme.primaryContainer
                selectedTextColor: Theme.primaryText
                horizontalAlignment: TextInput.AlignHCenter
                verticalAlignment: TextInput.AlignVCenter
                selectByMouse: true
                inputMethodHints: Qt.ImhDigitsOnly
                validator: IntValidator {
                    bottom: root.from
                    top: root.to
                }
                clip: true

                onEditingFinished: root.commitEditor()

                Keys.onReturnPressed: {
                    root.commitEditor();
                    editor.focus = false;
                }
                Keys.onEnterPressed: {
                    root.commitEditor();
                    editor.focus = false;
                }
                Keys.onEscapePressed: {
                    editor.text = Qt.binding(() => String(root.value));
                    editor.focus = false;
                    root.editingFinished();
                }
                Keys.onUpPressed: root.stepUp()
                Keys.onDownPressed: root.stepDown()
            }

            MouseArea {
                id: textClickArea
                anchors.fill: parent
                visible: !editor.activeFocus
                cursorShape: Qt.IBeamCursor
                hoverEnabled: true
                onClicked: {
                    editor.text = String(root.value);
                    editor.forceActiveFocus();
                    editor.selectAll();
                }
            }
        }

        // Plus Button
        Item {
            id: plusButton
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: parent.height
            opacity: (root.enabled && root.value < root.to) ? 1.0 : 0.38

            Rectangle {
                id: plusHover
                anchors.fill: parent
                anchors.margins: 2
                radius: Math.max(2, stepperBox.radius - 2)
                color: Theme.surfaceText
                opacity: plusArea.pressed ? 0.12 : (plusArea.containsMouse ? 0.08 : 0)
                Behavior on opacity { NumberAnimation { duration: 100 } }
            }

            DankIcon {
                anchors.centerIn: parent
                name: "add"
                size: Theme.iconSizeSmall
                color: (root.enabled && root.value < root.to) ? Theme.surfaceText : Theme.surfaceVariantText
            }

            MouseArea {
                id: plusArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: (root.enabled && root.value < root.to) ? Qt.PointingHandCursor : Qt.ArrowCursor
                enabled: root.enabled && root.value < root.to

                onPressed: root.startStepping(root.stepUp)
                onReleased: root.stopStepping()
                onCanceled: root.stopStepping()
            }
        }
    }

    // =========================================================================
    // Helper Methods & Stepper Timer Logic
    // =========================================================================
    onValueChanged: {
        if (!editor.activeFocus) {
            editor.text = String(root.value);
        }
    }

    function commitEditor() {
        var parsed = parseInt(editor.text, 10);
        if (isNaN(parsed)) {
            parsed = root.value;
        }
        var clamped = Math.max(root.from, Math.min(root.to, parsed));
        if (clamped !== root.value) {
            root.modified(clamped);
        }
        editor.text = Qt.binding(() => String(root.value));
        root.editingFinished();
    }

    function stepUp() {
        var newVal = Math.min(root.to, root.value + 1);
        if (newVal !== root.value) {
            root.modified(newVal);
        }
    }

    function stepDown() {
        var newVal = Math.max(root.from, root.value - 1);
        if (newVal !== root.value) {
            root.modified(newVal);
        }
    }

    Timer {
        id: stepRepeatTimer
        interval: 80
        repeat: true
        property var stepAction: null
        onTriggered: {
            if (stepAction) stepAction();
        }
    }

    Timer {
        id: stepInitialDelayTimer
        interval: 350
        repeat: false
        property var stepAction: null
        onTriggered: {
            stepRepeatTimer.stepAction = stepAction;
            stepRepeatTimer.start();
        }
    }

    function startStepping(action) {
        action();
        stepInitialDelayTimer.stepAction = action;
        stepInitialDelayTimer.start();
    }

    function stopStepping() {
        stepInitialDelayTimer.stop();
        stepRepeatTimer.stop();
        root.editingFinished();
    }
}
