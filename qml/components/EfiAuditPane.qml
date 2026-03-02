import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Rectangle {
    id: paneRoot
    color: UIColors.theme.queue_background_hex ? UIColors.theme.queue_background_hex : Qt.darker(Kirigami.Theme.backgroundColor, UIColors.theme.queue_darker_multiplier)
    border.color: UIColors.theme.border_color_hex ? UIColors.theme.border_color_hex : Kirigami.Theme.highlightColor
    border.width: 1
    radius: SettingsManager.cornerRadius
    clip: true

    property var activeTask: null
    property int updateTrigger: 0 // Used to force Qt to re-evaluate functions

    TextMetrics {
        id: measureText
        font.weight: Font.DemiBold
    }
    
    property real idealWidth: {
        let dummy = updateTrigger;
        let maxW = 0;
        if (activeTask && activeTask.subItems) {
            let pItems = activeTask.subItems;
            let lim = Math.min(pItems.length, 300);
            for (let i = 0; i < lim; i++) {
                measureText.text = pItems[i].name;
                if (measureText.width > maxW) maxW = measureText.width;
                
                measureText.text = pItems[i].details;
                if (measureText.width > maxW) maxW = measureText.width;
            }
        }
        return Math.max(Kirigami.Units.gridUnit * 18, Math.min(mainWindow.width * 0.5, maxW + Kirigami.Units.gridUnit * 10));
    }

    function getSelectedCount() {
        if (!activeTask) return 0;
        let dummy = updateTrigger;
        let count = 0;
        for (let i = 0; i < activeTask.subItems.length; ++i) {
            if (activeTask.subItems[i].checked) count++;
        }
        return count;
    }

    function getSelectedItems() {
        if (!activeTask) return [];
        let dummy = updateTrigger;
        let selected = [];
        for (let i = 0; i < activeTask.subItems.length; ++i) {
            if (activeTask.subItems[i].checked) {
                // Ensure we capture originalIndex for global dialog compatibility
                let item = Object.assign({}, activeTask.subItems[i]);
                item.originalIndex = i;
                selected.push(item);
            }
        }
        return selected;
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Kirigami.Units.largeSpacing
        spacing: Kirigami.Units.smallSpacing

        Kirigami.Heading {
            text: UIStrings.ui.boot_audit.results_title
            level: 2
            font.pointSize: UIFonts.fonts.headline
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            visible: false // Removed headline as requested
        }

        // List Area
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: UIColors.theme.description_background_hex ? UIColors.theme.description_background_hex : Qt.darker(Kirigami.Theme.backgroundColor, UIColors.theme.description_darker_multiplier)
            border.color: UIColors.theme.border_color_hex ? UIColors.theme.border_color_hex : Kirigami.Theme.highlightColor
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
                    Label {
                        anchors.centerIn: parent
                        text: (paneRoot.activeTask && paneRoot.activeTask.state === 2) 
                              ? UIStrings.ui.boot_audit.placeholder_empty 
                              : UIStrings.ui.boot_audit.placeholder_unscanned
                        color: Kirigami.Theme.disabledTextColor
                        font.italic: true
                        horizontalAlignment: Qt.AlignHCenter
                        width: parent.width - Kirigami.Units.gridUnit * 2
                        wrapMode: Text.WordWrap
                    }
                }

                // 1: Loading State
                Item {
                    ColumnLayout {
                        anchors.centerIn: parent
                        BusyIndicator {
                            Layout.alignment: Qt.AlignHCenter
                            running: parent.visible
                        }
                        Label {
                            text: paneRoot.activeTask ? paneRoot.activeTask.progressText : "Working..."
                            color: Kirigami.Theme.neutralTextColor
                            Layout.alignment: Qt.AlignHCenter
                        }
                    }
                }

                // 2: Results List
                RowLayout {
                    spacing: 0
                    ListView {
                        id: efiListView
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        model: paneRoot.activeTask ? paneRoot.activeTask.subItems : []
                        ScrollBar.vertical: efiScroll
                        
                        delegate: ItemDelegate {
                            id: efiDel
                            width: efiListView.width
                            height: implicitHeight
                            
                            background: Rectangle {
                                color: (efiDel.hovered || efiDel.down) ? Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b, 0.1) : "transparent"
                            }

                            contentItem: ColumnLayout {
                                spacing: 0
                                RowLayout {
                                    Layout.fillWidth: true
                                    Layout.margins: Kirigami.Units.smallSpacing
                                    spacing: Kirigami.Units.smallSpacing

                                    CheckBox {
                                        id: efiCbox
                                        checked: modelData.checked || false
                                        onCheckedChanged: {
                                            if (paneRoot.activeTask && paneRoot.activeTask.subItems[index].checked !== checked) {
                                                paneRoot.activeTask.set_sub_item_checked(index, checked)
                                                paneRoot.updateTrigger++
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
                                            wrapMode: Text.Wrap
                                            Layout.fillWidth: true
                                        }
                                        
                                        Label {
                                            text: modelData.details
                                            font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.9
                                            color: Kirigami.Theme.neutralTextColor
                                            wrapMode: Text.Wrap
                                            Layout.fillWidth: true
                                        }
                                    }
                                }
                                Kirigami.Separator {
                                    Layout.fillWidth: true
                                    opacity: 0.3
                                }
                            }
                            onClicked: {
                                efiCbox.toggle();
                            }
                        }
                    }
                    
                    ScrollBar {
                        id: efiScroll
                        Layout.fillHeight: true
                        policy: ScrollBar.AlwaysOn
                        visible: efiListView.contentHeight > efiListView.height
                    }
                }
            }
        }

        // Action Buttons
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            Label {
                text: UIStrings.ui.boot_audit.total_selected + paneRoot.getSelectedCount()
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                color: "#ff8c00" // Standardize warning orange
                Layout.alignment: Qt.AlignHCenter
                visible: paneRoot.getSelectedCount() > 0
            }

            Button {
                id: cleanBtn
                text: UIStrings.ui.boot_audit.btn_clean + " (" + paneRoot.getSelectedCount() + ")"
                Layout.fillWidth: true
                enabled: paneRoot.getSelectedCount() > 0 && paneRoot.activeTask && paneRoot.activeTask.state !== 1
                background: Rectangle {
                    color: cleanBtn.down ? Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b, 0.2) : 
                           cleanBtn.hovered ? Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b, 0.1) : "transparent"
                    border.color: Kirigami.Theme.highlightColor
                    border.width: 1
                    radius: Kirigami.Units.smallSpacing
                }
                onClicked: {
                    let items = paneRoot.getSelectedItems();
                    for (let i=0; i<items.length; i++) {
                        items[i].sizeBytes = 0; 
                    }
                    mainWindow.openEfiAuditConfirmation(paneRoot.activeTask, items);
                }
            }

            Label {
                text: paneRoot.activeTask && paneRoot.activeTask.state === 1 ? UIStrings.ui.boot_audit.status_cleaning : ""
                visible: text !== ""
                color: Kirigami.Theme.neutralTextColor
                Layout.alignment: Qt.AlignHCenter
                font.italic: true
            }
        }
    }
}
