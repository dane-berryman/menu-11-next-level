// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PC3
import org.kde.plasma.plasma5support as Plasma5Support

Rectangle {
    id: card
    property bool active: false
    property bool showIpAddress: true
    property bool showDiskSpace: true
    property bool showRamUsage: true
    property bool showCpuUsage: true
    property bool showGpuUsage: true
    property var stats: ({})
    visible: showIpAddress || showDiskSpace || showRamUsage || showCpuUsage || showGpuUsage
    height: visible ? content.implicitHeight + 24 : 0
    radius: 10
    color: Qt.alpha(Kirigami.Theme.textColor, 0.05)
    function size(bytes) {
        return bytes >= 1073741824 ? (bytes / 1073741824).toFixed(1) + " GiB"
                                  : (bytes / 1048576).toFixed(0) + " MiB";
    }
    function refresh() {
        if (!active || !visible || reader.busy) return;
        var path = decodeURIComponent(Qt.resolvedUrl("code/system_info.py").toString().replace(/^file:\/\//, ""));
        reader.busy = true;
        reader.connectSource("python3 '" + path.replace(/'/g, "'\\''") + "'");
    }
    onActiveChanged: refresh()
    onVisibleChanged: refresh()
    Plasma5Support.DataSource {
        id: reader
        property bool busy: false
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => {
            disconnectSource(source);
            busy = false;
            if (data["exit code"] === 0) {
                try { card.stats = JSON.parse(data.stdout); } catch (e) { card.stats = ({}); }
            }
        }
    }
    Timer { interval: 5000; repeat: true; running: card.active && card.visible; onTriggered: card.refresh() }
    ColumnLayout {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 12
        spacing: 8
        PC3.Label {
            text: qsTr("System information")
            font.bold: true
        }
        PC3.Label {
            visible: card.showIpAddress
            Layout.fillWidth: true
            text: qsTr("Local IP: %1").arg(card.stats.ip || qsTr("Not connected"))
            elide: Text.ElideMiddle
        }
        RowLayout {
            Layout.fillWidth: true
            visible: card.showCpuUsage || card.showGpuUsage || card.showRamUsage
            spacing: 12
            PC3.Label {
                visible: card.showCpuUsage
                Layout.fillWidth: true
                text: typeof card.stats.cpu === "number" ? qsTr("CPU %1%").arg(Math.round(card.stats.cpu)) : qsTr("CPU —")
                elide: Text.ElideRight
            }
            PC3.Label {
                visible: card.showGpuUsage
                Layout.fillWidth: true
                text: typeof card.stats.gpu === "number" ? qsTr("GPU %1%").arg(Math.round(card.stats.gpu)) : qsTr("GPU —")
                elide: Text.ElideRight
            }
            PC3.Label {
                id: ramLabel
                visible: card.showRamUsage
                Layout.fillWidth: true
                text: card.stats.ram && card.stats.ram.total > 0
                    ? qsTr("RAM %1%").arg(Math.round(card.stats.ram.used * 100 / card.stats.ram.total))
                    : qsTr("RAM —")
                readonly property string details: card.stats.ram && card.stats.ram.total > 0
                    ? qsTr("RAM: %1 used of %2").arg(card.size(card.stats.ram.used)).arg(card.size(card.stats.ram.total))
                    : qsTr("RAM: unavailable")
                Accessible.name: text + ", " + details
                PC3.ToolTip.text: details
                PC3.ToolTip.visible: ramHover.containsMouse
                elide: Text.ElideRight
                MouseArea { id: ramHover; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton }
            }
        }
        PC3.Label {
            visible: card.showDiskSpace
            Layout.fillWidth: true
            text: card.stats.disk ? qsTr("Disk: %1 free of %2").arg(card.size(card.stats.disk.free)).arg(card.size(card.stats.disk.total))
                                  : qsTr("Disk: unavailable")
            elide: Text.ElideRight
        }
    }
}
