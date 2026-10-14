// FeaturedPage —— 精选 / 歌单广场
//
// 数据来自 /api/playlist/highquality/list?cat=<分类>&limit=N&lasttime=0
// 顶部分类标签是官方「歌单广场」的那套（来自 /api/playlist/category/list 的 tags 语义）。
import QtQuick 2.15
import TightNCM 1.0
import "../widgets"

ScrollColumn {
    id: root

    property var playlists: []
    property string category: "全部"
    property bool loading: true

    signal playlistClicked(var item)
    // 注意：不能叫 categoryChanged —— property string category 会自动生成同名信号
    signal categorySelected(string cat)

    readonly property var categories: [
        "全部", "华语", "欧美", "流行", "摇滚", "民谣", "电子", "说唱",
        "轻音乐", "爵士", "乡村", "古典", "民族", "英伦", "粤语",
        "日语", "韩语", "小语种", "夜晚", "学习", "工作", "运动", "旅行"
    ]

    spacing: 0

    Text {
        text: "精选"
        font.pixelSize: 28
        font.weight: Font.DemiBold
        color: Theme.colorBlack1
    }
    Text {
        topPadding: 6
        text: "歌单广场 · 按标签挑"
        font.pixelSize: Metrics.fontMedium
        color: Theme.colorBlack5
    }

    Item { width: 1; height: 16 }

    // ── 分类标签（自动换行） ─────────────────────────
    Flow {
        width: parent.width
        spacing: 8

        Repeater {
            model: root.categories
            delegate: Item {
                required property string modelData
                readonly property bool active: root.category === modelData
                readonly property bool hovered: chipHover.hovered

                width: chipText.width + 24
                height: 30

                RoundRect {
                    anchors.fill: parent
                    radius: 15
                    color: parent.active ? Theme.brand
                         : parent.hovered ? Theme.colorBlack10
                         : "transparent"
                    borderColor: parent.active ? "transparent" : Theme.colorBlack10
                    borderWidth: 1
                    Behavior on color { ColorAnimation { duration: 110 } }
                }
                Text {
                    id: chipText
                    anchors.centerIn: parent
                    text: modelData
                    font.pixelSize: Metrics.fontSmall
                    color: parent.active ? Theme.colorWhite1 : Theme.colorBlack3
                    Behavior on color { ColorAnimation { duration: 110 } }
                }

                HoverHandler { id: chipHover }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.categorySelected(modelData)
                }
            }
        }
    }

    Item { width: 1; height: 20 }

    Item {
        width: 1
        height: 120
        visible: root.playlists.length === 0
        Text {
            anchors.centerIn: parent
            text: root.loading ? "加载中…" : ("「" + root.category + "」下没取到歌单")
            font.pixelSize: Metrics.fontMedium
            color: Theme.colorBlack7
        }
    }

    CardGrid {
        items: root.playlists
        cardSize: 168
        subtitleField: "author"
        onCardClicked: function (item) { root.playlistClicked(item) }
    }

    Item { width: 1; height: 20 }
}
