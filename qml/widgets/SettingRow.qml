// SettingRow —— 设置页的一行（对应官方 styled.section 的 BaseItem）
//
// 官方 CSS 字面值：
//   section { display:flex; flex-direction:row; padding:30px 0;
//             font-size:16px; line-height:18px; color:colorBlack2;
//             border-bottom:1px solid colorBlack11 }
//     h3 { width:132px; flex:none; margin-bottom:20px; font-weight:600; font-size:16px }
//
// 用法：label 写左边那 132px 的标题，子项写右边的内容。
//     SettingRow {
//         label: "程序启动时自动播放"
//         SettingSwitch { checked: ...; onToggled: ... }
//     }
import QtQuick 2.15
import TightNCM 1.0
import "../widgets"

Item {
    id: root

    property string label: ""
    property bool   showDivider: true

    // ⚠️ 必须 alias 到 inner.content 而不是 inner.data：
    // data 是 VStack 根节点自己的数据列表，写进去的子项跟内部的 host 平级，
    // VStack 的排位函数（遍历 host.children）根本看不到它们，于是量出来高度是 0、
    // 整段设置项会叠在一起。content 才是链到 host.data 的别名。
    default property alias content: inner.content

    width: parent ? parent.width : 0
    implicitHeight: Math.max(Metrics.sRowLine, inner.height) + Metrics.sRowPadY * 2
    height: implicitHeight

    Text {
        id: labelText
        x: 0
        y: Metrics.sRowPadY
        width: Metrics.sLabelWidth - 12
        text: root.label
        font.pixelSize: Metrics.sRowLabelSize
        font.weight: Font.DemiBold
        color: Theme.colorBlack2
        wrapMode: Text.Wrap
    }

    Item {
        id: host
        x: Metrics.sLabelWidth
        y: Metrics.sRowPadY
        width: Math.max(0, root.width - Metrics.sLabelWidth)
        height: inner.height

        // ⚠️ 内容必须放进一个**有自己的高度**的容器里，不能直接用 childrenRect.height：
        // 内容里常见的 `anchors.verticalCenter: parent.verticalCenter` 会反过来依赖
        // 这个高度，形成 Binding loop（实测报 "Binding loop detected for property height"）。
        // 放进 VStack 之后，VStack 会自己给子项排 y，子项的 verticalCenter 不再是依赖。
        VStack {
            id: inner
            width: parent.width
            spacing: 8
        }
    }

    Rectangle {
        visible: root.showDivider
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 1
        color: Theme.colorBlack11
    }
}
