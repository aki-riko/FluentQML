// Copyright 2026 aki-riko
// SPDX-License-Identifier: MIT
// This file is part of FluentQML, licensed under MIT.

import QtQuick
import QtQuick.Effects
import "../.."
import "../icons"
import "../../effects"
import "Card"
import "../data/Label"

// TimelineCore - Timeline widget 时间线组件
// Supports grouped items with status icons and cards 支持分组项目、状态图标和卡片
Item {
    id: control
    
    // ==================== Public Props 公开属性 ====================
    // Items format: [{title: "已完成", status: "success", cards: [{text: "Task1", status: "success", strikeOut: true}]}, ...]
    // status: "success", "info", "warning", "error"
    property var items: []
    
    // ==================== Signals 信号 ====================
    signal itemClicked(int groupIndex, string title)
    signal cardClicked(int groupIndex, int cardIndex, string text)
    // cardClickedData: 回传完整 card 对象(含调用方自定义字段,如业务 id/hash)
    // cardClickedData: emits the full card object (carrying caller's custom fields, e.g. business id/hash)
    signal cardClickedData(int groupIndex, int cardIndex, var cardData)
    
    implicitWidth: 400
    implicitHeight: contentColumn.implicitHeight
    
    // ==================== Helper 辅助函数 ====================
    function _getStatusColor(status) {
        switch (status) {
            case "success": return Enums.statusLevel.successColor
            case "warning": return Enums.statusLevel.warningColor
            case "error": return Enums.statusLevel.errorColor
            default: return Enums.accentColor  // info
        }
    }
    
    function _getStatusIcon(status) {
        switch (status) {
            case "success": return "Checkmark"      // 简单勾号，不带圆圈
            case "warning": return "Warning"        // 感叹号三角
            case "error": return "Dismiss"          // 简单X，不带圆圈
            default: return "Info"                  // info - i图标
        }
    }
    
    // ==================== Content 内容 ====================
    Column {
        id: contentColumn
        width: parent.width
        spacing: Enums.spacing.none
        
        Repeater {
            model: items
            
            delegate: Item {
                id: groupItem
                width: contentColumn.width
                height: groupContent.height
                
                required property var modelData
                required property int index
                
                // Connector line 连接线（在图标下方）
                Rectangle {
                    x: 7  // 图标中心位置
                    y: Enums.spacing.timelineHeaderHeight  // 从标题下方开始
                    width: Enums.border.normal
                    height: parent.height - Enums.spacing.timelineHeaderHeight
                    color: Enums.stateColor.borderSubtle
                }
                
                Column {
                    id: groupContent
                    width: parent.width
                    spacing: Enums.spacing.none
                    
                    // Group header 分组标题
                    Item {
                        width: groupContent.width
                        height: Enums.spacing.timelineHeaderHeight
                        
                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Enums.spacing.m
                            
                            // Status icon 状态图标（圆形填充）
                            Rectangle {
                                width: Enums.controlSize.timelineIcon
                                height: Enums.controlSize.timelineIcon
                                radius: Enums.controlSize.timelineIcon / 2
                                anchors.verticalCenter: parent.verticalCenter
                                color: control._getStatusColor(groupItem.modelData.status || "info")
                                
                                // Info用文字i，其他用图标
                                Loader {
                                    anchors.centerIn: parent
                                    sourceComponent: (groupItem.modelData.status || "info") === "info" ? infoTextComponent : iconComponent
                                    
                                    Component {
                                        id: infoTextComponent
                                        Text {
                                            text: "i"
                                            font.family: "Times New Roman"
                                            font.pixelSize: Enums.typography.micro
                                            font.italic: true
                                            font.weight: Font.DemiBold
                                            color: Enums.accentForeground
                                        }
                                    }
                                    
                                    Component {
                                        id: iconComponent
                                        Icon {
                                            icon: control._getStatusIcon(groupItem.modelData.status || "info")
                                            iconSize: Enums.typography.micro
                                            color: Enums.accentForeground
                                        }
                                    }
                                }
                            }
                            
                            // Title 标题
                            Label {
                                type: Enums.label.type_body_strong
                                anchors.verticalCenter: parent.verticalCenter
                                text: groupItem.modelData.title || ""
                            }
                        }
                        
                        MouseArea {
                            anchors.fill: parent
                            onClicked: control.itemClicked(groupItem.index, groupItem.modelData.title || "")
                        }
                    }
                    
                    // Cards container 卡片容器
                    Column {
                        width: groupContent.width
                        spacing: Enums.spacing.m
                        leftPadding: Enums.spacing.timelineIndent  // 与标题对齐
                        topPadding: Enums.spacing.s
                        bottomPadding: Enums.spacing.l
                        
                        Repeater {
                            model: groupItem.modelData.cards || []
                            
                            delegate: Item {
                                id: cardItem
                                width: groupContent.width - 56
                                height: simpleCard.height
                                
                                required property var modelData
                                required property int index
                                
                                // Card status 卡片状态
                                property string cardStatus: typeof modelData === "object" ? (modelData.status || groupItem.modelData.status || "info") : (groupItem.modelData.status || "info")
                                property bool hasStrikeOut: typeof modelData === "object" ? (modelData.strikeOut || false) : false
                                property string cardText: typeof modelData === "string" ? modelData : (modelData.text || "")
                                // 可选副标题行(如提交的 hash·作者·日期);为空则不显示
                                property string cardDescription: typeof modelData === "object" ? (modelData.description || "") : ""
                                
                                Card {
                                    id: simpleCard
                                    cardType: Enums.card.type_hover
                                    width: parent.width
                                    height: cardContent.implicitHeight + Enums.spacing.l * 2
                                    clickEnabled: true
                                    onClicked: {
                                        control.cardClicked(groupItem.index, cardItem.index, cardItem.cardText)
                                        control.cardClickedData(groupItem.index, cardItem.index, cardItem.modelData)
                                    }
                                    
                                    Row {
                                        id: cardContent
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.margins: Enums.spacing.l
                                        spacing: Enums.spacing.m
                                        
                                        // Card status icon 卡片状态图标
                                        Rectangle {
                                            width: Enums.controlSize.timelineCardIcon
                                            height: Enums.controlSize.timelineCardIcon
                                            radius: Enums.radius.medium
                                            anchors.verticalCenter: parent.verticalCenter
                                            color: control._getStatusColor(cardItem.cardStatus)
                                            
                                            // Info用文字i，其他用图标
                                            Loader {
                                                anchors.centerIn: parent
                                                sourceComponent: cardItem.cardStatus === "info" ? cardInfoTextComponent : cardIconComponent
                                                
                                                Component {
                                                    id: cardInfoTextComponent
                                                    Text {
                                                        text: "i"
                                                        font.family: "Times New Roman"
                                                        font.pixelSize: Enums.typography.tiny
                                                        font.italic: true
                                                        font.weight: Font.DemiBold
                                                        color: Enums.accentForeground
                                                    }
                                                }
                                                
                                                Component {
                                                    id: cardIconComponent
                                                    Icon {
                                                        icon: control._getStatusIcon(cardItem.cardStatus)
                                                        iconSize: Enums.typography.tiny
                                                        color: Enums.accentForeground
                                                    }
                                                }
                                            }
                                        }
                                        
                                        // Card text 卡片文字(主标题 + 可选副标题)
                                        Column {
                                            width: parent.width - 24
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: Enums.spacing.xxs

                                            Label {
                                                type: Enums.label.type_body
                                                width: parent.width
                                                text: cardItem.cardText
                                                color: cardItem.hasStrikeOut ? Enums.textColor.secondary : Enums.textColor.primary
                                                wrapMode: Text.Wrap
                                                font.strikeout: cardItem.hasStrikeOut
                                            }
                                            Label {
                                                type: Enums.label.type_caption
                                                width: parent.width
                                                visible: cardItem.cardDescription !== ""
                                                text: cardItem.cardDescription
                                                color: Enums.textColor.tertiary
                                                wrapMode: Text.Wrap
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
