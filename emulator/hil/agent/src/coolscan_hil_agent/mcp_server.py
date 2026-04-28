"""FastMCP stdio server. Claude Code (Max sub) connects via `.mcp.json`
at the repo root and invokes these tools.

Tools mirror the planning spec in `~/.claude/plans/purrfect-sparking-newt.md`:
- run_recipe — execute one named recipe end-to-end
- inspect_screenshot — Holo3 oracle call against an arbitrary screenshot
- compare_runs — pHash diff between two runs' steps
- vm_state / vm_revert — libvirt lifecycle
- record_recipe — interactive recorder for new recipes
- record_baseline — promote a captured screen into baselines/
- aggregate_oracle_stats — agreement-rate report over historical runs
"""

from __future__ import annotations

import json
from dataclasses import asdict
from pathlib import Path

from fastmcp import FastMCP
from PIL import Image

from .config import Settings
from .holo3 import Holo3Client
from .lifecycle import Lifecycle
from .logging_setup import configure, get_logger
from .metrics import aggregate
from .recipes import discover
from .runner import RecipeResult, RecipeRunner
from .vnc import VncClient

mcp = FastMCP("coolscan-hil-agent")
log = get_logger(__name__)


def _settings() -> Settings:
    return Settings()


@mcp.tool()
async def run_recipe(name: str) -> dict[str, object]:
    """Run a named recipe against the live VM and return its RecipeResult."""
    settings = _settings()
    recipes = discover()
    if name not in recipes:
        return {"success": False, "error": f"unknown recipe {name!r}; have {sorted(recipes)}"}

    holo3 = Holo3Client(
        base_url=settings.holo3_base_url,
        model=settings.holo3_model,
        api_key=settings.holo3_api_key,
    )
    vnc = VncClient(settings.vnc_host, settings.vnc_port, settings.vnc_password)
    vnc.connect()
    try:
        with Lifecycle(settings.libvirt_uri, settings.libvirt_domain) as lc:
            runner = RecipeRunner(
                vnc=vnc,
                holo3=holo3,
                lifecycle=lc,
                artifacts_root=settings.artifacts_dir,
                baselines_dir=settings.baselines_dir,
            )
            result = await runner.run(recipes[name]())
            return _result_to_dict(result)
    finally:
        await holo3.aclose()
        vnc.disconnect()


@mcp.tool()
async def inspect_screenshot(path: str, question: str) -> dict[str, object]:
    """Send a saved screenshot to Holo3 with a free-form question (oracle mode)."""
    settings = _settings()
    img = Image.open(path).convert("RGB")
    holo3 = Holo3Client(settings.holo3_base_url, settings.holo3_model, settings.holo3_api_key)
    try:
        call = await holo3.oracle(img, question)
        return {"agreed": call.agreed, "reason": call.reason, "model_id": call.model_id}
    finally:
        await holo3.aclose()


@mcp.tool()
def vm_state() -> dict[str, object]:
    settings = _settings()
    with Lifecycle(settings.libvirt_uri, settings.libvirt_domain) as lc:
        return asdict(lc.status())


@mcp.tool()
def vm_revert(snapshot: str | None = None) -> dict[str, object]:
    settings = _settings()
    snap = snapshot or settings.libvirt_snapshot
    with Lifecycle(settings.libvirt_uri, settings.libvirt_domain) as lc:
        lc.revert_snapshot(snap)
        return {"ok": True, "reverted_to": snap}


@mcp.tool()
def aggregate_oracle_stats(run_id: str | None = None) -> dict[str, object]:
    """If run_id is given, aggregate that run's oracle.jsonl. Otherwise aggregate all runs."""
    settings = _settings()
    if run_id:
        report = aggregate(settings.artifacts_dir / run_id / "oracle.jsonl")
        return asdict(report)

    # Concatenate across runs by reading every file.
    combined: list[dict[str, object]] = []
    for jsonl in settings.artifacts_dir.glob("*/oracle.jsonl"):
        for line in jsonl.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if line:
                combined.append(json.loads(line))
    # Quick aggregate without re-running through the file API
    total = len(combined)
    agreed = sum(1 for r in combined if r["agreed"])
    return {
        "total": total,
        "agreed": agreed,
        "disagreed": total - agreed,
        "agreement_rate": (agreed / total) if total else 0.0,
    }


@mcp.tool()
def record_baseline(recipe: str, state: str, run_id: str) -> dict[str, object]:
    """Promote the screenshot taken during `state` in run `run_id` into baselines/."""
    settings = _settings()
    # Find the matching screenshot — runner saves <NNN>-expect_screen.png in steps/.
    # We rely on oracle.jsonl to map idx → state.
    oracle_path = settings.artifacts_dir / run_id / "oracle.jsonl"
    if not oracle_path.exists():
        return {"ok": False, "error": f"run {run_id!r} not found"}

    target_idx: int | None = None
    target_phash: str | None = None
    for line in oracle_path.read_text(encoding="utf-8").splitlines():
        rec = json.loads(line)
        if rec["expected_state"] == state and rec["agreed"]:
            target_idx = rec["step_idx"]
            target_phash = rec["frame_phash"]
            break

    if target_idx is None or target_phash is None:
        return {"ok": False, "error": f"no green oracle record for state={state!r}"}

    out = settings.baselines_dir / recipe / f"{state}.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(
        json.dumps(
            {
                "phash": target_phash,
                "model_id": _read_manifest(settings.artifacts_dir / run_id).get("model_id"),
                "promoted_from_run": run_id,
                "step_idx": target_idx,
            },
            indent=2,
        )
    )
    return {"ok": True, "baseline_path": str(out)}


def _read_manifest(run_dir: Path) -> dict[str, object]:
    manifest = run_dir / "manifest.json"
    if not manifest.exists():
        return {}
    return dict(json.loads(manifest.read_text(encoding="utf-8")))


def _result_to_dict(result: RecipeResult) -> dict[str, object]:
    # RecipeResult is a slotted dataclass; asdict handles it.
    return asdict(result)


def main() -> None:
    configure(level="INFO", json_format=True)
    log.info("mcp_server_start")
    mcp.run()


if __name__ == "__main__":
    main()
