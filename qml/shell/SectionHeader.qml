// SectionHeader —— 侧栏分组头（「创建的歌单 N」/「收藏的歌单 N」）
//
// 官方实测：TitleContainer_t2femva 164 × 32
//   标题文字  x = 容器左 + 10，字号 12，字重 600，颜色 colorBlack7
//   收起箭头  正文右边 4px，16×16（展开时是 sidebar_slide_up）
//   新建按钮  贴右边缘，30×32 热区，图标 16×16 居中
import QtQuick 2.15
import TightNCM 1.0
import "../widgets"

Item {
    id: root

    property string title: ""
    property int count: 0
    property bool expanded: true
    property bool showAdd: true

    signal toggled()
    signal addClicked()

    height: Metrics.sectionHeaderHeight

    readonly property bool hovered: hh.hovered

    // 标题 + 箭头（箭头紧跟文字）
    Row {
        anchors.verticalCenter: parent.verticalCenter
        x: Metrics.sectionHeaderPadL + 1        // 官方 34 - 24（容器左） = 10
        spacing: 4

        Text {
            id: label
            text: root.count > 0 ? (root.title + " " + root.count) : root.title
            anchors.verticalCenter: parent.verticalCenter
            font.pixelSize: Metrics.fontSmall
            font.weight: Font.DemiBold
            color: Theme.colorBlack7
        }

        Icon {
            // 只有 sidebar_slide_up 这一份资源（没有 sidebar_slide_down），
            // 收起态用旋转 180° 代替换图，保证两个方向长得一模一样。
            name: "sidebar_slide_up"
            size: 16
            rotation: root.expanded ? 0 : 180
            color: Theme.colorBlack5
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    // 右侧：新建歌单按钮
    // 实测官方的 AddPointer（30×32 热区 + 14×14 圆底 + 16 图标）是**常驻**的，
    // 不是 hover 才出现 —— 之前写成 hover-only，分组头右边就空了一块。
    Item {
        x: root.width - 30
        width: 30
        height: parent.height
        anchors.verticalCenter: parent.verticalCenter
        visible: root.showAdd

        // 官方 IconWithBackground：14×14 的圆形浅底（rgba(40,50,72,0.1)），图标 16 叠在上面
        RoundRect {
            anchors.centerIn: parent
            width: Metrics.sectionAddDotSize
            height: Metrics.sectionAddDotSize
            radius: width / 2
            color: Theme.colorBlack10
        }
        Icon {
            anchors.centerIn: parent
            name: "sidebar_add"
            size: 16
            color: Theme.colorBlack5
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.addClicked()
        }
    }

    HoverHandler { id: hh }
    MouseArea {
        anchors.fill: parent
        anchors.rightMargin: root.showAdd ? 30 : 0
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }
}
