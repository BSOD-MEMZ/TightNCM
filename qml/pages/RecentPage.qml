// RecentPage —— 最近播放（本地播放历史）
// 数据来自 AppStore（QSettings 持久化），不依赖登录。
import QtQuick 2.15
import TightNCM 1.0
import "../widgets"

Item {
    id: root

    property var songs: []
    property var playingSongId: -1

    signal playRequested(int index)
    signal likeToggled(int index)
    signal clearRequested()

    SongList {
        anchors.fill: parent
        songs: root.songs
        playingSongId: root.playingSongId
        emptyText: "还没有播放记录"
        onPlayRequested: function (i) { root.playRequested(i) }
        onLikeToggled: function (i) { root.likeToggled(i) }

        headerSource: Component {
            Column {
                width: parent ? parent.width : 0
                topPadding: 12

                Row {
                    width: parent.width

                    Column {
                        width: parent.width - 120
                        Text {
                            text: "最近播放"
                            font.pixelSize: 28
                            font.weight: Font.DemiBold
                            color: Theme.colorBlack1
                        }
                        Text {
                            topPadding: 6
                            text: root.songs.length > 0
                                  ? ("本地记录 " + root.songs.length + " 首")
                                  : "本机记录，不上传"
                            font.pixelSize: Metrics.fontMedium
                            color: Theme.colorBlack5
                        }
                    }

                    CmdButton {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: root.songs.length > 0
                        text: "清空记录"
                        iconName: "delete"
                        variant: "outline-sec"
                        textColor: Theme.colorBlack3
                        borderColor: Theme.colorBlack10
                        borderWidth: 1
                        size: "l"
                        customHeight: 32
                        customPadding: 14
                        customRadius: 16
                        customFontSize: Metrics.fontSmall
                        onClicked: root.clearRequested()
                    }
                }

                Item { width: 1; height: 16 }
            }
        }
    }
}
