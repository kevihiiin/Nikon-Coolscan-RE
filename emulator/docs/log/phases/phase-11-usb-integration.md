# Phase 11: Real USB & Integration

**Status**: COMPLETE
**Tests**: 240 (51 e2e + 133 core + 56 peripherals)
**Started**: 2026-03-25
**Completed**: 2026-03-25

---

## Session 1 (2026-03-25): Full Phase 11 Implementation

### Goals
- Implement all Phase 11 sub-tasks (11.1-11.7)
- ISP1581 USB enumeration register support
- Zero-patch mode (--full-usb-init + --firmware-dispatch)
- IRQ1-driven CDB injection path
- Gadget bridge wired to ISP1581 FIFOs
- --emulated-scsi safety net flag
- force_usb_session_state() gated by full_usb_init

### Sub-task Results

**11.1 ISP1581 Enumeration Registers** (+80 lines, +3 tests)
- Added registers: DcHardwareConfiguration (0x16), EndpointMaxPacketSize (0x04),
  Unlock (0x7C), FrameNumber (0x74), EndpointType (0x08 context)
- Added DcInterrupt bits: IRQ_BUS_RESET (bit 6), IRQ_VBUS (bit 0),
  IRQ_SUSPEND (bit 5), IRQ_HIGH_SPEED (bit 8)
- SOFTCT transition detection (0→1) triggers bus reset simulation
- ISP1581 tick() method for deferred state transitions
- MmioDevice::tick() trait method added to h8300h-core
- 3 new unit tests: chip_id, usb_enum_registers, softct_bus_reset

**11.2 Un-NOP USB Init + Zero-Patch Mode** (+30 lines)
- Zero-patch mode: `full_usb_init && firmware_dispatch && !emulated_scsi` → 0 patches
- USB init patches already gated by `full_usb_init` flag
- force_usb_session_state() skipped when full_usb_init is set
- ISP1581 tick wired into check_peripherals() for bus reset delivery

**11.3 CDB via IRQ1** (+20 lines)
- inject_cdb_irq1() method: injects CDB into ISP1581 EP1 OUT FIFO
- host_send_ep1() sets irq_pending → check_peripherals() asserts IRQ1 (Vec 13)
- has_response() and drain_response() methods for polling response
- Firmware ISR at 0x014E00 handles CDB reading in the run() loop

**11.4 Un-NOP All SCSI Handler Patches** (logic only)
- Zero-patch mode skips all 21 SCSI dispatch/handler NOP patches
- firmware_dispatch_scsi() mini-loop handles TRAPA yields
- ISP1581 PIO model (DcInterrupt bits 12+15 always set) supports firmware writes
- No additional code needed — the ISP1581 model provides correct behavior

**11.5 Gadget Bridge Integration** (+40 lines)
- Emulator.gadget field: Option<Box<dyn UsbBridge>>
- setup_gadget() method initializes GadgetBridge
- poll_gadget() in run() loop: gadget.recv_ep1_out() → ISP1581 inject,
  ISP1581 EP2 drain → gadget.send_ep2_in()
- main.rs updated to call setup_gadget() when --gadget flag set
- TCP bridge continues as alternative (parallel operation)

**11.6 --emulated-scsi Flag** (+15 lines)
- New CLI flag --emulated-scsi forces Rust SCSI emulation path
- scsi_command() and scsi_command_out() check `firmware_dispatch && !emulated_scsi`
- Safety net: existing tests all pass with emulated_scsi=true
- Phase query 0xD0 confirmed in firmware dispatch table (handler 0x013748)
- Sense retrieval: firmware uses 0x03 (REQUEST SENSE), not 0x06 (NKDUSCAN-specific)

**11.7 Tests and Documentation** (+140 lines test, +docs)
- 7 new e2e tests:
  - phase11_isp1581_enum_registers: register read/write through memory bus
  - phase11_zero_patch_mode_config: config flag verification + emulated_scsi boot
  - phase11_irq1_cdb_injection: FIFO injection API test
  - phase11_all_21_opcodes_in_dispatch_table: full table verification
  - phase11_gadget_bridge_poll_noop: gadget=None polling safety
  - phase11_emulated_scsi_flag: Rust SCSI via emulated_scsi
  - phase11_full_sequence_firmware_dispatch: TUR→INQUIRY→RESERVE→SENSE→RELEASE

### Issues Encountered

1. **SCSI patches prematurely un-NOPed**: First attempt skipped SCSI patches
   when `firmware_dispatch && !emulated_scsi`. This broke existing tests because
   the firmware's response manager calls need PIO handshake that only works in
   the mini-loop (not the run loop). Fixed: SCSI patches only skipped in true
   zero-patch mode (full_usb_init + firmware_dispatch + !emulated_scsi).

2. **ISP1581 SOFTCT initialization**: Constructor sets mode=0x0010 directly
   (not through write_word), so SOFTCT transition detection doesn't fire at
   init. This is correct — we don't want a bus reset on construction.

### Metrics
- Lines changed: ~250 net (+300, -50 cleanup)
- Tests added: 7 e2e + 3 ISP1581 unit = 10 total
- Total tests: 240 (was 230)
- Clippy: 0 warnings
- All 230 existing tests still pass
