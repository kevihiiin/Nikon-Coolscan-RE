"""Structlog configuration. JSON output, run_id propagated via contextvars."""

from __future__ import annotations

import logging
import sys
from typing import Any

import structlog
from structlog.contextvars import bind_contextvars, clear_contextvars, merge_contextvars


def configure(level: str = "INFO", json_format: bool = True) -> None:
    """Idempotent structlog setup. Call once at program start."""
    logging.basicConfig(
        format="%(message)s",
        stream=sys.stderr,
        level=level.upper(),
    )

    processors: list[Any] = [
        merge_contextvars,
        structlog.processors.add_log_level,
        structlog.processors.TimeStamper(fmt="iso", utc=True),
        structlog.processors.StackInfoRenderer(),
        structlog.processors.format_exc_info,
    ]
    if json_format:
        processors.append(structlog.processors.JSONRenderer())
    else:
        processors.append(structlog.dev.ConsoleRenderer(colors=True))

    structlog.configure(
        processors=processors,
        wrapper_class=structlog.make_filtering_bound_logger(logging.getLevelName(level.upper())),
        context_class=dict,
        logger_factory=structlog.PrintLoggerFactory(file=sys.stderr),
        cache_logger_on_first_use=True,
    )


def bind_run(run_id: str) -> None:
    bind_contextvars(run_id=run_id)


def clear_run() -> None:
    clear_contextvars()


def get_logger(name: str) -> Any:
    """Return a structlog bound logger.

    Typed as `Any` because structlog's runtime logger class depends on the
    `wrapper_class` we configured, which mypy can't infer.
    """
    return structlog.get_logger(name)
