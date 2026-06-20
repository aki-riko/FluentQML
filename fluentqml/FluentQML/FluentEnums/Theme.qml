// Copyright 2026 aki-riko
// SPDX-License-Identifier: MIT
// This file is part of FluentQML, licensed under MIT.

import QtQuick

// Theme - Global theme properties 全局主题属性
// Part of Enums modular system FluentEnums模块化系统
QtObject {
    id: root
    
    // Reference to parent for isDark 引用父级获取isDark
    required property bool isDark
    required property color accentColor
    required property color accentColorLight
    required property color accentColorDark
    required property var constants
    
    // ==================== Background Colors 背景色 ====================
    readonly property color backgroundColor: root.isDark ? constants.themeColors.backgroundDark : constants.themeColors.backgroundLight
    readonly property color surfaceColor: root.isDark ? constants.themeColors.surfaceDark : constants.themeColors.surfaceLight
    readonly property color cardColor: root.isDark ? constants.themeColors.cardDark : constants.themeColors.cardLight
    readonly property color toastCardColor: root.isDark ? constants.themeColors.toastCardDark : constants.themeColors.toastCardLight
    readonly property color dialogColor: root.isDark ? constants.themeColors.dialogDark : constants.themeColors.dialogLight
    readonly property color headerColor: root.isDark ? constants.themeColors.headerDark : constants.themeColors.headerLight
    readonly property color tableHoverColor: root.isDark ? constants.themeColors.tableHoverDark : constants.themeColors.tableHoverLight
    readonly property color alternateRowColor: root.isDark ? constants.themeColors.alternateRowDark : constants.themeColors.alternateRowLight
    readonly property color scrollTrackColor: root.isDark ? constants.themeColors.scrollTrackDark : constants.themeColors.scrollTrackLight
    readonly property color scrollHandleColor: root.isDark ? constants.themeColors.scrollHandleDark : constants.themeColors.scrollHandleLight
    readonly property color scrollHandleHoverColor: root.isDark ? constants.themeColors.scrollHandleHoverDark : constants.themeColors.scrollHandleHoverLight
    readonly property color tableBgColor: root.isDark ? constants.themeColors.tableBgDark : constants.themeColors.tableBgLight
    
    // ==================== Foreground Colors 前景色 ====================
    readonly property color foregroundColor: root.isDark ? constants.themeColors.foregroundDark : constants.themeColors.foregroundLight
    readonly property color secondaryForeground: root.isDark ? constants.themeColors.secondaryForegroundDark : constants.themeColors.secondaryForegroundLight
    readonly property color tertiaryForeground: root.isDark ? constants.themeColors.tertiaryForegroundDark : constants.themeColors.tertiaryForegroundLight
    readonly property color disabledForeground: root.isDark ? constants.themeColors.disabledForegroundDark : constants.themeColors.disabledForegroundLight
    readonly property color accentForeground: constants.themeColors.accentForeground
    
    // ==================== Border Colors 边框色 ====================
    readonly property color borderColor: root.isDark ? constants.themeColors.borderDark : constants.themeColors.borderLight
    readonly property color borderLightColor: root.isDark ? constants.themeColors.borderLightDark : constants.themeColors.borderLightLight
    readonly property color borderStrongColor: root.isDark ? constants.themeColors.borderStrongDark : constants.themeColors.borderStrongLight
    readonly property color dividerColor: root.isDark ? constants.themeColors.dividerDark : constants.themeColors.dividerLight
    
    // ==================== Interaction Colors 交互色 ====================
    readonly property color hoverColor: root.isDark ? constants.themeColors.hoverDark : constants.themeColors.hoverLight
    readonly property color pressedColor: root.isDark ? constants.themeColors.pressedDark : constants.themeColors.pressedLight
    readonly property color disabledColor: root.isDark ? constants.themeColors.disabledDark : constants.themeColors.disabledLight
    readonly property color selectedColor: root.isDark ? constants.themeColors.selectedDark : constants.themeColors.selectedLight
    readonly property color starColor: constants.themeColors.star
    readonly property color infoAccentColor: root.isDark ? constants.themeColors.infoAccentDark : constants.themeColors.infoAccentLight
    
    // ==================== Shadow Colors 阴影色 ====================
    readonly property color shadowColor: root.isDark ? constants.themeColors.shadowDark : constants.themeColors.shadowLight
    readonly property color shadowStrongColor: root.isDark ? constants.themeColors.shadowStrongDark : constants.themeColors.shadowStrongLight
}
