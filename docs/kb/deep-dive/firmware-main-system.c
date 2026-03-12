/*
 * Nikon Coolscan LS-50 Firmware — Main System Pseudocode
 * ======================================================
 *
 * CPU:        Hitachi H8/3003 (H8/300H, 24-bit addresses, big-endian)
 * Flash:      MBM29F400B, 512KB (0x000000-0x07FFFF)
 * Firmware:   "Nikon LS-50 MBM29F400B TSOP48.bin"
 *
 * This file is a readable C pseudocode reconstruction of the scanner's
 * "operating system": boot, coroutine scheduler, task dispatcher, SCSI
 * command processing, scan state machine, and USB communication layer.
 *
 * All addresses are from the flash/memory map. Handler addresses are
 * firmware (FW:0xXXXXX) or hardware (H8 I/O at 0xFFFFxx).
 *
 * Source: reverse-engineered from binary disassembly (Ghidra H8/300H SLEIGH,
 *         radare2 h8300 arch, raw hex analysis).  Cross-validated against
 *         host-side Windows drivers (Phase 1-3, 5-7).
 *
 * Status:     Complete reconstruction
 * Confidence: High / Verified
 */

#include <stdint.h>
#include <stdbool.h>

/* =====================================================================
 * PART 0 — MEMORY MAP
 * ===================================================================== */

/*
 * Physical memory regions as configured by the Bus State Controller (BSC)
 * and the I/O init table.
 *
 * Flash        0x000000 - 0x07FFFF   512KB  Firmware + data
 * ASIC regs    0x200000 - 0x200FFF    4KB   Custom scanner ASIC
 * External RAM 0x400000 - 0x41FFFF  128KB   Main working RAM
 * ISP1581 USB  0x600000 - 0x6000FF   256B   Philips ISP1581 USB 2.0 controller
 * ASIC RAM     0x800000 - 0x837FFF  224KB   CCD line / scan data buffer
 * Buffer RAM   0xC00000 - 0xC0FFFF   64KB   USB staging buffer
 * On-chip RAM  0xFFFD00 - 0xFFFF1F   544B   H8/3003 internal (trampolines here)
 * I/O regs     0xFFFF20 - 0xFFFFFF   224B   H8/3003 peripheral registers
 *
 * Flash is mapped at BOTH low addresses (for vector table boot) and
 * 0x000000+ (direct). The BSC registers (ABWCR, CSCR, WCR) configure this.
 */


/* =====================================================================
 * PART 1 — HARDWARE REGISTER AND RAM VARIABLE DEFINITIONS
 * ===================================================================== */

/* --- H8/3003 CPU registers (memory-mapped I/O) --- */

#define WDT_TCSR       (*(volatile uint16_t *)0xFFFFA8)  /* Watchdog timer */
#define CCR            /* CPU condition code register — accessed via LDC/STC */

/* Port registers */
#define P1DDR          (*(volatile uint8_t  *)0xFFFFD4)  /* Port 1 data direction */
#define P2DDR          (*(volatile uint8_t  *)0xFFFFD5)  /* Port 2 data direction */
#define P3DDR          (*(volatile uint8_t  *)0xFFFFD6)  /* Port 3 data direction */
#define P4DDR          (*(volatile uint8_t  *)0xFFFF85)  /* Port 4 DDR (lamp control) */
#define PORTA_DR       (*(volatile uint8_t  *)0xFFFFA3)  /* Port A data (motor phases) */
#define PORT7_DR       (*(volatile uint8_t  *)0xFFFF8E)  /* Port 7 data (adapter ID) */
#define PORT9_DR       (*(volatile uint8_t  *)0xFFFFC8)  /* Port 9 data (encoder/step) */

/* Timer registers */
#define TSTR           (*(volatile uint8_t  *)0xFFFF60)  /* Timer start register */
#define ADCSR          (*(volatile uint8_t  *)0xFFFFE8)  /* A/D control/status */

/* --- ISP1581 USB Controller registers (base 0x600000) --- */

#define ISP_INT_STATUS (*(volatile uint16_t *)0x600008)  /* Interrupt status */
#define ISP_MODE       (*(volatile uint16_t *)0x60000C)  /* Mode register (bit4=SOFTCT) */
#define ISP_DMA_CONFIG (*(volatile uint16_t *)0x600018)  /* DMA configuration */
#define ISP_EP_INDEX   (*(volatile uint16_t *)0x60001C)  /* Endpoint index/count */
#define ISP_EP_DATA    (*(volatile uint16_t *)0x600020)  /* Endpoint data port (R/W) */
#define ISP_EP_CTRL    (*(volatile uint16_t *)0x60002C)  /* Endpoint control */
#define ISP_DMA_COUNT  (*(volatile uint16_t *)0x600084)  /* DMA transfer count */

/* --- Custom Scanner ASIC registers (base 0x200000) --- */

#define ASIC_CMD       (*(volatile uint8_t  *)0x200001)  /* Master enable/reset */
#define ASIC_STATUS    (*(volatile uint8_t  *)0x200002)  /* Status (bit3=DMA busy) */
#define ASIC_DAC_CFG   (*(volatile uint8_t  *)0x2000C0)  /* DAC/ADC master config */
#define ASIC_DAC_CTRL  (*(volatile uint8_t  *)0x2000C1)  /* DAC/ADC control */
#define ASIC_DAC_MODE  (*(volatile uint8_t  *)0x2000C2)  /* DAC mode: 0x20/0x22/0xA2 */
#define ASIC_DAC_FINE  (*(volatile uint8_t  *)0x2000C7)  /* DAC fine: 0x08(LS50)/0x00(LS5000) */
#define ASIC_DMA_BUF_H (*(volatile uint8_t  *)0x200147)  /* DMA buffer addr [23:16] */
#define ASIC_DMA_BUF_M (*(volatile uint8_t  *)0x200148)  /* DMA buffer addr [15:8] */
#define ASIC_DMA_BUF_L (*(volatile uint8_t  *)0x200149)  /* DMA buffer addr [7:0] */
#define ASIC_DMA_CNT_H (*(volatile uint8_t  *)0x20014B)  /* DMA xfer count [23:16] */
#define ASIC_DMA_CNT_M (*(volatile uint8_t  *)0x20014C)  /* DMA xfer count [15:8] */
#define ASIC_DMA_CNT_L (*(volatile uint8_t  *)0x20014D)  /* DMA xfer count [7:0] */
#define ASIC_MOTOR_CFG (*(volatile uint8_t  *)0x200181)  /* Motor drive config */
#define ASIC_LINE_MODE (*(volatile uint8_t  *)0x2001C0)  /* CCD line timing mode */
#define ASIC_LINE_CTRL (*(volatile uint8_t  *)0x2001C1)  /* CCD line timing control */

/* --- RAM variables (external RAM at 0x400000) --- */

/* USB / command state */
#define ram_cmd_pending     (*(volatile uint8_t  *)0x400082)  /* USB cmd pending flag */
#define ram_usb_reset_flag  (*(volatile uint8_t  *)0x400084)  /* USB bus reset flag */
#define ram_usb_reinit_flag (*(volatile uint8_t  *)0x400085)  /* USB re-init needed */
#define ram_error_flag      (*(volatile uint8_t  *)0x400086)  /* Error flag */
#define ram_usb_conn_state  (*(volatile uint8_t  *)0x407DC7)  /* USB session: 2=ready */

/* Task / scan state */
#define ram_task_complete   (*(volatile uint8_t  *)0x400492)  /* Task done flag */
#define ram_task_active     (*(volatile uint8_t  *)0x400493)  /* Task executing flag */
#define ram_usb_txn_active  (*(volatile uint8_t  *)0x40049A)  /* USB transaction active */
#define ram_exec_mode       (*(volatile uint8_t  *)0x40049B)  /* Current SCSI exec mode */
#define ram_xfer_phase      (*(volatile uint8_t  *)0x40049C)  /* USB transfer phase */
#define ram_cmd_ctr         (*(volatile uint8_t  *)0x40049D)  /* Cmd completion counter */

/* Context system */
#define ram_ctx_state       (*(volatile uint16_t *)0x400764)  /* Context switch state */
#define ram_ctx_save        ((volatile uint32_t  *)0x400766)  /* SP save area [2] */
#define ram_boot_flag       (*(volatile uint8_t  *)0x400772)  /* 0=cold, 1=warm */
#define ram_cmd_state       (*(volatile uint8_t  *)0x400773)  /* Command state */
#define ram_motor_mode      (*(volatile uint8_t  *)0x400774)  /* Motor mode for ITU2 ISR */
#define ram_scanner_flags   (*(volatile uint16_t *)0x400776)  /* bit6=abort, bit7=resp */
#define ram_task_code       (*(volatile uint16_t *)0x400778)  /* Current task code */
#define ram_scan_progress   (*(volatile uint16_t *)0x40077A)  /* Scan progress / DMA */
#define ram_scanner_state   (*(volatile uint16_t *)0x40077C)  /* Scanner state machine */
#define ram_task_remaining  (*(volatile uint32_t *)0x40078C)  /* Task remaining work */
#define ram_task_budget     (*(volatile uint32_t *)0x400896)  /* Task time budget */
#define ram_task_budget_sav (*(volatile uint32_t *)0x40089A)  /* Saved initial budget */
#define ram_gpio_shadow     (*(volatile uint8_t  *)0x400791)  /* GPIO shadow register */

/* SCSI */
#define ram_sense_code      (*(volatile uint16_t *)0x4007B0)  /* SCSI sense code */
#define ram_scsi_opcode     (*(volatile uint8_t  *)0x4007B6)  /* Current SCSI opcode */
#define ram_cdb_buffer      ((volatile uint8_t   *)0x4007DE)  /* 16-byte CDB buffer */
#define ram_soft_reset      (*(volatile uint8_t  *)0x400E5F)  /* Soft-reset request */
#define ram_init_result     (*(volatile uint8_t  *)0x400E80)  /* Init result byte */
#define ram_timestamp       (*(volatile uint32_t *)0x40076E)  /* System tick counter */

/* Scan pipeline */
#define ram_dma_burst_ctr   (*(volatile uint8_t  *)0x406374)  /* DMA burst counter */
#define ram_dma_mode        (*(volatile uint8_t  *)0x4052D6)  /* DMA mode byte */
#define ram_scan_status     (*(volatile uint8_t  *)0x4052EE)  /* 3=buffer full */
#define ram_scan_active     (*(volatile uint8_t  *)0x4052F1)  /* Scan in progress */
#define ram_xfer_state      (*(volatile uint8_t  *)0x4062E6)  /* USB xfer in progress */
#define ram_adapter_type    (*(volatile uint8_t  *)0x400F22)  /* Adapter bitmask */

/* Model identification */
#define ram_model_flag      (*(volatile uint8_t  *)0x404E96)  /* 0=LS-50, nonzero=LS-5000 */


/* =====================================================================
 * PART 2 — ENUMERATIONS AND TYPE DEFINITIONS
 * ===================================================================== */

/* --- SCSI Opcodes supported by the firmware (21 total) --- */

typedef enum {
    SCSI_TEST_UNIT_READY  = 0x00,
    SCSI_REQUEST_SENSE    = 0x03,
    SCSI_INQUIRY          = 0x12,
    SCSI_MODE_SELECT      = 0x15,
    SCSI_RESERVE          = 0x16,
    SCSI_RELEASE          = 0x17,
    SCSI_MODE_SENSE       = 0x1A,
    SCSI_SCAN             = 0x1B,
    SCSI_RECV_DIAGNOSTIC  = 0x1C,
    SCSI_SEND_DIAGNOSTIC  = 0x1D,
    SCSI_SET_WINDOW       = 0x24,
    SCSI_GET_WINDOW       = 0x25,
    SCSI_READ_10          = 0x28,
    SCSI_SEND_10          = 0x2A,
    SCSI_WRITE_BUFFER     = 0x3B,
    SCSI_READ_BUFFER      = 0x3C,
    SCSI_VENDOR_C0        = 0xC0,   /* Status Query */
    SCSI_VENDOR_C1        = 0xC1,   /* Trigger Action */
    SCSI_VENDOR_D0        = 0xD0,   /* Phase Query (transport layer) */
    SCSI_VENDOR_E0        = 0xE0,   /* Data Out (register write) */
    SCSI_VENDOR_E1        = 0xE1,   /* Data In  (register read) */
} scsi_opcode_t;

/* --- SCSI execution modes (byte at SCSI table offset +8) --- */

typedef enum {
    EXEC_DIRECT      = 0x00,  /* Handler manages own transfer (SCAN uses this) */
    EXEC_USB_SETUP   = 0x01,  /* Calls usb_state_setup() before handler */
    EXEC_DATA_OUT    = 0x02,  /* Host sends data to device */
    EXEC_DATA_IN     = 0x03,  /* Device sends data to host */
} exec_mode_t;

/* --- Scanner state machine states (ram_scanner_state low byte) --- */

typedef enum {
    STATE_IDLE          = 0x00,
    STATE_ACTIVE_SCAN   = 0x01,
    STATE_SETUP_20      = 0x20,   /* 0x20-0x2F: setup phase */
    STATE_EJECTING      = 0x80,
    STATE_SENSOR_ERROR  = 0xF0,
    STATE_MOTOR_ERROR   = 0xF1,
    STATE_ACTIVE_SCAN2  = 0xF2,   /* Alternative active scan */
    STATE_MOTOR_BUSY    = 0xF3,
    STATE_CAL_BUSY      = 0xF4,
} scanner_state_t;

/* --- Internal sense codes (ram_sense_code) --- */

typedef enum {
    SENSE_NONE              = 0x0000,
    SENSE_BECOMING_READY    = 0x0007,  /* SK=02 ASC/ASCQ=04/01 */
    SENSE_BECOMING_READY_USB= 0x0008,  /* SK=02 ASC/ASCQ=04/01 FRU=01 */
    SENSE_BECOMING_READY_ENC= 0x0009,  /* SK=02 ASC/ASCQ=04/01 FRU=02 */
    SENSE_INIT_REQUIRED     = 0x000A,  /* SK=02 ASC/ASCQ=04/02 */
    SENSE_EJECTING          = 0x000D,  /* SK=02 ASC/ASCQ=05/00 */
    SENSE_INVALID_CDB       = 0x0050,  /* SK=05 ASC/ASCQ=24/00 */
    SENSE_INVALID_PARAM     = 0x0053,  /* SK=05 ASC/ASCQ=26/00 */
    SENSE_SAVING_UNSUPPORTED= 0x0059,  /* SK=05 ASC/ASCQ=39/00 */
    SENSE_USB_COMM_ERROR    = 0x0061,
    SENSE_SCAN_TIMEOUT      = 0x0071,  /* SK=02 ASC/ASCQ=04/02 */
    SENSE_MOTOR_BUSY        = 0x0079,  /* SK=02 ASC/ASCQ=04/01 FRU=03 */
    SENSE_CAL_IN_PROGRESS   = 0x007A,  /* SK=02 ASC/ASCQ=04/01 FRU=04 */
} sense_code_t;

