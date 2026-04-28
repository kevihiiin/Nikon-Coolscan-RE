"""VNC client wrapper around vncdotool.

Two responsibilities:
- Capture the VM's framebuffer as a PIL.Image (input to Holo3)
- Inject mouse/keyboard events for `Action`s the runner has authorized

`vncdotool` is synchronous and uses a Twisted reactor under the hood.
We hide that behind a small adapter so the rest of the harness can treat
it as plain blocking I/O.
"""

from __future__ import annotations

import io
import time
from pathlib import Path

from PIL import Image
from vncdotool import api as vnc_api

from . import actions
from .actions import Action, Click, DoubleClick, Key, Scroll, Type, Wait
from .errors import VmStateError
from .logging_setup import get_logger

log = get_logger(__name__)


class VncClient:
    """Synchronous VNC client backed by vncdotool."""

    def __init__(self, host: str, port: int, password: str = "") -> None:
        self._host = host
        self._port = port
        self._password = password
        self._client: vnc_api.ThreadedVNCClientProxy | None = None

    def connect(self) -> None:
        if self._client is not None:
            return
        target = f"{self._host}::{self._port}"
        try:
            self._client = vnc_api.connect(target, password=self._password or None)
        except Exception as e:
            raise VmStateError(f"VNC connect to {target} failed: {e}") from e

    def disconnect(self) -> None:
        if self._client is not None:
            self._client.disconnect()
            self._client = None

    def capture(self) -> Image.Image:
        """Snapshot the framebuffer as a PIL RGB image."""
        client = self._require()
        # vncdotool captureScreen writes a PNG to a path; we round-trip through
        # an in-memory file to avoid a tempfile.
        buf = io.BytesIO()
        client.captureScreen(buf)
        buf.seek(0)
        return Image.open(buf).convert("RGB")

    def execute(self, action: Action) -> None:
        """Translate a validated `Action` into VNC events."""
        client = self._require()
        match action:
            case Click():
                self._move(client, action.x, action.y)
                client.mousePress(_button(action.button))
            case DoubleClick():
                self._move(client, action.x, action.y)
                client.mousePress(1)
                client.mousePress(1)
            case Type():
                # vncdotool's keyPress handles ASCII directly; for unicode use typeString
                client.typeString(action.text)
            case Key():
                client.keyPress(action.key)
            case Scroll():
                button = 4 if action.direction == "up" else 5
                for _ in range(action.amount):
                    client.mousePress(button)
            case Wait():
                time.sleep(action.ms / 1000.0)
            case actions.Done() | actions.Abort():
                # Terminal actions; runner inspects them directly, VNC never executes.
                pass

    def save_capture(self, path: Path) -> Image.Image:
        img = self.capture()
        path.parent.mkdir(parents=True, exist_ok=True)
        img.save(path, format="PNG")
        return img

    def _require(self) -> vnc_api.ThreadedVNCClientProxy:
        if self._client is None:
            raise VmStateError("VncClient.connect() not called")
        return self._client

    @staticmethod
    def _move(client: vnc_api.ThreadedVNCClientProxy, x: int, y: int) -> None:
        client.mouseMove(x, y)


def _button(name: str) -> int:
    return {"left": 1, "middle": 2, "right": 3}[name]
