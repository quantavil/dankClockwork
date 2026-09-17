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
            text: I18n.trFor("clockwork", "Clockwork Settings")
            font.pixelSize: Theme.fontSizeXLarge
            font.weight: Font.Bold
            color: Theme.surfaceText
        }

        StyledText {
            text: I18n.trFor("clockwork", "Configure Pomodoro intervals, alarm preferences, and countdown behavior.")
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
        implicitHeight: pomodoroCol.implicitHeight + Theme.spacingL * 2
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
                    text: I18n.trFor("clockwork", "Pomodoro Preferences")
                    font.pixelSize: Theme.fontSizeLarge
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            SliderSetting {
                settingKey: "pomodoroWorkMinutes"
                label: I18n.trFor("clockwork", "Work Duration")
                description: I18n.trFor("clockwork", "Duration of focus work intervals in minutes")
                defaultValue: 25
                minimum: Engine.LIMITS.POMODORO_WORK_MIN
                maximum: Engine.LIMITS.POMODORO_WORK_MAX
                unit: " min"
            }

            SliderSetting {
                settingKey: "pomodoroShortBreakMinutes"
                label: I18n.trFor("clockwork", "Short Break Duration")
                description: I18n.trFor("clockwork", "Duration of short breaks in minutes")
                defaultValue: 5
                minimum: Engine.LIMITS.POMODORO_SHORT_BREAK_MIN
                maximum: Engine.LIMITS.POMODORO_SHORT_BREAK_MAX
                unit: " min"
            }

            SliderSetting {
                settingKey: "pomodoroLongBreakMinutes"
                label: I18n.trFor("clockwork", "Long Break Duration")
                description: I18n.trFor("clockwork", "Duration of long breaks after completing cycle set in minutes")
                defaultValue: 15
                minimum: Engine.LIMITS.POMODORO_LONG_BREAK_MIN
                maximum: Engine.LIMITS.POMODORO_LONG_BREAK_MAX
                unit: " min"
            }

            SliderSetting {
                settingKey: "pomodoroCycles"
                label: I18n.trFor("clockwork", "Cycles Until Long Break")
                description: I18n.trFor("clockwork", "Number of focus sessions before a long break")
                defaultValue: 4
                minimum: Engine.LIMITS.POMODORO_CYCLES_MIN
                maximum: Engine.LIMITS.POMODORO_CYCLES_MAX
            }

            ToggleSetting {
                settingKey: "pomodoroSound"
                label: I18n.trFor("clockwork", "Pomodoro Sound Alerts")
                description: I18n.trFor("clockwork", "Play completion sound chime at the end of each phase")
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
        implicitHeight: alarmCol.implicitHeight + Theme.spacingL * 2
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
                    text: I18n.trFor("clockwork", "Alarm Preferences")
                    font.pixelSize: Theme.fontSizeLarge
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            ToggleSetting {
                settingKey: "alarmUses12Hour"
                label: I18n.trFor("clockwork", "12-Hour Clock Format")
                description: I18n.trFor("clockwork", "Display and edit alarm times using 12-hour AM/PM format")
                defaultValue: false
            }

            SelectionSetting {
                settingKey: "alarmSound"
                label: I18n.trFor("clockwork", "Alarm Sound")
                description: I18n.trFor("clockwork", "Audio ringtone played when alarm triggers")
                options: [
                    {
                        label: I18n.trFor("clockwork", "Alarm clock (alarm-clock-elapsed.oga)"),
                        value: "alarm-clock-elapsed.oga"
                    },
                    {
                        label: I18n.trFor("clockwork", "Bell (bell.oga)"),
                        value: "bell.oga"
                    },
                    {
                        label: I18n.trFor("clockwork", "Phone (phone-incoming-call.oga)"),
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
        implicitHeight: countdownCol.implicitHeight + Theme.spacingL * 2
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
                    text: I18n.trFor("clockwork", "Countdown & Breaks")
                    font.pixelSize: Theme.fontSizeLarge
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            SliderSetting {
                settingKey: "countdownMinutes"
                label: I18n.trFor("clockwork", "Default Countdown Duration")
                description: I18n.trFor("clockwork", "Default minutes when resetting or starting countdown")
                minimum: 1
                maximum: 180
                unit: " min"
                defaultValue: 5
            }

            StringSetting {
                settingKey: "countdownMessage"
                label: I18n.trFor("clockwork", "Default Break / Alert Message")
                description: I18n.trFor("clockwork", "Message shown in full-screen overlay and desktop notifications")
                placeholder: "Take a break"
                defaultValue: "Take a break"
            }

            ToggleSetting {
                settingKey: "countdownFullscreenEnabled"
                label: I18n.trFor("clockwork", "Full-Screen Overlay on Expiry")
                description: I18n.trFor("clockwork", "Display a full-screen break reminder when a countdown completes")
                defaultValue: false
            }

            ToggleSetting {
                settingKey: "showBarText"
                label: I18n.trFor("clockwork", "Show Remaining Time in Bar")
                description: I18n.trFor("clockwork", "Show countdown and timer text in the bar widget pill")
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
        ClockworkCore.ClockworkState.setCountdownSeconds(loadValue("countdownSeconds", 0), false);
    }
}
