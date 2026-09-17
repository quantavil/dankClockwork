import QtQuick
import qs.Common
import qs.Widgets
import "ClockworkEngine.js" as Engine

Item {
    id: root

    // =========================================================================
    // Properties
    // =========================================================================
    property int value: 0
    property int from: 0
    property int to: 59
    property bool wrap: true
    property real fontSize: 36
    readonly property bool isVisualActive: editor.activeFocus

    // =========================================================================
    // Signals
    // =========================================================================
    signal modified(int newValue)
    signal editingFinished()

    // =========================================================================
    // Dimensions
    // =========================================================================
    implicitWidth: Math.max(88, Math.round(root.fontSize * 2.3))
    implicitHeight: Math.max(54, Math.round(root.fontSize * 1.5))

    // =========================================================================
    // Material 3 Pill Container
    // =========================================================================
    StyledRect {
        id: pillBox
        anchors.fill: parent
        radius: Math.round(root.implicitHeight / 2)

        color: root.isVisualActive
            ? Theme.surfaceContainerHighest
            : Theme.surfaceContainerHigh

        border.color: root.isVisualActive
            ? Theme.primary
            : Theme.withAlpha(Theme.outline, 0.12)
        border.width: root.isVisualActive ? 2 : 1

        Behavior on color {
            ColorAnimation { duration: 150 }
        }
        Behavior on border.color {
            ColorAnimation { duration: 150 }
        }
        Behavior on border.width {
            NumberAnimation { duration: 150 }
        }

        // Mouse Hover Highlight
        Rectangle {
            id: hoverState
            anchors.fill: parent
            radius: pillBox.radius
            color: Theme.surfaceText
            opacity: pillArea.containsMouse && !editor.activeFocus ? 0.06 : 0
            Behavior on opacity { NumberAnimation { duration: 150 } }
        }

        // Mouse Wheel Scroll Adjustment (Mouse only to prevent touchpad runaway)
        WheelHandler {
            acceptedDevices: PointerDevice.Mouse
            enabled: root.enabled
            onWheel: event => {
                if (event.angleDelta.y > 0) {
                    root.stepUp();
                } else if (event.angleDelta.y < 0) {
                    root.stepDown();
                }
            }
        }

        // Editable Text Input & Display
        TextInput {
            id: editor
            anchors.centerIn: parent
            width: pillBox.width - 24
            horizontalAlignment: TextInput.AlignHCenter
            verticalAlignment: TextInput.AlignVCenter
            text: Engine.pad2(root.value)
            font.pixelSize: root.fontSize
            font.family: Theme.monoFontFamily
            font.weight: Font.Bold
            color: root.isVisualActive ? Theme.primary : Theme.surfaceText
            selectionColor: Theme.primaryContainer
            selectedTextColor: Theme.primaryText
            selectByMouse: true
            inputMethodHints: Qt.ImhDigitsOnly
            maximumLength: Math.max(2, String(root.to).length)
            validator: IntValidator {
                bottom: 0
                top: root.to
            }

            onEditingFinished: root.commitText()

            onActiveFocusChanged: {
                if (activeFocus) {
                    selectAll();
                }
            }

            Keys.onReturnPressed: {
                root.commitText();
                editor.focus = false;
            }
            Keys.onEnterPressed: {
                root.commitText();
                editor.focus = false;
            }
            Keys.onEscapePressed: {
                editor.text = Qt.binding(() => Engine.pad2(root.value));
                editor.focus = false;
                root.editingFinished();
            }
            Keys.onUpPressed: root.stepUp()
            Keys.onDownPressed: root.stepDown()
        }

        // Click Handler to focus and select
        MouseArea {
            id: pillArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            enabled: !editor.activeFocus
            onClicked: {
                editor.forceActiveFocus();
                editor.selectAll();
            }
        }
    }

    // =========================================================================
    // Helper Methods
    // =========================================================================
    function commitText() {
        const parsed = parseInt(editor.text, 10);
        const resolved = isNaN(parsed) ? root.value : parsed;
        const clamped = Math.max(root.from, Math.min(root.to, resolved));
        if (clamped !== root.value) {
            root.modified(clamped);
        }
        editor.text = Qt.binding(() => Engine.pad2(root.value));
        root.editingFinished();
    }

    function stepUp() {
        let nextVal = root.value + 1;
        if (nextVal > root.to) {
            nextVal = root.wrap ? root.from : root.to;
        }
        if (nextVal !== root.value) {
            root.modified(nextVal);
        }
    }

    function stepDown() {
        let nextVal = root.value - 1;
        if (nextVal < root.from) {
            nextVal = root.wrap ? root.to : root.from;
        }
        if (nextVal !== root.value) {
            root.modified(nextVal);
        }
    }
}
