// ScrollColumn —— 通用「可滚动 + 左右留白 + 纵向堆叠」页面容器
//
// ⚠️ 为什么不用 Column（positioner）：
// 本工程的内容区是「全部常驻 + visible 切换」。实测在这种结构下，
// `Column` 只会给**创建时就已经存在的那几个子项**排位 —— 之后通过别名/Repeater
// 加进来或高度变化的子项，y 一直停在 0，Column 自己的 height 也是陈旧值。
// 结果就是：区块互相重叠、页面总高算错、后面内容被裁掉。
// （已用场景树逐项核对：SectionTitle / CardGrid / Repeater 委托的 y 全是 0。）
//
// 所以这里改成手动纵向堆叠，并且让重排是「响应式」的：
//   _contentHeight 这个只读属性绑定到 relayout()，relayout() 内部读了
//   children.length 和每个子项的 height —— QML 的依赖捕获是**动态**的（函数内部
//   读到的属性一样会被登记为依赖），因此任何子项高度一变，绑定就会重算并重新排位。
//   这样既不需要 Timer 轮询，也不依赖 positioner 的 polish 时序。
import QtQuick 2.15
import QtQuick.Controls 2.15
import TightNCM 1.0

Flickable {
    id: root

    property real padding: Metrics.pBodyPadding
    property real topPad: 12
    property real bottomPad: 48
    property real spacing: 0

    default property alias content: host.data

    clip: true
    contentWidth: width
    contentHeight: host.y + host.height + bottomPad
    boundsBehavior: Flickable.StopAtBounds
    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

    Item {
        id: host
        x: root.padding
        y: root.topPad
        width: Math.max(0, root.width - root.padding * 2)

        // 副作用即排位：读到 children/height 会被登记为依赖，高度一变就自动重排
        readonly property real _stacked: relayout()
        height: _stacked

        function relayout() {
            var y = 0
            var n = children.length
            for (var i = 0; i < n; ++i) {
                var c = children[i]
                if (!c.visible)
                    continue
                c.y = y
                y += c.height + root.spacing
            }
            return Math.max(0, y - root.spacing)
        }
    }
}
