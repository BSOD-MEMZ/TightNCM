// SongList —— 可复用的歌曲表格（表头 + 虚拟化列表 + 可滚动页头）
//
// 歌单详情 / 搜索结果 / 歌手热门 / 专辑曲目 / 最近播放 全部共用这一个，
// 省得每页重写一遍 ListView + 列宽计算。
//
// 用法：
//     SongList {
//         anchors.fill: parent
//         songs: mySongs
//         headerSource: Component { PlaylistHeader { width: parent ? parent.width : 0; ... } }
//         onPlayRequested: function (i) { ... }
//     }
//
// 为什么页头要写成 Component 而不是直接塞子项：
// ListView.header 的类型是 Component（声明式写上去会被 QML 自动包一层 Component，
// 也就是**延迟实例化**），此时任何 `default property alias xxx: 内部id.data` 都
// 会在解析时拿到尚未创建的对象。用显式 Component + Loader 就能规避。
import QtQuick 2.15
import QtQuick.Controls 2.15
import TightNCM 1.0
import "../widgets"

ListView {
    id: root

    property var songs: []
    // 用歌曲 id 而不是行号来判断「是不是正在播这首」——
    // 行号只在当前列表内有效，切换页面/搜索后就对不上了。
    property var playingSongId: -1
    property real sidePadding: Metrics.pBodyPadding
    property bool showTableHeader: true
    property string emptyText: "这里还没有歌"

    // 表头以上的自定义内容（歌单封面区 / 页面标题 / 分类标签等）
    property Component headerSource: null

    // 列宽用和官方一样的 flex 语义算：width = minWidth + free * grow / growSum，
    // 表头和行传同一份，保证严丝合缝对齐。
    readonly property real contentWidth: Math.max(0, width - sidePadding * 2)
    readonly property var colWidths: {
        var cols = Metrics.tColumns
        var fixed = 0, growSum = 0
        for (var i = 0; i < cols.length; ++i) { fixed += cols[i].minWidth; growSum += cols[i].grow }
        var free = contentWidth - fixed
        var out = []
        for (i = 0; i < cols.length; ++i) {
            var w = cols[i].minWidth
            if (growSum > 0 && free > 0)
                w += free * cols[i].grow / growSum
            out.push(Math.max(cols[i].minWidth, Math.round(w)))
        }
        return out
    }

    signal playRequested(int index)
    signal likeToggled(int index)

    // ⚠️ 必须补这一下。
    // 本工程的内容区用「全部常驻 + 用 visible 切换」来保留页面状态。但 ListView
    // 的首次布局是在组件完成时就排好的 —— 那时页面还不可见，viewport 为空，
    // 于是只实例化极少数委托；等 pageKey 切过来把 visible 打开时，**没有任何属性
    // 变化来触发重新布局**，列表就一直空着。
    // 典型翻车场景：启动时就已有数据的「最近播放」；以及先加载好数据、后来才切过去的页面。
    // forceLayout() 是 ListView 自带的，正是干这个的。
    onVisibleChanged: if (visible) Qt.callLater(forceLayout)

    anchors.leftMargin: sidePadding
    anchors.rightMargin: sidePadding
    // 内容区顶部留白 18px（官方 scrollArea padding-top: 18px）
    anchors.topMargin: Metrics.pageTopPad
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    // 委托复用：长歌单（几千条）靠这个把内存压住
    reuseItems: true
    // 缓存区从 800 收到 400：长歌单下少留一半的委托实例（内存换一点点滚动顺滑度）
    cacheBuffer: 400
    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

    model: root.songs

    header: Column {
        width: root.width

        Loader {
            id: headerLoader
            width: parent.width
            // ⚠️ 必须用 implicitHeight 而不是 height：
            // Loader 在自身尺寸「有效」时会去写 item.height，若 height 又反过来绑定
            // item.height 就成了循环依赖，最终算成 0（表现为页头不占位、被列表压在下面）。
            height: headerLoader.item ? headerLoader.item.implicitHeight : 0
            sourceComponent: root.headerSource
        }

        SongTableHeader {
            width: parent.width
            visible: root.showTableHeader
            colWidths: root.colWidths
        }

        // .thead-boundary { margin-bottom: 8px } —— 这条间距在表头**下面**，
        // 之前错放到了表头上面，把整张表往下顶了 8px。
        Item {
            width: 1
            height: Metrics.tHeadGap
            visible: root.showTableHeader
        }
    }

    delegate: SongRow {
        width: root.width
        song: modelData
        colWidths: root.colWidths
        isPlaying: root.playingSongId !== -1 && modelData.id === root.playingSongId
        selected: false
        onPlayRequested: function (i) { root.playRequested(i) }
        onLikeToggled: function (i) { root.likeToggled(i) }
    }

    footer: Item {
        width: root.width
        height: 40
        Text {
            anchors.centerIn: parent
            visible: root.songs.length === 0 && root.emptyText !== ""
            text: root.emptyText
            font.pixelSize: Metrics.fontMedium
            color: Theme.colorBlack7
        }
    }
}
