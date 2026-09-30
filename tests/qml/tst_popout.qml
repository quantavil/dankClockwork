import QtQuick
import QtTest
import Clockwork
import qs.Common

TestCase {
    id: root
    name: "ClockworkPopout"
    when: windowShown
    visible: true
    width: 480
    height: 480
    readonly property var state: ClockworkState

    Component {
        id: panelComponent
        ClockworkPopout { width: Theme.fontSizeSmall * 35 + Theme.spacingXL + Theme.spacingL }
    }

    function init() {
        Theme.fontScale = 1;
        Theme.spacingScale = 1;
        Theme.cornerRadius = 12;
        state.configuredSettings = {};
        state.selectMode(0);
        state.reset();
    }
    function cleanup() {
        state.reset();
        Theme.fontScale = 1;
        Theme.spacingScale = 1;
        Theme.cornerRadius = 12;
    }

    function test_panelFitsVisibleControls() {
        const panel = createTemporaryObject(panelComponent, root);
        verify(panel);
        const content = findChild(panel, "dankClockworkContent");
        const display = findChild(panel, "dankClockworkDisplay");
        const controls = findChild(panel, "dankClockworkConfiguration");
        const actions = findChild(panel, "dankClockworkActions");
        const heights = [];
        for (let mode = 0; mode < 5; mode++) {
            state.selectMode(mode);
            wait(20);
            heights.push(panel.implicitHeight);
            for (let phase = 0; phase < 3; phase++) {
                verify(actions.y >= display.y + display.height + 12);
                if (controls.height > 0) {
                    verify(actions.y >= controls.y + controls.height + 12);
                    verify(actions.y <= controls.y + controls.height + 24);
                } else {
                    verify(actions.y <= display.y + display.height + 24);
                }
                compare(content.implicitHeight, actions.y + actions.height + 12);
                if (phase === 0) state.start();
                if (phase === 1) state.pause();
                wait(20);
            }
            state.reset();
        }
        compare(heights[0], heights[1], "Countdown toggle should not add a configuration row");
        verify(heights[2] < heights[4], "Two-row Pomodoro controls need more room");
        verify(heights[4] < 436, "Even the largest mode should be compact");
    }

    function test_themeMetrics_data() {
        return [
            { tag: "large-rounded", fontScale: 1.5, spacingScale: 1.25, radius: 20 },
            { tag: "double-square", fontScale: 2, spacingScale: 1, radius: 0 }
        ];
    }

    function test_themeMetrics(data) {
        state.selectMode(1);
        const panel = createTemporaryObject(panelComponent, root);
        const display = findChild(panel, "dankClockworkDisplay");
        const actions = findChild(panel, "dankClockworkActions");
        const field = findChild(panel, "dankClockworkFirstTimeField");
        const editor = findChild(panel, "dankClockworkFirstTimeFieldInput");
        const initialHeight = panel.implicitHeight;
        const initialFont = editor.font.pixelSize;
        const initialActionHeight = actions.height;
        Theme.fontScale = data.fontScale;
        Theme.spacingScale = data.spacingScale;
        Theme.cornerRadius = data.radius;
        wait(30);
        compare(display.radius, Theme.cornerRadius);
        compare(field.children[0].radius, Theme.cornerRadius / 2);
        compare(findChild(panel, "dankClockworkMainAction").radius, Theme.cornerRadius);
        verify(editor.font.pixelSize >= initialFont * data.fontScale - 1);
        verify(panel.implicitHeight > initialHeight);
        verify(actions.height > initialActionHeight);
        verify(field.mapToItem(display, 0, 0).y + field.height <= display.height);
        verify(field.mapToItem(display, 0, 0).x >= 0);
        const second = findChild(panel, "dankClockworkSecondTimeField");
        verify(second.mapToItem(display, 0, 0).x + second.width <= display.width);
        for (let mode = 0; mode < 5; mode++) {
            state.selectMode(mode);
            wait(20);
            const controls = findChild(panel, "dankClockworkConfiguration");
            verify(actions.y >= display.y + display.height + Theme.spacingM);
            if (controls.height > 0) verify(actions.y >= controls.y + controls.height + Theme.spacingM);
            compare(findChild(panel, "dankClockworkContent").implicitHeight,
                actions.y + actions.height + Theme.spacingM);
        }
    }

    function test_tabsUseAccentWithoutSelectedFill() {
        const panel = createTemporaryObject(panelComponent, root);
        wait(200);
        for (let mode = 0; mode < 5; mode++) {
            state.selectMode(mode);
            wait(200);
            for (let index = 0; index < 5; index++) {
                const tab = findChild(panel, "dankClockworkTab" + index);
                verify(tab);
                compare(tab.tonal, index === mode);
                compare(tab.color.a, 0);
                compare(tab.contentColor, index === mode ? Theme.primary : Theme.surfaceVariantText);
            }
        }
    }

    function test_fullscreenToggleLivesInTimerCard() {
        state.selectMode(1);
        state.countdownFullscreenEnabled = false;
        const panel = createTemporaryObject(panelComponent, root);
        const display = findChild(panel, "dankClockworkDisplay");
        const toggle = findChild(panel, "dankClockworkFullscreenToggle");
        verify(toggle);
        compare(toggle.parent, display);
        compare(toggle.visible, true);
        verify(toggle.x + toggle.width <= display.width);
        const initialHeight = panel.implicitHeight;
        toggle.clicked();
        compare(state.countdownFullscreenEnabled, true);
        compare(panel.implicitHeight, initialHeight);
        state.selectMode(0);
        compare(toggle.visible, false);
        state.countdownFullscreenEnabled = false;
    }

    function test_timeEditingUsesNeutralSelectionAndRestoresBinding() {
        state.selectMode(1);
        const panel = createTemporaryObject(panelComponent, root);
        wait(30);
        const field = findChild(panel, "dankClockworkFirstTimeField");
        const editor = findChild(panel, "dankClockworkFirstTimeFieldInput");
        verify(field && editor);
        mouseClick(field, field.width / 2, field.height / 2);
        compare(editor.activeFocus, true);
        compare(editor.selectedTextColor, "#e0e0e0");
        verify(editor.selectionColor.a < 0.2);
        keyClick(Qt.Key_1);
        keyClick(Qt.Key_2);
        keyClick(Qt.Key_Return);
        compare(state.countdownMinutes, 12);
        compare(state.running, false);
        state.setCountdownMinutes(34, false);
        compare(editor.text, "34");
    }

    function test_numberKeysEditFieldsWithoutChangingMode() {
        state.selectMode(3);
        const panel = createTemporaryObject(panelComponent, root);
        wait(30);
        const field = findChild(panel, "dankClockworkFirstTimeField");
        mouseClick(field, field.width / 2, field.height / 2);
        keyClick(Qt.Key_1);
        keyClick(Qt.Key_5);
        keyClick(Qt.Key_Return);
        compare(state.mode, 3);
        compare(state.alarmHour, 15);
        compare(state.running, false);
    }
}
