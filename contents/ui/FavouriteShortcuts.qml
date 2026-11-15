// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PC3

RowLayout {
    id: shortcuts
    // Keep these values in the same order as the settings selector.
    enum DisplayMode { IconAndText, IconOnly, TextOnly }
    property int displayMode: FavouriteShortcuts.IconAndText
    property int iconSize: Kirigami.Units.iconSizes.medium
    readonly property bool showIcon: displayMode !== FavouriteShortcuts.TextOnly
    readonly property bool showText: displayMode !== FavouriteShortcuts.IconOnly

    property string savedShortcuts
    property var applications: []
    signal editRequested()
    signal launchRequested(string appId)
    signal shortcutsSaved(string json)

    readonly property var defaults: [
        { appId: "org.kde.dolphin.desktop", label: qsTr("Files"), icon: "system-file-manager" },
        { appId: "org.mozilla.firefox.desktop", label: qsTr("Web"), icon: "internet-web-browser" },
        { appId: "org.kde.konsole.desktop", label: qsTr("Terminal"), icon: "utilities-terminal" },
        { appId: "systemsettings.desktop", label: qsTr("Settings"), icon: "preferences-system" }
    ]
    readonly property var slots: {
        try {
            const saved = JSON.parse(savedShortcuts)
            if (Array.isArray(saved)) {
                return defaults.map((entry, index) => {
                    const shortcut = saved[index]
                    return shortcut && typeof shortcut.appId === "string"
                           && typeof shortcut.label === "string" && typeof shortcut.icon === "string"
                           ? shortcut : entry
                })
            }
        } catch (error) {}
        return defaults
    }

    spacing: Kirigami.Units.smallSpacing

    function edit(index) {
        editRequested()
        const slot = slots[index]
        editor.slotIndex = index
        editor.originalAppId = slot.appId
        appPicker.currentIndex = appPicker.indexOfValue(slot.appId)
        labelField.text = slot.label
        iconField.text = slot.icon
        editor.open()
    }

    Repeater {
        model: shortcuts.slots
        PC3.Button {
            id: shortcutButton
            required property int index
            required property var modelData
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            Layout.minimumWidth: 0
            Layout.preferredHeight: Math.max(Kirigami.Units.gridUnit * 3.5,
                                             implicitContentHeight + topPadding + bottomPadding)
            text: modelData.label
            Accessible.name: text
            PC3.ToolTip.text: text
            PC3.ToolTip.visible: !shortcuts.showText && hovered
            PC3.ToolTip.delay: 500
            background: Rectangle {
                radius: Kirigami.Units.smallSpacing
                color: Qt.alpha(Kirigami.Theme.highlightColor, shortcutButton.down ? 0.25
                                : shortcutButton.hovered ? 0.16 : 0.08)
                border.color: shortcutButton.activeFocus ? Kirigami.Theme.highlightColor
                                                         : Qt.alpha(Kirigami.Theme.textColor, 0.15)
            }
            contentItem: ColumnLayout {
                spacing: Kirigami.Units.smallSpacing
                Kirigami.Icon {
                    Layout.alignment: Qt.AlignHCenter
                    visible: shortcuts.showIcon
                    Layout.preferredWidth: Math.min(shortcuts.iconSize, shortcutButton.availableWidth)
                    Layout.preferredHeight: Layout.preferredWidth
                    source: shortcutButton.modelData.icon || "application-x-executable"
                }
                PC3.Label {
                    visible: shortcuts.showText
                    Layout.fillWidth: true
                    text: shortcutButton.text
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                }
            }
            onClicked: shortcuts.launchRequested(modelData.appId)
            TapHandler {
                acceptedButtons: Qt.RightButton
                onTapped: shortcuts.edit(shortcutButton.index)
            }
            Keys.onMenuPressed: shortcuts.edit(index)
        }
    }

    Dialog {
        id: editor
        property int slotIndex: 0
        property string originalAppId
        title: qsTr("Edit shortcut")
        modal: true
        focus: true
        width: shortcuts.width
        // Center in the launcher window rather than over the shortcut row.
        parent: Overlay.overlay
        anchors.centerIn: parent
        standardButtons: Dialog.Save | Dialog.Cancel

        onAccepted: {
            const edited = shortcuts.slots.slice()
            edited[slotIndex] = {
                appId: appPicker.currentValue || originalAppId,
                label: labelField.text.trim() || appPicker.currentText || shortcuts.slots[slotIndex].label,
                icon: iconField.text.trim() || "application-x-executable"
            }
            shortcuts.shortcutsSaved(JSON.stringify(edited))
        }

        ColumnLayout {
            spacing: Kirigami.Units.smallSpacing

            PC3.Label { text: qsTr("Application") }
            PC3.ComboBox {
                id: appPicker
                Layout.fillWidth: true
                model: shortcuts.applications
                textRole: "label"
                valueRole: "id"
                onActivated: {
                    labelField.text = currentText
                    iconField.text = shortcuts.applications[currentIndex].icon
                }
            }

            PC3.Label { text: qsTr("Button name") }
            PC3.TextField {
                id: labelField
                Layout.fillWidth: true
                Accessible.name: qsTr("Button name")
            }

            PC3.Label { text: qsTr("Icon name") }
            RowLayout {
                Kirigami.Icon {
                    Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                    Layout.preferredHeight: Layout.preferredWidth
                    source: iconField.text.trim() || "application-x-executable"
                }
                PC3.TextField {
                    id: iconField
                    Layout.fillWidth: true
                    Accessible.name: qsTr("Icon name")
                    placeholderText: qsTr("For example, folder or internet-web-browser")
                }
            }
        }
    }
}
