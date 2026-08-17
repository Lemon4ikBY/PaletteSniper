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
        color: "white"
        font.pixelSize: 12
        verticalAlignment: Text.AlignVCenter
    }

    background: Rectangle {
        color: control.hovered ? "#232D3F" : "#171D28"
        radius: 8
        border.color: "#3C4454"
    }
}
