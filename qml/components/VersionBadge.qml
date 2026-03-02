import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// A small status chip showing update state
Rectangle {
    id: badge

    property string status: "idle"  // idle | checking | available | up-to-date | error | downloading

    implicitHeight: badgeLabel.implicitHeight + Kirigami.Units.smallSpacing
    implicitWidth: badgeRow.implicitWidth + Kirigami.Units.largeSpacing

    radius: height / 2
    color: Qt.rgba(badgeColor.r, badgeColor.g, badgeColor.b, 0.15)
    border.color: Qt.rgba(badgeColor.r, badgeColor.g, badgeColor.b, 0.6)
    border.width: 1

    property color badgeColor: {
        switch (badge.status) {
            case "available":    return Kirigami.Theme.neutralTextColor
            case "up-to-date":  return Kirigami.Theme.positiveTextColor
            case "error":       return Kirigami.Theme.negativeTextColor
            case "checking":    return Kirigami.Theme.highlightColor
            case "downloading": return Kirigami.Theme.highlightColor
            default:            return Kirigami.Theme.disabledTextColor
        }
    }

    RowLayout {
        id: badgeRow
        anchors.centerIn: parent
        spacing: Kirigami.Units.smallSpacing / 2

        BusyIndicator {
            id: spinner
            visible: badge.status === "checking" || badge.status === "downloading"
            running: visible
            implicitWidth: badgeLabel.implicitHeight
            implicitHeight: badgeLabel.implicitHeight
            padding: 0
        }

        Label {
            id: badgeLabel
            text: {
                switch (badge.status) {
                    case "available":    return "Update available"
                    case "up-to-date":  return "Up to date"
                    case "error":       return "Check failed"
                    case "checking":    return "Checking…"
                    case "downloading": return "Downloading…"
                    default:            return "Not checked"
                }
            }
            font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.85
            font.weight: Font.Medium
            color: badge.badgeColor
        }
    }
}
