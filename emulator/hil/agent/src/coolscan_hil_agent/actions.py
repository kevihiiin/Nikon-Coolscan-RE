"""Action schema — discriminated union forced on the Holo3 endpoint via
OpenAI-compatible `response_format={"type":"json_schema", ...}`.

Out-of-bounds coordinates are caught before VNC injection (see `validate_in_frame`).
"""

from __future__ import annotations

from typing import Annotated, Literal

from pydantic import BaseModel, Field

from .errors import InvalidGroundingError


class Click(BaseModel):
    type: Literal["click"]
    x: int
    y: int
    button: Literal["left", "right", "middle"] = "left"


class DoubleClick(BaseModel):
    type: Literal["double_click"]
    x: int
    y: int


class Type(BaseModel):
    type: Literal["type"]
    text: str


class Key(BaseModel):
    type: Literal["key"]
    key: str  # vncdotool key name, e.g. "Return", "Escape", "Tab"


class Scroll(BaseModel):
    type: Literal["scroll"]
    direction: Literal["up", "down"]
    amount: int = Field(gt=0, le=20)


class Wait(BaseModel):
    type: Literal["wait"]
    ms: int = Field(ge=0, le=120_000)


class Done(BaseModel):
    type: Literal["done"]
    reason: str


class Abort(BaseModel):
    type: Literal["abort"]
    reason: str


Action = Annotated[
    Click | DoubleClick | Type | Key | Scroll | Wait | Done | Abort,
    Field(discriminator="type"),
]


class ActionEnvelope(BaseModel):
    """Wrapper Holo3 emits via `response_format`. The wrapper is needed because
    OpenAI's structured-output requires an object root, not a discriminated union root.
    """

    action: Action


def validate_in_frame(action: Action, width: int, height: int) -> None:
    """Reject (x, y) coordinates outside the current VNC frame.

    Holo3 occasionally hallucinates coordinates outside the screenshot's
    bounds (especially on small dialogs). Catching this before VNC saves us
    from injecting clicks at e.g. (-1, -1) which vncdotool turns into a
    crash on some servers.
    """
    if isinstance(action, Click | DoubleClick) and not (
        0 <= action.x < width and 0 <= action.y < height
    ):
        raise InvalidGroundingError(
            f"action {action.type} at ({action.x}, {action.y}) outside frame {width}x{height}"
        )
