import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Kirigami.ScrollablePage {
    id: page
    objectName: "efiAuditPage"

    // Property injected from main.qml when navigating here
    property var taskModel: null
    property var myTask: null
    
    Component.onCompleted: {
        // Find our specialized task in the model
        if (taskModel) {
            for (let i = 0; i < taskModel.rowCount(); i++) {
                let t = taskModel.get_task(i)
                if (t && t.name === "Boot Audit") {
                    myTask = t;
                    break;
                }
            }
        }
    }

    ColumnLayout {
        width: page.width
        spacing: Kirigami.Units.largeSpacing

        // Title and Description Area
        ColumnLayout {
            Layout.fillWidth: true
            Layout.margins: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.smallSpacing

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: Kirigami.Units.smallSpacing
                
                Kirigami.Icon {
                    source: UIIcons.icons.boot_audit || ""
                    Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                    Layout.preferredHeight: Kirigami.Units.iconSizes.medium
                    isMask: UIIcons.shouldColorize("boot_audit")
                    color: UIIcons.iconColor("boot_audit", Kirigami.Theme.highlightColor)
                }

                Kirigami.Heading {
                    text: UIStrings.ui.boot_audit.title
                    level: 2
                }
            }
            
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: Math.max(Kirigami.Units.gridUnit * 10, Math.min(Kirigami.Units.gridUnit * 40, page.width - Kirigami.Units.gridUnit * 4))
                implicitHeight: colDesc.implicitHeight + Kirigami.Units.largeSpacing * 2
                color: Qt.rgba(Kirigami.Theme.negativeTextColor.r, Kirigami.Theme.negativeTextColor.g, Kirigami.Theme.negativeTextColor.b, 0.1)
                border.color: Kirigami.Theme.negativeTextColor
                border.width: 1
                radius: SettingsManager.cornerRadius / 2

                ColumnLayout {
                    id: colDesc
                    anchors.centerIn: parent
                    width: parent.width - Kirigami.Units.largeSpacing * 2
                    spacing: Kirigami.Units.smallSpacing

                    Label {
                        text: UIStrings.ui.boot_audit.description
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignHCenter
                        color: Kirigami.Theme.negativeTextColor
                        Layout.fillWidth: true
                        font.weight: Font.DemiBold
                    }
                }
            }
        }

        // Action Buttons
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: Kirigami.Units.largeSpacing

            Button {
                text: UIStrings.ui.boot_audit.btn_scan || "Scan"
                icon.name: "system-search"
                enabled: myTask && myTask.state !== 1
                background: Rectangle {
                    color: parent.down ? Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b, 0.4) : 
                           parent.hovered ? Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b, 0.2) : "transparent"
                    border.color: Kirigami.Theme.highlightColor
                    border.width: 1
                    radius: Kirigami.Units.smallSpacing
                }
                onClicked: {
                    if (myTask) {
                        myTask.scan()
                    }
                }
            }
        }
        
        // Let the right pane (EfiAuditPane) handle the result visualization
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
        }
    }
}
