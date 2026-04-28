"""CLI smoke tests via typer.testing.CliRunner."""

from __future__ import annotations

import json

import pytest
import respx
from typer.testing import CliRunner

from coolscan_hil_agent.cli import app


@pytest.fixture
def runner() -> CliRunner:
    return CliRunner()


def test_help_renders(runner: CliRunner) -> None:
    res = runner.invoke(app, ["--help"])
    assert res.exit_code == 0
    assert "coolscan-hil-agent" in res.stdout


def test_holo3_smoke_fails_fast_without_url(
    runner: CliRunner, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.delenv("HOLO3_BASE_URL", raising=False)
    monkeypatch.chdir("/")  # avoid finding a stray .env
    res = runner.invoke(app, ["holo3-smoke"])
    assert res.exit_code == 2
    assert "config error" in res.stdout.lower() or "config error" in (res.stderr or "").lower()


def test_holo3_smoke_against_mocked_endpoint(
    runner: CliRunner, monkeypatch: pytest.MonkeyPatch, tmp_path: object
) -> None:
    monkeypatch.setenv("HOLO3_BASE_URL", "https://endpoint.test/v1")
    monkeypatch.setenv("HOLO3_MODEL", "mock-holo3")
    monkeypatch.setenv("HOLO3_API_KEY", "test")
    monkeypatch.chdir(tmp_path)  # type: ignore[arg-type]

    completion = {
        "id": "x",
        "object": "chat.completion",
        "created": 0,
        "model": "mock-holo3",
        "choices": [
            {
                "index": 0,
                "message": {
                    "role": "assistant",
                    "content": json.dumps({"agreed": True, "reason": "looks good"}),
                },
                "finish_reason": "stop",
            }
        ],
    }
    with respx.mock(base_url="https://endpoint.test/v1") as router:
        router.post("/chat/completions").respond(json=completion)
        res = runner.invoke(app, ["holo3-smoke"])

    assert res.exit_code == 0, res.stdout
    parsed = json.loads(res.stdout)
    assert parsed["agreed"] is True
    assert parsed["reason"] == "looks good"


def test_vm_status_translates_hil_error(runner: CliRunner, monkeypatch: pytest.MonkeyPatch) -> None:
    """If libvirt isn't installed, Lifecycle raises VmStateError on entry — CLI exits 2 cleanly."""
    monkeypatch.setattr("coolscan_hil_agent.lifecycle._libvirt", None)
    res = runner.invoke(app, ["vm", "status"])
    assert res.exit_code == 2
    output = (res.stdout or "") + (res.stderr or "")
    assert "VmStateError" in output


def test_run_unknown_recipe_fails(
    runner: CliRunner, monkeypatch: pytest.MonkeyPatch, tmp_path: object
) -> None:
    monkeypatch.setenv("HOLO3_BASE_URL", "https://endpoint.test/v1")
    monkeypatch.chdir(tmp_path)  # type: ignore[arg-type]
    res = runner.invoke(app, ["run", "no-such-recipe"])
    assert res.exit_code == 2
    output = (res.stdout or "") + (res.stderr or "")
    assert "no-such-recipe" in output or "unknown" in output.lower()


def test_vm_help_lists_subcommands(runner: CliRunner) -> None:
    res = runner.invoke(app, ["vm", "--help"])
    assert res.exit_code == 0
    for sub in ("status", "start", "shutdown", "revert"):
        assert sub in res.stdout
