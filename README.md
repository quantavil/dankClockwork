# Clockwork for DankMaterialShell

A versatile multi-mode productivity timer and bar widget for [DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell) (DMS), built natively with Quickshell, QtQuick, and Material 3 design tokens.

Clockwork combines five essential time-tracking tools into a single compact bar widget and popout interface:

- **Stopwatch**: Precision count-up timer with centisecond (`.cs`) display.
- **Countdown**: Configurable minutes and seconds timer with an optional Wayland fullscreen break overlay and custom reminder message upon completion.
- **Alarm**: One-shot alarm targeting the next occurrence of a time (24-hour or 12-hour AM/PM), customizable audio ringtone, and urgent bar alert pulse.
- **Intervals**: High-intensity interval / workout timer tracking elapsed rounds and durations with boundary chimes and notifications.
- **Pomodoro**: Productivity cycle timer alternating focus sessions with short and long breaks, tracking completed cycles and displaying dynamic status in the bar.

---

## Features & Modes

### 1. Stopwatch
- Real-time count-up timer formatted as `MM:SS.cs` (or `H:MM:SS.cs`).
- Runs at a responsive 20ms tick rate when the popout panel is open, and automatically throttles to 250ms when minimized to the bar to conserve CPU resources.
- Quick start, pause, and reset controls via popout, bar clicks, or IPC.

### 2. Countdown & Fullscreen Break
- Set durations in minutes and seconds using stepper controls or direct typing.
- **Fullscreen Break Overlay**: When enabled in Settings, completing a countdown triggers a dedicated Wayland fullscreen overlay (`ClockworkFullscreenBreak.qml`) displaying large typography and your custom break reminder note.
- Layer shell keyboard focus uses `OnDemand` so the overlay never locks up the Wayland compositor.
- Chimes `complete.oga` and dispatches a desktop notification upon completion.

### 3. Alarm
- Set a one-shot target time in either **24-hour** or **12-hour (AM/PM)** format.
- Automatically calculates the next occurrence (today if the target time is in the future, or tomorrow if it has already passed).
- Choose from standard system sounds:
  - `alarm-clock-elapsed.oga` (default)
  - `bell.oga`
  - `phone-incoming-call.oga`
- Repeats ring audio every 3 seconds for up to 3 minutes or until silenced/acknowledged.
- Pulses an urgent accent color in the DankBar pill while ringing.

### 4. Intervals
- Configure the number of rounds (1–99) and round duration (minutes and seconds).
- Audio chime (`complete.oga`) and desktop notification at each round transition ("Round X complete · Round Y starts now").
- Audio chime and completion notification when all rounds finish ("All X rounds complete").

### 5. Pomodoro (Focus & Break Cycles)
- **Focus Phase**: Configurable work duration (default: 25 min). Displays the `work` icon on the bar pill and popout. Chimes `complete.oga` upon focus session completion.
- **Break Phases**: Alternates between short breaks (default: 5 min) and a long break (default: 15 min after target cycle count, default: 4). Automatically switches to the `emoji_food_beverage` (tea cup) icon and soft green accent color (`#a6e3a1`). Chimes `bell.oga` upon break completion.
- **Phase Skipping**: Advance between focus and break immediately via the popout button, `S` key shortcut, or IPC (`dms ipc call clockwork skip`).

---

## DankBar Widget Integration

- **Persistent Pill**: Displays current mode icon and time in either horizontal or vertical DankBar layouts.
- **Adaptive Typography**: Complies with Material 3 contrast tokens (`Theme.surfaceText`, `Theme.primary`, `Theme.error`).
- **Interactive Controls**:
  - **Left-Click**: Opens or toggles the Clockwork popout interface.
  - **Middle-Click**: Starts or pauses the active timer immediately from the bar.
  - **Right-Click**: If running, pauses the timer; if paused or completed, resets the timer; if an alarm is ringing, silences it.

---

## Keyboard Shortcuts

### Popout Keyboard Controls
When the Clockwork popout is open, the following keyboard controls are active immediately:

| Key | Action |
| :--- | :--- |
| `1` – `5` (or Numpad `1`–`5`) | Switch modes: `1` Stopwatch, `2` Countdown, `3` Intervals, `4` Alarm, `5` Pomodoro |
| `Space` or `Enter` | Start or Pause the active timer (or arm/disarm the Alarm) |
| `R` | Reset the active timer (or silence a ringing alarm) |
| `S` | Skip current Pomodoro phase (advance between Focus and Break) |
| `Esc` | Close the popout panel |
| `Mouse Wheel` | Hover over any time or round field and scroll Up/Down to adjust values |
| `Click & Type` | Click into any number field to directly type values (standard typing keys preserved while editing) |

### Fullscreen Break Overlay Controls
When the fullscreen break view is displayed:

| Key | Action |
| :--- | :--- |
| `Esc` | Dismiss / close the fullscreen break overlay |
| `Space` | Toggle start / pause |
| `R` | Reset the timer |
---

## IPC Interface Reference

Clockwork registers the `clockwork` IPC target in DMS. All methods can be called via `dms ipc call clockwork <function> [args...]`:

