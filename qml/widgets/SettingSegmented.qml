// SettingSegmented —— 设置页里的分段选择（下载音质 / 同时下载数）
import QtQuick 2.15
import TightNCM 1.0
import "../widgets"

Item {
    id: root

    property var    options: []
    property int    currentIndex: 0
    property string tip: ""

    signal activated(int index)

    implicitHeight: Math.max(32, tipText.height)
    implicitWidth: segRow.width + (tip === "" ? 0 : 16 + tipText.width)
    height: implicitHeight

    Row {
        id: segRow
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8

        Repeater {
            model: root.options
            delegate: Item {
                required property int index
                required property var modelData
                readonly property bool active: root.currentIndex === index
                width: segText.width + 28
                height: 32

                RoundRect {
                    anchors.fill: parent
                    radius: 8
                    color: parent.active ? Theme.colorPrimary7
                         : segHover.hovered ? Theme.colorBlack11
                         : "transparent"
                    borderColor: parent.active ? Theme.colorPrimary1 : Theme.colorBlack10
                    borderWidth: 1
                    Behavior on color { ColorAnimation { duration: 110 } }
                }
                Text {
                    id: segText
                    anchors.centerIn: parent
                    text: modelData
                    font.pixelSize: Metrics.sRowTextSize
                    color: parent.active ? Theme.colorPrimary1 : Theme.colorBlack3
                }
                HoverHandler { id: segHover }
                TapHandler { onTapped: root.activated(index) }
            }
        }
    }

    Text {
        id: tipText
        visible: root.tip !== ""
        anchors.left: segRow.right
        anchors.leftMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        text: root.tip
        font.pixelSize: Metrics.sRowTextSize
        color: Theme.colorBlack6
    }
}
