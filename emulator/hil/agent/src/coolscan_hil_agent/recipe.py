"""Recipe DSL.

A `Recipe` is a sequence of `Step`s built via a fluent chain. Each step is
a value the runner inspects and executes. No hidden contextvars / globals;
recipes are testable by introspecting `Recipe.steps` directly.

```python
def build() -> Recipe:
    return (
        Recipe("preview_scan")
        .open_app("NikonScan.exe")
        .expect_screen("nikonscan-main-window")
        .click_at(425, 360)
        .expect_screen("scanner-source-dialog")
        .click_at(380, 510)
        .wait_for_screen("preview-pane-shown", timeout_s=120)
        .assert_image_nonblank()
        .assert_file_exists(r"C:\\scans\\preview*.tiff")
    )
```
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any, Literal

from .actions import Click, DoubleClick, Key, Type, Wait

StepKind = Literal[
    "action",
    "expect_screen",
    "wait_for_screen",
    "assert_image_nonblank",
    "assert_file_exists",
    "open_app",
]


@dataclass(slots=True)
class Step:
    kind: StepKind
    # Heterogeneous payload (Action, str, int, bool, None). `Any` is the right
    # choice here: callers branch on `kind` and downcast.
    payload: dict[str, Any]


@dataclass(slots=True)
class Recipe:
    name: str
    steps: list[Step] = field(default_factory=list)

    # --- VNC actions ---

    def click_at(self, x: int, y: int, *, button: str = "left") -> Recipe:
        self.steps.append(
            Step(
                "action",
                {"action": Click(type="click", x=x, y=y, button=button)},  # type: ignore[arg-type]
            )
        )
        return self

    def double_click_at(self, x: int, y: int) -> Recipe:
        self.steps.append(Step("action", {"action": DoubleClick(type="double_click", x=x, y=y)}))
        return self

    def type_text(self, text: str) -> Recipe:
        self.steps.append(Step("action", {"action": Type(type="type", text=text)}))
        return self

    def key(self, key: str) -> Recipe:
        self.steps.append(Step("action", {"action": Key(type="key", key=key)}))
        return self

    def wait_ms(self, ms: int) -> Recipe:
        self.steps.append(Step("action", {"action": Wait(type="wait", ms=ms)}))
        return self

    # --- High-level helpers ---

    def open_app(self, exe: str) -> Recipe:
        self.steps.append(Step("open_app", {"exe": exe}))
        return self

    # --- Oracle-driven assertions ---

    def expect_screen(self, state: str, *, baseline_hash: str | None = None) -> Recipe:
        self.steps.append(Step("expect_screen", {"state": state, "baseline_hash": baseline_hash}))
        return self

    def wait_for_screen(self, state: str, *, timeout_s: int = 60) -> Recipe:
        self.steps.append(Step("wait_for_screen", {"state": state, "timeout_s": timeout_s}))
        return self

    def assert_image_nonblank(self, *, min_unique_colors: int = 100) -> Recipe:
        self.steps.append(Step("assert_image_nonblank", {"min_unique_colors": min_unique_colors}))
        return self

    def assert_file_exists(self, path: str) -> Recipe:
        self.steps.append(Step("assert_file_exists", {"path": path}))
        return self
