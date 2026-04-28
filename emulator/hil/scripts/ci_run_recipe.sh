#!/usr/bin/env bash
# CI orchestration for M15 Tier 2 regression.
#
# Brings up:
#   - coolscan-emu --usbip-server (background)
#   - Win10 VM via libvirt (revert to nikonscan-installed snapshot first)
#   - waits for qemu-guest-agent ping
# Then runs every recipe via pytest, collects artifacts, and tears down.
#
# Triggered by .github/workflows/m15-regression.yml on a self-hosted runner.

set -euo pipefail

# --- paths ---
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
AGENT_DIR="$REPO_ROOT/emulator/hil/agent"
EMULATOR_DIR="$REPO_ROOT/emulator"
ARTIFACTS_DIR="${ARTIFACTS_DIR:-/mnt/vmstore/ci-artifacts}"
mkdir -p "$ARTIFACTS_DIR"

# --- config (env vars override defaults) ---
LIBVIRT_DOMAIN="${LIBVIRT_DOMAIN:-win10-ltsc-nikonscan}"
LIBVIRT_SNAPSHOT="${LIBVIRT_SNAPSHOT:-nikonscan-installed}"
USBIP_BIND="${USBIP_BIND:-127.0.0.1}"

EMU_PID=""
cleanup() {
    local exit_code=$?
    set +e
    echo "[ci_run_recipe] cleanup (exit_code=$exit_code)"
    if [[ -n "$EMU_PID" ]] && kill -0 "$EMU_PID" 2>/dev/null; then
        kill "$EMU_PID" 2>/dev/null
        wait "$EMU_PID" 2>/dev/null
    fi
    if virsh -c qemu:///system list --name | grep -q "^$LIBVIRT_DOMAIN$"; then
        virsh -c qemu:///system shutdown "$LIBVIRT_DOMAIN" 2>/dev/null || true
        # Give it 60 s, then destroy.
        for _ in $(seq 1 60); do
            virsh -c qemu:///system list --name | grep -q "^$LIBVIRT_DOMAIN$" || break
            sleep 1
        done
        virsh -c qemu:///system destroy "$LIBVIRT_DOMAIN" 2>/dev/null || true
    fi
    return $exit_code
}
trap cleanup EXIT INT TERM

# --- 1. Revert VM to baseline snapshot (idempotent) ---
echo "[ci_run_recipe] reverting VM to snapshot $LIBVIRT_SNAPSHOT"
virsh -c qemu:///system snapshot-revert "$LIBVIRT_DOMAIN" "$LIBVIRT_SNAPSHOT"

# --- 2. Start emulator USB/IP server ---
echo "[ci_run_recipe] starting coolscan-emu"
cd "$EMULATOR_DIR"
cargo run --release -- --usbip-server --usbip-bind "$USBIP_BIND" --firmware-dispatch \
    > "$ARTIFACTS_DIR/emulator.log" 2>&1 &
EMU_PID=$!
echo "[ci_run_recipe] emulator PID=$EMU_PID"

# Wait briefly for the USB/IP listener to come up.
for i in $(seq 1 30); do
    if ss -tln | grep -q ":3240 "; then
        echo "[ci_run_recipe] emulator USB/IP listening"
        break
    fi
    sleep 1
done

# --- 3. Start VM and wait for qemu-guest-agent ---
echo "[ci_run_recipe] starting VM"
virsh -c qemu:///system start "$LIBVIRT_DOMAIN"
cd "$AGENT_DIR"
echo "[ci_run_recipe] waiting for qemu-ga"
uv run coolscan-hil vm start  # blocks until qemu-ga responsive

# --- 4. Run recipes ---
echo "[ci_run_recipe] running pytest recipes"
uv run pytest src/coolscan_hil_agent/recipes/ -v

# --- 5. Cleanup happens via trap ---
echo "[ci_run_recipe] all green"
