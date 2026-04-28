"""Typer CLI: `coolscan-hil <subcommand>`.

Subcommands:
- holo3-smoke: send a fixture screenshot to the Holo3 endpoint and print the result
- run <recipe>: execute a recipe against the live VM
- record <recipe>: start an interactive recording session
- vm <action>: status | start | shutdown | revert
"""

from __future__ import annotations

import asyncio
import json
import sys
from pathlib import Path
from typing import Annotated

import typer
from PIL import Image

from .config import Settings, load_settings
from .errors import HilError
from .holo3 import Holo3Client
from .lifecycle import Lifecycle
from .logging_setup import configure, get_logger
from .recipes import discover
from .recorder import RecipeRecorder
from .runner import RecipeRunner
from .vnc import VncClient

app = typer.Typer(
    help="coolscan-hil-agent — NikonScan E2E regression harness",
    pretty_exceptions_show_locals=False,
    pretty_exceptions_short=True,
)
vm_app = typer.Typer(help="VM lifecycle commands")
app.add_typer(vm_app, name="vm")

log = get_logger(__name__)


@app.callback()
def _root(
    log_level: Annotated[str, typer.Option("--log-level")] = "INFO",
    log_format: Annotated[str, typer.Option("--log-format", help="json | console")] = "console",
) -> None:
    configure(level=log_level, json_format=log_format == "json")


def _exit_on_hil_error(e: HilError) -> typer.Exit:
    """Translate every harness exception into a clean stderr message + exit code."""
    typer.echo(f"{type(e).__name__}: {e}", err=True)
    return typer.Exit(2)


@app.command("holo3-smoke")
def holo3_smoke(
    image: Annotated[
        Path | None,
        typer.Option(help="Override fixture screenshot. Defaults to a 1024x768 placeholder."),
    ] = None,
    state: Annotated[str, typer.Option(help="expected_state to check")] = "nikonscan-main-window",
) -> None:
    """Round-trip a screenshot through the configured Holo3 endpoint."""
    try:
        settings = load_settings()
    except HilError as e:
        typer.echo(f"config error: {e}", err=True)
        raise typer.Exit(2) from e

    if image is None:
        # Fall back to a tiny solid-grey image so the smoke test runs without a VM.
        img = Image.new("RGB", (1024, 768), color=(192, 192, 192))
    else:
        img = Image.open(image).convert("RGB")

    async def _run() -> None:
        holo3 = Holo3Client(settings.holo3_base_url, settings.holo3_model, settings.holo3_api_key)
        try:
            call = await holo3.oracle(img, state)
            typer.echo(
                json.dumps(
                    {
                        "model_id": call.model_id,
                        "agreed": call.agreed,
                        "reason": call.reason,
                        "latency_ms": round(call.latency_ms, 1),
                    },
                    indent=2,
                )
            )
        finally:
            await holo3.aclose()

    asyncio.run(_run())


@app.command()
def run(name: str) -> None:
    """Execute a recipe end-to-end against the live VM."""
    settings = load_settings()
    recipes = discover()
    if name not in recipes:
        typer.echo(f"unknown recipe {name!r}; have {sorted(recipes)}", err=True)
        raise typer.Exit(2)

    asyncio.run(_run_recipe(settings, recipes[name]()))


async def _run_recipe(settings: Settings, recipe: object) -> None:
    holo3 = Holo3Client(settings.holo3_base_url, settings.holo3_model, settings.holo3_api_key)
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
            result = await runner.run(recipe)  # type: ignore[arg-type]
            typer.echo(
                json.dumps(
                    {
                        "success": result.success,
                        "run_id": result.run_id,
                        "artifacts_dir": result.artifacts_dir,
                        "failure_step": result.failure_step,
                    },
                    indent=2,
                )
            )
            if not result.success:
                sys.exit(1)
    finally:
        await holo3.aclose()
        vnc.disconnect()


@app.command()
def record(name: str, max_frames: int = 200) -> None:
    """Start an interactive recording session for a new recipe."""
    settings = Settings()
    vnc = VncClient(settings.vnc_host, settings.vnc_port, settings.vnc_password)
    vnc.connect()
    try:
        rec = RecipeRecorder(vnc, settings.recordings_dir)
        manifest = asyncio.run(rec.record(name, max_frames=max_frames))
        typer.echo(f"recording manifest: {manifest}")
    finally:
        vnc.disconnect()


@vm_app.command("status")
def vm_status() -> None:
    settings = Settings()
    try:
        with Lifecycle(settings.libvirt_uri, settings.libvirt_domain) as lc:
            status = lc.status()
            typer.echo(
                json.dumps(
                    {
                        "name": status.name,
                        "state": status.state,
                        "qemu_ga_responsive": status.qemu_ga_responsive,
                    },
                    indent=2,
                )
            )
    except HilError as e:
        raise _exit_on_hil_error(e) from e


@vm_app.command("start")
def vm_start() -> None:
    settings = Settings()
    try:
        with Lifecycle(settings.libvirt_uri, settings.libvirt_domain) as lc:
            lc.start()
            lc.wait_ready()
            typer.echo("ready")
    except HilError as e:
        raise _exit_on_hil_error(e) from e


@vm_app.command("shutdown")
def vm_shutdown() -> None:
    settings = Settings()
    try:
        with Lifecycle(settings.libvirt_uri, settings.libvirt_domain) as lc:
            lc.shutdown()
    except HilError as e:
        raise _exit_on_hil_error(e) from e


@vm_app.command("revert")
def vm_revert(snapshot: str | None = None) -> None:
    settings = Settings()
    target = snapshot or settings.libvirt_snapshot
    try:
        with Lifecycle(settings.libvirt_uri, settings.libvirt_domain) as lc:
            lc.revert_snapshot(target)
            typer.echo(f"reverted to {target}")
    except HilError as e:
        raise _exit_on_hil_error(e) from e


if __name__ == "__main__":
    app()