/* --- Motor modes (ram_motor_mode, dispatched by ITU2 ISR) --- */

typedef enum {
    MOTOR_MODE_SCAN     = 2,   /* Scan motor step */
    MOTOR_MODE_AF       = 3,   /* AF motor step */
    MOTOR_MODE_ENCODER  = 4,   /* Encoder/special processing */
    MOTOR_MODE_SCAN_REV = 6,   /* Scan motor reverse direction */
} motor_mode_t;

/* --- Adapter types (ram_adapter_type bitmask from Port 7) --- */

typedef enum {
    ADAPTER_NONE    = 0x00,
    ADAPTER_MOUNT   = 0x04,   /* SA-21 Slide Mount */
    ADAPTER_STRIP   = 0x08,   /* SF-210 Strip Film */
    ADAPTER_240     = 0x20,   /* IA-20(s) APS/IX240 */
    ADAPTER_FEEDER  = 0x40,   /* SA-30 Roll Film */
    /* Additional modes: 6Strip, 36Strip, Test (index 5-7) */
} adapter_type_t;

/* --- C1 Vendor subcommand codes --- */

typedef enum {
    C1_SCAN_40     = 0x40,   /* Scan control variant 0 */
    C1_SCAN_41     = 0x41,   /* Scan control variant 1 */
    C1_SCAN_42     = 0x42,   /* Scan control variant 2 */
    C1_SCAN_43     = 0x43,   /* Scan control variant 3 */
    C1_MOTOR_44    = 0x44,   /* Motor/calibration param */
    C1_SCAN_45     = 0x45,   /* Calibration variant A */
    C1_SCAN_46     = 0x46,   /* Calibration variant B */
    C1_SCAN_47     = 0x47,   /* Calibration variant C */
    C1_LAMP        = 0x80,   /* Lamp on/off + exposure */
    C1_LAMP_STATUS = 0x81,   /* Lamp status query */
    C1_CCD_CONFIG  = 0x91,   /* CCD configuration */
    C1_EXPOSURE    = 0xA0,   /* Exposure/focus params */
    C1_STATE_B0    = 0xB0,   /* State change A */
    C1_STATE_B1    = 0xB1,   /* State change B */
    C1_CONFIG_B3   = 0xB3,   /* Motor position B3 */
    C1_CONFIG_B4   = 0xB4,   /* Motor position B4 */
    C1_GAIN_CAL    = 0xC0,   /* Gain calibration */
    C1_OFFSET_CAL  = 0xC1,   /* Offset calibration */
    C1_DIAG_D0     = 0xD0,   /* Diagnostic A */
    C1_DIAG_D1     = 0xD1,   /* Diagnostic B */
    C1_DIAG_D2     = 0xD2,   /* Diagnostic data */
    C1_FOCUS_D5    = 0xD5,   /* Focus control */
    C1_PERSIST_D6  = 0xD6,   /* Persistent settings */
} c1_subcmd_t;


/* =====================================================================
 * PART 3 — COMPLETE TASK TABLE (97 entries at FW:0x49910)
 *
 * Format: 4 bytes per entry — task_code:16 (big-endian), handler_index:16
 * Terminated by 0x0000.
 *
 * The handler_index is NOT a function pointer — it indexes into a
 * secondary function pointer table used by the task execution engine.
 * ===================================================================== */

typedef struct {
    uint16_t task_code;
    uint16_t handler_index;
} task_entry_t;

/*
 * Full 97-entry task table, decoded directly from FW:0x49910.
 * Grouped by subsystem prefix for readability.
 */
static const task_entry_t task_table[97] = {

    /* === 0x01xx: System Initialization (3 entries) === */
    { 0x0110, 0x004C },  /* Init sequence step 1 (scan param setup) */
    { 0x0120, 0x0029 },  /* Init sequence step 2 (hardware config) */
    { 0x0121, 0x002A },  /* Init sequence step 3 (final config) */

    /* === 0x02xx: High-level (1 entry) === */
    { 0x0200, 0x0080 },  /* Top-level data management task */

    /* === 0x03xx: Motor Positioning (8 entries) === */
    { 0x0300, 0x0030 },  /* Motor: absolute positioning (shared handler) */
    { 0x0310, 0x0084 },  /* Motor: relative move / fine position */
    { 0x0320, 0x007E },  /* Motor: scan direction set */
    { 0x0330, 0x007B },  /* Motor: scan buffer stall wait */
    { 0x0340, 0x0082 },  /* Motor: position complete */
    { 0x0350, 0x0083 },  /* Motor: extended move */
    { 0x0380, 0x0073 },  /* Motor: slow precision move */
    { 0x0390, 0x0074 },  /* Motor: return to home/reference */

    /* === 0x04xx: Focus/Lens Motor (4 entries) === */
    { 0x0400, 0x0030 },  /* Focus: stop/reset (shares handler with 0x0300) */
    { 0x0430, 0x002C },  /* Focus: home/reference */
    { 0x0440, 0x002B },  /* Focus: relative move */
    { 0x0450, 0x007F },  /* Focus: extended fine adjustment */

    /* === 0x05xx: Calibration (3 entries) === */
    { 0x0500, 0x0031 },  /* Primary calibration */
    { 0x0501, 0x0032 },  /* Secondary calibration */
    { 0x0502, 0x0030 },  /* Shared handler (same as motor/focus) */

    /* === 0x06xx: CCD Readout (10 entries) === */
    { 0x0600, 0x0010 },  /* CCD basic config 0 */
    { 0x0601, 0x0011 },  /* CCD basic config 1 */
    { 0x0602, 0x0012 },  /* CCD basic config 2 */
    { 0x0603, 0x0013 },  /* CCD basic config 3 */
    { 0x0604, 0x0014 },  /* CCD basic config 4 */
    { 0x0610, 0x003D },  /* CCD extended config 0 */
    { 0x0611, 0x003E },  /* CCD extended config 1 */
    { 0x0612, 0x003F },  /* CCD extended config 2 */
    { 0x0613, 0x0040 },  /* CCD extended config 3 */
    { 0x0614, 0x0041 },  /* CCD extended config 4 */

    /* === 0x08xx: Scan Workflow (45 entries) === */

    /* Group 0-2: Preview scans (3 entries, all share handler 0x0022) */
    { 0x0800, 0x0022 },  /* Preview: low resolution */
    { 0x0810, 0x0022 },  /* Preview: medium resolution */
    { 0x0820, 0x0022 },  /* Preview: full resolution */

    /* Group 3: Fine scan, 8-bit, no ICE (5 entries) */
    { 0x0830, 0x0015 },  /* Fine 8-bit base */
    { 0x0831, 0x0016 },  /* Fine 8-bit variant 1 (strip adapter) */
    { 0x0832, 0x0017 },  /* Fine 8-bit variant 2 (mount adapter) */
    { 0x0833, 0x0018 },  /* Fine 8-bit variant 3 (240 adapter) */
    { 0x0834, 0x0019 },  /* Fine 8-bit variant 4 (feeder adapter) */

    /* Group 4: Fine scan, 8-bit, with ICE/IR (5 entries) */
    { 0x0840, 0x0042 },  /* Fine 8-bit ICE base */
    { 0x0841, 0x0043 },  /* Fine 8-bit ICE variant 1 */
    { 0x0842, 0x0044 },  /* Fine 8-bit ICE variant 2 */
    { 0x0843, 0x0045 },  /* Fine 8-bit ICE variant 3 */
    { 0x0844, 0x0046 },  /* Fine 8-bit ICE variant 4 */

    /* Group 5: Fine scan, 14-bit, no ICE (5 entries) */
    { 0x0850, 0x0023 },  /* Fine 14-bit base */
    { 0x0851, 0x0024 },  /* Fine 14-bit variant 1 */
    { 0x0852, 0x0025 },  /* Fine 14-bit variant 2 */
    { 0x0853, 0x0026 },  /* Fine 14-bit variant 3 */
    { 0x0854, 0x0027 },  /* Fine 14-bit variant 4 */

    /* Group 6: Fine scan, 14-bit, with ICE/IR (5 entries) */
    { 0x0860, 0x0033 },  /* Fine 14-bit ICE base */
    { 0x0861, 0x0034 },  /* Fine 14-bit ICE variant 1 */
    { 0x0862, 0x0035 },  /* Fine 14-bit ICE variant 2 */
    { 0x0863, 0x0036 },  /* Fine 14-bit ICE variant 3 */
    { 0x0864, 0x0037 },  /* Fine 14-bit ICE variant 4 */

    /* Group 7: Multi-pass scan, no ICE (5 entries) */
    { 0x0870, 0x0038 },  /* Multi-pass base */
    { 0x0871, 0x0039 },  /* Multi-pass variant 1 */
    { 0x0872, 0x003A },  /* Multi-pass variant 2 */
    { 0x0873, 0x003B },  /* Multi-pass variant 3 */
    { 0x0874, 0x003C },  /* Multi-pass variant 4 */

    /* Group 8: Multi-pass scan, with ICE/IR (5 entries) */
    { 0x0880, 0x0047 },  /* Multi-pass ICE base */
    { 0x0881, 0x0048 },  /* Multi-pass ICE variant 1 */
    { 0x0882, 0x0049 },  /* Multi-pass ICE variant 2 */
    { 0x0883, 0x004A },  /* Multi-pass ICE variant 3 */
    { 0x0884, 0x004B },  /* Multi-pass ICE variant 4 */

    /* Groups 9-B: Extended multi-sample (12 entries, late FW addition) */
    /* NOTE: No variant 0 (no base) — only 1-4; handler indices 0x85-0x90 */
    { 0x0891, 0x0085 },  /* Extended multi-sample A, variant 1 */
    { 0x0892, 0x0086 },  /* Extended multi-sample A, variant 2 */
    { 0x0893, 0x0087 },  /* Extended multi-sample A, variant 3 */
    { 0x0894, 0x0088 },  /* Extended multi-sample A, variant 4 */
    { 0x08A1, 0x0089 },  /* Extended multi-sample B, variant 1 */
    { 0x08A2, 0x008A },  /* Extended multi-sample B, variant 2 */
    { 0x08A3, 0x008B },  /* Extended multi-sample B, variant 3 */
    { 0x08A4, 0x008C },  /* Extended multi-sample B, variant 4 */
    { 0x08B1, 0x008D },  /* Extended multi-sample C, variant 1 */
    { 0x08B2, 0x008E },  /* Extended multi-sample C, variant 2 */
    { 0x08B3, 0x008F },  /* Extended multi-sample C, variant 3 */
    { 0x08B4, 0x0090 },  /* Extended multi-sample C, variant 4 */

    /* === 0x09xx: Exposure/Timing (8 entries) === */
    { 0x0910, 0x001A },  /* Exposure: sequence step 0 */
    { 0x0911, 0x001B },  /* Exposure: sequence step 1 */
    { 0x0912, 0x001C },  /* Exposure: sequence step 2 */
    { 0x0913, 0x001D },  /* Exposure: sequence step 3 */
    { 0x0914, 0x001E },  /* Exposure: sequence step 4 */
    { 0x0920, 0x0005 },  /* Exposure: param computation */
    { 0x0930, 0x0006 },  /* Exposure: timing set */
    { 0x0940, 0x0077 },  /* Exposure: final configure */

    /* === 0x0Fxx: Error Recovery (6 entries) === */
    { 0x0F10, 0x0020 },  /* Recovery: scan abort */
    { 0x0F20, 0x0021 },  /* Recovery: cleanup / post-scan */
    { 0x0F30, 0x0028 },  /* Recovery: motor error */
    { 0x0F40, 0x002D },  /* Recovery: calibration error */
    { 0x0F50, 0x002E },  /* Recovery: CCD error */
    { 0x0F60, 0x002F },  /* Recovery: general error */

    /* === 0x10xx-0x12xx: Extended Subsystems (3 entries) === */
    { 0x1000, 0x000B },  /* Lamp/power control */
    { 0x1100, 0x0078 },  /* Dust detection (Digital ICE support) */
    { 0x1200, 0x0091 },  /* Extended subsystem final entry */

    /* === 0x20xx-0x90xx: System Control (6 entries) === */
    { 0x2000, 0x000A },  /* Startup / boot-complete task */
    { 0x3000, 0x0071 },  /* Self-test / hardware diagnostics */
    { 0x4000, 0x000E },  /* Eject media */
    { 0x7000, 0x000F },  /* Park / low-power sleep (same handler as 0x9000) */
    { 0x8000, 0x000C },  /* Firmware soft reset */
    { 0x9000, 0x000F },  /* Hardware reset (same handler as 0x7000) */

    /* Terminator */
    /* { 0x0000, 0x0000 }, -- table ends with null entry */
};

/*
 * Scan task code format: 0x08GV
 *   G = Group (0x0-0xB): scan type (preview, fine, multi-pass, extended)
 *   V = Variant (0x0-0x4): adapter-specific configuration
 *
 * Runtime computation:
 *   task_code = 0x08G0 | (adapter_variant_byte + 1)
 *
 * Handler index allocation blocks reveal firmware development timeline:
 *   Block 1: Group 3        (0x0015-0x0019) — first scan mode implemented
 *   Block 2: Groups 0-2 + 5 (0x0022-0x0027) — preview + fine 14-bit
 *   Block 3: Groups 6 + 7   (0x0033-0x003C) — 14-bit ICE + multi-pass
 *   Block 4: Groups 4 + 8   (0x0042-0x004B) — 8-bit ICE + multi-pass ICE
 *   Block 5: Groups 9-B     (0x0085-0x0090) — late addition (gap from 0x4B)
 */


