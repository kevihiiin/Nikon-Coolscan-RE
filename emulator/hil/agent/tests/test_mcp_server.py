"""MCP server helper functions. The MCP runtime itself is exercised by Claude
Code; here we test the pieces that operate on artifacts/baselines."""

from __future__ import annotations

import json
from pathlib import Path
from unittest.mock import MagicMock, patch

import pytest


@pytest.fixture
def stub_settings(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> object:
    monkeypatch.setenv("HOLO3_BASE_URL", "https://x.test/v1")
    monkeypatch.setenv("ARTIFACTS_DIR", str(tmp_path / "artifacts"))
    monkeypatch.setenv("BASELINES_DIR", str(tmp_path / "baselines"))
    monkeypatch.chdir(tmp_path)
    from coolscan_hil_agent.config import Settings

    return Settings()


def _seed_run(artifacts: Path, run_id: str, model_id: str = "test-holo3") -> None:
    run_dir = artifacts / run_id
    (run_dir / "steps").mkdir(parents=True)
    (run_dir / "manifest.json").write_text(
        json.dumps({"recipe": "r", "run_id": run_id, "model_id": model_id})
    )
    oracle_path = run_dir / "oracle.jsonl"
    oracle_path.write_text(
        json.dumps(
            {
                "run_id": run_id,
                "step_idx": 0,
                "expected_state": "main-window",
                "frame_phash": "ff00ff00ff00ff00",
                "agreed": True,
                "reason": "ok",
                "latency_ms": 100,
                "model_id": model_id,
                "fallback_taken": False,
            }
        )
        + "\n"
    )


def test_record_baseline_promotes_oracle_record(tmp_path: Path, stub_settings: object) -> None:
    artifacts = tmp_path / "artifacts"
    baselines = tmp_path / "baselines"
    _seed_run(artifacts, "run42")

    with patch(
        "coolscan_hil_agent.mcp_server._settings",
        return_value=stub_settings,
    ):
        from coolscan_hil_agent.mcp_server import record_baseline

        result = record_baseline("test_recipe", "main-window", "run42")

    assert result["ok"] is True
    out_file = baselines / "test_recipe" / "main-window.json"
    assert out_file.exists()
    body = json.loads(out_file.read_text(encoding="utf-8"))
    assert body["phash"] == "ff00ff00ff00ff00"
    assert body["model_id"] == "test-holo3"
    assert body["promoted_from_run"] == "run42"


def test_record_baseline_unknown_run_returns_error(tmp_path: Path, stub_settings: object) -> None:
    with patch(
        "coolscan_hil_agent.mcp_server._settings",
        return_value=stub_settings,
    ):
        from coolscan_hil_agent.mcp_server import record_baseline

        result = record_baseline("any", "x", "missing-run")

    assert result["ok"] is False


def test_aggregate_oracle_stats_for_specific_run(tmp_path: Path, stub_settings: object) -> None:
    artifacts = tmp_path / "artifacts"
    _seed_run(artifacts, "runA")

    with patch(
        "coolscan_hil_agent.mcp_server._settings",
        return_value=stub_settings,
    ):
        from coolscan_hil_agent.mcp_server import aggregate_oracle_stats

        result = aggregate_oracle_stats("runA")

    assert result["total"] == 1
    assert result["agreed"] == 1


def test_aggregate_oracle_stats_across_all_runs(tmp_path: Path, stub_settings: object) -> None:
    artifacts = tmp_path / "artifacts"
    _seed_run(artifacts, "run1")
    _seed_run(artifacts, "run2")

    with patch(
        "coolscan_hil_agent.mcp_server._settings",
        return_value=stub_settings,
    ):
        from coolscan_hil_agent.mcp_server import aggregate_oracle_stats

        result = aggregate_oracle_stats(None)

    assert result["total"] == 2
    assert result["agreed"] == 2
    assert result["agreement_rate"] == 1.0


def test_vm_state_calls_lifecycle(tmp_path: Path, stub_settings: object) -> None:
    from coolscan_hil_agent.lifecycle import VmStatus

    fake_status = VmStatus(name="win10-ltsc-nikonscan", state="running", qemu_ga_responsive=True)

    fake_lc = MagicMock()
    fake_lc.__enter__.return_value = fake_lc
    fake_lc.status.return_value = fake_status

    with (
        patch("coolscan_hil_agent.mcp_server._settings", return_value=stub_settings),
        patch("coolscan_hil_agent.mcp_server.Lifecycle", return_value=fake_lc),
    ):
        from coolscan_hil_agent.mcp_server import vm_state

        result = vm_state()

    assert result["state"] == "running"
    assert result["qemu_ga_responsive"] is True
