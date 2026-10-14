// VStack —— 纵向堆叠容器（替代 Column positioner）
//
// 与 ScrollColumn 内部用的是同一套手动排位逻辑，抽出来给「会动态增删子项 /
// 子项高度会变」的地方用（例如排行榜里按区块生成的委托）。
//
// 为什么不直接用 Column：见 ScrollColumn.qml 顶部的说明 —— 在本工程这种
// 「常驻页面 + visible 切换 + 数据后到」的结构里，positioner 的排位会停留在
// 首次布局的结果上，导致后续子项 y 全是 0、互相重叠。
//
// 响应式原理：_stacked 绑定到 relayout()，函数内部读到的 children.length 与每个
// 子项的 height 都会被 QML 动态登记为依赖，因此任一子项高度变化都会自动重排。
import QtQuick 2.15

Item {
    id: root

    property real spacing: 0
    default property alias content: host.data

    // ★ 根节点必须自己撑出高度。
    // 之前只把高度写进内部 host，VStack 自己的 height 一直是 0 ——
    // 于是外层 ScrollColumn 排位时 `y += c.height` 每次加 0，
    // 所有 VStack 委托全被放在同一个 y 上（排行榜 6 个区块完全重叠、标题叠字）。
    // 这个 bug 只有在「用 VStack 当 Repeater 委托、且外层有多个兄弟」时才暴露，
    // 所以布局检查脚本没报（它只看块级子项的 xy 是否相同，高度为 0 的子项被跳过）。
    height: host.height
    implicitHeight: host.height

    // 上一次排位得到的总高（供外部读取）
    readonly property real contentHeight: host.height

    Item {
        id: host
        width: root.width
        height: _stacked

        readonly property real _stacked: relayout()

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
