// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import org.kde.kirigami as Kirigami
Item {
    id: avatar
    property url source
    implicitWidth: 40
    implicitHeight: 40
    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: Qt.alpha(Kirigami.Theme.highlightColor, 0.15)
        Kirigami.Icon { anchors.fill: parent; anchors.margins: parent.width * 0.15; source: "user-identity" }
    }
    // Canvas clipping also works with Qt's software renderer.
    Image {
        id: photo
        objectName: "avatarPhoto"
        visible: false
        source: avatar.source
        onStatusChanged: {
            if (status === Image.Ready) canvas.loadImage(source);
            canvas.requestPaint();
        }
    }
    Canvas {
        id: canvas
        objectName: "avatarCanvas"
        anchors.fill: parent
        onImageLoaded: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            if (photo.status !== Image.Ready || !isImageLoaded(photo.source)) return;
            var scale = Math.max(width / photo.implicitWidth, height / photo.implicitHeight);
            var w = photo.implicitWidth * scale, h = photo.implicitHeight * scale;
            ctx.save();
            ctx.beginPath();
            ctx.arc(width / 2, height / 2, Math.min(width, height) / 2, 0, 2 * Math.PI);
            ctx.clip();
            ctx.drawImage(photo.source, (width - w) / 2, (height - h) / 2, w, h);
            ctx.restore();
        }
    }
}
