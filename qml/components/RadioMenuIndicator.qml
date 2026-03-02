import QtQuick
import org.kde.kirigami as Kirigami

Item {
    property bool isChecked: false
    implicitWidth: Kirigami.Units.iconSizes.small
    implicitHeight: Kirigami.Units.iconSizes.small

    Rectangle {
        anchors.centerIn: parent
        width: parent.width - 2
        height: width
        radius: width / 2
        border.color: isChecked ? Kirigami.Theme.highlightColor : Kirigami.Theme.disabledTextColor
        border.width: 1
        color: "transparent"

        Rectangle {
            anchors.centerIn: parent
            width: parent.width / 2
            height: width
            radius: width / 2
            color: Kirigami.Theme.highlightColor
            visible: isChecked
        }
    }
}
