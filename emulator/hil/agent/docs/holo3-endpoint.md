# Holo3 endpoint configuration

The Holo3 vLLM service is **operated externally** — the harness consumes it
via three environment variables, fail-fast at startup if missing.

## Required env vars

| Var | Default | Required | Purpose |
|---|---|---|---|
| `HOLO3_BASE_URL` | (none) | yes | OpenAI-compatible base URL, e.g. `https://holo3.your-tailnet.ts.net/v1` |
| `HOLO3_MODEL` | `Hcompany/Holo3-35B-A3B` | no | Model id; matched against `/v1/models` listing |
| `HOLO3_API_KEY` | empty | no | Bearer token; sent as `Authorization: Bearer ...` |

Set in `.env` (gitignored):
```
HOLO3_BASE_URL=https://holo3.example.tailnet.ts.net/v1
HOLO3_API_KEY=sk-test-...
```

## Verify connectivity: `holo3-smoke`

```
uv run coolscan-hil holo3-smoke
```

Sends a 1024×768 grey fixture screenshot with `expected_state=nikonscan-main-window`
and prints the round-trip:

```json
{
  "model_id": "Hcompany/Holo3-35B-A3B",
  "agreed": false,
  "reason": "image is solid grey, not the NikonScan main window",
  "latency_ms": 211.3
}
```

`agreed=false` is fine here — the fixture isn't NikonScan. What we're
checking is that the request round-trips and the response parses to a valid
`OracleResult`.

## Failure-mode triage

| stderr | Cause | Fix |
|---|---|---|
| `config error: HOLO3_BASE_URL is required` | env var unset | edit `.env`, or `export HOLO3_BASE_URL=...` |
| `OracleUnavailableError: Holo3 endpoint failed: connection refused` | unreachable | check the URL, firewall, VPN |
| `OracleUnavailableError: ... 401 Unauthorized` | wrong / missing token | set `HOLO3_API_KEY` |
| `OracleUnavailableError: ... 403 Forbidden` | ACL on the endpoint | endpoint operator action |
| `OracleUnavailableError: ... 503 Service Unavailable` | inference OOM / overload | retry; if persistent, check endpoint logs |
| `OracleUnavailableError: ... certificate verify failed` | TLS cert issue | install the CA chain, or temporarily set `HTTPX_VERIFY=false` (NOT for prod) |
| `OracleUnavailableError: invalid OracleResult` | endpoint returned malformed JSON or unrelated content | check the endpoint is serving the right model + supports `response_format`/structured output |

## What we expect from the endpoint

The harness uses the OpenAI Chat Completions API:

- `POST /v1/chat/completions` with `messages` (system + user with image) and
  `response_format={"type":"json_schema", ...}` enforcing either
  `OracleResult` (`{agreed, reason}`) or `ActionEnvelope` (`{action: ...}`).
- `GET /v1/models` is consulted by `holo3-smoke` to confirm the configured
  `HOLO3_MODEL` is served.

vLLM ≥ 0.6 supports both. Other OpenAI-compatible servers (e.g.,
`text-generation-inference`, `llama.cpp` server) need to support structured
output / JSON-schema response formats — verify with the endpoint operator.

## Latency expectations

| Operation | Expected p95 | Yellow flag |
|---|---|---|
| `oracle()` (single image + short prompt) | < 1 s | > 2 s |
| `ground()` (single image + recovery prompt) | < 2 s | > 5 s |

Aggregated in `metrics.aggregate(...)`. Persistent yellow = endpoint is
under-provisioned or batched too aggressively.

## Switching endpoints

The harness re-reads `HOLO3_BASE_URL` on every CLI invocation. To switch
between, e.g., a local mock and the production endpoint:

```
HOLO3_BASE_URL=http://127.0.0.1:18888/v1 uv run coolscan-hil holo3-smoke   # mock
HOLO3_BASE_URL=https://prod-endpoint/v1  uv run coolscan-hil holo3-smoke   # real
```

The MCP server (`mcp_server.py`) reads `HOLO3_BASE_URL` per tool call too —
update `.mcp.json`'s `env` block (or the shell that launched Claude Code) to
change endpoints for an active session.
