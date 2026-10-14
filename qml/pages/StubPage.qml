// StubPage —— 尚未接入的页面占位
// 目标是把「这页存在、正在做」表达清楚，而不是留一片空白。
import QtQuick 2.15
import TightNCM 1.0
import "../widgets"

Item {
    id: root

    property string title: ""
    property string subtitle: ""
    property string iconName: "playlist"
    property var planned: []      // 待做项列表

    Column {
        x: Metrics.pBodyPadding
        y: 40
        width: parent.width - Metrics.pBodyPadding * 2
        spacing: 0

        Row {
            spacing: 12
            Icon {
                name: root.iconName
                size: 32
                color: Theme.colorBlack8
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: root.title
                font.pixelSize: 28
                font.weight: Font.DemiBold
                color: Theme.colorBlack1
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        Text {
            topPadding: 12
            width: parent.width
            text: root.subtitle
            font.pixelSize: Metrics.fontMedium
            color: Theme.colorBlack5
            wrapMode: Text.Wrap
        }

        Item { width: 1; height: 28 }

        Repeater {
            model: root.planned
            delegate: Row {
                required property string modelData
                spacing: 10
                topPadding: 8

                Rectangle {
                    width: 5; height: 5; radius: 2.5
                    color: Theme.colorBlack9
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: modelData
                    font.pixelSize: Metrics.fontNormal
                    color: Theme.colorBlack6
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }
}