/* =====================================================================
 * PART 4 — SCSI HANDLER TABLE (21 entries at FW:0x49834)
 *
 * Format: 10 bytes per entry (big-endian):
 *   opcode:8, pad:8, perm_flags:16, handler_ptr:32, exec_mode:8, pad:8
 *
 * Terminated by null entry (all zeros) at 0x49906.
 * ===================================================================== */

typedef struct {
    uint8_t  opcode;
    uint8_t  _pad0;
    uint16_t perm_flags;     /* Bitmask: which scanner states allow this cmd */
    uint32_t handler_addr;   /* 24-bit function pointer */
    uint8_t  exec_mode;      /* 0=direct, 1=USB setup, 2=data-out, 3=data-in */
    uint8_t  _pad1;
} scsi_handler_entry_t;

static const scsi_handler_entry_t scsi_handler_table[21] = {
    /* op   pad  perms    handler     exec pad */
    { 0x00, 0, 0x07D4, 0x0215C2, 0x01, 0 },  /* TEST UNIT READY */
    { 0x03, 0, 0x07FF, 0x021866, 0x03, 0 },  /* REQUEST SENSE */
    { 0x12, 0, 0x07FF, 0x025E18, 0x03, 0 },  /* INQUIRY */
    { 0x15, 0, 0x0014, 0x02194A, 0x02, 0 },  /* MODE SELECT(6) */
    { 0x16, 0, 0x07CC, 0x021E3E, 0x01, 0 },  /* RESERVE(6) */
    { 0x17, 0, 0x07FC, 0x021EA0, 0x01, 0 },  /* RELEASE(6) */
    { 0x1A, 0, 0x07D4, 0x021F1C, 0x03, 0 },  /* MODE SENSE(6) */
    { 0x1B, 0, 0x0014, 0x0220B8, 0x00, 0 },  /* SCAN */
    { 0x1C, 0, 0x0014, 0x023856, 0x03, 0 },  /* RECEIVE DIAGNOSTIC */
    { 0x1D, 0, 0x0016, 0x023D32, 0x02, 0 },  /* SEND DIAGNOSTIC */
    { 0x24, 0, 0x0014, 0x026E38, 0x02, 0 },  /* SET WINDOW */
    { 0x25, 0, 0x0254, 0x0272F6, 0x03, 0 },  /* GET WINDOW */
    { 0x28, 0, 0x0054, 0x023F10, 0x03, 0 },  /* READ(10) */
    { 0x2A, 0, 0x0014, 0x025506, 0x02, 0 },  /* SEND/WRITE(10) */
    { 0x3B, 0, 0x0014, 0x02837C, 0x02, 0 },  /* WRITE BUFFER */
    { 0x3C, 0, 0x0014, 0x028884, 0x03, 0 },  /* READ BUFFER */
    { 0xC0, 0, 0x0754, 0x028AB4, 0x01, 0 },  /* Vendor: Status Query */
    { 0xC1, 0, 0x0014, 0x028B08, 0x01, 0 },  /* Vendor: Trigger Action */
    { 0xD0, 0, 0x07FF, 0x013748, 0x01, 0 },  /* Vendor: Phase Query */
    { 0xE0, 0, 0x0014, 0x028E16, 0x02, 0 },  /* Vendor: Data Out */
    { 0xE1, 0, 0x0014, 0x0295EA, 0x03, 0 },  /* Vendor: Data In */
};

/*
 * Permission flag semantics:
 *   0x07FF = always allowed (any state)         — REQUEST SENSE, INQUIRY, D0
 *   0x07D4 = most states except active scan      — TEST UNIT READY, MODE SENSE
 *   0x07FC = all states except initial           — RELEASE
 *   0x07CC = restricted (not during scan/xfer)   — RESERVE
 *   0x0754 = specific states (status query)       — C0
 *   0x0254 = limited (window query states)        — GET WINDOW
 *   0x0054 = only during active read ops          — READ(10)
 *   0x0016 = diagnostic/service mode only         — SEND DIAGNOSTIC
 *   0x0014 = requires scanner initialized         — most write commands
 */


/* =====================================================================
 * PART 5 — INTERRUPT VECTOR TABLE AND HANDLERS
 *
 * H8/3003: 64 vectors at 0x000000-0x0000FF (4 bytes each).
 * 15 active vectors, 49 point to default handler (infinite loop).
 *
 * Active vectors use on-chip RAM trampolines (0xFFFD10-0xFFFD3C)
 * containing JMP instructions installed at runtime.
 * ===================================================================== */

/*
 * Vector table (first 256 bytes of flash):
 *
 * Vec  Address  Trampoline  Handler     H8/3003 Source   Purpose
 * ---  -------  ----------  -------     --------------   -------
 *  0   0x000    —           0x000100    Reset            Power-on entry
 *  7   0x01C    —           0x000182    NMI              Tight loop (error trap)
 *  8   0x020    0xFFFD10    0x010876    TRAP #0          Context switch (TRAPA #0)
 * 13   0x034    0xFFFD3C    0x014E00    IRQ1             ISP1581 USB interrupt
 * 15   0x03C    0xFFFD14    0x033444    IRQ3             Motor encoder pulses
 * 16   0x040    0xFFFD18    0x014D4A    IRQ4             External interrupt (shared)
 * 17   0x044    0xFFFD18    0x014D4A    IRQ5             External interrupt (shared)
 * 19   0x04C    0xFFFD38    0x02B544    IRQ7             Motor step/scan segment ISR
 * 32   0x080    0xFFFD1C    0x010B76    IMIA2 (ITU2)     Motor mode dispatcher
 * 36   0x090    0xFFFD20    0x02D536    IMIA3 (ITU3)     DMA burst coordinator
 * 40   0x0A0    0xFFFD24    0x010A16    IMIA4 (ITU4)     System tick timer
 * 45   0x0B4    0xFFFD28    0x02CEF2    DEND0B           DMA ch0B end
 * 47   0x0BC    0xFFFD2C    0x02E10A    DEND1B           DMA ch1B end
 * 49   0x0C4    0xFFFD30    0x02E9F8    Timer/CCD        CCD line readout / DMA coord
 * 60   0x0F0    0xFFFD34    0x02EDDE    ADI              A/D conversion complete
 *
 * All SCI vectors (52-59) are INACTIVE — serial I/O is polled.
 */


/* =====================================================================
 * PART 6 — BOOT AND STARTUP SEQUENCE
 *
 * FW:0x000100 -> 0x00016E -> 0x020334 -> ... -> 0x020620
 * ===================================================================== */

/*
 * reset_vector_handler()
 * FW:0x000100  —  Called on power-on by H8/3003 (vector 0 = 0x000100)
 *
 * Path A (cold boot): state_flag = 0, jump to bank_select
 * Path B (warm restart from 0x000112): state_flag = 1, copy saved
 *   state from external RAM to on-chip RAM, then bank_select
 */
void reset_vector_handler(void)                        /* FW:0x000100 */
{
    /* === Path A: Normal cold boot === */
    register uint32_t sp = 0xFFFF00;                   /* Stack -> on-chip RAM top */
    /* LDC #0xC0, CCR */                               /* Disable all interrupts */
    *(volatile uint8_t *)0xFFFD4C = 0x00;              /* state_flag = cold boot */
    goto bank_select;                                  /* BRA 0x16E */
}

void warm_restart_entry(void)                          /* FW:0x000112 */
{
    /* === Path B: Warm restart (entered from soft-reset) === */
    register uint32_t sp = 0xFFFF00;
    /* LDC #0xC0, CCR */
    *(volatile uint8_t *)0xFFFD4C = 0x01;              /* state_flag = warm restart */

    /* Copy saved state from external RAM to on-chip RAM */
    *(volatile uint8_t *)0xFFFD4D = *(volatile uint8_t *)0x4006B2;
    *(volatile uint8_t *)0xFFFD4E = *(volatile uint8_t *)0x4006B3;

    /* Three eepmov.b copy operations: */
    memcpy((void *)0xFFFD50, (void *)0x4006B4, 8);    /* 8 bytes */
    memcpy((void *)0xFFFD58, (void *)0x4006BC, 160);   /* 160 bytes */
    memcpy((void *)0xFFFDF8, (void *)0x40075C, 8);     /* 8 bytes */
    /* NOTE: Source data at flash 0x6B4 is all 0xFF (erased).
     * These copies are ineffective in current flash. Legacy mechanism. */

    /* Fall through to bank_select */
}

void bank_select(void)                                 /* FW:0x00016E */
{
    /*
     * Address 0x4001 is a hardware register (not flash/RAM) that
     * selects which firmware bank to run. In normal operation: 0x00.
     */
    uint8_t bank = *(volatile uint8_t *)0x4001;
    if (bank == 0x00)
        main_firmware_entry();                         /* JMP 0x020334 */
    else
        backup_firmware_entry();                       /* JMP 0x010334 */
}

/* NMI and default exception handlers: infinite loops */
void nmi_handler(void)     { for (;;) ; }              /* FW:0x000182 */
void default_handler(void) { for (;;) ; }              /* FW:0x000186 */


/*
 * main_firmware_entry()
 * FW:0x020334  —  Main firmware initialization sequence
 */
void main_firmware_entry(void)                         /* FW:0x020334 */
{
    /* --- Step 1: Bank verification --- */
    if (*(volatile uint8_t *)0x4001 != 0x00)
        backup_firmware_entry();                       /* Safety redirect */
    if ((*(volatile uint8_t *)0x4000 & 0xFE) != 0x00)
        backup_firmware_entry();                       /* Safety redirect */

    WDT_TCSR = 0x5A00;                                /* Reset watchdog */

    /* --- Step 2: I/O register initialization (132 entries) --- */
    /*
     * Table at FW:0x2001C — 132 entries of 6 bytes each:
     *   [address:32 (big-endian)] [value:16 (low byte written)]
     *
     * Configures: BSC (bus width, wait states, chip select),
     *   GPIO ports (P1-P4 DDR), ITU timers (TSTR, TCR),
     *   ~70 ASIC registers (0x200044-0x200487), etc.
     *
     * Last entry: ASIC master enable (0x200001 = 0x80)
     */
    io_init_table_process();                           /* FW:0x02035C */

    /* --- Step 3: RAM test --- */
    /*
     * Tests external RAM at 0x400000+ using complementary patterns:
     *   Write 0x55AA55AA, verify; write 0xAA55AA55, verify.
     * Memory region table at FW:0x207A8.
     */
    ram_test();                                        /* FW:0x203BA */

    /* --- Step 4: Relocate stack to external RAM --- */
    /* MOV.L #0x40F800, ER7 */
    /* SP now at external RAM (was 0xFFFF00 in on-chip RAM) */

    /* --- Step 5: Peripheral initialization --- */
    peripheral_init();                                 /* JSR 0x015EAA */

    /* --- Step 6: Interrupt trampoline installation --- */
    /*
     * Install 12 JMP instructions into on-chip RAM trampolines.
     * Each trampoline = 4 bytes of JMP @target_address.
     *
     * Installation uses eepmov.b to copy 4 bytes of inline
     * JMP instruction data to each trampoline RAM address.
     *
     * Trampolines (0xFFFD10 - 0xFFFD3C):
     *   0xFFFD10 -> JMP 0x010876  (TRAP #0 context switch)
     *   0xFFFD14 -> JMP 0x033444  (IRQ3 encoder)
     *   0xFFFD18 -> JMP 0x014D4A  (IRQ4/IRQ5 shared)
     *   0xFFFD1C -> JMP 0x010B76  (ITU2 motor dispatcher)
     *   0xFFFD20 -> JMP 0x02D536  (ITU3 DMA coordinator)
     *   0xFFFD24 -> JMP 0x010A16  (ITU4 system tick)
     *   0xFFFD28 -> JMP 0x02CEF2  (DEND0B DMA end)
     *   0xFFFD2C -> JMP 0x02E10A  (DEND1B DMA end)
     *   0xFFFD30 -> JMP 0x02E9F8  (CCD line readout)
     *   0xFFFD34 -> JMP 0x02EDDE  (A/D conversion complete)
     *   0xFFFD38 -> JMP 0x02B544  (IRQ7 motor step)
     *   0xFFFD3C -> JMP 0x014E00  (IRQ1 ISP1581 USB)
     */
    install_trampolines();                             /* FW:0x204C4 - 0x205F7 */

    /* --- Step 7: Clear shared state --- */
    clear_shared_state();                              /* JSR 0x0109FA */
    /*  Sets ram_timestamp (0x40076E) etc. to zero */

    /* --- Step 8: Enable interrupts briefly for hardware init --- */
    ram_boot_flag = 0x01;                              /* "initialized" flag */
    /* ANDC #0x7F, CCR — ENABLE INTERRUPTS (first time!) */
    hardware_init_with_interrupts();                   /* JSR 0x02A188 */
    /* ORC #0x80, CCR — DISABLE INTERRUPTS again */

    /* --- Step 9: Prepare context system --- */
    ram_boot_flag = 0x00;                              /* Cold-boot descriptor */
    register_context_a_entry();                        /* JSR 0x0107BC */
    init_asic_dma_state();                             /* JSR 0x010BCE */

    /* --- Step 10: ENTER CONTEXT SYSTEM (never returns) --- */
    context_system_init();                             /* JMP 0x0107EC */
}


/*
 * io_init_table_process()
 * FW:0x02035C  —  Process the 132-entry I/O register init table
 */
void io_init_table_process(void)                       /* FW:0x02035C */
{
    const uint8_t *src = (const uint8_t *)0x2001C;     /* Table start */
    const uint8_t *end = (const uint8_t *)0x20334;     /* Table end */

    while (src < end) {
        uint32_t target_addr = read_be32(src);         /* 4-byte address */
        src += 4;
        uint16_t value = read_be16(src);               /* 2-byte value */
        src += 2;
        *(volatile uint8_t *)target_addr = (uint8_t)(value & 0xFF);
    }

    /*
     * Key entries include:
     *   ABWCR  (0xFFFFF2) = 0x0B  — Bus width config
     *   WCR    (0xFFFFF4) = 0xBA  — Wait states
     *   CSCR   (0xFFFFF9) = 0x30  — Chip select
     *   P1DDR  (0xFFFFD4) = 0xFF  — Port 1: all outputs
     *   TSTR   (0xFFFF60) = 0xE0  — Enable ITU channels 2,3,4
     *   ~70 ASIC registers at 0x200xxx
     *   Last: 0x200001 = 0x80     — ASIC master enable
     */
}


