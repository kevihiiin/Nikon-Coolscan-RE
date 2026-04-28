"""Append-only oracle.jsonl writer + simple aggregation.

Every Holo3 call (oracle or grounding) is recorded to
`artifacts/<run-id>/oracle.jsonl` so we can track agreement-rate drift
over time and triage which screens Holo3 mis-grades.
"""

from __future__ import annotations

import json
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any


@dataclass(slots=True)
class OracleRecord:
    run_id: str
    step_idx: int
    expected_state: str
    frame_phash: str
    agreed: bool
    reason: str
    latency_ms: float
    model_id: str
    fallback_taken: bool = False


def append_oracle(path: Path, record: OracleRecord) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a", encoding="utf-8") as f:
        f.write(json.dumps(asdict(record)) + "\n")


@dataclass(slots=True)
class AgreementReport:
    total: int
    agreed: int
    disagreed: int
    fallback_recovered: int
    p50_latency_ms: float
    p95_latency_ms: float

    @property
    def agreement_rate(self) -> float:
        return self.agreed / self.total if self.total else 0.0


def aggregate(jsonl_path: Path) -> AgreementReport:
    """Produce an agreement report over the records in `jsonl_path`."""
    records: list[dict[str, Any]] = []
    if jsonl_path.exists():
        with jsonl_path.open(encoding="utf-8") as f:
            for line in f:
                stripped = line.strip()
                if stripped:
                    records.append(json.loads(stripped))

    total = len(records)
    agreed = sum(1 for r in records if r["agreed"])
    fallback_recovered = sum(1 for r in records if not r["agreed"] and r.get("fallback_taken"))
    latencies = sorted(float(r["latency_ms"]) for r in records)
    p50 = _quantile(latencies, 0.50)
    p95 = _quantile(latencies, 0.95)
    return AgreementReport(
        total=total,
        agreed=agreed,
        disagreed=total - agreed,
        fallback_recovered=fallback_recovered,
        p50_latency_ms=p50,
        p95_latency_ms=p95,
    )


def _quantile(sorted_xs: list[float], q: float) -> float:
    """Approximate q-th quantile via the "value above which (1-q) lies" convention.

    Matches numpy's `quantile(x, q, method='higher')` close enough for our
    needs (operator latency reporting). Tail items dominate at small N.
    """
    import math

    if not sorted_xs:
        return 0.0
    idx = math.ceil(q * len(sorted_xs)) - 1
    idx = max(0, min(idx, len(sorted_xs) - 1))
    return sorted_xs[idx]
