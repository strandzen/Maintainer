import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Kirigami.ScrollablePage {
    id: page
    objectName: "settingsPage"
    title: UIStrings.ui.settings.title

    titleDelegate: Item {}

    ColumnLayout {
        Layout.fillWidth: true
        spacing: Kirigami.Units.largeSpacing

        Kirigami.FormLayout {
            Layout.fillWidth: true

            // --- SECTION: General ---
            Label {
                Kirigami.FormData.isSection: true
                text: "General"
                font.bold: true
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                Layout.topMargin: Kirigami.Units.largeSpacing
            }
            Kirigami.Separator {
                Kirigami.FormData.isSection: true
                Layout.fillWidth: true
                opacity: 0.3
            }

            Switch {
                Kirigami.FormData.label: "Check for Updates on Startup"
                checked: SettingsManager.checkUpdatesOnStartup
                onCheckedChanged: SettingsManager.checkUpdatesOnStartup = checked
            }

            // --- SECTION: Home Page ---
            Label {
                Kirigami.FormData.isSection: true
                text: "Home Page"
                font.bold: true
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                Layout.topMargin: Kirigami.Units.largeSpacing
            }
            Kirigami.Separator {
                Kirigami.FormData.isSection: true
                Layout.fillWidth: true
                opacity: 0.3
            }


            // --- SECTION: Package Manager ---
            Label {
                Kirigami.FormData.isSection: true
                text: "Package Manager"
                font.bold: true
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                Layout.topMargin: Kirigami.Units.largeSpacing
            }
            Kirigami.Separator {
                Kirigami.FormData.isSection: true
                Layout.fillWidth: true
                opacity: 0.3
            }

            ComboBox {
                Kirigami.FormData.label: "AUR Helper"
                model: ["pacman", "paru"]
                currentIndex: {
                    var idx = model.indexOf(SettingsManager.aurHelper)
                    return idx >= 0 ? idx : 0
                }
                onActivated: SettingsManager.aurHelper = currentText
            }

            SpinBox {
                Kirigami.FormData.label: UIStrings.ui.settings.label_caches
                from: 1
                to: 10
                value: SettingsManager.packageCacheCount
                onValueChanged: SettingsManager.packageCacheCount = value
            }

            // --- SECTION: AppImage Manager ---
            Label {
                Kirigami.FormData.isSection: true
                text: "AppImage Manager"
                font.bold: true
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                Layout.topMargin: Kirigami.Units.largeSpacing
            }
            Kirigami.Separator {
                Kirigami.FormData.isSection: true
                Layout.fillWidth: true
                opacity: 0.3
            }

            TextField {
                Kirigami.FormData.label: "AppImage Folder"
                Layout.fillWidth: true
                text: SettingsManager.appImageDir
                placeholderText: "~/Applications"
                onEditingFinished: SettingsManager.appImageDir = text
            }

            // --- SECTION: Clean System ---
            Label {
                Kirigami.FormData.isSection: true
                text: "Clean System"
                font.bold: true
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                Layout.topMargin: Kirigami.Units.largeSpacing
            }
            Kirigami.Separator {
                Kirigami.FormData.isSection: true
                Layout.fillWidth: true
                opacity: 0.3
            }

            ComboBox {
                Kirigami.FormData.label: UIStrings.ui.settings.label_log_age
                model: ["1week", "2weeks", "1month"]
                currentIndex: {
                    var idx = model.indexOf(SettingsManager.journalLogAge)
                    return idx >= 0 ? idx : 1
                }
                onActivated: SettingsManager.journalLogAge = currentText
            }

            TextField {
                Kirigami.FormData.label: UIStrings.ui.settings.label_ghost_blacklist
                Layout.fillWidth: true
                text: SettingsManager.ghostConfigBlacklist
                placeholderText: UIStrings.ui.settings.placeholder_ghost
                onEditingFinished: SettingsManager.ghostConfigBlacklist = text
            }

            TextField {
                Kirigami.FormData.label: UIStrings.ui.settings.label_custom_paths
                Layout.fillWidth: true
                text: SettingsManager.corpseCleanerCustomPaths
                placeholderText: UIStrings.ui.settings.placeholder_custom_paths
                onEditingFinished: SettingsManager.corpseCleanerCustomPaths = text
            }


            // --- SECTION: UI ---
            Label {
                Kirigami.FormData.isSection: true
                text: "UI"
                font.bold: true
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                Layout.topMargin: Kirigami.Units.largeSpacing
            }
            Kirigami.Separator {
                Kirigami.FormData.isSection: true
                Layout.fillWidth: true
                opacity: 0.3
            }

            SpinBox {
                Kirigami.FormData.label: "Corner Radius"
                from: 0
                to: 24
                value: SettingsManager.cornerRadius
                onValueChanged: SettingsManager.cornerRadius = value
            }

            Switch {
                Kirigami.FormData.label: "Contrast Borders"
                checked: SettingsManager.enableContrastBorders
                onCheckedChanged: SettingsManager.enableContrastBorders = checked
            }

            Switch {
                Kirigami.FormData.label: "Alternating Row Colors"
                checked: SettingsManager.alternatingRowColors
                onCheckedChanged: SettingsManager.alternatingRowColors = checked
            }

            TextField {
                Kirigami.FormData.label: "Global Font"
                Layout.fillWidth: true
                placeholderText: "leave empty for system font"
                text: SettingsManager.globalFont
                onEditingFinished: SettingsManager.globalFont = text
            }

            SpinBox {
                Kirigami.FormData.label: "Global Font Size"
                from: 0
                to: 72
                value: SettingsManager.globalFontSize
                onValueChanged: SettingsManager.globalFontSize = value
                ToolTip.text: "Standard system font size is typically 10. Set to 0 to use the system default size."
                ToolTip.visible: hovered
                ToolTip.delay: Kirigami.Units.toolTipDelay
            }

            // --- SECTION: Colors ---
            Label {
                Kirigami.FormData.isSection: true
                text: "UI Colors"
                font.bold: true
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                Layout.topMargin: Kirigami.Units.largeSpacing
            }
            Kirigami.Separator {
                Kirigami.FormData.isSection: true
                Layout.fillWidth: true
                opacity: 0.3
            }

            RowLayout {
                Kirigami.FormData.label: "Emphasis Color"
                spacing: Kirigami.Units.smallSpacing

                Rectangle {
                    width: Kirigami.Units.iconSizes.small
                    height: Kirigami.Units.iconSizes.small
                    radius: 3
                    color: SettingsManager.emphasisColor !== "" ? SettingsManager.emphasisColor : Kirigami.Theme.highlightColor
                    border.color: Kirigami.Theme.textColor
                    border.width: 1
                }

                TextField {
                    placeholderText: "leave empty for system accent color"
                    text: SettingsManager.emphasisColor
                    onEditingFinished: {
                        if (text === "" || /^#[0-9a-fA-F]{6}$/.test(text))
                            SettingsManager.emphasisColor = text
                    }
                }
            }

            RowLayout {
                Kirigami.FormData.label: "CPU Color"
                spacing: Kirigami.Units.smallSpacing
                Rectangle {
                    width: Kirigami.Units.iconSizes.small; height: Kirigami.Units.iconSizes.small
                    radius: 3
                    color: SettingsManager.cpuColor !== "" ? SettingsManager.cpuColor : Kirigami.Theme.highlightColor
                    border.color: Kirigami.Theme.textColor; border.width: 1
                }
                TextField {
                    placeholderText: "leave empty for system accent color"
                    text: SettingsManager.cpuColor
                    onEditingFinished: {
                        if (text === "" || /^#[0-9a-fA-F]{6}$/.test(text))
                            SettingsManager.cpuColor = text
                    }
                }
            }

            RowLayout {
                Kirigami.FormData.label: "Memory Color"
                spacing: Kirigami.Units.smallSpacing
                Rectangle {
                    width: Kirigami.Units.iconSizes.small; height: Kirigami.Units.iconSizes.small
                    radius: 3
                    color: SettingsManager.memoryColor !== "" ? SettingsManager.memoryColor : Kirigami.Theme.highlightColor
                    border.color: Kirigami.Theme.textColor; border.width: 1
                }
                TextField {
                    placeholderText: "leave empty for system accent color"
                    text: SettingsManager.memoryColor
                    onEditingFinished: {
                        if (text === "" || /^#[0-9a-fA-F]{6}$/.test(text))
                            SettingsManager.memoryColor = text
                    }
                }
            }

            RowLayout {
                Kirigami.FormData.label: "Download Color"
                spacing: Kirigami.Units.smallSpacing
                Rectangle {
                    width: Kirigami.Units.iconSizes.small; height: Kirigami.Units.iconSizes.small
                    radius: 3
                    color: SettingsManager.downloadColor !== "" ? SettingsManager.downloadColor : Kirigami.Theme.highlightColor
                    border.color: Kirigami.Theme.textColor; border.width: 1
                }
                TextField {
                    placeholderText: "leave empty for system accent color"
                    text: SettingsManager.downloadColor
                    onEditingFinished: {
                        if (text === "" || /^#[0-9a-fA-F]{6}$/.test(text))
                            SettingsManager.downloadColor = text
                    }
                }
            }

            RowLayout {
                Kirigami.FormData.label: "Upload Color"
                spacing: Kirigami.Units.smallSpacing
                Rectangle {
                    width: Kirigami.Units.iconSizes.small; height: Kirigami.Units.iconSizes.small
                    radius: 3
                    color: SettingsManager.uploadColor !== "" ? SettingsManager.uploadColor : Kirigami.Theme.highlightColor
                    border.color: Kirigami.Theme.textColor; border.width: 1
                }
                TextField {
                    placeholderText: "leave empty for system accent color"
                    text: SettingsManager.uploadColor
                    onEditingFinished: {
                        if (text === "" || /^#[0-9a-fA-F]{6}$/.test(text))
                            SettingsManager.uploadColor = text
                    }
                }
            }

            RowLayout {
                Kirigami.FormData.label: "Swap Bar Color"
                spacing: Kirigami.Units.smallSpacing
                Rectangle {
                    width: Kirigami.Units.iconSizes.small; height: Kirigami.Units.iconSizes.small
                    radius: 3
                    color: SettingsManager.swapColor !== "" ? SettingsManager.swapColor : Kirigami.Theme.highlightColor
                    border.color: Kirigami.Theme.textColor; border.width: 1
                }
                TextField {
                    placeholderText: "leave empty for system accent color"
                    text: SettingsManager.swapColor
                    onEditingFinished: {
                        if (text === "" || /^#[0-9a-fA-F]{6}$/.test(text))
                            SettingsManager.swapColor = text
                    }
                }
            }
        }
    }

}
