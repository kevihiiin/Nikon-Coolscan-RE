"""Shared pytest fixtures."""

from __future__ import annotations

from collections.abc import Iterator
from pathlib import Path
from unittest.mock import MagicMock

import pytest
from PIL import Image


@pytest.fixture
def tmp_artifacts(tmp_path: Path) -> Path:
    """A clean per-test artifacts root."""
    out = tmp_path / "artifacts"
    out.mkdir()
    return out


@pytest.fixture
def grey_frame() -> Image.Image:
    """1024x768 solid-grey image — stand-in for a VNC capture."""
    return Image.new("RGB", (1024, 768), color=(192, 192, 192))


@pytest.fixture
def mock_vnc(grey_frame: Image.Image) -> MagicMock:
    """A mock VncClient that returns `grey_frame` from capture() and persists
    it on save_capture so the runner's per-step PNG writes appear on disk."""
    vnc = MagicMock()
    vnc.capture.return_value = grey_frame

    def _save(path: Path) -> Image.Image:
        path.parent.mkdir(parents=True, exist_ok=True)
        grey_frame.save(path, format="PNG")
        return grey_frame

    vnc.save_capture.side_effect = _save
    return vnc


@pytest.fixture
def mock_lifecycle() -> MagicMock:
    """A mock Lifecycle whose `status()` always reports running + qemu-ga ready."""
    lc = MagicMock()
    lc.status.return_value.state = "running"
    lc.status.return_value.qemu_ga_responsive = True
    lc.file_exists.return_value = True
    return lc


@pytest.fixture(autouse=True)
def _clear_structlog_context() -> Iterator[None]:
    """Ensure no run_id leaks across tests."""
    from coolscan_hil_agent.logging_setup import clear_run

    yield
    clear_run()
