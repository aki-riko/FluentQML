import QtQuick
import QtQuick.Layouts
import QtQuick.Window

Window {
    visible: true
    width: 800
    height: 600
    title: "CommandBar Layout Debug"
    color: "#f0f0f0"
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 10
        
        // 测试1: 简单Rectangle
        Rectangle {
            Layout.fillWidth: true
            height: 40
            color: "lightblue"
            Text { anchors.centerIn: parent; text: "Rectangle (Layout.fillWidth: true) - width: " + parent.width }
        }
        
        // 测试2: Item + 内部Rectangle
        Item {
            Layout.fillWidth: true
            implicitHeight: 40
            implicitWidth: 100  // 比父容器小的隐式宽度
            
            Rectangle {
                anchors.fill: parent
                color: "lightgreen"
                Text { anchors.centerIn: parent; text: "Item->Rect (Layout.fillWidth: true) - width: " + parent.width }
            }
        }
        
        // 测试3: Item + Loader + Rectangle (模拟CommandBar结构)
        Item {
            id: testItem3
            Layout.fillWidth: true
            implicitHeight: loader3.implicitHeight
            implicitWidth: loader3.implicitWidth  // 这就是问题！
            
            Loader {
                id: loader3
                anchors.fill: parent
                sourceComponent: Component {
                    Rectangle {
                        implicitWidth: 150
                        implicitHeight: 40
                        color: "lightyellow"
                        Text { 
                            anchors.centerIn: parent
                            text: "Loader->Rect - Item.width: " + testItem3.width + ", parent.width: " + parent.width
                        }
                    }
                }
            }
        }
        
        // 填充剩余空间
        Item { Layout.fillHeight: true }
        
        // 调试输出
        Text {
            text: "ColumnLayout width: " + parent.width
        }
    }
}
