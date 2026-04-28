"""VM lifecycle helpers — libvirt + qemu-guest-agent.

`libvirt-python` is an optional extra (`uv sync --extra vm`) so the harness
can be installed and tested without libvirt-dev present. The actual
lifecycle calls fail-fast with a clear `VmStateError` if libvirt isn't
available.
"""

from __future__ import annotations

import base64
import json
import time
from dataclasses import dataclass
from typing import Any

from .errors import VmStateError
from .logging_setup import get_logger

log = get_logger(__name__)

try:
    import libvirt
    import libvirt_qemu

    _libvirt: Any = libvirt
    _libvirt_qemu: Any = libvirt_qemu
    del libvirt, libvirt_qemu
except ImportError:
    _libvirt = None
    _libvirt_qemu = None


def _lv() -> Any:
    """Return the libvirt module or raise a clear error."""
    if _libvirt is None:
        raise VmStateError(
            "libvirt-python not installed. After Phase 1 (apt install libvirt-dev), "
            "run `uv sync --extra vm` from emulator/hil/agent."
        )
    return _libvirt


def _state_name(state: int) -> str:
    lv = _lv()
    mapping = {
        lv.VIR_DOMAIN_NOSTATE: "unknown",
        lv.VIR_DOMAIN_RUNNING: "running",
        lv.VIR_DOMAIN_BLOCKED: "running",
        lv.VIR_DOMAIN_PAUSED: "paused",
        lv.VIR_DOMAIN_SHUTDOWN: "shutoff",
        lv.VIR_DOMAIN_SHUTOFF: "shutoff",
        lv.VIR_DOMAIN_CRASHED: "crashed",
        lv.VIR_DOMAIN_PMSUSPENDED: "paused",
    }
    return mapping.get(state, "unknown")


@dataclass(slots=True)
class VmStatus:
    name: str
    state: str  # "running" | "shutoff" | "paused" | "crashed" | "unknown"
    qemu_ga_responsive: bool


