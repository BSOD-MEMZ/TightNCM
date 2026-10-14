// PodcastPage —— 我的播客（订阅的电台）
// 数据：/api/djradio/get/subed（需要登录）
import QtQuick 2.15
import TightNCM 1.0
import "../widgets"

ScrollColumn {
    id: root

    property var radios: []
    property bool loading: false
    property bool loggedIn: false

    signal radioClicked(var item)
    signal loginRequested()

    spacing: 0

    Text {
        text: "我的播客"
        font.pixelSize: 28
        font.weight: Font.DemiBold
        color: Theme.colorBlack1
    }
    Text {
        topPadding: 6
        text: "订阅的电台与节目"
        font.pixelSize: Metrics.fontMedium
        color: Theme.colorBlack5
    }

    Item { width: 1; height: 20 }

    // 未登录
    Column {
        width: parent.width
        visible: !root.loggedIn
        spacing: 12

        Text {
            text: "登录后才能看到你订阅的播客"
            font.pixelSize: Metrics.fontMedium
            color: Theme.colorBlack5
        }
        CmdButton {
            text: "去登录"
            variant: "surface-pri"
            size: "l"
            customHeight: 36
            customPadding: 20
            customRadius: 18
            customFontSize: Metrics.fontNormal
            onClicked: root.loginRequested()
        }
    }

    Item {
        width: 1
        height: 100
        visible: root.loggedIn && root.radios.length === 0
        Text {
            anchors.centerIn: parent
            text: root.loading ? "加载中…" : "还没订阅任何播客"
            font.pixelSize: Metrics.fontMedium
            color: Theme.colorBlack7
        }
    }

    CardGrid {
        items: root.radios
        cardSize: 168
        subtitleField: "author"
        fallbackIcon: "podcast"
        onCardClicked: function (item) { root.radioClicked(item) }
    }

    Item { width: 1; height: 20 }
}
