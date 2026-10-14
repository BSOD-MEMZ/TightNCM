// SongTableHeader —— 歌曲表格表头
// 实测：.thead 高 41（= .tr 40 + 底边线 1），底边线 1px colorBlack12，
//       色 colorBlack5，.th 高 39 line-height 39 padding-top 1
//       .th-num padding-left 20，其余 .td/.th padding 0 8，首列 padding-left 16
import QtQuick 2.15
import TightNCM 1.0
import "../widgets"

Item {
    id: root

    property var columns: Metrics.tColumns
    property var colWidths: [45, 180, 115, 60, 64]
    property bool showBoundary: true

    signal sortRequested(string key)

    height: Metrics.tHeadTotal

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 1
        color: root.showBoundary ? Theme.colorBlack12 : "transparent"
    }

    Row {
        anchors.fill: parent

        Repeater {
            model: root.columns
            delegate: Item {
                required property int index
                required property var modelData
                width: root.colWidths[index]
                height: root.height

                readonly property bool hovered: thHover.hovered
                readonly property bool isNum: modelData.key === "num"

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    x: parent.isNum ? 12 : 0
                    width: parent.width - (parent.isNum ? 24 : 0)
                    height: 32
                    radius: 8
                    color: parent.hovered ? Theme.colorBlack12 : "transparent"
                }

                Text {
                    // th-num 额外 padding-left: 20px；其余用 td 的 0 8px
                    x: parent.isNum ? 20 : Metrics.tCellPaddingX
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.title
                    font.pixelSize: Metrics.fontSmall
                    color: Theme.colorBlack5
                }

                HoverHandler { id: thHover }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.sortRequested(modelData.key)
                }
            }
        }
    }
}
