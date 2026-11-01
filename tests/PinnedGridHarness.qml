import QtQuick
import "../contents/ui"
Item {
    width: 600
    height: 360
    property var storedFolders: []
    property var storedOrder: []
    PinnedGrid {
        id: pinned
        objectName: "pinned"
        anchors.fill: parent
        model: testFavorites
        folders: parent.storedFolders
        order: parent.storedOrder
        onFoldersEdited: value => parent.storedFolders = value
        onOrderEdited: value => parent.storedOrder = value
        columns: 6
        rows: 4
        cellHeight: 90
        iconSize: 40
    }
}
