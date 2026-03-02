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

        // Header: Icon and Main task
        ColumnLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Icon {
                source: {
                    var headerKey = page.categoryId + "_header"
                    if (UIIcons.icons[headerKey]) {
                        return UIIcons.icons[headerKey]
                    }
                    return page.categoryIcon !== "" ? (UIIcons.icons[page.categoryIcon] || "") : (UIIcons.icons.app_main || "")
                }
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: Kirigami.Units.iconSizes.huge * UIIcons.headerIconScale
                Layout.preferredHeight: Kirigami.Units.iconSizes.huge * UIIcons.headerIconScale
                isMask: {
                    var headerKey = page.categoryId + "_header"
                    if (UIIcons.icons[headerKey]) {
                        return UIIcons.shouldColorize(headerKey)
                    }
                    return UIIcons.shouldColorize(page.categoryIcon !== "" ? page.categoryIcon : "app_main")
                }
                color: {
                    var headerKey = page.categoryId + "_header"
                    if (UIIcons.icons[headerKey]) {
                        return UIIcons.iconColor(headerKey, "")
                    }
                    return UIIcons.iconColor(page.categoryIcon !== "" ? page.categoryIcon : "app_main", "")
                }
            }

            Label {
                text: page.pageTitle
                Layout.alignment: Qt.AlignHCenter
                font.pointSize: Kirigami.Theme.defaultFont.pointSize * 2
                font.weight: Font.DemiBold
            }
        }

        // Description
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: Math.max(Kirigami.Units.gridUnit * 10, Math.min(Kirigami.Units.gridUnit * 40, page.width - Kirigami.Units.gridUnit * 4))
            implicitHeight: descLabel.implicitHeight + Kirigami.Units.largeSpacing * 2
            color: UIColors.theme.description_background_hex ? UIColors.theme.description_background_hex : Qt.darker(Kirigami.Theme.backgroundColor, UIColors.theme.description_darker_multiplier)
            border.color: UIColors.theme.border_color_hex ? UIColors.theme.border_color_hex : Kirigami.Theme.highlightColor
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
