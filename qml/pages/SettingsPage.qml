import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Kirigami.ScrollablePage {
    id: page
    objectName: "settingsPage"
    background: null
    title: UIStrings.ui.settings.title

    titleDelegate: Item {}

    ColumnLayout {
        width: page.width
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

            SpinBox {
                Kirigami.FormData.label: "Corner Radius"
                from: 0
                to: 24
                value: SettingsManager.cornerRadius
                onValueChanged: SettingsManager.cornerRadius = value
            }

            Switch {
                Kirigami.FormData.label: UIStrings.ui.settings.label_developer_mode
                checked: SettingsManager.developerMode
                onCheckedChanged: SettingsManager.developerMode = checked
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

            Button {
                Kirigami.FormData.label: "Favorite Tasks"
                text: "Select Favorites..."
                onClicked: favoriteTasksSheet.open()
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
                model: ["pacman", "paru", "yay"]
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

            Switch {
                Kirigami.FormData.label: "Confirm Package Removal"
                checked: SettingsManager.confirmPackageRemoval
                onCheckedChanged: SettingsManager.confirmPackageRemoval = checked
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

            // --- SECTION: Clean System Files ---
            Label {
                Kirigami.FormData.isSection: true
                text: "Clean System Files"
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

            // --- SECTION: Custom Scripts ---
            Label {
                Kirigami.FormData.isSection: true
                text: "Custom Scripts"
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
                Kirigami.FormData.label: UIStrings.ui.settings.label_scripts_dir
                Layout.fillWidth: true
                text: SettingsManager.scriptsDir
                placeholderText: UIStrings.ui.settings.placeholder_scripts_dir
                onEditingFinished: SettingsManager.scriptsDir = text
            }
        }
    }

    Kirigami.OverlaySheet {
        id: favoriteTasksSheet
        title: UIStrings.ui.settings.favorite_tasks_title
        
        ListView {
            id: favList
            implicitWidth: Kirigami.Units.gridUnit * 25
            implicitHeight: Kirigami.Units.gridUnit * 20
            clip: true
            model: TaskRegistry.allowedFavoriteTaskNames
            
            delegate: CheckDelegate {
                width: favList.width
                text: modelData
                checked: {
                    var favs = SettingsManager.favoriteTasks
                    if (!favs || typeof favs === "undefined") return false
                    for (var i = 0; i < favs.length; i++) {
                        if (String(favs[i]) === String(modelData)) return true
                    }
                    return false
                }
                onToggled: {
                    var arr = []
                    var currentFavs = SettingsManager.favoriteTasks
                    if (currentFavs) {
                        for (var i = 0; i < currentFavs.length; i++) {
                            arr.push(String(currentFavs[i]))
                        }
                    }
                    
                    var taskName = String(modelData)
                    var idx = arr.indexOf(taskName)
                    if (checked && idx === -1) {
                        arr.push(taskName)
                    } else if (!checked && idx !== -1) {
                        arr.splice(idx, 1)
                    }
                    SettingsManager.favoriteTasks = arr
                }
            }
            
            ScrollBar.vertical: ScrollBar {}
        }
    }
}
