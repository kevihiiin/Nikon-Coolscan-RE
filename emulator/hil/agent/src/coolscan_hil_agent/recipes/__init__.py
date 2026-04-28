"""Recipe definitions.

Each recipe module exposes a `build() -> Recipe` function. The runner
discovers recipes by importing this package and looking for `build`
attributes.
"""

from __future__ import annotations

import importlib
import pkgutil
from collections.abc import Callable

from ..recipe import Recipe


def discover() -> dict[str, Callable[[], Recipe]]:
    """Return {recipe_name: build_callable} for every importable recipe module."""
    out: dict[str, Callable[[], Recipe]] = {}
    for _, modname, _ in pkgutil.iter_modules(__path__):
        mod = importlib.import_module(f"{__name__}.{modname}")
        build = getattr(mod, "build", None)
        if callable(build):
            out[modname] = build
    return out
