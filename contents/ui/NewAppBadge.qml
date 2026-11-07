// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PC3
PC3.Label {
    text: qsTr("New")
    font.pixelSize: 10
    font.bold: true
    color: Kirigami.Theme.highlightedTextColor
    padding: 3
    background: Rectangle { radius: 4; color: Kirigami.Theme.highlightColor }
}
