# Agent harness architecture

## What this is

The agent harness drives **NikonScan 4.0.3** in a Windows VM against the
Coolscan emulator and grades each post-action screen against a Holo3
endpoint, with grounding fallback for recovery. It is the M15 milestone's
test driver — repeatable regression instead of manual operator clicks.

Plan reference: `~/.claude/plans/purrfect-sparking-newt.md`.

## Component map

```
                 ┌─────────────────────────────────┐
                 │ Claude Code (Max sub) / pytest  │   planner / scheduler
                 └──────────────┬──────────────────┘
                                │ MCP / direct call
                                ▼
   ┌────────────────────────────────────────────────────────────┐
   │ RecipeRunner (runner.py)                                    │
   │  ─ executes Step list from a Recipe                         │
   │  ─ per-step asyncio.timeout watchdog                        │
   │  ─ writes artifacts/<run-id>/ (manifest, steps/, oracle.jsonl)│
   └─┬─────────────┬────────────────┬──────────────┬─────────────┘
     │ click/type  │ screenshot     │ oracle/ground│ vm_state /
     ▼             ▼                ▼              ▼ file_exists
   ┌──────────┐ ┌────────────┐ ┌─────────────┐ ┌────────────┐
   │ VncClient │ │ VncClient   │ │ Holo3Client │ │ Lifecycle  │
   │ .execute  │ │ .capture    │ │ .oracle()   │ │ (libvirt + │
   │           │ │             │ │ .ground()   │ │  qemu-ga)  │
   └──────┬────┘ └──────┬──────┘ └──────┬──────┘ └─────┬──────┘
          │             │               │              │
        VNC :5900      VNC :5900       HTTPS         libvirt
        (loopback)     (loopback)      (Tailscale)   (qemu:///system)
          │             │               │              │
          ▼             ▼               ▼              ▼
   ┌────────────────────────────────┐ ┌──────────────────┐ ┌──────────────┐
   │ Win10 VM (libvirt domain)      │ │ Holo3 endpoint   │ │ qemu-guest-  │
   │   ├ NikonScan 4.0.3            │ │  (vLLM,          │ │ agent inside │
   │   ├ usbip-win2 client          │ │   user-operated) │ │  the VM      │
   │   └ qemu-ga (virtio-serial)    │ └──────────────────┘ └──────────────┘
   └──────────────┬─────────────────┘
                  │ usbip attach 192.168.122.1:3240 (libvirt NAT gw)
                  ▼
        ┌────────────────────────────┐
        │ coolscan-emu --usbip-server │
        │  (Rust, on the dev box)    │
        └────────────────────────────┘
```

## Per-step flow

For each `Step` in a `Recipe`:

1. **Execute** the step kind:
   - `action`: bounds-check the Pydantic `Action`, then VNC injection
   - `expect_screen`: capture frame, send to Holo3 oracle ("does this match
     the expected_state name?"), optionally compare pHash to a committed
     baseline
   - `wait_for_screen`: poll the oracle every 2 s until agreement or timeout
   - `assert_image_nonblank`: count unique colors via PIL — guards against
     all-black framebuffers
   - `assert_file_exists`: qemu-ga `guest-exec cmd.exe /c if exist <path>`
   - `open_app`: Win+R → type → Enter macro

2. **Capture** post-action screenshot to `artifacts/<run-id>/steps/NNN-<kind>.png`
   (always, even on success — forensic value when triaging later regressions).

3. **Oracle disagreement → grounding fallback**:
   - Up to 3 retries; each retry asks Holo3 `ground(image, recovery_instruction)`
     for one Action, executes it, re-checks the oracle
   - `Done` short-circuits success; `Abort` fails the recipe
   - All grounding calls flagged in `oracle.jsonl` with `fallback_taken=true`

4. **Watchdog**: each step has a 60 s `asyncio.timeout`. On firing, we check
   `lifecycle.status()` — if the VM crashed, `VmStateError`; otherwise
   `RecipeAbortedError`.

5. **Append** an `OracleRecord` to `artifacts/<run-id>/oracle.jsonl` for every
   Holo3 call (oracle and grounding). `metrics.aggregate(...)` reports
   agreement rate over time.

## Why this design

- **Vision-oracle + grounding fallback** balances determinism (scripted clicks
  for the 95 % happy path on a pixel-stable 2003 UI) with resilience (Holo3
  handles the 5 % of unexpected dialogs / driver popups). See ADR 0001.
- **VM is local on the dev box, Holo3 is remote.** USB/IP requires sub-ms
  latency between the firmware and the VM-side `usbip-win2`; Holo3 is
  decision-point traffic and tolerates Tailscale RTT. See ADR 0002.
- **Pydantic discriminated-union Action schema** is enforced by the Holo3
  endpoint via OpenAI `response_format`. No free-text parsing → no surprises.
  See ADR 0004.
- **MCP server (FastMCP)** exposes `run_recipe` / `inspect_screenshot` /
  `record_baseline` / `vm_*` to Claude Code in this terminal. The same
  functions are callable directly from pytest (they're regular Python
  functions; the `@mcp.tool()` decorator just registers them). See ADR 0003.

## Run-id propagation

`structlog`'s contextvars binds `run_id` at the top of `RecipeRunner.run()`
and clears it on exit. Every log record from VNC, Holo3, lifecycle, and the
runner itself includes the same `run_id` — stitching artifacts to logs is
trivial.

## Boundaries

- The harness does **not** start `coolscan-emu` itself. CI's
  `ci_run_recipe.sh` orchestrates the emulator; locally, you run it in a
  separate terminal. This is intentional — the harness is host-agnostic
  and could drive a real LS-50 too.
- The harness does **not** install or update Holo3 / vLLM. The endpoint is
  externally operated; we consume it via `HOLO3_BASE_URL`. See `holo3-endpoint.md`.
- The harness does **not** define libvirt domains or networks. That's
  Phase 1/2 plumbing in the M15 plan, run once.
