// CardGrid —— 卡片网格（歌单 / 专辑 / 歌手 / 电台通用）
//
// 首页、精选、排行榜、歌手页的专辑区、播客页都用它。
//
// 为什么不用 Grid + Repeater：
// Grid 是 positioner，它的布局发生在 polish 阶段。实测在本工程里 ——
// 数据在首帧之后才从「空」变成「非空」（接口回调）时，Grid **不会重新排布子项**，
// 结果是所有卡片叠在同一个 x/y、Grid 自身高度停在 0，把后面的区块全压上来。
// 所以这里改成在普通 Item 里手动算 x/y：完全确定，不依赖 positioner 的时序。
import QtQuick 2.15
import TightNCM 1.0
import "../widgets"

Item {
    id: root

    property var  items: []
    property real cardSize: 168
    property real hSpacing: 20
    property real vSpacing: 24

    // 字段映射
    property string titleField:    "name"
    property string coverField:    "cover"
    property string subtitleField: ""          // 空则不显示副标题
    property string countField:    "playCount" // 空则不显示播放量
    property string badgeField:    ""
    property bool   round: false
    property string fallbackIcon: "playlist"

    signal cardClicked(var item)
    signal cardPlayClicked(var item)

    // 单元格：封面 + 8 + 标题两行 + 副标题行
    readonly property real cellHeight: cardSize + 8 + 34 + (subtitleField !== "" ? 18 : 0) + 8
    readonly property int colCount: Math.max(1, Math.floor((width + hSpacing) / (cardSize + hSpacing)))
    readonly property int rowCount: Math.ceil(items.length / colCount)

    width: parent ? parent.width : 0
    height: rowCount * cellHeight + Math.max(0, rowCount - 1) * vSpacing

    Repeater {
        model: root.items
        delegate: Item {
            required property int index
            required property var modelData

            width: root.cardSize
            height: root.cellHeight
            x: Math.round((index % root.colCount) * (root.cardSize + root.hSpacing))
            y: Math.round(Math.floor(index / root.colCount) * (root.cellHeight + root.vSpacing))

            PlaylistCard {
                anchors.top: parent.top
                anchors.left: parent.left
                cardSize: root.cardSize
                round: root.round
                fallbackIcon: root.fallbackIcon
                title: root.titleField    ? (modelData[root.titleField] || "") : ""
                cover: root.coverField    ? (modelData[root.coverField] || "") : ""
                subtitle: root.subtitleField ? (modelData[root.subtitleField] || "") : ""
                playCount: root.countField ? (modelData[root.countField] || 0) : 0
                badge: root.badgeField    ? (modelData[root.badgeField] || "") : ""
                onClicked: root.cardClicked(modelData)
                onPlayClicked: root.cardPlayClicked(modelData)
            }
        }
    }
}