/* =====================================================================
 * PART 7 — COROUTINE SYSTEM (Two-Context Cooperative Scheduler)
 *
 * The firmware's "OS" is a simple two-context cooperative coroutine
 * system. Contexts share the CPU via explicit yield (TRAPA #0).
 *
 * Context A: Main loop (SCSI commands, state machine)
 *   Stack at 0x410000 (top of 128KB external RAM)
 *   Entry: 0x0207F2 (cold) or 0x010C46 (warm restart)
 *
 * Context B: Background processing (DMA, motor, data transfers)
 *   Stack at 0x40D000 (52KB below Context A)
 *   Entry: 0x029B16 (same for both cold and warm)
 *
 * This is NOT preemptive. Hardware interrupts run independently.
 * ===================================================================== */

/*
 * Context descriptor tables in flash:
 *
 * Table A (cold boot, FW:0x107CC):
 *   Context A: stack_base=0x410000, entry=0x0207F2  (main loop)
 *   Context B: stack_base=0x40D000, entry=0x029B16  (USB/data handler)
 *
 * Table B (warm restart, FW:0x107DC):
 *   Context A: stack_base=0x410000, entry=0x010C46  (alternate main)
 *   Context B: stack_base=0x40D000, entry=0x029B16  (same)
 */
typedef struct {
    uint32_t stack_base;
    uint32_t entry_point;
} context_descriptor_t;

static const context_descriptor_t ctx_table_cold[2] = {  /* FW:0x107CC */
    { 0x410000, 0x0207F2 },  /* Context A: main firmware loop */
    { 0x40D000, 0x029B16 },  /* Context B: background processing */
};

static const context_descriptor_t ctx_table_warm[2] = {  /* FW:0x107DC */
    { 0x410000, 0x010C46 },  /* Context A: alternate main loop */
    { 0x40D000, 0x029B16 },  /* Context B: same */
};


/*
 * context_system_init()
 * FW:0x0107EC  —  Initialize both contexts and start Context A.
 *
 * Creates initial stack frames for each context with:
 *   - Entry point pushed as return address (popped by RTE)
 *   - 7 zero-initialized register saves (ER0-ER6)
 *
 * Then loads Context A's saved SP, pops registers, RTE into it.
 */
void context_system_init(void) __attribute__((noreturn))  /* FW:0x0107EC */
{
    const context_descriptor_t *table;

    if (ram_boot_flag != 0)
        table = ctx_table_warm;                        /* Table B (warm restart) */
    else
        table = ctx_table_cold;                        /* Table A (first boot) */

    /* Initialize each context's stack frame */
    for (int i = 0; i < 2; i++) {
        uint32_t *sp = (uint32_t *)table[i].stack_base;

        /* Push entry point (will be the return address for RTE) */
        *(--sp) = table[i].entry_point;

        /* Push 7 zero registers (ER0-ER6 initial values = 0) */
        for (int r = 0; r < 7; r++)
            *(--sp) = 0x00000000;

        /* Save this SP to context save area in RAM */
        ram_ctx_save[i] = (uint32_t)sp;
    }

    /* Clear context switch state */
    ram_ctx_state = 0x0000;

    /* Load Context A's stack pointer and start it via RTE */
    uint32_t *ctx_a_sp = (uint32_t *)ram_ctx_save[0];

    /* Pop ER6, ER5, ER4, ER3, ER2, ER1, ER0 */
    /* RTE: pops CCR + PC -> jumps to Context A entry point */

    /* >>> Execution continues at 0x0207F2 (Context A main loop) <<< */
    /* This function never returns. */
}


/*
 * yield()
 * FW:0x0109E2  —  Cooperative context switch via TRAPA #0
 *
 * Called explicitly by the running context to give up the CPU.
 * The TRAPA instruction pushes CCR+PC, then vectors to the
 * TRAP #0 handler (vector 8 -> trampoline 0xFFFD10 -> 0x010876).
 */
void yield(void)                                       /* FW:0x0109E2 */
{
    __asm__("TRAPA #0");                               /* Push CCR+PC, vector 8 */
    /* Returns here when this context is resumed */
}


/*
 * trap0_handler()
 * FW:0x010876  —  TRAP #0 handler (context switch core)
 *
 * Called when any context executes TRAPA #0.
 * Saves all registers of the yielding context, swaps stacks,
 * restores all registers of the other context, and RTE into it.
 */
void trap0_handler(void)                               /* FW:0x010876 */
{
    /* Re-enable interrupts during context switch */
    /* ANDC #0x7F, CCR */

    /* Save all registers of the yielding context onto its stack */
    /* PUSH ER0, ER1, ER2, ER3, ER4, ER5, ER6  (28 bytes) */

    /* Reset watchdog timer */
    WDT_TCSR = 0x5A00;

    /* Read boot flag and bank register for validation */
    uint8_t boot = ram_boot_flag;
    uint8_t bank = *(volatile uint8_t *)0x4001;

    /* Disable interrupts during SP swap (critical section) */
    /* ORC #0x80, CCR */

    /* Read current context index and swap */
    uint16_t ctx = ram_ctx_state;

    /* Swap: save current SP to ctx_save[current], load from ctx_save[other] */
    if (ctx == 0) {
        ram_ctx_save[0] = __get_sp();
        __set_sp(ram_ctx_save[1]);
        ram_ctx_state = 1;
    } else {
        ram_ctx_save[1] = __get_sp();
        __set_sp(ram_ctx_save[0]);
        ram_ctx_state = 0;
    }

    /* Re-enable interrupts */
    /* ANDC #0x7F, CCR */

    /* Pop all registers of the OTHER (now-active) context from its stack */
    /* POP ER6, ER5, ER4, ER3, ER2, ER1, ER0 */

    /* RTE: pops CCR+PC from the new context's stack.
     * Atomically resumes the other context with its saved
     * interrupt state and program counter. */
}


/* Utility stubs at FW:0x109E0 - 0x109FA */
void rte_direct(void)      { __asm__("RTE"); }        /* FW:0x109E0 */
/* yield() at 0x109E2 defined above */
void disable_interrupts(void) { /* ORC #0x80, CCR */ } /* FW:0x109EA */
void enable_interrupts(void)  { /* ANDC #0x7F, CCR */} /* FW:0x109EE */
uint8_t read_ccr(void)     { /* STC CCR, R0L */ }     /* FW:0x109F2 */
void write_ccr(uint8_t v)  { /* LDC R0L, CCR */ }     /* FW:0x109F6 */
void clear_shared_state(void) {                        /* FW:0x0109FA */
    ram_timestamp = 0;
    /* Zero additional shared variables */
}


/* =====================================================================
 * PART 8 — CONTEXT A: MAIN FIRMWARE LOOP
 *
 * FW:0x0207F2  —  The control plane.
 * Receives SCSI commands, dispatches handlers, manages state,
 * sends USB responses. Yields to Context B when no command pending.
 * ===================================================================== */

void context_a_main_loop(void) __attribute__((noreturn))  /* FW:0x0207F2 */
{
    /* Save callee-saved registers (push_context) */
    push_context();                                    /* JSR 0x016458 */

    /* Load frequently-used RAM pointers into registers:
     *   ER3 -> 0x40077A  (scan progress state)
     *   ER4 -> 0x400084  (USB bus reset flag)
     *   ER5 -> 0x400085  (USB re-init flag)
     *   ER6 -> 0x400776  (scanner state flags)
     */
    volatile uint16_t *scan_progress = &ram_scan_progress;
    volatile uint8_t  *usb_reset     = &ram_usb_reset_flag;
    volatile uint8_t  *usb_reinit    = &ram_usb_reinit_flag;
    volatile uint16_t *scan_flags    = &ram_scanner_flags;

    /* One-time init (shared module) */
    ram_init_result = shared_module_init();             /* JSR 0x010D22 */

    /* USB configuration with timeout */
    usb_configure_with_timeout(50);                    /* JSR 0x01233A */

    /* Enable USB endpoints */
    usb_enable_endpoints();                            /* JSR 0x0126EE */

    /* <<<< MAIN POLLING LOOP >>>> */
    for (;;) {

        /* --- Step 1: Check USB connection state --- */
        if (ram_usb_conn_state != 0x02) {
            /* Not connected: re-establish USB session */
            usb_reestablish_session(0x005C, 0x01);     /* JSR 0x013836 */
        }

        /* --- Step 2: Process scan state changes --- */
        process_scan_state(*scan_progress, ram_task_code);
                                                       /* JSR 0x0133A4 */

        /* --- Step 3: Handle USB bus reset --- */
        if (*usb_reset != 0) {
            usb_handle_bus_reset();                    /* JSR 0x013A20 */
        }

        /* --- Step 4: Run scanner state machine --- */
        scanner_state_machine();                       /* BSR 0x208AC */

        /* --- Step 5: Handle USB re-initialization --- */
        if (*usb_reinit != 0) {
            *usb_reinit = 0;                           /* Clear flag */
            if (ram_error_flag != 0) {
                ram_sense_code = SENSE_USB_COMM_ERROR;  /* 0x0061 */
            }
            if (*scan_flags & 0x0040) {                /* bit 6 = abort */
                *scan_flags |= 0x0080;                 /* bit 7 = response pending */
            }
            if (*usb_reset == 0) {
                usb_soft_reconnect();                  /* JSR 0x013BB4 */
            }
        }

        /* --- Step 6: Check for incoming SCSI command --- */
        uint8_t cmd_ready = usb_check_command_ready(); /* JSR 0x013C70 */

        if (cmd_ready == 0) {
            /*
             * No command pending.
             * YIELD to Context B (USB data handler).
             * When Context B yields back, we re-enter the loop.
             */
            yield();                                   /* JSR 0x0109E2 */
            continue;                                  /* BRA .loop_top */
        }

        /* --- Step 7: Process SCSI command --- */
        scanner_state_machine();                       /* Re-check state */
        scsi_dispatch();                               /* JSR 0x020AE2 */

        /* --- Step 8: Check for soft-reset --- */
        if (ram_soft_reset == 0x01) {
            usb_disconnect();                          /* JSR 0x012F5A */
            disable_interrupts();                      /* JSR 0x0109EA */
            warm_restart_entry();                      /* JMP 0x000112 */
            /* Never reached */
        }
    }
}


/* =====================================================================
 * PART 9 — CONTEXT B: BACKGROUND PROCESSING LOOP
 *
 * FW:0x029B16  —  The data plane.
 * Monitors task progress, manages DMA transfers, coordinates
 * motor/CCD timing, handles long-running data flows.
 * ===================================================================== */

void context_b_background_loop(void) __attribute__((noreturn))  /* FW:0x029B16 */
{
    push_context();

    volatile uint16_t *scan_progress = &ram_scan_progress;  /* ER3 -> 0x40077A */
    volatile uint16_t *scan_flags    = &ram_scanner_flags;  /* ER5 -> 0x400776 */
    volatile uint16_t *state_var     = &ram_scanner_state;  /* ER6 -> 0x40077C */

    for (;;) {
        /*
         * Monitor task codes at ram_task_code (0x400778) for various events:
         *
         *   0x0010 -> set scan progress to 0x2000, call handler, yield
         *   0x0110/0x0120/0x0121 -> init sequence monitoring
         *   0x2000/0x3000 -> scan/recovery monitoring
         *
         * Check ASIC DMA status and manage data flow.
         * Check adapter state (0x400F22, 0x40632F).
         * Check USB busy (0x400773) and cmd_state values (1-7).
         *
         * Functions called from this loop:
         *   0x29E96 - Init state handler (150 bytes)
         *   0x29F56 - Secondary state machine (556 bytes)
         *   0x2A690 - Motor coordination (380 bytes)
         *   0x2A812 - ASIC DMA management (1.5KB)
         *   0x2ADE4 - Data path control (242 bytes)
         *   0x2AF1A - Task code monitoring (142 bytes)
         *   0x2AFAE - ISR support (1.4KB)
         *
         * Has 21 yield calls across 0x29B16-0x2C400 region,
         * yielding frequently to keep Context A responsive.
         * Yield points distributed across:
         *   - Task code polling loops
         *   - DMA completion polling
         *   - Motor position waiting
         *   - USB transfer completion
         */

        /* Check task code for state transitions */
        uint16_t task = ram_task_code;

        switch (task) {
        case 0x0010:
            ram_scan_progress = 0x2000;
            /* Call scan init handler, then yield */
            break;

        case 0x0110:
        case 0x0120:
        case 0x0121:
            /* Init sequence monitoring — poll for completion */
            break;

        case 0x2000:
        case 0x3000:
            /* Scan/recovery monitoring — manage DMA, motor state */
            break;

        default:
            /* Check ASIC DMA, adapter state, USB busy */
            break;
        }

        /* When idle: yield to Context A */
        yield();                                       /* JSR 0x0109E2 */
    }
}

/*
 * Context B region function map (0x29600-0x2C400, 12KB total):
 *
 * Address    Size     Function
 * -------    ----     --------
 * 0x29600    1.3KB    Pre-B support functions
 * 0x29B16    892B     Context B main loop (entry point)
 * 0x29E96    150B     Init state handler
 * 0x29F56    556B     Secondary state machine
 * 0x2A188    1.3KB    One-time hardware init (with interrupts)
 * 0x2A690    380B     Motor coordination
 * 0x2A812    1.5KB    ASIC DMA management
 * 0x2ADE4    242B     Data path control
 * 0x2AF1A    142B     Task code monitoring
 * 0x2AFAE    1.4KB    ISR support functions
 * 0x2B544    388B     IRQ7 motor step/scan segment ISR
 * 0x2B6CE    690B     Encoder processing support
 * 0x2B986    314B     Motor stepping support
 * 0x2BCAE    320B     Error recovery
 * 0x2BDF4    634B     Focus motor coordination
 * 0x2C074    350B     Scan coordination
 */


/* =====================================================================
 * PART 10 — SCSI COMMAND DISPATCH
 *
 * FW:0x020AE2  —  Entry point from main loop when SCSI command arrives.
 * FW:0x020B48  —  Handler lookup (linear search through table).
 * ===================================================================== */

/*
 * scsi_dispatch()
 * FW:0x020AE2  —  Top-level SCSI command dispatcher
 *
 * Called from the main loop when usb_check_command_ready() returns true.
 * Clears sense state, looks up the handler, calls it, signals completion.
 */
