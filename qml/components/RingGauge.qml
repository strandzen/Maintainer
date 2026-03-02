import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Shapes
import org.kde.kirigami as Kirigami

Item {
    id: root
    property real value: 0.0 // 0.0 to 1.0
    property string text: ""
    property string subText: ""

    implicitWidth: 100
    implicitHeight: 100

    Shape {
        anchors.fill: parent
        layer.enabled: true
        layer.samples: 4

        // Background Ring
        ShapePath {
            fillColor: "transparent"
            strokeColor: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.1)
            strokeWidth: 8
            capStyle: ShapePath.RoundCap

            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: root.width / 2 - 8
                radiusY: root.height / 2 - 8
                startAngle: 0
                sweepAngle: 360
            }
        }

        // Foreground Ring
        ShapePath {
            fillColor: "transparent"
            strokeColor: Kirigami.Theme.highlightColor
            strokeWidth: 8
            capStyle: ShapePath.RoundCap

            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: root.width / 2 - 8
                radiusY: root.height / 2 - 8
                startAngle: -90
                sweepAngle: root.value * 360
            }
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 0

        Label {
            text: root.text
            font.weight: Font.DemiBold
            font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.2
            Layout.alignment: Qt.AlignHCenter
        }
        
        Label {
            text: root.subText
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            color: UIColors.theme.neutral_text_hex || Kirigami.Theme.neutralTextColor
            Layout.alignment: Qt.AlignHCenter
            visible: root.subText !== ""
        }
    }
}