### Timer Control Commands
| Command | Arguments | Return Value | Description |
| :--- | :--- | :--- | :--- |
| `start` | *(none)* | `CLOCKWORK_STARTED` or `CLOCKWORK_ALREADY_RUNNING` | Starts the active timer |
| `pause` | *(none)* | `CLOCKWORK_PAUSED` or `CLOCKWORK_ALREADY_PAUSED` | Pauses the active timer |
| `toggle` | *(none)* | `CLOCKWORK_RUNNING` or `CLOCKWORK_PAUSED` | Toggles between start and pause |
| `reset` | *(none)* | `CLOCKWORK_RESET` | Resets active timer (or silences ringing alarm) |
| `skip` | *(none)* | `CLOCKWORK_POMODORO_SKIPPED` or `ERROR_NOT_POMODORO` | Skips current Pomodoro phase |

### Mode Activation Commands
| Command | Arguments | Return Value | Description |
| :--- | :--- | :--- | :--- |
| `stopwatch` | *(none)* | `CLOCKWORK_STOPWATCH_STARTED` | Switches to Stopwatch and starts counting |
| `countdown` | `<minutes> [seconds]` | `CLOCKWORK_COUNTDOWN_STARTED` | Sets countdown duration and starts |
| `intervals` | `<rounds> <minutes> [seconds]` | `CLOCKWORK_INTERVALS_STARTED` | Sets interval rounds, duration, and starts |
| `alarm` | `<hour> <minute> [message]` | `CLOCKWORK_ALARM_ARMED` | Arms alarm for `hour` (24h: 0–23) and `minute` (0–59) |
| `pomodoro` | `[work] [short] [cycles] [long]` | `CLOCKWORK_POMODORO_STARTED` | Configures Pomodoro parameters and starts |

*(Note: Passing invalid numeric arguments returns `ERROR_INVALID_ARGUMENTS`)*

### Popout & Window Commands
| Command | Arguments | Return Value | Description |
| :--- | :--- | :--- | :--- |
| `open` | *(none)* | `CLOCKWORK_POPOUT_OPENED` | Opens the Clockwork popout panel |
| `close` | *(none)* | `CLOCKWORK_POPOUT_CLOSED` | Closes the Clockwork popout panel |
| `togglePopout` | *(none)* | `CLOCKWORK_POPOUT_TOGGLED` | Toggles the Clockwork popout panel |

### Status Query
`dms ipc call clockwork status` returns a formatted JSON string representing the current state:

```json
{
  "mode": "Stopwatch",
  "running": false,
  "completed": false,
  "displayText": "00:00.00",
  "statusText": "Ready",
  "progress": 0
}
```

---

## Settings & Preferences

All preferences can be configured in DMS Settings (**Mod+,** or via Control Center -> **Plugins** -> **Clockwork**):

### 1. Pomodoro Preferences
- **Work Duration**: Duration of focus work intervals (1–120 min, default: 25 min).
- **Short Break Duration**: Duration of short breaks (1–60 min, default: 5 min).
- **Long Break Duration**: Duration of long breaks after completing cycle set (1–60 min, default: 15 min).
- **Cycles Until Long Break**: Number of focus sessions before a long break (1–12, default: 4).
- **Pomodoro Sound Alerts**: Play completion sound chime at the end of each phase (default: enabled).

### 2. Alarm Preferences
- **12-Hour Clock Format**: Display and edit alarm times using 12-hour AM/PM format (default: 24-hour).
- **Alarm Sound**: Audio ringtone played when alarm triggers (`alarm-clock-elapsed.oga`, `bell.oga`, or `phone-incoming-call.oga`).

### 3. Countdown & General
- **Default Countdown Duration**: Default duration for countdown timer (1–180 min, default: 5 min).
- **Fullscreen Break View**: Automatically show fullscreen break overlay when countdown completes (default: disabled).
- **Break Message**: Custom reminder text displayed on countdown and break screens (default: "Take a break").
- **Show Remaining Time in Bar**: Show countdown and timer text in the DankBar widget pill (default: enabled).

---

## Installation & Requirements

### Runtime Dependencies
- **DankMaterialShell**: `>=1.4.0`
- **PipeWire**: `pw-play` for non-blocking audio alerts
- **Desktop Notifications**: `notify-send` (libnotify)
- **Audio Theme**: Standard sound files from `sound-theme-freedesktop` located at `/usr/share/sounds/freedesktop/stereo/`

### Installation
Clone or symlink the `dankClockwork` directory into your DankMaterialShell plugins directory:

```bash
ln -s "/path/to/dankClockwork" ~/.config/DankMaterialShell/plugins/clockwork
dms restart
```

Then enable **Clockwork** in your DankBar widget settings (via DMS Settings -> **DankBar** -> **Right Widgets**).

---

## Verification & Testing

The plugin includes a full automated test suite:

```bash
# 1. Pure-JS State Engine Unit Tests (26/26 tests)
node tests/test_engine.js

# 2. QML Syntax & Module Linting (all 7 components via qmllint)
bash tests/test_qml_syntax.sh

# 3. DMS Manifest Schema Validation (validates against DMS plugin-schema.json)
uv run --with jsonschema python3 tests/validate_manifest.py
```

---

## License

MIT License. Copyright (c) 2026 quantavil.