void scsi_dispatch(void)                               /* FW:0x020AE2 */
{
    volatile uint8_t *cmd_ctr = &ram_cmd_ctr;          /* 0x40049D */

    /* Clear sense state for new command */
    ram_sense_code = SENSE_NONE;
    *(volatile uint8_t *)0x400877 = 0;                 /* Clear additional sense */

    /* Verify command is ready for processing */
    if (!usb_verify_command_ready())                    /* JSR 0x013690 */
        goto done;

    /* Clear execution state */
    *cmd_ctr = 0;
    ram_usb_txn_active = 0;
    ram_xfer_phase = 0;

    /* If sense code was already set (from previous error), skip handler */
    if (ram_sense_code != SENSE_NONE)
        goto already_error;

    /* >>> Look up and call the SCSI handler <<< */
    scsi_handler_lookup();                             /* BSR 0x020B48 */

    /* Signal command-complete phase */
    usb_signal_response(0x01);                         /* JSR 0x01374A */

already_error:
    /* Increment completion counter */
    (*cmd_ctr)++;
    if (*cmd_ctr == 0x02) {
        if (ram_usb_txn_active)
            goto done;
    }
    usb_signal_response(0x01);                         /* JSR 0x01374A */

done:
    post_dispatch_cleanup();                           /* JSR 0x01117A */
}


/*
 * scsi_handler_lookup()
 * FW:0x020B48  —  Linear search through the SCSI handler table.
 *
 * Matches the received opcode against the table, checks permissions
 * against the current scanner state, then calls the handler.
 */
void scsi_handler_lookup(void)                         /* FW:0x020B48 */
{
    push_context();

    uint8_t cmd_phase = 0x01;                          /* R3L = command phase */
    const scsi_handler_entry_t *entry =
        (const scsi_handler_entry_t *)0x049834;        /* Table base */

    /* Linear search through handler table */
    while (entry->handler_addr != 0) {
        if (entry->opcode == ram_scsi_opcode)
            goto found;
        entry++;                                       /* 10-byte stride */
    }

    /* Opcode not found -> ILLEGAL REQUEST */
    ram_sense_code = SENSE_INVALID_CDB;
    goto exit;

found:
    /* --- Permission checking (FW:0x020B70 - 0x020D90) --- */
    uint16_t perms = entry->perm_flags;

    /*
     * Permission checking against scanner state.
     * Tests bits in perms against current state flags.
     * If the command is not allowed in the current state,
     * sets sense_code and exits.
     *
     * Permission flag meanings:
     *   0x07FF = always allowed
     *   0x0014 = requires initialized
     *   etc. (see permission table above)
     */
    if (!check_command_permission(perms))
        goto exit;

    /* --- Handler invocation (FW:0x020D94) --- */
    uint8_t exec = entry->exec_mode;

    /* If exec mode == 1: USB state setup before handler */
    if (exec == EXEC_USB_SETUP) {
        usb_signal_response(cmd_phase);                /* JSR 0x01374A */
    }

    /* Store exec mode for later reference */
    ram_exec_mode = exec;

    /* >>> CALL THE SCSI HANDLER <<< */
    void (*handler)(void) = (void (*)(void))entry->handler_addr;
    handler();

exit:
    pop_context();
}


/* =====================================================================
 * PART 11 — TASK DISPATCHER AND EXECUTION ENGINE
 *
 * FW:0x020DBA  —  Task code lookup in the 97-entry table.
 * FW:0x020DD6  —  Task execution with time-budget system.
 * ===================================================================== */

/*
 * task_dispatch()
 * FW:0x020DBA  —  Look up a 16-bit task code in the internal task table.
 *
 * Input:  task_code (16-bit) in R0
 * Output: handler_index (16-bit) in R0
 *
 * Linear search through 97 entries at FW:0x49910.
 * Returns 0 if not found (null terminator).
 */
uint16_t task_dispatch(uint16_t task_code)             /* FW:0x020DBA */
{
    const task_entry_t *entry = (const task_entry_t *)0x049910;

    while (entry->task_code != 0x0000) {
        if (entry->task_code == task_code)
            return entry->handler_index;
        entry++;                                       /* 4-byte stride */
    }

    /* Not found — return the handler index at the null terminator (0) */
    return entry->handler_index;
}


/*
 * task_execute()
 * FW:0x020DD6  —  Execute a task with a time-budget system.
 *
 * Each task gets a budget (number of execution units).
 * When budget runs out or no work remains, the function either
 * exits or yields. This prevents scan tasks from starving
 * SCSI command processing.
 */
void task_execute(void)                                /* FW:0x020DD6 */
{
    push_context();

    volatile uint32_t *remaining = &ram_task_remaining;  /* ER3 -> 0x40078C */
    volatile uint32_t *budget    = &ram_task_budget;      /* ER5 -> 0x400896 */

    /* Save initial budget for accounting */
    ram_task_budget_sav = *budget;

    /* Set "task execution active" flag */
    ram_task_active = 0x01;

    while (*budget != 0) {

        uint32_t work = *remaining;

        if (work == 0) {
            /* No work: check for errors or USB re-init */
            if (ram_sense_code != SENSE_NONE)
                goto error_exit;
            if (ram_usb_reinit_flag) {
                ram_task_active = 0;
                goto done;
            }

            /* No work and no errors: yield (give up CPU) */
            yield();                                   /* JSR 0x0109E2 */
            continue;
        }

        /* Execute one unit of work (DMA transfer/task step) */
        uint32_t work_done = execute_work_unit();      /* JSR 0x0140F2 */

        /* Decrease budget by work done */
        *budget -= work_done;

        /* Update remaining work */
        /* ... (accounting logic) ... */

        if (*budget == 0) {
            /* Budget exhausted */
            ram_task_complete = 0x01;
        }
    }

error_exit:
    /* Clean up, reconcile accounting */
    ram_task_active = 0;
    /* ... final accounting ... */

done:
    pop_context();
}


/* =====================================================================
 * PART 12 — SCANNER STATE MACHINE
 *
 * FW:0x0208AC  —  Called from the main loop on each iteration.
 * Checks for pending events, manages state transitions.
 * ===================================================================== */

/*
 * scanner_state_machine()
 * FW:0x0208AC  —  Main state machine, runs in Context A.
 *
 * Reads scanner_state (0x40077C), task_code (0x400778), and
 * scan_progress (0x40077A) to determine current state and drive
 * transitions. Does NOT use a function pointer table — it reads
 * task codes and branches directly.
 */
void scanner_state_machine(void)                       /* FW:0x0208AC */
{
    uint16_t state   = ram_scanner_state & 0xFF;
    uint16_t task    = ram_task_code;
    uint16_t progress = ram_scan_progress;

    switch (state) {
    case STATE_IDLE:
        /* Check if task_code indicates pending work */
        if (task == 0x0010) {
            /* Internal task request: dispatch it */
            uint16_t handler_idx = task_dispatch(task);
            ram_sense_code = handler_idx;  /* Store result */
        }
        break;

    case STATE_ACTIVE_SCAN:
    case STATE_ACTIVE_SCAN2:
        /*
         * Active scan in progress.
         * Check DMA state (progress) for completion or stall:
         *   0x0330 = scan buffer full (stalled)
         *   0x0340 = scan position complete
         *   0x0320 = scan direction change complete
         *   0x3000 = resolution-dependent handling
         *   0x2000 = check sub-states (0x0110, 0x0120, 0x0121)
         */
        if (progress == 0x0330) {
            /* Buffer stall: dispatch to handle it */
            uint16_t idx = task_dispatch(progress);
            ram_sense_code = idx;
            ram_scan_progress = 0;
            ram_task_code = 0;
        }
        else if (progress == 0x0340 || progress == 0x0320) {
            uint16_t idx = task_dispatch(progress);
            ram_sense_code = idx;
            ram_scan_progress = 0;
            ram_task_code = 0;
        }
        else if (progress == 0x3000) {
            /* Resolution-dependent: check color mode at 0x400E92 */
            if (*(volatile uint8_t *)0x400E92 == 6) {
                ram_scan_progress = 0x9000;
            }
        }
        else if (progress == 0x2000) {
            /* Check init sub-states */
            if (task == 0x0110 || task == 0x0120 || task == 0x0121) {
                /* Init in progress, continue monitoring */
            }
        }
        break;

    case STATE_EJECTING:
        /* Ejecting media — report sense 0x000D */
        ram_sense_code = SENSE_EJECTING;
        break;

    case STATE_SENSOR_ERROR:
        ram_sense_code = SENSE_BECOMING_READY_USB;     /* 0x0008 */
        break;

    case STATE_MOTOR_ERROR:
        ram_sense_code = SENSE_BECOMING_READY_ENC;     /* 0x0009 */
        break;

    case STATE_MOTOR_BUSY:
        ram_sense_code = SENSE_MOTOR_BUSY;             /* 0x0079 */
        break;

    case STATE_CAL_BUSY:
        ram_sense_code = SENSE_CAL_IN_PROGRESS;        /* 0x007A */
        break;

    default:
        if ((state & 0xF0) == 0x20) {
            /* Setup phase (0x20-0x2F): specific handling */
            if (state == 0x22) {
                ram_sense_code = SENSE_BECOMING_READY;  /* 0x0007 */
            }
        } else {
            ram_sense_code = SENSE_BECOMING_READY;      /* 0x0007 */
        }
        break;
    }
}


/* =====================================================================
 * PART 13 — SCAN STATE MACHINE AND WORKFLOW
 *
 * The 45 scan tasks (0x08xx) at FW:0x40000-0x45300.
 * 12 "giant functions" implement all scan modes.
 * ===================================================================== */

/*
 * Scan execution flow (pipeline):
 *
 *   Host SCSI SCAN (0x1B) or Vendor C1 trigger
 *     -> C1 handler (FW:0x28B08) decodes subcode
 *     -> Stores task code to ram_task_code (0x400778)
 *     -> Main loop reads task code
 *     -> task_dispatch(0x20DBA) maps code to handler index
 *     -> Adapter dispatch selects entry point (one of 4)
 *     -> Entry: F12 (common init) -> mode setup -> F2 (orchestrator)
 *     -> F2 calls F3-F6 in sequence
 *     -> Inner loop at 0x40000 processes each CCD line
 *     -> Scan complete -> recovery task 0x0F20
 */

/*
 * State transition pipeline during a scan:
 *
 * INIT PHASE:
 *   0x0110 -> Init step 1 (scan parameter setup)
 *   0x0120 -> Init step 2 (hardware config)
 *   0x0121 -> Init step 3 (final config)
 *
 * MOTOR POSITIONING:
 *   0x0300 -> Absolute move (to scan start position)
 *   0x0310 -> Relative move (fine positioning)
 *   0x0380 -> Slow precision move
 *   0x0390 -> Return to home/reference
 *
 * FOCUS:
 *   0x0400 -> Focus motor positioning
 *   0x0450 -> Extended focus (fine adjustment)
 *
 * CALIBRATION:
 *   0x0501 -> Calibration data acquisition
 *
 * EXPOSURE SETUP:
 *   0x0930 -> Exposure parameter computation
 *   0x0940 -> Exposure timing set
 *
 * SCAN EXECUTION:
 *   0x08xx -> Scan task (group + variant determines mode)
 *             Inner loop processes each CCD line
 *
 * COMPLETION / ERROR:
 *   0x0F20 -> Recovery/cleanup (on error or completion)
 */


/* Scan entry points — one per adapter type (FW:0x40630) */
typedef void (*scan_entry_fn)(void);

/*
 * Each entry point follows the pattern:
 *   JSR @F12 (common init)  -> JSR @mode_setup -> JMP @F2 (orchestrator)
 */
void scan_entry_strip(void)    /* FW:0x40630 — Strip adapter (bit 0x08) */
{
    scan_common_init();                                /* JSR 0x044E40 (F12) */
    scan_mode_strip_setup();                           /* JSR 0x04536E */
    scan_orchestrator();                               /* JMP 0x040660 (F2) */
}

void scan_entry_mount(void)    /* FW:0x4063C — Mount adapter (bit 0x04) */
{
    scan_common_init();
    scan_mode_mount_setup();                           /* JSR 0x045390 */
    scan_orchestrator();
}

void scan_entry_240(void)      /* FW:0x40648 — 240/APS adapter (bit 0x20) */
{
    scan_common_init();
    scan_mode_240_setup();                             /* JSR 0x0453CA */
    scan_orchestrator();
}

void scan_entry_feeder(void)   /* FW:0x40654 — Feeder adapter (bit 0x40) */
{
    scan_common_init();
    scan_mode_feeder_setup();                          /* JSR 0x0453D6 */
    scan_orchestrator();
}


/*
 * scan_adapter_dispatch()
 * FW:0x3C400  —  Routes to the correct scan entry point
 *                based on the adapter type bitmask.
 */
void scan_adapter_dispatch(void)                       /* FW:0x3C400 */
{
    uint8_t adapter = ram_adapter_type;                /* @0x400F22 */

    switch (adapter) {
    case 0x04: scan_entry_mount();   break;            /* Entry B */
    case 0x08: scan_entry_strip();   break;            /* Entry A */
    case 0x20: scan_entry_240();     break;            /* Entry C */
    case 0x40: scan_entry_feeder();  break;            /* Entry D */
    case 0x01: /* alternate path */ break;             /* 0x3C43C */
    case 0x02: /* alternate path */ break;             /* 0x3C460 */
    }
}


/*
 * The 12 giant functions (FW:0x40000-0x45300):
 *
 * F1  (0x40318,  792B)  Scan step core — per-line pixel processing
 * F2  (0x40660,  670B)  Scan orchestrator — central coordinator
 * F3  (0x408FE, 2282B)  ASIC channel config + timing
 * F4  (0x411E8,  764B)  ASIC DMA register programming
 * F5  (0x414E4, 2498B)  CCD pixel transfer (per-channel readout)
 * F6  (0x41EE8, 2630B)  Resolution/adapter scan setup
 * F7  (0x4292E, 1276B)  Calibration scan routine
 * F8  (0x42E2A, 3790B)  Multi-pass scan orchestrator
 * F9  (0x43D2A,  184B)  Scan parameter computation
 * F10 (0x43DE2, 4076B)  Full scan pipeline (direct mode)
 * F11 (0x44DCE,  114B)  Timing computation
 * F12 (0x44E40, 1216B)  Common scan initialization
 *
 * All delimited by push_context/pop_context idiom.
 * Total: ~20KB of scan logic.
 */


