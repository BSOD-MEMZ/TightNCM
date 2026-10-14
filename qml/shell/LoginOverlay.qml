// LoginOverlay —— 扫码/手机号登录之外的登录方式
//
// 本项目没实现手机号/二维码登录（那要接官方登录态加密，工作量大且容易失效），
// 走的是「粘贴浏览器 cookie」这条路 —— 和官方 web 版用的是同一套鉴权。
// 步骤在界面上写清楚了。
import QtQuick 2.15
import TightNCM 1.0
import "../widgets"

Item {
    id: root

    property bool busy: false
    property string message: ""
    property bool failed: false

    signal submitted(string musicU)
    signal cancelled()

    // 半透明遮罩
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.45)
        MouseArea { anchors.fill: parent }   // 挡住底下
    }

    ShadowBox {
        id: card
        anchors.centerIn: parent
        width: 520
        height: 380
        radius: 16
        color: Theme.panel
        css: "0 8px 60px rgba(36,48,72,0.18)"

        Column {
            anchors.fill: parent
            anchors.margins: 32
            spacing: 0

            Text {
                text: "登录"
                font.pixelSize: 22
                font.weight: Font.DemiBold
                color: Theme.colorBlack1
            }

            Text {
                topPadding: 10
                width: parent.width
                text: "本客户端用「网易云网页版登录态」鉴权，不需要手机号。\n" +
                      "在任意已登录网易云网页版的浏览器里：\n" +
                      "    F12 → Application → Cookies → https://music.163.com → 复制 MUSIC_U 的值"
                font.pixelSize: Metrics.fontSmall
                color: Theme.colorBlack5
                lineHeight: 1.7
                wrapMode: Text.Wrap
            }

            Item { width: 1; height: 20 }

            RoundRect {
                width: parent.width
                height: 44
                radius: 8
                color: Theme.colorBlack12
                borderColor: input.activeFocus ? Theme.brand : Theme.colorBlack10
                borderWidth: 1
                Behavior on borderColor { ColorAnimation { duration: 120 } }

                TextInput {
                    id: input
                    anchors.fill: parent
                    anchors.margins: 12
                    verticalAlignment: TextInput.AlignVCenter
                    font.pixelSize: Metrics.fontSmall
                    color: Theme.colorBlack1
                    selectByMouse: true
                    clip: true

                    Text {
                        text: "粘贴 MUSIC_U 的值"
                        visible: !input.text && !input.activeFocus
                        font: input.font
                        color: Theme.colorBlack8
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            Item { width: 1; height: 10 }

            Text {
                visible: root.message !== ""
                width: parent.width
                text: root.message
                font.pixelSize: Metrics.fontSmall
                color: root.failed ? Theme.brand : Theme.colorBlack5
                wrapMode: Text.Wrap
            }

            Item { width: 1; height: 20 }

            Row {
                spacing: 12

                Item {
                    width: 108; height: 40
                    RoundRect {
                        anchors.fill: parent
                        radius: 8
                        color: Theme.colorBlack11
                    }
                    Text {
                        anchors.centerIn: parent
                        text: "取消"
                        font.pixelSize: Metrics.fontMedium
                        color: Theme.colorBlack3
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.cancelled()
                    }
                }

                Item {
                    width: 108; height: 40
                    opacity: root.busy || input.text.trim() === "" ? 0.5 : 1
                    AngleGradientRect {
                        anchors.fill: parent
                        radius: 8
                        cssAngle: 242.83
                        Component.onCompleted: set3(0.1696, Theme.colorSecondary1_2,
                                                    0.3433, Theme.colorSecondary1_2,
                                                    0.8304, Theme.colorSecondary1_1)
                    }
                    Text {
                        anchors.centerIn: parent
                        text: root.busy ? "验证中…" : "登录"
                        font.pixelSize: Metrics.fontMedium
                        color: Theme.colorWhite1
                    }
                    MouseArea {
                        anchors.fill: parent
                        enabled: !root.busy && input.text.trim() !== ""
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.submitted(input.text.trim())
                    }
                }
            }
        }
    }

    Component.onCompleted: input.forceActiveFocus()
}
