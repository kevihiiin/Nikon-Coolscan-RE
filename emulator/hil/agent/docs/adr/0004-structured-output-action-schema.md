# ADR 0004 — Pydantic discriminated-union Action schema, enforced via OpenAI structured output

**Status**: Accepted
**Date**: 2026-04-27

## Context

Holo3 grounding returns "do this next action" given a screenshot and an
instruction. Three candidate output formats:

1. **Free text**: "click(420, 560)". Parser extracts coordinates with
   regex.
2. **Free-form JSON**: model emits `{"action":"click","x":420,"y":560}`.
   Parser hopes for the best.
3. **Schema-enforced JSON** (chosen): model is forced to emit JSON matching
   a Pydantic schema we define, via OpenAI Chat Completions'
   `response_format={"type":"json_schema", ...}`.

## Decision

Define `Action` as a Pydantic discriminated union and pass its JSON Schema
as `response_format`. vLLM serves Holo3 with this enforcement out of the
box.

```python
class Click(BaseModel):
    type: Literal["click"]; x: int; y: int; button: Literal["left","right","middle"] = "left"
class DoubleClick(BaseModel): type: Literal["double_click"]; x: int; y: int
# ... Type, Key, Scroll, Wait, Done, Abort

Action = Annotated[
    Click | DoubleClick | Type | Key | Scroll | Wait | Done | Abort,
    Field(discriminator="type"),
]

class ActionEnvelope(BaseModel):
    action: Action
```

## Consequences

**Pros**:
- The model **cannot** return malformed actions. The runner gets a typed
  `Action` instance, not a string to parse.
- New actions are added by appending to the union — schema and parser
  update together.
- Out-of-bounds coordinates are still our responsibility (caught by
  `validate_in_frame` before VNC injection); but the *shape* of the
  output is guaranteed.
- The same schema can be passed to non-Holo3 endpoints if we ever swap
  models — every OpenAI-compatible server with structured output (vLLM,
  TGI, llama.cpp ≥ recent, etc.) understands the JSON Schema.

**Cons**:
- Wrapped in `ActionEnvelope` because OpenAI's structured output requires
  an object root, not a discriminated union root. Slight ergonomic tax;
  hidden inside `holo3.py`.
- Schema-enforced inference is sometimes slower than free generation
  (model has to backtrack on illegal token sequences). Not measurable in
  our latency budget.
- If the endpoint silently disables structured output (older vLLM, custom
  server), we'd get free-text JSON. `Holo3Client` translates parse
  failures to `OracleUnavailableError` — visible, not silent.

## Why an envelope, not a top-level union

OpenAI's `response_format={"type":"json_schema", ...}` requires the schema
root to be an object. Discriminated unions are object-typed under the
hood, but the JSON Schema spec for `oneOf` at the root upsets some
implementations. The envelope (`{"action": <union>}`) is universally
accepted and adds zero runtime cost.
