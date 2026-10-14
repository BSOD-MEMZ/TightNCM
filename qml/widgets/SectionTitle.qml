// SectionTitle —— 区块标题
//
// 规格（官方 .cmd-section-title / 首页分组头）：
//   标题 20px weight 600 colorBlack1
//   右侧「更多 >」12px colorBlack5，hover 变 colorBlack3
import QtQuick 2.15
import TightNCM 1.0
import "../widgets"

Item {
    id: root

    property string text: ""
    property string actionText: ""        // 留空则不显示
    property int fontSize: 20

    signal actionClicked()

    height: actionText !== "" ? 44 : 36

    Text {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        text: root.text
        font.pixelSize: root.fontSize
        font.weight: Font.DemiBold
        color: Theme.colorBlack1
    }

    // 右侧「更多」：整块可点。
    // 注意 MouseArea 不能放在 Row 里面 —— Row 的子项不能使用 anchors.fill。
    Item {
        id: actionArea
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: actionRow.implicitWidth + 8
        height: parent.height
        visible: root.actionText !== ""

        Row {
            id: actionRow
            anchors.centerIn: parent
            spacing: 2

            Text {
                text: root.actionText
                font.pixelSize: Metrics.fontSmall
                color: moreHover.hovered ? Theme.colorBlack3 : Theme.colorBlack5
                anchors.verticalCenter: parent.verticalCenter
                Behavior on color { ColorAnimation { duration: 110 } }
            }
            Icon {
                name: "forward"
                size: 12
                color: moreHover.hovered ? Theme.colorBlack3 : Theme.colorBlack5
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        HoverHandler { id: moreHover }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.actionClicked()
        }
    }
}
