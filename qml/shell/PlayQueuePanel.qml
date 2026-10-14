// PlayQueuePanel —— 右侧滑出的播放队列
import QtQuick 2.15
import QtQuick.Controls 2.15
import TightNCM 1.0
import "../widgets"

Item {
    id: root

    property bool open: false
    property var songs: []
    property int currentIndex: -1
    property bool playing: false

    signal songClicked(int index)
    signal closeRequested()
    signal clearRequested()

    // 面板从右侧滑入；关闭时停在窗口右边外面，且不拦截任何点击
    readonly property int panelWidth: 400

    // ── 遮罩 ────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.18)
        opacity: root.open ? 1 : 0
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: 180 } }
        MouseArea {
            anchors.fill: parent
            onClicked: root.closeRequested()
        }
    }

    // ── 面板 ────────────────────────────────────────
    Item {
        id: panel
        width: root.panelWidth
        height: parent.height
        x: root.open ? parent.width - width : parent.width
        Behavior on x { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

        Rectangle {
            anchors.fill: parent
            color: Theme.pageBackground
            // 左侧一条细边界，和内容区分开
            Rectangle {
                anchors.left: parent.left
                width: 1
                height: parent.height
                color: Theme.divider
            }
        }

        Column {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 0

            // 标题行
            Row {
                width: parent.width
                height: 32

                Text {
                    text: "播放列表"
                    font.pixelSize: Metrics.fontLarge
                    font.weight: Font.DemiBold
                    color: Theme.colorBlack1
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    topPadding: 3
                    leftPadding: 6
                    text: root.songs.length + " 首"
                    font.pixelSize: Metrics.fontSmall
                    color: Theme.colorBlack7
                    anchors.verticalCenter: parent.verticalCenter
                }

                Item { width: parent.width - 220; height: 1 }

                Icon {
                    name: "delete"
                    size: 18
                    color: clearHover.hovered ? Theme.brand : Theme.colorBlack5
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.songs.length > 0
                    Behavior on color { ColorAnimation { duration: 110 } }
                    HoverHandler { id: clearHover }
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.clearRequested()
                    }
                }
                Item { width: 12; height: 1 }
                Icon {
                    name: "close"
                    size: 16
                    color: closeHover.hovered ? Theme.colorBlack1 : Theme.colorBlack5
                    anchors.verticalCenter: parent.verticalCenter
                    Behavior on color { ColorAnimation { duration: 110 } }
                    HoverHandler { id: closeHover }
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.closeRequested()
                    }
                }
            }

            Item { width: 1; height: 12 }

            ListView {
                id: list
                width: parent.width
                height: parent.height - 44
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                reuseItems: true
                model: root.songs
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                delegate: Item {
                    required property int index
                    required property var modelData
                    width: list.width
                    height: 48
                    readonly property bool current: index === root.currentIndex
                    readonly property bool hovered: qh.hovered

                    Rectangle {
                        anchors.fill: parent
                        radius: 8
                        color: parent.hovered ? Theme.colorBlack12 : "transparent"
                        Behavior on color { ColorAnimation { duration: 90 } }
                    }

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 10

                        // 当前曲目显示出声波图标
                        Item {
                            width: 16
                            height: parent.height
                            anchors.verticalCenter: parent.verticalCenter
                            Text {
                                anchors.centerIn: parent
                                visible: !parent.parent.parent.current
                                text: index + 1
                                font.pixelSize: Metrics.fontSmall
                                color: Theme.colorBlack7
                            }
                            Icon {
                                anchors.centerIn: parent
                                visible: parent.parent.parent.current
                                name: "playing"
                                size: 14
                                color: Theme.brand
                            }
                        }

                        Column {
                            width: parent.width - 26 - 48
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2
                            Text {
                                width: parent.width
                                text: modelData.name || ""
                                font.pixelSize: Metrics.fontNormal
                                color: parent.parent.parent.current ? Theme.brand : Theme.colorBlack1
                                elide: Text.ElideRight
                            }
                            Text {
                                width: parent.width
                                text: (modelData.artist || "")
                                      + (modelData.album ? " · " + modelData.album : "")
                                font.pixelSize: Metrics.fontSmall
                                color: Theme.colorBlack5
                                elide: Text.ElideRight
                            }
                        }

                        Text {
                            text: fmt(modelData.duration)
                            font.pixelSize: Metrics.fontSmall
                            color: Theme.colorBlack7
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    HoverHandler { id: qh }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.songClicked(index)
                    }
                }

                footer: Item {
                    width: list.width
                    height: 60
                    Text {
                        anchors.centerIn: parent
                        visible: root.songs.length === 0
                        text: "播放列表是空的"
                        font.pixelSize: Metrics.fontSmall
                        color: Theme.colorBlack7
                    }
                }
            }
        }
    }

    function fmt(sec) {
        if (!sec || sec < 0) return "--:--"
        var m = Math.floor(sec / 60)
        var s = sec % 60
        return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s
    }
}
