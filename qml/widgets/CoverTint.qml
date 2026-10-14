// CoverTint —— 从封面里取「主色」，供沉浸式背景用
//
// 官方歌单 / 专辑页会给整个窗口铺一层由封面主色推出的淡色：
//     background-image: linear-gradient(<主色 alpha .1> 0%, transparent 480px)
// 取色本身在 C++ 侧做（见 src/core/ColorProbe.cpp），这里只负责转发事件。
import QtQuick 2.15

Item {
    id: root

    property url source: ""
    signal colorReady(color color)

    width: 1
    height: 1

    onSourceChanged: {
        if (source === "")
            root.colorReady("transparent")
        else
            ColorProbe.probe(source)
    }

    Connections {
        target: ColorProbe
        function onSampled(c) { root.colorReady(c) }
    }
}
