import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Kirigami.ScrollablePage {
    id: page
    background: null
    
    // Properties that can be set when this page is pushed/replaced
    property string pageTitle: "Main Task"
    property var taskModel: null
    property string categoryIcon: ""
    property string categoryId: ""

    title: pageTitle

    titleDelegate: Item {}

    // Actions moved to the persistent right pane

    ColumnLayout {
        width: page.width
        spacing: Kirigami.Units.largeSpacing

        // Description
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: Math.max(Kirigami.Units.gridUnit * 10, Math.min(Kirigami.Units.gridUnit * 40, page.width - Kirigami.Units.gridUnit * 4))
            implicitHeight: descLabel.implicitHeight + Kirigami.Units.largeSpacing * 2
            color: UIColors.theme.description_background_hex ? UIColors.theme.description_background_hex : Qt.darker(Kirigami.Theme.backgroundColor, UIColors.theme.description_darker_multiplier)
            border.color: SettingsManager.enableContrastBorders ? (UIColors.theme.border_color_hex ? UIColors.theme.border_color_hex : Kirigami.Theme.highlightColor) : Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.5)
            border.width: 1
            radius: SettingsManager.cornerRadius / 2
            visible: UIStrings.ui[categoryId] !== undefined && UIStrings.ui[categoryId].description !== undefined

            Label {
                id: descLabel
                anchors.fill: parent
                anchors.margins: Kirigami.Units.largeSpacing
                text: UIStrings.ui[categoryId] !== undefined && UIStrings.ui[categoryId].description !== undefined ? UIStrings.ui[categoryId].description : ""
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }

        // Task list has been moved to the Right Pane (TaskProgressPane)
        
        Label {
            text: "Select tasks from the Action Queue on the right to execute."
            color: Kirigami.Theme.disabledTextColor
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Kirigami.Units.largeSpacing * 2
        }
    }
}
