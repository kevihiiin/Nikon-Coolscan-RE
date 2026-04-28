"""Exception hierarchy invariants."""

from __future__ import annotations

from coolscan_hil_agent.errors import (
    BaselineMismatchError,
    ConfigError,
    HilError,
    InvalidGroundingError,
    OracleUnavailableError,
    RecipeAbortedError,
    VmStateError,
)


def test_all_errors_subclass_hil_error() -> None:
    for cls in (
        ConfigError,
        OracleUnavailableError,
        InvalidGroundingError,
        VmStateError,
        RecipeAbortedError,
        BaselineMismatchError,
    ):
        assert issubclass(cls, HilError)


def test_hil_error_is_exception() -> None:
    assert issubclass(HilError, Exception)
