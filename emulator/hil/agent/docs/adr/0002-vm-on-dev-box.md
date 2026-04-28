# ADR 0002 — VM lives on the dev box, not the GPU box

**Status**: Accepted
**Date**: 2026-04-27

## Context

The HIL stack has three components: (1) the Coolscan emulator, (2) the
Win10 VM running NikonScan, (3) the Holo3 inference endpoint. The dev box
is RAM- and disk-constrained but has KVM and a 240 GB scratch disk; the
GPU box (Tailscale-reachable) has plenty of RAM/disk and a discrete GPU.

The original plan put the VM on the GPU box, alongside Holo3. Two
candidate topologies:

1. **VM on GPU box** — original. USB/IP traffic crosses Tailscale; Holo3
   is local to the VM.
2. **VM on dev box** (chosen) — emulator and VM share loopback; Holo3 is
   the only Tailscale dependency.

## Decision

Put the VM on the dev box. Holo3 stays remote.

## Consequences

The decision turned on **USB/IP latency**, not generic network latency.

A real USB 2.0 SCSI exchange is ~1 ms; the firmware issues many such
exchanges per scan command. With Tailscale RTT typically 10-50 ms, a
600-CDB scan workflow becomes ~6-30 s of pure latency overhead, plus the
risk of NikonScan's per-CDB driver timeouts firing. Loopback is sub-ms.

Holo3 traffic, by contrast, happens at decision points (oracle calls, ~1
per recipe step) rather than inside the SCSI inner loop. ~30 ms of
Tailscale RTT per call is invisible against ~500-1500 ms of inference.

**Pros**:
- USB/IP loopback eliminates the entire latency-sensitive path from the
  network.
- Disk pressure on the dev box's `/` is sidestepped by mounting a
  dedicated 240 GB volume at `/mnt/vmstore`.
- Local VNC means the agent harness has zero network hops to the VM,
  which simplifies recipe debugging.

**Cons**:
- Dev box must run libvirt + qemu-kvm (one apt install).
- Dev box RAM has to budget the VM's 4 GB (still leaves headroom on the
  16 GB host given the emulator is ~500 MB).
- If we ever want to move to a Pi-based real-USB gadget, USB/IP topology
  changes — but that's the point of M14.5: avoid the Pi.

## What flipped

Originally I assumed network calls were fungible — "just put it on
Tailscale". That's true for HTTP RPC but **not** for USB-protocol traffic,
where round-trip count dominates and any added latency multiplies. The user
caught this before plan approval; the topology was reversed in the same
planning round.
