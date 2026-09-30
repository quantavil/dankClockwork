#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR=$(cd -- "$SCRIPT_DIR/.." && pwd)
QML_TEST_RUNNER=${QML_TEST_RUNNER:-/usr/lib/qt6/bin/qmltestrunner}
if ! command -v "$QML_TEST_RUNNER" >/dev/null 2>&1; then
    echo "ERROR: qmltestrunner is required (set QML_TEST_RUNNER to its path)" >&2
    exit 1
fi
FIXTURE_DIR=$(mktemp -d)
trap 'rm -rf -- "$FIXTURE_DIR"' EXIT
mkdir -p "$FIXTURE_DIR/Clockwork" "$FIXTURE_DIR/Quickshell/Io"
cp "$ROOT_DIR/ClockworkState.qml" "$ROOT_DIR/ClockworkEngine.js" "$ROOT_DIR/ClockworkPopout.qml" "$ROOT_DIR/ClockworkChip.qml" "$ROOT_DIR/ClockworkTimeField.qml" "$ROOT_DIR/ClockworkCompactField.qml" "$FIXTURE_DIR/Clockwork/"
printf '%s\n' 'module Clockwork' 'singleton ClockworkState 1.0 ClockworkState.qml' 'ClockworkPopout 1.0 ClockworkPopout.qml' 'ClockworkChip 1.0 ClockworkChip.qml' 'ClockworkTimeField 1.0 ClockworkTimeField.qml' 'ClockworkCompactField 1.0 ClockworkCompactField.qml' > "$FIXTURE_DIR/Clockwork/qmldir"
# Native Quickshell plugins only load inside its executable. Substitute only those
# OS boundaries; the state singleton, bindings, timers and IPC methods run in Qt.
printf '%s\n' 'module Quickshell' 'singleton Quickshell 1.0 Quickshell.qml' > "$FIXTURE_DIR/Quickshell/qmldir"
cat > "$FIXTURE_DIR/Quickshell/Quickshell.qml" <<'QML'
pragma Singleton
import QtQml
QtObject { function execDetached(args) {} }
QML
printf '%s\n' 'module Quickshell.Io' 'IpcHandler 1.0 IpcHandler.qml' > "$FIXTURE_DIR/Quickshell/Io/qmldir"
cat > "$FIXTURE_DIR/Quickshell/Io/IpcHandler.qml" <<'QML'
import QtQuick
Item { property string target: "" }
QML
# DMS presentation primitives are substituted at the host boundary. Production
# Clockwork controls run unchanged, including focus, key events and text bindings.
mkdir -p "$FIXTURE_DIR/qs/Common" "$FIXTURE_DIR/qs/Widgets" "$FIXTURE_DIR/qs/Modules/Plugins"
printf '%s\n' 'module qs.Common' 'singleton Theme 1.0 Theme.qml' 'singleton I18n 1.0 I18n.qml' > "$FIXTURE_DIR/qs/Common/qmldir"
cat > "$FIXTURE_DIR/qs/Common/Theme.qml" <<'QML'
pragma Singleton
import QtQuick
QtObject {
    readonly property color primary: "#bfc2ff"
    readonly property color primaryText: "#101438"
    readonly property color primaryContainer: "#0000ff"
    readonly property color secondary: "#c2d8ba"
    readonly property color surfaceText: "#e0e0e0"
    readonly property color surfaceVariantText: "#b0b0b0"
    readonly property color surfaceContainerHigh: "#202128"
    readonly property color surfaceContainerHighest: "#2b2c34"
    readonly property color outline: "#808080"
    readonly property color error: "#ffb4ab"
    readonly property string monoFontFamily: "monospace"
    readonly property string fontFamily: "sans-serif"
    property real fontScale: 1
    property real spacingScale: 1
    property real cornerRadius: 12
    readonly property real spacingXXS: 2 * spacingScale
    readonly property real spacingXS: 4 * spacingScale
    readonly property real spacingS: 8 * spacingScale
    readonly property real spacingM: 12 * spacingScale
    readonly property real spacingL: 16 * spacingScale
    readonly property real spacingXL: 24 * spacingScale
    readonly property real fontSizeSmall: 12 * fontScale
    readonly property real fontSizeMedium: 14 * fontScale
    readonly property real fontSizeLarge: 16 * fontScale
    readonly property real fontSizeXLarge: 20 * fontScale
    readonly property int iconSizeSmall: 16
    readonly property int iconSize: 24
    readonly property int iconSizeLarge: 32
    function withAlpha(color, alpha) { return Qt.rgba(color.r, color.g, color.b, alpha); }
}
QML
cat > "$FIXTURE_DIR/qs/Common/I18n.qml" <<'QML'
pragma Singleton
import QtQml
QtObject { function trFor(domain, text) { return text; } }
QML
printf '%s\n' 'module qs.Widgets' 'StyledRect 1.0 StyledRect.qml' 'StyledText 1.0 StyledText.qml' 'DankIcon 1.0 DankIcon.qml' 'DankActionButton 1.0 DankActionButton.qml' > "$FIXTURE_DIR/qs/Widgets/qmldir"
printf '%s\n' 'import QtQuick' 'Rectangle {}' > "$FIXTURE_DIR/qs/Widgets/StyledRect.qml"
printf '%s\n' 'import QtQuick' 'Text {}' > "$FIXTURE_DIR/qs/Widgets/StyledText.qml"
printf '%s\n' 'import QtQuick' 'Item { property string name; property real size; property color color; width: size; height: size }' > "$FIXTURE_DIR/qs/Widgets/DankIcon.qml"
printf '%s\n' 'import QtQuick' 'Item { property string iconName; property real iconSize; property string tooltipText; property color iconColor; property color backgroundColor; property real buttonSize: 32; signal clicked(); width: buttonSize; height: buttonSize }' > "$FIXTURE_DIR/qs/Widgets/DankActionButton.qml"
printf '%s\n' 'module qs.Modules.Plugins' 'PopoutComponent 1.0 PopoutComponent.qml' > "$FIXTURE_DIR/qs/Modules/Plugins/qmldir"
cat > "$FIXTURE_DIR/qs/Modules/Plugins/PopoutComponent.qml" <<'QML'
import QtQuick
Column {
    property string headerText
    property string detailsText
    property bool showCloseButton
    property var parentPopout: null
    property var closePopout: null
    property Component headerActions
    Item { width: parent.width; height: 40 }
}
QML
QT_QPA_PLATFORM=offscreen "$QML_TEST_RUNNER" -import "$FIXTURE_DIR" -input "$SCRIPT_DIR/qml"
