import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../components" as MyComponents

Kirigami.ScrollablePage {
    id: page
    objectName: "landingPage"
    title: UIStrings.ui.landing.title

    readonly property real customContentWidth: Math.max(Kirigami.Units.gridUnit * 10, Math.min(Kirigami.Units.gridUnit * 40, page.width - Kirigami.Units.gridUnit * 4))

    function formatSpeed(b) {
        if (b >= 1024 * 1024) return (b / (1024 * 1024)).toFixed(1) + " MiB/s"
        if (b >= 1024) return (b / 1024).toFixed(1) + " KiB/s"
        return b.toFixed(0) + " B/s"
    }

    titleDelegate: Item {}

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Kirigami.Units.largeSpacing
        spacing: Kirigami.Units.largeSpacing
        
        Item { Layout.preferredHeight: Kirigami.Units.gridUnit }

        // Top Icon
        Kirigami.Icon {
            Layout.alignment: Qt.AlignHCenter
            source: UIIcons.icons.app_main || ""
            Layout.preferredWidth: Kirigami.Units.iconSizes.huge * UIIcons.headerIconScale
            Layout.preferredHeight: Kirigami.Units.iconSizes.huge * UIIcons.headerIconScale
            isMask: UIIcons.shouldColorize("app_main")
            color: UIIcons.iconColor("app_main", "")
        }

        Item { Layout.preferredHeight: Kirigami.Units.largeSpacing }

        // 2×2 metric panel grid
        GridLayout {
            Layout.fillWidth: true
            columns: 2
            rowSpacing: Kirigami.Units.largeSpacing
            columnSpacing: Kirigami.Units.largeSpacing

            // CPU
            MyComponents.MetricPanel {
                Layout.fillWidth: true
                Layout.preferredHeight: 110
                title: UIStrings.ui.monitor.cpu
                currentText: (SystemHealth.cpuUsage * 100).toFixed(1) + "%"
                values: SystemHealth.cpuHistory
                autoScale: false
                accentColor: SettingsManager.cpuColor !== "" ? SettingsManager.cpuColor : Kirigami.Theme.highlightColor
            }

            // Memory
            MyComponents.MetricPanel {
                Layout.fillWidth: true
                Layout.preferredHeight: 110
                title: UIStrings.ui.monitor.memory
                currentText: SystemHealth.ramTotalStr
                values: SystemHealth.ramHistory
                autoScale: false
                accentColor: SettingsManager.memoryColor !== "" ? SettingsManager.memoryColor : Kirigami.Theme.highlightColor
            }

            // Download
            MyComponents.MetricPanel {
                Layout.fillWidth: true
                Layout.preferredHeight: 110
                title: "↓  " + UIStrings.ui.monitor.download
                currentText: page.formatSpeed(SystemHealth.netDownload)
                values: SystemHealth.netDownHistory
                autoScale: true
                accentColor: SettingsManager.downloadColor !== "" ? SettingsManager.downloadColor : Kirigami.Theme.highlightColor
            }

            // Upload
            MyComponents.MetricPanel {
                Layout.fillWidth: true
                Layout.preferredHeight: 110
                title: "↑  " + UIStrings.ui.monitor.upload
                currentText: page.formatSpeed(SystemHealth.netUpload)
                values: SystemHealth.netUpHistory
                autoScale: true
                accentColor: SettingsManager.uploadColor !== "" ? SettingsManager.uploadColor : Kirigami.Theme.highlightColor
            }
        }

        // ── Disk + Swap card ──────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: diskLayout.implicitHeight + Kirigami.Units.largeSpacing * 2
            color: UIColors.theme.description_background_hex
                ? UIColors.theme.description_background_hex
                : Qt.darker(Kirigami.Theme.backgroundColor, UIColors.theme.description_darker_multiplier)
            border.color: SettingsManager.enableContrastBorders ? (UIColors.theme.border_color_hex ? UIColors.theme.border_color_hex : Kirigami.Theme.highlightColor) : Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.5)
            border.width: 1
            radius: SettingsManager.cornerRadius / 2

            ColumnLayout {
                id: diskLayout
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    margins: Kirigami.Units.largeSpacing
                }
                spacing: Kirigami.Units.smallSpacing

                MyComponents.StorageOverviewBar {
                    Layout.fillWidth: true
                    
                    appsSize: SystemHealth.appsSize
                    mediaSize: SystemHealth.mediaSize
                    gamesSize: SystemHealth.gamesSize
                    downloadsSize: SystemHealth.downloadsSize
                    vmsSize: SystemHealth.vmsSize
                    trashCacheSize: SystemHealth.trashCacheSize
                    otherSize: SystemHealth.otherSize
                    totalUsedSize: SystemHealth.totalUsedSize
                    totalDiskSize: SystemHealth.totalDiskSize
                }

                // Swap section
                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: Kirigami.Units.smallSpacing
                    Label {
                        text: UIStrings.ui.monitor.swap
                        font.weight: Font.DemiBold
                        color: SettingsManager.emphasisColor !== "" ? SettingsManager.emphasisColor : Kirigami.Theme.highlightColor
                    }
                    Item { Layout.fillWidth: true }
                    Label {
                        text: SystemHealth.swapTotalStr
                        color: Kirigami.Theme.textColor
                        font.weight: Font.DemiBold
                    }
                }

                Rectangle {
                    id: swapFrame
                    Layout.fillWidth: true
                    Layout.preferredHeight: Kirigami.Units.gridUnit
                    radius: SettingsManager.cornerRadius
                    color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.1)
                    border.color: UIColors.theme.border_color_hex ? UIColors.theme.border_color_hex : Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.3)
                    border.width: 1

                    Kirigami.ShadowedRectangle {
                        height: parent.height
                        width: parent.width * SystemHealth.swapUsage
                        color: SettingsManager.swapColor !== "" ? SettingsManager.swapColor : Kirigami.Theme.highlightColor
                        visible: width > 0
                        corners.topLeftRadius: swapFrame.radius
                        corners.bottomLeftRadius: swapFrame.radius
                        corners.topRightRadius: swapFrame.radius
                        corners.bottomRightRadius: swapFrame.radius
                    }
                }
            }
        }
        
        Item { Layout.fillHeight: true }
    }
}
