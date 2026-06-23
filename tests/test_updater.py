# coding: utf-8
# Copyright 2026 aki-riko
# SPDX-License-Identifier: MIT
"""Updater 组件单元测试。

覆盖纯逻辑(版本比对 / asset 选择)与信号发射(注入假 JSON,不真连网)。
"""

import json
import os
import pytest

from fluentqml.python.core.updater import (
    Updater,
    _parse_version,
    _is_newer,
    _pick_asset,
)


# ==================== 版本比对 ====================
class TestVersionCompare:
    def test_strip_v_prefix(self):
        assert _parse_version("v1.0.3") == _parse_version("1.0.3")
        assert _parse_version("V2.1.0") == _parse_version("2.1.0")

    def test_newer_basic(self):
        assert _is_newer("v1.0.4", "v1.0.3")
        assert _is_newer("v1.1.0", "v1.0.9")
        assert _is_newer("v2.0.0", "v1.9.9")

    def test_not_newer_equal(self):
        assert not _is_newer("v1.0.3", "v1.0.3")

    def test_not_newer_older(self):
        assert not _is_newer("v1.0.2", "v1.0.3")
        assert not _is_newer("v1.0.0", "v1.1.0")

    def test_release_newer_than_prerelease(self):
        # 1.0.0 应比 1.0.0-beta 新(数字段 > 字符串段)
        assert _is_newer("v1.0.0", "v1.0.0-beta")

    def test_empty_is_smallest(self):
        assert _parse_version("") == ()
        assert _is_newer("v0.0.1", "")
        assert not _is_newer("", "v0.0.1")

    def test_different_length(self):
        # 1.0.1 > 1.0
        assert _is_newer("v1.0.1", "v1.0")
        # 1.0 不比 1.0.0 新(段比较,1.0 的元组更短)
        assert not _is_newer("v1.0", "v1.0.0")


# ==================== asset 选择 ====================
class TestPickAsset:
    def test_empty(self):
        assert _pick_asset([], "Setup") is None

    def test_keyword_exe_first(self):
        assets = [
            {"name": "source.zip"},
            {"name": "Gitora-Setup-1.0.4.exe"},
            {"name": "other.exe"},
        ]
        a = _pick_asset(assets, "Setup")
        assert a["name"] == "Gitora-Setup-1.0.4.exe"

    def test_fallback_any_exe(self):
        assets = [{"name": "source.zip"}, {"name": "tool.exe"}]
        a = _pick_asset(assets, "Setup")
        assert a["name"] == "tool.exe"

    def test_fallback_first(self):
        assets = [{"name": "a.zip"}, {"name": "b.tar.gz"}]
        a = _pick_asset(assets, "Setup")
        assert a["name"] == "a.zip"

    def test_keyword_case_insensitive(self):
        assets = [{"name": "MyApp-setup-2.0.exe"}]
        a = _pick_asset(assets, "Setup")
        assert a["name"] == "MyApp-setup-2.0.exe"


# ==================== 信号(注入假数据,不连网) ====================
class TestSignals:
    def _make(self):
        return Updater("owner/repo", "v1.0.3", asset_keyword="Setup")

    def test_update_available(self, qapp):
        up = self._make()
        received = {}

        def on_avail(version, notes, dl, html):
            received.update(version=version, notes=notes, dl=dl, html=html)

        up.updateAvailable.connect(on_avail)

        fake = {
            "tag_name": "v1.0.4",
            "body": "新功能",
            "html_url": "https://github.com/owner/repo/releases/tag/v1.0.4",
            "assets": [
                {"name": "Gitora-Setup-1.0.4.exe",
                 "browser_download_url": "https://example.com/Gitora-Setup-1.0.4.exe"},
            ],
        }
        up._inject_release_for_test(json.dumps(fake).encode("utf-8"))

        assert received["version"] == "v1.0.4"
        assert received["notes"] == "新功能"
        assert received["dl"].endswith("Gitora-Setup-1.0.4.exe")
        assert "releases/tag" in received["html"]

    def test_up_to_date(self, qapp):
        up = self._make()
        seen = {}
        up.upToDate.connect(lambda v: seen.update(v=v))
        up._inject_release_for_test(json.dumps({"tag_name": "v1.0.3"}).encode("utf-8"))
        assert seen["v"] == "v1.0.3"

    def test_up_to_date_when_older_remote(self, qapp):
        up = self._make()
        seen = {}
        up.upToDate.connect(lambda v: seen.update(v=v))
        up._inject_release_for_test(json.dumps({"tag_name": "v1.0.0"}).encode("utf-8"))
        assert seen["v"] == "v1.0.3"

    def test_check_failed_bad_json(self, qapp):
        up = self._make()
        seen = {}
        up.checkFailed.connect(lambda m: seen.update(m=m))
        up._inject_release_for_test(b"not json {{{")
        assert "m" in seen

    def test_check_failed_no_tag(self, qapp):
        up = self._make()
        seen = {}
        up.checkFailed.connect(lambda m: seen.update(m=m))
        up._inject_release_for_test(json.dumps({"name": "no tag here"}).encode("utf-8"))
        assert "m" in seen


# ==================== 安装(不真启动进程) ====================
class TestInstaller:
    def test_run_installer_missing_file(self, qapp):
        up = Updater("owner/repo", "v1.0.3")
        assert up.runInstallerAndQuit("/non/existent/path.exe") is False

    def test_open_in_browser_empty(self, qapp):
        up = Updater("owner/repo", "v1.0.3")
        assert up.openInBrowser("") is False
