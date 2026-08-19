import QtQuick
import QtQuick.Controls

CheckBox {
    id: cb

    contentItem: Text {
        text: cb.text
        color: backend.theme === "light" ? "#111827" : "#F3F6FF"
        font.pixelSize: 13
        leftPadding: cb.indicator.width + 8
        verticalAlignment: Text.AlignVCenter
    }

    indicator: Rectangle {
        width: 18
        height: 18
        y: cb.height / 2 - 9
        radius: 4
        color: cb.checked ? "#7C9CFF" : (backend.theme === "light" ? "#FFFFFF" : "#171D28")
        border.color: backend.theme === "light" ? "#9CA3AF" : "#3C4454"
        border.width: backend.theme === "light" ? 2 : 1

        Text {
            anchors.centerIn: parent
            text: cb.checked ? "✓" : ""
            color: "white"
            font.pixelSize: 12
        }
    }
}
