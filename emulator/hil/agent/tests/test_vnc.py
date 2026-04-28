"""VncClient — verify vncdotool calls dispatch correctly per Action."""

from __future__ import annotations

from unittest.mock import MagicMock, patch

import pytest
from PIL import Image

from coolscan_hil_agent.actions import (
    Click,
    DoubleClick,
    Key,
    Scroll,
    Type,
    Wait,
)
from coolscan_hil_agent.errors import VmStateError
from coolscan_hil_agent.vnc import VncClient


@pytest.fixture
def mock_inner() -> MagicMock:
    """Mock the underlying ThreadedVNCClientProxy that vncdotool returns."""
    return MagicMock()


def _client_with(mock_inner: MagicMock) -> VncClient:
    c = VncClient("127.0.0.1", 5900, "")
    with patch("coolscan_hil_agent.vnc.vnc_api.connect", return_value=mock_inner):
        c.connect()
    return c


def test_capture_returns_image(mock_inner: MagicMock) -> None:
    c = _client_with(mock_inner)

    def fake_capture(buf: object) -> None:
        Image.new("RGB", (16, 16), color=(0, 0, 0)).save(buf, format="PNG")  # type: ignore[arg-type]

    mock_inner.captureScreen.side_effect = fake_capture
    img = c.capture()
    assert img.size == (16, 16)


def test_execute_click_dispatches_left_button(mock_inner: MagicMock) -> None:
    c = _client_with(mock_inner)
    c.execute(Click(type="click", x=100, y=200, button="left"))
    mock_inner.mouseMove.assert_called_once_with(100, 200)
    mock_inner.mousePress.assert_called_once_with(1)


def test_execute_click_dispatches_right_button(mock_inner: MagicMock) -> None:
    c = _client_with(mock_inner)
    c.execute(Click(type="click", x=10, y=20, button="right"))
    mock_inner.mousePress.assert_called_once_with(3)


def test_execute_double_click_presses_twice(mock_inner: MagicMock) -> None:
    c = _client_with(mock_inner)
    c.execute(DoubleClick(type="double_click", x=10, y=10))
    assert mock_inner.mousePress.call_count == 2


def test_execute_type_per_char_keypress(mock_inner: MagicMock) -> None:
    # vncdotool exposes no string-typing helper; we keyPress per character
    # and translate spaces to the named "space" key.
    c = _client_with(mock_inner)
    c.execute(Type(type="type", text="ab c"))
    assert mock_inner.keyPress.call_count == 4
    mock_inner.keyPress.assert_any_call("a")
    mock_inner.keyPress.assert_any_call("b")
    mock_inner.keyPress.assert_any_call("space")
    mock_inner.keyPress.assert_any_call("c")


def test_execute_key_normalizes_multichar_to_lowercase(mock_inner: MagicMock) -> None:
    # vncdotool's KEYMAP uses lowercase named-key entries; multi-char keys
    # like "Return" must be lowercased before keyPress to avoid an ord()
    # crash in _decodeKey's fallback path.
    c = _client_with(mock_inner)
    c.execute(Key(type="key", key="Return"))
    mock_inner.keyPress.assert_called_once_with("return")


def test_execute_key_preserves_singlechar_case(mock_inner: MagicMock) -> None:
    # Single-char keys keep case so capital ASCII letters resolve to the
    # uppercase keysym via ord('A') = 65.
    c = _client_with(mock_inner)
    c.execute(Key(type="key", key="A"))
    mock_inner.keyPress.assert_called_once_with("A")


def test_execute_scroll_up_uses_button_4(mock_inner: MagicMock) -> None:
    c = _client_with(mock_inner)
    c.execute(Scroll(type="scroll", direction="up", amount=3))
    assert mock_inner.mousePress.call_count == 3
    mock_inner.mousePress.assert_any_call(4)


def test_execute_scroll_down_uses_button_5(mock_inner: MagicMock) -> None:
    c = _client_with(mock_inner)
    c.execute(Scroll(type="scroll", direction="down", amount=2))
    assert mock_inner.mousePress.call_count == 2
    mock_inner.mousePress.assert_any_call(5)


def test_execute_wait_sleeps(mock_inner: MagicMock) -> None:
    c = _client_with(mock_inner)
    with patch("coolscan_hil_agent.vnc.time.sleep") as sleep:
        c.execute(Wait(type="wait", ms=50))
    sleep.assert_called_once_with(0.05)


def test_capture_fails_when_not_connected() -> None:
    c = VncClient("127.0.0.1", 5900)
    with pytest.raises(VmStateError):
        c.capture()


def test_connect_failure_translates_to_vmstateerror() -> None:
    c = VncClient("127.0.0.1", 5900)
    with (
        patch("coolscan_hil_agent.vnc.vnc_api.connect", side_effect=ConnectionRefusedError("nope")),
        pytest.raises(VmStateError),
    ):
        c.connect()


def test_disconnect_is_idempotent(mock_inner: MagicMock) -> None:
    c = _client_with(mock_inner)
    c.disconnect()
    c.disconnect()  # second call no-ops
    mock_inner.disconnect.assert_called_once()


def test_save_capture_writes_png(tmp_path: object, mock_inner: MagicMock) -> None:
    c = _client_with(mock_inner)

    def fake_capture(buf: object) -> None:
        Image.new("RGB", (8, 8)).save(buf, format="PNG")  # type: ignore[arg-type]

    mock_inner.captureScreen.side_effect = fake_capture
    out = tmp_path / "sub" / "frame.png"  # type: ignore[operator]
    img = c.save_capture(out)
    assert out.exists()
    assert img.size == (8, 8)
