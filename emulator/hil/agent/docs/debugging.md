# Debugging

Practical guidance for the three classes of failures the harness produces.

## Oracle disagreement (Holo3 says "no")

**Symptom**: `oracle.jsonl` has `agreed=false`; eventually `RecipeAbortedError`
if grounding can't recover.

**Triage**:
1. Open the screenshot at the failing step (`steps/<NNN>-expect_screen.png`).
2. Read the oracle's `reason` field. Holo3 explains what it sees vs what was
   expected.
3. Look at the previous step's screenshot — was it correct? The disagreement
   may be downstream of an earlier wrong click.

**Causes**, in order of likelihood:
- The expected_state name was misleading; rewrite to match what Holo3
  reports it sees.
- A new dialog appeared (driver popup, "register your product"). Bake it
  into the snapshot; rebuild via `re_roll_vm.sh`.
- Holo3 mis-classified the screen (false negative). Check `agreement_rate`
  trend in `metrics.aggregate`; if dropping, see Holo3 model drift below.
- Real emulator regression: scanner UI changed because the emulator now
  reports a different INQUIRY / VPD / mode. Confirm by comparing screenshots
  pre/post the suspect commit.

## Grounding hallucination

**Symptom**: `InvalidGroundingError: action click at (-1, -1) outside frame`
or the recovery click goes somewhere senseless.

**Why**: Holo3 occasionally returns coordinates outside the frame (especially
on dialogs much smaller than the surrounding window). `actions.validate_in_frame`
catches the obvious cases.

**Fix**:
- Verify by reading the frame Holo3 saw and the `instruction` it received
  (logged in the structlog output).
- If Holo3 systematically misses on a particular dialog, note this in the
  recipe — explicit `click_at(x, y)` rather than relying on oracle+grounding
  is the right call there.

## VM hang / crash mid-recipe

**Symptom**: `VmStateError: step ... timed out; VM state=crashed` or `=shutoff`.

**Triage**:
1. Check the emulator log (separate terminal or CI artifact). Did the
   firmware enter an infinite loop / panic?
2. `virsh dumpxml win10-ltsc-nikonscan` — sanity-check the VM's USB
   controller and qemu-ga channel are still wired.
3. `virsh console win10-ltsc-nikonscan` (if serial console is configured)
   for kernel messages.
4. The runner *does* revert to the snapshot before the next run, so a
   single crash doesn't cascade.

## Holo3 endpoint unavailable

**Symptom**: `OracleUnavailableError: Holo3 endpoint failed: ...`.

**Triage**:
1. `uv run coolscan-hil holo3-smoke` — the same client as the runner uses,
   minus the VM.
2. The error message distinguishes connection refused, 401 (token), 403
   (ACL), 503 (overload), and TLS verification failures.
3. If the endpoint is up but slow, check `oracle.jsonl` for `latency_ms`
   p95 — > 2 s is a yellow flag, > 5 s likely means the inference server
   is OOMing or under heavy load.

## pHash baseline drift

**Symptom**: `BaselineMismatchError: pHash distance N > 5`.

**Triage**:
1. Look at the current frame (`steps/<NNN>-expect_screen.png`) and the
   committed baseline (`baselines/<recipe>/<state>.json` records the
   pHash but not the original frame — check the run_id it was promoted
   from).
2. If the change is intentional (e.g., emulator now returns a slightly
   different INQUIRY string that NikonScan renders differently), re-record:
   ```
   record_baseline(recipe, state, new_run_id)
   ```
3. If unintentional, this is a regression — the harness did its job.

## Holo3 model drift

**Symptom**: Suddenly higher disagreement rate across many recipes that
previously passed; no emulator changes.

**Triage**:
1. Compare `manifest.json` `model_id` between green and red runs. If it
   changed (e.g., the user re-deployed Holo3 against a newer revision),
   that's the cause.
2. Workarounds: pin the endpoint to a specific Holo3 revision; or tighten
   prompts (see `holo3.py::ORACLE_SYSTEM_PROMPT`); or add explicit
   `baseline_hash=` to the affected `expect_screen` calls.

## Reading structlog output

Every line in `logs/recipe.jsonl` has `run_id`, the event name, and any
extra fields. Useful greps:

```
jq 'select(.event=="oracle_disagreement")' logs/recipe.jsonl
jq 'select(.event=="post_step_capture_failed")' logs/recipe.jsonl
jq 'select(.latency_ms != null) | {event, latency_ms}' logs/recipe.jsonl
```