/*
 * scan_orchestrator()
 * FW:0x040660 (F2)  —  The central scan coordinator.
 *
 * After entry point initialization, sequences the scan operation
 * through calibration, config, DMA setup, pixel transfer, and
 * the inner per-line loop.
 */
void scan_orchestrator(void)                           /* FW:0x040660 */
{
    push_context();

    /* Step 1: Calibration loop until stable */
    while (!calibration_stable())
        calibrate();                                   /* JSR 0x039C6C */

    /* Step 2: Check command state */
    uint8_t cmd = ram_cmd_state;

    if (cmd == 0x01 || cmd == 0x04) {
        /* Scan data mode: proceed with scan */
        scan_config_asic();                            /* F3: JSR 0x408FE */
        scan_program_dma();                            /* F4: JSR 0x411E8 */
        scan_ccd_pixel_transfer();                     /* F5: JSR 0x414E4 */
        scan_resolution_setup();                       /* F6: JSR 0x41EE8 */

        /* Call scan pipeline functions */
        scan_pipeline_a();                             /* JSR 0x2D4E2 */
        scan_pipeline_b();                             /* JSR 0x2D598 */
        scan_pipeline_c();                             /* JSR 0x2D7AE */

        /* Motor/ASIC coordination */
        motor_asic_setup();                            /* JSR 0x358EC */
        motor_scan_start();                            /* JSR 0x37D18 */
        motor_scan_coord();                            /* JSR 0x37338 */
    }
    else if (cmd == 0x05) {
        /* Calibration data: calibration scan variant */
        calibration_scan();                            /* F7: JSR 0x4292E */
    }
    else {
        /* Alternative path */
        /* 0x407BE handler */
    }

    pop_context();
}


/*
 * inner_scan_loop()
 * FW:0x040000  —  Pre-function state machine (NOT a standard function).
 *
 * Called repeatedly during an active scan to process each CCD line.
 * 792 bytes. Dispatches on ram_task_code (0x400778) for motor states.
 */
void inner_scan_loop(void)                             /* FW:0x040000 */
{
    for (;;) {
        /* Read scan descriptor */
        uint32_t desc = *(volatile uint32_t *)0x406E6A;

        /* Configure next scan line via ASIC */
        asic_configure_next_line(desc);                /* JSR 0x35A9A */

        /* Check task state for motor positioning */
        uint16_t task = ram_task_code;

        switch (task) {
        case 0x0300:  /* Motor: absolute positioning */
        case 0x0310:  /* Motor: relative move */
            /* Wait for motor, yield */
            yield();
            continue;

        case 0x0320:  /* Motor: scan direction set */
            /* Update scan direction */
            break;

        case 0x0330:  /* Motor: scan buffer stall */
            /* Wait for buffer, yield */
            yield();
            continue;
        }

        /* Check scan active flag */
        if (!(ram_scanner_flags & 0x0080))             /* bit 7 */
            break;

        /* Trigger ASIC DMA for this scan line */
        ASIC_CMD = 0x02;                               /* Write 0x02 to 0x200001 */

        /* Poll ASIC DMA busy */
        while (ASIC_STATUS & 0x08) {                   /* Bit 3 of 0x200002 */
            yield();                                   /* Yield between polls */
        }

        /* DMA complete: process pixels */
        scan_step_core();                              /* F1: JSR 0x40318 */

        /* Update scan status */
        *(volatile uint8_t *)0x4052EF = /* scan status */;
        ram_scan_active = /* active flag */;
    }
}


/*
 * scan_common_init()
 * FW:0x044E40 (F12)  —  Called by all 4 entry points as first step.
 *
 * Performs adapter detection, ASIC base config, timing setup,
 * scan area initialization, and USB data transfer setup.
 */
void scan_common_init(void)                            /* FW:0x044E40 */
{
    push_context();

    /* Adapter detection and configuration */
    uint8_t adapter = ram_adapter_type;

    /* ASIC base configuration */
    /* ... register writes to 0x200xxx ... */

    /* Timing setup (calls F11 for timing computation) */
    scan_timing_compute();                             /* F11: JSR 0x44DCE */

    /* Scan area parameter initialization */
    /* References: 0x400F30-0x400F34 (scan config area) */

    /* USB data transfer setup */
    usb_data_transfer_setup();                         /* JSR 0x12360 */

    pop_context();
}


/*
 * Scan task code encoding:
 *
 * Task code = 0x08GV
 *   G = Group (0-B): scan type
 *   V = Variant (0-4): adapter variant
 *
 * Built at runtime:
 *   task_code = 0x08G0 | (adapter_variant_byte + 1)
 *
 * Scan modes:
 *   Group 0-2: Preview (low/medium/full resolution), handler 0x22
 *   Group 3:   Fine scan, 8-bit RGB (no infrared), handlers 0x15-0x19
 *   Group 4:   Fine scan, 8-bit RGBI (with Digital ICE), handlers 0x42-0x46
 *   Group 5:   Fine scan, 14-bit RGB, handlers 0x23-0x27
 *   Group 6:   Fine scan, 14-bit RGBI, handlers 0x33-0x37
 *   Group 7:   Multi-pass scan (multi-exposure HDR), handlers 0x38-0x3C
 *   Group 8:   Multi-pass + ICE, handlers 0x47-0x4B
 *   Group 9-B: Extended multi-sample (late FW addition), handlers 0x85-0x90
 *
 * Multi-pass scanning: Multiple CCD exposures per line for improved
 * dynamic range. Managed by F8 (multi-pass orchestrator, 3790 bytes).
 *
 * Preview vs Final:
 *   Preview (groups 0-2) shares handler 0x22 and uses lower resolution.
 *   Final (groups 3+) uses adapter-specific variants.
 *   The handler index determines which giant function(s) are called.
 */


/* =====================================================================
 * PART 14 — USB COMMUNICATION LAYER (ISP1581)
 *
 * Firmware USB code: 0x12200-0x15200 (shared handler module)
 * Total ISP1581 code: ~3,750 bytes
 * ===================================================================== */

/*
 * USB Device Configuration:
 *   VID:  0x04B0 (Nikon Corporation)
 *   PID:  0x4001 (Coolscan V / LS-50)
 *   Class: 0xFF/0xFF/0xFF (vendor-specific, NOT Mass Storage)
 *   Endpoints:
 *     EP1 OUT Bulk — CDB and data-out (host -> scanner)
 *     EP2 IN  Bulk — phase query, data-in, sense (scanner -> host)
 *   Max packet size: 64B (USB 1.1) / 512B (USB 2.0)
 *   Power: Self-powered (bmAttributes=0xC0)
 *   bcdDevice: 0x0102
 *
 * Descriptor locations in flash:
 *   0x170FA: USB 1.1 Device Descriptor (18 bytes)
 *   0x1710C: USB 2.0 Device Descriptor (18 bytes)
 *   0x1711E: USB 1.1 Endpoint templates (EP1 OUT 64B, EP2 IN 64B)
 *   0x1712E: USB 2.0 Endpoint templates (EP1 OUT 512B, EP2 IN 512B)
 *   0x1713E: USB 1.1 Config Descriptor
 *   0x17148: USB 2.0 Config Descriptor
 *   0x170D6: INQUIRY string "Nikon   LS-50 ED        1.02" + serial
 */


/*
 * usb_endpoint_read()
 * FW:0x012258  —  Read bulk data from ISP1581 EP data register into RAM.
 *
 * ISP1581 data register is 16-bit; USB data is byte-oriented.
 * Handles endian conversion (ISP1581=LE, H8/3003=BE).
 */
void usb_endpoint_read(uint8_t *dest, uint16_t byte_count)  /* FW:0x012258 */
{
    uint16_t words = byte_count >> 1;

    for (uint16_t i = 0; i < words; i++) {
        uint16_t w = ISP_EP_DATA;                      /* Read 16-bit from 0x600020 */
        *dest++ = w & 0xFF;                            /* Low byte first (LE USB) */
        *dest++ = w >> 8;                              /* High byte */
    }

    if (byte_count & 1) {
        uint16_t w = ISP_EP_DATA;                      /* Read final word */
        *dest++ = w & 0xFF;                            /* Only low byte used */
    }
}


/*
 * usb_endpoint_write()
 * FW:0x0122C4  —  Write data from RAM to ISP1581 EP data register.
 */
void usb_endpoint_write(const uint8_t *src, uint16_t byte_count)
                                                       /* FW:0x0122C4 */
{
    ISP_EP_INDEX = byte_count;                         /* Write count to 0x60001C */

    uint16_t words = byte_count >> 1;

    for (uint16_t i = 0; i < words; i++) {
        uint16_t w = src[0] | ((uint16_t)src[1] << 8); /* Pack LE word */
        ISP_EP_DATA = w;                               /* Write to 0x600020 */
        src += 2;
    }

    if (byte_count & 1) {
        ISP_EP_DATA = *src;                            /* Final odd byte */
    }
}


/*
 * usb_soft_connect() / usb_soft_disconnect()
 * FW:0x0139B8-0x0139D8  —  ISP1581 SOFTCT bit control.
 *
 * The ISP1581 Mode register bit 4 (SOFTCT) controls the USB
 * pull-up resistor. Setting it disconnects the device from the bus.
 */
void usb_soft_disconnect(void)                         /* FW:0x0139B8 */
{
    *(volatile uint8_t *)0x407DDE = 0;                 /* Clear reset flag */

    uint16_t mode = ISP_MODE;                          /* Read 0x60000C */
    mode |= (1 << 4);                                 /* Set SOFTCT bit */
    ISP_MODE = mode;                                   /* Device disconnected */
}

void usb_soft_connect(void)                            /* FW:0x0139D0 */
{
    uint16_t mode = ISP_MODE;
    mode &= ~(1 << 4);                                /* Clear SOFTCT bit */
    ISP_MODE = mode;                                   /* Device visible on bus */

    *(volatile uint8_t *)0x407DE0 = 1;                 /* Connected flag */
    ram_usb_reset_flag = 1;                            /* Trigger reset handler */
    ram_usb_conn_state = 0;                            /* Not yet configured */
    *(volatile uint8_t *)0x407DC8 = 0;                 /* Clear retry counter */
}


/*
 * usb_handle_bus_reset()
 * FW:0x013A20  —  Called when USB bus reset is detected.
 *
 * Reinitializes all USB state, ASIC USB path, and ISP1581 endpoints.
 */
void usb_handle_bus_reset(void)                        /* FW:0x013A20 */
{
    /* Reset ASIC-side USB interface */
    ASIC_CMD = 0x02;                                   /* Write to 0x200001 */

    /* Initialize timeout timer */
    usb_init_timer(0x4007D6, 8);                       /* JSR 0x013920 */

    /* Clear task budget */
    ram_task_budget = 0;

    /* Clear all USB state variables */
    *(volatile uint8_t *)0x407DD9 = 0;                 /* Interrupt mask */
    ram_usb_reset_flag = 0;
    ram_error_flag = 0;
    *(volatile uint8_t *)0x407DDD = 0;                 /* DMA completion */
    *(volatile uint8_t *)0x407DDC = 0;                 /* DMA direction */
    *(volatile uint8_t *)0x407DDB = 0;                 /* DMA state */
    *(volatile uint8_t *)0x407DD8 = 0;                 /* Stall flags */
    ram_usb_conn_state = 0;                            /* Session state */
    *(volatile uint8_t *)0x407DC8 = 0;                 /* Retry counter */
    *(volatile uint8_t *)0x400087 = 0;

    /* Install endpoint callback table */
    uint32_t callback = *(volatile uint32_t *)0x400DC8;
    *(volatile uint32_t *)0xFD44 = callback;

    /* Clear additional state */
    *(volatile uint32_t *)0x400DD8 = 0;
    *(volatile uint8_t *)0x400DDC = 0;
    *(volatile uint8_t *)0x400E5E = 0;
    *(volatile uint8_t *)0x400E5D = 0;

    /* Clear per-endpoint state (4 endpoints) */
    for (int i = 0; i < 4; i++)
        *(volatile uint8_t *)(0x400B20 + i) = 0;

    /* Re-enable ASIC USB path */
    ASIC_DAC_MODE = 0x20;                              /* Write to 0x2000C2 */

    pop_context();
}


/*
 * usb_response_manager()
 * FW:0x01374A  —  Manages USB bulk-in response transfers.
 *
 * Checks endpoint busy, sets up ISP1581 DMA, starts bulk transfer.
 * Special fast-path for D0 phase query (no data transfer).
 */
void usb_response_manager(uint8_t cmd_phase)           /* FW:0x01374A */
{
    if (ram_usb_txn_active)
        return;                                        /* Already active */

    *(volatile uint8_t *)0x407DC6 = cmd_phase;         /* Store command phase */

    usb_setup_isp1581_dma();                           /* JSR 0x13C70 */

    /* Wait for DMA completion (may yield) */
    yield();                                           /* JSR 0x0109E2 */

    ram_usb_txn_active = 1;                            /* Mark active */
}


/*
 * usb_install_ram_code()
 * FW:0x012486  —  Copy critical USB handler code from flash to RAM.
 *
 * Copies 414 bytes from FW:0x124BA to RAM at 0x4010A0.
 * During high-speed USB DMA, code executing from flash may conflict
 * with DMA bus accesses. Running from RAM avoids bus contention.
 */
void usb_install_ram_code(void)                        /* FW:0x012486 */
{
    const uint16_t *src = (const uint16_t *)0x124BA;   /* Flash source */
    uint16_t *dst = (uint16_t *)0x4010A0;              /* RAM destination */
    const uint16_t *end = (const uint16_t *)0x12658;   /* End of code block */

    while (src < end) {
        *dst++ = *src++;                               /* Copy word by word */
    }
    /* 414 bytes (0x19E) copied */

    /* Jump tables redirect to RAM:
     *   0x01247E: JMP @0x4010A0  (primary entry)
     *   0x012482: JMP @0x4011A2  (alternate entry)
     */
}


/* =====================================================================
 * PART 15 — ISP1581 INTERRUPT HANDLER (IRQ1)
 *
 * FW:0x014E00  —  ISP1581 USB interrupt service routine.
 * Trampoline: Vec 13 -> 0xFFFD3C -> JMP 0x014E00
 * ===================================================================== */

