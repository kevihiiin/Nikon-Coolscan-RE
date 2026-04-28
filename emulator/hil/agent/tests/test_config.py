"""Settings + load_settings behaviour."""

from __future__ import annotations

from pathlib import Path

import pytest

from coolscan_hil_agent.config import Settings, load_settings
from coolscan_hil_agent.errors import ConfigError


def test_settings_uses_defaults_when_env_missing(monkeypatch: pytest.MonkeyPatch) -> None:
    for key in ("HOLO3_BASE_URL", "HOLO3_API_KEY", "VNC_HOST"):
        monkeypatch.delenv(key, raising=False)
    settings = Settings(_env_file=None)  # type: ignore[call-arg]
    assert settings.holo3_base_url == ""
    assert settings.holo3_model == "Hcompany/Holo3-35B-A3B"
    assert settings.vnc_host == "127.0.0.1"
    assert settings.vnc_port == 5900


def test_load_settings_raises_without_holo3_url(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    monkeypatch.delenv("HOLO3_BASE_URL", raising=False)
    monkeypatch.chdir(tmp_path)
    with pytest.raises(ConfigError):
        load_settings()


def test_load_settings_succeeds_with_url(monkeypatch: pytest.MonkeyPatch, tmp_path: Path) -> None:
    monkeypatch.setenv("HOLO3_BASE_URL", "https://example.test/v1")
    monkeypatch.chdir(tmp_path)
    settings = load_settings()
    assert settings.holo3_base_url == "https://example.test/v1"
