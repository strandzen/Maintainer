import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

ItemDelegate {
    id: control
    property string iconSource: ""
    property string iconKey: ""
    property bool active: false
    
    Layout.fillWidth: true
    implicitHeight: Kirigami.Units.gridUnit * 2.5
    
    // Subtle background highlight for active/hover states
    background: Rectangle {
        color: control.active ? Qt.rgba(Kirigami.Theme.focusColor.r, Kirigami.Theme.focusColor.g, Kirigami.Theme.focusColor.b, 0.1) :
               control.down ? Kirigami.Theme.focusColor : 
               control.hovered ? Kirigami.Theme.hoverColor : "transparent"
        radius: Kirigami.Units.smallSpacing
        anchors.fill: parent
        anchors.margins: 2
    }

    padding: Kirigami.Units.largeSpacing

    contentItem: RowLayout {
        spacing: Kirigami.Units.largeSpacing
        
        Kirigami.Icon {
            source: control.iconSource
            Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
            Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
            isMask: true
            color: control.active ? Kirigami.Theme.focusColor : UIIcons.iconColor(control.iconKey, Kirigami.Theme.textColor)
            Layout.alignment: Qt.AlignVCenter
        }
        
        Label {
            text: control.text
            Layout.fillWidth: true
            elide: Text.ElideRight
            font.weight: Font.DemiBold
            visible: true
            opacity: control.width > (Kirigami.Units.iconSizes.smallMedium + (Kirigami.Units.largeSpacing * 3)) ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Kirigami.Units.shortDuration } }
            Layout.alignment: Qt.AlignVCenter
        }
    }
}
