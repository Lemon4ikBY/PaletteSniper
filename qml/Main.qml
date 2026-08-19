import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window

ApplicationWindow {
    id: root
    visible: true
    width: 660
    height: 640
    minimumWidth: 560
    minimumHeight: 480
    title: "PaletteSniper"
    color: backend.theme === "light" ? "#FFFFFF" : "#0B0F16"

    property bool settingsWereOpen: false

    function openPicker() {
        var cap = backend.captureScreen()
        if (cap.image) screenImage.source = cap.image
        pickerWindow.showFullScreen()
        pickerWindow.raise()
        pickerWindow.requestActivate()
        pickerArea.forceActiveFocus()
    }

    Connections {
        target: backend
        function onColorChanged() { statusText.text = "Цвет обновлён." }
        function onCopied(text) { statusText.text = "Скопировано: " + text }
        function onHotkeyPressed() { root.openPicker() }
    }

    // ------------------------------------------------------------------------
    // Окно пипетки
    // ------------------------------------------------------------------------
    Window {
        id: pickerWindow
        visible: false
        flags: Qt.FramelessWindowHint | Qt.Tool | Qt.WindowStaysOnTopHint
        color: "#000000"

        function updateHud(mx, my) {
            var hx = mx + 28
            if (hx + hud.width > pickerArea.width - 8) hx = mx - hud.width - 28
            var hy = my + 28
            if (hy + hud.height > pickerArea.height - 8) hy = my - hud.height - 28
            hud.x = hx; hud.y = hy
        }

        onVisibleChanged: { if (visible) pickerArea.forceActiveFocus() }

        Image {
            id: screenImage
            anchors.fill: parent
            fillMode: Image.Stretch
            smooth: false
            asynchronous: false
        }

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(5/255, 8/255, 12/255, backend.dimAlpha/255)
        }

        MouseArea {
            id: pickerArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.CrossCursor
            focus: true
            property int mx: width / 2
            property int my: height / 2

            Keys.onEscapePressed: pickerWindow.close()

            onPositionChanged: {
                mx = mouse.x; my = mouse.y
                var info = backend.sampleAt(mouse.x, mouse.y)
                hoverHexText.text = info.hex
                hoverSwatch.color = info.hex
                if (info.magnifier) magnifierImage.source = info.magnifier
                pickerWindow.updateHud(mx, my)
            }

            onClicked: {
                var info = backend.sampleAt(mouse.x, mouse.y)
                pickerWindow.visible = false
                backend.pickHex(info.hex)
            }

            Rectangle { x: 0; y: pickerArea.my; width: Math.max(0, pickerArea.mx - 10); height: 1; color: "#CCFFFFFF" }
            Rectangle { x: pickerArea.mx + 10; y: pickerArea.my; width: Math.max(0, pickerArea.width - pickerArea.mx - 10); height: 1; color: "#CCFFFFFF" }
            Rectangle { x: pickerArea.mx; y: 0; width: 1; height: Math.max(0, pickerArea.my - 10); color: "#CCFFFFFF" }
            Rectangle { x: pickerArea.mx; y: pickerArea.my + 10; width: 1; height: Math.max(0, pickerArea.height - pickerArea.my - 10); color: "#CCFFFFFF" }
            Rectangle { x: pickerArea.mx - 18; y: pickerArea.my - 18; width: 36; height: 36; radius: 18; color: "transparent"; border.color: "#CCFFFFFF"; border.width: 1 }
        }

        Item {
            id: hud
            property int zoom: backend.zoom
            width: 176
            height: 13 * zoom + 46
            enabled: false

            Rectangle {
                id: magnifierFrame
                width: 13 * hud.zoom + 4
                height: 13 * hud.zoom + 4
                anchors.horizontalCenter: parent.horizontalCenter
                color: "#20000000"
                border.color: "#CCFFFFFF"
                border.width: 1
                radius: 6
                Image {
                    id: magnifierImage
                    anchors.centerIn: parent
                    width: 13 * hud.zoom
                    height: 13 * hud.zoom
                    smooth: false
                }
                Rectangle {
                    anchors.centerIn: parent
                    width: hud.zoom; height: hud.zoom
                    color: "transparent"
                    border.color: "white"; border.width: 1
                }
            }

            Row {
                anchors.top: magnifierFrame.bottom
                anchors.topMargin: 8
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 8
                Rectangle {
                    id: hoverSwatch
                    width: 22; height: 22; radius: 5
                    color: "#000000"
                    border.color: "#CCFFFFFF"
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    id: hoverHexText
                    text: "#000000"
                    color: "white"
                    font.pixelSize: 14
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        Text {
            x: 12; y: parent.height - 28
            color: "white"
            font.pixelSize: 12
            text: "ЛКМ — выбрать · ESC — отмена · " + backend.hotkey
        }
    }

    // ------------------------------------------------------------------------
    // Окно настроек
    // ------------------------------------------------------------------------
    Window {
        id: settingsWindow
        visible: false
        width: 440
        height: 600
        title: "PaletteSniper — Настройки"
        color: backend.theme === "light" ? "#FFFFFF" : "#0B0F16"

        onVisibleChanged: {
            if (visible) root.settingsWereOpen = true
            else if (root.settingsWereOpen) {
                root.settingsWereOpen = false
                savedToast.visible = true
                savedTimer.restart()
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 12

            Text {
                text: "Настройки"
                color: backend.theme === "light" ? "#1F2937" : "#E5E7EB"
                font.pixelSize: 20
                font.weight: Font.Black
            }

            Text {
                text: "Тема оформления"
                color: backend.theme === "light" ? "#4B5563" : "#AAB2C0"
                font.pixelSize: 11
            }
            Row {
                spacing: 6
                SegButton { label: "Тёмная"; active: backend.theme === "dark"; onActivated: backend.theme = "dark" }
                SegButton { label: "Светлая"; active: backend.theme === "light"; onActivated: backend.theme = "light" }
            }

            DarkCheckBox { text: "Автоматически копировать при клике"; checked: backend.autoCopy; onToggled: backend.autoCopy = checked }

            Text {
                text: "Формат по умолчанию"
                color: backend.theme === "light" ? "#4B5563" : "#AAB2C0"
                font.pixelSize: 11
            }
            Row {
                spacing: 6
                SegButton { label: "HEX"; active: backend.defaultFormat === "hex"; onActivated: backend.defaultFormat = "hex" }
                SegButton { label: "RGB"; active: backend.defaultFormat === "rgb"; onActivated: backend.defaultFormat = "rgb" }
                SegButton { label: "HSL"; active: backend.defaultFormat === "hsl"; onActivated: backend.defaultFormat = "hsl" }
            }

            Text {
                text: "Зум лупы"
                color: backend.theme === "light" ? "#4B5563" : "#AAB2C0"
                font.pixelSize: 11
            }
            Row {
                spacing: 6
                SegButton { label: "8×"; active: backend.zoom === 8; onActivated: backend.zoom = 8 }
                SegButton { label: "12×"; active: backend.zoom === 12; onActivated: backend.zoom = 12 }
                SegButton { label: "16×"; active: backend.zoom === 16; onActivated: backend.zoom = 16 }
                SegButton { label: "24×"; active: backend.zoom === 24; onActivated: backend.zoom = 24 }
            }

            Text {
                text: "Затемнение оверлея"
                color: backend.theme === "light" ? "#4B5563" : "#AAB2C0"
                font.pixelSize: 11
            }
            Row {
                spacing: 6
                SegButton { label: "Выкл"; active: backend.dimAlpha === 0; onActivated: backend.dimAlpha = 0 }
                SegButton { label: "Слабое"; active: backend.dimAlpha === 48; onActivated: backend.dimAlpha = 48 }
                SegButton { label: "Среднее"; active: backend.dimAlpha === 80; onActivated: backend.dimAlpha = 80 }
                SegButton { label: "Сильное"; active: backend.dimAlpha === 128; onActivated: backend.dimAlpha = 128 }
            }

            Text {
                text: "Хоткей (ctrl+alt+c, Enter — применить)"
                color: backend.theme === "light" ? "#4B5563" : "#AAB2C0"
                font.pixelSize: 11
            }
            RowLayout {
                spacing: 10
                Rectangle {
                    id: hotkeyBox
                    property bool ok: true
                    width: 220; height: 30; radius: 8
                    color: backend.theme === "light" ? "#FFFFFF" : "#171D28"
                    border.color: hotkeyBox.ok ? (backend.theme === "light" ? "#D1D5DB" : "#3C4454") : "#FF6B6B"
                    TextInput {
                        anchors.fill: parent; anchors.margins: 6
                        color: backend.theme === "light" ? "#111827" : "#F3F6FF"
                        font.pixelSize: 12
                        text: backend.hotkey; clip: true
                        onAccepted: {
                            hotkeyBox.ok = backend.trySetHotkey(text)
                            if (hotkeyBox.ok) { savedLabel.visible = true; saveTimer.restart() }
                            else savedLabel.visible = false
                        }
                    }
                }
                Text {
                    id: savedLabel
                    text: "✓ Сохранено"
                    color: "#4CAF50"
                    font.pixelSize: 12; font.bold: true; visible: false
                    Layout.alignment: Qt.AlignVCenter
                }
            }

            Timer { id: saveTimer; interval: 2000; running: false; repeat: false; onTriggered: savedLabel.visible = false }

            Text {
                text: "Модификаторы: ctrl, alt, shift, win · клавиши: a-z, 0-9, f1-f12, space"
                color: backend.theme === "light" ? "#6B7280" : "#9CA3AF"
                font.pixelSize: 10; wrapMode: Text.Wrap; Layout.fillWidth: true
            }

            DarkCheckBox { text: "Запускаться вместе с системой"; checked: backend.autostart; onToggled: backend.autostart = checked }

            Item { Layout.fillHeight: true }

            Button {
                text: "Сбросить к настройкам по умолчанию"
                onClicked: backend.resetSettings()
                padding: 7; leftPadding: 14; rightPadding: 14
                contentItem: Text {
                    text: parent.text
                    color: "#D97706"
                    font.pixelSize: 12
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle {
                    color: parent.hovered ? (backend.theme === "light" ? "#FDE68A" : "#4A3520")
                                           : (backend.theme === "light" ? "#FEF3C7" : "#3D2E1A")
                    radius: 10
                    border.color: "#D97706"
                }
            }

            Button {
                text: "Закрыть"
                onClicked: settingsWindow.visible = false
                padding: 7; leftPadding: 16; rightPadding: 16
                contentItem: Text {
                    text: parent.text
                    color: backend.theme === "light" ? "#111827" : "white"
                    font.pixelSize: 12
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle {
                    color: parent.hovered ? (backend.theme === "light" ? "#E5E7EB" : "#232D3F")
                                           : (backend.theme === "light" ? "#F3F4F6" : "#171D28")
                    radius: 10
                    border.color: backend.theme === "light" ? "#D1D5DB" : "#3C4454"
                }
            }
        }
    }

    // ------------------------------------------------------------------------
    // Главный интерфейс
    // ------------------------------------------------------------------------
    Text {
        id: savedToast
        text: "✓ Настройки сохранены"
        color: "#4CAF50"
        font.pixelSize: 13; font.bold: true; visible: false
        anchors.bottom: parent.bottom; anchors.bottomMargin: 20
        anchors.horizontalCenter: parent.horizontalCenter; z: 100
    }
    Timer { id: savedTimer; interval: 2000; running: false; repeat: false; onTriggered: savedToast.visible = false }

    Flickable {
        anchors.fill: parent
        contentWidth: width
        contentHeight: contentColumn.implicitHeight + 32
        ScrollBar.vertical: ScrollBar {}

        ColumnLayout {
            id: contentColumn
            x: 16; y: 16; width: root.width - 32; spacing: 10

            Text {
                text: "PaletteSniper"
                color: backend.theme === "light" ? "#1F2937" : "#E5E7EB"
                font.pixelSize: 22
                font.weight: Font.Black
            }
            Text {
                text: "«Взять цвет» или " + backend.hotkey + " — затем клик по любому месту экрана."
                color: backend.theme === "light" ? "#6B7280" : "#9CA3AF"
                font.pixelSize: 11; wrapMode: Text.Wrap; Layout.fillWidth: true
            }

            Row {
                spacing: 8
                Button {
                    id: pickButton
                    text: "Взять цвет"
                    onClicked: root.openPicker()
                    padding: 7; leftPadding: 14; rightPadding: 14
                    contentItem: Text {
                        text: pickButton.text
                        color: "white"
                        font.pixelSize: 12
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        color: pickButton.hovered ? "#8FABFF" : "#7C9CFF"
                        radius: 10
                    }
                }
                Button {
                    id: settingsButton
                    text: "Настройки"
                    onClicked: settingsWindow.show()
                    padding: 7; leftPadding: 14; rightPadding: 14
                    contentItem: Text {
                        text: settingsButton.text
                        color: backend.theme === "light" ? "#111827" : "#F3F6FF"
                        font.pixelSize: 12
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        color: settingsButton.hovered ? (backend.theme === "light" ? "#E5E7EB" : "#232D3F")
                                                       : (backend.theme === "light" ? "#F3F4F6" : "#171D28")
                        radius: 10
                        border.color: backend.theme === "light" ? "#D1D5DB" : "#3C4454"
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true; height: 110; radius: 16
                color: backend.hex
                border.color: backend.theme === "light" ? "#E4E7EB" : "#2A3346"
                Text {
                    anchors.centerIn: parent
                    text: backend.hex
                    color: backend.bestText
                    font.pixelSize: 22
                    font.weight: Font.Black
                }
            }

            GridLayout {
                Layout.fillWidth: true; columns: 3; columnSpacing: 8; rowSpacing: 6

                Text { text: "HEX"; color: backend.theme === "light" ? "#4B5563" : "#AAB2C0"; font.pixelSize: 11; Layout.preferredWidth: 70 }
                Text { text: backend.hex; color: backend.theme === "light" ? "#111827" : "#F3F6FF"; font.pixelSize: 11; font.bold: true; Layout.fillWidth: true }
                CopyButton { copyText: backend.hex }

                Text { text: "RGB"; color: backend.theme === "light" ? "#4B5563" : "#AAB2C0"; font.pixelSize: 11; Layout.preferredWidth: 70 }
                Text { text: backend.rgb; color: backend.theme === "light" ? "#111827" : "#F3F6FF"; font.pixelSize: 11; font.bold: true; Layout.fillWidth: true }
                CopyButton { copyText: backend.rgb }

                Text { text: "HSL"; color: backend.theme === "light" ? "#4B5563" : "#AAB2C0"; font.pixelSize: 11; Layout.preferredWidth: 70 }
                Text { text: backend.hsl; color: backend.theme === "light" ? "#111827" : "#F3F6FF"; font.pixelSize: 11; font.bold: true; Layout.fillWidth: true }
                CopyButton { copyText: backend.hsl }

                Text { text: "Контраст"; color: backend.theme === "light" ? "#4B5563" : "#AAB2C0"; font.pixelSize: 11; Layout.preferredWidth: 70 }
                Text {
                    text: "W " + backend.contrastWhite.toFixed(2) + " · B " + backend.contrastBlack.toFixed(2) + " · " + backend.bestText
                    color: backend.theme === "light" ? "#111827" : "#F3F6FF"
                    font.pixelSize: 11; font.bold: true; wrapMode: Text.Wrap; Layout.fillWidth: true
                }
                CopyButton { copyText: "White " + backend.contrastWhite.toFixed(2) + ":1 · Black " + backend.contrastBlack.toFixed(2) + ":1 · Text " + backend.bestText }
            }

            Text {
                text: "Палитра"
                color: backend.theme === "light" ? "#1F2937" : "#E5E7EB"
                font.pixelSize: 13
                font.weight: Font.Bold
            }
            Flow {
                Layout.fillWidth: true; spacing: 6
                Repeater {
                    model: backend.palette
                    Rectangle {
                        width: 96; height: 46; radius: 12
                        color: modelData.color
                        border.color: backend.theme === "light" ? "#D1D5DB" : "#3C4454"
                        Text {
                            anchors.centerIn: parent
                            text: modelData.name + "\n" + modelData.hex
                            color: modelData.text
                            horizontalAlignment: Text.AlignHCenter
                            font.bold: true
                            font.pixelSize: 9
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: backend.copyText(modelData.hex) }
                    }
                }
            }

            RowLayout {
                spacing: 8; Layout.topMargin: 2
                Text {
                    text: "История"
                    color: backend.theme === "light" ? "#1F2937" : "#E5E7EB"
                    font.pixelSize: 13
                    font.weight: Font.Bold
                }
                Button {
                    text: "очистить"
                    onClicked: backend.clearHistory()
                    padding: 3; leftPadding: 8; rightPadding: 8
                    contentItem: Text {
                        text: parent.text
                        color: backend.theme === "light" ? "#4B5563" : "#AAB2C0"
                        font.pixelSize: 11
                        verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        color: parent.hovered ? (backend.theme === "light" ? "#E5E7EB" : "#232D3F")
                                               : (backend.theme === "light" ? "#F3F4F6" : "#171D28")
                        radius: 6
                        border.color: backend.theme === "light" ? "#D1D5DB" : "#3C4454"
                    }
                }
            }

            Flow {
                Layout.fillWidth: true; spacing: 6
                Repeater {
                    model: backend.history
                    Rectangle {
                        width: 30; height: 30; radius: 7
                        color: modelData.hex
                        border.color: backend.theme === "light" ? "#D1D5DB" : "#3C4454"
                        MouseArea {
                            anchors.fill: parent; acceptedButtons: Qt.LeftButton | Qt.RightButton; cursorShape: Qt.PointingHandCursor
                            onClicked: (mouse) => {
                                if (mouse.button === Qt.RightButton) backend.removeFromHistory(index)
                                else backend.copyText(modelData.hex)
                            }
                        }
                    }
                }
            }

            Text {
                text: "ЛКМ — копировать · ПКМ — удалить"
                color: backend.theme === "light" ? "#6B7280" : "#8B95A5"
                font.pixelSize: 10
            }
            Text {
                id: statusText
                text: "Готово."
                color: backend.theme === "light" ? "#6B7280" : "#8B95A5"
                font.pixelSize: 11
                Layout.topMargin: 4
            }
        }
    }
}
