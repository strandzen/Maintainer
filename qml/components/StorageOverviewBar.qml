import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Item {
    id: root
    implicitHeight: layout.implicitHeight + Kirigami.Units.smallSpacing * 2
    implicitWidth: 300
    
    readonly property color accentColor: Kirigami.Theme.highlightColor

    function _paletteColor(index) {
        var baseHue = accentColor.hsvHue < 0 ? 0.0 : accentColor.hsvHue
        var hue = (baseHue + index / 6.0) % 1.0
        var sat = Math.max(0.55, accentColor.hsvSaturation)
        var val = Math.max(0.65, Math.min(0.92, accentColor.hsvValue))
        return Qt.hsva(hue, sat, val, 1.0)
    }

    readonly property color colorPackages:   _paletteColor(0)
    readonly property color colorGames:      _paletteColor(1)
    readonly property color colorMedia:      _paletteColor(2)
    readonly property color colorDownloads:  _paletteColor(3)
    readonly property color colorVMs:        _paletteColor(4)
    readonly property color colorCacheTrash: _paletteColor(5)

    // Properties to bind from SystemHealth
    property real appsSize: 0
    property real mediaSize: 0
    property real gamesSize: 0
    property real downloadsSize: 0
    property real vmsSize: 0
    property real trashCacheSize: 0
    property real otherSize: 0
    property real totalUsedSize: 0
    property real totalDiskSize: 1
    
    function formatBytes(bytes) {
        if (!bytes || bytes <= 0) return "0 B";
        var k = 1024,
            sizes = ['B', 'KiB', 'MiB', 'GiB', 'TiB'],
            i = Math.floor(Math.log(bytes) / Math.log(k));
        if (i < 0) return bytes + " B";
        return parseFloat((bytes / Math.pow(k, i)).toFixed(1)) + ' ' + sizes[i];
    }

    readonly property var _segmentSizes: [appsSize, gamesSize, mediaSize, downloadsSize, vmsSize, trashCacheSize, otherSize]

    function isFirstVisible(index) {
        for (var i = 0; i < index; i++) {
            if (_segmentSizes[i] > 0) return false;
        }
        return _segmentSizes[index] > 0;
    }

    function isLastVisible(index) {
        for (var i = index + 1; i < _segmentSizes.length; i++) {
            if (_segmentSizes[i] > 0) return false;
        }
        return _segmentSizes[index] > 0;
    }

    ColumnLayout {
        id: layout
        width: parent.width
        spacing: Kirigami.Units.smallSpacing

        // Header
        RowLayout {
            Layout.fillWidth: true
            Label {
                text: "Storage"
                font.weight: Font.DemiBold
            }
            Item { Layout.fillWidth: true }
            Label {
                text: formatBytes(root.totalUsedSize) + " of " + formatBytes(root.totalDiskSize)
                color: Kirigami.Theme.disabledTextColor
                font.pointSize: Kirigami.Theme.smallFont.pointSize
            }
        }

        // Bar
        Rectangle {
            id: barFrame
            Layout.fillWidth: true
            Layout.preferredHeight: Kirigami.Units.gridUnit
            radius: SettingsManager.cornerRadius
            color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.1)
            border.color: UIColors.theme.border_color_hex ? UIColors.theme.border_color_hex : Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.3)
            border.width: 1

            Row {
                anchors.fill: parent
                // Packages
                Kirigami.ShadowedRectangle {
                    height: parent.height
                    width: root.totalDiskSize > 0 ? (root.appsSize / root.totalDiskSize) * parent.width : 0
                    color: root.colorPackages
                    visible: width > 0
                    corners.topLeftRadius: isFirstVisible(0) ? barFrame.radius : 0
                    corners.bottomLeftRadius: isFirstVisible(0) ? barFrame.radius : 0
                    corners.topRightRadius: isLastVisible(0) ? barFrame.radius : 0
                    corners.bottomRightRadius: isLastVisible(0) ? barFrame.radius : 0
                    MouseArea { 
                        id: pkgMouse; 
                        anchors.fill: parent; 
                        hoverEnabled: true
                        ToolTip.visible: containsMouse
                        ToolTip.delay: 500
                        ToolTip.text: formatBytes(root.appsSize)
                    }
                }
                // Games
                Kirigami.ShadowedRectangle {
                    height: parent.height
                    width: root.totalDiskSize > 0 ? (root.gamesSize / root.totalDiskSize) * parent.width : 0
                    color: root.colorGames
                    visible: width > 0
                    corners.topLeftRadius: isFirstVisible(1) ? barFrame.radius : 0
                    corners.bottomLeftRadius: isFirstVisible(1) ? barFrame.radius : 0
                    corners.topRightRadius: isLastVisible(1) ? barFrame.radius : 0
                    corners.bottomRightRadius: isLastVisible(1) ? barFrame.radius : 0
                    MouseArea { 
                        id: gamesMouse; 
                        anchors.fill: parent; 
                        hoverEnabled: true
                        ToolTip.visible: containsMouse
                        ToolTip.delay: 500
                        ToolTip.text: formatBytes(root.gamesSize)
                    }
                }
                // Media
                Kirigami.ShadowedRectangle {
                    height: parent.height
                    width: root.totalDiskSize > 0 ? (root.mediaSize / root.totalDiskSize) * parent.width : 0
                    color: root.colorMedia
                    visible: width > 0
                    corners.topLeftRadius: isFirstVisible(2) ? barFrame.radius : 0
                    corners.bottomLeftRadius: isFirstVisible(2) ? barFrame.radius : 0
                    corners.topRightRadius: isLastVisible(2) ? barFrame.radius : 0
                    corners.bottomRightRadius: isLastVisible(2) ? barFrame.radius : 0
                    MouseArea { 
                        id: mediaMouse; 
                        anchors.fill: parent; 
                        hoverEnabled: true
                        ToolTip.visible: containsMouse
                        ToolTip.delay: 500
                        ToolTip.text: formatBytes(root.mediaSize)
                    }
                }
                // Downloads
                Kirigami.ShadowedRectangle {
                    height: parent.height
                    width: root.totalDiskSize > 0 ? (root.downloadsSize / root.totalDiskSize) * parent.width : 0
                    color: root.colorDownloads
                    visible: width > 0
                    corners.topLeftRadius: isFirstVisible(3) ? barFrame.radius : 0
                    corners.bottomLeftRadius: isFirstVisible(3) ? barFrame.radius : 0
                    corners.topRightRadius: isLastVisible(3) ? barFrame.radius : 0
                    corners.bottomRightRadius: isLastVisible(3) ? barFrame.radius : 0
                    MouseArea { 
                        id: dlMouse; 
                        anchors.fill: parent; 
                        hoverEnabled: true
                        ToolTip.visible: containsMouse
                        ToolTip.delay: 500
                        ToolTip.text: formatBytes(root.downloadsSize)
                    }
                }
                // VMs
                Kirigami.ShadowedRectangle {
                    height: parent.height
                    width: root.totalDiskSize > 0 ? (root.vmsSize / root.totalDiskSize) * parent.width : 0
                    color: root.colorVMs
                    visible: width > 0
                    corners.topLeftRadius: isFirstVisible(4) ? barFrame.radius : 0
                    corners.bottomLeftRadius: isFirstVisible(4) ? barFrame.radius : 0
                    corners.topRightRadius: isLastVisible(4) ? barFrame.radius : 0
                    corners.bottomRightRadius: isLastVisible(4) ? barFrame.radius : 0
                    MouseArea { 
                        id: vmsMouse; 
                        anchors.fill: parent; 
                        hoverEnabled: true
                        ToolTip.visible: containsMouse
                        ToolTip.delay: 500
                        ToolTip.text: formatBytes(root.vmsSize)
                    }
                }
                // Cache/Trash
                Kirigami.ShadowedRectangle {
                    height: parent.height
                    width: root.totalDiskSize > 0 ? (root.trashCacheSize / root.totalDiskSize) * parent.width : 0
                    color: root.colorCacheTrash
                    visible: width > 0
                    corners.topLeftRadius: isFirstVisible(5) ? barFrame.radius : 0
                    corners.bottomLeftRadius: isFirstVisible(5) ? barFrame.radius : 0
                    corners.topRightRadius: isLastVisible(5) ? barFrame.radius : 0
                    corners.bottomRightRadius: isLastVisible(5) ? barFrame.radius : 0
                    MouseArea { 
                        id: cacheMouse; 
                        anchors.fill: parent; 
                        hoverEnabled: true
                        ToolTip.visible: containsMouse
                        ToolTip.delay: 500
                        ToolTip.text: formatBytes(root.trashCacheSize)
                    }
                }
                // System
                Kirigami.ShadowedRectangle {
                    height: parent.height
                    width: root.totalDiskSize > 0 ? (root.otherSize / root.totalDiskSize) * parent.width : 0
                    color: Kirigami.Theme.disabledTextColor
                    visible: width > 0
                    corners.topLeftRadius: isFirstVisible(6) ? barFrame.radius : 0
                    corners.bottomLeftRadius: isFirstVisible(6) ? barFrame.radius : 0
                    corners.topRightRadius: isLastVisible(6) ? barFrame.radius : 0
                    corners.bottomRightRadius: isLastVisible(6) ? barFrame.radius : 0
                    MouseArea { 
                        id: otherMouse; 
                        anchors.fill: parent; 
                        hoverEnabled: true
                        ToolTip.visible: containsMouse
                        ToolTip.delay: 500
                        ToolTip.text: formatBytes(root.otherSize)
                    }
                }
            }
        }

        // Legend
        Flow {
            Layout.fillWidth: true
            spacing: Kirigami.Units.largeSpacing
            
            // Packages
            Row {
                spacing: Kirigami.Units.smallSpacing
                Rectangle { width: 8; height: 8; radius: 4; color: root.colorPackages; anchors.verticalCenter: parent.verticalCenter }
                Label { text: "Packages"; font.pointSize: Kirigami.Theme.smallFont.pointSize; color: Kirigami.Theme.disabledTextColor }
            }
            // Games
            Row {
                spacing: Kirigami.Units.smallSpacing
                Rectangle { width: 8; height: 8; radius: 4; color: root.colorGames; anchors.verticalCenter: parent.verticalCenter }
                Label { text: "Games"; font.pointSize: Kirigami.Theme.smallFont.pointSize; color: Kirigami.Theme.disabledTextColor }
            }
            // Media
            Row {
                spacing: Kirigami.Units.smallSpacing
                Rectangle { width: 8; height: 8; radius: 4; color: root.colorMedia; anchors.verticalCenter: parent.verticalCenter }
                Label { text: "Media"; font.pointSize: Kirigami.Theme.smallFont.pointSize; color: Kirigami.Theme.disabledTextColor }
            }
            // Downloads
            Row {
                spacing: Kirigami.Units.smallSpacing
                Rectangle { width: 8; height: 8; radius: 4; color: root.colorDownloads; anchors.verticalCenter: parent.verticalCenter }
                Label { text: "Downloads"; font.pointSize: Kirigami.Theme.smallFont.pointSize; color: Kirigami.Theme.disabledTextColor }
            }
            // VMs
            Row {
                spacing: Kirigami.Units.smallSpacing
                Rectangle { width: 8; height: 8; radius: 4; color: root.colorVMs; anchors.verticalCenter: parent.verticalCenter }
                Label { text: "VMs"; font.pointSize: Kirigami.Theme.smallFont.pointSize; color: Kirigami.Theme.disabledTextColor }
            }
            // Cache/Trash
            Row {
                spacing: Kirigami.Units.smallSpacing
                Rectangle { width: 8; height: 8; radius: 4; color: root.colorCacheTrash; anchors.verticalCenter: parent.verticalCenter }
                Label { text: "Cache / Trash"; font.pointSize: Kirigami.Theme.smallFont.pointSize; color: Kirigami.Theme.disabledTextColor }
            }
            // Other
            Row {
                spacing: Kirigami.Units.smallSpacing
                Rectangle { width: 8; height: 8; radius: 4; color: Kirigami.Theme.disabledTextColor; anchors.verticalCenter: parent.verticalCenter }
                Label { text: "System"; font.pointSize: Kirigami.Theme.smallFont.pointSize; color: Kirigami.Theme.disabledTextColor }
            }
        }
    }
}
