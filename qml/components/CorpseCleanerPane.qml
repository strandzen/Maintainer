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
    
    readonly property color effectiveHighlight: Kirigami.Theme.highlightColor

    // Pass the task object from main.qml via Loader properties
    property var activeTask: null
    property int updateTrigger: 0

    TextMetrics {
        id: measureText
        font.weight: Font.DemiBold
    }
    
    property real idealWidth: {
        let dummy = updateTrigger; // Force re-eval on change
        let maxW = 0;
        if (activeTask && activeTask.subItems) {
            let pItems = activeTask.subItems;
            
            // Limit to first 300 to avoid freezing on massive cleanup results
            let lim = Math.min(pItems.length, 300);
            
            for (let i = 0; i < lim; i++) {
                measureText.text = pItems[i].name;
                if (measureText.width > maxW) maxW = measureText.width;
                
                measureText.text = pItems[i].description;
                if (measureText.width > maxW) maxW = measureText.width;
            }
        }
        return Math.max(Kirigami.Units.gridUnit * 18, Math.min(Kirigami.Units.gridUnit * 40, maxW + Kirigami.Units.gridUnit * 10));
    }
    
    // Helper to calculate total sizes
    function getSelectedTotal() {
        let dummy = updateTrigger;
        if (!activeTask || !activeTask.subItems) return "";
        let total = 0;
        let pItems = activeTask.subItems; // Get the list once
        let count = 0;
        
        for (let i = 0; i < pItems.length; i++) {
            if (pItems[i].checked) {
                total += pItems[i].sizeBytes;
                count++;
            }
        }
        
        if (count === 0) return "";
        return Utils.formatBytes(total);
    }

    function getSelectedCount() {
        let dummy = updateTrigger;
        if (!activeTask || !activeTask.subItems) return 0;
        let count = 0;
        let pItems = activeTask.subItems;
        for (let i = 0; i < pItems.length; i++) {
            if (pItems[i].checked) count++;
        }
        return count;
    }

    // Returns a list of objects that are checked for the confirmation sheet
    function getSelectedItems() {
        let dummy = updateTrigger;
        if (!activeTask || !activeTask.subItems) return [];
        let items = [];
        let pItems = activeTask.subItems;
        for (let i = 0; i < pItems.length; i++) {
            if (pItems[i].checked) {
                // Add the original index so we can Uncheck it from the sheet
                items.push({
                    originalIndex: i,
                    name: pItems[i].name,
                    description: pItems[i].description,
                    sizeBytes: pItems[i].sizeBytes
                });
            }
        }
        return items;
    }

    Item {
        anchors.fill: parent
        anchors.margins: Kirigami.Units.largeSpacing
        
        ColumnLayout {
            anchors.fill: parent
            spacing: Kirigami.Units.smallSpacing
            
        // ── Search, Action and Filters ───────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            Kirigami.SearchField {
                id: corpseSearchField
                Layout.fillWidth: true
                placeholderText: "Search corpses..."
                enabled: paneRoot.activeTask && paneRoot.activeTask.state === 2
            }

            Button {
                id: sortBtn
                text: "Sort"
                icon.name: "view-sort-ascending"
                enabled: paneRoot.activeTask && paneRoot.activeTask.state === 2
                onClicked: sortMenu.opened ? sortMenu.close() : sortMenu.open()

                Menu {
                    id: sortMenu
                    y: sortBtn.height

                    ActionGroup { id: corpseSortGroup; exclusive: true }

                    RadioDelegate {
                        text: "Name (A \u2192 Z)"
                        ActionGroup.group: corpseSortGroup
                        onClicked: { if(paneRoot.activeTask) paneRoot.activeTask.set_sort_order("name_asc"); sortMenu.close() }
                    }
                    RadioDelegate {
                        text: "Name (Z \u2192 A)"
                        ActionGroup.group: corpseSortGroup
                        onClicked: { if(paneRoot.activeTask) paneRoot.activeTask.set_sort_order("name_desc"); sortMenu.close() }
                    }
                    MenuSeparator {}
                    RadioDelegate {
                        text: "Size (Small \u2192 Large)"
                        ActionGroup.group: corpseSortGroup
                        onClicked: { if(paneRoot.activeTask) paneRoot.activeTask.set_sort_order("size_asc"); sortMenu.close() }
                    }
                    RadioDelegate {
                        text: "Size (Large \u2192 Small)"
                        ActionGroup.group: corpseSortGroup
                        onClicked: { if(paneRoot.activeTask) paneRoot.activeTask.set_sort_order("size_desc"); sortMenu.close() }
                    }
                }
            }

            Button {
                id: scanBtn
                text: UIStrings.ui.corpse_cleaner.btn_scan
                icon.name: "search"
                enabled: paneRoot.activeTask && paneRoot.activeTask.state !== 1
                onClicked: {
                    if (paneRoot.activeTask) {
                        paneRoot.activeTask.calculate_size()
                    }
                }
            }
        }

            // List Area
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: UIColors.theme.description_background_hex ? UIColors.theme.description_background_hex : Qt.darker(Kirigami.Theme.backgroundColor, UIColors.theme.description_darker_multiplier)
                border.color: SettingsManager.enableContrastBorders ? (UIColors.theme.border_color_hex ? UIColors.theme.border_color_hex : Kirigami.Theme.highlightColor) : Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.5)
                border.width: 0 // Removed border as requested
                radius: Kirigami.Units.smallSpacing
                clip: true

                StackLayout {
                    anchors.fill: parent
                    currentIndex: {
                        if (!paneRoot.activeTask) return 0;
                        if (paneRoot.activeTask.state === 1) return 1; // Scanning or Cleaning
                        if (paneRoot.activeTask.subItems.length === 0) return 0; // Empty
                        return 2; // Has Items
                    }

                    // 0: Empty State
                    Item {
                        Kirigami.PlaceholderMessage {
                            anchors.centerIn: parent
                            text: paneRoot.activeTask && paneRoot.activeTask.state === 0 ? UIStrings.ui.corpse_cleaner.placeholder_unscanned : UIStrings.ui.corpse_cleaner.placeholder_empty
                            icon.name: "task-complete"
                        }
                    }

                    // 1: Loading/Cleaning State
                    Item {
                        ColumnLayout {
                            anchors.centerIn: parent
                            BusyIndicator {
                                Layout.alignment: Qt.AlignHCenter
                                running: paneRoot.activeTask && paneRoot.activeTask.state === 1
                            }
                            Label {
                                text: paneRoot.activeTask ? paneRoot.activeTask.progressText : "Working..."
                                color: Kirigami.Theme.neutralTextColor
                                Layout.alignment: Qt.AlignHCenter
                                font.italic: true
                            }
                        }
                    }

                    // 2: Results List
                    ColumnLayout {
                        spacing: 0
                    

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            spacing: 0

                            ListView {
                                id: resultsList
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                clip: true
                                model: paneRoot.activeTask ? paneRoot.activeTask.subItems : null
                                boundsBehavior: Flickable.StopAtBounds
                                ScrollBar.vertical: resultsScroll
                                
                                delegate: ItemDelegate {
                                id: del
                                
                                property bool matchesSearch: corpseSearchField.text === "" || modelData.name.toLowerCase().indexOf(corpseSearchField.text.toLowerCase()) !== -1 || modelData.description.toLowerCase().indexOf(corpseSearchField.text.toLowerCase()) !== -1
                                
                                visible: matchesSearch
                                width: resultsList.width
                                height: visible ? implicitHeight : 0
                                
                                background: Rectangle {
                                    color: del.hovered ? Qt.rgba(paneRoot.effectiveHighlight.r, paneRoot.effectiveHighlight.g, paneRoot.effectiveHighlight.b, 0.1) : "transparent"
                                }

                                contentItem: ColumnLayout {
                                    spacing: 0
                                    RowLayout {
                                        Layout.fillWidth: true
                                        Layout.margins: Kirigami.Units.smallSpacing
                                        spacing: Kirigami.Units.smallSpacing

                                        CheckBox {
                                            id: cbox
                                            checked: modelData.checked
                                            onToggled: {
                                                if (paneRoot.activeTask) {
                                                    modelData.checked = checked;
                                                    paneRoot.activeTask.set_sub_item_checked(index, checked);
                                                    paneRoot.updateTrigger++;
                                                }
                                            }
                                            Layout.alignment: Qt.AlignVCenter
                                        }

                                        ColumnLayout {
                                            spacing: 0
                                            Layout.fillWidth: true
                                            
                                            Label {
                                                text: modelData.name
                                                font.weight: Font.DemiBold
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }
                                            
                                            Label {
                                                text: modelData.description
                                                font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.9
                                                color: Kirigami.Theme.neutralTextColor
                                                wrapMode: Text.Wrap
                                                Layout.fillWidth: true
                                            }
                                        }

                                        Label {
                                            text: Utils.formatBytes(modelData.sizeBytes)
                                            font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.9
                                            color: Kirigami.Theme.neutralTextColor
                                            Layout.alignment: Qt.AlignVCenter
                                        }
                                    }
                                    Kirigami.Separator {
                                        Layout.fillWidth: true
                                        opacity: 0.3
                                    }
                                }
                                onClicked: {
                                    cbox.toggle();
                                }
                            }
                        }

                        ScrollBar {
                            id: resultsScroll
                            Layout.fillHeight: true
                            policy: ScrollBar.AlwaysOn
                            visible: resultsList.contentHeight > resultsList.height
                        }
                        }
                    }
                }
            }
            
            Kirigami.Separator { Layout.fillWidth: true; opacity: 0.5 }
            
            Label {
                text: paneRoot.getSelectedTotal() ? UIStrings.ui.corpse_cleaner.total_selected + paneRoot.getSelectedTotal() : ""
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                color: SettingsManager.emphasisColor
                Layout.alignment: Qt.AlignHCenter
                visible: paneRoot.getSelectedCount() > 0
            }

            Button {
                id: cleanBtn
                Layout.fillWidth: true
                Layout.preferredHeight: Kirigami.Units.gridUnit * 1.8
                enabled: paneRoot.getSelectedCount() > 0 && paneRoot.activeTask && paneRoot.activeTask.state !== 1
                contentItem: Item {
                    implicitWidth: rowClean.implicitWidth
                    implicitHeight: rowClean.implicitHeight
                    Row {
                        id: rowClean
                        anchors.centerIn: parent
                        spacing: Kirigami.Units.smallSpacing
                        Kirigami.Icon {
                            source: UIIcons.icons.delete || ""
                            width: Kirigami.Units.iconSizes.smallMedium
                            height: Kirigami.Units.iconSizes.smallMedium
                            anchors.verticalCenter: parent.verticalCenter
                            isMask: true
                            color: UIIcons.iconColor("delete", cleanBtn.enabled ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.disabledTextColor)
                        }
                        Label {
                            text: UIStrings.ui.corpse_cleaner.btn_clean + " (" + paneRoot.getSelectedCount() + ")"
                            color: cleanBtn.enabled ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.disabledTextColor
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
                onClicked: {
                    let items = paneRoot.getSelectedItems();
                    mainWindow.openCorpseCleanerConfirmation(paneRoot.activeTask, items, paneRoot.getSelectedTotal());
                }
                background: Rectangle {
                    color: cleanBtn.down ? Qt.rgba(Kirigami.Theme.negativeTextColor.r, Kirigami.Theme.negativeTextColor.g, Kirigami.Theme.negativeTextColor.b, 0.2) :
                           cleanBtn.hovered ? Qt.rgba(Kirigami.Theme.negativeTextColor.r, Kirigami.Theme.negativeTextColor.g, Kirigami.Theme.negativeTextColor.b, 0.1) : "transparent"
                    border.color: Kirigami.Theme.negativeTextColor
                    border.width: 1
                    radius: Kirigami.Units.smallSpacing
                }
            }
            
            // Progress message area
            Label {
                text: paneRoot.activeTask && paneRoot.activeTask.state === 1 ? UIStrings.ui.corpse_cleaner.status_cleaning : ""
                visible: text !== ""
                color: Kirigami.Theme.neutralTextColor
                Layout.alignment: Qt.AlignHCenter
                font.italic: true
            }
        }
    }


}
