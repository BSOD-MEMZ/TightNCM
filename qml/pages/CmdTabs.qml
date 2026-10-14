// CmdTabs —— 对齐官方 desktop-ui 的标签栏
// 规格：.cmd-tabs { height: 40px }；.cmd-tabs-tab { font-size:14px; padding: 0 16px;
//       line-height: 25px }
//       命中态：文字变 colorBlack1 + 字重 500，**并且激活的标签下方有一条圆角红条**
//       （实测：宽 = 标签文字宽度，高 3~4，贴标签盒底部，颜色 colorPrimary1）
import QtQuick 2.15
import TightNCM 1.0
import "../widgets"

Item {
    id: root

    // [{ text: "歌曲", count: 45 }, ...]
    property var items: []
    property int currentIndex: 0
    property int fontSize: Metrics.pTabFontSize

    // 右侧扩展位（歌单页放「搜索」按钮）
    property string extraText: ""
    property string extraIcon: "search"

    signal tabClicked(int index)
    signal extraClicked()

    height: Metrics.pTabsHeight

    Row {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter

        Repeater {
            model: root.items
            delegate: Item {
                required property int index
                required property var modelData
                readonly property bool active: root.currentIndex === index
                readonly property bool hovered: tabHover.hovered

                width: label.implicitWidth + countLabel.width + Metrics.pTabPadX * 2
                height: Metrics.pTabHeight

                Text {
                    id: label
                    anchors.left: parent.left
                    anchors.leftMargin: Metrics.pTabPadX
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.text
                    font.pixelSize: root.fontSize
                    font.weight: parent.active ? Font.Medium : Font.Normal
                    color: parent.active ? Theme.colorBlack1
                         : parent.hovered ? Theme.colorBlack3
                         : Theme.colorBlack5
                    Behavior on color { ColorAnimation { duration: 110 } }
                }

                // 数量做成上标（官方把计数抬到文字基线之上）
                Text {
                    id: countLabel
                    anchors.left: label.right
                    anchors.leftMargin: 1
                    y: label.y - 2
                    visible: modelData.count !== undefined && modelData.count > 0
                    text: visible ? String(modelData.count) : ""
                    font.pixelSize: Metrics.pTabCountFontSize
                    color: Theme.colorBlack8
                }

                // 激活态下划线（只用文字宽度，不含计数）
                Rectangle {
                    visible: parent.active
                    x: Metrics.pTabPadX
                    width: label.width
                    height: 3
                    radius: 1.5
                    color: Theme.colorPrimary1
                    anchors.bottom: parent.bottom
                }

                HoverHandler { id: tabHover }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.tabClicked(index)
                }
            }
        }
    }

    // 右侧扩展：outline 药丸按钮
    Item {
        id: extraBtn
        visible: root.extraText !== ""
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: extraRow.implicitWidth + 28
        height: 32

        readonly property bool hovered: extraHover.hovered

        RoundRect {
            anchors.fill: parent
            radius: height / 2
            color: parent.hovered ? Theme.colorBlack11 : "transparent"
            borderColor: Theme.colorBlack10
            borderWidth: 1
            Behavior on color { ColorAnimation { duration: 110 } }
        }
        Row {
            id: extraRow
            anchors.centerIn: parent
            spacing: 4
            Icon {
                name: root.extraIcon
                size: 14
                color: Theme.colorBlack5
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: root.extraText
                font.pixelSize: Metrics.fontSmall
                color: Theme.colorBlack3
                anchors.verticalCenter: parent.verticalCenter
            }
        }
        HoverHandler { id: extraHover }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.extraClicked()
        }
    }
}
