import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    id: root
    pluginId: "dankClockwork"

    // =========================================================================
    // Header
    // =========================================================================
    Column {
        width: parent.width
        spacing: Theme.spacingXS

        StyledText {
            text: I18n.trFor("dankClockwork", "DankClockwork Settings")
            font.pixelSize: Theme.fontSizeXLarge
            font.weight: Font.Bold
            color: Theme.surfaceText
        }

        StyledText {
            text: I18n.trFor("dankClockwork", "Configure alarm preferences, countdown reminders, and bar appearance.")
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            width: parent.width
            wrapMode: Text.WordWrap
        }
    }

    // =========================================================================
    // Alarm Preferences
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
                    text: I18n.trFor("dankClockwork", "Alarm Preferences")
                    font.pixelSize: Theme.fontSizeLarge
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            ToggleSetting {
                settingKey: "alarmUses12Hour"
                label: I18n.trFor("dankClockwork", "12-Hour Clock Format")
                description: I18n.trFor("dankClockwork", "Display and edit alarm times using 12-hour AM/PM format")
                defaultValue: false
            }

            SelectionSetting {
                settingKey: "alarmSound"
                label: I18n.trFor("dankClockwork", "Alarm Sound")
                description: I18n.trFor("dankClockwork", "Audio ringtone played when alarm triggers")
                options: [
                    {
                        label: I18n.trFor("dankClockwork", "Alarm clock"),
                        value: "alarm-clock-elapsed.oga"
                    },
                    {
                        label: I18n.trFor("dankClockwork", "Bell"),
                        value: "bell.oga"
                    },
                    {
                        label: I18n.trFor("dankClockwork", "Phone"),
                        value: "phone-incoming-call.oga"
                    }
                ]
                defaultValue: "alarm-clock-elapsed.oga"
            }
        }
    }

    // =========================================================================
    // Countdown & General
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
                    text: I18n.trFor("dankClockwork", "Countdown & Breaks")
                    font.pixelSize: Theme.fontSizeLarge
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            StringSetting {
                settingKey: "countdownMessage"
                label: I18n.trFor("dankClockwork", "Break reminder message")
                description: I18n.trFor("dankClockwork", "Message shown in full-screen overlay and desktop notifications")
                placeholder: I18n.trFor("dankClockwork", "Take a break")
                defaultValue: "Take a break"
            }

            ToggleSetting {
                settingKey: "showBarText"
                label: I18n.trFor("dankClockwork", "Show timer text in bar")
                description: I18n.trFor("dankClockwork", "Show countdown and timer text in the bar widget pill")
                defaultValue: true
            }
        }
    }
}
