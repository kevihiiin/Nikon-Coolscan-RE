# ADR 0003 — FastMCP for the MCP server (not the official `mcp` SDK)

**Status**: Accepted
**Date**: 2026-04-27

## Context

The agent harness exposes tools to Claude Code (Max sub) via the Model
Context Protocol. Two Python implementations:

- **Official `mcp` SDK** (https://github.com/modelcontextprotocol/python-sdk),
  PyPI `mcp`. Anthropic-maintained, low-level, spec-compliant.
- **FastMCP** (https://github.com/jlowin/fastmcp), PyPI `fastmcp`.
  Community-favored, Flask/FastAPI-style decorators, ~5× less boilerplate
  for the common stdio-server case.

## Decision

FastMCP, registered via `.mcp.json` at the repo root with stdio transport.

```python
mcp = FastMCP("coolscan-hil-agent")

@mcp.tool()
async def run_recipe(name: str) -> dict[str, object]: ...
```

## Consequences

**Pros**:
- Each tool is a plain async/sync function. No protocol scaffolding visible
  in our code. New tools are one decorator + one function body.
- The decorator returns the underlying function unchanged — tools are
  directly callable from pytest (proven in `tests/test_mcp_server.py`)
  without going through MCP at all.
- Claude Code MCP docs (`code.claude.com/docs/en/mcp.md`) confirm FastMCP
  is a supported pattern for stdio servers.

**Cons**:
- Dependency on a community-maintained library. If FastMCP becomes
  unmaintained, migrating to the official SDK is a ~1-day refactor: the
  tool-function bodies don't change, only the registration boilerplate.
- FastMCP's surface is larger than we use (it supports HTTP transport,
  resources, prompts, etc.). We only use `@mcp.tool()` + `mcp.run()`.

## Migration plan if needed

The official SDK's tool registration is a small wrapper around its
`Server` class. Replace `mcp = FastMCP(...)` and `@mcp.tool()` with the
SDK's equivalents; the function bodies are unchanged. Estimated effort: a
few hours plus tests-pass verification.
