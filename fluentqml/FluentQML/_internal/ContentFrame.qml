// Copyright 2026 aki-riko
// SPDX-License-Identifier: MIT
// This file is part of FluentQML, licensed under MIT.

import QtQuick
import ".."

// ContentFrame - Reusable content area with rounded corner and border 可复用的圆角边框内容区域
// Used by Window and compact-nav window 用于 Window 和 compact-nav window
Item {
    id: root
    
    // ==================== Required Props 必需属性 ====================
    required property color backgroundColor
    required property int cornerRadius
    
    // ==================== Content Slot 内容插槽 ====================
    default property alias content: contentItem.data
    
    // ==================== Background 背景 ====================
    Rectangle {
        id: background
        anchors.fill: parent
        color: root.backgroundColor
        radius: root.cornerRadius
        
        // Bottom-left corner fill 左下角填充
        Rectangle {
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            width: root.cornerRadius
            height: root.cornerRadius
            color: parent.color
        }
        
        // Top-right corner fill 右上角填充
        Rectangle {
            anchors.right: parent.right
            anchors.top: parent.top
            width: root.cornerRadius
            height: root.cornerRadius
            color: parent.color
        }
    }
    
    // ==================== Border Canvas 边框画布 ====================
    Canvas {
        id: borderCanvas
        anchors.fill: parent
        
        onPaint: {
            var ctx = getContext("2d")
            var w = width, h = height, r = root.cornerRadius
            ctx.clearRect(0, 0, w, h)
            ctx.strokeStyle = Enums.stateColor.contentBorder.toString()
            ctx.lineWidth = Enums.border.thin
            // Top border 顶部边框
            ctx.beginPath()
            ctx.moveTo(r, 0.5)
            ctx.lineTo(w, 0.5)
            ctx.stroke()
            // Left border 左侧边框
            ctx.beginPath()
            ctx.moveTo(0.5, r)
            ctx.lineTo(0.5, h)
            ctx.stroke()
            // Top-left arc 左上角圆弧
            ctx.beginPath()
            ctx.arc(r, r, r - 0.5, Math.PI, Math.PI * 1.5)
            ctx.stroke()
        }
        
        Component.onCompleted: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
    }
    
    // ==================== Theme Connection 主题连接 ====================
    Connections {
        target: ThemeManager
        function onThemeChanged() { borderCanvas.requestPaint() }
    }
    
    // ==================== Content Container 内容容器 ====================
    Item {
        id: contentItem
        anchors.fill: parent
        anchors.topMargin: Enums.border.thin
        anchors.leftMargin: Enums.border.thin
        clip: true

        // 点击空白区域时清除输入焦点（z:-1 确保在页面内容之下）
        MouseArea {
            anchors.fill: parent
            z: Enums.zIndex.background
            onClicked: contentItem.forceActiveFocus()
        }
    }
}
