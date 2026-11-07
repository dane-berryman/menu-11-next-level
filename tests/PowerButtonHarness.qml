import QtQuick
import "../contents/ui"
Rectangle {
    width: 400
    height: 360
    color: "#eeeeee"
    PowerButton {
        x: 340
        y: 300
        session: testSession
    }
}
