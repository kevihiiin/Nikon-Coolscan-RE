"""Metrics: oracle.jsonl writer + aggregation."""

from __future__ import annotations

import json
from pathlib import Path

from coolscan_hil_agent.metrics import OracleRecord, aggregate, append_oracle


def test_append_creates_parent_dir(tmp_path: Path) -> None:
    out = tmp_path / "deeply" / "nested" / "oracle.jsonl"
    rec = OracleRecord(
        run_id="r1",
        step_idx=0,
        expected_state="s",
        frame_phash="0",
        agreed=True,
        reason="ok",
        latency_ms=12.0,
        model_id="m",
    )
    append_oracle(out, rec)
    assert out.exists()
    body = out.read_text(encoding="utf-8").strip()
    assert json.loads(body)["run_id"] == "r1"


def test_aggregate_empty(tmp_path: Path) -> None:
    report = aggregate(tmp_path / "missing.jsonl")
    assert report.total == 0
    assert report.agreement_rate == 0.0


def test_aggregate_mixed(tmp_path: Path) -> None:
    out = tmp_path / "oracle.jsonl"
    for i, agreed in enumerate([True, True, False, False, True]):
        append_oracle(
            out,
            OracleRecord(
                run_id="r",
                step_idx=i,
                expected_state="s",
                frame_phash="0",
                agreed=agreed,
                reason="ok" if agreed else "nope",
                latency_ms=10.0 * (i + 1),
                model_id="m",
                fallback_taken=not agreed,
            ),
        )
    report = aggregate(out)
    assert report.total == 5
    assert report.agreed == 3
    assert report.disagreed == 2
    assert report.fallback_recovered == 2
    assert report.agreement_rate == 0.6
    # latencies are 10, 20, 30, 40, 50; p50 ≈ 30, p95 ≈ 50
    assert report.p50_latency_ms == 30.0
    assert report.p95_latency_ms == 50.0
