"""RecipeRunner — vnc/holo3/lifecycle mocked; verify per-step flow + fallback."""

from __future__ import annotations

import json
from pathlib import Path
from unittest.mock import AsyncMock, MagicMock

import imagehash
import pytest
from PIL import Image

from coolscan_hil_agent.actions import Click, Done
from coolscan_hil_agent.errors import OracleUnavailableError
from coolscan_hil_agent.holo3 import GroundingCall, OracleCall
from coolscan_hil_agent.recipe import Recipe
from coolscan_hil_agent.runner import RecipeRunner


def _agreed(reason: str = "ok") -> OracleCall:
    return OracleCall(agreed=True, reason=reason, latency_ms=10.0, model_id="test-holo3")


def _disagreed(reason: str = "wrong") -> OracleCall:
    return OracleCall(agreed=False, reason=reason, latency_ms=10.0, model_id="test-holo3")


def _make_runner(
    tmp_path: Path,
    vnc: MagicMock,
    holo3: MagicMock,
    lifecycle: MagicMock,
) -> RecipeRunner:
    return RecipeRunner(
        vnc=vnc,
        holo3=holo3,
        lifecycle=lifecycle,
        artifacts_root=tmp_path / "artifacts",
        baselines_dir=tmp_path / "baselines",
    )


def _holo3_mock(model_id: str = "test-holo3") -> MagicMock:
    h = MagicMock()
    h.model_id = model_id
    h.oracle = AsyncMock(return_value=_agreed())
    h.ground = AsyncMock()
    return h


@pytest.mark.asyncio
async def test_action_step_executes_and_captures(
    tmp_path: Path, mock_vnc: MagicMock, mock_lifecycle: MagicMock
) -> None:
    holo3 = _holo3_mock()
    runner = _make_runner(tmp_path, mock_vnc, holo3, mock_lifecycle)
    recipe = Recipe("smoke").click_at(100, 200)
    result = await runner.run(recipe)
    assert result.success
    assert result.run_id  # non-empty
    assert mock_vnc.execute.called
    artifacts_dir = Path(result.artifacts_dir)
    assert (artifacts_dir / "manifest.json").exists()
    assert (artifacts_dir / "steps" / "000-action.png").exists()


@pytest.mark.asyncio
async def test_expect_screen_oracle_agreed_passes(
    tmp_path: Path, mock_vnc: MagicMock, mock_lifecycle: MagicMock
) -> None:
    holo3 = _holo3_mock()
    runner = _make_runner(tmp_path, mock_vnc, holo3, mock_lifecycle)
    recipe = Recipe("ok").expect_screen("welcome")
    result = await runner.run(recipe)
    assert result.success
    holo3.oracle.assert_awaited_once()
    # oracle.jsonl appended to
    assert (Path(result.artifacts_dir) / "oracle.jsonl").exists()


@pytest.mark.asyncio
async def test_oracle_disagrees_then_grounding_recovers(
    tmp_path: Path, mock_vnc: MagicMock, mock_lifecycle: MagicMock
) -> None:
    holo3 = _holo3_mock()
    holo3.oracle.side_effect = [
        _disagreed("dialog visible"),
        _agreed("dialog dismissed"),
    ]
    holo3.ground.return_value = GroundingCall(
        action=Click(type="click", x=50, y=50), latency_ms=20.0, model_id="test-holo3"
    )

    runner = _make_runner(tmp_path, mock_vnc, holo3, mock_lifecycle)
    recipe = Recipe("recovery").expect_screen("clean")
    result = await runner.run(recipe)
    assert result.success
    assert holo3.ground.await_count == 1
    assert holo3.oracle.await_count == 2  # initial + recheck


@pytest.mark.asyncio
async def test_grounding_done_action_short_circuits(
    tmp_path: Path, mock_vnc: MagicMock, mock_lifecycle: MagicMock
) -> None:
    holo3 = _holo3_mock()
    holo3.oracle.return_value = _disagreed()
    holo3.ground.return_value = GroundingCall(
        action=Done(type="done", reason="already there"),
        latency_ms=15.0,
        model_id="test-holo3",
    )
    runner = _make_runner(tmp_path, mock_vnc, holo3, mock_lifecycle)
    result = await runner.run(Recipe("done").expect_screen("here"))
    assert result.success


@pytest.mark.asyncio
async def test_grounding_abort_fails_recipe(
    tmp_path: Path, mock_vnc: MagicMock, mock_lifecycle: MagicMock
) -> None:
    from coolscan_hil_agent.actions import Abort

    holo3 = _holo3_mock()
    holo3.oracle.return_value = _disagreed("nope")
    holo3.ground.return_value = GroundingCall(
        action=Abort(type="abort", reason="cannot recover"),
        latency_ms=10.0,
        model_id="test-holo3",
    )
    runner = _make_runner(tmp_path, mock_vnc, holo3, mock_lifecycle)
    result = await runner.run(Recipe("abort").expect_screen("x"))
    assert not result.success
    assert result.failure_step == 0
    assert "cannot recover" in result.oracle_reasoning


