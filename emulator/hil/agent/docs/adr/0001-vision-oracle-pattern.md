# ADR 0001 — Vision oracle + grounding fallback (not pure-LLM-in-loop)

**Status**: Accepted
**Date**: 2026-04-27

## Context

We need to drive NikonScan 4.0.3 in a Win10 VM repeatedly for regression
testing. The UI is pixel-stable (a 2003 Win32 app — it doesn't shift), and
the underlying SCSI/USB protocol can change as the emulator evolves. Three
candidate architectures:

1. **Pure LLM-in-the-loop**: Every action goes through Holo3 (or a more
   capable model). Maximum adaptivity; ~1-3 s of inference per click.
2. **Pure scripted replay**: Deterministic VNC clicks with no model in the
   loop. Fast; brittle to any UI surprise.
3. **Vision oracle + grounding fallback** (chosen): scripted clicks for
   the happy path; Holo3 grades each post-action screen as oracle; if the
   oracle disagrees, escalate to Holo3 grounding for recovery.

## Decision

Adopt the hybrid (#3). NikonScan's UI is stable enough that scripted clicks
are reliable for the 95% case. Robustness comes from grading every screen
and recovering when reality diverges.

## Consequences

**Pros**:
- Fast happy-path execution: 30-step recipe runs in ~30 s of inference
  (oracle calls only) instead of ~1.5-3 minutes (every click via LLM).
- Strong regression detection: every step is vision-validated; the harness
  notices ANY deviation, not just the ones a planner LLM happens to ask
  about.
- Self-healing for novel surprises (driver popups, OS dialogs) without
  hard-coding every workaround.
- Exercises Holo3 in three roles (oracle, grounder, silent passthrough),
  maximizing the user's stated "learn the stack" goal.

**Cons**:
- Two LLM call sites with different prompt requirements (oracle vs
  grounding). More moving parts than #1 or #2.
- Recipe authoring still requires capturing baseline coordinates manually
  (mitigated by `recorder.py` + Holo3-assisted coordinate extraction).
- Harder to reason about test failures: "did the click miss, or did Holo3
  hallucinate the disagreement?" — we mitigate via per-step screenshot
  artifacts and explicit `agreement_rate` tracking.

## Alternatives considered

- **Pure scripted (Sikuli/AutoIt-style)**: Rejected because it gives up the
  vision-grading signal, which is the whole point — we want to know when
  the *underlying scanner state* drifts, not just whether a button click
  reached coordinates.
- **Run-time-recorded baselines**: Tempting (just pHash the first green
  run, replay forever) but offers no semantic validation — "this screen
  looks the same" doesn't mean "this screen is correct". We use pHash as
  an *assist* to the oracle, not a replacement.
