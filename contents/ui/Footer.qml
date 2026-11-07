import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15
import QtCore

import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.extras as PlasmaExtras

import org.kde.plasma.private.kicker 0.1 as Kicker
import org.kde.coreaddons 1.0 as KCoreAddons
import org.kde.plasma.private.shell

import org.kde.kwindowsystem
import org.kde.kquickcontrolsaddons

import org.kde.plasma.components as PlasmaComponents3


import org.kde.kirigami as Kirigami
import org.kde.plasma.private.sessions

RowLayout{

    spacing: Kirigami.Units.largeSpacing

    signal tabOut

    Keys.onTabPressed: event => {
        event.accepted = true;
        tabOut();
    }

    KCoreAddons.KUser {   id: kuser  }
    //Logic {   id: logic }

    SessionManagement {
        id: sessionManager
    }

    PlasmaComponents3.ToolButton {
        Accessible.name: qsTr("User settings")
        Layout.preferredWidth: Math.max(24, Math.min(96, Plasmoid.configuration.profilePictureSize))
        Layout.preferredHeight: Layout.preferredWidth
        padding: 0
        contentItem: RoundAvatar { source: kuser.faceIconUrl }
        onClicked: {
            executable.exec("systemsettings kcm_users");
            root.visible = false;
        }
    }

    PlasmaComponents3.ToolButton {
        MouseArea {
                cursorShape: Qt.PointingHandCursor
                anchors.fill: parent
                onClicked: Qt.openUrlExternally("file:///home/" + qsTr(kuser.loginName))
        }
        icon.width: 24
        icon.height: 24
        icon.name:  "user-home"
        
        Layout.leftMargin: 10
        PlasmaComponents3.ToolTip.delay: 1000
        PlasmaComponents3.ToolTip.timeout: 1000
        PlasmaComponents3.ToolTip.visible: hovered
        PlasmaComponents3.ToolTip.text: i18n("User Home")
    }

    PlasmaComponents3.ToolButton {
        MouseArea {
            cursorShape: Qt.PointingHandCursor
            anchors.fill: parent
            onClicked: executable.exec("systemsettings")
        }
        icon.width: 24
        icon.height: 24
        icon.name: "configure"
        Layout.leftMargin: 10
        PlasmaComponents3.ToolTip.delay: 1000
        PlasmaComponents3.ToolTip.timeout: 1000
        PlasmaComponents3.ToolTip.visible: hovered
        PlasmaComponents3.ToolTip.text: i18n("System Preferences")
    }

    Item{
        Layout.fillWidth: true
    }



    PowerButton {
        session: sessionManager
        onActionRequested: root.visible = false
    }
}