@pytest.mark.asyncio
async def test_oracle_unavailable_fails_step(
    tmp_path: Path, mock_vnc: MagicMock, mock_lifecycle: MagicMock
) -> None:
    holo3 = _holo3_mock()
    holo3.oracle.side_effect = OracleUnavailableError("503")
    runner = _make_runner(tmp_path, mock_vnc, holo3, mock_lifecycle)
    result = await runner.run(Recipe("dead-endpoint").expect_screen("x"))
    assert not result.success
    assert "503" in result.oracle_reasoning


@pytest.mark.asyncio
async def test_assert_file_exists_calls_lifecycle(
    tmp_path: Path, mock_vnc: MagicMock, mock_lifecycle: MagicMock
) -> None:
    holo3 = _holo3_mock()
    runner = _make_runner(tmp_path, mock_vnc, holo3, mock_lifecycle)
    result = await runner.run(Recipe("ck").assert_file_exists(r"C:\foo.txt"))
    assert result.success
    mock_lifecycle.file_exists.assert_called_once_with(r"C:\foo.txt")


@pytest.mark.asyncio
async def test_assert_file_exists_fails_when_absent(
    tmp_path: Path, mock_vnc: MagicMock, mock_lifecycle: MagicMock
) -> None:
    mock_lifecycle.file_exists.return_value = False
    holo3 = _holo3_mock()
    runner = _make_runner(tmp_path, mock_vnc, holo3, mock_lifecycle)
    result = await runner.run(Recipe("missing").assert_file_exists(r"C:\nope.txt"))
    assert not result.success


@pytest.mark.asyncio
async def test_baseline_hash_passes_when_close(tmp_path: Path, mock_lifecycle: MagicMock) -> None:
    img = Image.new("RGB", (32, 32), color=(50, 50, 50))
    vnc = MagicMock()
    vnc.capture.return_value = img
    holo3 = _holo3_mock()
    runner = _make_runner(tmp_path, vnc, holo3, mock_lifecycle)
    baseline = str(imagehash.phash(img))
    result = await runner.run(Recipe("baseline_ok").expect_screen("x", baseline_hash=baseline))
    assert result.success


@pytest.mark.asyncio
async def test_baseline_hash_fails_when_different(
    tmp_path: Path, mock_lifecycle: MagicMock
) -> None:
    # Use two visually different images so pHash differs by > threshold (5).
    different = Image.new("RGB", (32, 32), color=(0, 0, 0))
    captured = Image.effect_noise((32, 32), 200).convert("RGB")
    vnc = MagicMock()
    vnc.capture.return_value = captured
    holo3 = _holo3_mock()
    runner = _make_runner(tmp_path, vnc, holo3, mock_lifecycle)
    baseline = str(imagehash.phash(different))
    result = await runner.run(Recipe("baseline_drift").expect_screen("x", baseline_hash=baseline))
    assert not result.success
    assert "pHash distance" in (result.oracle_reasoning or result.steps[-1].error)


@pytest.mark.asyncio
async def test_manifest_records_model_id(
    tmp_path: Path, mock_vnc: MagicMock, mock_lifecycle: MagicMock
) -> None:
    holo3 = _holo3_mock(model_id="custom-model-7b")
    runner = _make_runner(tmp_path, mock_vnc, holo3, mock_lifecycle)
    result = await runner.run(Recipe("m"))
    manifest = json.loads(
        (Path(result.artifacts_dir) / "manifest.json").read_text(encoding="utf-8")
    )
    assert manifest["model_id"] == "custom-model-7b"


@pytest.mark.asyncio
async def test_assert_image_nonblank_passes_on_colorful_image(
    tmp_path: Path, mock_lifecycle: MagicMock
) -> None:
    vnc = MagicMock()
    vnc.capture.return_value = Image.effect_noise((32, 32), 200).convert("RGB")
    holo3 = _holo3_mock()
    runner = _make_runner(tmp_path, vnc, holo3, mock_lifecycle)
    result = await runner.run(Recipe("nb").assert_image_nonblank(min_unique_colors=5))
    assert result.success


@pytest.mark.asyncio
async def test_assert_image_nonblank_fails_on_solid_color(
    tmp_path: Path, mock_lifecycle: MagicMock
) -> None:
    vnc = MagicMock()
    vnc.capture.return_value = Image.new("RGB", (32, 32), color=(7, 7, 7))
    holo3 = _holo3_mock()
    runner = _make_runner(tmp_path, vnc, holo3, mock_lifecycle)
    result = await runner.run(Recipe("blank").assert_image_nonblank(min_unique_colors=5))
    assert not result.success
