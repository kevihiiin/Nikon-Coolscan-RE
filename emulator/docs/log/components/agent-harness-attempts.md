# Agent Harness Development Log

Python package at `emulator/hil/agent/`. Drives NikonScan in a Win10 VM via VNC,
grades each post-action screenshot through a Holo3 endpoint (vision oracle),
falls back to Holo3 grounding when the oracle disagrees, exposes the pipeline
to Claude Code as MCP tools.

Plan: `~/.claude/plans/purrfect-sparking-newt.md`

---

## 2026-04-27 — Package scaffold

**Target**: directory layout, pyproject, tooling configs

### Directory layout created
```
emulator/hil/agent/
├── src/coolscan_hil_agent/recipes/
├── tests/
├── docs/adr/
├── baselines/    # committed pHash baselines per recipe per screen
├── recordings/   # gitignored; recorder.py output
└── artifacts/    # gitignored; per-run-id outputs
```

### Conventions confirmed against repo
- Python project tooling: `uv` (matches existing `pyproject.toml` at repo root)
- License: MIT (workspace setting from `emulator/Cargo.toml`)
- Logging style: APPEND ONLY (this file), status header above `---`, dated entries below
- Existing Rust `hil` crate at `emulator/hil/` is sibling to the new Python package; both share the same configs/ and scripts/ dirs at `emulator/hil/`

---

## 2026-04-27 — Implementation complete (5.1–5.5 + Phase 7 CI + VM runbook)

**Source modules (16)**: actions, cli, config, errors, holo3, lifecycle, logging_setup, mcp_server, metrics, recipe, runner, recorder, vnc + recipes/inquiry_smoke + 2 `__init__.py`

**Tests (12 files, 83 cases)**: actions/config/errors/holo3/lifecycle/metrics at 100 %, runner at 86 %, recipe at 81 %, vnc at 96 %, recorder at 88 %; cli + mcp_server lower because they exercise typer/MCP runtime paths that we don't unit-test.

**Docs (10 files)**: README + architecture, operator-guide, recipe-authoring, debugging, holo3-endpoint + 4 ADRs (vision-oracle pattern, VM-on-dev-box, FastMCP-vs-mcp-sdk, structured-output schema).

**CI**: `.github/workflows/agent-harness-tests.yml` (Tier 0, hosted) + `m15-regression.yml` (Tier 2, self-hosted). `.mcp.json` at repo root for Claude Code stdio server.

**VM runbook + scripts**: `vm-setup.md` + `setup_dev_box.sh`, `verify_iso.sh`, `win_vm_create.sh`, `re_roll_vm.sh`.

### Notable design choices

- **`@mcp.tool()` returns the function unchanged** — verified at runtime; test files call tool functions directly without `.fn` accessors. Makes the MCP server testable with no MCP runtime spun up.
- **`Action` discriminated union wrapped in `ActionEnvelope`** — OpenAI's `response_format={"type":"json_schema"}` requires an object root, not a union root. The envelope adds zero runtime cost.
- **`libvirt-python` is an optional `vm` extra** — package is installable + lint-able + (most-)testable on machines without `libvirt-dev`. `Lifecycle._lv()` raises a clear `VmStateError` if libvirt module is absent.
- **pytest coverage gate at 80 %** (planned target). `recipes/` excluded via `[tool.coverage.report].omit` — they're integration code, exercised by running them.
- **ISO is downloaded with `curl -L -C -`** so partial downloads resume on retry; SHA-256 verification is mandatory before any `virt-install` invocation.

### Bug fixes during testing
- Exception classes renamed to consistent `*Error` suffix (ruff N818)
- `_quantile` switched from floor-of-(q*(n-1)) to ceil(q*n)-1 — p95 of [10,20,30,40,50] now correctly returns 50
- CLI `vm` subcommands wrap `HilError` and exit cleanly (was raising tracebacks)
- `_libvirt: Any` typed via `try/import/del/except` dance to satisfy mypy strict + handle absent libvirt gracefully
- `mock_vnc` conftest fixture now persists `save_capture(path)` to disk so runner artifact assertions work

---

## 2026-04-28 — preview_scan + full_scan recipe skeletons

**Target**: ship the remaining two M15 recipes as committed skeletons. Closes plan exit criterion (`preview_scan` end-to-end).

**Files added**:
- `src/coolscan_hil_agent/recipes/preview_scan.py` — launch NikonScan, wait for main window, drive Preview, assert preview pane is not flat-grey
- `src/coolscan_hil_agent/recipes/full_scan.py` — launch NikonScan, drive Scan, wait for completion, assert TIFF in `C:\scans\*.tif`
- `tests/test_recipe.py` — discovery + shape assertions for both new recipes (open_app present, terminal step is the right kind)

**Design choice — no committed click coordinates yet**: vision-oracle + grounding-fallback pattern (ADR 0001) gives Holo3 up to 3 recovery actions per `expect_screen` to advance the UI to the expected state. For known-good NikonScan, this is sufficient for single-target buttons (Preview, Scan) without recorded coordinates. After a few green runs, `coolscan-hil record` will lock in pixel-accurate clicks and screen baselines, replacing the grounding hops with deterministic `click_at` calls. Recipes are honest about being "skeleton" in their docstrings.

**Why preview_scan ends on `assert_image_nonblank` rather than file-exists**: NikonScan does not auto-save preview to disk — preview is a window-internal render. Image-pixel-variety check is the only observable signal. `full_scan` is the recipe that produces the TIFF.

**`full_scan` resolution**: left at NikonScan default. A first green at default DPI proves the firmware-driven CCD → ASIC DMA → ISP1581 → USB-bulk pipeline end-to-end. Bumping to 4000 DPI for the throughput stress test (~50 MB transfer, exercises N4 from backlog) belongs in a follow-up `full_scan_4000.py` once this one is stable.

