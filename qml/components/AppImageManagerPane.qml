import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../components" as MyComponents
import "../Utils.js" as Utils

Rectangle {
    id: paneRoot
    color: UIColors.theme.queue_background_hex ? UIColors.theme.queue_background_hex : Qt.darker(Kirigami.Theme.backgroundColor, UIColors.theme.queue_darker_multiplier)
    border.color: SettingsManager.enableContrastBorders ? (UIColors.theme.border_color_hex ? UIColors.theme.border_color_hex : Kirigami.Theme.highlightColor) : Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.5)
    border.width: 1
    radius: SettingsManager.cornerRadius
    clip: true

    readonly property color effectiveHighlight: Kirigami.Theme.highlightColor

    property real idealWidth: Kirigami.Units.gridUnit * 22
    property string selectedAppImagePath: ""
    property string currentUpdateUrl: ""

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Kirigami.Units.largeSpacing
        spacing: Kirigami.Units.smallSpacing

        // ── Tab Bar ───────────────────────────────────────────────────────────
        TabBar {
            id: modeTabBar
            Layout.fillWidth: true
            background: Rectangle {
                color: Qt.darker(Kirigami.Theme.backgroundColor, 1.2)
                radius: Kirigami.Units.smallSpacing
            }

            TabButton {
                text: "Manage"
                contentItem: Label {
                    text: parent.text
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    color: parent.checked ? Kirigami.Theme.textColor : Kirigami.Theme.disabledTextColor
                    font.weight: parent.checked ? Font.Bold : Font.Normal
                }
                background: Rectangle {
                    color: parent.checked ? Qt.rgba(paneRoot.effectiveHighlight.r, paneRoot.effectiveHighlight.g, paneRoot.effectiveHighlight.b, 0.2) : "transparent"
                    radius: Kirigami.Units.smallSpacing
                }
            }

            TabButton {
                text: "Browse"
                contentItem: Label {
                    text: parent.text
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    color: parent.checked ? Kirigami.Theme.textColor : Kirigami.Theme.disabledTextColor
                    font.weight: parent.checked ? Font.Bold : Font.Normal
                }
                background: Rectangle {
                    color: parent.checked ? Qt.rgba(paneRoot.effectiveHighlight.r, paneRoot.effectiveHighlight.g, paneRoot.effectiveHighlight.b, 0.2) : "transparent"
                    radius: Kirigami.Units.smallSpacing
                }
            }
        }

        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: modeTabBar.currentIndex

            // ── Tab 0: Installed ─────────────────────────────────────────────
            ColumnLayout {
                spacing: Kirigami.Units.smallSpacing

                // ── Search and Sort ───────────────────────────────────────────
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing

                    Kirigami.SearchField {
                        id: appImageSearchField
                        Layout.fillWidth: true
                        placeholderText: "Search AppImages..."
                        onTextChanged: AppImageManager.searchQuery = text
                    }

                    Button {
                        id: appImgSortBtn
                        icon.name: "view-sort-ascending"
                        text: "Sort"
                        onClicked: appImgSortMenu.opened ? appImgSortMenu.close() : appImgSortMenu.open()

                        Menu {
                            id: appImgSortMenu
                            y: appImgSortBtn.height

                            ActionGroup { id: appImgSortGroup; exclusive: true }

                            RadioDelegate {
                                text: "Name (A \u2192 Z)"
                                checked: AppImageManager.sortOrder === "name_asc"
                                ActionGroup.group: appImgSortGroup
                                onClicked: { AppImageManager.set_sort_order("name_asc"); sortMenu.close() }
                            }
                            RadioDelegate {
                                text: "Name (Z \u2192 A)"
                                checked: AppImageManager.sortOrder === "name_desc"
                                ActionGroup.group: appImgSortGroup
                                onClicked: { AppImageManager.set_sort_order("name_desc"); sortMenu.close() }
                            }
                            MenuSeparator {}
                            RadioDelegate {
                                text: "Size (Small \u2192 Large)"
                                checked: AppImageManager.sortOrder === "size_asc"
                                ActionGroup.group: appImgSortGroup
                                onClicked: { AppImageManager.set_sort_order("size_asc"); sortMenu.close() }
                            }
                            RadioDelegate {
                                text: "Size (Large \u2192 Small)"
                                checked: AppImageManager.sortOrder === "size_desc"
                                ActionGroup.group: appImgSortGroup
                                onClicked: { AppImageManager.set_sort_order("size_desc"); sortMenu.close() }
                            }
                        }
                    }
                }

                ListView {
                    id: installedListView
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: AppImageManager.model
                    boundsBehavior: Flickable.StopAtBounds

                    ScrollBar.vertical: ScrollBar { id: installScroll; policy: ScrollBar.AsNeeded }

                    Kirigami.Separator {
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.right: parent.right
                        anchors.rightMargin: installScroll.implicitWidth
                        visible: installScroll.size < 1.0
                    }

                    delegate: ItemDelegate {
                        id: instDel
                        width: installedListView.width - (installScroll.size < 1.0 ? installScroll.width : 0)
                        
                        property bool expanded: hovered || ListView.isCurrentItem || model.isChecked

                        background: Rectangle {
                            color: model.isChecked 
                                ? Qt.rgba(paneRoot.effectiveHighlight.r, paneRoot.effectiveHighlight.g, paneRoot.effectiveHighlight.b, 0.2)
                                : instDel.hovered 
                                ? Qt.rgba(paneRoot.effectiveHighlight.r, paneRoot.effectiveHighlight.g, paneRoot.effectiveHighlight.b, 0.08)
                                : "transparent"
                        }

                        contentItem: ColumnLayout {
                            spacing: Kirigami.Units.smallSpacing

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Kirigami.Units.smallSpacing

                                CheckBox {
                                    checked: model.isChecked
                                    onCheckedChanged: {
                                        if (model.isChecked !== checked) {
                                            model.isChecked = checked
                                        }
                                    }
                                    Layout.alignment: Qt.AlignVCenter
                                }

                                Kirigami.Icon {
                                    source: model.iconPath && model.iconPath !== "" ? model.iconPath : "application-x-executable"
                                    Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                                    Layout.preferredHeight: Kirigami.Units.iconSizes.medium
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0

                                    Label {
                                        text: model.name || ""
                                        font.weight: model.isChecked ? Font.Bold : Font.Normal
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                    }
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: Kirigami.Units.smallSpacing

                                        Label {
                                            text: {
                                                let parts = [model.version || "Unknown"]
                                                if (model.updateUrl) {
                                                    let m = (model.updateUrl || "").match(/github\.com\/([^\/]+\/[^\/]+)/)
                                                    if (m) parts.push(m[1])
                                                }
                                                return parts.join("  ·  ")
                                            }
                                            color: Kirigami.Theme.neutralTextColor
                                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                                            Layout.fillWidth: true
                                            elide: Text.ElideMiddle
                                        }

                                        Label {
                                            text: Utils.formatBytes(model.size)
                                            visible: model.size > 0
                                            color: Kirigami.Theme.textColor
                                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                                        }
                                    }
                                }

                                RowLayout {
                                    spacing: Kirigami.Units.smallSpacing
                                    Layout.alignment: Qt.AlignVCenter | Qt.AlignRight

                                    ToolButton {
                                        Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                                        Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                                        onClicked: {
                                            paneRoot.selectedAppImagePath = model.path;
                                            paneRoot.currentUpdateUrl = model.updateUrl || "";
                                            urlDialog.urlFieldText = paneRoot.currentUpdateUrl;
                                            urlDialog.open();
                                        }
                                        ToolTip.text: (model.updateUrl && model.updateUrl !== "") ? "Edit Update URL" : "Set Update URL"
                                        ToolTip.visible: hovered
                                        ToolTip.delay: Kirigami.Units.toolTipDelay
                                        contentItem: Kirigami.Icon {
                                            source: (model.updateUrl && model.updateUrl !== "") ? (UIIcons.icons.url || "") : (UIIcons.icons.empty_url || "")
                                            isMask: true
                                            color: (model.updateUrl && model.updateUrl !== "") ? paneRoot.effectiveHighlight : Kirigami.Theme.disabledTextColor
                                        }
                                    }

                                    ToolButton {
                                        visible: true
                                        onClicked: AppImageManager.check_for_updates(model.path)
                                        ToolTip.text: "Check for Updates"
                                        ToolTip.visible: hovered
                                        ToolTip.delay: Kirigami.Units.toolTipDelay
                                        contentItem: Kirigami.Icon {
                                            source: UIIcons.icons.check_update || ""
                                            implicitWidth: Kirigami.Units.iconSizes.small
                                            implicitHeight: Kirigami.Units.iconSizes.small
                                            isMask: true
                                            color: Kirigami.Theme.textColor
                                        }
                                    }

                                    Kirigami.Icon {
                                        source: UIIcons.icons.package_update_available || "view-refresh" // Fallback if missing
                                        visible: model.updateUrl !== "" && model.updateStatus === "available"
                                        implicitWidth: Kirigami.Units.iconSizes.smallMedium
                                        implicitHeight: Kirigami.Units.iconSizes.smallMedium
                                        isMask: true
                                        color: Kirigami.Theme.positiveTextColor
                                        
                                        HoverHandler {
                                            id: updateAvailableHover
                                        }
                                        ToolTip.text: "Update Available"
                                        ToolTip.visible: updateAvailableHover.hovered
                                        ToolTip.delay: Kirigami.Units.toolTipDelay
                                    }
                                }
                            }

                            // Expanded Details (Release notes and version comparison)
                            ColumnLayout {
                                visible: instDel.expanded && (model.latestVersion !== "" || model.releaseNotes !== "")
                                Layout.fillWidth: true
                                Layout.leftMargin: Kirigami.Units.largeSpacing * 2
                                Layout.rightMargin: Kirigami.Units.largeSpacing
                                spacing: Kirigami.Units.smallSpacing

                                Kirigami.Separator { Layout.fillWidth: true; opacity: 0.3 }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: Kirigami.Units.largeSpacing
                                    Label { text: "Current: " + (model.version || "Unknown"); font.pointSize: Kirigami.Theme.smallFont.pointSize; color: Kirigami.Theme.neutralTextColor }
                                    Label { 
                                        text: "Latest: " + (model.latestVersion || "Unknown")
                                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                                        color: model.updateStatus === "available" ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.neutralTextColor
                                        font.weight: model.updateStatus === "available" ? Font.Bold : Font.Normal
                                    }
                                    Item { Layout.fillWidth: true }
                                }

                                Label {
                                    visible: model.releaseNotes && model.releaseNotes !== ""
                                    text: model.releaseNotes || ""
                                    wrapMode: Text.Wrap
                                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                                    color: Qt.darker(Kirigami.Theme.textColor, 1.2)
                                    maximumLineCount: 3
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }
                        }

                        onClicked: {
                            model.isChecked = !model.isChecked
                        }
                    }
                } // Installed List

                // ── Installed Actions ──────────────────────────────────────────
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing

                    Button {
                        Layout.fillWidth: true
                        visible: AppImageManager.checkedCount === 0
                        enabled: !AppImageManager.isChecking && !AppImageManager.isDownloading
                        contentItem: Item {
                            implicitWidth: row1.implicitWidth
                            implicitHeight: row1.implicitHeight
                            Row {
                                id: row1
                                anchors.centerIn: parent
                                spacing: Kirigami.Units.smallSpacing
                                Kirigami.Icon {
                                    source: UIIcons.icons.check_update || ""
                                    width: Kirigami.Units.iconSizes.smallMedium
                                    height: Kirigami.Units.iconSizes.smallMedium
                                    anchors.verticalCenter: parent.verticalCenter
                                    isMask: UIIcons.shouldColorize("check_update")
                                    color: UIIcons.iconColor("check_update", parent.enabled ? paneRoot.effectiveHighlight : Kirigami.Theme.disabledTextColor)
                                }
                                Label {
                                    text: AppImageManager.isChecking ? "Checking all…" : "Check All Updates"
                                    color: parent.enabled ? paneRoot.effectiveHighlight : Kirigami.Theme.disabledTextColor
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }
                        background: Rectangle {
                            color: parent.down ? Qt.rgba(paneRoot.effectiveHighlight.r, paneRoot.effectiveHighlight.g, paneRoot.effectiveHighlight.b, 0.2)
                                               : parent.hovered ? Qt.rgba(paneRoot.effectiveHighlight.r, paneRoot.effectiveHighlight.g, paneRoot.effectiveHighlight.b, 0.1) : "transparent"
                            border.color: paneRoot.effectiveHighlight; border.width: 1; radius: Kirigami.Units.smallSpacing
                        }
                        onClicked: AppImageManager.check_all_updates()
                    }

                    Button {
                        Layout.fillWidth: true
                        visible: AppImageManager.checkedUpdateCount > 0
                        enabled: !AppImageManager.isDownloading && !AppImageManager.isChecking
                        contentItem: Item {
                            implicitWidth: row2.implicitWidth
                            implicitHeight: row2.implicitHeight
                            Row {
                                id: row2
                                anchors.centerIn: parent
                                spacing: Kirigami.Units.smallSpacing
                                Kirigami.Icon {
                                    source: UIIcons.icons.download || ""
                                    width: Kirigami.Units.iconSizes.smallMedium
                                    height: Kirigami.Units.iconSizes.smallMedium
                                    anchors.verticalCenter: parent.verticalCenter
                                    isMask: UIIcons.shouldColorize("download")
                                    color: UIIcons.iconColor("download", parent.enabled ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.disabledTextColor)
                                }
                                Label {
                                    text: AppImageManager.isDownloading ? "Downloading…" : "Download Updates (" + AppImageManager.checkedUpdateCount + ")"
                                    color: parent.enabled ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.disabledTextColor
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }
                        background: Rectangle {
                            color: parent.down ? Qt.rgba(Kirigami.Theme.positiveTextColor.r, Kirigami.Theme.positiveTextColor.g, Kirigami.Theme.positiveTextColor.b, 0.2)
                                               : parent.hovered ? Qt.rgba(Kirigami.Theme.positiveTextColor.r, Kirigami.Theme.positiveTextColor.g, Kirigami.Theme.positiveTextColor.b, 0.1) : "transparent"
                            border.color: Kirigami.Theme.positiveTextColor; border.width: 1; radius: Kirigami.Units.smallSpacing
                        }
                        onClicked: AppImageManager.download_checked()
                    }

                    Button {
                        Layout.fillWidth: true
                        visible: AppImageManager.checkedCount > 0 && AppImageManager.checkedUpdateCount === 0
                        enabled: !AppImageManager.isDownloading && !AppImageManager.isChecking
                        contentItem: Item {
                            implicitWidth: row3.implicitWidth
                            implicitHeight: row3.implicitHeight
                            Row {
                                id: row3
                                anchors.centerIn: parent
                                spacing: Kirigami.Units.smallSpacing
                                Kirigami.Icon {
                                    source: UIIcons.icons.delete || ""
                                    width: Kirigami.Units.iconSizes.smallMedium
                                    height: Kirigami.Units.iconSizes.smallMedium
                                    anchors.verticalCenter: parent.verticalCenter
                                    isMask: true
                                    color: UIIcons.iconColor("delete", parent.enabled ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.disabledTextColor)
                                }
                                Label {
                                    text: "Remove Selected (" + AppImageManager.checkedCount + ")"
                                    color: parent.enabled ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.disabledTextColor
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }
                        background: Rectangle {
                            color: parent.down ? Qt.rgba(Kirigami.Theme.negativeTextColor.r, Kirigami.Theme.negativeTextColor.g, Kirigami.Theme.negativeTextColor.b, 0.2)
                                               : parent.hovered ? Qt.rgba(Kirigami.Theme.negativeTextColor.r, Kirigami.Theme.negativeTextColor.g, Kirigami.Theme.negativeTextColor.b, 0.1) : "transparent"
                            border.color: Kirigami.Theme.negativeTextColor; border.width: 1; radius: Kirigami.Units.smallSpacing
                        }
                        onClicked: AppImageManager.delete_checked()
                    }
                }
            } // End Tab 0

            // ── Tab 1: Browse ────────────────────────────────────────────────
            ColumnLayout {
                spacing: 0

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: Kirigami.Units.largeSpacing
                    Layout.leftMargin: Kirigami.Units.largeSpacing
                    Layout.rightMargin: Kirigami.Units.smallSpacing
                    spacing: Kirigami.Units.smallSpacing

                    Kirigami.SearchField {
                        id: hubSearchField
                        Layout.fillWidth: true
                        placeholderText: "Search apps…"
                        onTextChanged: hubSearchTimer.restart()
                    }

                    ToolButton {
                        icon.name: "view-refresh"
                        enabled: !AppImageHub.isLoading
                        onClicked: AppImageHub.refresh()
                    }

                    Timer {
                        id: hubSearchTimer
                        interval: 300
                        onTriggered: AppImageHub.setSearch(hubSearchField.text)
                    }
                }

                Kirigami.InlineMessage {
                    Layout.fillWidth: true
                    Layout.margins: Kirigami.Units.largeSpacing
                    type: Kirigami.MessageType.Error
                    text: AppImageHub.error
                    visible: AppImageHub.error !== ""
                }

                Item {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    visible: AppImageHub.isLoading && hubListView.count === 0
                    Kirigami.PlaceholderMessage { anchors.centerIn: parent; width: parent.width * 0.8; icon.name: "internet-services"; text: "Loading AppImageHub…" }
                }

                Item {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    visible: !AppImageHub.isLoading && hubListView.count === 0 && AppImageHub.error === ""
                    Kirigami.PlaceholderMessage { anchors.centerIn: parent; width: parent.width * 0.8; icon.name: "edit-find"; text: hubSearchField.text !== "" ? "No apps found" : "No apps available" }
                }

                ListView {
                    id: hubListView
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.topMargin: Kirigami.Units.smallSpacing
                    visible: hubListView.count > 0
                    model: AppImageHub.model
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    ScrollBar.vertical: ScrollBar { id: hubScrollBar; policy: ScrollBar.AsNeeded }

                    Kirigami.Separator {
                        anchors.top: parent.top; anchors.bottom: parent.bottom; anchors.right: parent.right
                        anchors.rightMargin: hubScrollBar.implicitWidth
                        visible: hubScrollBar.size < 1.0
                    }

                    delegate: ItemDelegate {
                        id: delegateRoot
                        width: hubListView.width - (hubScrollBar.size < 1.0 ? hubScrollBar.width : 0)
                        leftPadding: Kirigami.Units.largeSpacing
                        rightPadding: Kirigami.Units.largeSpacing
                        topPadding: Kirigami.Units.largeSpacing
                        bottomPadding: Kirigami.Units.largeSpacing

                        background: Rectangle {
                            color: delegateRoot.hovered 
                                ? Qt.rgba(paneRoot.effectiveHighlight.r, paneRoot.effectiveHighlight.g, paneRoot.effectiveHighlight.b, 0.08)
                                : "transparent"
                        }

                        property string appName: model.name || ""
                        property string appDesc: model.description || ""
                        property string appIconUrl: model.iconUrl || ""
                        property string githubAvatarUrl: model.githubAvatarUrl || ""
                        property string appOwnerRepo: model.ownerRepo || ""
                        property var appCategories: model.categories || []

                        property bool isThisInstalling: AppImageManager.hubInstallApp === appName && AppImageManager.hubInstallStatus === "downloading"
                        property bool isThisChecking: AppImageManager.hubInstallApp === appName && AppImageManager.hubInstallStatus === "checking"
                        property bool isInstalled: {
                            let repos = AppImageManager.installedOwnerRepos
                            return repos.indexOf(appOwnerRepo.toLowerCase()) !== -1
                        }
                        property bool expanded: hovered || ListView.isCurrentItem

                        contentItem: RowLayout {
                            spacing: Kirigami.Units.largeSpacing

                            Item {
                                Layout.preferredWidth: Kirigami.Units.iconSizes.large
                                Layout.preferredHeight: Kirigami.Units.iconSizes.large
                                Image {
                                    id: hubAppIcon
                                    anchors.fill: parent
                                    source: delegateRoot.appIconUrl
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true; asynchronous: true
                                    onStatusChanged: {
                                        if (status === Image.Error && delegateRoot.githubAvatarUrl !== "") {
                                            source = delegateRoot.githubAvatarUrl
                                        }
                                    }
                                }
                                Kirigami.Icon { 
                                    anchors.fill: parent; 
                                    source: "application-x-executable"; 
                                    visible: hubAppIcon.status !== Image.Ready && hubAppIcon.status !== Image.Loading 
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                Label { text: delegateRoot.appName; font.weight: Font.DemiBold; Layout.fillWidth: true; elide: Text.ElideRight }
                                Label {
                                    text: delegateRoot.expanded ? delegateRoot.appDesc : delegateRoot.appDesc.replace(/\n/g, " ")
                                    color: Kirigami.Theme.neutralTextColor
                                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                                    Layout.fillWidth: true
                                    wrapMode: delegateRoot.expanded ? Text.WordWrap : Text.WrapAnywhere
                                    maximumLineCount: delegateRoot.expanded ? 0 : 1
                                    elide: delegateRoot.expanded ? Text.ElideNone : Text.ElideRight
                                    visible: delegateRoot.appDesc !== ""
                                    clip: true
                                }
                                Label {
                                    text: delegateRoot.appCategories.join("  ·  ")
                                    color: Kirigami.Theme.disabledTextColor
                                    font.pointSize: Kirigami.Theme.smallFont.pointSize - 1
                                    Layout.fillWidth: true; elide: Text.ElideRight
                                    visible: delegateRoot.appCategories.length > 0; clip: true
                                }
                            }

                            Button {
                                Layout.alignment: Qt.AlignVCenter
                                Layout.minimumWidth: Kirigami.Units.gridUnit * 5.5
                                contentItem: Item {
                                    implicitWidth: row4.implicitWidth
                                    implicitHeight: row4.implicitHeight
                                    Row {
                                        id: row4
                                        anchors.centerIn: parent
                                        spacing: Kirigami.Units.smallSpacing
                                        Kirigami.Icon {
                                            source: delegateRoot.isInstalled ? (UIIcons.icons.success || "") : (UIIcons.icons.download || "")
                                            width: Kirigami.Units.iconSizes.smallMedium
                                            height: Kirigami.Units.iconSizes.smallMedium
                                            anchors.verticalCenter: parent.verticalCenter
                                            isMask: delegateRoot.isInstalled ? UIIcons.shouldColorize("success") : UIIcons.shouldColorize("download")
                                            color: UIIcons.iconColor(delegateRoot.isInstalled ? "success" : "download", parent.enabled ? Kirigami.Theme.textColor : Kirigami.Theme.disabledTextColor)
                                        }
                                        Label {
                                            text: delegateRoot.isInstalled ? "Installed" : (delegateRoot.isThisChecking || delegateRoot.isThisInstalling) ? "Installing…" : "Install"
                                            color: parent.enabled ? Kirigami.Theme.textColor : Kirigami.Theme.disabledTextColor
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }
                                }
                                onClicked: AppImageManager.install_from_hub(delegateRoot.appOwnerRepo, delegateRoot.appName)
                            }
                        }
                    }
                }
            } // End Tab 1
        }
    }

    // ── Dialogs ────────────────────────────────────────────────────────────
    Kirigami.PromptDialog {
        id: urlDialog
        title: "Set Update URL"
        standardButtons: Kirigami.PromptDialog.Ok | Kirigami.PromptDialog.Cancel
        
        property alias urlFieldText: urlField.text
        
        ColumnLayout {
            spacing: Kirigami.Units.smallSpacing
            Label { 
                text: "Enter GitHub Repo URL for " + (paneRoot.selectedAppImagePath ? paneRoot.selectedAppImagePath.split('/').pop() : "AppImage") + ":"
                wrapMode: Text.WordWrap 
                Layout.fillWidth: true
            }
            TextField {
                id: urlField
                Layout.fillWidth: true
                placeholderText: "https://github.com/owner/repository"
            }
        }
        onAccepted: AppImageManager.set_update_url(paneRoot.selectedAppImagePath, urlField.text)
    }
}
