import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Rectangle {
    id: root
    color: UIColors.theme.queue_background_hex ? UIColors.theme.queue_background_hex : Qt.darker(Kirigami.Theme.backgroundColor, UIColors.theme.queue_darker_multiplier)
    border.color: UIColors.theme.border_color_hex ? UIColors.theme.border_color_hex : Kirigami.Theme.highlightColor
    border.width: 1
    radius: SettingsManager.cornerRadius
    clip: true

    property bool isRunning: TaskEngine.currentTask !== null
    property bool isFinished: !isRunning && TaskEngine.overallProgress === 1.0
    property bool isReady: !isRunning && !isFinished
    
    // Links to Center Pane
    property var activeTaskModel: isHomeActive ? TaskRegistry.favoritesTaskModel : (myPageStack && myPageStack.currentItem ? myPageStack.currentItem.taskModel : null)
    property int selectedCount: activeTaskModel ? activeTaskModel.checkedCount : 0
    property bool isHomeActive: myPageStack && myPageStack.currentItem && myPageStack.currentItem.objectName === "landingPage"
    
    property bool isCompact: root.width < Kirigami.Units.gridUnit * 12
    property var currentModel: activeTaskModel
    
    TextMetrics {
        id: measureText
        font.weight: Font.DemiBold
    }
    
    property real idealWidth: Kirigami.Units.gridUnit * 18
    
    function updateIdealWidth() {
        let maxW = 0;
        if (activeTaskModel) {
            for (let i = 0; i < activeTaskModel.rowCount(); i++) {
                let task = activeTaskModel.get_task(i);
                if (task) {
                    measureText.text = task.name;
                    if (measureText.width > maxW) maxW = measureText.width;
                    
                    if (task.description) {
                        measureText.text = task.description;
                        if (measureText.width > maxW) maxW = measureText.width;
                    }
                }
            }
        }
        let calculated = Math.max(Kirigami.Units.gridUnit * 18, Math.min(mainWindow.width * 0.5, maxW + Kirigami.Units.gridUnit * 8));
        if (root.idealWidth !== calculated) {
            root.idealWidth = calculated;
        }
    }

    Timer {
        id: idealWidthTimer
        interval: 100
        repeat: false
        onTriggered: root.updateIdealWidth()
    }

    Connections {
        target: activeTaskModel
        function onRowsInserted() { idealWidthTimer.restart() }
        function onRowsRemoved() { idealWidthTimer.restart() }
        function onDataChanged() { idealWidthTimer.restart() }
    }

    Component.onCompleted: updateIdealWidth()
    
    property string ellipsis: ""
    Timer {
        interval: 500
        running: root.isRunning
        repeat: true
        onTriggered: {
            if (root.ellipsis === "...") {
                root.ellipsis = ""
            } else {
                root.ellipsis += "."
            }
        }
    }
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Kirigami.Units.largeSpacing
        spacing: Kirigami.Units.smallSpacing
        
        Kirigami.Heading {
            text: isRunning ? UIStrings.ui.running.title : 
                  isFinished ? UIStrings.ui.finished.title : "Action Queue"
            level: root.isCompact ? 4 : 2
            font.pointSize: root.isCompact ? Kirigami.Theme.defaultFont.pointSize : UIFonts.fonts.headline
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            visible: false // Removed headline as requested
        }

        Kirigami.Separator { Layout.fillWidth: true; opacity: 0.5; visible: false }
        
        // --- READY STATE (CHECKBOX LIST OR APPIMAGE LIST) ---
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: !!(isReady && currentModel && currentModel.rowCount() > 0)
            color: UIColors.theme.description_background_hex ? UIColors.theme.description_background_hex : Qt.darker(Kirigami.Theme.backgroundColor, UIColors.theme.description_darker_multiplier)
            border.color: UIColors.theme.border_color_hex ? UIColors.theme.border_color_hex : Kirigami.Theme.highlightColor
            border.width: 0 // Removed border as requested
            radius: Kirigami.Units.smallSpacing
            clip: true

            RowLayout {
                anchors.fill: parent
                spacing: 0

                ListView {
                    id: readyView
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: currentModel
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: readyScroll
                    
                    delegate: ItemDelegate {
                        id: readyDelegate
                        
                        width: readyView.width
                        height: implicitHeight
                        
                        background: Rectangle {
                            color: readyDelegate.hovered ? Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b, 0.1) : "transparent"
                        }

                        contentItem: ColumnLayout {
                            spacing: 0
                            RowLayout {
                                Layout.fillWidth: true
                                Layout.margins: Kirigami.Units.smallSpacing
                                spacing: Kirigami.Units.smallSpacing
                                
                                CheckBox {
                                    id: cbox
                                    checked: model.isChecked || false
                                    visible: model.name !== "Boot Audit" && !root.isCompact
                                    onCheckedChanged: {
                                        if (model.isChecked !== checked) {
                                            model.isChecked = checked
                                        }
                                    }
                                    Layout.alignment: Qt.AlignVCenter
                                }
                                

                                ColumnLayout {
                                    spacing: 0
                                    Layout.fillWidth: true
                                    visible: !root.isCompact
                                    
                                    Label {
                                        text: model.name
                                        Layout.fillWidth: true
                                        font.weight: Font.DemiBold
                                        elide: Text.ElideRight
                                    }
                                    
                                    Label {
                                        text: model.description || ""
                                        visible: text !== ""
                                        Layout.fillWidth: true
                                        font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.9
                                        color: Kirigami.Theme.neutralTextColor
                                        wrapMode: Text.Wrap
                                        elide: Text.NoWrap
                                    }
                                }

                                RowLayout {
                                    spacing: Kirigami.Units.smallSpacing
                                    Layout.alignment: root.isCompact ? Qt.AlignHCenter : (Qt.AlignVCenter | Qt.AlignRight)
                                    Layout.fillWidth: root.isCompact
                                    

                                    // Existing Task Icons
                                    Kirigami.Icon {
                                        id: recIcon
                                        source: UIIcons.icons.recommended || ""
                                        visible: model.isRecommended
                                        Layout.preferredWidth: Kirigami.Units.iconSizes.small
                                        Layout.preferredHeight: Kirigami.Units.iconSizes.small
                                        isMask: UIIcons.shouldColorize("recommended")
                                        color: UIIcons.iconColor("recommended", Kirigami.Theme.positiveTextColor)
                                        
                                        HoverHandler { id: recHover }
                                        ToolTip.text: UIStrings.ui.selection.tooltip_recommended || "Recommended"
                                        ToolTip.visible: recHover.hovered
                                        ToolTip.delay: Kirigami.Units.toolTipDelay
                                    }
                                    
                                    Kirigami.Icon {
                                        id: advIcon
                                        source: UIIcons.icons.advanced || ""
                                        visible: model.isAdvanced || false
                                        Layout.preferredWidth: Kirigami.Units.iconSizes.small
                                        Layout.preferredHeight: Kirigami.Units.iconSizes.small
                                        isMask: UIIcons.shouldColorize("advanced")
                                        color: UIIcons.iconColor("advanced", Kirigami.Theme.negativeTextColor)
                                        
                                        HoverHandler { id: advHover }
                                        ToolTip.text: UIStrings.ui.selection.tooltip_advanced || "Advanced Task"
                                        ToolTip.visible: advHover.hovered
                                        ToolTip.delay: Kirigami.Units.toolTipDelay
                                    }
                                    
                                    Kirigami.Icon {
                                        id: sudoIcon
                                        source: UIIcons.icons.sudo || ""
                                        visible: model.requiresPrivilege || false
                                        Layout.preferredWidth: Kirigami.Units.iconSizes.small
                                        Layout.preferredHeight: Kirigami.Units.iconSizes.small
                                        isMask: UIIcons.shouldColorize("sudo")
                                        color: UIIcons.iconColor("sudo", Kirigami.Theme.highlightColor)
                                        
                                        HoverHandler { id: sudoHover }
                                        ToolTip.text: UIStrings.ui.selection.tooltip_sudo || "Sudo required"
                                        ToolTip.visible: sudoHover.hovered
                                        ToolTip.delay: Kirigami.Units.toolTipDelay
                                    }

                                    Label {
                                        text: model.reclaimedSpace ? model.reclaimedSpace : ""
                                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                                        color: Kirigami.Theme.neutralTextColor
                                        visible: !root.isCompact && text !== "" && model.name !== "Boot Audit"
                                    }

                                    Button {
                                        text: "Audit"
                                        visible: model.name === "Boot Audit"
                                        Layout.alignment: Qt.AlignVCenter
                                        Layout.preferredHeight: Kirigami.Units.gridUnit * 1.2
                                        onClicked: {
                                            if (myPageStack) {
                                                myPageStack.replace(Qt.resolvedUrl("../pages/EfiAuditPage.qml"), {
                                                    "taskModel": activeTaskModel
                                                })
                                            }
                                        }
                                    }
                                }
                            }
                            Kirigami.Separator {
                                Layout.fillWidth: true
                                opacity: 0.3
                            }
                        }
                        onClicked: {
                            if (model.name !== "Boot Audit") {
                                cbox.checked = !cbox.checked
                            }
                        }
                    }
                }
                
                ScrollBar {
                    id: readyScroll
                    Layout.fillHeight: true
                    policy: ScrollBar.AlwaysOn
                    visible: readyView.contentHeight > readyView.height
                }
            }
        }
        
        // --- EMPTY QUEUE STATE ---
        Item {
            // Spacer to keep buttons at the bottom when list is empty
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: isReady && (!activeTaskModel || activeTaskModel.rowCount() === 0)
        }

        // --- RUNNING/FINISHED STATE (EXECUTION QUEUE) ---
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: !isReady && TaskEngine.queue.length > 0
            color: UIColors.theme.description_background_hex ? UIColors.theme.description_background_hex : Qt.darker(Kirigami.Theme.backgroundColor, UIColors.theme.description_darker_multiplier)
            border.color: UIColors.theme.border_color_hex ? UIColors.theme.border_color_hex : Kirigami.Theme.highlightColor
            border.width: 0 // Removed border as requested
            radius: Kirigami.Units.smallSpacing
            clip: true

            RowLayout {
                anchors.fill: parent
                spacing: 0

                ListView {
                    id: runningView
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: TaskEngine.queue
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: runningScroll
                    
                    delegate: ItemDelegate {
                        id: runningDelegate
                        width: runningView.width
                        height: visible ? implicitHeight : 0
                        
                        background: Rectangle {
                            color: runningDelegate.hovered ? Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b, 0.1) : "transparent"
                        }

                        contentItem: ColumnLayout {
                            spacing: 0
                            RowLayout {
                                Layout.fillWidth: true
                                Layout.margins: Kirigami.Units.smallSpacing
                                spacing: Kirigami.Units.smallSpacing
                                
                                ColumnLayout {
                                    spacing: 0
                                    Layout.fillWidth: true
                                    visible: !root.isCompact
                                    
                                    Label {
                                        text: {
                                            if (modelData.state === 1) return modelData.name + root.ellipsis
                                            return modelData.name
                                        }
                                        Layout.fillWidth: true
                                        font.italic: modelData.state === 1
                                        font.weight: modelData.state === 1 ? Font.DemiBold : Font.Normal
                                        elide: Text.ElideRight
                                        color: {
                                            if (modelData.state === 2) return Kirigami.Theme.positiveTextColor
                                            if (modelData.state === 3) return Kirigami.Theme.negativeTextColor
                                            return Kirigami.Theme.neutralTextColor
                                        }
                                    }
                                }
                                
                                Kirigami.Icon {
                                    visible: modelData.state === 2 || modelData.state === 3 || root.isCompact
                                    source: {
                                        if (modelData.state === 2) return (UIIcons.icons.success || "")
                                        if (modelData.state === 3) return (UIIcons.icons.error || "")
                                        // In compact mode, show an hourglass or running icon while it's in state 1
                                        return "media-playback-start"
                                    }
                                    Layout.preferredWidth: Kirigami.Units.iconSizes.small
                                    Layout.preferredHeight: Kirigami.Units.iconSizes.small
                                    Layout.alignment: root.isCompact ? Qt.AlignHCenter : Qt.AlignVCenter | Qt.AlignRight
                                    isMask: true
                                    color: {
                                        if (modelData.state === 2) return UIIcons.iconColor("success", Kirigami.Theme.positiveTextColor)
                                        if (modelData.state === 3) return UIIcons.iconColor("error", Kirigami.Theme.negativeTextColor)
                                        return UIIcons.iconColor("running", Kirigami.Theme.neutralTextColor)
                                    }
                                }
                            }
                            Kirigami.Separator {
                                Layout.fillWidth: true
                                opacity: 0.3
                            }
                        }
                    }
                }
                
                ScrollBar {
                    id: runningScroll
                    Layout.fillHeight: true
                    policy: ScrollBar.AlwaysOn
                    visible: runningView.contentHeight > runningView.height
                }
            }
        }
        
        Kirigami.Separator { 
            Layout.fillWidth: true
            opacity: 0.5
            visible: (isReady && activeTaskModel && activeTaskModel.rowCount() > 0) || (!isReady && TaskEngine.queue.length > 0)
        }

        Item {
            Layout.fillWidth: true
            implicitHeight: Kirigami.Units.gridUnit // Safer fixed height
            visible: isRunning

            ProgressBar {
                id: prog
                width: parent.width
                anchors.verticalCenter: parent.verticalCenter
                value: TaskEngine.overallProgress
            }
        }
        
        ScrollView {
            Layout.fillWidth: true
            Layout.preferredHeight: Kirigami.Units.gridUnit * 10
            visible: isRunning && TaskEngine.currentTask && TaskEngine.currentTask.isScript
            
            TextArea {
                readOnly: true
                color: "lightgreen"
                font.family: "monospace"
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                text: TaskEngine.currentTask ? TaskEngine.currentTask.outputHistory : ""
                wrapMode: Text.WrapAnywhere
                background: Rectangle { color: Qt.darker(Kirigami.Theme.backgroundColor, 1.2) }
                
                onTextChanged: {
                    cursorPosition = length
                }
            }
        }
        
        Button {
            text: UIStrings.ui.landing.run_recommended
            Layout.fillWidth: true
            Layout.preferredHeight: Kirigami.Units.gridUnit * 1.8
            visible: isReady && isHomeActive && selectedCount === 0
            icon.name: "media-playback-start"
            onClicked: {
                var recommendedModel = TaskRegistry.recommendedTasksModel
                if (recommendedModel) {
                    var tasks = recommendedModel.get_checked_tasks()
                    TaskEngine.start_tasks(tasks)
                }
            }
            background: Rectangle {
                color: parent.down ? Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b, 0.2) : 
                       parent.hovered ? Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b, 0.1) : "transparent"
                border.color: Kirigami.Theme.highlightColor
                border.width: 1
                radius: Kirigami.Units.smallSpacing
            }
        }

        Label {
            text: UIStrings.ui.landing.potential_savings + (TaskRegistry.recommendedTasksModel ? TaskRegistry.recommendedTasksModel.totalReclaimedSpaceStr : "")
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            color: "#ff8c00" // Standardize to orange from Image 1
            Layout.alignment: Qt.AlignHCenter
            visible: !root.isCompact && isReady && isHomeActive && selectedCount === 0 && TaskRegistry.recommendedTasksModel && TaskRegistry.recommendedTasksModel.totalPossibleReclaimedSpaceBytes > 0
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
        
        Label {
            text: activeTaskModel && activeTaskModel.totalReclaimedSpaceStr ? activeTaskModel.totalReclaimedSpaceStr : ""
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            color: "#ff8c00" // Standardize to orange from Image 1
            Layout.alignment: Qt.AlignHCenter
            visible: !root.isCompact && isReady && selectedCount > 0 && text !== ""
            horizontalAlignment: Text.AlignHCenter
        }

        Button {
            id: runSelectedBtn
            Layout.fillWidth: true
            Layout.preferredHeight: Kirigami.Units.gridUnit * 1.8
            visible: isReady && selectedCount > 0
            onClicked: {
                if (activeTaskModel) {
                    var tasks = activeTaskModel.get_checked_tasks()
                    TaskEngine.start_tasks(tasks)
                }
            }
            contentItem: RowLayout {
                spacing: Kirigami.Units.smallSpacing
                Layout.alignment: Qt.AlignHCenter
                Kirigami.Icon {
                    source: UIIcons.icons.run || ""
                    Layout.preferredWidth: Kirigami.Units.iconSizes.small
                    Layout.preferredHeight: Kirigami.Units.iconSizes.small
                    isMask: UIIcons.shouldColorize("run")
                    color: UIIcons.iconColor("run", Kirigami.Theme.highlightColor)
                }
                Label {
                    text: "Run (" + selectedCount + ")"
                    visible: !root.isCompact
                    color: Kirigami.Theme.textColor
                    verticalAlignment: Text.AlignVCenter
                    horizontalAlignment: Text.AlignHCenter
                    Layout.fillWidth: true
                }
            }
            background: Rectangle {
                color: runSelectedBtn.down ? Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b, 0.2) : 
                       runSelectedBtn.hovered ? Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b, 0.1) : "transparent"
                border.color: Kirigami.Theme.highlightColor
                border.width: 1
                radius: Kirigami.Units.smallSpacing
            }
            ToolTip.text: root.isCompact ? ("Run " + selectedCount + " Selected Task" + (selectedCount > 1 ? "s" : "")) : ""
            ToolTip.visible: root.isCompact && runSelectedBtn.hovered
        }



        // --- FINISHED STATE BUTTONS ---
        ColumnLayout {
            Layout.fillWidth: true
            visible: isFinished
            spacing: Kirigami.Units.smallSpacing

            Button {
                id: confirmBtn
                Layout.fillWidth: true
                onClicked: TaskEngine.reset()
                contentItem: RowLayout {
                    spacing: Kirigami.Units.smallSpacing
                    Kirigami.Icon {
                        source: UIIcons.icons.confirm || ""
                        Layout.preferredWidth: Kirigami.Units.iconSizes.small
                        Layout.preferredHeight: Kirigami.Units.iconSizes.small
                        isMask: UIIcons.shouldColorize("confirm")
                        color: UIIcons.iconColor("confirm", Kirigami.Theme.positiveTextColor)
                    }
                    Label {
                        text: "Confirm"
                        color: Kirigami.Theme.textColor
                        verticalAlignment: Text.AlignVCenter
                        horizontalAlignment: Text.AlignHCenter
                        Layout.fillWidth: true
                    }
                }
            }
            
            Button {
                id: quitBtn
                Layout.fillWidth: true
                onClicked: Qt.quit()
                contentItem: RowLayout {
                    spacing: Kirigami.Units.smallSpacing
                    Kirigami.Icon {
                        source: UIIcons.icons.quit || ""
                        Layout.preferredWidth: Kirigami.Units.iconSizes.small
                        Layout.preferredHeight: Kirigami.Units.iconSizes.small
                        isMask: UIIcons.shouldColorize("quit")
                        color: UIIcons.iconColor("quit", Kirigami.Theme.negativeTextColor)
                    }
                    Label {
                        text: "Quit"
                        color: Kirigami.Theme.textColor
                        verticalAlignment: Text.AlignVCenter
                        horizontalAlignment: Text.AlignHCenter
                        Layout.fillWidth: true
                    }
                }
            }
            
            Button {
                id: rebootBtn
                Layout.fillWidth: true
                onClicked: Qt.quit() 
                contentItem: RowLayout {
                    spacing: Kirigami.Units.smallSpacing
                    Kirigami.Icon {
                        source: UIIcons.icons.reboot || ""
                        Layout.preferredWidth: Kirigami.Units.iconSizes.small
                        Layout.preferredHeight: Kirigami.Units.iconSizes.small
                        isMask: UIIcons.shouldColorize("reboot")
                        color: UIIcons.iconColor("reboot", Kirigami.Theme.highlightColor)
                    }
                    Label {
                        text: "Reboot"
                        color: Kirigami.Theme.textColor
                        verticalAlignment: Text.AlignVCenter
                        horizontalAlignment: Text.AlignHCenter
                        Layout.fillWidth: true
                    }
                }
            }
        }

    }
}
