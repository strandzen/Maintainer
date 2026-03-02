import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Kirigami.ScrollablePage {
    id: page
    objectName: "corpseCleanerPage"
    background: null
    title: UIStrings.ui.corpse_cleaner.title

    titleDelegate: Item {}

    property var myTask: TaskRegistry.getTask("corpse_cleaner", 0)

    ColumnLayout {
        width: page.width
        spacing: Kirigami.Units.largeSpacing

        // Top Icon
        Kirigami.Icon {
            source: UIIcons.icons.corpse_cleaner || ""
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: Kirigami.Units.iconSizes.huge * UIIcons.headerIconScale
            Layout.preferredHeight: Kirigami.Units.iconSizes.huge * UIIcons.headerIconScale
            isMask: UIIcons.shouldColorize("corpse_cleaner")
            color: UIIcons.iconColor("corpse_cleaner")
        }

        // Headline
        Label {
            text: UIStrings.ui.corpse_cleaner.title
            Layout.alignment: Qt.AlignHCenter
            font.pointSize: Kirigami.Theme.defaultFont.pointSize * 2
            font.weight: Font.DemiBold
        }

        // Description Box
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: Math.max(Kirigami.Units.gridUnit * 10, Math.min(Kirigami.Units.gridUnit * 40, page.width - Kirigami.Units.gridUnit * 4))
            implicitHeight: descLabel.implicitHeight + Kirigami.Units.largeSpacing * 2
            color: UIColors.theme.description_background_hex ? UIColors.theme.description_background_hex : Qt.darker(Kirigami.Theme.backgroundColor, UIColors.theme.description_darker_multiplier)
            border.color: SettingsManager.enableContrastBorders ? (UIColors.theme.border_color_hex ? UIColors.theme.border_color_hex : Kirigami.Theme.highlightColor) : Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.5)
            border.width: 1
            radius: SettingsManager.cornerRadius / 2

            Label {
                id: descLabel
                anchors.fill: parent
                anchors.margins: Kirigami.Units.largeSpacing
                text: UIStrings.ui.corpse_cleaner.description || (myTask ? myTask.description : "Scanner is not available.")
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }
        
        Item { Layout.preferredHeight: Kirigami.Units.largeSpacing }

        Button {
            text: UIStrings.ui.corpse_cleaner.btn_scan
            icon.name: "search"
            Layout.alignment: Qt.AlignHCenter
            onClicked: {
                if (myTask) {
                    myTask.calculate_size()
                }
            }
        }
        
        Label {
            text: myTask ? (myTask.reclaimedSpace !== "-- MB" ? myTask.reclaimedSpace : "") : ""
            font.italic: true
            color: Kirigami.Theme.neutralTextColor
            Layout.alignment: Qt.AlignHCenter
        }
    }
}
