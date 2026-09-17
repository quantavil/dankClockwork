import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins
import "." as ClockworkCore
import "ClockworkEngine.js" as Engine

PluginSettings {
    id: root
    pluginId: "clockwork"

    // =========================================================================
    // Header
    // =========================================================================
    Column {
        width: parent.width
        spacing: Theme.spacingXS

        StyledText {
            text: I18n.tr("Clockwork Settings")
            font.pixelSize: Theme.fontSizeXLarge
            font.weight: Font.Bold
            color: Theme.surfaceText
        }

        StyledText {
            text: I18n.tr("Configure Pomodoro intervals, alarm preferences, and countdown behavior.")
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            width: parent.width
            wrapMode: Text.WordWrap
        }
    }

    // =========================================================================
    // Card 1: Pomodoro Preferences
    // =========================================================================
    StyledRect {
        id: pomodoroCard
        width: parent.width
        height: pomodoroCol.implicitHeight + Theme.spacingL * 2
        radius: Theme.cornerRadius
        color: Theme.surfaceContainerHigh

        Column {
            id: pomodoroCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Theme.spacingL
            spacing: Theme.spacingM

            Row {
                spacing: Theme.spacingS
                DankIcon {
                    name: "timer"
                    size: Theme.iconSize
                    color: Theme.primary
                    anchors.verticalCenter: parent.verticalCenter
                }
                StyledText {
                    text: I18n.tr("Pomodoro Preferences")
                    font.pixelSize: Theme.fontSizeLarge
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            SliderSetting {
                settingKey: "pomodoroWorkMinutes"
                label: I18n.tr("Work Duration")
                description: I18n.tr("Duration of focus work intervals in minutes")
                defaultValue: 25
                minimum: Engine.LIMITS.POMODORO_WORK_MIN
                maximum: Engine.LIMITS.POMODORO_WORK_MAX
                unit: " min"
            }

            SliderSetting {
                settingKey: "pomodoroShortBreakMinutes"
                label: I18n.tr("Short Break Duration")
                description: I18n.tr("Duration of short breaks in minutes")
                defaultValue: 5
                minimum: Engine.LIMITS.POMODORO_SHORT_BREAK_MIN
                maximum: Engine.LIMITS.POMODORO_SHORT_BREAK_MAX
                unit: " min"
            }

            SliderSetting {
                settingKey: "pomodoroLongBreakMinutes"
                label: I18n.tr("Long Break Duration")
                description: I18n.tr("Duration of long breaks after completing cycle set in minutes")
                defaultValue: 15
                minimum: Engine.LIMITS.POMODORO_LONG_BREAK_MIN
                maximum: Engine.LIMITS.POMODORO_LONG_BREAK_MAX
                unit: " min"
            }

            SliderSetting {
                settingKey: "pomodoroCycles"
                label: I18n.tr("Cycles Until Long Break")
                description: I18n.tr("Number of focus sessions before a long break")
                defaultValue: 4
                minimum: Engine.LIMITS.POMODORO_CYCLES_MIN
                maximum: Engine.LIMITS.POMODORO_CYCLES_MAX
            }

            ToggleSetting {
                settingKey: "pomodoroSound"
                label: I18n.tr("Pomodoro Sound Alerts")
                description: I18n.tr("Play completion sound chime at the end of each phase")
                defaultValue: true
            }
        }
    }

    // =========================================================================
    // Card 2: Alarm Preferences
    // =========================================================================
    StyledRect {
        id: alarmCard
        width: parent.width
        height: alarmCol.implicitHeight + Theme.spacingL * 2
        radius: Theme.cornerRadius
        color: Theme.surfaceContainerHigh

        Column {
            id: alarmCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Theme.spacingL
            spacing: Theme.spacingM

            Row {
                spacing: Theme.spacingS
                DankIcon {
                    name: "alarm"
                    size: Theme.iconSize
                    color: Theme.primary
                    anchors.verticalCenter: parent.verticalCenter
                }
                StyledText {
                    text: I18n.tr("Alarm Preferences")
                    font.pixelSize: Theme.fontSizeLarge
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            ToggleSetting {
                settingKey: "alarmUses12Hour"
                label: I18n.tr("12-Hour Clock Format")
                description: I18n.tr("Display and edit alarm times using 12-hour AM/PM format")
                defaultValue: false
            }

            SelectionSetting {
                settingKey: "alarmSound"
                label: I18n.tr("Alarm Sound")
                description: I18n.tr("Audio ringtone played when alarm triggers")
                options: [
                    {
                        label: "Alarm clock (alarm-clock-elapsed.oga)",
                        value: "alarm-clock-elapsed.oga"
                    },
                    {
                        label: "Bell (bell.oga)",
                        value: "bell.oga"
                    },
                    {
                        label: "Phone (phone-incoming-call.oga)",
                        value: "phone-incoming-call.oga"
                    }
                ]
                defaultValue: "alarm-clock-elapsed.oga"
            }
        }
    }

    // =========================================================================
    // Card 3: Countdown & General
    // =========================================================================
    StyledRect {
        id: countdownCard
        width: parent.width
        height: countdownCol.implicitHeight + Theme.spacingL * 2
        radius: Theme.cornerRadius
        color: Theme.surfaceContainerHigh

        Column {
            id: countdownCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Theme.spacingL
            spacing: Theme.spacingM

            Row {
                spacing: Theme.spacingS
                DankIcon {
                    name: "hourglass_empty"
                    size: Theme.iconSize
                    color: Theme.primary
                    anchors.verticalCenter: parent.verticalCenter
                }
                StyledText {
                    text: I18n.tr("Countdown & Breaks")
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.Bold
                    color: Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            SpinBoxSetting {
                settingKey: "countdownMinutes"
                label: I18n.tr("Default Countdown Duration (minutes)")
                description: I18n.tr("Default duration when resetting or opening countdown")
                minimumValue: 1
                maximumValue: 180
                stepSize: 1
                defaultValue: 5
            }

            TextFieldSetting {
                settingKey: "countdownMessage"
                label: I18n.tr("Default Break / Alert Message")
                description: I18n.tr("Message shown in full-screen overlay and desktop notifications")
                defaultValue: "Take a break"
            }

            ToggleSetting {
                settingKey: "countdownFullscreenEnabled"
                label: I18n.tr("Full-Screen Overlay on Expiry")
                description: I18n.tr("Display a full-screen break reminder when a countdown completes")
                defaultValue: false
            }

            ToggleSetting {
                settingKey: "showBarText"
                label: I18n.tr("Show Remaining Time in Bar")
                description: I18n.tr("Show countdown and timer text in the bar widget pill")
                defaultValue: true
            }
        }
    }

    // =========================================================================
    // State Synchronization
    // =========================================================================
    onSettingChanged: syncToState()

    Component.onCompleted: syncToState()

    function syncToState() {
        ClockworkCore.ClockworkState.setPomodoroWorkMinutes(loadValue("pomodoroWorkMinutes", 25), false);
        ClockworkCore.ClockworkState.setPomodoroShortBreakMinutes(loadValue("pomodoroShortBreakMinutes", 5), false);
        ClockworkCore.ClockworkState.setPomodoroLongBreakMinutes(loadValue("pomodoroLongBreakMinutes", 15), false);
        ClockworkCore.ClockworkState.setPomodoroCycles(loadValue("pomodoroCycles", 4), false);
        ClockworkCore.ClockworkState.setPomodoroSoundEnabled(loadValue("pomodoroSound", true), false);
        ClockworkCore.ClockworkState.setAlarmUses12Hour(loadValue("alarmUses12Hour", false), false);
        ClockworkCore.ClockworkState.setAlarmSound(loadValue("alarmSound", "alarm-clock-elapsed.oga"), false);
        ClockworkCore.ClockworkState.setCountdownFullscreenEnabled(loadValue("countdownFullscreenEnabled", false), false);
        ClockworkCore.ClockworkState.setCountdownMessage(loadValue("countdownMessage", "Take a break"), false);
        ClockworkCore.ClockworkState.setCountdownMinutes(loadValue("countdownMinutes", 5), false);
    }
}
