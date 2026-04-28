"""Holo3Client: mock vLLM via respx; verify oracle / ground roundtrips."""

from __future__ import annotations

import json

import httpx
import pytest
import respx
from PIL import Image

from coolscan_hil_agent.actions import Click
from coolscan_hil_agent.errors import OracleUnavailableError
from coolscan_hil_agent.holo3 import Holo3Client


def _completion(content: dict[str, object]) -> dict[str, object]:
    return {
        "id": "cmpl-test",
        "object": "chat.completion",
        "created": 0,
        "model": "test-holo3",
        "choices": [
            {
                "index": 0,
                "message": {"role": "assistant", "content": json.dumps(content)},
                "finish_reason": "stop",
            }
        ],
    }


@pytest.mark.asyncio
async def test_oracle_roundtrip() -> None:
    img = Image.new("RGB", (32, 32))
    client = Holo3Client("https://endpoint.test/v1", "test-holo3", "key")
    try:
        with respx.mock(base_url="https://endpoint.test/v1") as router:
            router.post("/chat/completions").respond(
                json=_completion({"agreed": True, "reason": "looks right"})
            )
            call = await client.oracle(img, "main-window")
        assert call.agreed is True
        assert call.reason == "looks right"
        assert call.model_id == "test-holo3"
        assert call.latency_ms >= 0
    finally:
        await client.aclose()


@pytest.mark.asyncio
async def test_grounding_returns_action() -> None:
    img = Image.new("RGB", (32, 32))
    client = Holo3Client("https://endpoint.test/v1", "test-holo3")
    try:
        with respx.mock(base_url="https://endpoint.test/v1") as router:
            router.post("/chat/completions").respond(
                json=_completion({"action": {"type": "click", "x": 100, "y": 200}})
            )
            call = await client.ground(img, "click the Scan button")
        assert isinstance(call.action, Click)
        assert call.action.x == 100
    finally:
        await client.aclose()


@pytest.mark.asyncio
async def test_oracle_translates_5xx_to_oracle_unavailable() -> None:
    img = Image.new("RGB", (32, 32))
    client = Holo3Client("https://endpoint.test/v1", "test-holo3")
    try:
        with respx.mock(base_url="https://endpoint.test/v1") as router:
            router.post("/chat/completions").respond(503)
            with pytest.raises(OracleUnavailableError):
                await client.oracle(img, "anything")
    finally:
        await client.aclose()


@pytest.mark.asyncio
async def test_oracle_translates_invalid_json_to_oracle_unavailable() -> None:
    img = Image.new("RGB", (32, 32))
    client = Holo3Client("https://endpoint.test/v1", "test-holo3")
    try:
        with respx.mock(base_url="https://endpoint.test/v1") as router:
            # content is not a valid OracleResult — missing `agreed`
            router.post("/chat/completions").respond(json=_completion({"reason": "no agreed key"}))
            with pytest.raises(OracleUnavailableError):
                await client.oracle(img, "anything")
    finally:
        await client.aclose()


@pytest.mark.asyncio
async def test_oracle_connection_refused_translates() -> None:
    img = Image.new("RGB", (32, 32))
    client = Holo3Client("https://endpoint.test/v1", "test-holo3")
    try:
        with respx.mock(base_url="https://endpoint.test/v1") as router:
            router.post("/chat/completions").mock(side_effect=httpx.ConnectError("refused"))
            with pytest.raises(OracleUnavailableError):
                await client.oracle(img, "anything")
    finally:
        await client.aclose()
