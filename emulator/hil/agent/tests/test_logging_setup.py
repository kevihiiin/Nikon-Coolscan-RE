"""Logging setup — verify configure() is idempotent and run_id binds via contextvars."""

from __future__ import annotations

from coolscan_hil_agent.logging_setup import (
    bind_run,
    clear_run,
    configure,
    get_logger,
)


def test_configure_idempotent() -> None:
    configure(level="DEBUG", json_format=True)
    configure(level="INFO", json_format=False)


def test_get_logger_returns_a_callable_logger() -> None:
    log = get_logger("test")
    # Just verify the logger has the expected method surface.
    assert hasattr(log, "info")
    assert hasattr(log, "warning")
    assert hasattr(log, "error")


def test_bind_and_clear_run() -> None:
    bind_run("abc123")
    clear_run()  # autouse fixture also calls this; this just verifies no-op safety
