"""Holo3 endpoint client.

Two operations:
- `oracle(image, expected_state)` → bool + reasoning. Used after every scripted
  action to grade whether the VM screen matches the expected state.
- `ground(image, instruction)` → `Action`. Used as fallback when the oracle
  disagrees, to either recover or `Abort`.

Both use the OpenAI-compatible chat completions endpoint with structured
output. The endpoint URL, model, and optional bearer token come from
`Settings`. Single-flight is enforced by the runner, not here.
"""

from __future__ import annotations

import base64
import io
import time
from dataclasses import dataclass
from typing import Any

from openai import APIConnectionError, APIStatusError, AsyncOpenAI
from PIL import Image
from pydantic import BaseModel, ValidationError

from .actions import Action, ActionEnvelope
from .errors import OracleUnavailableError
from .logging_setup import get_logger

log = get_logger(__name__)


ORACLE_SYSTEM_PROMPT = """\
You are a UI test oracle for the Nikon Scan 4.0.3 application running in a Windows 10 VM.
You are given a screenshot of the VM and an expected_state name describing what the screen
should look like.

Respond with a JSON object: {"agreed": true, "reason": "..."} if the screenshot matches the
expected state, or {"agreed": false, "reason": "..."} otherwise. Be strict: subtle dialogs,
unexpected popups, or "scanner not found" overlays count as disagreement even if the
underlying NikonScan window looks fine.
"""

GROUNDING_SYSTEM_PROMPT = """\
You are a UI agent driving Nikon Scan 4.0.3 in a Windows 10 VM. Given a screenshot and
a recovery instruction (because a scripted step failed), output exactly one Action that
will either advance the workflow or abort with a clear reason. Coordinates must be within
the screenshot bounds.
"""


class OracleResult(BaseModel):
    agreed: bool
    reason: str


@dataclass(slots=True)
class OracleCall:
    agreed: bool
    reason: str
    latency_ms: float
    model_id: str


@dataclass(slots=True)
class GroundingCall:
    action: Action
    latency_ms: float
    model_id: str


class Holo3Client:
    """Async client. Construct once per process; reuse across recipe steps."""

    def __init__(
        self,
        base_url: str,
        model: str,
        api_key: str = "",
        connect_timeout_s: float = 30.0,
        read_timeout_s: float = 60.0,
    ) -> None:
        # OpenAI SDK requires *some* string for api_key even if the endpoint
        # doesn't enforce auth.
        self._client = AsyncOpenAI(
            base_url=base_url,
            api_key=api_key or "unused",
            timeout=read_timeout_s,
            max_retries=0,  # we own retry policy
        )
        self._model = model
        self._connect_timeout_s = connect_timeout_s
        self._read_timeout_s = read_timeout_s

    @property
    def model_id(self) -> str:
        return self._model

    async def oracle(self, image: Image.Image, expected_state: str) -> OracleCall:
        """Ask Holo3 whether the screenshot matches `expected_state`."""
        # OpenAI SDK message types are TypedDicts; building them as plain dicts
        # is correct at runtime but mypy can't verify the structure. Annotate
        # as `list[Any]` so the SDK's overload set still accepts the call.
        messages: list[Any] = [
            {"role": "system", "content": ORACLE_SYSTEM_PROMPT},
            {
                "role": "user",
                "content": [
                    _image_part(image),
                    {"type": "text", "text": f"expected_state={expected_state}"},
                ],
            },
        ]
        response_format: Any = {
            "type": "json_schema",
            "json_schema": {
                "name": "OracleResult",
                "schema": OracleResult.model_json_schema(),
                "strict": True,
            },
        }

        t0 = time.perf_counter()
        try:
            resp = await self._client.chat.completions.create(
                model=self._model,
                messages=messages,
                response_format=response_format,
            )
        except (APIConnectionError, APIStatusError) as e:
            raise OracleUnavailableError(f"Holo3 endpoint failed: {e}") from e
        latency_ms = (time.perf_counter() - t0) * 1000

        content = resp.choices[0].message.content or ""
        try:
            parsed = OracleResult.model_validate_json(content)
        except ValidationError as e:
            raise OracleUnavailableError(f"Holo3 returned invalid OracleResult: {e}") from e
        return OracleCall(
            agreed=parsed.agreed,
            reason=parsed.reason,
            latency_ms=latency_ms,
            model_id=resp.model,
        )

    async def ground(self, image: Image.Image, instruction: str) -> GroundingCall:
        """Ask Holo3 for the next `Action` given the current screenshot."""
        messages: list[Any] = [
            {"role": "system", "content": GROUNDING_SYSTEM_PROMPT},
            {
                "role": "user",
                "content": [
                    _image_part(image),
                    {"type": "text", "text": instruction},
                ],
            },
        ]
        response_format: Any = {
            "type": "json_schema",
            "json_schema": {
                "name": "ActionEnvelope",
                "schema": ActionEnvelope.model_json_schema(),
                "strict": True,
            },
        }

        t0 = time.perf_counter()
        try:
            resp = await self._client.chat.completions.create(
                model=self._model,
                messages=messages,
                response_format=response_format,
            )
        except (APIConnectionError, APIStatusError) as e:
            raise OracleUnavailableError(f"Holo3 endpoint failed: {e}") from e
        latency_ms = (time.perf_counter() - t0) * 1000

        content = resp.choices[0].message.content or ""
        try:
            envelope = ActionEnvelope.model_validate_json(content)
        except ValidationError as e:
            raise OracleUnavailableError(f"Holo3 returned invalid Action: {e}") from e
        return GroundingCall(action=envelope.action, latency_ms=latency_ms, model_id=resp.model)

    async def aclose(self) -> None:
        await self._client.close()


def _image_part(image: Image.Image) -> dict[str, object]:
    buf = io.BytesIO()
    image.save(buf, format="PNG")
    encoded = base64.b64encode(buf.getvalue()).decode("ascii")
    return {
        "type": "image_url",
        "image_url": {"url": f"data:image/png;base64,{encoded}"},
    }
