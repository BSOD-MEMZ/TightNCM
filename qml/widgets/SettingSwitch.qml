// SettingSwitch —— 设置页里的开关（对齐官方 cmd-switch 的观感）
import QtQuick 2.15
import TightNCM 1.0
import "../widgets"

Item {
    id: root

    property bool   checked: false
    property string text: ""
    property string tip: ""

    signal toggled(bool checked)

    implicitWidth: textRow.width
    // ⚠️ 必须同时给 height —— Item 的 height 默认是 0，
    // 外层 VStack / SettingRow 读到 0 就会把整段排成一坨（实测：设置页「播放」那几行重叠）
    implicitHeight: Math.max(20, textRow.height)
    height: implicitHeight

    readonly property bool hovered: hh.hovered

    Row {
        id: textRow
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: 12

        Text {
            text: root.text
            font.pixelSize: Metrics.sRowTextSize
            color: Theme.colorBlack2
            anchors.verticalCenter: parent.verticalCenter
        }

        // 药丸开关
        Item {
            width: 36
            height: 20
            anchors.verticalCenter: parent.verticalCenter

            RoundRect {
                anchors.fill: parent
                radius: height / 2
                color: root.checked ? Theme.colorPrimary1
                     : root.hovered ? Theme.colorBlack10
                     : Theme.colorBlack9
                Behavior on color { ColorAnimation { duration: 120 } }
            }
            RoundRect {
                width: 16; height: 16
                radius: 8
                color: Theme.colorWhite1
                anchors.verticalCenter: parent.verticalCenter
                x: root.checked ? parent.width - width - 2 : 2
                Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
            }
        }

        Text {
            visible: root.tip !== ""
            text: root.tip
            font.pixelSize: Metrics.sRowTextSize
            color: Theme.colorBlack6
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    HoverHandler { id: hh }
    TapHandler { onTapped: root.toggled(!root.checked) }
}
