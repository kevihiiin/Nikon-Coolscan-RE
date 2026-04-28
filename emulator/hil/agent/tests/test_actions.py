"""Action schema validation."""

from __future__ import annotations

import pytest

from coolscan_hil_agent.actions import (
    ActionEnvelope,
    Click,
    DoubleClick,
    Type,
    validate_in_frame,
)
from coolscan_hil_agent.errors import InvalidGroundingError


def test_click_parses_from_envelope() -> None:
    env = ActionEnvelope.model_validate({"action": {"type": "click", "x": 100, "y": 200}})
    assert isinstance(env.action, Click)
    assert env.action.x == 100
    assert env.action.button == "left"  # default


def test_envelope_rejects_unknown_type() -> None:
    with pytest.raises(ValueError):
        ActionEnvelope.model_validate({"action": {"type": "tickle", "x": 0, "y": 0}})


def test_validate_in_frame_accepts_in_bounds() -> None:
    validate_in_frame(Click(type="click", x=100, y=200), 1024, 768)


@pytest.mark.parametrize("x,y", [(-1, 0), (0, -1), (1024, 0), (0, 768), (9999, 9999)])
def test_validate_in_frame_rejects_out_of_bounds(x: int, y: int) -> None:
    with pytest.raises(InvalidGroundingError):
        validate_in_frame(Click(type="click", x=x, y=y), 1024, 768)


def test_validate_in_frame_rejects_double_click_too() -> None:
    with pytest.raises(InvalidGroundingError):
        validate_in_frame(DoubleClick(type="double_click", x=-5, y=0), 1024, 768)


def test_validate_in_frame_ignores_non_coordinate_actions() -> None:
    # Type, Key, Scroll, Wait, Done, Abort don't carry coordinates; should pass.
    validate_in_frame(Type(type="type", text="hello"), 1024, 768)


def test_scroll_amount_bounds() -> None:
    from coolscan_hil_agent.actions import Scroll

    Scroll(type="scroll", direction="up", amount=1)
    with pytest.raises(ValueError):
        Scroll(type="scroll", direction="up", amount=0)
    with pytest.raises(ValueError):
        Scroll(type="scroll", direction="up", amount=21)
