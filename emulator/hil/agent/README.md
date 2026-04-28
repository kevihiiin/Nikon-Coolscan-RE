# coolscan-hil-agent

Python agent harness that drives **NikonScan 4.0.3** in a Windows 10 VM
against the Coolscan emulator, using a vision-oracle + grounding-fallback
loop powered by an externally-hosted **Holo3** endpoint.

Sits alongside the Rust `hil` crate (`../`) which already provides the
USB/IP server and smoke-test client. This package adds the *agent loop*:
screenshot capture, scripted clicks, vision-based assertion, recovery
grounding, recipe orchestration, and an MCP server so Claude Code can
drive everything from this terminal.

See `docs/architecture.md` for design, `docs/operator-guide.md` for
day-to-day usage, and `~/.claude/plans/purrfect-sparking-newt.md` for
the full M15 plan.

## Status

Phase 5 of M15 (NikonScan E2E). Scaffolding in progress.

## Quickstart (once scaffold complete)

```bash
# from repo root
cd emulator/hil/agent
uv sync --extra dev
cp .env.example .env       # then fill HOLO3_BASE_URL, HOLO3_API_KEY, etc.

# verify endpoint
uv run coolscan-hil holo3-smoke

# verify VM lifecycle
uv run coolscan-hil vm status

# run a recipe (after one has been recorded)
uv run coolscan-hil run inquiry_smoke
```

## Layout

| Path | Purpose |
|---|---|
| `src/coolscan_hil_agent/` | Library + CLI |
| `src/.../recipes/` | Recipe definitions (Python files using the DSL) |
| `baselines/` | Committed pHash + model_id per recipe per screen state |
| `recordings/` | (gitignored) `recorder.py` output for new recipes |
| `artifacts/` | (gitignored) Per-run-id screenshots, oracle responses, logs |
| `tests/` | Unit tests; Holo3 + libvirt + VNC are mocked |
| `docs/` | Architecture, operator guide, ADRs |

## Architecture in one sentence

Scripted VNC clicks drive deterministic happy-path execution; a Holo3
oracle grades each post-action screenshot; on disagreement, Holo3
grounding takes over to recover or fail-loud with diagnostics; Claude
Code (Max sub) sits above as the planner via FastMCP.

## Project conventions

- Python ≥ 3.11, uv-managed, pinned via `uv.lock`
- `ruff` lint + format, `mypy --strict`, `pytest` with ≥ 80% coverage gate
- Structured logs via `structlog` (JSON), every step indexed by `run_id`
- Logs append to `../../docs/log/components/agent-harness-attempts.md`
  per project APPEND ONLY rules
