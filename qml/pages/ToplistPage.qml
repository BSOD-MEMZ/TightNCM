// ToplistPage —— 排行榜
//
// 数据来自 /api/toplist/detail/v2，返回的是「榜单分组」，每组里若干榜单：
//   [{ name: "官方榜", code: "OFFICIAL", list: [{id, name, cover, updateFrequency, tracks}] }]
// 官方接口在每个榜单里塞了前几首歌（tracks），点卡片进歌单详情。
import QtQuick 2.15
import TightNCM 1.0
import "../widgets"

ScrollColumn {
    id: root

    property var blocks: []
    property bool loading: true

    signal toplistClicked(var item)
    signal artistClicked(var item)

    spacing: 0

    Text {
        text: "排行榜"
        font.pixelSize: 28
        font.weight: Font.DemiBold
        color: Theme.colorBlack1
    }
    Text {
        topPadding: 6
        text: "官方榜 / 精选榜 / 曲风榜 / 全球榜"
        font.pixelSize: Metrics.fontMedium
        color: Theme.colorBlack5
    }

    Item { width: 1; height: 12 }

    // 加载态 / 空态
    Item {
        width: 1
        height: 120
        visible: root.blocks.length === 0
        Text {
            anchors.centerIn: parent
            text: root.loading ? "加载中…" : "暂时拿不到榜单"
            font.pixelSize: Metrics.fontMedium
            color: Theme.colorBlack7
        }
    }

    Repeater {
        model: root.blocks
        delegate: VStack {
            required property var modelData
            width: root.width
            spacing: 0

            SectionTitle {
                width: parent.width
                text: modelData.name
            }

            CardGrid {
                items: modelData.list || []
                cardSize: 168
                subtitleField: "updateFrequency"
                countField: ""
                fallbackIcon: "rankflat"
                onCardClicked: function (item) { root.toplistClicked(item) }
            }

            Item { width: 1; height: 16 }
        }
    }
}