/*
 * isp1581_irq_handler()
 * FW:0x014E00  —  USB interrupt handler (IRQ1).
 *
 * Fires when the ISP1581 generates an interrupt:
 *   - Endpoint event (new CDB arrived on bulk-out)
 *   - Bus reset
 *   - DMA completion
 *
 * This is the entry point for all USB-initiated events.
 */
void isp1581_irq_handler(void)                         /* FW:0x014E00 */
{
    /* Read ISP1581 interrupt status */
    uint16_t int_status = ISP_INT_STATUS;              /* Read 0x600008 */

    /* Check for endpoint events (bit 3) */
    if (int_status & 0x08) {
        /* New data on bulk-out endpoint.
         * Read CDB bytes from endpoint data register. */
        uint8_t *cdb = (uint8_t *)ram_cdb_buffer;     /* -> 0x4007DE */

        /* Read CDB words from ISP1581 */
        for (int i = 0; i < 8; i++) {                  /* 16 bytes max */
            uint16_t w = ISP_EP_DATA;                  /* Read 0x600020 */
            cdb[i*2]     = w & 0xFF;
            cdb[i*2 + 1] = w >> 8;
        }

        /* Extract SCSI opcode (byte 0 of CDB) */
        ram_scsi_opcode = cdb[0];                      /* -> 0x4007B6 */

        /* Signal "command pending" to main loop */
        ram_cmd_pending = 1;                           /* -> 0x400082 */

        /* Update USB state variables */
        /* ... (0x407Dxx block updates) ... */
    }

    /* Check for bus reset */
    if (int_status & /* bus_reset_bit */) {
        /* Set bus reset flag for main loop to handle */
        ram_usb_reset_flag = 1;
    }

    /* Clear interrupt by writing back modified status */
    ISP_INT_STATUS = int_status;                       /* Ack interrupt */

    /* RTE at 0x014EA4 */
}


/* =====================================================================
 * PART 16 — TIMER INTERRUPT HANDLERS
 * ===================================================================== */

/*
 * itu2_motor_dispatcher()
 * FW:0x010B76  —  ITU2 Compare A ISR (Vector 32).
 *
 * Motor mode dispatcher. Reads motor_mode from RAM and dispatches
 * to the appropriate motor step handler. Started/stopped per
 * motor movement (BSET/BCLR #2, TSTR).
 */
void itu2_motor_dispatcher(void)                       /* FW:0x010B76 */
{
    /* Push ER1, ER0 */

    switch (ram_motor_mode) {                          /* @0x400774 */
    case MOTOR_MODE_SCAN:                              /* 2 */
        scan_motor_step();                             /* JSR 0x02E268 */
        break;

    case MOTOR_MODE_AF:                                /* 3 */
        af_motor_step();                               /* JSR 0x02EDC0 */
        break;

    case MOTOR_MODE_ENCODER:                           /* 4 */
        encoder_special();                             /* JSR 0x03337E */
        break;

    case MOTOR_MODE_SCAN_REV:                          /* 6 */
        scan_motor_step_reverse();                     /* JSR 0x02E276 */
        break;

    default:
        break;                                         /* No-op */
    }

    /* Pop, RTE */
}


/*
 * itu4_system_tick()
 * FW:0x010A16  —  ITU4 Compare A ISR (Vector 40).
 *
 * System tick timer. Started ONCE at init (BSET #4, TSTR at 0x010A10),
 * never stopped. Increments the global timestamp and polls for scan
 * data ready to transfer via USB.
 */
void itu4_system_tick(void)                            /* FW:0x010A16 */
{
    /* Clear interrupt flag (TSR4) */

    /* Increment global timestamp */
    ram_timestamp++;                                   /* @0x40076E */

    /* Check for active USB transfer */
    if (ram_xfer_state != 0) {
        /* Continue existing transfer */
        continue_usb_transfer();
        return;
    }

    /* Check for new scan data ready */
    if (ram_cmd_state == 0x04) {                       /* Scan data ready */
        if (ram_scan_status == 0x03) {                 /* Buffer full */
            usb_push_scan_data();                      /* JSR 0x10B3E */
        }
    }
    else if (ram_cmd_state == 0x05) {                  /* Calibration data */
        if (ram_scan_status == 0x03) {
            usb_push_scan_data();
        }
    }

    /* RTE */
}


/*
 * itu3_dma_coordinator()
 * FW:0x02D536  —  ITU3 Compare A ISR (Vector 36).
 *
 * Manages CCD line DMA bursts. Counts down bursts per scan line,
 * then dispatches based on DMA mode when the full line is complete.
 */
void itu3_dma_coordinator(void)                        /* FW:0x02D536 */
{
    /* Clear DMA interrupt flag */

    /* Decrement burst counter */
    ram_dma_burst_ctr--;                               /* @0x406374 */

    if (ram_dma_burst_ctr != 0)
        return;                                        /* More bursts remaining */

    /* Full CCD line transfer complete — dispatch by mode */
    switch (ram_dma_mode) {                            /* @0x4052D6 */
    case 1:
        /* Scan line callback */
        scan_line_complete_callback();                 /* JSR 0x2CEB2 */
        break;

    case 2:
        /* Set state 3 (buffer full), trigger next DMA */
        ram_scan_status = 3;
        /* Re-trigger ASIC DMA */
        break;

    case 6:
        /* Cleanup */
        dma_cleanup();                                 /* JSR 0x2D4B2 */
        break;
    }

    /* RTE */
}


/*
 * irq3_encoder_isr()
 * FW:0x033444  —  IRQ3 handler (Vector 15).
 *
 * Motor encoder pulse ISR. Counts pulses and measures inter-pulse
 * timing for position and speed feedback.
 */
void irq3_encoder_isr(void)                            /* FW:0x033444 */
{
    /* Push ER1, ER0 */

    /* Increment encoder pulse count */
    volatile uint16_t *count = (volatile uint16_t *)0x40530E;
    (*count)++;

    /* Measure inter-pulse timing */
    uint16_t current_timer = *(volatile uint16_t *)0x400770;
    uint16_t previous      = *(volatile uint16_t *)0x40531A;
    uint16_t delta          = current_timer - previous;

    *(volatile uint16_t *)0x405314 = delta;            /* Speed measurement */
    *(volatile uint32_t *)0x405318 = ram_timestamp;    /* Timestamp */

    /* Check for special encoder mode (0xD1) */
    if (*(volatile uint8_t *)0x40530A == 0xD1)
        encoder_special_processing();                  /* BSR 0x033A0C */

    /* Pop, RTE */
}


/*
 * irq7_motor_step_isr()
 * FW:0x02B544  —  IRQ7 handler (Vector 19).
 *
 * Motor step completion / scan segment initialization.
 * Fires on external interrupt (limit switch or auxiliary encoder).
 * 392 bytes.
 */
void irq7_motor_step_isr(void)                        /* FW:0x02B544 */
{
    /* Read motor state from 0x4052EA */
    /* Check I/O register 0xFFFF3C (timer counter) */

    /* Set task code for motor positioning */
    ram_task_code = 0x0310;

    /* Initialize scan config variables (0x400E9x range) */
    /* Set calibration values (0x400B8A, 0x400B8C) */

    /* Update scan state: 0x4052E8, 0x4052EC, 0x4052ED */

    /* RTE at 0x2B6CC */
}


/*
 * vec49_ccd_readout_isr()
 * FW:0x02E9F8  —  CCD line readout / DMA coordination (Vector 49).
 *
 * Manages per-line CCD readout timing. Reads I/O register 0xFFFF4C,
 * triggers ASIC DMA (0x200001), controls CCD timing (0x2001C1).
 */
void vec49_ccd_readout_isr(void)                       /* FW:0x02E9F8 */
{
    /* Read I/O timer register 0xFFFF4C */

    /* Check scan active flag */
    if (!ram_scan_active)
        return;

    /* Trigger ASIC DMA */
    ASIC_CMD = /* DMA trigger value */;                /* 0x200001 */

    /* Update CCD line timing */
    ASIC_LINE_CTRL = /* timing value */;               /* 0x2001C1 */

    /* Manage pixel transfer state:
     *   0x4052F0/F2 scan status
     *   0x405284/5288 pixel descriptors
     *   0x4058FC line counter
     *   0x4062DC/DD channel data
     *   0x406DB6 line descriptor
     */

    /* RTE */
}


/*
 * adc_complete_isr()
 * FW:0x02EDDE  —  A/D conversion complete ISR (Vector 60).
 *
 * Tests ADF flag (ADCSR bit 7 at 0xFFFFE8). Used for analog
 * measurements (lamp intensity, CCD temperature, etc.).
 */
void adc_complete_isr(void)                            /* FW:0x02EDDE */
{
    /* Test ADCSR bit 7 (ADF = A/D conversion complete) */
    if (ADCSR & 0x80) {
        /* Read A/D result */
        /* Store measurement */
        /* Clear ADF flag */
    }

    /* RTE at 0x02EE94 */
}


/* =====================================================================
 * PART 17 — SCAN DATA PIPELINE (CCD -> USB)
 *
 * Five pipeline stages move pixel data from CCD to host:
 *   1. CCD -> ASIC RAM (ASIC internal DMA)
 *   2. ASIC RAM line counting (ITU3 ISR)
 *   3. Pixel processing (minimal: bit extraction only)
 *   4. USB staging (ITU4 polls for data)
 *   5. USB bulk transfer (ISP1581 DMA)
 *
 * Key design insight: The firmware does MINIMAL pixel processing.
 * Only bit extraction from 16-bit CCD words. ALL calibration
 * correction (dark subtraction, white normalization, gamma,
 * color balance) is performed HOST-SIDE by NikonScan software.
 * ===================================================================== */

/*
 * Pipeline overview:
 *
 * CCD Sensor (tri-linear R/G/B + optional IR for Digital ICE)
 *   |  analog signal -> ASIC ADC -> 16-bit digital
 *   v
 * ASIC Analog Front-End (0x200000)
 *   |  DAC config: 0x2000C0-C7
 *   |  Integration timing: 0x200408-425
 *   |  Per-channel windows: 0x20046D-487
 *   v
 * ASIC Internal DMA
 *   |  Config: 0x200142-14D
 *   |  Buffer addr: 0x200147/148/149 -> target 0x800000
 *   |  Trigger: write 0x80 to 0x2001C1
 *   |  Poll: read 0x200002 bit 3 until clear
 *   |  Ack: write 0xC0 to 0x200001
 *   v
 * ASIC RAM (0x800000, 224KB) — CCD line buffer
 *   |  16 banks (4 @ 32KB spacing + 12 @ 8KB spacing)
 *   |  Bank addresses: 0x800000, 0x808000, 0x810000, ...
 *   v
 * ITU3 ISR (Vec 36) counts DMA bursts per scan line
 *   |  Counter: ram_dma_burst_ctr (0x406374)
 *   |  Mode: ram_dma_mode (0x4052D6)
 *   |  On line complete: scan_line_complete_callback (0x2CEB2)
 *   |  Sets ram_scan_status = 3 when buffer full
 *   v
 * Pixel Processing (FW:0x36C90-0x37A8C)
 *   |  shlr.w for bit-depth extraction (14-bit -> usable bits)
 *   |  Process in 4KB-16KB blocks with yield between blocks
 *   |  4 color channels: R/G/B/IR
 *   |  Dual banks: 0x800000 (primary) + 0x418000 (secondary)
 *   v
 * Buffer RAM (0xC00000, 64KB) — USB staging
 *   |  Calibration uses ping-pong: 0xC00000 (A) + 0xC08000 (B)
 *   v
 * ITU4 System Tick (Vec 40) polls for scan data
 *   |  Checks: ram_cmd_state == 4 (scan data ready)
 *   |  Checks: ram_scan_status == 3 (buffer full)
 *   |  Transfer mode dispatch (0x10B3E):
 *   |    Mode 2 -> block transfer (0x02E268)
 *   |    Mode 3 -> streaming (0x02EDC0)
 *   |    Mode 4 -> scan line (0x3337E)
 *   |    Mode 6 -> calibration (0x02E276)
 *   v
 * USB Response Manager (FW:0x01374A)
 *   |  ISP1581 DMA setup: 0x13C70
 *   |  Bulk transfer start: 0x13F3A
 *   |    DMA direction = host-read (0x8000 -> 0x600018)
 *   |    DMA mode = bulk (0x0005 -> 0x60002C)
 *   |    Enable (0x0001 -> 0x60001C)
 *   v
 * ISP1581 USB Controller (0x600000)
 *   |  EP2 IN Bulk -> Host
 *   v
 * Host PC (NikonScan via NKDUSCAN.dll)
 */


/* =====================================================================
 * PART 18 — MOTOR CONTROL SUBSYSTEM
 * ===================================================================== */

/*
 * Two stepper motors:
 *   SCAN Motor — drives the scanning carriage along the film
 *   AF Motor   — positions the autofocus lens
 *
 * Driven by timer-interrupt-based stepper sequences via ITU2.
 * Wave drive (unipolar 4-phase, single-phase excitation):
 *   Forward: 01, 02, 04, 08  (FW:0x16E92)
 *   Reverse: 08, 04, 02, 01  (FW:0x4A8A8)
 *
 * Speed ramp table (FW:0x16C38): 33 entries, linear 56-312 (step 8).
 * Timer compare values — smaller = faster stepping.
 *
 * Motor output: Port A DR (0xFFFFA3) — stepper phase values.
 * Direction: Port 3 DDR (0xFFFF84) bit 0.
 * Encoder: Port 9 DR (0xFFFFC8).
 * Adapter ID: Port 7 DR (0xFFFF8E).
 *
 * AUTOFOCUS is HOST-DRIVEN: firmware provides only basic motor
 * positioning. NikonScan runs the contrast-based AF algorithm.
 */

static const uint8_t stepper_phase_fwd[4] = { 0x01, 0x02, 0x04, 0x08 };
static const uint8_t stepper_phase_rev[4] = { 0x08, 0x04, 0x02, 0x01 };

/* Linear speed ramp: 33 entries (FW:0x16C38) */
static const uint16_t speed_ramp[33] = {
     56,  64,  72,  80,  88,  96, 104, 112, 120, 128,
    136, 144, 152, 160, 168, 176, 184, 192, 200, 208,
    216, 224, 232, 240, 248, 256, 264, 272, 280, 288,
    296, 304, 312
};


/*
 * motor_setup()
 * FW:0x02E158  —  Configure ITU2 and start a motor movement.
 */
