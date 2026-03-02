import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Kirigami.ScrollablePage {
    id: page
    objectName: "appImageManagerPage"
    background: null
    title: "AppImages"

    titleDelegate: Item {}

    Component.onCompleted: AppImageManager.scan()

    ColumnLayout {
        width: page.width
        spacing: Kirigami.Units.largeSpacing

        Kirigami.Icon {
            source: "application-x-executable"
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: Kirigami.Units.iconSizes.huge * UIIcons.headerIconScale
            Layout.preferredHeight: Kirigami.Units.iconSizes.huge * UIIcons.headerIconScale
            isMask: true
            color: UIIcons.iconColor("appimage_manager", Kirigami.Theme.highlightColor)
        }

        Label {
            text: "AppImages"
            Layout.alignment: Qt.AlignHCenter
            font.pointSize: Kirigami.Theme.defaultFont.pointSize * 2
            font.weight: Font.DemiBold
        }

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
                text: "Browse and manage portable AppImage applications. Check for updates on GitHub or browse the community catalog."
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }
    }
}
