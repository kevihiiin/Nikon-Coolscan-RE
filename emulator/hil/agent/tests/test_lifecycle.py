"""Lifecycle — libvirt is mocked; verify state translation, qemu-ga ping, file_exists."""

from __future__ import annotations

import json
from unittest.mock import MagicMock

import pytest

from coolscan_hil_agent.errors import VmStateError
from coolscan_hil_agent.lifecycle import Lifecycle, _state_name


def _libvirt_mock() -> MagicMock:
    """A mock libvirt module with the constants and exception type we use."""
    lv = MagicMock()
    lv.VIR_DOMAIN_NOSTATE = 0
    lv.VIR_DOMAIN_RUNNING = 1
    lv.VIR_DOMAIN_BLOCKED = 2
    lv.VIR_DOMAIN_PAUSED = 3
    lv.VIR_DOMAIN_SHUTDOWN = 4
    lv.VIR_DOMAIN_SHUTOFF = 5
    lv.VIR_DOMAIN_CRASHED = 6
    lv.VIR_DOMAIN_PMSUSPENDED = 7
    lv.libvirtError = type("MockLibvirtError", (Exception,), {})
    return lv


@pytest.fixture
def lv(monkeypatch: pytest.MonkeyPatch) -> MagicMock:
    mock = _libvirt_mock()
    monkeypatch.setattr("coolscan_hil_agent.lifecycle._libvirt", mock)
    return mock


def test_state_name_translates_known_constants(lv: MagicMock) -> None:
    assert _state_name(lv.VIR_DOMAIN_RUNNING) == "running"
    assert _state_name(lv.VIR_DOMAIN_BLOCKED) == "running"
    assert _state_name(lv.VIR_DOMAIN_SHUTOFF) == "shutoff"
    assert _state_name(lv.VIR_DOMAIN_CRASHED) == "crashed"
    assert _state_name(99) == "unknown"


def test_lifecycle_raises_when_libvirt_missing(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr("coolscan_hil_agent.lifecycle._libvirt", None)
    with (
        pytest.raises(VmStateError, match="libvirt-python not installed"),
        Lifecycle("qemu:///system", "x"),
    ):
        pass


def test_open_returns_none_raises(lv: MagicMock) -> None:
    lv.open.return_value = None
    with pytest.raises(VmStateError, match="returned None"), Lifecycle("qemu:///system", "x"):
        pass


def test_status_running_with_qemu_ga(lv: MagicMock) -> None:
    conn = MagicMock()
    dom = MagicMock()
    dom.state.return_value = (lv.VIR_DOMAIN_RUNNING, 0)
    dom.qemuAgentCommand.return_value = json.dumps({"return": {}})
    conn.lookupByName.return_value = dom
    lv.open.return_value = conn

    with Lifecycle("qemu:///system", "vm1") as lc:
        st = lc.status()
        assert st.state == "running"
        assert st.qemu_ga_responsive is True


def test_status_running_but_qemu_ga_silent(lv: MagicMock) -> None:
    conn = MagicMock()
    dom = MagicMock()
    dom.state.return_value = (lv.VIR_DOMAIN_RUNNING, 0)
    dom.qemuAgentCommand.side_effect = lv.libvirtError("agent timeout")
    conn.lookupByName.return_value = dom
    lv.open.return_value = conn

    with Lifecycle("qemu:///system", "vm1") as lc:
        st = lc.status()
        assert st.state == "running"
        assert st.qemu_ga_responsive is False


def test_start_no_op_when_already_running(lv: MagicMock) -> None:
    conn, dom = MagicMock(), MagicMock()
    dom.state.return_value = (lv.VIR_DOMAIN_RUNNING, 0)
    conn.lookupByName.return_value = dom
    lv.open.return_value = conn

    with Lifecycle("qemu:///system", "vm1") as lc:
        lc.start()
    dom.create.assert_not_called()


def test_start_creates_when_off(lv: MagicMock) -> None:
    conn, dom = MagicMock(), MagicMock()
    dom.state.return_value = (lv.VIR_DOMAIN_SHUTOFF, 0)
    conn.lookupByName.return_value = dom
    lv.open.return_value = conn

    with Lifecycle("qemu:///system", "vm1") as lc:
        lc.start()
    dom.create.assert_called_once()


def test_revert_snapshot_calls_libvirt(lv: MagicMock) -> None:
    conn, dom = MagicMock(), MagicMock()
    snap = MagicMock()
    dom.snapshotLookupByName.return_value = snap
    conn.lookupByName.return_value = dom
    lv.open.return_value = conn

    with Lifecycle("qemu:///system", "vm1") as lc:
        lc.revert_snapshot("baseline")
    dom.snapshotLookupByName.assert_called_once_with("baseline")
    dom.revertToSnapshot.assert_called_once_with(snap)


def test_file_exists_true_when_guest_exec_returns_zero(lv: MagicMock) -> None:
    conn, dom = MagicMock(), MagicMock()
    conn.lookupByName.return_value = dom
    lv.open.return_value = conn

    responses = [
        json.dumps({"return": {"pid": 42}}),
        json.dumps({"return": {"exited": True, "exitcode": 0}}),
    ]
    dom.qemuAgentCommand.side_effect = responses

    with Lifecycle("qemu:///system", "vm1") as lc:
        assert lc.file_exists(r"C:\out.txt") is True


def test_file_exists_false_when_guest_exec_returns_nonzero(lv: MagicMock) -> None:
    conn, dom = MagicMock(), MagicMock()
    conn.lookupByName.return_value = dom
    lv.open.return_value = conn

    responses = [
        json.dumps({"return": {"pid": 7}}),
        json.dumps({"return": {"exited": True, "exitcode": 1}}),
    ]
    dom.qemuAgentCommand.side_effect = responses

    with Lifecycle("qemu:///system", "vm1") as lc:
        assert lc.file_exists(r"C:\absent.txt") is False


def test_lookup_failure_translates(lv: MagicMock) -> None:
    conn = MagicMock()
    conn.lookupByName.side_effect = lv.libvirtError("not found")
    lv.open.return_value = conn

    with Lifecycle("qemu:///system", "missing") as lc, pytest.raises(VmStateError):
        lc.status()


def test_wait_ready_succeeds_immediately_when_running(lv: MagicMock) -> None:
    conn, dom = MagicMock(), MagicMock()
    dom.state.return_value = (lv.VIR_DOMAIN_RUNNING, 0)
    dom.qemuAgentCommand.return_value = json.dumps({"return": {}})
    conn.lookupByName.return_value = dom
    lv.open.return_value = conn

    with Lifecycle("qemu:///system", "vm1") as lc:
        lc.wait_ready(timeout_s=1)


def test_wait_ready_raises_on_crashed(lv: MagicMock) -> None:
    conn, dom = MagicMock(), MagicMock()
    dom.state.return_value = (lv.VIR_DOMAIN_CRASHED, 0)
    conn.lookupByName.return_value = dom
    lv.open.return_value = conn

    with Lifecycle("qemu:///system", "vm1") as lc, pytest.raises(VmStateError, match="crashed"):
        lc.wait_ready(timeout_s=1)


def test_used_outside_with_block_raises(lv: MagicMock) -> None:
    lc = Lifecycle("qemu:///system", "vm1")
    with pytest.raises(VmStateError, match="outside a `with` block"):
        lc.status()
