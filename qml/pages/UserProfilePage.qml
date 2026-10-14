// UserProfilePage —— 个人主页（点顶栏用户区打开）
//
// 数据都来自「按 uid 取」那组接口，所以同一个页面既能看自己也能看别人：
//   /api/v1/user/detail/<uid>   资料（昵称/头像/签名/等级/听歌数）
//   /api/user/playlist?uid=     创建 & 收藏的歌单
//   /api/v1/play/record?uid=    听歌排行
//
// 官方主页是「左头像 + 右信息」的横排头，下面是歌单网格；听歌排行是单独一块。
// 这里按同样的顺序排，不做 tab 切换（tab 在这个工程里要额外处理懒加载重排）。
import QtQuick 2.15
import QtQuick.Window 2.15
import TightNCM 1.0
import "../widgets"

ScrollColumn {
    id: root

    property var user: null             // {nickname, avatar, signature, level, listenSongs, ...}
    property var createdPlaylists: []
    property var collectedPlaylists: []
    property var record: []             // 听歌排行 [{name, artist, playCount, ...}]
    property int level: 0
    property bool isSelf: true

    signal playlistClicked(var playlist)
    signal songClicked(var songs, int index)

    spacing: 0

    readonly property string nick: root.user ? (root.user.nickname || "") : ""
    readonly property string avatar: root.user ? (root.user.avatar || "") : ""
    readonly property string sign: root.user ? (root.user.signature || "") : ""

    // ── 头部：头像 + 信息 ────────────────────────────
    Row {
        width: parent.width
        spacing: 20
        height: 100

        RoundRect {
            width: 80; height: 80
            radius: 40
            color: Theme.colorBlack12
            clip: true
            anchors.verticalCenter: parent.verticalCenter
            Image {
                anchors.fill: parent
                source: root.avatar
                sourceSize.width: Math.max(1, Math.round(width * Screen.devicePixelRatio))
                sourceSize.height: Math.max(1, Math.round(height * Screen.devicePixelRatio))
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: status === Image.Ready
            }
            Icon {
                anchors.centerIn: parent
                visible: root.avatar === ""
                name: "music"; size: 36; color: Theme.colorBlack8
            }
        }

        VStack {
            width: Math.max(200, parent.width - 100)
            spacing: 6
            anchors.verticalCenter: parent.verticalCenter

            Row {
                spacing: 8
                Text {
                    text: root.nick || "未知用户"
                    font.pixelSize: 20
                    font.weight: Font.DemiBold
                    color: Theme.colorBlack1
                }
                // 等级徽章（官方是「Lv.N」小药丸）
                Item {
                    width: 40; height: 18
                    visible: root.level > 0
                    anchors.verticalCenter: parent.verticalCenter
                    RoundRect {
                        anchors.fill: parent
                        radius: 9
                        color: Theme.colorBlack12
                    }
                    Text {
                        anchors.centerIn: parent
                        text: "Lv." + root.level
                        font.pixelSize: 11
                        font.weight: Font.Bold
                        color: Theme.colorBlack3
                    }
                }
            }

            Text {
                width: parent.width
                visible: text !== ""
                text: root.sign
                font.pixelSize: Metrics.fontSmall
                color: Theme.colorBlack5
                elide: Text.ElideRight
            }

            // 用**一个** Text 拼出来，别用 Row 装两个 Text ——
            // 本工程首帧前 positioner 会漏排子项，两个 Text 会一起停在 x=0 叠字。
            Text {
                text: {
                    var s = "累计听歌 " + (root.user ? (root.user.listenSongs || 0) : 0) + " 首"
                    if (root.user && root.user.follows !== undefined)
                        s += "　关注 " + root.user.follows + "　粉丝 " + root.user.followeds
                    return s
                }
                font.pixelSize: Metrics.fontSmall
                color: Theme.colorBlack6
            }
        }
    }

    Item { width: 1; height: 24 }

    // ── 创建的歌单 ──────────────────────────────────
    SectionTitle {
        width: parent.width
        text: root.isSelf ? "我创建的歌单" : "TA 创建的歌单"
    }
    CardGrid {
        items: root.createdPlaylists
        cardSize: 168
        countField: "playCount"
        onCardClicked: function (item) { root.playlistClicked(item) }
    }
    Text {
        width: parent.width
        visible: root.createdPlaylists.length === 0
        topPadding: 12
        text: "还没有歌单"
        font.pixelSize: Metrics.fontNormal
        color: Theme.colorBlack7
    }

    Item { width: 1; height: 28 }

    // ── 收藏的歌单 ──────────────────────────────────
    SectionTitle {
        width: parent.width
        visible: root.collectedPlaylists.length > 0
        text: root.isSelf ? "我收藏的歌单" : "TA 收藏的歌单"
    }
    CardGrid {
        visible: root.collectedPlaylists.length > 0
        items: root.collectedPlaylists
        cardSize: 168
        countField: "playCount"
        onCardClicked: function (item) { root.playlistClicked(item) }
    }

    Item { width: 1; height: 28 }

    // ── 听歌排行 ────────────────────────────────────
    SectionTitle {
        width: parent.width
        text: "听歌排行"
    }

    Repeater {
        model: root.record
        delegate: Item {
            required property int index
            required property var modelData
            width: parent.width
            height: 56

            readonly property bool hovered: rHover.hovered

            Rectangle {
                anchors.fill: parent
                radius: 8
                color: parent.hovered ? Theme.colorBlack12 : "transparent"
            }

            Row {
                anchors.fill: parent
                anchors.leftMargin: 6
                spacing: 10

                Text {
                    width: 22
                    text: (index + 1) < 10 ? "0" + (index + 1) : String(index + 1)
                    font.pixelSize: Metrics.fontSmall
                    color: Theme.colorBlack7
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
                }
                VStack {
                    width: Math.max(120, parent.width - 22 - 44 - 20 - 80)
                    spacing: 2
                    anchors.verticalCenter: parent.verticalCenter
                    Text {
                        width: parent.width
                        text: modelData.name
                        font.pixelSize: Metrics.fontNormal
                        color: Theme.colorBlack1
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
                Text {
                    width: 70
                    text: (modelData.playCount || 0) + " 次"
                    font.pixelSize: Metrics.fontSmall
                    color: Theme.colorBlack7
                    horizontalAlignment: Text.AlignRight
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            HoverHandler { id: rHover }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.songClicked(root.record, index)
            }
        }
    }

    Text {
        width: parent.width
        visible: root.record.length === 0
        topPadding: 12
        text: "暂无听歌记录"
        font.pixelSize: Metrics.fontNormal
        color: Theme.colorBlack7
    }

    Item { width: 1; height: 40 }
}
