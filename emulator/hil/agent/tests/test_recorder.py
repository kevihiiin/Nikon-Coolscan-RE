"""RecipeRecorder — verify frames are captured and manifest is written."""

from __future__ import annotations

import json
from pathlib import Path
from unittest.mock import MagicMock

import pytest
from PIL import Image

from coolscan_hil_agent.recorder import RecipeRecorder


@pytest.mark.asyncio
async def test_records_distinct_frames(tmp_path: Path) -> None:
    vnc = MagicMock()
    # First two captures differ; third is a duplicate of the second.
    vnc.capture.side_effect = [
        Image.new("RGB", (32, 32), color=(0, 0, 0)),
        Image.effect_noise((32, 32), 200).convert("RGB"),
        Image.effect_noise((32, 32), 200).convert("RGB"),  # close to previous
        Image.effect_noise((32, 32), 50).convert("RGB"),  # different again
    ]
    rec = RecipeRecorder(vnc, tmp_path / "recordings")
    manifest_path = await rec.record("test", max_frames=4, poll_s=0)
    assert manifest_path.exists()
    lines = [
        line for line in manifest_path.read_text(encoding="utf-8").splitlines() if line.strip()
    ]
    # We capture 4 frames but the recorder may dedupe close ones; should have ≥2 entries.
    assert len(lines) >= 2
    # Each line is a parseable JSON object
    parsed = [json.loads(line) for line in lines]
    assert all("frame" in r and "phash" in r for r in parsed)
    # The PNG files referenced by the manifest exist.
    out_dir = tmp_path / "recordings" / "test"
    for r in parsed:
        assert (out_dir / r["frame"]).exists()
