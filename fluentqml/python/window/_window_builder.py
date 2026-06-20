# coding: utf-8
# Copyright 2026 aki-riko
# SPDX-License-Identifier: MIT
"""FluentQML Window Builder - 窗口构建器

负责 QML 窗口的动态构建与字符串拼接。
"""

from typing import List, Optional, TYPE_CHECKING
from pathlib import Path
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtQuick import QQuickItem
from PySide6.QtCore import QTimer, QMetaObject, Q_ARG
from ..core.logger import warning, info, error, debug
from ..core.engine import EngineManager
from ..providers import get_svg_provider

if TYPE_CHECKING:
    from .window_base import NavigationItem

class WindowBuilderMixin:
    """窗口构建器 Mixin，提供 _create_window 等方法"""

    @staticmethod
    def _escape_qml(text: str) -> str:
        """转义 QML 字符串中的特殊字符，防止注入

        安全说明：此函数仅用于转义用户传入的字符串值（如标题、文本标签），
        不可用于 QML 模板代码片段——花括号转义会破坏 QML 语法。

        Args:
            text: 原始字符串

        Returns:
            转义后的安全字符串
        """
        # 反斜杠必须最先替换，避免二次转义
        text = text.replace("\\", "\\\\")
        text = text.replace('"', '\\"')
        text = text.replace("\n", "\\n")
        text = text.replace("\r", "\\r")
        text = text.replace("\t", "\\t")
        # 花括号在 QML 中有语义（对象字面量 / JavaScript 代码块），需要 Unicode 转义
        text = text.replace("{", "\\u007B")
        text = text.replace("}", "\\u007D")
        return text

    def _create_window(self):
        """创建QML窗口"""
        from ..core import ThemeManager, getShadowManager
        from ..config import getConfigManager

        # 获取或创建引擎
        try:
            self._engine = EngineManager.get_engine()
        except RuntimeError:
            # 引擎未初始化，创建新引擎
            self._engine = QQmlApplicationEngine()
            EngineManager.set_engine(self._engine)

        # 注入管理器
        from .mica_window import get_mica_manager
        from .native_window import get_native_window_hook
        from ..providers.clipboard import get_clipboard_helper
        from ..core.icon_provider import register_icon_provider

        ctx = self._engine.rootContext()
        ctx.setContextProperty("ThemeManager", ThemeManager())
        ctx.setContextProperty("ShadowManager", getShadowManager())
        ctx.setContextProperty("ConfigManager", getConfigManager())
        ctx.setContextProperty("MicaManager", get_mica_manager())
        ctx.setContextProperty("ClipboardHelper", get_clipboard_helper())
        # WindowCore 调 NativeWindow.attach 让 frameless 享受 DWM 动画
        ctx.setContextProperty("NativeWindow", get_native_window_hook())

        # 注册Icon到QML（Python作为单一来源）
        register_icon_provider(self._engine)

        # 注册SVG图片提供器（高质量SVG渲染）
        self._engine.addImageProvider("svg", get_svg_provider())

        from ..core.utils import qml_path
        qml_dir = qml_path()
        icon_dir = qml_dir / "controls" / "icons" / "fluent"

        def icon_path(name: str) -> str:
            if not name:
                return ""
            
            # 支持内置协议
            if name.startswith(("qrc:/", "file:///", "http://", "https://")):
                return name
            
            # Qt 简写协议
            if name.startswith(":/"):
                return "qrc" + name
                
            # 本地绝对路径
            if "\\" in name or (len(name) > 1 and name[1] == ":") or name.startswith("/"):
                path_str = name.replace("\\", "/")
                return f"file:///{path_str.lstrip('/')}"
                
            # 内置图标回退
            return f"file:///{(icon_dir / f'{name}.svg').as_posix()}"

        # 构建导航项
        esc = self._escape_qml
        nav_items_qml = ", ".join(
            [
                f'{{ "text": "{esc(item.text)}", "icon": "{esc(icon_path(item.icon))}" }}'
                for item in self._nav_items
            ]
        )

        # Bottom items: all items get key, selectable controls page switching
        # 底部项：所有项都有key，selectable控制是否切换页面
        bottom_items_qml = ", ".join(
            [
                f'{{ "text": "{esc(item.text)}", "icon": "{esc(icon_path(item.icon))}", "key": "page_{len(self._nav_items) + i}", "selectable": {"true" if getattr(item, "selectable", True) else "false"} }}'
                for i, item in enumerate(self._bottom_nav_items)
            ]
        )

        # 生成用户卡片QML
        user_card_qml = ""
        if self._user_card:
            avatar = self._user_card.get("avatar", "")
            title = self._user_card.get("title", "")
            subtitle = self._user_card.get("subtitle", "")
            position = self._user_card.get("position", "bottom")
            # 如果avatar是图标名，转换为路径
            if avatar and not (
                "/" in avatar or "\\" in avatar or avatar.startswith("image://")
            ):
                avatar = icon_path(avatar)
            # Windows路径转换为QML格式（正斜杠 + file:///前缀）
            if avatar and ("\\" in avatar or (len(avatar) > 1 and avatar[1] == ":")):
                avatar = "file:///" + avatar.replace("\\", "/")
            user_card_qml = f'''
    userCard: {{ "avatar": "{esc(avatar)}", "title": "{esc(title)}", "subtitle": "{esc(subtitle)}" }}
    userCardPosition: "{esc(position)}"'''

        # 页面容器由Python动态创建，作为窗口默认子元素会自动放入StackedWidget
        # StackedWidget会自动管理可见性和动画
        # All items get page containers (function items just have empty containers)
        # 所有项都创建页面容器（功能项的容器为空）
        # 注意：必须显式绑定宽高到父容器，StackedWidget的Component.onCompleted
        # 只在初始化时执行，无法处理后续动态添加的子项
        page_items = []
        for i in range(len(self._nav_items) + len(self._bottom_nav_items)):
            page_items.append(f"""
        Item {{
            id: page_{i}
            objectName: "page_{i}"
            width: parent ? parent.width : 0
            height: parent ? parent.height : 0
        }}""")

        pages_qml = "\n".join(page_items) if page_items else ""

        # 根据window_type选择QML组件
        from .window_base import _WINDOW_TYPE_QML_NAMES
        qml_component = _WINDOW_TYPE_QML_NAMES.get(self._window_type, "WindowsBar")

        # 生成窗口QML
        window_qml = f"""import QtQuick
import "file:///{qml_dir.as_posix()}"
import "file:///{qml_dir.as_posix()}/_internal"
import "file:///{qml_dir.as_posix()}/controls/containers"

{qml_component} {{
    id: window
    objectName: "mainWindow"
    width: {self._width}
    height: {self._height}
    windowTitle: "{esc(self._title)}"
    windowIcon: "{esc(icon_path(self._icon) if self._icon else f'file:///{icon_dir.as_posix()}/Apps.svg')}"
    windowIconColored: {'true' if self._icon_colored else 'false'}
    lazyLoading: false
    micaEnabled: {'true' if getConfigManager().micaEnabled else 'false'}
    
    navigationItems: [{nav_items_qml}]
    bottomNavigationItems: [{bottom_items_qml}]
{user_card_qml}
    // Python动态填充的页面容器（绑定到stack.currentIndex控制可见性）
{pages_qml}
    
    onCurrentPageChanged: (index) => {{
    }}
}}
"""

        self._engine.loadData(window_qml.encode("utf-8"))

        if not self._engine.rootObjects():
            raise RuntimeError("Failed to create window")

        self._window = self._engine.rootObjects()[-1]

        # 找到内容区域（StackedWidget）
        self._find_content_area()

        # 连接信号
        self._connect_signals()

        # ⚠️ apply 子类 __init__ 期间缓存的 setProperty (Mica 等),
        # 这一步必须在 nativeHookReady (50ms 后) 之前完成,否则 hookReady 读到默认值
        self._apply_pending_state()

    def _build_nav_items_json(self, items: List['NavigationItem']) -> str:
        """构建导航项JSON"""
        esc = self._escape_qml
        return ", ".join(
            [f'{{"text": "{esc(item.text)}", "icon": "{esc(item.icon)}"}}' for item in items]
        )
