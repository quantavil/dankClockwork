#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR=$(cd -- "$SCRIPT_DIR/.." && pwd)

echo "=== Clockwork QML Syntax & Module Validator ==="

# 1. Locate qmllint
QMLLINT=""
if command -v qmllint >/dev/null 2>&1; then
    QMLLINT=$(command -v qmllint)
elif [ -x "/usr/lib/qt6/bin/qmllint" ]; then
    QMLLINT="/usr/lib/qt6/bin/qmllint"
fi

if [ -z "$QMLLINT" ]; then
    echo "ERROR: qmllint not found in PATH or /usr/lib/qt6/bin/qmllint" >&2
    exit 1
fi

echo "Found qmllint: $QMLLINT"

# 2. Configure QML import paths (real imports, NO --import disable)
IMPORT_ARGS=("-I" "$ROOT_DIR")
if [ -d "/usr/lib/qt6/qml" ]; then
    IMPORT_ARGS+=("-I" "/usr/lib/qt6/qml")
fi
DMS_DIR=$(find "/run/user/$(id -u)/danklinux-shell" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | head -n 1 || true)
if [ -n "$DMS_DIR" ] && [ -d "$DMS_DIR" ]; then
    IMPORT_ARGS+=("-I" "$DMS_DIR")
fi

# 3. List of components to validate
QML_FILES=(
    "ClockworkState.qml"
    "ClockworkCompactField.qml"
    "ClockworkTimeField.qml"
    "ClockworkPopout.qml"
    "ClockworkFullscreenBreak.qml"
    "ClockworkSettings.qml"
    "ClockworkWidget.qml"
)

FAILED=0

for file in "${QML_FILES[@]}"; do
    target="$ROOT_DIR/$file"
    if [ ! -f "$target" ]; then
        echo "✖ Missing file: $file" >&2
        FAILED=$((FAILED + 1))
        continue
    fi

    echo "Checking $file..."
    if output=$("$QMLLINT" "${IMPORT_ARGS[@]}" "$target" 2>&1); then
        echo "  ✔ $file syntax valid"
    else
        echo "  ✖ $file failed validation:" >&2
        echo "$output" >&2
        FAILED=$((FAILED + 1))
    fi
done

if [ "$FAILED" -gt 0 ]; then
    echo "ERROR: $FAILED QML file(s) failed syntax validation" >&2
    exit 1
fi

echo "=== All QML components passed syntax & import checks ==="
