import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import org.kde.kirigami as Kirigami

Rectangle {
    id: root

    property string title: ""
    property string currentText: ""
    property var values: []
    property color accentColor: Kirigami.Theme.highlightColor
    property bool autoScale: false

    color: UIColors.theme.description_background_hex
        ? UIColors.theme.description_background_hex
        : Qt.darker(Kirigami.Theme.backgroundColor, UIColors.theme.description_darker_multiplier)
    border.color: SettingsManager.enableContrastBorders ? (UIColors.theme.border_color_hex ? UIColors.theme.border_color_hex : Kirigami.Theme.highlightColor) : Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.5)
    border.width: 1
    radius: SettingsManager.cornerRadius / 2
    clip: true

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Kirigami.Units.largeSpacing
        spacing: Kirigami.Units.smallSpacing

        // Header row: title on left, value on right
        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            Label {
                text: root.title
                font.weight: Font.DemiBold
                color: root.accentColor
            }

            Item { Layout.fillWidth: true }

            Label {
                text: root.currentText
                font.weight: Font.DemiBold
                color: root.accentColor
            }
        }

        // Sparkline fills the remaining vertical space
        SparklineGraph {
            Layout.fillWidth: true
            Layout.fillHeight: true
            values: root.values
            autoScale: root.autoScale
            lineColor: root.accentColor
            fillColor: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.18)
        }
    }
}
