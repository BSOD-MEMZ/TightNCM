// HomePage —— 首页 / 推荐
// 内容来自 /api/personalized/playlist（推荐歌单）与 /api/personalized/newsong（每日推荐）。
import QtQuick 2.15
import QtQuick.Window 2.15
import TightNCM 1.0
import "../widgets"

ScrollColumn {
    id: root

    property var recommendPlaylists: []
    property var recommendSongs: []
    property var dailySongs: []      // /api/v1/discovery/recommend/songs（跟随口味）
    property var playingSongId: -1
    property string greeting: "推荐"

    signal playlistClicked(var playlist)
    signal songClicked(int index)
    signal morePlaylistsClicked()
    signal playDailyClicked()

    spacing: 0

    Text {
        text: root.greeting
        font.pixelSize: 28
        font.weight: Font.DemiBold
        color: Theme.colorBlack1
    }
    Text {
        topPadding: 6
        text: "根据你的口味生成"
        font.pixelSize: Metrics.fontMedium
        color: Theme.colorBlack5
    }

    Item { width: 1; height: 16 }

    SectionTitle {
        width: parent.width
        text: "推荐歌单"
        actionText: "更多"
        onActionClicked: root.morePlaylistsClicked()
    }

    CardGrid {
        items: root.recommendPlaylists
        cardSize: 168
        countField: "playCount"
        onCardClicked: function (item) { root.playlistClicked(item) }
    }

    Item { width: 1; height: 28 }

    SectionTitle {
        width: parent.width
        text: "每日推荐"
        actionText: root.dailySongs.length > 0 ? "播放全部" : ""
        onActionClicked: root.playDailyClicked()
    }

    // 两列歌曲网格（首页量小，不需要表格）
    Grid {
        id: songGrid
        width: parent.width
        columns: 2
        rowSpacing: 2
        columnSpacing: 24

        Repeater {
            model: root.dailySongs
            delegate: Item {
                required property int index
                required property var modelData
                width: (songGrid.width - songGrid.columnSpacing) / 2
                height: 56

                readonly property bool hovered: sHover.hovered
                readonly property bool isPlaying: root.playingSongId !== -1
                                                  && modelData.id === root.playingSongId

                Rectangle {
                    anchors.fill: parent
                    radius: 8
                    color: parent.hovered ? Theme.colorBlack12 : "transparent"
                    Behavior on color { ColorAnimation { duration: 90 } }
                }

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 6
                    spacing: 10

                    Text {
                        width: 22
                        text: (index + 1) < 10 ? "0" + (index + 1) : String(index + 1)
                        font.pixelSize: Metrics.fontSmall
                        color: parent.parent.isPlaying ? Theme.brand : Theme.colorBlack7
                        horizontalAlignment: Text.AlignRight
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    RoundRect {
                        width: 44; height: 44; radius: 8
                        color: Theme.colorBlack12
                        clip: true
                        anchors.verticalCenter: parent.verticalCenter
                        Image {
                            anchors.fill: parent
                            source: modelData.cover || ""
                            sourceSize.width: Math.max(1, Math.round(width * Screen.devicePixelRatio))
                            sourceSize.height: Math.max(1, Math.round(height * Screen.devicePixelRatio))
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            visible: status === Image.Ready
                        }
                        Icon {
                            anchors.centerIn: parent
                            visible: !modelData.cover
                            name: "music"; size: 16; color: Theme.colorBlack8
                        }
                    }

                    // 用 VStack 而不是 Column：本工程里 positioner 会漏排后加进来的子项
                    VStack {
                        width: parent.width - 22 - 44 - 20
                        spacing: 2
                        anchors.verticalCenter: parent.verticalCenter
                        Text {
                            width: parent.width
                            text: modelData.name
                            font.pixelSize: Metrics.fontNormal
                            color: parent.parent.parent.isPlaying ? Theme.brand : Theme.colorBlack1
                            elide: Text.ElideRight
                        }
                        Text {
                            width: parent.width
                            text: modelData.artist
                            font.pixelSize: Metrics.fontSmall
                            color: Theme.colorBlack5
                            elide: Text.ElideRight
                        }
                    }
                }

                HoverHandler { id: sHover }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.songClicked(index)
                }
            }
        }
    }

    Item {
        width: 1
        height: 80
        visible: root.dailySongs.length === 0
        Text {
            anchors.top: parent.top
            anchors.topMargin: 16
            text: "正在获取每日推荐…"
            font.pixelSize: Metrics.fontMedium
            color: Theme.colorBlack7
        }
    }
}
