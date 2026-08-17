import QtQuick
import QtQuick.Controls

CheckBox {
    id: cb

    contentItem: Text {
        text: cb.text
        color: "#F3F6FF"
        font.pixelSize: 13
        leftPadding: cb.indicator.width + 8
        verticalAlignment: Text.AlignVCenter
    }

    indicator: Rectangle {
        width: 18
        height: 18
        y: cb.height / 2 - 9
        radius: 4

        color: cb.checked ? "#7C9CFF" : "#171D28"
        border.color: "#3C4454"

        Text {
            anchors.centerIn: parent
            text: cb.checked ? "✓" : ""
            color: "white"
            font.pixelSize: 12
        }
    }
}
