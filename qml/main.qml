import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "components" as MyComponents
import "Utils.js" as Utils

ApplicationWindow {
    id: mainWindow
    width: 1050
    height: 700
    visible: true
    title: UIStrings.ui.main.title


    color: UIColors.theme.window_background_hex ? UIColors.theme.window_background_hex : Qt.darker(Kirigami.Theme.backgroundColor, UIColors.theme.window_darker_multiplier) // Darker window background to pop panels

    // Confirmation Dialog State
    property var confirmItems: []
    property string confirmTotal: ""
    property var activeCleaningTask: null
    property int confirmUpdateTrigger: 0

    // Sidebar State
    property string currentSidebarId: "home"


    // Custom Header removed. Relying on system window decorations.

    SplitView {
        anchors.fill: parent
        anchors.margins: Kirigami.Units.largeSpacing
        // We'll use a small spacing natively with split handle
        
        handle: Rectangle {
            implicitWidth: Kirigami.Units.largeSpacing
            color: SplitHandle.pressed ? Kirigami.Theme.focusColor : 
                   (SplitHandle.hovered ? Kirigami.Theme.hoverColor : "transparent")
            
            // Add a small visible line indicator for dragging
            Rectangle {
                width: 2
                height: Kirigami.Units.gridUnit * 2
                color: Kirigami.Theme.disabledTextColor
                anchors.centerIn: parent
                radius: 1
            }

            Connections {
                target: SplitHandle
                function onPressedChanged() {
                    if (!SplitHandle.pressed) {
                        try {
                            if (index === 0) { // left handle
                                var midLeft = (leftSidebar.SplitView.minimumWidth + leftSidebar.SplitView.maximumWidth) / 2;
                                leftSidebar.SplitView.preferredWidth = (leftSidebar.width < midLeft) ? leftSidebar.SplitView.minimumWidth : leftSidebar.SplitView.maximumWidth;
                            }
                        } catch(e) {}
                    }
                }
            }
        }

        // 1. Sidebar
        Rectangle {
            id: leftSidebar
            SplitView.preferredWidth: leftSidebarLayout.implicitWidth
            SplitView.minimumWidth: Kirigami.Units.iconSizes.smallMedium + (Kirigami.Units.largeSpacing * 2) // Exactly Left Margin + Icon Width + Right Margin
            // Limit expansion to exactly the implicit width of the column layout, which naturally holds the widest text plus paddings
            SplitView.maximumWidth: leftSidebarLayout.implicitWidth
            
            color: UIColors.theme.sidebar_background_hex ? UIColors.theme.sidebar_background_hex : Qt.darker(Kirigami.Theme.backgroundColor, UIColors.theme.sidebar_darker_multiplier)
            border.color: UIColors.theme.border_color_hex ? UIColors.theme.border_color_hex : Kirigami.Theme.highlightColor
            border.width: 1
            radius: SettingsManager.cornerRadius
            clip: true // Prevents children from spilling out of rounded corners

            ColumnLayout {
                id: leftSidebarLayout
                anchors.fill: parent
                spacing: 0

                ColumnLayout {
                    id: itemsLayout
                    Layout.fillWidth: true
                    spacing: 0
                    
                    Repeater {
                        model: SidebarModel
                        delegate: Loader {
                            Layout.fillWidth: true
                            
                            sourceComponent: {
                                if (model.modelType === "separator") return separatorDelegate;
                                if (model.modelType === "label") return labelDelegate;
                                return itemDelegate;
                            }
                            
                            // Pass model data to the loaded component securely
                            property var itemModel: model
                        }
                    }
                }
                
                Component {
                    id: separatorDelegate
                    Item {
                        width: parent ? parent.width : 0
                        height: Kirigami.Units.smallSpacing * 2 + 1
                        Kirigami.Separator {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.leftMargin: Kirigami.Units.largeSpacing
                            anchors.rightMargin: Kirigami.Units.largeSpacing
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
                
                Component {
                    id: labelDelegate
                    Label {
                        width: parent ? parent.width : 0
                        text: itemModel.modelName
                        font.weight: Font.Bold
                        color: Kirigami.Theme.disabledTextColor
                        leftPadding: Kirigami.Units.largeSpacing
                        rightPadding: Kirigami.Units.largeSpacing
                        topPadding: Kirigami.Units.largeSpacing
                        bottomPadding: Kirigami.Units.largeSpacing
                        visible: true
                        opacity: leftSidebar.width > (Kirigami.Units.iconSizes.smallMedium + (Kirigami.Units.largeSpacing * 3)) ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: Kirigami.Units.shortDuration } }
                    }
                }
                
                Component {
                    id: itemDelegate
                    MyComponents.SidebarItem {
                        width: parent ? parent.width : 0
                        iconKey: itemModel.modelIcon
                        text: {
                            // Automatically lookup static pages in UIStrings
                            if (itemModel.modelType === "page") {
                                return UIStrings.ui.main[itemModel.modelId] || itemModel.modelName;
                            }
                            return itemModel.modelName;
                        }
                        iconSource: UIIcons.icons[itemModel.modelIcon] || ""
                        active: mainWindow.currentSidebarId === itemModel.modelId
                        onClicked: {
                            mainWindow.currentSidebarId = itemModel.modelId
                            while (myPageStack.depth > 1) { myPageStack.pop(); }
                            
                            if (itemModel.modelType === "page") {
                                myPageStack.replace(Qt.resolvedUrl(itemModel.modelUrl));
                            } else if (itemModel.modelType === "category") {
                                if (itemModel.modelId === "corpse_cleaner") {
                                    myPageStack.replace(Qt.resolvedUrl("pages/CorpseCleanerPage.qml"));
                                } else if (itemModel.modelId === "boot_audit") {
                                    myPageStack.replace(Qt.resolvedUrl("pages/EfiAuditPage.qml"), {
                                        "taskModel": TaskRegistry.getModelForCategory(itemModel.modelId)
                                    });
                                } else {
                                    var specificModel = TaskRegistry.getModelForCategory(itemModel.modelId);
                                    myPageStack.replace(Qt.resolvedUrl("pages/TaskSelectionPage.qml"), {
                                        "pageTitle": itemModel.modelName,
                                        "taskModel": specificModel,
                                        "categoryIcon": itemModel.modelIcon,
                                        "categoryId": itemModel.modelId
                                    });
                                }
                            }
                        }
                    }
                }
                
                Item { Layout.fillHeight: true } // Spacer
            }
        }

        // 2. Central Content
        ColumnLayout {
            id: centerColumn
            SplitView.fillWidth: myPageStack.currentItem && myPageStack.currentItem.objectName !== "packageManagerPage" && myPageStack.currentItem.objectName !== "appImageManagerPage"
            Layout.preferredWidth: visible ? -1 : 0
            visible: !myPageStack.currentItem || (myPageStack.currentItem.objectName !== "packageManagerPage" && myPageStack.currentItem.objectName !== "appImageManagerPage")
            
            Kirigami.PageRow {
                id: myPageStack
                Layout.fillWidth: true
                Layout.fillHeight: true
                defaultColumnWidth: width
                initialPage: Qt.resolvedUrl("pages/LandingPage.qml")
            }

            // Persistent Status Bars removed
        }

        // 3. Right Progress
        Loader {
            id: rightPaneLoader
            SplitView.fillWidth: myPageStack.currentItem && (myPageStack.currentItem.objectName === "packageManagerPage" || myPageStack.currentItem.objectName === "appImageManagerPage")
            SplitView.preferredWidth: {
                if (myPageStack.currentItem && (myPageStack.currentItem.objectName === "packageManagerPage" || myPageStack.currentItem.objectName === "appImageManagerPage")) return -1;
                return item && item.idealWidth ? item.idealWidth : Kirigami.Units.gridUnit * 18
            }
            SplitView.minimumWidth: Kirigami.Units.gridUnit * 10
            visible: myPageStack.currentItem
                     && myPageStack.currentItem.objectName !== "settingsPage"
                     && myPageStack.currentItem.objectName !== "systemMonitorPage"
            
            // Swap between regular Action Queue and Corpse Cleaner Results
            sourceComponent: {
                if (!myPageStack.currentItem) return null;
                if (myPageStack.currentItem.objectName === "corpseCleanerPage") {
                    return corpseCleanerComponent;
                }
                if (myPageStack.currentItem.objectName === "efiAuditPage") {
                    return efiAuditComponent;
                }
                if (myPageStack.currentItem.objectName === "packageManagerPage") {
                    return packageManagerComponent;
                }
                if (myPageStack.currentItem.objectName === "appImageManagerPage") {
                    return appImageManagerComponent;
                }
                return standardTaskComponent; // For Home and TaskSelection
            }

            // Using Components here instead of QML files directly allows us to 
            // easily bind properties without needing setSource's dictionary syntax
            // which can sometimes be tricky with dynamic QObject pointers.
        }
        
        Component {
            id: standardTaskComponent
            MyComponents.TaskProgressPane {
                anchors.fill: parent
            }
        }
        
        Component {
            id: corpseCleanerComponent
            MyComponents.CorpseCleanerPane {
                anchors.fill: parent
                // The corpseCleanerPage exposes myTask. Note: myPageStack.currentItem is the CorpseCleanerPage
                activeTask: myPageStack.currentItem ? myPageStack.currentItem.myTask : null
            }
        }
        
        Component {
            id: efiAuditComponent
            MyComponents.EfiAuditPane {
                anchors.fill: parent
                activeTask: myPageStack.currentItem ? myPageStack.currentItem.myTask : null
            }
        }

        Component {
            id: packageManagerComponent
            MyComponents.PackageManagerPane {
                anchors.fill: parent
            }
        }

        Component {
            id: appImageManagerComponent
            MyComponents.AppImageManagerPane {
                anchors.fill: parent
            }
        }
    }

    Kirigami.OverlaySheet {
        id: globalConfirmSheet
        title: "Confirm Deletion"
        // Force width to help horizontal centering
        width: Math.min(Kirigami.Units.gridUnit * 40, mainWindow.width * 0.9)
        
        ColumnLayout {
            id: confirmLayout
            spacing: Kirigami.Units.largeSpacing
            Layout.fillWidth: true
            Layout.margins: Kirigami.Units.gridUnit
            
            Label {
                text: "The following specific folders will be completely deleted. This action cannot be undone. Are you sure you want to proceed?"
                wrapMode: Text.WordWrap
                color: Kirigami.Theme.neutralTextColor
                Layout.fillWidth: true
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Kirigami.Units.gridUnit * 12
                color: UIColors.theme.description_background_hex ? UIColors.theme.description_background_hex : Qt.darker(Kirigami.Theme.backgroundColor, UIColors.theme.description_darker_multiplier)
                border.color: UIColors.theme.border_color_hex ? UIColors.theme.border_color_hex : Kirigami.Theme.highlightColor
                border.width: 1
                radius: SettingsManager.cornerRadius / 2
                clip: true

                ListView {
                    id: globalConfirmListView
                    anchors.fill: parent
                    anchors.margins: Kirigami.Units.smallSpacing
                    model: globalConfirmSheet.visible ? mainWindow.confirmItems : []
                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                    clip: true
                    
                    delegate: ItemDelegate {
                        width: ListView.view.width
                        contentItem: RowLayout {
                            spacing: Kirigami.Units.smallSpacing
                            Layout.topMargin: 2
                            Layout.bottomMargin: 2
                            
                            Button {
                                icon.source: UIIcons.icons.delete || ""
                                icon.color: UIIcons.iconColor("delete", Kirigami.Theme.negativeTextColor)
                                ToolTip.text: "Remove from selection"
                                ToolTip.visible: hovered
                                ToolTip.delay: Kirigami.Units.toolTipDelay
                                onClicked: {
                                    if (mainWindow.activeCleaningTask) {
                                        let realIdx = modelData.originalIndex;
                                        let items = mainWindow.activeCleaningTask.subItems;
                                        if (realIdx >= 0 && realIdx < items.length) {
                                            items[realIdx].checked = false;
                                        }
                                        mainWindow.activeCleaningTask.set_sub_item_checked(realIdx, false);
                                        mainWindow.confirmUpdateTrigger++;
                                        
                                        // Update the local list
                                        let newList = [];
                                        for (let i=0; i<items.length; i++) {
                                            if (items[i].checked) {
                                                newList.push({
                                                    "name": items[i].name,
                                                    "sizeBytes": items[i].sizeBytes,
                                                    "originalIndex": i
                                                });
                                            }
                                        }
                                        mainWindow.confirmItems = newList;
                                        mainWindow.confirmTotal = mainWindow.calculateTotal(newList);

                                        if (newList.length === 0) {
                                            globalConfirmSheet.close();
                                        }
                                    }
                                }
                            }
                            
                            Label {
                                text: modelData.name
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                                color: Kirigami.Theme.textColor
                            }
                            
                            Label {
                                text: Utils.formatBytes(modelData.sizeBytes)
                                color: Kirigami.Theme.neutralTextColor
                                font.pointSize: Kirigami.Theme.smallFont.pointSize
                            }
                        }
                    }
                }
            }

            Label {
                text: "Total to free: " + mainWindow.confirmTotal
                font.weight: Font.DemiBold
                Layout.alignment: Qt.AlignRight
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.largeSpacing
                
                Button {
                    text: "Cancel"
                    Layout.fillWidth: true
                    onClicked: globalConfirmSheet.close()
                }
                
                Button {
                    id: globalCleanBtn
                    text: "Clean Now"
                    icon.source: UIIcons.icons.delete || ""
                    icon.color: UIIcons.iconColor("delete", Kirigami.Theme.highlightColor)
                    onClicked: {
                        console.log("Global Clean Now clicked!");
                        globalConfirmSheet.close()
                        if (mainWindow.activeCleaningTask) {
                            console.log("Executing active cleaning task...");
                            mainWindow.activeCleaningTask.execute()
                        } else {
                            console.log("No active cleaning task found!");
                        }
                    }
                    background: Rectangle {
                        color: globalCleanBtn.down ? Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b, 0.4) : 
                               globalCleanBtn.hovered ? Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b, 0.3) :
                               Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b, 0.2)
                        radius: Kirigami.Units.smallSpacing
                        border.color: Kirigami.Theme.highlightColor
                        border.width: 1
                    }
                    contentItem: Label {
                        text: globalCleanBtn.text
                        color: Kirigami.Theme.highlightColor
                        font.weight: Font.Bold
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }
        }
    }

    // Global Confirmation Sheet for Boot Audit
    Kirigami.OverlaySheet {
        id: efiAuditConfirmSheet
        title: UIStrings.ui.boot_audit.confirm_title
        width: Math.min(Kirigami.Units.gridUnit * 40, mainWindow.width * 0.9)
        
        ColumnLayout {
            id: auditLayout
            spacing: Kirigami.Units.largeSpacing
            Layout.fillWidth: true
            Layout.margins: Kirigami.Units.gridUnit
            
            Label {
                text: UIStrings.ui.boot_audit.confirm_description
                wrapMode: Text.WordWrap
                color: Kirigami.Theme.negativeTextColor
                font.weight: Font.DemiBold
                Layout.fillWidth: true
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Kirigami.Units.gridUnit * 12
                color: UIColors.theme.description_background_hex ? UIColors.theme.description_background_hex : Qt.darker(Kirigami.Theme.backgroundColor, UIColors.theme.description_darker_multiplier)
                border.color: Kirigami.Theme.negativeTextColor
                border.width: 1
                radius: SettingsManager.cornerRadius / 2
                clip: true

                ListView {
                    id: efiAuditConfirmListView
                    anchors.fill: parent
                    anchors.margins: Kirigami.Units.smallSpacing
                    model: efiAuditConfirmSheet.visible ? mainWindow.confirmItems : []
                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                    clip: true
                    
                    delegate: ItemDelegate {
                        width: ListView.view.width
                        contentItem: RowLayout {
                            spacing: Kirigami.Units.smallSpacing
                            Layout.topMargin: 2
                            Layout.bottomMargin: 2
                            
                            Button {
                                icon.source: UIIcons.icons.delete || ""
                                icon.color: UIIcons.iconColor("delete", Kirigami.Theme.negativeTextColor)
                                ToolTip.text: "Remove from selection"
                                ToolTip.visible: hovered
                                ToolTip.delay: Kirigami.Units.toolTipDelay
                                onClicked: {
                                    if (mainWindow.activeCleaningTask) {
                                        let realIdx = modelData.originalIndex;
                                        let items = mainWindow.activeCleaningTask.subItems;
                                        if (realIdx >= 0 && realIdx < items.length) {
                                            items[realIdx].checked = false;
                                        }
                                        mainWindow.activeCleaningTask.set_sub_item_checked(realIdx, false);
                                        mainWindow.confirmUpdateTrigger++;
                                        
                                        // Update the local list
                                        let newList = [];
                                        for (let i=0; i<items.length; i++) {
                                            if (items[i].checked) {
                                                newList.push({
                                                    "name": items[i].name,
                                                    "sizeBytes": items[i].sizeBytes,
                                                    "details": items[i].details,
                                                    "originalIndex": i
                                                });
                                            }
                                        }
                                        mainWindow.confirmItems = newList;

                                        if (newList.length === 0) {
                                            efiAuditConfirmSheet.close();
                                        }
                                    }
                                }
                            }
                            
                            ColumnLayout {
                                spacing: 0
                                Layout.fillWidth: true
                                
                                Label {
                                    text: modelData.name
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                    font.weight: Font.DemiBold
                                    color: Kirigami.Theme.textColor
                                }
                                
                                Label {
                                    text: modelData.details
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                    color: Kirigami.Theme.neutralTextColor
                                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                                }
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.largeSpacing
                
                Button {
                    text: "Cancel"
                    Layout.fillWidth: true
                    onClicked: efiAuditConfirmSheet.close()
                }
                
                Button {
                    id: efiCleanBtn
                    text: UIStrings.ui.boot_audit.btn_remove_now
                    icon.name: "delete"
                    onClicked: {
                        efiAuditConfirmSheet.close()
                        if (mainWindow.activeCleaningTask) {
                            mainWindow.activeCleaningTask.execute()
                        }
                    }
                    background: Rectangle {
                        color: efiCleanBtn.down ? Qt.rgba(Kirigami.Theme.negativeTextColor.r, Kirigami.Theme.negativeTextColor.g, Kirigami.Theme.negativeTextColor.b, 0.4) : 
                               efiCleanBtn.hovered ? Qt.rgba(Kirigami.Theme.negativeTextColor.r, Kirigami.Theme.negativeTextColor.g, Kirigami.Theme.negativeTextColor.b, 0.3) :
                               Qt.rgba(Kirigami.Theme.negativeTextColor.r, Kirigami.Theme.negativeTextColor.g, Kirigami.Theme.negativeTextColor.b, 0.2)
                        radius: Kirigami.Units.smallSpacing
                        border.color: Kirigami.Theme.negativeTextColor
                        border.width: 1
                    }
                    contentItem: Label {
                        text: efiCleanBtn.text
                        color: Kirigami.Theme.negativeTextColor
                        font.weight: Font.Bold
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }
        }
    }

    function openCorpseCleanerConfirmation(task, items, total) {
        mainWindow.activeCleaningTask = task;
        mainWindow.confirmItems = items;
        mainWindow.confirmTotal = total;
        globalConfirmSheet.open();
    }

    function openEfiAuditConfirmation(task, items) {
        mainWindow.activeCleaningTask = task;
        mainWindow.confirmItems = items;
        mainWindow.confirmTotal = "";
        efiAuditConfirmSheet.open();
    }

    function calculateTotal(items) {
        let total = items.reduce((acc, item) => acc + (item.sizeBytes || 0), 0);
        return Utils.formatBytes(total);
    }
}
