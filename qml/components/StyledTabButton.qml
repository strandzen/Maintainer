import QtQuick
import QtQuick.Controls
import org.kde.kirigami as Kirigami

TabButton {
    id: root

    contentItem: Label {
        text: root.text
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        color: root.checked ? Kirigami.Theme.textColor : Kirigami.Theme.disabledTextColor
        font.weight: root.checked ? Font.Bold : Font.Normal
    }

    background: Rectangle {
        color: root.checked
               ? Qt.rgba(Kirigami.Theme.highlightColor.r,
                         Kirigami.Theme.highlightColor.g,
                         Kirigami.Theme.highlightColor.b, 0.2)
               : "transparent"
        radius: Kirigami.Units.smallSpacing
    }
}
