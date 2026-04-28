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
