import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../components"

Kirigami.ScrollablePage {
    id: page
    objectName: "landingPage"
    title: UIStrings.ui.landing.title

    readonly property real customContentWidth: Math.max(Kirigami.Units.gridUnit * 10, Math.min(Kirigami.Units.gridUnit * 40, page.width - Kirigami.Units.gridUnit * 4))

    titleDelegate: Item {}

    ColumnLayout {
        width: page.width
        anchors.margins: Kirigami.Units.largeSpacing
        spacing: Kirigami.Units.largeSpacing * 2
        
        Item {
            // Spacer
            Layout.fillWidth: true
            Layout.preferredHeight: Kirigami.Units.gridUnit * 2
        }

        // Top Icon
        Kirigami.Icon {
            Layout.alignment: Qt.AlignHCenter
            source: UIIcons.icons.app_main || ""
            Layout.preferredWidth: Kirigami.Units.iconSizes.huge * UIIcons.headerIconScale
            Layout.preferredHeight: Kirigami.Units.iconSizes.huge * UIIcons.headerIconScale
            isMask: UIIcons.shouldColorize("app_main")
            color: UIIcons.iconColor("app_main", "")
        }

        // Project Name
        Label {
            Layout.alignment: Qt.AlignHCenter
            text: UIStrings.ui.landing.app_name
            font.pointSize: Kirigami.Theme.defaultFont.pointSize * 2
            font.weight: Font.DemiBold
            horizontalAlignment: Text.AlignHCenter
            Layout.bottomMargin: Kirigami.Units.largeSpacing
        }
        

        // Description
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: page.customContentWidth
            implicitHeight: descLabel.implicitHeight + Kirigami.Units.largeSpacing * 2
            color: UIColors.theme.description_background_hex ? UIColors.theme.description_background_hex : Qt.darker(Kirigami.Theme.backgroundColor, UIColors.theme.description_darker_multiplier)
            border.color: SettingsManager.enableContrastBorders ? (UIColors.theme.border_color_hex ? UIColors.theme.border_color_hex : Kirigami.Theme.highlightColor) : Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.5)
            border.width: 1
            radius: SettingsManager.cornerRadius / 2

            Label {
                id: descLabel
                anchors.fill: parent
                anchors.margins: Kirigami.Units.largeSpacing
                text: UIStrings.ui.landing.app_description
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }
        
        Item { Layout.fillHeight: true } // Spacer pushes everything up cleanly
    }
}