void motor_setup(void)                                 /* FW:0x02E158 */
{
    /* 1. Set motor_enable_flag at 0x4052EA */
    *(volatile uint8_t *)0x4052EA = 1;

    /* 2. Clear GRA1 compare register */
    /* 3. Stop ITU1 */
    /* 4. Load ramp config from 0x400CC8 */

    /* 5. Calculate initial timer period */
    /* Uses: jsr 0x0163EA (multiply), jsr 0x015CCC (divide) */

    /* 6. Load counter into TCNT3 */
    /* 7. Set motor direction at 0x400791 */

    /* 8. Configure GRB2 compare register */

    /* 9. Set motor_mode (2, 3, 4, or 6) */
    ram_motor_mode = MOTOR_MODE_SCAN;                  /* Or AF, etc. */

    /* 10. Configure TIER3 interrupt enable */

    /* 11. START ITU2 */
    TSTR |= (1 << 2);                                 /* BSET #2, TSTR */
}


/* =====================================================================
 * PART 19 — LAMP CONTROL
 * ===================================================================== */

/*
 * Lamp GPIO: Port 4 DDR (0xFFFF85), bit 0.
 * Open-drain pattern:
 *   BCLR #0 = set to input = lamp ON  (pull-up activates circuit)
 *   BSET #0 = set to output = lamp OFF
 *
 * All 6 lamp-on sites use the same pattern:
 *   mov.b #0xA3, r0l
 *   mov.b r0l, @(status)
 *   mov.b @0xFF85, r0l
 *   mov.b r0l, @0x400791    ; save to GPIO shadow
 *   bclr  #0, @0xFF85       ; LAMP ON
 *   sub.w r0, r0
 *   mov.w r0, @0xFF86       ; clear adjacent port
 */

void lamp_on(void)
{
    ram_gpio_shadow = P4DDR;                           /* Save GPIO state */
    P4DDR &= ~0x01;                                   /* BCLR #0 -> lamp ON */
}

void lamp_off(void)
{
    P4DDR |= 0x01;                                    /* BSET #0 -> lamp OFF */
}


/* =====================================================================
 * PART 20 — CALIBRATION SUBSYSTEM
 * ===================================================================== */

/*
 * Three calibration task codes:
 *   0x0500 (handler 0x31) — Primary calibration
 *   0x0501 (handler 0x32) — Secondary calibration
 *   0x0502 (handler 0x30) — Shared handler (reuses scan infrastructure)
 *
 * DAC mode register (ASIC 0x2000C2):
 *   0x20 = Init/basic (after USB bus reset)
 *   0x22 = Normal scan
 *   0xA2 = Calibration (bit 7 = calibration enable)
 *
 * Four calibration routines:
 *   0x3D12D, 0x3DE51, 0x3EEF9, 0x3F897
 *
 * Each routine:
 *   1. Write 0xA2 to 0x2000C2 (enter cal mode)
 *   2. Read cal params from RAM (0x400F56-0x400F9D)
 *   3. Write to ASIC cal regs (0x2001CA/CB, 0x20014E/152/153)
 *   4. Perform cal scan via Buffer RAM (0xC00000)
 *   5. Compute per-channel min/max from CCD data
 *   6. Update results in RAM (0x400F0A, 0x400F12, 0x400F1A)
 *
 * LS-50 vs LS-5000 (model flag at 0x404E96):
 *   LS-50:   DAC fine = 0x08, coarse gain = 100
 *   LS-5000: DAC fine = 0x00, coarse gain = 180
 *
 * CCD characterization data in flash (FW:0x4A8BC-0x528BD):
 *   ~32KB factory-programmed analog correction levels (0x00-0x0B).
 *   Two sections of 16,385 bytes, accessed via pointer table at 0x4A37E.
 *   Monotonic edge-to-center decay pattern (vignetting compensation).
 *   4 identical bytes per group (4 CCD sub-elements per pixel).
 *   NEVER written at runtime — factory-programmed only.
 */


/* =====================================================================
 * PART 21 — COMPLETE DATA FLOW: HOST COMMAND -> SCANNER -> RESPONSE
 *
 * This section describes the full lifecycle of a SCSI command,
 * from host transmission to scanner response.
 * ===================================================================== */

/*
 * SCSI Command Lifecycle:
 *
 * 1. HOST sends CDB via USB bulk-out pipe:
 *      NikonScan4.ds -> LS5000.md3 -> NKDUSCAN.dll -> USB
 *
 * 2. ISP1581 generates interrupt (IRQ1):
 *      Hardware interrupt fires on the H8/3003.
 *      IRQ1 vector (13) -> trampoline 0xFFFD3C -> ISR at 0x014E00.
 *
 * 3. IRQ1 ISR processes the interrupt:
 *      - Read ISP1581 interrupt status (0x600008)
 *      - Read CDB bytes from EP data register (0x600020)
 *      - Store CDB in RAM at 0x4007DE (16 bytes)
 *      - Extract opcode -> 0x4007B6
 *      - Set command-pending flag (0x400082 = 1)
 *      - RTE (return from exception)
 *
 * 4. Context switch wakes main loop:
 *      If Context A was yielded (in TRAPA #0), the interrupt
 *      wakes the CPU. The TRAP handler returns to the main loop.
 *
 * 5. Main loop detects command (Context A, 0x207F2):
 *      Step 6: usb_check_command_ready() reads 0x400082
 *      Returns non-zero -> command available
 *
 * 6. Main loop dispatches (0x020AE2):
 *      - Clear sense state
 *      - scsi_handler_lookup() (0x020B48):
 *          Linear search table at 0x49834 (10-byte entries)
 *          Match opcode, check permissions, load handler pointer
 *      - Call handler
 *
 * 7a. For SIMPLE commands (INQUIRY, MODE SENSE, etc.):
 *      Handler executes, builds response, returns immediately.
 *      Response sent via usb_response_manager (0x01374A) ->
 *      ISP1581 DMA -> USB bulk-in -> host.
 *
 * 7b. For ACTION commands (SCAN, C1 trigger):
 *      Handler sets up task parameters in RAM:
 *        - task code at 0x400778 or 0x40077C
 *        - scan config at 0x400Dxx, 0x400Exx
 *      Returns to dispatch.
 *      Actual work happens over subsequent main loop iterations.
 *
 * 8. Task execution (for action commands):
 *      Main loop Step 2 reads scan state (0x400778, 0x40077A).
 *      State machine at 0x208AC checks for pending tasks.
 *      task_dispatch(0x20DBA) maps task code to handler index.
 *      task_execute(0x20DD6) runs the handler with time budget.
 *      Yields when budget exhausted or no work.
 *
 * 9. Host polls for completion:
 *      Sends D0 phase query via NKDUSCAN.dll (USB driver layer).
 *      Firmware D0 handler (0x13748, in shared module) returns
 *      current command phase.
 *
 *      Sends 0x00 TEST UNIT READY to check detailed status.
 *      TUR handler (0x0215C2, ~700 bytes) examines scanner state
 *      machine and returns appropriate sense code.
 *
 * 10. Response latency depends on:
 *      - Whether Context A is currently yielded
 *      - Whether a long-running task is executing
 *      - Whether the main loop is in a JSR that doesn't yield
 */


/* =====================================================================
 * PART 22 — PUSH/POP CONTEXT (REGISTER SAVE/RESTORE)
 * ===================================================================== */

/*
 * push_context() / pop_context()
 * FW:0x016458 / FW:0x016436
 *
 * Standard register save/restore used by all major functions.
 * Saves ER3-ER6 (callee-saved registers) to the stack.
 * Every "giant function" and SCSI handler uses this idiom.
 */
void push_context(void)                                /* FW:0x016458 */
{
    /* PUSH ER3, ER4, ER5, ER6 (16 bytes to stack) */
}

void pop_context(void)                                 /* FW:0x016436 */
{
    /* POP ER6, ER5, ER4, ER3 (restore 16 bytes from stack) */
    /* Followed by RTS in caller */
}


/* =====================================================================
 * PART 23 — VENDOR REGISTER TABLE (23 entries at FW:0x4A134)
 *
 * Maps E0/C1/E1 register IDs to max data lengths.
 * Format: 2 bytes per entry (reg_id:8, max_len:8).
 * Terminated by 0xFF marker.
 * ===================================================================== */

typedef struct {
    uint8_t reg_id;
    uint8_t max_len;
} vendor_reg_entry_t;

static const vendor_reg_entry_t vendor_reg_table[23] = {
    { 0x40, 11 },  /* Scan parameters (R/W) */
    { 0x41, 11 },  /* Calibration data (R/W) */
    { 0x42, 11 },  /* Gain values (R/W) */
    { 0x43, 11 },  /* Offset values (R/W) */
    { 0x44,  5 },  /* Motor position (R/W) */
    { 0x45, 11 },  /* Exposure time (R/W) */
    { 0x46, 11 },  /* Focus position (R/W) */
    { 0x47, 11 },  /* Lamp settings (R/W) */
    { 0x80,  0 },  /* Lamp on/off (trigger only, no data) */
    { 0x81,  0 },  /* Motor init (trigger only) */
    { 0x91,  5 },  /* CCD config: direction + count */
    { 0xA0,  9 },  /* Exposure/focus params */
    { 0xB0,  0 },  /* State change A (trigger only) */
    { 0xB1,  0 },  /* State change B (trigger only) */
    { 0xB3, 13 },  /* Motor position extended */
    { 0xB4,  9 },  /* Motor position */
    { 0xC0,  5 },  /* Gain calibration data */
    { 0xC1,  5 },  /* Offset calibration data */
    { 0xD0,  0 },  /* Diagnostic A (trigger only) */
    { 0xD1,  0 },  /* Diagnostic B (trigger only) */
    { 0xD2,  5 },  /* Diagnostic data */
    { 0xD5,  5 },  /* Extended diagnostic */
    { 0xD6,  5 },  /* Persistent settings */
    /* 0xFF terminator */
};

/*
 * The E0->C1->E1 vendor command flow:
 *   1. Host sends E0 (Data Out) with register data
 *   2. Host sends C1 (Trigger) to execute the operation
 *   3. Host sends E1 (Data In) to read results
 *
 * Register IDs match C1 subcommand codes. E0 handler at 0x028E16
 * and E1 handler at 0x0295EA both use this table for validation.
 */


/* =====================================================================
 * PART 24 — READ/WRITE DATA TYPE CODE TABLES
 * ===================================================================== */

/*
 * READ DTC Table (FW:0x49AD8, 15 entries x 12 bytes):
 *
 * DTC   Name                Qual  MaxSize  Sub
 * 0x00  Image Data          0x10  var      0x00
 * 0x03  Gamma/LUT           0x01  32768    0x00
 * 0x81  Film Frame Info     0x01  8        0x0C
 * 0x84  Calibration Data    0x01  6        0x10
 * 0x87  Scan Parameters     0x00  24       0x08  (RAM addr: 0x400D45)
 * 0x88  Boundary/Per-Ch     0x03  644      0x20
 * 0x8E  Focus/Measurement   0x10  var      0x00
 * 0x8F  Histogram/Profile   0x30  324      0x00
 * 0x8A  Exposure/Gain       0x03  14       0x20
 * 0x8C  Offset/Dark         0x03  10       0x20
 * 0x8D  Extended Scan Line  0x30  var      0x00
 * 0x90  CCD Characterize    0x03  54       0x00
 * 0x92  Motor/Positioning   0x03  10       0x00
 * 0x93  Adapter/Film Type   0x01  12       0x00
 * 0xE0  Extended Config     0x30  1030     0x00
 *
 * WRITE DTC Table (FW:0x49B98, 7 entries x 10 bytes):
 *
 * DTC   Name                Qual  MaxSize
 * 0x03  Gamma/LUT           0x01  32768
 * 0x84  Calibration Upload  0x01  0 (handler-managed)
 * 0x85  Extended Cal        0x01  0 (WRITE-only, not in READ table)
 * 0x88  Boundary/Per-Ch     0x03  644
 * 0x8F  Histogram/Profile   0x30  324
 * 0x92  Motor Control       0x03  4
 * 0xE0  Extended Config     0x30  1024
 *
 * Qualifier categories:
 *   0x00 = no qualifier needed
 *   0x01 = single mode (must match table)
 *   0x03 = channel select: 0=all, 1=R, 2=G, 3=B
 *   0x10 = two-mode select: 0 or 1
 *   0x30 = three-mode: 0, 1, or 3 (R/G/B, skip 2)
 */


/* =====================================================================
 * PART 25 — FLASH LAYOUT SUMMARY
 * ===================================================================== */

/*
 * Flash layout (512KB MBM29F400B):
 *
 * Offset      Size    Content
 * ----------  ------  ----------------------------------------
 * 0x00000     4KB     Boot code: vector table + startup
 * 0x01000     12KB    ERASED
 * 0x04000     4KB     Small data block
 * 0x05000     4KB     ERASED
 * 0x06000     4KB     Small data block
 * 0x07000     4KB     ERASED
 * 0x08000     32KB    ERASED (no "extended settings")
 * 0x10000     32KB    Shared handler module (ISR, USB, context system)
 * 0x18000     32KB    ERASED
 * 0x20000     ~200KB  Main firmware code + data tables
 * 0x53000     52KB    ERASED
 * 0x60000     16KB    Log area 1 (433 x 32-byte usage records)
 * 0x64000     48KB    ERASED
 * 0x70000     64KB    Log area 2 (2048 x 32-byte usage records)
 *
 * Total used: ~314KB (59.9%) of 512KB
 * ~660 functions, 304 unique call targets
 *
 * Data tables region (0x45000-0x528BE):
 *   0x49834: SCSI handler table (21 x 10 bytes)
 *   0x49910: Internal task table (97 x 4 bytes)
 *   0x49AD8: READ DTC table (15 x 12 bytes)
 *   0x49B98: WRITE DTC table (7 x 10 bytes)
 *   0x49C20: VPD page table (8 standard + per-adapter)
 *   0x49E30: String table (adapter names, motor labels, cal params)
 *   0x49EFC: String pointer table (24 x 4-byte pointers)
 *   0x4A134: Vendor register table (23 x 2 bytes)
 *   0x4A200: Trigonometric + calibration coefficient tables
 *   0x4A520: CCD channel remap table
 *   0x4A8BC: CCD characterization map (~32KB, factory-programmed)
 */

/* === END OF FIRMWARE MAIN SYSTEM PSEUDOCODE === */
