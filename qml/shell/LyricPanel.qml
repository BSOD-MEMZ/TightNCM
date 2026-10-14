// LyricPanel —— 歌词页（覆盖内容区）
//
// 歌词格式有坑：新版 web 播放器返回的 lrc.lyric **不是 LRC 文本，而是 JSONL**：
//     {"t":0,"c":[{"tx":"作词: "},{"tx":"张国祥"}]}
// C++ 侧（NcmApi::parseLyric）已经统一解析成 [{t: 毫秒, text, tr}]，这里只管展示。
import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls 2.15
import TightNCM 1.0
import "../widgets"

Item {
    id: root

    property bool open: false
    property var lines: []            // [{t, text, tr}]
    property int positionMs: 0
    property string cover: ""
    property string title: ""
    property string artist: ""

    signal closeRequested()

    // 当前行：最后一个 t <= positionMs 的行
    readonly property int currentLine: {
        var idx = -1
        for (var i = 0; i < lines.length; ++i) {
            if (lines[i].t <= positionMs) idx = i
            else break
        }
        return idx
    }

    // 关闭时完全移出视野并停止拦截事件
    x: open ? 0 : parent.width
    Behavior on x { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
    visible: x < parent.width

    Rectangle {
        anchors.fill: parent
        color: Theme.pageBackground
    }

    // ── 左：封面 ────────────────────────────────────
    Item {
        id: coverArea
        width: 320
        height: 320
        anchors.left: parent.left
        anchors.leftMargin: 72
        anchors.verticalCenter: parent.verticalCenter

        RoundRect {
            x: 14
            y: -10
            width: parent.width - 28
            height: parent.height - 28
            radius: 10
            color: Theme.colorBlack11
        }
        RoundRect {
            anchors.fill: parent
            radius: 14
            color: Theme.colorBlack12
            clip: true

            Image {
                id: bigCover
                anchors.fill: parent
                source: root.cover
                sourceSize.width: Math.max(1, Math.round(width * Screen.devicePixelRatio))
                sourceSize.height: Math.max(1, Math.round(height * Screen.devicePixelRatio))
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: status === Image.Ready
            }
            Icon {
                anchors.centerIn: parent
                visible: bigCover.status !== Image.Ready
                name: "music"
                size: 64
                color: Theme.colorBlack8
            }
        }
    }

    // ── 右：歌词 ────────────────────────────────────
    Item {
        anchors.left: coverArea.right
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.leftMargin: 48
        anchors.rightMargin: 72
        anchors.topMargin: 80
        anchors.bottomMargin: 80
        clip: true

        Column {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            width: parent.width
            spacing: 4
            visible: root.lines.length === 0

            Text {
                text: root.title
                font.pixelSize: 22
                font.weight: Font.DemiBold
                color: Theme.colorBlack1
                width: parent.width
                elide: Text.ElideRight
            }
            Text {
                text: root.artist
                font.pixelSize: Metrics.fontMedium
                color: Theme.colorBlack5
                width: parent.width
                elide: Text.ElideRight
            }
            Item { width: 1; height: 20 }
            Text {
                text: "这首歌没有歌词"
                font.pixelSize: Metrics.fontNormal
                color: Theme.colorBlack7
            }
        }

        ListView {
            id: lyricList
            anchors.fill: parent
            clip: true
            model: root.lines
            spacing: 6
            boundsBehavior: Flickable.StopAtBounds
            highlightMoveDuration: 260
            cacheBuffer: 600

            delegate: Item {
                required property int index
                required property var modelData
                width: lyricList.width
                height: lyricText.implicitHeight + (modelData.tr ? trText.implicitHeight + 2 : 0) + 10

                readonly property bool current: index === root.currentLine

                Column {
                    width: parent.width
                    spacing: 2

                    Text {
                        id: lyricText
                        width: parent.width
                        text: modelData.text
                        font.pixelSize: parent.parent.current ? 18 : 16
                        font.weight: parent.parent.current ? Font.DemiBold : Font.Normal
                        color: parent.parent.current ? Theme.colorBlack1 : Theme.colorBlack7
                        wrapMode: Text.Wrap
                        Behavior on color { ColorAnimation { duration: 180 } }
                    }
                    Text {
                        id: trText
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
    }

    signal seekRequested(int ms)

    // 同 SongList 的理由：不可见时完成的布局，在变可见后不会自动重来
    onVisibleChanged: if (visible) Qt.callLater(lyricList.forceLayout)

    // 当前行变化 → 把它滚到中间
    onCurrentLineChanged: scrollToCurrent()
    onOpenChanged: if (open) Qt.callLater(scrollToCurrent)

    function scrollToCurrent() {
        if (root.currentLine < 0 || root.currentLine >= lyricList.count)
            return
        if (lyricList.moving || lyricList.flicking)
            return
        lyricList.positionViewAtIndex(root.currentLine, ListView.Center)
    }

    // ── 关闭 ────────────────────────────────────────
    Icon {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 24
        anchors.rightMargin: 32
        name: "close"
        size: 20
        color: clHover.hovered ? Theme.colorBlack1 : Theme.colorBlack5
        Behavior on color { ColorAnimation { duration: 110 } }
        HoverHandler { id: clHover }
        MouseArea {
            anchors.fill: parent
            anchors.margins: -8
            cursorShape: Qt.PointingHandCursor
            onClicked: root.closeRequested()
        }
    }
}
