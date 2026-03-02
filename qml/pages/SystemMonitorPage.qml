import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../components" as MyComponents

Kirigami.Page {
    id: page
    objectName: "systemMonitorPage"
    background: null
    title: UIStrings.ui.monitor.title

    titleDelegate: Item {}
    padding: 0
    topPadding: 0
    bottomPadding: 0
    leftPadding: 0
    rightPadding: 0

    function formatSpeed(b) {
        if (b >= 1024 * 1024) return (b / (1024 * 1024)).toFixed(1) + " MiB/s"
        if (b >= 1024) return (b / 1024).toFixed(1) + " KiB/s"
        return b.toFixed(0) + " B/s"
    }

    function sortIndicator(col) {
        if (SystemHealth.sortColumn !== col) return ""
        return SystemHealth.sortAscending ? " ▲" : " ▼"
    }

    function headerColor(col) {
        return SystemHealth.sortColumn === col
            ? Kirigami.Theme.highlightColor
            : (UIColors.theme.neutral_text_hex || Kirigami.Theme.neutralTextColor)
    }

    Rectangle {
        anchors.fill: parent
        color: UIColors.theme.queue_background_hex
            ? UIColors.theme.queue_background_hex
            : Qt.darker(Kirigami.Theme.backgroundColor, UIColors.theme.queue_darker_multiplier)
        border.color: UIColors.theme.border_color_hex
            ? UIColors.theme.border_color_hex
            : Kirigami.Theme.highlightColor
        border.width: 1
        radius: SettingsManager.cornerRadius
        clip: true

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.smallSpacing

        // ── Tab bar ────────────────────────────────────────────────────────
        TabBar {
            id: tabBar
            Layout.fillWidth: true
            Layout.bottomMargin: Kirigami.Units.smallSpacing

            background: Rectangle {
                color: Qt.darker(Kirigami.Theme.backgroundColor, 1.2)
                radius: Kirigami.Units.smallSpacing
            }

            MyComponents.StyledTabButton { 
                text: UIStrings.ui.monitor.overview
                Layout.fillWidth: true
            }
            MyComponents.StyledTabButton { 
                text: UIStrings.ui.monitor.processes
                Layout.fillWidth: true
            }
        }

        // ── Content ────────────────────────────────────────────────────────
        StackLayout {
            id: stack
            currentIndex: tabBar.currentIndex
            Layout.fillWidth: true
            Layout.fillHeight: true

            // ── Tab 0: Overview ───────────────────────────────────────────
            Item {
                ColumnLayout {
                    anchors.fill: parent
                    spacing: Kirigami.Units.largeSpacing

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
                            accentColor: Kirigami.Theme.highlightColor
                        }

                        // Memory
                        MyComponents.MetricPanel {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 110
                            title: UIStrings.ui.monitor.memory
                            currentText: SystemHealth.ramTotalStr
                            values: SystemHealth.ramHistory
                            autoScale: false
                            accentColor: Kirigami.Theme.positiveTextColor
                        }

                        // Download
                        MyComponents.MetricPanel {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 110
                            title: "↓  " + UIStrings.ui.monitor.download
                            currentText: page.formatSpeed(SystemHealth.netDownload)
                            values: SystemHealth.netDownHistory
                            autoScale: true
                            accentColor: Kirigami.Theme.positiveTextColor
                        }

                        // Upload
                        MyComponents.MetricPanel {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 110
                            title: "↑  " + UIStrings.ui.monitor.upload
                            currentText: page.formatSpeed(SystemHealth.netUpload)
                            values: SystemHealth.netUpHistory
                            autoScale: true
                            accentColor: Kirigami.Theme.neutralTextColor
                        }
                    }

                    // ── Disk + Swap card ──────────────────────────────────
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: diskLayout.implicitHeight + Kirigami.Units.largeSpacing * 2
                        color: UIColors.theme.description_background_hex
                            ? UIColors.theme.description_background_hex
                            : Qt.darker(Kirigami.Theme.backgroundColor, UIColors.theme.description_darker_multiplier)
                        border.color: UIColors.theme.border_color_hex
                            ? UIColors.theme.border_color_hex
                            : Kirigami.Theme.highlightColor
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
                                    color: UIColors.theme.neutral_text_hex || Kirigami.Theme.neutralTextColor
                                }
                                Item { Layout.fillWidth: true }
                                Label {
                                    text: SystemHealth.swapTotalStr
                                    color: Kirigami.Theme.neutralTextColor
                                    font.weight: Font.DemiBold
                                }
                            }

                            ProgressBar {
                                Layout.fillWidth: true
                                value: SystemHealth.swapUsage

                                background: Rectangle {
                                    implicitHeight: Kirigami.Units.mediumSpacing
                                    color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.1)
                                    radius: Kirigami.Units.smallSpacing
                                }
                                contentItem: Item {
                                    implicitHeight: Kirigami.Units.mediumSpacing
                                    Rectangle {
                                        width: parent.parent.visualPosition * parent.width
                                        height: parent.height
                                        radius: Kirigami.Units.smallSpacing
                                        color: Kirigami.Theme.neutralTextColor
                                    }
                                }
                            }

                            // IPv4
                            RowLayout {
                                Layout.fillWidth: true
                                Layout.topMargin: Kirigami.Units.smallSpacing
                                Label {
                                    text: UIStrings.ui.monitor.ipv4
                                    color: UIColors.theme.neutral_text_hex || Kirigami.Theme.neutralTextColor
                                }
                                Item { Layout.fillWidth: true }
                                Label {
                                    text: SystemHealth.ipv4Address
                                    color: Kirigami.Theme.highlightColor
                                }
                            }
                        }
                    }
                }
            }

            // ── Tab 1: Processes ──────────────────────────────────────────
            Item {
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Kirigami.Units.largeSpacing
                    spacing: 0

                    // Header
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.bottomMargin: Kirigami.Units.smallSpacing

                        Kirigami.Heading {
                            text: UIStrings.ui.monitor.processes
                            level: 3
                            Layout.alignment: Qt.AlignVCenter
                        }

                        Item { Layout.fillWidth: true }

                        TextField {
                            id: processSearchField
                            placeholderText: "Search processes..."
                            Layout.preferredWidth: 250
                            Layout.alignment: Qt.AlignVCenter
                            text: SystemHealth.searchQuery
                            onTextChanged: SystemHealth.searchQuery = text

                            rightPadding: clearButton.width + Kirigami.Units.smallSpacing
                            ToolButton {
                                id: clearButton
                                icon.name: "edit-clear"
                                visible: processSearchField.text.length > 0
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                onClicked: processSearchField.text = ""
                            }
                        }
                    }

                    Kirigami.Separator { Layout.fillWidth: true; opacity: 0.5 }

                    // Column headers (clickable for sort)
                    RowLayout {
                        id: listHeader
                        Layout.fillWidth: true
                        Layout.leftMargin: Kirigami.Units.largeSpacing
                        Layout.rightMargin: Kirigami.Units.largeSpacing
                        Layout.topMargin: Kirigami.Units.smallSpacing
                        Layout.bottomMargin: Kirigami.Units.smallSpacing

                        Label {
                            text: "PID" + page.sortIndicator("pid")
                            font.weight: Font.DemiBold
                            color: page.headerColor("pid")
                            Layout.preferredWidth: listHeader.width * 0.1
                            horizontalAlignment: Text.AlignHCenter
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: SystemHealth.toggleSort("pid")
                            }
                        }
                        Label {
                            text: UIStrings.ui.monitor.name + page.sortIndicator("name")
                            font.weight: Font.DemiBold
                            color: page.headerColor("name")
                            Layout.preferredWidth: listHeader.width * 0.25
                            horizontalAlignment: Text.AlignHCenter
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: SystemHealth.toggleSort("name")
                            }
                        }
                        Label {
                            text: "User" + page.sortIndicator("user")
                            font.weight: Font.DemiBold
                            color: page.headerColor("user")
                            Layout.preferredWidth: listHeader.width * 0.15
                            horizontalAlignment: Text.AlignHCenter
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: SystemHealth.toggleSort("user")
                            }
                        }
                        Label {
                            text: UIStrings.ui.monitor.cpu + page.sortIndicator("cpu")
                            font.weight: Font.DemiBold
                            color: page.headerColor("cpu")
                            Layout.preferredWidth: listHeader.width * 0.15
                            horizontalAlignment: Text.AlignHCenter
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: SystemHealth.toggleSort("cpu")
                            }
                        }
                        Label {
                            text: UIStrings.ui.monitor.memory + page.sortIndicator("memory")
                            font.weight: Font.DemiBold
                            color: page.headerColor("memory")
                            Layout.preferredWidth: listHeader.width * 0.2
                            horizontalAlignment: Text.AlignHCenter
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: SystemHealth.toggleSort("memory")
                            }
                        }
                        Item { Layout.fillWidth: true }
                    }

                    Kirigami.Separator { Layout.fillWidth: true; opacity: 0.5 }

                    // Process list
                    ListView {
                        id: appList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        currentIndex: -1
                        model: SystemHealth.applications
                        boundsBehavior: Flickable.StopAtBounds
                        ScrollBar.vertical: ScrollBar {
                            policy: ScrollBar.AlwaysOn
                        }

                        delegate: ItemDelegate {
                            width: appList.width
                            height: implicitHeight
                            onClicked: appList.currentIndex = index

                            background: Rectangle {
                                color: parent.highlighted
                                    ? Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b, 0.2)
                                    : parent.hovered
                                        ? Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b, 0.1)
                                        : "transparent"
                            }

                            contentItem: ColumnLayout {
                                spacing: 0
                                RowLayout {
                                    Layout.fillWidth: true
                                    Layout.leftMargin: Kirigami.Units.largeSpacing
                                    Layout.rightMargin: Kirigami.Units.largeSpacing
                                    Layout.topMargin: Kirigami.Units.smallSpacing
                                    Layout.bottomMargin: Kirigami.Units.smallSpacing
                                    spacing: 0

                                    Label {
                                        text: model.pid
                                        Layout.preferredWidth: appList.width * 0.1
                                        color: UIColors.theme.neutral_text_hex || Kirigami.Theme.neutralTextColor
                                        horizontalAlignment: Text.AlignHCenter
                                    }
                                    Label {
                                        text: model.name
                                        elide: Text.ElideRight
                                        Layout.preferredWidth: appList.width * 0.25
                                        font.weight: Font.DemiBold
                                        color: UIColors.theme.text_color_hex || Kirigami.Theme.textColor
                                        horizontalAlignment: Text.AlignHCenter
                                    }
                                    Label {
                                        text: model.user
                                        elide: Text.ElideRight
                                        Layout.preferredWidth: appList.width * 0.15
                                        color: UIColors.theme.neutral_text_hex || Kirigami.Theme.neutralTextColor
                                        horizontalAlignment: Text.AlignHCenter
                                    }
                                    Label {
                                        text: model.cpu
                                        Layout.preferredWidth: appList.width * 0.15
                                        color: {
                                            let v = parseFloat(model.cpu)
                                            if (v >= 50) return Kirigami.Theme.negativeTextColor
                                            if (v >= 20) return Kirigami.Theme.neutralTextColor
                                            return UIColors.theme.text_color_hex || Kirigami.Theme.textColor
                                        }
                                        horizontalAlignment: Text.AlignHCenter
                                    }
                                    Label {
                                        text: model.memory
                                        Layout.preferredWidth: appList.width * 0.2
                                        color: UIColors.theme.text_color_hex || Kirigami.Theme.textColor
                                        horizontalAlignment: Text.AlignHCenter
                                    }

                                    Item { Layout.fillWidth: true }

                                    RowLayout {
                                        Layout.alignment: Qt.AlignVCenter
                                        spacing: Kirigami.Units.smallSpacing

                                        ToolButton {
                                            implicitWidth: Kirigami.Units.gridUnit * 2
                                            implicitHeight: Kirigami.Units.gridUnit * 2
                                            visible: model.exe !== ""
                                            onClicked: SystemHealth.open_file_location(model.pid)
                                            ToolTip.text: "Open Folder Location"
                                            ToolTip.visible: hovered
                                            contentItem: Kirigami.Icon {
                                                source: UIIcons.icons.ssd || ""
                                                implicitWidth: Kirigami.Units.iconSizes.small
                                                implicitHeight: Kirigami.Units.iconSizes.small
                                                isMask: true
                                                color: {
                                                    let c = UIIcons.iconColor("ssd", "")
                                                    if (c === "#ffffff") return "#ffffff"
                                                    return c || Kirigami.Theme.highlightColor
                                                }
                                            }
                                        }

                                        ToolButton {
                                            implicitWidth: Kirigami.Units.gridUnit * 2
                                            implicitHeight: Kirigami.Units.gridUnit * 2
                                            onClicked: SystemHealth.kill_process(model.pid)
                                            ToolTip.text: "Kill Process"
                                            ToolTip.visible: hovered
                                            contentItem: Kirigami.Icon {
                                                source: UIIcons.icons.kill || ""
                                                implicitWidth: Kirigami.Units.iconSizes.small
                                                implicitHeight: Kirigami.Units.iconSizes.small
                                                isMask: true
                                                color: {
                                                    let c = UIIcons.iconColor("kill", "")
                                                    if (c === "#ffffff") return "#ffffff"
                                                    return c || Kirigami.Theme.highlightColor
                                                }
                                            }
                                        }
                                    }
                                }
                                Kirigami.Separator {
                                    Layout.fillWidth: true
                                    opacity: 0.2
                                }
                            }
                        }
                    }
                }
            }
        }
        } // ColumnLayout
    } // Rectangle
}
