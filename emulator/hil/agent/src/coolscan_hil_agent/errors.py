"""Typed exception hierarchy.

Every recipe-runner failure surfaces as a specific subclass so downstream
triage (Claude Code planner, CI artifacts, dashboards) can react without
parsing log strings.
"""

from __future__ import annotations


class HilError(Exception):
    """Base for every harness-raised error."""


class ConfigError(HilError):
    """Missing or invalid env-var / setting at startup."""


class OracleUnavailableError(HilError):
    """Holo3 endpoint unreachable, timed out, or returned non-2xx."""


class InvalidGroundingError(HilError):
    """Holo3 returned coordinates outside the current VNC frame."""


class VmStateError(HilError):
    """VM is in an unexpected state (crashed, paused, missing)."""


class RecipeAbortedError(HilError):
    """Recipe step asked to abort, watchdog fired, or oracle disagreement was unrecoverable."""


class BaselineMismatchError(HilError):
    """Oracle agreed but committed pHash baseline diverged beyond threshold."""
