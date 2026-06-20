// Copyright 2026 aki-riko
// SPDX-License-Identifier: MIT
// This file is part of FluentQML, licensed under MIT.

import QtQuick
import "../../.."
import ".."

// ListView - 通用 ListView (QListView 等价物) 低阶 View 级组件
// 继承 DataWidgetCore,轻量模式(无阴影/无margin)
//
// Usage 用法:
//   Fluent.ListView {
//       model: myAbstractListModel
//       delegate: Rectangle { ... }
//   }
//
// 与 ListWidget (高阶) 区别 vs ListWidget:
//   ListView = QListView 等价物,只渲染,适合 QAbstractListModel 等自带 model 的场景
//   ListWidget     = QListWidget 等价物,自带 model + addItem/insertItem 等便利 API
DataWidgetCore {
    id: control

    // ==================== Public Props 公开属性 ====================
    property bool framed: true
    property alias model: control.listModel
    property alias delegate: control.contentDelegate
    // spacing 由父类 DataWidgetCore 暴露(本地id alias合法),此处勿重复三级alias control.listView.spacing(非法)
    readonly property int count: listView.count
    property int currentIndex: -1

    onCurrentIndexChanged: {
        if (listView && listView.currentIndex !== currentIndex)
            listView.currentIndex = currentIndex
    }
    Binding {
        target: control
        property: "currentIndex"
        value: control.listView.currentIndex
        when: control.listView
    }

    // ==================== Lightweight mode 轻量模式 ====================
    showShadow: false
    cardMargin: 0
    borderVisible: framed
    // showFooter 不在此硬编码: 基类默认 false (轻量模式), 但保留给用户/demo 覆盖
    showHeader: false
    itemCount: listView.count

    // ==================== Size 尺寸 ====================
    implicitWidth: Enums.controlSize.listDefaultWidth
    implicitHeight: Enums.controlSize.listDefaultHeight
}
