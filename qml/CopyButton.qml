import QtQuick
import QtQuick.Controls

Button {
    id: control
    property string copyText: ""

    text: "Копировать"
    padding: 5
    leftPadding: 10
    rightPadding: 10
    onClicked: backend.copyText(control.copyText)

    contentItem: Text {
        text: control.text
        color: backend.theme === "light" ? "#111827" : "white"
        font.pixelSize: 12
        font.bold: true
        verticalAlignment: Text.AlignVCenter
    }

    background: Rectangle {
        color: control.hovered ? (backend.theme === "light" ? "#E5E7EB" : "#232D3F")
                               : (backend.theme === "light" ? "#F3F4F6" : "#171D28")
        radius: 8
        border.color: backend.theme === "light" ? "#D1D5DB" : "#3C4454"
    }
}
