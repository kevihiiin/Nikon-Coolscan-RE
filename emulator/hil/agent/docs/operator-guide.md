# Operator guide

Day-to-day: bring up HIL, run a recipe, read artifacts, triage failures.

## One-time setup

1. Mount the VM disk (already done if you're reading this from the dev box):
   ```
   /mnt/vmstore  ← 240 GB XFS, in /etc/fstab
   ```
2. Add yourself to libvirt + kvm groups, then **fully log out** and back in:
   ```
   sudo usermod -aG libvirt,kvm $USER
   ```
3. Define the libvirt default network (one-time):
   ```
   sudo virsh -c qemu:///system net-define /usr/share/libvirt/networks/default.xml
   sudo virsh -c qemu:///system net-autostart default
   sudo virsh -c qemu:///system net-start default
   ```
4. Define the `vmstore` storage pool:
   ```
   sudo virsh -c qemu:///system pool-define-as vmstore dir --target /mnt/vmstore/libvirt-images
   sudo virsh -c qemu:///system pool-autostart vmstore
   sudo virsh -c qemu:///system pool-start vmstore
   ```
5. Build the Win10 VM and snapshot it as `nikonscan-installed` (see `vm-setup.md`).
6. Configure the agent's environment:
   ```
   cd emulator/hil/agent
   cp .env.example .env
   # edit .env: HOLO3_BASE_URL, HOLO3_API_KEY (when endpoint is provisioned)
   uv sync --extra dev --extra vm
   ```

## Run a recipe (manual)

In one terminal:
```
cd emulator
cargo run --release -- --usbip-server --usbip-bind 127.0.0.1 --firmware-dispatch
```

In another terminal:
```
cd emulator/hil/agent
uv run coolscan-hil vm revert    # restore baseline snapshot
uv run coolscan-hil vm start     # waits for qemu-ga
uv run coolscan-hil run inquiry_smoke
uv run coolscan-hil vm shutdown
```

## Interpreting `RecipeResult`

```
{
  "success": true,
  "run_id": "a185e7866c49483385385dadb9d9fb60",
  "artifacts_dir": "/.../artifacts/a185e786...",
  "failure_step": null
}
```

Open `artifacts/<run-id>/`:
- `manifest.json` — recipe name, run_id, started_at, model_id used by Holo3
- `steps/000-action.png`, `001-expect_screen.png`, ... — one PNG per step
- `oracle.jsonl` — one line per Holo3 call (oracle or grounding)
- `logs/recipe.jsonl` — structlog JSON output bound to this run_id

## When a recipe fails

1. **Find the failing step**: `failure_step` index in the result.
2. **Read the screenshot**: `artifacts/<run-id>/steps/<NNN>-<kind>.png` —
   the frame we saw at the moment of failure.
3. **Read the oracle reasoning**: in `oracle.jsonl`, search for `agreed=false`
   records. The `reason` field is Holo3's natural-language explanation.
4. **Grounding fallback artifacts**: any `fallback_taken=true` records show
   what Holo3 tried to do to recover.
5. **VM-side logs**: if the failure mentions VM state, check `virsh dumpxml`
   and the emulator log (separate terminal).

## Common failure modes

| Symptom | Likely cause | Fix |
|---|---|---|
| `OracleUnavailableError` | Holo3 endpoint unreachable / 5xx | Check `HOLO3_BASE_URL`; run `coolscan-hil holo3-smoke` |
| `VmStateError: domain ... not found` | wrong `LIBVIRT_DOMAIN` | check `.env`; `virsh list --all` |
| `VmStateError: ... outside a 'with' block` | bug — file an issue | n/a |
| `BaselineMismatchError: pHash distance N > 5` | UI changed visibly; could be a real regression OR a baseline that's drifted | inspect screenshot; if intentional, re-record baseline via `record_baseline(...)` |
| `RecipeAbortedError: oracle disagreement ... could not be recovered` | Holo3 grounding can't fix it | manual investigation; consider recording a new recipe step or fixing the underlying state |
| `assert_image_nonblank: only 1 unique colors` | scan returned a black frame | scan pipeline regression in the emulator; check `--firmware-dispatch` flag, ASIC state |

## Aggregating oracle-agreement stats over time

```
uv run coolscan-hil-agent <future CLI>  # aggregate_oracle_stats not yet wired into typer CLI
# or directly:
uv run python -c "
from pathlib import Path
from coolscan_hil_agent.metrics import aggregate
print(aggregate(Path('artifacts/<run-id>/oracle.jsonl')))
"
```

`agreement_rate` should track close to 1.0 on a stable build. Drops below
0.95 over a week of runs typically mean either (a) Holo3 model has been
re-deployed with a behavior shift, or (b) a real regression has crept in.
The `manifest.json`'s `model_id` distinguishes (a) from (b).
