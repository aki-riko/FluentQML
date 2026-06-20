// Copyright 2026 aki-riko
// SPDX-License-Identifier: MIT
// This file is part of FluentQML, licensed under MIT.

import QtQuick
import QtQuick.Effects
import "../../.."
import "../../../effects"
import "../../data/Label"
import ".."

// Card - Unified card component 统一卡片组件
// Types: simple, normal, elevated, header 类型：简单卡片、普通卡片、悬浮卡片、带标题卡片

Widget {
 id: control
 
 // ==================== Public Props 公开属性 ====================
 property int cardType: Enums.card.type_default // Card type 卡片类型
 property int borderRadius: Enums.radius.card // Border radius 圆角
 property bool clickEnabled: false // Enable click 启用点击
 property bool interactionEnabled: true // Enable mouse interaction 启用鼠标交互
 property string title: "" // Header title (for header type) 标题
 property alias border: card.border // Border access 边框访问
 property alias color: card.color // Background color 背景色
 default property alias content: contentLoader.data
 
 // ==================== Readonly State 只读状态 ====================
 readonly property bool hovered: mouseArea.containsMouse
 readonly property bool pressed: mouseArea.pressed
 readonly property bool isNormal: cardType === Enums.card.type_hover
 readonly property bool isElevated: cardType === Enums.card.type_elevated
 readonly property bool isHeader: cardType === Enums.card.type_header
 
 // ==================== Signals 信号 ====================
 signal clicked()
 
 // ==================== Size 尺寸 ====================
 // Content size (inherited from Widget) 内容尺寸（继承自Widget）
 contentWidth: Enums.controlSize.cardContentWidth
 contentHeight: isHeader ? card.height : Enums.controlSize.cardHeight
 
 // ==================== Elevation Animation 上浮动画 (only for elevated) ====================
 transform: Translate { 
 y: isElevated && hovered && !pressed ? -Enums.spacing.cardElevate : 0
 Behavior on y { NumberAnimation { duration: Enums.duration.medium; easing.type: Easing.OutCubic } }
 }
 
 // ==================== Shadow Layer 阴影层 ====================
 RectangularShadow {
 anchors.fill: card
 radius: card.radius
 color: _shadowColor
 blur: _shadowBlur
 offset: Qt.vector2d(0, _shadowOffset)
 
 // Shadow properties based on type and state 根据类型和状态计算阴影
 property color _shadowColor: isElevated && hovered 
 ? Enums.shadow.level4.color 
 : Enums.shadow.level2.color
 property real _shadowBlur: isElevated && hovered 
 ? Enums.shadow.level4.blur 
 : Enums.shadow.level2.blur
 property real _shadowOffset: isElevated && hovered 
 ? Enums.shadow.level4.offset 
 : Enums.shadow.level2.offset
 
 Behavior on _shadowBlur { NumberAnimation { duration: Enums.duration.medium; easing.type: Easing.OutCubic } }
 Behavior on _shadowColor { ColorAnimation { duration: Enums.duration.medium; easing.type: Easing.OutCubic } }
 }
 
 // ==================== Card 卡片 ====================
 Rectangle {
 id: card
 anchors.left: parent.left
 anchors.right: parent.right
 anchors.top: parent.top
 // Use preferredHeight if set, otherwise auto-calculate for HeaderCard or fill parent 如果设置了preferredHeight则使用，否则HeaderCard自动计算、普通卡片填充父容器

 height: preferredHeight > 0 ? preferredHeight : (isHeader ? (headerView.height + separator.height + contentLoader.childrenRect.height + Enums.spacing.xxxl * 2) : parent.height)
 radius: control.borderRadius
 
 // Background Color 背景色
 color: _bgColor
 
 property color _bgColor: {
 // Default/Header card: no hover effect 默认卡片/标题卡片无悬停效果
 // HeaderCard inherits DefaultCard behavior 标题卡继承默认卡行为
 if (cardType === Enums.card.type_default || cardType === Enums.card.type_header) {
 return Enums.stateColor.controlBg
 }
 // Hover/Elevated: hover effect 悬停/悬浮卡片有悬停效果
 if (pressed) return Enums.stateColor.controlBgPressed
 if (hovered) return Enums.stateColor.controlBgHover
 return Enums.stateColor.controlBg
 }
 
 Behavior on color { ColorAnimation { duration: Enums.duration.fast } }
 
 // Border 边框
 border.width: Enums.border.thin
 border.color: Enums.stateColor.borderLight
 
 // ==================== Header (for header type) 标题区域 ====================
 Item {
 id: headerView
 width: parent.width
 height: isHeader ? Enums.controlSize.navBarHeight : 0
 visible: isHeader
 
 Label {
 type: Enums.label.type_body_strong
 anchors.left: parent.left
 anchors.leftMargin: Enums.spacing.xxxl
 anchors.verticalCenter: parent.verticalCenter
 text: control.title
 visible: isHeader
 }
 }
 
 // Separator 分隔线
 Separator {
 id: separator
 anchors.top: headerView.bottom
 width: parent.width
 visible: isHeader
 }
 
 // ==================== Content Area 内容区域 ====================
 Item {
 id: contentLoader
 objectName: "contentLoader"
 anchors.top: isHeader ? separator.bottom : parent.top
 anchors.bottom: parent.bottom
 anchors.left: parent.left
 anchors.right: parent.right
 anchors.margins: isHeader ? Enums.spacing.xxxl : Enums.border.thin
 }
 
 // ==================== Interaction 交互 ====================
 MouseArea {
 id: mouseArea
 anchors.fill: parent
 z: Enums.zIndex.background // Below content to not block child interactions 置于内容下方避免阻挡子组件交互
 hoverEnabled: control.interactionEnabled
 enabled: control.interactionEnabled
 visible: control.interactionEnabled // 完全隐藏时不阻挡事件
 cursorShape: control.clickEnabled ? Qt.PointingHandCursor : Qt.ArrowCursor
 onClicked: if (control.clickEnabled) control.clicked()
 }
 }
}