class Lifecycle:
    def __init__(self, uri: str, domain: str) -> None:
        self._uri = uri
        self._domain_name = domain
        self._conn: Any = None

    def __enter__(self) -> Lifecycle:
        lv = _lv()
        self._conn = lv.open(self._uri)
        if self._conn is None:
            raise VmStateError(f"libvirt.open({self._uri!r}) returned None")
        return self

    def __exit__(self, *_exc: object) -> None:
        if self._conn is not None:
            self._conn.close()
            self._conn = None

    def status(self) -> VmStatus:
        dom = self._domain()
        state, _ = dom.state()
        name = _state_name(state)
        return VmStatus(
            name=self._domain_name,
            state=name,
            qemu_ga_responsive=name == "running" and self._guest_ping(),
        )

    def start(self) -> None:
        lv = _lv()
        dom = self._domain()
        state, _ = dom.state()
        if state in (lv.VIR_DOMAIN_RUNNING, lv.VIR_DOMAIN_BLOCKED):
            return
        dom.create()

    def shutdown(self, timeout_s: int = 60) -> None:
        lv = _lv()
        dom = self._domain()
        state, _ = dom.state()
        if state in (lv.VIR_DOMAIN_SHUTOFF, lv.VIR_DOMAIN_SHUTDOWN):
            return
        dom.shutdown()
        deadline = time.monotonic() + timeout_s
        while time.monotonic() < deadline:
            state, _ = dom.state()
            if state in (lv.VIR_DOMAIN_SHUTOFF, lv.VIR_DOMAIN_SHUTDOWN):
                return
            time.sleep(1.0)
        log.warning("graceful shutdown timed out, destroying", domain=self._domain_name)
        dom.destroy()

    def revert_snapshot(self, snapshot: str) -> None:
        dom = self._domain()
        snap = dom.snapshotLookupByName(snapshot)
        dom.revertToSnapshot(snap)

    def wait_ready(self, timeout_s: int = 90, poll_s: float = 1.0) -> None:
        """Wait for the VM to be running AND qemu-guest-agent responsive."""
        deadline = time.monotonic() + timeout_s
        while time.monotonic() < deadline:
            s = self.status()
            if s.state == "running" and s.qemu_ga_responsive:
                return
            if s.state == "crashed":
                raise VmStateError(f"VM {s.name} crashed during boot")
            time.sleep(poll_s)
        raise VmStateError(
            f"VM {self._domain_name} not ready within {timeout_s}s "
            "(libvirt running + qemu-ga responsive)"
        )

    def file_exists(self, path: str) -> bool:
        """qemu-ga guest-exec on Windows: cmd.exe /c if exist <path> exit 0 else exit 1."""
        result = self._guest_exec(
            ["cmd.exe", "/c", "if", "exist", path, "(exit 0)", "else", "(exit 1)"]
        )
        return result == 0

    def usbip_reattach(self, host_ip: str, busid: str = "1-1", timeout_s: int = 45) -> None:
        """Re-attach the emulator's USB/IP device inside the Windows VM.

        The `driver-bound` snapshot remembers an active usbip-win2 session,
        but after `revert_snapshot` the underlying TCP socket is dead and
        the device shows up as `CM_PROB_PHANTOM` in PnP. This re-runs the
        attach so NikonScan can find the scanner. Idempotent: detach is
        attempted first and tolerated if the device is already dropped.
        """
        # Poll up to ~20 s for PnP Status=OK after attach (usbip-win2's
        # driver bind is observed at 5-10 s per M15 phase log), then sleep
        # an additional 5 s for usbscan kernel-mode service to publish the
        # device handle. Without the post-OK settle, NikonScan launches
        # before the handle is available and reports "no active devices."
        ps_script = (
            "$ErrorActionPreference = 'Continue'\n"
            "$usbip = 'C:\\Program Files\\USBip\\usbip.exe'\n"
            "& $usbip detach -p 1 2>&1 | Out-Null\n"
            f"& $usbip attach -r {host_ip} -b {busid} 2>&1 | Out-String | Write-Output\n"
            "for ($i = 0; $i -lt 20; $i++) {\n"
            "    Start-Sleep -Seconds 1\n"
            "    $dev = Get-PnpDevice -InstanceId 'USB\\VID_04B0&PID_4001\\*' "
            "-ErrorAction SilentlyContinue\n"
            "    if ($dev -and $dev.Status -eq 'OK') {\n"
            "        Write-Output \"PnP OK after $i s; settling 5 s for usbscan\"\n"
            "        Start-Sleep -Seconds 5\n"
            "        exit 0\n"
            "    }\n"
            "}\n"
            "Write-Output \"PnP did not reach OK after 20 s\"\n"
            "exit 1\n"
        )
        encoded = base64.b64encode(ps_script.encode("utf-16-le")).decode()
        result = self._guest_exec(
            ["powershell.exe", "-NoProfile", "-NonInteractive", "-EncodedCommand", encoded],
            timeout_s=timeout_s,
        )
        if result != 0:
            raise VmStateError(
                f"usbip reattach to {host_ip} bus {busid} failed (exit code {result}); "
                "PnP device did not reach Status=OK within 20s"
            )

    # --- internals ---

    def _domain(self) -> Any:
        lv = _lv()
        if self._conn is None:
            raise VmStateError("Lifecycle used outside a `with` block")
        try:
            return self._conn.lookupByName(self._domain_name)
        except lv.libvirtError as e:
            raise VmStateError(f"domain {self._domain_name!r} not found: {e}") from e

    def _guest_ping(self) -> bool:
        lv = _lv()
        try:
            self._qemu_agent_command({"execute": "guest-ping"})
            return True
        except lv.libvirtError:
            return False

    def _guest_exec(self, argv: list[str], timeout_s: int = 10) -> int:
        start = self._qemu_agent_command(
            {
                "execute": "guest-exec",
                "arguments": {
                    "path": argv[0],
                    "arg": argv[1:],
                    "capture-output": False,
                },
            }
        )
        pid_obj = start["return"]
        if not isinstance(pid_obj, dict):
            raise VmStateError(f"guest-exec returned malformed pid response: {start!r}")
        pid = int(pid_obj["pid"])
        deadline = time.monotonic() + timeout_s
        while time.monotonic() < deadline:
            status_resp = self._qemu_agent_command(
                {"execute": "guest-exec-status", "arguments": {"pid": pid}}
            )["return"]
            if not isinstance(status_resp, dict):
                raise VmStateError(f"guest-exec-status malformed: {status_resp!r}")
            if status_resp.get("exited"):
                return int(status_resp.get("exitcode", -1))
            time.sleep(0.2)
        raise VmStateError(f"guest-exec {argv!r} timed out after {timeout_s}s")

    def _qemu_agent_command(self, payload: dict[str, object]) -> dict[str, object]:
        # qemuAgentCommand is exposed by the libvirt_qemu submodule as a free
        # function taking (domain, command, timeout, flags) — not as a method
        # on the domain object as the C API docs imply.
        if _libvirt_qemu is None:
            raise VmStateError("libvirt_qemu module not available")
        dom = self._domain()
        raw = _libvirt_qemu.qemuAgentCommand(dom, json.dumps(payload), 5, 0)
        return dict(json.loads(raw))
