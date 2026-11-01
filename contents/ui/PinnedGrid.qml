// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PC3
import "code/PinnedLayout.js" as PinnedLayout

FocusScope {
    id: pinned
    property var model: null
    property var folders: []
    property var order: []
    property int sortMode: 0
    property var externalDragSource: null
    property int columns: 6
    property int rows: 4
    property int page: 0
    property int iconSize: 48
    property real cellWidth: width / columns
    property real cellHeight: 90
    readonly property bool folderOpen: folderPopup.opened
    property alias currentIndex: grid.currentIndex
    readonly property int count: entries.length
    property var entries: []
    property var favoriteIds: []
    property var cleanFolders: []
    property var pendingDrop: null
    property bool dragging: false
    property string dragFolderId: ""
    property bool folderDragOutside: false
    property string dragKey: ""
    property string dragAppId: ""
    property string targetKey: ""
    property string dropMode: ""
    signal foldersEdited(var value)
    signal orderEdited(var value)
    signal manualOrderRequested()
    signal appActivated(string favoriteId)
    signal tabRequested()
    signal pageRequested(int requestedPage)
    signal keyNavUp()
    signal keyNavDown()
    signal keyNavLeft()
    signal keyNavRight()

    function resetDrag() {
        dragging = false;
        dragKey = "";
        dragAppId = "";
        dragFolderId = "";
        folderDragOutside = false;
        clearDrop();
    }
    function endFolderDrag() {
        resetDrag();
        folderPopup.close();
    }
    function closeFolder() { renameDialog.close(); folderPopup.close(); }
    function parseOrder(raw) {
        try { var parsed = JSON.parse(raw); return Array.isArray(parsed) ? parsed : []; }
        catch (e) { return []; }
    }
    function rebuild() {
        if (!model) return;
        var ids = [];
        for (var i = 0; i < model.count; ++i) {
            var id = model.data(model.index(i, 0), Qt.UserRole + 3);
            if (id) ids.push(String(id));
        }
        favoriteIds = ids;
        cleanFolders = PinnedLayout.normalize(folders, ids);
        var projected = PinnedLayout.project(ids, cleanFolders, order);
        entries = PinnedLayout.sorted(projected, sortMode, function(entry) {
            return entry.folderIndex >= 0 ? entry.name : String(info(entry.favoriteId, Qt.DisplayRole) || entry.favoriteId);
        });
        if (pendingDrop && ids.indexOf(pendingDrop.sourceId) >= 0) {
            var pending = pendingDrop;
            pendingDrop = null;
            applyDrop(pending.sourceId, pending.targetKey, pending.mode, "app:" + pending.sourceId);
        }
    }
    function info(id, role) {
        var index = favoriteIds.indexOf(id);
        return index >= 0 && model ? model.data(model.index(index, 0), role) : "";
    }
    function keys() { return entries.map(function(e) { return e.key; }); }
    function save(nextFolders, nextOrder) {
        foldersEdited(nextFolders);
        orderEdited(nextOrder);
        rebuild();
    }
    function createEmptyFolder() {
        var id = "pinned-" + Date.now();
        var next = cleanFolders.concat([{id: id, name: qsTr("New folder"), items: []}]);
        save(next, keys().concat(["folder:" + id]));
        openFolder(id);
        editFolderName(id);
    }
    function activate(index) {
        var entry = entries[index];
        if (!entry) return;
        if (entry.folderIndex >= 0) openFolder(cleanFolders[entry.folderIndex].id);
        else launchApp(entry.favoriteId);
    }
    function launchApp(id) {
        var row = favoriteIds.indexOf(id);
        if (row >= 0 && model && model.trigger(row, "", null)) appActivated(id);
    }
    function openFolder(id) {
        folderPopup.folderId = id;
        folderPopup.open();
    }
    function editFolderName(id) {
        var folder = cleanFolders.find(function(f) { return f.id === id; });
        if (!folder) return;
        renameDialog.folderId = id;
        folderName.text = folder.name;
        renameDialog.open();
        folderName.forceActiveFocus();
        folderName.selectAll();
    }
    function renameFolder(id, name) {
        if (!name.trim()) return;
        save(cleanFolders.map(function(f) {
            return {id: f.id, name: f.id === id ? name.trim() : f.name, items: f.items.slice()};
        }), keys());
    }
    function dissolveFolder(id) {
        var f = cleanFolders.find(function(f) { return f.id === id; });
        if (!f) return;
        var nextOrder = [];
        keys().forEach(function(key) {
            if (key === "folder:" + id) f.items.forEach(function(app) { nextOrder.push("app:" + app); });
            else nextOrder.push(key);
        });
        folderPopup.close();
        save(cleanFolders.filter(function(f) { return f.id !== id; }), nextOrder);
    }
    function moveOut(id) {
        var next = cleanFolders.map(function(f) {
            return {id: f.id, name: f.name, items: f.items.filter(function(app) { return app !== id; })};
        });
        save(next, keys().concat(["app:" + id]));
    }
    function positionAtIndex(index) { grid.positionViewAtIndex(index, GridView.Beginning); }
    function tryActivate(row, col) {
        currentIndex = Math.min(count - 1, page * columns * rows + row * columns + col);
        forceActiveFocus();
    }
    function clearDrop() { targetKey = ""; dropMode = ""; }
    function updateDrop(x, y) {
        if (dragFolderId !== "") {
            var popupPoint = dropArea.mapToItem(folderPopup.contentItem, x, y);
            folderDragOutside = popupPoint.x < -folderPopup.padding || popupPoint.y < -folderPopup.padding
                || popupPoint.x > folderPopup.availableWidth + folderPopup.padding
                || popupPoint.y > folderPopup.availableHeight + folderPopup.padding;
            if (!folderDragOutside) { clearDrop(); return; }
        }
        var point = dropArea.mapToItem(grid.contentItem, x, y);
        var index = grid.indexAt(point.x, point.y);
        var entry = entries[index];
        var sourceId = dragAppId || (externalDragSource ? externalDragSource.favoriteId : "");
        if (!entry && dragFolderId !== "") { targetKey = "@end"; dropMode = "after"; return; }
        if (!entry || entry.key === dragKey || entry.favoriteId === sourceId) { clearDrop(); return; }
        targetKey = entry.key;
        // The middle half groups apps. Tile edges reorder, and nothing moves until release.
        var localX = point.x % cellWidth;
        dropMode = sourceId && localX >= cellWidth * 0.25 && localX <= cellWidth * 0.75
                 ? "group" : (localX < cellWidth / 2 ? "before" : "after");
    }
    function applyDrop(sourceId, target, mode, sourceKey) {
        if (target !== "@end" && !entries.some(function(entry) { return entry.key === target; })) return false;
        if (mode === "group") {
            var result = PinnedLayout.group(cleanFolders, keys(), sourceId, target,
                                            "pinned-" + Date.now(), qsTr("New folder"));
            if (!result) return false;
            save(result.folders, result.order);
        } else {
            manualOrderRequested();
            var nextFolders = cleanFolders.map(function(folder) {
                return {id: folder.id, name: folder.name,
                        items: folder.items.filter(function(id) { return id !== sourceId; })};
            });
            save(nextFolders, PinnedLayout.move(keys(), sourceKey, target, mode === "after"));
        }
        return true;
    }
    function finishDrop() {
        var sourceId = dragAppId || (externalDragSource ? externalDragSource.favoriteId : "");
        if (!targetKey) return false;
        if (sourceId && favoriteIds.indexOf(sourceId) < 0) {
            pendingDrop = {sourceId: sourceId, targetKey: targetKey, mode: dropMode};
            model.addFavorite(sourceId);
            Qt.callLater(rebuild);
            clearDrop();
            return true;
        }
        var accepted = applyDrop(sourceId, targetKey, dropMode, dragKey || "app:" + sourceId);
        clearDrop();
        return accepted;
    }
    onSortModeChanged: Qt.callLater(rebuild)
    onModelChanged: Qt.callLater(rebuild)
    onFoldersChanged: Qt.callLater(rebuild)
    onOrderChanged: Qt.callLater(rebuild)
    Component.onCompleted: rebuild()
    Connections {
        target: pinned.model
        ignoreUnknownSignals: true
        function onFavoritesChanged() { Qt.callLater(pinned.rebuild); }
        function onModelReset() { Qt.callLater(pinned.rebuild); }
        function onRowsInserted() { Qt.callLater(pinned.rebuild); }
        function onRowsRemoved() { Qt.callLater(pinned.rebuild); }
        function onDataChanged() { Qt.callLater(pinned.rebuild); }
        function onRowsMoved() { Qt.callLater(pinned.rebuild); }
    }

    GridView {
        id: grid
        anchors.fill: parent
        clip: true
        interactive: false
        cellWidth: pinned.cellWidth
        cellHeight: pinned.cellHeight
        model: pinned.entries
        currentIndex: -1
        delegate: Item {
            id: tile
            required property var modelData
            required property int index
            width: grid.cellWidth
            height: grid.cellHeight
            readonly property bool dragging: mouse.drag.active
            readonly property bool isFolder: modelData.folderIndex >= 0
            readonly property var folder: isFolder ? pinned.cleanFolders[modelData.folderIndex] : null
            readonly property string label: isFolder ? modelData.name : String(pinned.info(modelData.favoriteId, Qt.DisplayRole) || modelData.favoriteId)
            opacity: pinned.dragKey === modelData.key ? 0.35 : 1
            Accessible.role: Accessible.Button
            Accessible.name: label
            Accessible.onPressAction: pinned.activate(index)
            Rectangle {
                anchors.fill: parent
                anchors.margins: 4
                radius: 10
                color: mouse.containsMouse || grid.currentIndex === index
                       ? Qt.alpha(Kirigami.Theme.highlightColor, 0.15) : "transparent"
                border.width: pinned.targetKey === tile.modelData.key && pinned.dropMode === "group" ? 2 : 0
                border.color: Kirigami.Theme.highlightColor
            }
            Rectangle {
                visible: pinned.targetKey === tile.modelData.key && pinned.dropMode !== "group"
                x: pinned.dropMode === "before" ? 0 : parent.width - 3
                y: 8
                width: 3
                height: parent.height - 16
                color: Kirigami.Theme.highlightColor
            }
            Item {
                id: iconBox
                anchors.horizontalCenter: parent.horizontalCenter
                y: 8
                width: pinned.iconSize
                height: width
                Kirigami.Icon {
                    anchors.fill: parent
                    visible: !tile.isFolder
                    source: pinned.info(tile.modelData.favoriteId, Qt.DecorationRole)
                }
                Rectangle {
                    anchors.fill: parent
                    visible: tile.isFolder
                    radius: 8
                    color: Qt.alpha(Kirigami.Theme.textColor, 0.12)
                }
                Grid {
                    anchors.centerIn: parent
                    columns: 2
                    spacing: 3
                    visible: tile.isFolder
                    Repeater {
                        model: tile.folder ? tile.folder.items.slice(0, 4) : []
                        Kirigami.Icon {
                            required property string modelData
                            width: (pinned.iconSize - 12) / 2
                            height: width
                            source: pinned.info(modelData, Qt.DecorationRole)
                        }
                    }
                }
                Kirigami.Icon {
                    anchors.fill: parent
                    visible: tile.isFolder && tile.folder && tile.folder.items.length === 0
                    source: "folder"
                }
            }
            PC3.Label {
                anchors.top: iconBox.bottom
                anchors.topMargin: 4
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 4
                text: tile.label
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                maximumLineCount: 2
                wrapMode: Text.Wrap
            }
            MouseArea {
                id: mouse
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: Qt.PointingHandCursor
                drag.onActiveChanged: pinned.dragging = drag.active
                drag.target: ghost
                drag.threshold: Qt.styleHints.startDragDistance
                onPressed: event => {
                    grid.currentIndex = tile.index;
                    if (event.button !== Qt.LeftButton) return;
                    pinned.dragFolderId = "";
                    var p = mapToItem(ghost.parent, event.x, event.y);
                    ghost.x = p.x - ghost.width / 2;
                    ghost.y = p.y - ghost.height / 2;
                    pinned.dragKey = tile.modelData.key;
                    pinned.dragAppId = tile.modelData.favoriteId;
                    ghost.iconSource = tile.isFolder ? "folder" : pinned.info(tile.modelData.favoriteId, Qt.DecorationRole);
                }
                onReleased: event => {
                    if (drag.active) {
                        Qt.callLater(pinned.resetDrag);
                        ghost.Drag.drop();
                    }
                    pinned.dragKey = "";
                    pinned.dragAppId = "";
                    pinned.clearDrop();
                }
                onCanceled: { ghost.Drag.cancel(); pinned.dragKey = ""; pinned.dragAppId = ""; pinned.clearDrop(); }
                onClicked: event => {
                    if (event.button === Qt.RightButton) {
                        tileMenu.entry = tile.modelData;
                        tileMenu.popup();
                    } else pinned.activate(tile.index);
                }
            }
        }
    }
    DropArea {
        id: dropArea
        objectName: "dropArea"
        anchors.fill: parent
        onEntered: event => {
            if (!pinned.dragKey && (!pinned.externalDragSource || !pinned.externalDragSource.favoriteId)) {
                event.accepted = false;
                return;
            }
            pinned.updateDrop(event.x, event.y);
        }
        onPositionChanged: event => pinned.updateDrop(event.x, event.y)
        onExited: pinned.clearDrop()
        onDropped: event => { if (pinned.finishDrop()) event.acceptProposedAction(); }
    }
    Item {
        id: ghost
        objectName: "ghost"
        parent: Overlay.overlay ? Overlay.overlay : pinned
        z: 1000
        width: pinned.iconSize
        height: width
        property var iconSource: ""
        visible: Drag.active
        Drag.active: pinned.dragKey !== "" && pinned.dragging
        Drag.source: ghost
        Drag.hotSpot.x: width / 2
        Drag.hotSpot.y: height / 2
        Kirigami.Icon { anchors.fill: parent; source: ghost.iconSource }
    }
    Menu {
        id: tileMenu
        property var entry: null
        MenuItem {
            text: qsTr("Rename folder")
            visible: tileMenu.entry && tileMenu.entry.folderIndex >= 0
            height: visible ? implicitHeight : 0
            onTriggered: {
                pinned.openFolder(pinned.cleanFolders[tileMenu.entry.folderIndex].id);
                pinned.editFolderName(pinned.cleanFolders[tileMenu.entry.folderIndex].id);
            }
        }
        MenuItem {
            text: qsTr("Dissolve folder")
            visible: tileMenu.entry && tileMenu.entry.folderIndex >= 0
            height: visible ? implicitHeight : 0
            onTriggered: pinned.dissolveFolder(pinned.cleanFolders[tileMenu.entry.folderIndex].id)
        }
        MenuItem {
            text: qsTr("Unpin application")
            visible: tileMenu.entry && tileMenu.entry.folderIndex < 0
            height: visible ? implicitHeight : 0
            onTriggered: pinned.model.removeFavorite(tileMenu.entry.favoriteId)
        }
    }
    Popup {
        id: folderPopup
        property string folderId: ""
        readonly property var folder: pinned.cleanFolders.find(function(f) { return f.id === folderId; })
        width: Math.min(pinned.width, 420)
        height: Math.min(350, contentColumn.implicitHeight + padding * 2)
        x: (pinned.width - width) / 2
        y: Math.max(0, (pinned.height - height) / 2)
        padding: 16
        background: Rectangle {
            radius: 12
            color: Kirigami.Theme.backgroundColor
            border.color: Qt.alpha(Kirigami.Theme.textColor, 0.2)
        }
        // Keep the source delegate alive until release, but expose the grid while dragging out.
        opacity: pinned.dragging && pinned.folderDragOutside ? 0 : 1
        modal: !(pinned.dragging && pinned.dragFolderId !== "")
        focus: true
        closePolicy: pinned.dragging ? Popup.NoAutoClose : Popup.CloseOnEscape | Popup.CloseOnPressOutside
        onClosed: pinned.forceActiveFocus()
        ColumnLayout {
            id: contentColumn
            anchors.fill: parent
            RowLayout {
                Layout.fillWidth: true
                PC3.Label {
                    objectName: "folderTitle"
                    Layout.fillWidth: true
                    text: folderPopup.folder ? folderPopup.folder.name : ""
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.5
                    font.bold: true
                    elide: Text.ElideRight
                }
                PC3.ToolButton {
                    objectName: "renameFolderButton"
                    icon.name: "edit-rename"
                    Accessible.name: qsTr("Rename folder")
                    PC3.ToolTip.text: qsTr("Rename folder")
                    PC3.ToolTip.visible: hovered
                    onClicked: pinned.editFolderName(folderPopup.folderId)
                }
                PC3.ToolButton {
                    icon.name: "window-close"
                    Accessible.name: qsTr("Close folder")
                    onClicked: folderPopup.close()
                }
            }
            GridView {
                id: folderApps
                objectName: "folderApps"
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(240, Math.ceil(count / 3) * cellHeight)
                clip: true
                cellWidth: width / 3
                cellHeight: 90
                model: folderPopup.folder ? folderPopup.folder.items : []
                delegate: Column {
                    id: childTile
                    required property string modelData
                    width: folderApps.cellWidth
                    PC3.ToolButton {
                        width: parent.width
                        height: 62
                        contentItem: Kirigami.Icon {
                            source: pinned.info(childTile.modelData, Qt.DecorationRole)
                            implicitWidth: pinned.iconSize
                            implicitHeight: pinned.iconSize
                        }
                        Accessible.name: String(pinned.info(childTile.modelData, Qt.DisplayRole))
                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            cursorShape: Qt.PointingHandCursor
                            drag.target: ghost
                            drag.threshold: Qt.styleHints.startDragDistance
                            drag.onActiveChanged: pinned.dragging = drag.active
                            preventStealing: drag.active
                            onPressed: event => {
                                if (event.button !== Qt.LeftButton) return;
                                var p = mapToItem(ghost.parent, event.x, event.y);
                                ghost.x = p.x - ghost.width / 2;
                                ghost.y = p.y - ghost.height / 2;
                                ghost.iconSource = pinned.info(childTile.modelData, Qt.DecorationRole);
                                pinned.dragKey = "app:" + childTile.modelData;
                                pinned.dragAppId = childTile.modelData;
                                pinned.dragFolderId = folderPopup.folderId;
                                pinned.folderDragOutside = false;
                            }
                            onReleased: {
                                var wasDragging = drag.active;
                                if (wasDragging) {
                                    // The drop rebuilds this delegate's model. Schedule cleanup first.
                                    Qt.callLater(pinned.endFolderDrag);
                                    ghost.Drag.drop();
                                }
                                pinned.dragKey = "";
                                pinned.dragAppId = "";
                                pinned.dragFolderId = "";
                                pinned.folderDragOutside = false;
                                pinned.clearDrop();
                                if (wasDragging) folderPopup.close();
                            }
                            onCanceled: {
                                ghost.Drag.cancel();
                                pinned.dragKey = "";
                                pinned.dragAppId = "";
                                pinned.dragFolderId = "";
                                pinned.folderDragOutside = false;
                                pinned.clearDrop();
                            }
                            onClicked: event => {
                                if (event.button === Qt.RightButton) {
                                    childMenu.appId = childTile.modelData;
                                    childMenu.popup();
                                } else {
                                    folderPopup.close();
                                    pinned.launchApp(childTile.modelData);
                                }
                            }
                        }
                    }
                    PC3.Label {
                        width: parent.width
                        text: String(pinned.info(childTile.modelData, Qt.DisplayRole))
                        elide: Text.ElideRight
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }
            PC3.Label {
                visible: folderApps.count === 0
                text: qsTr("Drop pinned apps onto this folder to add them.")
                Layout.fillWidth: true
                wrapMode: Text.Wrap
            }
        }
    }
    Dialog {
        id: renameDialog
        objectName: "renameFolderDialog"
        property string folderId: ""
        title: qsTr("Rename folder")
        modal: true
        focus: true
        width: Math.min(pinned.width, 360)
        x: (pinned.width - width) / 2
        y: Math.max(0, (pinned.height - height) / 2)
        standardButtons: Dialog.Save | Dialog.Cancel
        onOpened: standardButton(Dialog.Save).enabled = folderName.text.trim().length > 0
        onAccepted: pinned.renameFolder(folderId, folderName.text)
        PC3.TextField {
            id: folderName
            objectName: "folderNameInput"
            width: parent.width
            Accessible.name: qsTr("Folder name")
            onTextChanged: {
                var button = renameDialog.standardButton(Dialog.Save);
                if (button) button.enabled = text.trim().length > 0;
            }
            Keys.onReturnPressed: { if (text.trim()) renameDialog.accept(); }
        }
    }
    Menu {
        id: childMenu
        property string appId: ""
        MenuItem { text: qsTr("Move out of folder"); onTriggered: pinned.moveOut(childMenu.appId) }
    }
    Keys.onPressed: event => {
        var offset = currentIndex % (columns * rows);
        if (event.key === Qt.Key_Tab) {
            tabRequested(); event.accepted = true;
        } else if (event.key === Qt.Key_PageDown || event.key === Qt.Key_PageUp
                   || event.key === Qt.Key_Home || event.key === Qt.Key_End) {
            var total = Math.max(1, Math.ceil(count / (columns * rows)));
            var next = event.key === Qt.Key_Home ? 0 : event.key === Qt.Key_End ? total - 1
                     : Math.max(0, Math.min(total - 1, page + (event.key === Qt.Key_PageDown ? 1 : -1)));
            pageRequested(next); event.accepted = true;
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            activate(currentIndex); event.accepted = true;
        } else if (event.key === Qt.Key_Left) {
            if (offset % columns > 0) currentIndex--; else keyNavLeft();
            event.accepted = true;
        } else if (event.key === Qt.Key_Right) {
            if (offset % columns < columns - 1 && currentIndex < count - 1) currentIndex++; else keyNavRight();
            event.accepted = true;
        } else if (event.key === Qt.Key_Up) {
            if (offset >= columns) currentIndex -= columns; else keyNavUp();
            event.accepted = true;
        } else if (event.key === Qt.Key_Down) {
            if (offset < columns * (rows - 1) && currentIndex + columns < count) currentIndex += columns; else keyNavDown();
            event.accepted = true;
        }
    }
}
