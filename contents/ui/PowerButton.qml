// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls
import org.kde.plasma.components as PC3

PC3.ToolButton {
    id: button
    property var session
    signal actionRequested()
    objectName: "powerButton"
    icon.name: "system-shutdown"
    icon.width: 24
    icon.height: 24
    Accessible.name: qsTr("Power options")
    PC3.ToolTip.text: qsTr("Power options")
    PC3.ToolTip.visible: hovered
    onClicked: powerMenu.opened ? powerMenu.close() : powerMenu.open()

    Menu {
        id: powerMenu
        objectName: "powerMenu"
        x: button.width - width
        y: -height
        MenuItem {
            objectName: "powerOffAction"
            text: qsTr("Power Off")
            icon.name: "system-shutdown"
            enabled: button.session && button.session.canShutdown
            onTriggered: { button.actionRequested(); button.session.requestShutdown(); }
        }
        MenuItem {
            objectName: "restartAction"
            text: qsTr("Restart")
            icon.name: "system-reboot"
            enabled: button.session && button.session.canReboot
            onTriggered: { button.actionRequested(); button.session.requestReboot(); }
        }
        MenuItem {
            objectName: "suspendAction"
            text: qsTr("Suspend")
            icon.name: "system-suspend"
            enabled: button.session && button.session.canSuspend
            onTriggered: { button.actionRequested(); button.session.suspend(); }
        }
        MenuSeparator {}
        MenuItem {
            objectName: "logoutAction"
            text: qsTr("Log Out")
            icon.name: "system-log-out"
            enabled: button.session && button.session.canLogout
            onTriggered: { button.actionRequested(); button.session.requestLogout(); }
        }
    }
}
