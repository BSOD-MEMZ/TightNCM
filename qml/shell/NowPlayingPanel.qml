// NowPlayingPanel —— 「正在播放」全屏页（点播放栏左侧封面打开，官方同款）
//
// 官方：点播放栏封面 → 进入播放详情。左半是旋转的黑胶（封面做盘面），
// 右半是歌名 + 歌手/专辑 + 歌词滚动，右下角是「评论」入口。
//
// 几点和 LyricPanel 的区别（所以单独做一个组件，不复用）：
//   * 黑胶会随播放状态**旋转**（这里用 RotationAnimation，暂停就停在原角度）
//   * 封面是**圆形**盘面，不是圆角矩形
//   * 保留底部播放栏（anchors.bottom: playBar.top 由外部决定），只盖住上面
import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls 2.15
import TightNCM 1.0
import "../widgets"

Item {
    id: root

    property bool open: false
    property var lines: []              // [{t, text, tr}]
    property int positionMs: 0
    property string cover: ""
    property string title: ""
    property string artist: ""
    property string album: ""
    property bool playing: false
    property int commentCount: 0

    signal closeRequested()
    signal commentsRequested()
    signal seekRequested(int ms)

    readonly property int currentLine: {
        var idx = -1
        for (var i = 0; i < lines.length; ++i) {
            if (lines[i].t <= positionMs) idx = i
            else break
        }
        return idx
    }

    // 从下方滑入：官方是「向上收起/展开」，这里用 y 位移，收起时彻底移出并停止拦截事件
    y: open ? 0 : parent.height
    Behavior on y { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
    visible: y < parent.height

    Rectangle {
        anchors.fill: parent
        color: Theme.pageBackground
    }

    // ── 左：黑胶 ────────────────────────────────────
    // 官方的黑胶结构（从外到内）：
    //   唱片外圈深色圆 → 盘面（封面，圆形裁切）→ 中心轴孔（浅色小圆）
    // 封面直接当盘面用，所以外面那圈深色只露出一圈边（8px）。
    Item {
        id: disc
        width: 300
        height: 300
        anchors.left: parent.left
        anchors.leftMargin: 96
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -20

        // 唱片外圈
        RoundRect {
            anchors.fill: parent
            radius: width / 2
            color: "#2B2727"
        }

        // 会转的那一层：盘面 + 封面 + 中心孔
        Item {
            id: spinner
            anchors.fill: parent
            // 官方的封面只占盘面中间一块（外面那圈黑胶留得挺宽），
            // 铺满整盘会变成"一张圆形封面贴片"，没有黑胶的感觉。
            anchors.margins: 56

            // 封面铺满 + 圆形遮罩。
            // RoundRect + clip 只裁矩形边界，盘面会变成旋转的方块；
            // 遮罩用 CircleMask（Shapes 几何挖洞），软件后端下也成立。
            Image {
                id: discCover
                anchors.fill: parent
                source: root.cover
                sourceSize.width: Math.max(1, Math.round(width * Screen.devicePixelRatio))
                sourceSize.height: Math.max(1, Math.round(height * Screen.devicePixelRatio))
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: status === Image.Ready
            }
            // 遮罩色必须 = 下面那张「唱片外圈」的颜色（#2B2727）。
            // 一开始填的是页面背景色，结果和封面自身的白底几乎同色，
            // 看起来"遮罩没生效、封面还是方块" —— 换成品红才看出遮罩其实一直是对的。
            // 填黑胶色之后，方形四角与外盘融为一体，视觉上就是一张圆盘 + 居中圆形封面。
            CircleMask { anchors.fill: parent; coverColor: "#2B2727" }
            Icon {
                anchors.centerIn: parent
                visible: discCover.status !== Image.Ready
                name: "music"
                size: 56
                color: Theme.colorBlack8
            }

            // 中心轴孔
            RoundRect {
                anchors.centerIn: parent
                width: 44
                height: 44
                radius: 22
                color: Theme.pageBackground
            }
            RoundRect {
                anchors.centerIn: parent
                width: 12
                height: 12
                radius: 6
                color: "#2B2727"
            }

            RotationAnimation on rotation {
                from: 0
                to: 360
                duration: 24000
                loops: Animation.Infinite
                running: root.playing && root.open
            }
        }
    }

    // ── 右：歌名 / 歌词 ──────────────────────────────
    Item {
        anchors.left: disc.right
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.leftMargin: 72
        anchors.rightMargin: 96
        anchors.topMargin: 72
        anchors.bottomMargin: 96

        // 标题区固定在顶部，歌词区在它下面独立滚动
        VStack {
            id: head
            width: parent.width
            spacing: 6

            Text {
                width: parent.width
                text: root.title || "未在播放"
                font.pixelSize: 24
                font.weight: Font.DemiBold
                color: Theme.colorBlack1
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                text: root.artist
                font.pixelSize: Metrics.fontMedium
                color: Theme.colorBlack5
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                text: root.album ? ("专辑：" + root.album) : ""
                visible: text !== ""
                font.pixelSize: Metrics.fontSmall
                color: Theme.colorBlack6
                elide: Text.ElideRight
            }
        }

        ListView {
            id: lyricList
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: head.bottom
            anchors.topMargin: 24
            anchors.bottom: parent.bottom
            clip: true
            model: root.lines
            spacing: 8
            boundsBehavior: Flickable.StopAtBounds
            cacheBuffer: 600

            delegate: Item {
                required property int index
                required property var modelData
                width: lyricList.width
                height: lt.implicitHeight + (modelData.tr ? tt.implicitHeight + 2 : 0) + 10

                readonly property bool current: index === root.currentLine

                VStack {
                    width: parent.width
                    spacing: 2

                    Text {
                        id: lt
                        width: parent.width
                        text: modelData.text
                        font.pixelSize: parent.parent.current ? 18 : 16
                        font.weight: parent.parent.current ? Font.DemiBold : Font.Normal
                        color: parent.parent.current ? Theme.colorBlack1 : Theme.colorBlack7
                        wrapMode: Text.Wrap
                        Behavior on color { ColorAnimation { duration: 180 } }
                    }
                    Text {
                        id: tt
                        width: parent.width
                        visible: text !== ""
                        text: modelData.tr || ""
                        font.pixelSize: 13
                        color: Theme.colorBlack5
                        wrapMode: Text.Wrap
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.seekRequested(modelData.t)
                }
            }
        }

        Text {
            anchors.centerIn: lyricList
            visible: root.lines.length === 0
            text: "这首歌没有歌词"
            font.pixelSize: Metrics.fontNormal
            color: Theme.colorBlack7
        }
    }

    onVisibleChanged: if (visible) Qt.callLater(lyricList.forceLayout)
    onCurrentLineChanged: scrollToCurrent()
    onOpenChanged: if (open) Qt.callLater(scrollToCurrent)

    function scrollToCurrent() {
        if (root.currentLine < 0 || root.currentLine >= lyricList.count)
            return
        if (lyricList.moving || lyricList.flicking)
            return
        lyricList.positionViewAtIndex(root.currentLine, ListView.Center)
    }

    // ── 收起（左下角向下箭头，官方同位置） ─────────────
    Item {
        width: 32
        height: 32
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.leftMargin: 32
        anchors.bottomMargin: 24

        RoundRect {
            anchors.fill: parent
            radius: 16
            color: npHover.hovered ? Theme.colorBlack11 : "transparent"
        }
        Icon {
            anchors.centerIn: parent
            name: "unfold"          // 官方 cmd-icon-unfold，收起时朝下
            size: 16
            color: Theme.colorBlack3
            rotation: 180
        }
        HoverHandler { id: npHover }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.closeRequested()
        }
    }

    // ── 评论入口（右下） ─────────────────────────────
    Item {
        width: 96
        height: 32
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: 32
        anchors.bottomMargin: 24

        RoundRect {
            anchors.fill: parent
            radius: 16
            color: cmHover.hovered ? Theme.colorBlack11 : Theme.colorBlack12
        }
        Row {
            anchors.centerIn: parent
            spacing: 6
            Icon { name: "comment"; size: 16; color: Theme.colorBlack3; anchors.verticalCenter: parent.verticalCenter }
            Text {
                text: root.commentCount > 0 ? String(root.commentCount) : "评论"
                font.pixelSize: Metrics.fontSmall
                color: Theme.colorBlack2
                anchors.verticalCenter: parent.verticalCenter
            }
        }
        HoverHandler { id: cmHover }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.commentsRequested()
        }
    }
}
