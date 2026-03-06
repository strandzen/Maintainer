import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../Utils.js" as Utils

Rectangle {
    id: paneRoot
    color: UIColors.theme.queue_background_hex ? UIColors.theme.queue_background_hex : Qt.darker(Kirigami.Theme.backgroundColor, UIColors.theme.queue_darker_multiplier)
    border.color: SettingsManager.enableContrastBorders ? (UIColors.theme.border_color_hex ? UIColors.theme.border_color_hex : Kirigami.Theme.highlightColor) : Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.5)
    border.width: 1
    radius: SettingsManager.cornerRadius
    clip: true

    property real idealWidth: Kirigami.Units.gridUnit * 22

    // Multi-selection management
    property var selectedNames: ({}) // Using an object as a Set for efficiency
    property int selectedCount: Object.keys(selectedNames).length

    onSelectedNamesChanged: {
        PackageManager.selectedPackages = Object.keys(selectedNames)
    }

    function isSelected(name) { return selectedNames[name] === true }
    function toggleSelection(name) {
        let n = Object.assign({}, selectedNames)
        if (n[name]) delete n[name]
        else n[name] = true
        selectedNames = n
    }
    function clearSelection() { selectedNames = {} }

    // Dependencies preview state
    property var pendingDeps: []
    property string totalRemovedSize: ""
    property bool confirmChecked: false
    property real depsAreaHeight: Kirigami.Units.gridUnit * 5

    onSelectedCountChanged: {
        paneRoot.confirmChecked = false
        depsDebounce.restart()
    }

    Connections {
        target: PackageManager

        function onPackagesChanged() {
            paneRoot.clearSelection()
            paneRoot.confirmChecked = false
        }

        function onDepsReady(deps, size) {
            paneRoot.pendingDeps = deps
            paneRoot.totalRemovedSize = size
        }

        function onRemovalDone(success) {
            paneRoot.confirmChecked = false
            if (success) {
                closeTimer.start()
            }
        }
    }

    // Auto-close overlay 2 s after a successful removal
    Timer {
        id: closeTimer
        interval: 2000
        onTriggered: confirmRemovalSheet.close()
    }

    // Re-run the dep check 400 ms after the selection stabilises
    Timer {
        id: depsDebounce
        interval: 400
        onTriggered: {
            if (paneRoot.selectedCount > 0) {
                PackageManager.get_remove_deps(Object.keys(paneRoot.selectedNames))
            } else {
                paneRoot.pendingDeps = []
                paneRoot.totalRemovedSize = ""
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Kirigami.Units.largeSpacing
        spacing: Kirigami.Units.smallSpacing

        // ── Title ─────────────────────────────────────────────────────────────
        Kirigami.Heading {
            text: "Package Manager"
            level: 2
            font.pointSize: UIFonts.fonts.headline
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            visible: false // Removed headline as requested
        }

        // ── Mode Toggle ───────────────────────────────────────────────────────
        TabBar {
            id: modeTabBar
            Layout.fillWidth: true
            currentIndex: PackageManager.mode === "installed" ? 0 : 1
            
            background: Rectangle {
                color: Qt.darker(Kirigami.Theme.backgroundColor, 1.2)
                radius: Kirigami.Units.smallSpacing
            }

            onCurrentIndexChanged: {
                if (currentIndex === 0) {
                    PackageManager.mode = "installed"
                } else {
                    PackageManager.mode = "browse"
                }
                paneRoot.clearSelection()
            }

            TabButton {
                text: "Manage"
                Layout.fillWidth: true
                contentItem: Label {
                    text: parent.text
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    color: parent.checked ? Kirigami.Theme.textColor : Kirigami.Theme.disabledTextColor
                    font.weight: parent.checked ? Font.Bold : Font.Normal
                }
                background: Rectangle {
                    color: parent.checked ? Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b, 0.2) : "transparent"
                    radius: Kirigami.Units.smallSpacing
                }
            }
            TabButton {
                text: "Browse"
                Layout.fillWidth: true
                contentItem: Label {
                    text: parent.text
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    color: parent.checked ? Kirigami.Theme.textColor : Kirigami.Theme.disabledTextColor
                    font.weight: parent.checked ? Font.Bold : Font.Normal
                }
                background: Rectangle {
                    color: parent.checked ? Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b, 0.2) : "transparent"
                    radius: Kirigami.Units.smallSpacing
                }
            }
        }

        // ── Search and Filters ───────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            Kirigami.SearchField {
                id: searchField
                Layout.fillWidth: true
                placeholderText: "Search packages..."
                onTextChanged: PackageManager.searchQuery = text
            }

            Button {
                id: filterBtn
                icon.name: "view-filter"
                text: "Filters"
                onClicked: filterMenu.opened ? filterMenu.close() : filterMenu.open()

                Menu {
                    id: filterMenu
                    y: filterBtn.height

                    MenuItem {
                        text: "Hide Dependencies"
                        checkable: true
                        checked: PackageManager.showExplicitOnly
                        onToggled: PackageManager.set_show_explicit_only(checked)
                    }
                    MenuItem {
                        text: "Use Pretty Names"
                        checkable: true
                        checked: PackageManager.showPrettyNames
                        onToggled: PackageManager.set_show_pretty_names(checked)
                    }
                    MenuItem {
                        text: "Group by Group"
                        checkable: true
                        checked: PackageManager.showGrouped
                        onToggled: PackageManager.set_show_grouped(checked)
                    }

                    MenuSeparator {}

                    MenuItem {
                        text: "Core"
                        checkable: true
                        checked: PackageManager.repoFilter.includes("core")
                        onToggled: PackageManager.toggle_repo_filter("core")
                    }
                    MenuItem {
                        text: "Extra"
                        checkable: true
                        checked: PackageManager.repoFilter.includes("extra")
                        onToggled: PackageManager.toggle_repo_filter("extra")
                    }
                    MenuItem {
                        text: "Multilib"
                        checkable: true
                        checked: PackageManager.repoFilter.includes("multilib")
                        onToggled: PackageManager.toggle_repo_filter("multilib")
                    }
                    MenuItem {
                        text: "AUR"
                        checkable: true
                        checked: PackageManager.repoFilter.includes("AUR")
                        onToggled: PackageManager.toggle_repo_filter("AUR")
                    }
                    MenuItem {
                        text: "Local"
                        checkable: true
                        checked: PackageManager.repoFilter.includes("Unknown")
                        onToggled: PackageManager.toggle_repo_filter("Unknown")
                    }
                }
            }

            Button {
                id: sortBtn
                icon.name: "view-sort-ascending"
                text: "Sort"
                onClicked: sortMenu.opened ? sortMenu.close() : sortMenu.open()

                Menu {
                    id: sortMenu
                    y: sortBtn.height

                    ActionGroup { id: pkgSortGroup; exclusive: true }

                    RadioDelegate {
                        text: "Name (A \u2192 Z)"
                        checked: PackageManager.sortOrder === "name_asc"
                        ActionGroup.group: pkgSortGroup
                        onClicked: { PackageManager.set_sort_order("name_asc"); sortMenu.close() }
                    }
                    RadioDelegate {
                        text: "Name (Z \u2192 A)"
                        checked: PackageManager.sortOrder === "name_desc"
                        ActionGroup.group: pkgSortGroup
                        onClicked: { PackageManager.set_sort_order("name_desc"); sortMenu.close() }
                    }
                    MenuSeparator {}
                    RadioDelegate {
                        text: "Size (Small \u2192 Large)"
                        checked: PackageManager.sortOrder === "size_asc"
                        enabled: PackageManager.mode === "installed"
                        ActionGroup.group: pkgSortGroup
                        onClicked: { PackageManager.set_sort_order("size_asc"); sortMenu.close() }
                    }
                    RadioDelegate {
                        text: "Size (Large \u2192 Small)"
                        checked: PackageManager.sortOrder === "size_desc"
                        enabled: PackageManager.mode === "installed"
                        ActionGroup.group: pkgSortGroup
                        onClicked: { PackageManager.set_sort_order("size_desc"); sortMenu.close() }
                    }
                }
            }
        }

        Kirigami.Separator { Layout.fillWidth: true; opacity: 0.5; visible: false }

        // ── Package list (+ inline deps panel at the bottom) ──────────────────
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredHeight: Kirigami.Units.gridUnit * 10 // Minimum height so it collapses, letting bottom buttons show
            color: UIColors.theme.description_background_hex ? UIColors.theme.description_background_hex : Qt.darker(Kirigami.Theme.backgroundColor, UIColors.theme.description_darker_multiplier)
            border.color: SettingsManager.enableContrastBorders ? (UIColors.theme.border_color_hex ? UIColors.theme.border_color_hex : Kirigami.Theme.highlightColor) : Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.5)
            border.width: 0 // Removed border as requested
            radius: Kirigami.Units.smallSpacing
            clip: true

            // Loading state
            ColumnLayout {
                anchors.centerIn: parent
                visible: PackageManager.isLoading
                spacing: Kirigami.Units.smallSpacing
                BusyIndicator { Layout.alignment: Qt.AlignHCenter; running: parent.visible }
                Label {
                    text: "Loading packages…"
                    color: SettingsManager.emphasisColor !== "" ? SettingsManager.emphasisColor : Kirigami.Theme.highlightColor
                    Layout.alignment: Qt.AlignHCenter
                }
            }

            // Content column: package list above, deps panel below
            ColumnLayout {
                anchors.fill: parent
                anchors.topMargin: 2
                anchors.bottomMargin: 2
                spacing: 0
                visible: !PackageManager.isLoading

                // ── Package list ──────────────────────────────────────────────
                ListView {
                    id: pkgListView
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: PackageManager.model
                    boundsBehavior: Flickable.StopAtBounds

                    ScrollBar.vertical: ScrollBar {
                        id: pkgScrollBar
                        policy: ScrollBar.AlwaysOn
                        visible: pkgListView.contentHeight > pkgListView.height
                    }

                    Kirigami.Separator {
                        anchors.right: parent.right
                        anchors.rightMargin: pkgScrollBar.width
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        visible: pkgScrollBar.visible
                        opacity: 0.5
                    }

                    section.property: PackageManager.showGrouped ? "group" : ""
                    section.criteria: ViewSection.FullString
                    section.delegate: Kirigami.ListSectionHeader {
                        width: pkgListView.width - pkgScrollBar.width
                        text: section
                        visible: PackageManager.showGrouped
                    }

                    delegate: ItemDelegate {
                        id: pkgDel
                        width: pkgListView.width - pkgScrollBar.width
                        leftPadding: Kirigami.Units.smallSpacing
                        // Provide enough right padding so the scrollbar does not occlude the text
                        rightPadding: Kirigami.Units.smallSpacing
                        topPadding: Kirigami.Units.smallSpacing / 2
                        bottomPadding: Kirigami.Units.smallSpacing / 2

                        background: Rectangle {
                            color: paneRoot.isSelected(model.fullName)
                                ? Qt.rgba(Kirigami.Theme.highlightColor.r,
                                          Kirigami.Theme.highlightColor.g,
                                          Kirigami.Theme.highlightColor.b, 0.2)
                                : pkgDel.hovered
                                ? Qt.rgba(Kirigami.Theme.highlightColor.r,
                                          Kirigami.Theme.highlightColor.g,
                                          Kirigami.Theme.highlightColor.b, 0.08)
                                : SettingsManager.alternatingRowColors && index % 2 !== 0
                                ? Qt.darker(Kirigami.Theme.backgroundColor, 1.06)
                                : "transparent"
                        }

                        contentItem: RowLayout {
                            spacing: Kirigami.Units.smallSpacing

                            CheckBox {
                                checked: paneRoot.isSelected(model.fullName)
                                onToggled: paneRoot.toggleSelection(model.fullName)
                                Layout.alignment: Qt.AlignVCenter
                            }

                            // Highlight updates
                            Kirigami.Icon {
                                source: Qt.resolvedUrl("../../icons/package_update_available.svg")
                                visible: model.updateStatus === "available"
                                isMask: true
                                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                                Layout.preferredHeight: Kirigami.Units.iconSizes.small
                                Layout.alignment: Qt.AlignVCenter
                                color: Kirigami.Theme.positiveTextColor

                                HoverHandler { id: updateAvailableHover }
                                ToolTip.text: (model.repo === "AUR" || model.repo === "") ? "View PKGBUILD" : "Update Available"
                                ToolTip.visible: updateAvailableHover.hovered
                                ToolTip.delay: Kirigami.Units.toolTipDelay

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: (model.repo === "AUR" || model.repo === "") ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    onClicked: {
                                        if (model.repo === "AUR" || model.repo === "") {
                                            PackageManager.fetch_pkgbuild(model.name)
                                            pkgbuildSheet.open()
                                        }
                                    }
                                }
                            }

                            // Placeholder to keep alignment for updates
                            Item {
                                visible: model.updateStatus !== "available"
                                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                                Layout.preferredHeight: Kirigami.Units.iconSizes.small
                            }

                            // Favorite Star
                            Kirigami.Icon {
                                source: Qt.resolvedUrl("../../icons/star.svg")
                                visible: model.isFavorite
                                isMask: true
                                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                                Layout.preferredHeight: Kirigami.Units.iconSizes.small
                                Layout.alignment: Qt.AlignVCenter
                                color: model.updateStatus === "available" ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.highlightColor
                            }

                            // Placeholder for Favorite Star
                            Item {
                                visible: !model.isFavorite
                                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                                Layout.preferredHeight: Kirigami.Units.iconSizes.small
                            }

                            Label {
                                text: model.name
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                                font.weight: paneRoot.isSelected(model.fullName) ? Font.Bold : Font.Normal
                                color: model.updateStatus === "available" ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.textColor
                            }

                            Label {
                                text: model.version + "  " + (model.repo || "AUR")
                                color: model.updateStatus === "available"
                                    ? Kirigami.Theme.positiveTextColor
                                    : (mouseAreaRepo.containsMouse && (model.repo === "AUR" || model.repo === ""))
                                        ? Kirigami.Theme.highlightColor
                                        : (SettingsManager.emphasisColor !== "" ? SettingsManager.emphasisColor : Kirigami.Theme.highlightColor)
                                font.pointSize: Kirigami.Theme.smallFont.pointSize
                                font.underline: (mouseAreaRepo.containsMouse && (model.repo === "AUR" || model.repo === ""))
                                Layout.alignment: Qt.AlignVCenter

                                MouseArea {
                                    id: mouseAreaRepo
                                    anchors.fill: parent
                                    hoverEnabled: (model.repo === "AUR" || model.repo === "")
                                    cursorShape: (model.repo === "AUR" || model.repo === "") ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    onClicked: {
                                        if (model.repo === "AUR" || model.repo === "") {
                                            Qt.openUrlExternally("https://aur.archlinux.org/packages/" + model.name)
                                        }
                                    }
                                }
                            }

                            Label {
                                text: Utils.formatBytes(model.size)
                                visible: model.size > 0
                                color: Kirigami.Theme.textColor
                                font.pointSize: Kirigami.Theme.smallFont.pointSize
                                Layout.alignment: Qt.AlignVCenter
                            }
                        }

                        onClicked: {
                            paneRoot.toggleSelection(model.fullName)
                        }
                    }
                }

                // ── Inline deps panel (appears when packages are selected) ────
                Item {
                    visible: paneRoot.selectedCount > 0
                    Layout.fillWidth: true
                    Layout.preferredHeight: paneRoot.selectedCount > 0 ? paneRoot.depsAreaHeight : 0

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 0

                    // ── Drag handle (resize by dragging up/down) ──────────────
                    Item {
                        Layout.fillWidth: true
                        height: Kirigami.Units.smallSpacing * 2 + 2

                        Kirigami.Separator {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.leftMargin: Kirigami.Units.largeSpacing
                            anchors.rightMargin: Kirigami.Units.largeSpacing
                            anchors.verticalCenter: parent.verticalCenter
                            opacity: 0.5
                            visible: !SettingsManager.alternatingRowColors
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.SizeVerCursor
                            property real pressSceneY: 0
                            property real pressH: 0
                            onPressed: (mouse) => {
                                pressSceneY = mapToItem(null, mouse.x, mouse.y).y
                                pressH = paneRoot.depsAreaHeight
                            }
                            onPositionChanged: (mouse) => {
                                if (pressed) {
                                    let sceneY = mapToItem(null, mouse.x, mouse.y).y
                                    let delta = pressSceneY - sceneY
                                    paneRoot.depsAreaHeight = Math.max(
                                        Kirigami.Units.gridUnit * 3,
                                        Math.min(pressH + delta, paneRoot.height * 0.75)
                                    )
                                }
                            }
                        }
                    }

                    // ── Loading state ─────────────────────────────────────────
                    RowLayout {
                        visible: PackageManager.isDryRunning
                        Layout.fillWidth: true
                        Layout.leftMargin: Kirigami.Units.largeSpacing
                        spacing: Kirigami.Units.smallSpacing

                        BusyIndicator {
                            running: true
                            implicitWidth: Kirigami.Units.iconSizes.smallMedium
                            implicitHeight: Kirigami.Units.iconSizes.smallMedium
                            Layout.alignment: Qt.AlignVCenter
                        }

                        Label {
                            text: "Checking dependencies…"
                            color: SettingsManager.emphasisColor !== "" ? SettingsManager.emphasisColor : Kirigami.Theme.highlightColor
                            Layout.alignment: Qt.AlignVCenter
                        }
                    }

                    // ── Result state ──────────────────────────────────────────
                    ColumnLayout {
                        visible: !PackageManager.isDryRunning
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.leftMargin: Kirigami.Units.largeSpacing
                        Layout.rightMargin: Kirigami.Units.largeSpacing
                        Layout.topMargin: Kirigami.Units.smallSpacing
                        Layout.bottomMargin: Kirigami.Units.smallSpacing
                        spacing: Kirigami.Units.smallSpacing

                        // Summary line
                        Label {
                            Layout.fillWidth: true
                            text: {
                                let total = paneRoot.pendingDeps.length
                                let sizeStr = (paneRoot.totalRemovedSize && paneRoot.totalRemovedSize !== "Unknown")
                                    ? (PackageManager.mode === "installed" ? "  ·  Frees " : "  ·  Size ") + paneRoot.totalRemovedSize : ""
                                let actionWord = PackageManager.mode === "installed" ? "removal" : "installation"
                                let futureActionWord = PackageManager.mode === "installed" ? "removed" : "installed"
                                if (total === 0)
                                    return paneRoot.selectedCount + " package" + (paneRoot.selectedCount !== 1 ? "s" : "") + " selected for " + actionWord + sizeStr
                                return total + " package" + (total !== 1 ? "s" : "") + " will be " + futureActionWord + sizeStr
                            }
                            font.bold: true
                            color: SettingsManager.emphasisColor !== "" ? SettingsManager.emphasisColor : Kirigami.Theme.highlightColor
                            wrapMode: Text.Wrap
                        }

                        // Orphaned deps sub-section (only when extras exist)
                        ColumnLayout {
                            id: extraDepsSection
                            property var extraDeps: paneRoot.pendingDeps.filter(n => !paneRoot.selectedNames[n])
                            visible: extraDeps.length > 0
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            spacing: Kirigami.Units.smallSpacing / 2

                            Label {
                                text: {
                                    let n = extraDepsSection.extraDeps.length
                                    let actionWord = PackageManager.mode === "installed" ? "removes" : "installs"
                                    return "Also " + actionWord + " " + n + " dep" + (n !== 1 ? "s" : "") + ":"
                                }
                                color: SettingsManager.emphasisColor !== "" ? SettingsManager.emphasisColor : Kirigami.Theme.highlightColor
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                color: Qt.darker(Kirigami.Theme.backgroundColor, 1.05)
                                radius: 3
                                clip: true

                                ListView {
                                    id: extraList
                                    anchors.fill: parent
                                    anchors.margins: Kirigami.Units.smallSpacing
                                    model: extraDepsSection.extraDeps
                                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                                    delegate: Label {
                                        width: ListView.view.width
                                        text: "• " + modelData
                                        color: SettingsManager.emphasisColor !== "" ? SettingsManager.emphasisColor : Kirigami.Theme.highlightColor
                                        topPadding: 1
                                        bottomPadding: 1
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ── Stats ─────────────────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            Label {
                text: pkgListView.count === PackageManager.packageCount
                    ? PackageManager.packageCount + " packages"
                    : pkgListView.count + " / " + PackageManager.packageCount + " packages"
                color: SettingsManager.emphasisColor !== "" ? SettingsManager.emphasisColor : Kirigami.Theme.highlightColor
                font.pointSize: Kirigami.Theme.smallFont.pointSize
            }

            Item { Layout.fillWidth: true }

            Label {
                visible: PackageManager.updateCount > 0 && paneRoot.selectedCount === 0 && PackageManager.mode === "installed"
                text: PackageManager.updateCount + " update" + (PackageManager.updateCount !== 1 ? "s" : "")
                color: SettingsManager.emphasisColor !== "" ? SettingsManager.emphasisColor : Kirigami.Theme.highlightColor
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                font.weight: Font.Medium
            }
        }

        // ── Progress text (upgrade status) ────────────────────────────────────
        Label {
            Layout.fillWidth: true
            visible: PackageManager.progressText !== ""
            text: PackageManager.progressText
            wrapMode: Text.Wrap
            color: SettingsManager.emphasisColor !== "" ? SettingsManager.emphasisColor : Kirigami.Theme.highlightColor
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            font.italic: true
        }

        // ── Action buttons ────────────────────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            // Check Updates
            Button {
                id: checkBtn
                Layout.fillWidth: true
                Layout.preferredHeight: Kirigami.Units.gridUnit * 1.8
                visible: paneRoot.selectedCount === 0 && PackageManager.mode === "installed"
                enabled: !PackageManager.isCheckingUpdates && !PackageManager.isLoading
                        && !PackageManager.isUpgrading && !PackageManager.isRemoving
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
                            color: UIIcons.iconColor("check_update", checkBtn.enabled ? Kirigami.Theme.highlightColor : Kirigami.Theme.disabledTextColor)
                        }
                        Label {
                            text: PackageManager.isCheckingUpdates ? "Checking…" : "Check Updates"
                            color: checkBtn.enabled ? Kirigami.Theme.highlightColor : Kirigami.Theme.disabledTextColor
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
                background: Rectangle {
                    color: checkBtn.down
                        ? Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b, 0.2)
                        : checkBtn.hovered
                        ? Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b, 0.1)
                        : "transparent"
                    border.color: Kirigami.Theme.highlightColor
                    border.width: 1
                    radius: Kirigami.Units.smallSpacing
                }
                onClicked: PackageManager.check_updates()
            }

            // Upgrade System — proactive sync/upgrade action
            Button {
                id: upgradeBtn
                Layout.fillWidth: true
                Layout.preferredHeight: Kirigami.Units.gridUnit * 1.8
                visible: paneRoot.selectedCount === 0 && PackageManager.mode === "installed"
                enabled: !PackageManager.isUpgrading && !PackageManager.isLoading
                        && !PackageManager.isRemoving
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
                            color: UIIcons.iconColor("download", upgradeBtn.enabled ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.disabledTextColor)
                        }
                        Label {
                            text: PackageManager.isUpgrading
                                ? "Upgrading…"
                                : (PackageManager.updateCount > 0 ? "Upgrade System (" + PackageManager.updateCount + ")" : "Full System Upgrade")
                            color: upgradeBtn.enabled ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.disabledTextColor
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
                background: Rectangle {
                    color: upgradeBtn.down
                        ? Qt.rgba(Kirigami.Theme.positiveTextColor.r, Kirigami.Theme.positiveTextColor.g, Kirigami.Theme.positiveTextColor.b, 0.2)
                        : upgradeBtn.hovered
                        ? Qt.rgba(Kirigami.Theme.positiveTextColor.r, Kirigami.Theme.positiveTextColor.g, Kirigami.Theme.positiveTextColor.b, 0.1)
                        : "transparent"
                    border.color: Kirigami.Theme.positiveTextColor
                    border.width: 1
                    radius: Kirigami.Units.smallSpacing
                }
                onClicked: {
                    PackageManager.upgrade()
                    confirmRemovalSheet.open()
                }
            }

            // Confirmation checkbox — shown once the dep check has completed
            CheckBox {
                id: depsConfirmBox
                visible: paneRoot.selectedCount > 0 && !PackageManager.isDryRunning
                Layout.preferredHeight: visible ? implicitHeight : 0
                Layout.fillWidth: true
                text: PackageManager.mode === "installed" ? "I've reviewed the packages that will be removed" : "I've reviewed the packages that will be installed"
                checked: paneRoot.confirmChecked
                onToggled: paneRoot.confirmChecked = checked
            }

            // Remove/Install — always visible but disabled if nothing selected
            Button {
                id: removeBtn
                Layout.fillWidth: true
                Layout.preferredHeight: Kirigami.Units.gridUnit * 1.8
                visible: true
                enabled: paneRoot.selectedCount > 0 && !PackageManager.isRemoving && !PackageManager.isLoading
                        && !PackageManager.isUpgrading && !PackageManager.isDryRunning
                        && paneRoot.confirmChecked
                
                contentItem: Item {
                    implicitWidth: row3.implicitWidth
                    implicitHeight: row3.implicitHeight
                    Row {
                        id: row3
                        anchors.centerIn: parent
                        spacing: Kirigami.Units.smallSpacing
                        Kirigami.Icon {
                            source: PackageManager.mode === "installed" ? (UIIcons.icons.delete || "") : (UIIcons.icons.download || "")
                            width: Kirigami.Units.iconSizes.smallMedium
                            height: Kirigami.Units.iconSizes.smallMedium
                            anchors.verticalCenter: parent.verticalCenter
                            isMask: true
                            color: PackageManager.mode === "installed" 
                                        ? UIIcons.iconColor("delete", removeBtn.enabled ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.disabledTextColor)
                                        : UIIcons.iconColor("download", removeBtn.enabled ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.disabledTextColor)
                        }
                        Label {
                            text: {
                                if (PackageManager.isRemoving) return PackageManager.mode === "installed" ? "Removing…" : "Installing…"
                                let actionWord = PackageManager.mode === "installed" ? "Remove" : "Install"
                                if (paneRoot.selectedCount === 0) return actionWord
                                actionWord = actionWord + " Selected"
                                return actionWord + " (" + paneRoot.selectedCount + ")"
                            }
                            color: removeBtn.enabled ? (PackageManager.mode === "installed" ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.textColor) : Kirigami.Theme.disabledTextColor
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }

                background: Rectangle {
                    color: removeBtn.down
                        ? Qt.rgba(Kirigami.Theme.negativeTextColor.r, Kirigami.Theme.negativeTextColor.g, Kirigami.Theme.negativeTextColor.b, 0.2)
                        : removeBtn.hovered
                        ? Qt.rgba(Kirigami.Theme.negativeTextColor.r, Kirigami.Theme.negativeTextColor.g, Kirigami.Theme.negativeTextColor.b, 0.1)
                        : "transparent"
                    border.color: Kirigami.Theme.negativeTextColor
                    border.width: 1
                    radius: Kirigami.Units.smallSpacing
                }

                onClicked: {
                    // Deps already shown inline; go straight to removal
                    confirmRemovalSheet.open()
                    PackageManager.remove_packages(Object.keys(paneRoot.selectedNames))
                }
            }
        }

        // Persistent reboot recommendation banner
        Kirigami.InlineMessage {
            Layout.fillWidth: true
            visible: PackageManager.needsReboot
            type: Kirigami.MessageType.Warning
            text: "Reboot recommended — kernel or core system packages were upgraded."
        }
    }

    // ── Action progress overlay ───────────────────────────────────────────────
    Kirigami.OverlaySheet {
        id: confirmRemovalSheet
        showCloseButton: !PackageManager.isRemoving && !PackageManager.isUpgrading
        title: PackageManager.isUpgrading
            ? "Upgrading System…"
            : PackageManager.isRemoving
                ? (PackageManager.mode === "installed" ? "Removing Packages…" : "Installing Packages…")
                : "Action Output"

        implicitWidth: Kirigami.Units.gridUnit * 40

        ColumnLayout {
            spacing: Kirigami.Units.largeSpacing
            Layout.preferredWidth: Kirigami.Units.gridUnit * 38
            Layout.fillWidth: false
            Layout.alignment: Qt.AlignHCenter

            ProgressBar {
                visible: PackageManager.isRemoving || PackageManager.isUpgrading
                indeterminate: true
                Layout.fillWidth: true
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Kirigami.Units.gridUnit * 25 // Increased height
                color: Qt.darker(Kirigami.Theme.backgroundColor, 1.2) // Match system background instead of strict black
                border.color: Kirigami.Theme.disabledTextColor
                border.width: 1
                radius: SettingsManager.cornerRadius / 2
                clip: true

                ScrollView {
                    id: outputScrollView
                    anchors.fill: parent
                    anchors.margins: Kirigami.Units.smallSpacing

                    TextArea {
                        id: outputArea
                        text: PackageManager.removalOutput
                        readOnly: true
                        font.family: "Monospace"
                        font.pointSize: Kirigami.Theme.defaultFont.pointSize
                        color: Kirigami.Theme.textColor // System text color instead of green
                        background: null
                        wrapMode: Text.NoWrap

                        onTextChanged: {
                            cursorPosition = length
                            let sb = outputScrollView.ScrollBar.vertical
                            if (sb) sb.position = Math.max(0, 1.0 - sb.size)
                        }
                    }
                }
            }

            // Reboot recommendation (shown after upgrade completes)
            Kirigami.InlineMessage {
                Layout.fillWidth: true
                visible: PackageManager.needsReboot && !PackageManager.isUpgrading
                type: Kirigami.MessageType.Warning
                text: "A reboot is recommended to apply kernel or system library updates."
            }

            // Close / Abort button
            Button {
                visible: PackageManager.removalOutput !== "" || PackageManager.isUpgrading || PackageManager.isRemoving
                Layout.fillWidth: true
                Layout.preferredHeight: Kirigami.Units.gridUnit * 1.8
                text: (PackageManager.isRemoving || PackageManager.isUpgrading) ? "Abort" : "Close"
                background: Rectangle {
                    color: parent.down
                        ? Qt.rgba(Kirigami.Theme.negativeTextColor.r, Kirigami.Theme.negativeTextColor.g, Kirigami.Theme.negativeTextColor.b, 0.2)
                        : parent.hovered && (PackageManager.isRemoving || PackageManager.isUpgrading)
                        ? Qt.rgba(Kirigami.Theme.negativeTextColor.r, Kirigami.Theme.negativeTextColor.g, Kirigami.Theme.negativeTextColor.b, 0.1)
                        : "transparent"
                    border.color: (PackageManager.isRemoving || PackageManager.isUpgrading) ? Kirigami.Theme.negativeTextColor : "transparent"
                    border.width: (PackageManager.isRemoving || PackageManager.isUpgrading) ? 1 : 0
                    radius: Kirigami.Units.smallSpacing
                }
                contentItem: Label {
                    text: parent.text
                    color: (PackageManager.isRemoving || PackageManager.isUpgrading) ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.textColor
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                onClicked: {
                    if (PackageManager.isRemoving || PackageManager.isUpgrading) {
                        abortDialog.open()
                    } else {
                        confirmRemovalSheet.close()
                    }
                }
            }
        }
    }

    Kirigami.PromptDialog {
        id: abortDialog
        title: "Abort Process"
        subtitle: "Are you sure you want to abort the current process?"
        standardButtons: Kirigami.PromptDialog.Yes | Kirigami.PromptDialog.No
        onAccepted: {
            PackageManager.cancel_action()
            confirmRemovalSheet.close()
        }
    }

    Kirigami.OverlaySheet {
        id: pkgbuildSheet
        title: "PKGBUILD"
        showCloseButton: true
        width: Math.min(Kirigami.Units.gridUnit * 50, paneRoot.width * 0.95)

        ColumnLayout {
            spacing: Kirigami.Units.smallSpacing
            width: pkgbuildSheet.width - pkgbuildSheet.leftPadding - pkgbuildSheet.rightPadding

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Kirigami.Units.gridUnit * 30
                color: Qt.darker(Kirigami.Theme.backgroundColor, 1.2)
                border.color: Kirigami.Theme.disabledTextColor
                border.width: 1
                radius: Kirigami.Units.smallSpacing
                clip: true

                ScrollView {
                    anchors.fill: parent
                    anchors.margins: Kirigami.Units.smallSpacing

                    TextArea {
                        text: PackageManager.pkgbuildContent
                        readOnly: true
                        font.family: "Monospace"
                        font.pointSize: Kirigami.Theme.defaultFont.pointSize
                        background: null
                        wrapMode: Text.NoWrap
                        color: Kirigami.Theme.textColor
                    }
                }
            }
        }
    }
}
