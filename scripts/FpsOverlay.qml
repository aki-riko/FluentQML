// FpsOverlay - 实时帧率 + ScrollArea 内容流畅度 OSD
//
// 三个数字, 对症下药:
//   1) win fps: QQuickWindow.frameSwapped 1 秒计数 — 渲染管线吞吐
//   2) sc upd:  当前正在变的那个 Flickable 的 contentY 每秒变化次数
//                "窗口 fps 高但 sc upd 低" = 渲染没问题, 但滚动驱动跟不上
//                (典型: SmoothScrollHelper 的 NumberAnimation 时长过长 / 抖动)
//   3) sc ms:   两次 contentY 变化间最大间隔 ms — 滚动卡顿尖峰
//
// 探测方法: 周期扫窗口 visual tree 找 contentHeight>height 的 Flickable,
// 选每秒 contentY 变化次数最多的那个作为"活跃 ScrollArea". 不动鼠标/事件.

import QtQuick

Item {
    id: overlay
    objectName: "fpsOverlay"

    // ==================== 必填 ====================
    property var watchWindow: null

    // ==================== 窗口 fps ====================
    property int _winFrameCount: 0
    property int _winFps: 0
    property real _winMaxMs: 0
    property real _winCurMs: 0
    property real _winLastTs: 0

    // ==================== ScrollArea contentY 计数 ====================
    property var _activeFlickable: null         // 当前选中的活跃 Flickable
    property real _lastContentY: NaN
    property real _lastContentYTs: 0
    property int _scUpdCount: 0                 // 1 秒内 contentY 变化次数
    property int _scUpd: 0                      // 上一秒结果
    property real _scMaxMs: 0                   // 1 秒内 contentY 两次变化最大间隔
    property real _scCurMs: 0                   // 当前秒累积

    // 各候选 Flickable 在采样期内的 contentY 变化计数, 用于挑活跃的
    property var _candidateCounts: ({})         // key = qsobj 指针字符串, val = count

    anchors.right: parent ? parent.right : undefined
    anchors.top: parent ? parent.top : undefined
    anchors.rightMargin: 12
    anchors.topMargin: 12
    width: 170
    height: 90
    z: 99999

    // ==================== 监听窗口 frameSwapped ====================
    Connections {
        target: overlay.watchWindow
        function onFrameSwapped() {
            overlay._winFrameCount += 1
            var now = Date.now()
            if (overlay._winLastTs > 0) {
                var dt = now - overlay._winLastTs
                if (dt > overlay._winCurMs) overlay._winCurMs = dt
            }
            overlay._winLastTs = now
        }
    }

    // ==================== 监听活跃 Flickable contentY ====================
    Connections {
        target: overlay._activeFlickable
        ignoreUnknownSignals: true
        function onContentYChanged() {
            overlay._scUpdCount += 1
            var now = Date.now()
            if (overlay._lastContentYTs > 0) {
                var dt = now - overlay._lastContentYTs
                if (dt > overlay._scCurMs) overlay._scCurMs = dt
            }
            overlay._lastContentYTs = now
        }
    }

    // ==================== 候选探测: 200ms 扫一次, 计数所有可滚 Flickable 的 contentY 变化 ====================
    // 实现: 给所有候选 Flickable 挂 contentYChanged listener (动态), 累计 5 个采样周期后选 count 最高的为活跃.
    // 简化版: 每 200ms 比较所有候选当前 contentY 与上次记录, 不同就 +1.
    property var _scanCandidates: []          // {item, lastY, count} 数组
    Timer {
        interval: 200
        running: overlay.watchWindow !== null
        repeat: true
        onTriggered: overlay._scanScrollables()
    }

    function _scanScrollables() {
        var win = overlay.watchWindow
        if (!win) return
        var ci = win.contentItem
        if (!ci) return

        // 重新构建候选 (页面切换会让原候选失效)
        var found = []
        _walk(ci, found, 0)

        // 与已有候选合并: 复用旧的 lastY/count, 新增加入
        var byKey = {}
        for (var i = 0; i < _scanCandidates.length; i++) {
            byKey[_keyOf(_scanCandidates[i].item)] = _scanCandidates[i]
        }
        var fresh = []
        for (var j = 0; j < found.length; j++) {
            var k = _keyOf(found[j])
            var existing = byKey[k]
            if (existing) {
                // 比较 contentY 变化
                var cy = found[j].contentY
                if (cy !== existing.lastY) existing.count += 1
                existing.lastY = cy
                existing.item = found[j]
                fresh.push(existing)
            } else {
                fresh.push({ item: found[j], lastY: found[j].contentY, count: 0 })
            }
        }
        _scanCandidates = fresh

        // 选 count 最高的作为活跃 (count > 0 说明真的在动)
        var best = null; var bestCount = 0
        for (var m = 0; m < _scanCandidates.length; m++) {
            if (_scanCandidates[m].count > bestCount) {
                bestCount = _scanCandidates[m].count
                best = _scanCandidates[m].item
            }
        }
        if (best && best !== _activeFlickable) {
            _activeFlickable = best
            _lastContentYTs = 0
        }
    }

    function _keyOf(obj) {
        // QML 没有公开 obj 内部地址, 但 String(obj) 通常含类型@addr 信息, 够用
        return String(obj)
    }

    function _walk(item, out, depth) {
        if (!item || depth > 30) return
        // Flickable 鸭子类型: 同时有 contentY + contentHeight + height
        if (item.contentY !== undefined && item.contentHeight !== undefined &&
            item.height !== undefined && item.contentHeight > item.height + 1) {
            out.push(item)
        }
        var kids = []
        try { kids = item.childItems() } catch (e) { try { kids = item.children } catch (e2) {} }
        if (kids) {
            for (var i = 0; i < kids.length; i++) _walk(kids[i], out, depth + 1)
        }
    }

    // ==================== 1 秒采样 ====================
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            overlay._winFps = overlay._winFrameCount; overlay._winFrameCount = 0
            overlay._winMaxMs = overlay._winCurMs;     overlay._winCurMs = 0
            overlay._scUpd = overlay._scUpdCount;      overlay._scUpdCount = 0
            overlay._scMaxMs = overlay._scCurMs;       overlay._scCurMs = 0
            // 候选 count 半衰, 让久不动的候选淡出
            for (var i = 0; i < overlay._scanCandidates.length; i++) {
                overlay._scanCandidates[i].count = Math.floor(overlay._scanCandidates[i].count / 2)
            }
        }
    }

    // ==================== 视觉 ====================
    Rectangle {
        anchors.fill: parent
        color: "#CC000000"
        radius: 6
        border.color: "#33FFFFFF"
        border.width: 1
    }

    Column {
        anchors.fill: parent
        anchors.margins: 6
        spacing: 1

        Text {
            width: parent.width
            text: "win " + overlay._winFps + " / max " + overlay._winMaxMs.toFixed(0) + "ms"
            color: overlay._winFps >= 58 ? "#5DFF7A" : (overlay._winFps >= 40 ? "#FFD45D" : "#FF6F6F")
            font.pixelSize: 13
            font.bold: true
            font.family: "Consolas"
        }
        Text {
            width: parent.width
            text: "scroll " + overlay._scUpd + " upd/s"
            color: overlay._scUpd === 0 ? "#888888" :
                   (overlay._scUpd >= 50 ? "#5DFF7A" :
                    (overlay._scUpd >= 25 ? "#FFD45D" : "#FF6F6F"))
            font.pixelSize: 13
            font.bold: true
            font.family: "Consolas"
        }
        Text {
            width: parent.width
            text: "scroll max " + overlay._scMaxMs.toFixed(0) + " ms"
            color: "#CCFFFFFF"
            font.pixelSize: 11
            font.family: "Consolas"
        }
        Text {
            width: parent.width
            text: overlay._activeFlickable ? "watching active" : "no active flickable"
            color: "#888888"
            font.pixelSize: 9
            font.family: "Consolas"
        }
    }
}