**Quality gates**: `ruff check` clean on new files (the pre-existing `vnc.py` SIM105 left as-is — pre-dates this commit). `mypy --strict`: no issues. `pytest`: 85/85 passing (was 83; +2 for new recipe shape tests), coverage holds at 83.33% (recipes/ omitted from coverage as planned per pyproject).

**Remaining work after this commit**:
- Run `preview_scan` against the live HIL stack to validate grounding fallback can navigate NikonScan's UI; promote screens to `baselines/preview_scan/`
- Run `full_scan` similarly; baseline + verify TIFF integrity
- Re-record clicks via `coolscan-hil record` to replace grounding hops once layouts are pinned
- Tier 2 CI dry-run via `workflow_dispatch` once `preview_scan` is green

---

## 2026-04-28 — First live `preview_scan` run: 7 harness bugs surfaced + emulator block

The live run drove out a stack of harness API mismatches that `inquiry_smoke` (single-frame, no app launch, no clicks) had never exercised. All 7 fixes landed in this commit.

**Bug 1 — `lifecycle._qemu_agent_command`**:
```python
raw = dom.qemuAgentCommand(json.dumps(payload), 5, 0)  # AttributeError: virDomain has no attribute 'qemuAgentCommand'
```
QEMU agent commands live in the `libvirt_qemu` submodule as a free function:
```python
import libvirt_qemu
raw = libvirt_qemu.qemuAgentCommand(dom, json.dumps(payload), 5, 0)
```
This was always broken; surfaced because `inquiry_smoke` only used VNC + Holo3, never qemu-ga. Tests updated to also mock `_libvirt_qemu` and route through it via lambda so existing `dom.qemuAgentCommand.*` assertions keep working. `pyproject.toml` mypy override extended to ignore `libvirt_qemu.*` missing stubs.

**Bug 2 — `vnc.py` `Type` action**:
The original code called `client.typeString(action.text)` — vncdotool has no such method. Replaced with per-character `keyPress` loop:
```python
for ch in action.text:
    client.keyPress("space" if ch == " " else ch)
    time.sleep(0.05)  # Windows kbd buffer drops faster typing
```
Without the 50 ms inter-char sleep, only the first 5–6 characters of "Nikon Scan" registered in the Run dialog and Windows reported "cannot find 'Nikon'."

**Bug 3 — `vnc.py` `Key` action**:
vncdotool's KEYMAP entries are lowercase (`return`, `space`, `super`). Multi-char names with mixed case like `"Return"` (used by `runner._open_app`) miss KEYMAP and fall through to `ord("Return")` which raises `TypeError: ord() expected a character, but string of length 6`. Fix: lowercase only multi-char keys; preserve single-char case so capital ASCII letters resolve to the right keysym.

**Bug 4 — `runner._open_app` Run dialog vs Start menu**:
Win+R Run dialog parses the first whitespace-separated token as the executable, so typing "Nikon Scan" and pressing Enter tries to launch `Nikon` with arg `Scan`. Switched to Win-key Start menu search: just press Super (no `-r`), wait, type the query, press Enter. Start menu treats the whole string as a query and launches the top match. Spaces, multi-word app names, and special chars all behave naturally. Confirmed live.

**Bug 5 — `runner._do_expect_screen` baseline-vs-grounding race**:
The `baseline_hash` check ran on `img` captured *before* `_oracle_with_fallback`. If the oracle disagreed and grounding successfully recovered (e.g. dismissed a leftover dialog), the recovered screen never got pHashed — the original disrupted frame did, and failed the hash. Re-capture after the oracle phase so the baseline check sees the screen the oracle just signed off on.

**Bug 6 — `Lifecycle.usbip_reattach` (new method)**:
The `driver-bound` snapshot was taken with usbip-win2 actively attached. After `revert_snapshot`, the VM's kernel state thinks USB is attached but the underlying TCP socket is dead — device shows `CM_PROB_PHANTOM` until a fresh `usbip attach` runs from inside the VM. Implemented as a qemu-ga + base64-encoded PowerShell script:
```
usbip detach -p 1 (ignored if not connected)
usbip attach -r {host_ip} -b {busid}
poll Get-PnpDevice for Status=OK (up to 20 s)
sleep 5 s for usbscan handle to publish
```
Wired into `cli.run` between VM-ready and recipe-start, non-fatal (`log.warning` on failure). New env vars `USBIP_HOST` / `USBIP_BUSID`.

**Bug 7 — Tests for the above** (3 new in `test_vnc.py`, fixture rewrite in `test_lifecycle.py`).

**Quality gates after the fix-up**: pytest 86/86 green, 83.24 % coverage, ruff clean on new files (pre-existing `vnc.py` SIM105 untouched), mypy `--strict` clean (18 source files).

**Live `preview_scan` run** got to step 3 of 6 (NikonScan main window verified by Holo3) before failing on `expect_screen("nikonscan-scanner-ready")`. Diagnostic via qemu-ga at the failure point confirms the device is fully attached on the Windows side — `usbip port` shows "device in use at High Speed (480 Mbps)", PnP is `Status=OK / CM_PROB_NONE / Service: usbscan`, and the `usbscan` service is `Running`. The blocker is **emulator-side**, not harness-side: the ISP1581 EP1 OUT FIFO underrun fabricates zero bytes which the firmware decodes as opcode 0x00 = TEST UNIT READY, so usbscan-driven INQUIRY/MODE SENSE never reaches the firmware. Filed as backlog **N7**. Backlog **N8** also opened: usbip server only accepts one attach per emulator instance.

**Recipe skeletons land green** mechanically — they'll pass for real once N7 is fixed; no recipe-side changes needed.
