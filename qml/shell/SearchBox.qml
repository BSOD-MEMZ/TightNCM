// SearchBox —— 顶栏搜索框
// 实测：258 × 36，border-radius 8px，字号 14px
// 官方 class: cmd-input-wrapper searchbox background-normal-border
import QtQuick 2.15
import TightNCM 1.0
import "../widgets"

Item {
    id: root

    property alias text: input.text
    property string placeholder: "搜索音乐/视频/电台/用户"
    property bool showClear: input.text.length > 0 && input.activeFocus

    signal accepted(string text)

    implicitWidth: Metrics.searchBoxWidth
    implicitHeight: Metrics.searchBoxHeight

    readonly property bool hovered: hh.hovered

    RoundRect {
        anchors.fill: parent
        radius: 8
        color: root.hovered || input.activeFocus ? Theme.colorBlack11 : Theme.colorBlack12
        borderColor: Theme.colorBlack10
        borderWidth: 1
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    Row {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 10
        spacing: 8

        Icon {
            name: "search"
            size: 16
            color: input.activeFocus ? Theme.colorBlack3 : Theme.colorBlack6
            anchors.verticalCenter: parent.verticalCenter
        }

        TextInput {
            id: input
            width: parent.width - 16 - 8 - (root.showClear ? 24 : 0)
            anchors.verticalCenter: parent.verticalCenter
            verticalAlignment: TextInput.AlignVCenter
            font.pixelSize: Metrics.fontMedium
            color: Theme.colorBlack1
            selectByMouse: true
            clip: true

            Text {
                text: root.placeholder
                visible: !input.text && !input.activeFocus
                font: input.font
                color: Theme.colorBlack8
                anchors.verticalCenter: parent.verticalCenter
            }

            onAccepted: root.accepted(text)
        }

        Icon {
            name: "close"
            size: 14
            color: Theme.colorBlack6
            visible: root.showClear
            anchors.verticalCenter: parent.verticalCenter
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: { input.text = ""; input.forceActiveFocus(); }
            }
        }
    }

    HoverHandler { id: hh }
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.IBeamCursor
        onClicked: input.forceActiveFocus()
    }
}
