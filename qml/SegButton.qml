import QtQuick

Rectangle {
    property string label: ""
    property bool active: false
    signal activated()

    width: 64
    height: 30
    radius: 8
    color: active ? "#7C9CFF" : (backend.theme === "light" ? "#F3F4F6" : "#171D28")
    border.color: active ? "#8FABFF" : (backend.theme === "light" ? "#D1D5DB" : "#3C4454")

    Text {
        anchors.centerIn: parent
        text: label
        color: active ? "white" : (backend.theme === "light" ? "#374151" : "#AAB2C0")
        font.pixelSize: 12
        font.bold: true
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: parent.activated()
    }
}
