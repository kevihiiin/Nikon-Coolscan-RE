/*
 * firmware-scsi-handlers.c
 *
 * Pseudocode reconstruction of ALL 21 SCSI command handlers in the
 * Nikon LS-50 / LS-5000 firmware (H8/3003, 24-bit, big-endian).
 *
 * Source: Ghidra disassembly of "Nikon LS-50 MBM29F400B TSOP48.bin" (512 KB)
 * CPU:    Hitachi H8/3003 (H8/300H family)
 * Phase:  4 (Firmware) + cross-validated with Phase 2 (host-side LS5000.md3)
 *
 * This file is a readable reference for driver developers. It is NOT
 * compilable C -- it is pseudocode that preserves the firmware's logic
 * while using C constructs for clarity.
 *
 * Conventions:
 *   - RAM addresses are #defined with their purpose
 *   - Flash (ROM) addresses are noted in comments as FW:0xNNNNN
 *   - Subroutine calls use descriptive names (real addresses in comments)
 *   - Sense codes are set by writing to SENSE_RESULT (0x4007B0)
 *   - CDB bytes are accessed through CDB_BUFFER (0x4007B6)
 */

#include <stdint.h>

/* ====================================================================
 * MEMORY MAP -- Key RAM addresses used by SCSI handlers
 * ==================================================================== */

/* CDB and command state */
#define CDB_BUFFER          0x4007B6  /* 10-byte CDB receive area (byte 0 = opcode) */
#define CDB_OPCODE          0x4007B6  /* CDB[0]: SCSI opcode */
/* CDB[1] = CDB_BUFFER+1 = 0x4007B7, CDB[2] = 0x4007B8, etc. */

#define SENSE_RESULT        0x4007B0  /* 16-bit: internal sense index (0=OK) */
#define SENSE_AUX           0x4007B2  /* 16-bit: auxiliary sense/status word */
#define SENSE_INFO          0x4007A0  /* 32-bit: sense information field */
#define SENSE_SKSV          0x4007A4  /* 16-bit: sense key specific value */
#define CMD_RESULT_STATUS   0x4007B4  /* 16-bit: command result code */

/* Scanner state machine */
#define SCANNER_STATE       0x40077C  /* 16-bit: major scanner state (low byte = state code) */
#define SCAN_BUFFER_STATE   0x400778  /* 16-bit: scan buffer / DMA state code */
#define DMA_BLOCK_STATE     0x40077A  /* 16-bit: DMA block transfer state */
#define SCANNER_FLAGS       0x400776  /* 16-bit: scanner status flags (bit 6=abort, bit 7=response pending) */

/* USB transport */
#define USB_IN_PROGRESS     0x40049A  /* 8-bit: USB transaction in-progress flag */
#define EXEC_MODE           0x40049B  /* 8-bit: current execution mode */
#define USB_PHASE           0x40049C  /* 8-bit: USB transfer phase */
#define CMD_COMPLETION_CTR  0x40049D  /* 8-bit: command completion counter */

/* Command queue */
#define CMD_QUEUE_INDEX     0x40087B  /* 8-bit: current command queue slot */
#define CMD_QUEUE_BASE      0x4006B4  /* per-slot command storage */
#define CMD_QUEUE_STATE     0x40075C  /* per-slot state counter */
#define CMD_QUEUE_RESULT    0x4006BC  /* per-slot result words (20 bytes per slot) */

/* Peripheral qualifier / adapter */
#define ADAPTER_TYPE        0x400773  /* 8-bit: current film adapter index (0-7) */
#define PERIPH_QUALIFIER    0x400877  /* 8-bit: peripheral qualifier override */
#define PERIPH_QUAL_SRC     0x400880  /* 8-bit: peripheral qualifier source */

/* Scan parameters */
#define SCAN_COLOR_MODE     0x400E92  /* 8-bit: color mode (6 = special) */
#define SCAN_ACTIVE_FLAG    0x400D43  /* 8-bit: scan operation active */
#define SCAN_OP_STATE       0x400E7A  /* 8-bit: scan operation state code */
#define SCAN_MAX_OPS        0x400D3C  /* 8-bit: max operations for adapter */
#define MOTOR_BUSY_FLAG     0x400ED6  /* 8-bit: motor busy (1=busy) */
#define SCAN_PROGRESS_FLAG  0x400E79  /* 8-bit: scan in progress (1=active) */

/* Mode pages */
#define MODE_HEADER         0x400D26  /* 3 bytes: mode data length, medium type, dev-specific */
#define MODE_PAGE_CURRENT   0x400D2A  /* 8 bytes: current mode page values */
#define MODE_PAGE_CHANGE    0x400D32  /* 8 bytes: changeable mode page mask */
#define MODE_DATA_BUFFER    0x400DAA  /* MODE SELECT receive buffer */
#define MODE_PARAMS         0x400D8E  /* scan parameter storage */

/* SET WINDOW */
#define WINDOW_PARAMS       0x4009C2  /* Window descriptor storage */
#define RESOLUTION_SETTING  0x400790  /* 8-bit: scan resolution code */
#define RESOLUTION_X_STEP   0x400D8E  /* 32-bit: X step calculation */
#define RESOLUTION_Y_STEP   0x400D9A  /* 32-bit: Y step calculation */
#define RESOLUTION_Z_STEP   0x400D9E  /* 32-bit: Z step calculation */
#define RESOLUTION_AUX      0x400D92  /* 32-bit: auxiliary resolution calc */
#define MAX_RESOLUTION      0x400D3A  /* 16-bit: max resolution for model */

/* Vendor commands */
#define VENDOR_SUBCOMMAND   0x400D63  /* 8-bit: C1 subcommand code (set by E0) */
#define VENDOR_CMDDT_FLAG   0x4062E0  /* 8-bit: CMDDT flag from INQUIRY */

/* INQUIRY response */
#define INQUIRY_RESPONSE    0x4008A2  /* buffer for building INQUIRY data */

/* REQUEST SENSE */
#define CDB_RECV_BUFFER     0x4007DE  /* raw CDB bytes as received from USB */

/* Diagnostic */
#define DIAG_STATE_WORD     0x4062E2  /* diagnostic state storage */

/* Motor state */
#define MOTOR_STATE_BLOCK   0x400B20  /* 10 bytes: motor position/speed/direction */

/* READ/WRITE DTC dispatch tables (flash) */
#define READ_DTC_TABLE      0x49AD8   /* 15 entries x 12 bytes, 0xFF terminated */
#define WRITE_DTC_TABLE     0x49B98   /* 7 entries x 10 bytes, 0xFF terminated */

/* Vendor register table (flash) */
#define VENDOR_REG_TABLE    0x4A134   /* 23 entries x 2 bytes [reg_id, max_len] */


/* ====================================================================
 * DISPATCH TABLE -- Flash address 0x49834 (21 entries, 10 bytes each)
 * ==================================================================== */

/*
 * Each entry: [opcode:8, unused:8, perm_flags:16, handler_ptr:32, exec_mode:8, unused:8]
 * Table terminated by all-zero entry at 0x49906.
 */

typedef struct {
    uint8_t  opcode;        /* SCSI opcode */
    uint8_t  _pad0;         /* always 0 */
    uint16_t perm_flags;    /* permission bitmask (which scanner states allow this) */
    uint32_t handler_addr;  /* 24-bit function pointer (H8/300H) */
    uint8_t  exec_mode;     /* 0=direct, 1=USB setup, 2=data-out, 3=data-in */
    uint8_t  _pad1;         /* always 0 */
} scsi_dispatch_entry_t;

/* SCSI opcodes */
enum scsi_opcode {
    OP_TEST_UNIT_READY   = 0x00,
    OP_REQUEST_SENSE     = 0x03,
    OP_INQUIRY           = 0x12,
    OP_MODE_SELECT       = 0x15,
    OP_RESERVE           = 0x16,
    OP_RELEASE           = 0x17,
    OP_MODE_SENSE        = 0x1A,
    OP_SCAN              = 0x1B,
    OP_RECEIVE_DIAG      = 0x1C,
    OP_SEND_DIAG         = 0x1D,
    OP_SET_WINDOW        = 0x24,
    OP_GET_WINDOW        = 0x25,
    OP_READ_10           = 0x28,
    OP_WRITE_10          = 0x2A,   /* SCSI SEND for scanners */
    OP_WRITE_BUFFER      = 0x3B,
    OP_READ_BUFFER       = 0x3C,
    OP_VENDOR_C0         = 0xC0,   /* status query */
    OP_VENDOR_C1         = 0xC1,   /* trigger action */
    OP_VENDOR_D0         = 0xD0,   /* phase query (USB transport) */
    OP_VENDOR_E0         = 0xE0,   /* data-out to vendor registers */
    OP_VENDOR_E1         = 0xE1,   /* data-in from vendor registers */
};

/* Permission flag patterns */
enum perm_flags {
    PERM_ALWAYS          = 0x07FF,  /* any state (INQUIRY, REQUEST SENSE, D0) */
    PERM_MOST_STATES     = 0x07D4,  /* most states except active scan */
    PERM_NOT_INITIAL     = 0x07FC,  /* all except initial state */
    PERM_RESTRICTED      = 0x07CC,  /* not during scan/transfer */
    PERM_LIMITED          = 0x0254,  /* specific states only */
    PERM_ACTIVE_READ     = 0x0054,  /* only during active read */
    PERM_DIAG_SERVICE    = 0x0016,  /* diagnostic/service mode */
    PERM_INITIALIZED     = 0x0014,  /* scanner must be initialized */
};

/* Execution modes */
enum exec_mode {
    EXEC_DIRECT          = 0x00,  /* handler manages its own transfer */
    EXEC_USB_SETUP       = 0x01,  /* call usb_state_setup() first */
    EXEC_DATA_OUT        = 0x02,  /* host -> device data transfer */
    EXEC_DATA_IN         = 0x03,  /* device -> host data transfer */
};

/* Internal sense indices (written to SENSE_RESULT) */
enum sense_index {
    SENSE_OK             = 0x0000,  /* no error */
    SENSE_NO_ERROR_ILI   = 0x0001,  /* SK=0, deferred+ILI */
    SENSE_NO_ERROR_DEF   = 0x0002,  /* SK=0, deferred */
    SENSE_ROUNDED_PARAM  = 0x0004,  /* SK=1: rounded parameter */
    SENSE_BECOMING_READY = 0x0007,  /* SK=2: becoming ready (general) */
    SENSE_USB_INIT       = 0x0008,  /* SK=2: becoming ready (USB/ISP1581) */
    SENSE_ENCODER_INIT   = 0x0009,  /* SK=2: becoming ready (encoder) */
    SENSE_INIT_REQUIRED  = 0x000A,  /* SK=2: initialization command required */
    SENSE_MEDIUM_REMOVAL = 0x000D,  /* SK=2: LU not responding (ejecting) */
    SENSE_PARAM_LIST_LEN = 0x004E,  /* SK=5: parameter list length error */
    SENSE_INVALID_OPCODE = 0x004F,  /* SK=5: invalid command operation code */
    SENSE_INVALID_CDB    = 0x0050,  /* SK=5: invalid field in CDB */
    SENSE_LUN_NOT_SUPP   = 0x0051,  /* SK=5: logical unit not supported */
    SENSE_LUN_NOT_SUPP2  = 0x0052,  /* SK=5: LUN not supported (variant) */
    SENSE_INVALID_PARAM  = 0x0053,  /* SK=5: invalid field in parameter list */
    SENSE_CMD_SEQ_ERROR  = 0x0056,  /* SK=5: command sequence error */
    SENSE_SAVE_NOT_SUPP  = 0x0059,  /* SK=5: saving parameters not supported */
    SENSE_COMM_FAILURE   = 0x0065,  /* SK=B: LU communication failure */
    SENSE_NOT_CONFIGURED = 0x0066,  /* SK=B: LU has not self-configured */
    SENSE_SCAN_TIMEOUT   = 0x0071,  /* SK=2: scan timeout (reinit needed) */
    SENSE_MOTOR_BUSY     = 0x0079,  /* SK=2: motor busy (positioning) */
    SENSE_CAL_BUSY       = 0x007A,  /* SK=2: calibration in progress */
};

/* READ Data Type Codes (CDB byte 2) */
enum read_dtc {
    DTC_IMAGE_DATA       = 0x00,  /* scan image pixels */
    DTC_GAMMA_LUT        = 0x03,  /* gamma/LUT table */
    DTC_SCAN_AREA        = 0x81,  /* scan area / film frame info */
    DTC_CALIBRATION      = 0x84,  /* calibration data */
    DTC_SCAN_PARAMS      = 0x87,  /* scan parameters / status */
    DTC_BOUNDARY_CAL     = 0x88,  /* boundary / per-channel calibration */
    DTC_EXPOSURE_GAIN    = 0x8A,  /* exposure / gain parameters */
    DTC_OFFSET_DARK      = 0x8C,  /* offset / dark current */
    DTC_EXT_SCANLINE     = 0x8D,  /* extended scan line data */
    DTC_FOCUS_MEASURE    = 0x8E,  /* focus / measurement data */
    DTC_HISTOGRAM        = 0x8F,  /* histogram / profile */
    DTC_CCD_CHAR         = 0x90,  /* CCD characterization */
    DTC_MOTOR_STATUS     = 0x92,  /* motor / positioning status */
    DTC_ADAPTER_INFO     = 0x93,  /* adapter / film type info */
    DTC_EXT_CONFIG       = 0xE0,  /* extended configuration */
};

/* Scan operation codes (SCAN handler er6[0]) */
enum scan_operation {
    SCAN_OP_PREVIEW      = 0,  /* quick low-res preview */
    SCAN_OP_FINE_SINGLE  = 1,  /* full-res single pass */
    SCAN_OP_FINE_MULTI   = 2,  /* multi-sample averaging */
    SCAN_OP_CALIBRATION  = 3,  /* CCD/LED calibration scan */
    SCAN_OP_MOVE         = 4,  /* motor positioning only */
    SCAN_OP_EJECT        = 9,  /* eject film */
};

/* Vendor C1 subcommand codes */
enum vendor_c1_subcommand {
    C1_SCAN_OP_0         = 0x40,  /* scan operation variant 0 */
    C1_SCAN_OP_1         = 0x41,
    C1_SCAN_OP_2         = 0x42,
    C1_SCAN_OP_3         = 0x43,
    C1_MOTOR_MOVE        = 0x44,  /* move to position */
    C1_CAL_OP_0          = 0x45,  /* calibration variant 0 */
    C1_CAL_OP_1          = 0x46,
    C1_CAL_OP_2          = 0x47,
    C1_LAMP_CTRL         = 0x80,  /* lamp on/off */
    C1_MOTOR_INIT        = 0x81,  /* motor initialization */
    C1_STEP_MOTOR        = 0x91,  /* step motor command */
    C1_CCD_SETUP         = 0xA0,  /* CCD/sensor setup */
    C1_STATE_CHANGE_0    = 0xB0,  /* state change */
    C1_STATE_CHANGE_1    = 0xB1,
    C1_CONFIG_WRITE      = 0xB3,  /* write configuration data */
    C1_EXT_CONFIG        = 0xB4,  /* write extended config */
    C1_GAIN_CAL          = 0xC0,  /* gain calibration */
    C1_OFFSET_CAL        = 0xC1,  /* offset calibration */
    C1_DIAG_0            = 0xD0,  /* diagnostic */
    C1_DIAG_1            = 0xD1,
    C1_DIAG_DATA         = 0xD2,  /* diagnostic data */
    C1_EXT_DIAG          = 0xD5,  /* extended diagnostic */
    C1_PERSIST_SETTINGS  = 0xD6,  /* write persistent settings */
};


/* ====================================================================
 * FLASH DATA TABLES
 * ==================================================================== */

/*
 * SCSI Dispatch Table at FW:0x49834
 * 21 entries + null terminator, 10 bytes each
 */
static const scsi_dispatch_entry_t SCSI_DISPATCH_TABLE[22] = {
    /* op    pad  perm     handler      exec pad */
    { 0x00, 0, 0x07D4, 0x0215C2, 0x01, 0 },  /* TEST UNIT READY */
    { 0x03, 0, 0x07FF, 0x021866, 0x03, 0 },  /* REQUEST SENSE */
    { 0x12, 0, 0x07FF, 0x025E18, 0x03, 0 },  /* INQUIRY */
    { 0x15, 0, 0x0014, 0x02194A, 0x02, 0 },  /* MODE SELECT */
    { 0x16, 0, 0x07CC, 0x021E3E, 0x01, 0 },  /* RESERVE */
    { 0x17, 0, 0x07FC, 0x021EA0, 0x01, 0 },  /* RELEASE */
    { 0x1A, 0, 0x07D4, 0x021F1C, 0x03, 0 },  /* MODE SENSE */
    { 0x1B, 0, 0x0014, 0x0220B8, 0x00, 0 },  /* SCAN */
    { 0x1C, 0, 0x0014, 0x023856, 0x03, 0 },  /* RECEIVE DIAGNOSTIC */
    { 0x1D, 0, 0x0016, 0x023D32, 0x02, 0 },  /* SEND DIAGNOSTIC */
    { 0x24, 0, 0x0014, 0x026E38, 0x02, 0 },  /* SET WINDOW */
    { 0x25, 0, 0x0254, 0x0272F6, 0x03, 0 },  /* GET WINDOW */
    { 0x28, 0, 0x0054, 0x023F10, 0x03, 0 },  /* READ(10) */
    { 0x2A, 0, 0x0014, 0x025506, 0x02, 0 },  /* WRITE/SEND(10) */
    { 0x3B, 0, 0x0014, 0x02837C, 0x02, 0 },  /* WRITE BUFFER */
    { 0x3C, 0, 0x0014, 0x028884, 0x03, 0 },  /* READ BUFFER */
    { 0xC0, 0, 0x0754, 0x028AB4, 0x01, 0 },  /* Vendor: Status Query */
    { 0xC1, 0, 0x0014, 0x028B08, 0x01, 0 },  /* Vendor: Trigger */
    { 0xD0, 0, 0x07FF, 0x013748, 0x01, 0 },  /* Vendor: Phase Query */
    { 0xE0, 0, 0x0014, 0x028E16, 0x02, 0 },  /* Vendor: Data Out */
    { 0xE1, 0, 0x0014, 0x0295EA, 0x03, 0 },  /* Vendor: Data In */
    { 0x00, 0, 0x0000, 0x000000, 0x00, 0 },  /* terminator */
};

/*
 * Sense Translation Table at FW:0x16DEE
 * 148 entries, 5 bytes each: [flags, sense_key, ASC, ASCQ, FRU]
 * The internal sense index (at SENSE_RESULT) is used as an offset
 * into this table to produce standard SCSI sense data.
 */

/*
 * Standard VPD Page Table at FW:0x49C20
 * 8 entries, 6 bytes each: [page_code, field, handler_addr(32-bit)]
 */

/*
 * Adapter-Specific VPD Table at FW:0x49C74
 * Indexed by adapter_type * 30 (0x1E), 5 entries per adapter
 * 8 adapter types (0=none, 1=Mount, 2=Strip, 3=240, 4=Feeder,
 *                  5=6Strip, 6=36Strip, 7=Test)
 */

/*
 * Internal Task Code Table at FW:0x49910
 * 97 entries, 4 bytes each: [task_code:16, handler_index:16]
 * Maps internal event codes to handler indices.
 */

/*
 * Default Mode Page Data at FW:0x0168AF
 * Page 0x03: code=0x03, length=6, resolution=1200 DPI, max_x=4000, max_y=4000
 */


/* ====================================================================
 * FIRMWARE SUBROUTINES (named by function)
 * ==================================================================== */

/* FW:0x016458 -- Save er3-er6 to stack (standard prologue) */
static void push_context(void);

/* FW:0x016436 -- Restore er3-er6 from stack (standard epilogue) */
static void pop_context(void);

/* FW:0x01374A -- USB state setup / response manager
 * Called with r0l = command phase byte.
 * Sets up ISP1581 USB controller for the requested data transfer phase.
 */
static void usb_state_setup(uint8_t phase);

/* FW:0x014090 -- USB data transfer
 * er0 = pointer to response buffer
 * r1  = byte count to send
 * Performs ISP1581 DMA bulk-in transfer to host.
 */
static void usb_data_transfer(void *buffer, uint16_t byte_count);

/* FW:0x013E20 -- USB data receive (for data-out commands)
 * er0 = pointer to receive buffer
 * r1  = expected byte count
 * Reads data from host via ISP1581 bulk-out endpoint.
 */
static void usb_data_receive(void *buffer, uint16_t byte_count);

/* FW:0x0109E2 -- Yield / check for pending interrupts
 * Called during long operations to allow ISR processing.
 */
static void yield(void);

/* FW:0x020DBA -- Task code to sense index lookup
 * Takes a 16-bit task/event code in r0, looks it up in the task code
 * table at FW:0x49910, returns the corresponding handler index.
 */
static uint16_t task_to_sense_index(uint16_t task_code);

/* FW:0x0111F4 -- Build sense response from internal index
 * Reads sense translation table at FW:0x16DEE, produces 18-byte
 * SCSI fixed-format sense response.
 */
static void build_sense_response(void *out_buffer, uint16_t sense_index);

/* FW:0x020EC8 -- Dispatch internal event/task */
static void dispatch_internal_event(void);

/* FW:0x02605A -- Build standard INQUIRY response
 * Fills buffer at INQUIRY_RESPONSE with device type, vendor string, etc.
 */
static void build_standard_inquiry(void);

/* FW:0x02625E -- Build VPD page C1 response */
static void build_vpd_c1_response(void);

/* FW:0x026E36 -- Send INQUIRY-like response (helper)
 * r0 = byte count to send
 */
static void send_inquiry_response(uint16_t length);

/* FW:0x0279BE -- Parse/validate SET WINDOW descriptor fields
 * er0 = pointer to window data (past header)
 * r1  = remaining descriptor length
 * Returns count of validated bytes in r0.
 */
static uint16_t parse_window_descriptor(void *data, uint16_t length);

/* FW:0x033064 -- Check adapter position sensors (GPIO Port 7) */
static void check_adapter_position(void);

/* FW:0x0163EA -- 32-bit multiply (er0 = er0 * er1) */
static uint32_t multiply_32(uint32_t a, uint32_t b);


/* ====================================================================
 * DISPATCH LOOP -- Entry at FW:0x020B48
 *
 * Called when a SCSI CDB arrives via USB bulk-out endpoint.
 * The ISP1581 interrupt handler has already placed the CDB bytes
 * at CDB_RECV_BUFFER (0x4007DE) and the opcode at CDB_OPCODE (0x4007B6).
 * ==================================================================== */

void scsi_dispatch(void)  /* FW:0x020B48 */
{
    push_context();

    uint8_t  received_opcode = *(uint8_t *)CDB_OPCODE;
    uint8_t  cmd_phase = 1;  /* r3l, passed to usb_state_setup */

    /* --- Step 1: Opcode lookup in dispatch table --- */
    scsi_dispatch_entry_t *entry = (scsi_dispatch_entry_t *)0x49834;

    while (entry->handler_addr != 0) {
        if (entry->opcode == received_opcode)
            goto found;
        entry++;  /* next entry (10-byte stride) */
    }

    /* Opcode not in table -- fall through to error handling */
    /* entry->handler_addr == 0 means end of table */

found:
    uint16_t perm_flags = entry->perm_flags;

    yield();  /* FW:0x0109E2 */

    /* --- Step 2: Check if handler exists --- */
    if (entry->handler_addr == 0) {
        /* Unknown opcode */
        usb_state_setup(cmd_phase);
        *(uint16_t *)SENSE_RESULT = SENSE_INVALID_OPCODE;  /* 0x4F */
        goto cleanup;
    }

    /* --- Step 3: Permission / state checking --- */

    /* Check perm_flags bit 0: if clear, check for pending errors */
    if (!(perm_flags & 0x01)) {
        uint8_t slot = *(uint8_t *)CMD_QUEUE_INDEX;
        if (*(uint8_t *)(CMD_QUEUE_BASE + slot) != 0) {
            /* Pending error in queue -- replay queued result */
            uint32_t slot_offset = (uint32_t)slot * 20;  /* 0x14 bytes per slot */
            *(uint16_t *)SENSE_RESULT = *(uint16_t *)(CMD_QUEUE_RESULT + slot_offset);
            /* Decrement slot state counter */
            uint8_t count = *(uint8_t *)(CMD_QUEUE_STATE + slot);
            count--;
            *(uint8_t *)(CMD_QUEUE_STATE + slot) = count;
            /* ... additional queue processing ... */
            goto cleanup;
        }
    }

    /* Check perm_flags bit 1: if clear, check scanner state */
    if (!(perm_flags & 0x02)) {
        /* Scanner state-based permission check */
        uint16_t state = *(uint16_t *)SCANNER_STATE;

        if (state == 0x0080 || state == 0x0000) {
            /* Ejecting or idle with bit 7 of perm clear */
            if (!(perm_flags & 0x80)) {
                usb_state_setup(cmd_phase);
                *(uint16_t *)SENSE_RESULT = SENSE_NOT_CONFIGURED;  /* 0x66 */
                goto cleanup;
            }
        }

        yield();

        uint8_t state_lo = state & 0xFF;
        if ((state >> 8) != 0) {
            /* High byte non-zero: proceed to handler call */
            goto call_handler;
        }

        /*
         * State-based permission dispatch (FW:0x020CA0)
         * The low byte of SCANNER_STATE determines which permission
         * bit is tested. This implements the scanner state machine.
         */
        switch (state_lo) {
        case 0x10: case 0x11: case 0x12: case 0x13: case 0x14: case 0x15:
            /* States 0x10-0x15: test perm bit 9 (r5h bit 1) */
            if (perm_flags & 0x0200) goto call_handler;
            usb_state_setup(cmd_phase);
            *(uint8_t *)(SCANNER_FLAGS) |= 0x80;  /* set response pending */
            *(uint16_t *)SENSE_RESULT = SENSE_CMD_SEQ_ERROR;  /* 0x56 */
            goto cleanup;

        case 0x20: case 0x21:
            /* States 0x20-0x21: test perm bit 6 */
            if (perm_flags & 0x0040) goto call_handler;
            usb_state_setup(cmd_phase);
            *(uint8_t *)(SCANNER_FLAGS) |= 0x80;
            *(uint16_t *)SENSE_RESULT = SENSE_CMD_SEQ_ERROR;
            goto cleanup;

        case 0x40: case 0x41: case 0x42: case 0x43: case 0x44: case 0x45:
        case 0x81:
        case 0xB0: case 0xB1: case 0xB3:
        case 0xC0: case 0xC1:
        case 0xD0: case 0xD1: case 0xD2:
            /* These states: test perm bit 8 (r5h bit 0) */
            if (perm_flags & 0x0100) goto call_handler;
            usb_state_setup(cmd_phase);
            *(uint8_t *)(SCANNER_FLAGS) |= 0x80;
            *(uint16_t *)SENSE_RESULT = SENSE_CMD_SEQ_ERROR;
            goto cleanup;

        case 0xA0:
            /* State 0xA0: test perm bit 10 (r5h bit 2) */
            if (perm_flags & 0x0400) goto call_handler;
            usb_state_setup(cmd_phase);
            *(uint8_t *)(SCANNER_FLAGS) |= 0x80;
            *(uint16_t *)SENSE_RESULT = SENSE_CMD_SEQ_ERROR;
            goto cleanup;

        case 0xF3: case 0xF4:
            /* States 0xF3-0xF4: test perm bit 8 */
            if (perm_flags & 0x0100) goto call_handler;
            *(uint16_t *)SENSE_RESULT = SENSE_COMM_FAILURE;  /* 0x65 */
            goto cleanup;

        default:
            /* Unknown state: proceed to handler */
            goto call_handler;
        }
    }

call_handler:
    /* --- Step 4: Execute handler --- */
    {
        uint8_t mode = entry->exec_mode;

        /* If exec_mode == 1, call USB state setup first */
        if (mode == EXEC_USB_SETUP) {
            usb_state_setup(cmd_phase);
        }

        /* Store execution mode for handler reference */
        *(uint8_t *)EXEC_MODE = mode;

        /* Load handler address and call it */
        void (*handler)(void) = (void (*)(void))entry->handler_addr;
        handler();
    }

cleanup:
    pop_context();
    return;
}


/* ====================================================================
 * HANDLER 1: TEST UNIT READY (0x00) -- FW:0x0215C2
 *
 * Reports scanner readiness. No data transfer. The largest handler
 * (~700 bytes). Implements a comprehensive state machine check.
 *
 * CDB: [00 00 00 00 00 00]
 *      Bytes 1-5 must be zero.
 * ==================================================================== */

void handler_test_unit_ready(void)  /* FW:0x0215C2 */
{
    push_context();

    uint16_t *dma_state   = (uint16_t *)DMA_BLOCK_STATE;   /* er4 -> 0x40077A */
    uint16_t *scan_buf    = (uint16_t *)SCAN_BUFFER_STATE;  /* er5 -> 0x400778 */
    uint16_t *sense       = (uint16_t *)SENSE_RESULT;       /* er6 -> 0x4007B0 */

    /* -- CDB validation: bytes 1-5 must be zero -- */
    /* Firmware checks CDB[1] & 0x1F, then loops CDB[2..5] */
    uint8_t *cdb = (uint8_t *)CDB_BUFFER;
    if (cdb[1] & 0x1F) {
        *sense = SENSE_INVALID_CDB;
        goto done;
    }
    for (int i = 2; i < 6; i++) {
        if (cdb[i] != 0) {
            *sense = SENSE_INVALID_CDB;
            goto done;
        }
    }

    /* -- Scanner state machine check -- */
    uint16_t state = *(uint16_t *)SCANNER_STATE;
    uint8_t state_lo = state & 0xFF;

    if (state_lo == 0x00) {
        /* Idle state: check scan buffer for pending conditions */
        uint16_t buf_state = *scan_buf;
        if (buf_state == 0x0010) {
            /* Pending task code 0x0010 -- translate to sense */
            *sense = task_to_sense_index(buf_state);
        }
        /* else: scanner is ready, sense stays 0 (Good) */
        goto done;
    }

    if (state_lo == 0x80) {
        /* Ejecting film */
        *sense = SENSE_MEDIUM_REMOVAL;  /* 0x000D: SK=2, ASC=05/00 */
        goto done;
    }

    if (state_lo == 0x01 || state_lo == 0xF2) {
        /* Active scan state -- check sub-conditions */
        goto check_active_scan;
    }

    if ((state_lo & 0xF0) == 0x20) {
        /* Setup phase (0x20-0x2F) -- check active scan */
        goto check_active_scan;
    }

    /* Error states */
    if (state_lo == 0xF0) {
        *sense = SENSE_USB_INIT;  /* 0x0008: ISP1581/sensor error */
        goto done;
    }
    if (state_lo == 0xF1) {
        *sense = SENSE_ENCODER_INIT;  /* 0x0009: motor/encoder error */
        goto done;
    }
    if (state_lo == 0xF3) {
        *sense = SENSE_MOTOR_BUSY;    /* 0x0079: motor busy */
        goto done;
    }
    if (state_lo == 0xF4) {
        *sense = SENSE_CAL_BUSY;      /* 0x007A: calibration in progress */
        goto done;
    }

    /* Default: becoming ready */
    *sense = SENSE_BECOMING_READY;    /* 0x0007 */
    goto done;

check_active_scan:
    /* Reached when scanner_state = 0x01, 0xF2, or 0x2x */

    if (state_lo == 0x22) {
        /* State 0x22: becoming ready */
        *sense = SENSE_BECOMING_READY;
        goto done;
    }

    /* Must be state 0x01 or 0xF2 for remaining checks */
    if (state_lo != 0x01 && state_lo != 0xF2)
        goto done;

    /* Check abort flag at SCANNER_FLAGS bit 14 (0x4000) */
    if (*(uint16_t *)SCANNER_FLAGS & 0x4000) {
        *sense = SENSE_BECOMING_READY;
        goto done;
    }

    /* Check motor busy flag */
    if (*(uint8_t *)MOTOR_BUSY_FLAG == 1) {
        *sense = SENSE_MOTOR_BUSY;
        goto done;
    }

    /* Check scan progress flag */
    if (*(uint8_t *)SCAN_PROGRESS_FLAG == 1) {
        uint16_t dma = *dma_state;
        if (dma == 0x4000 || dma == 0x9000) {
            /* DMA complete or error recovery -- clear sense */
            *sense = 0;
        } else {
            /* DMA in progress: translate dma_state to sense */
            *sense = task_to_sense_index(dma);
        }
    } else {
        *sense = task_to_sense_index(*dma_state);
    }

    /* Check specific scan buffer states */
    uint16_t buf = *scan_buf;

    if (buf == 0x0330) {
        /* Scan buffer full (stalled -- host needs to READ) */
        *(uint16_t *)SENSE_AUX = task_to_sense_index(buf);
        *dma_state = 0;
        *scan_buf  = 0;
    }

    if (buf == 0x0340 || buf == 0x0320) {
        /* Scan complete (0x0340) or scan data ready (0x0320) */
        *(uint16_t *)SENSE_AUX = task_to_sense_index(buf);
        *dma_state = 0;
        *scan_buf  = 0;
    }

    /* Check for resolution-dependent sub-states */
    uint16_t dma = *dma_state;
    if (dma == 0x3000) {
        /* Resolution-dependent handling */
        if (*(uint8_t *)SCAN_COLOR_MODE == 6) {
            *dma_state = 0x9000;  /* special color mode -> recovery */
        } else if (buf == 0x0340) {
            *(uint16_t *)SENSE_AUX = task_to_sense_index(buf);
            *dma_state = 0;
        } else if (buf == 0x0350) {
            *(uint16_t *)SENSE_AUX = task_to_sense_index(buf);
            *dma_state = 0;
        }
    }

    if (dma == 0x2000) {
        /* Mode-change sub-state: check specific codes */
        if (buf == 0x0110 || buf == 0x0120 || buf == 0x0121) {
            /* Expected sub-states: configuration in progress */
            goto post_check;
        }
        /* Other sub-states under 0x2000 */
        if (*(uint8_t *)SCAN_COLOR_MODE == 6) {
            *dma_state = 0x9000;
        } else {
            *dma_state = 0;
        }
    }

post_check:
    /* Final: check if certain sense codes require clearing scan state */
    {
        uint16_t s = *sense;
        if (s == SENSE_INIT_REQUIRED || s == SENSE_SCAN_TIMEOUT ||
            s == 0x000C || s == 0x000E || s == 0x000F || s == 0x007E) {
            *(uint16_t *)SENSE_AUX = task_to_sense_index(*scan_buf);
            if (s == SENSE_INIT_REQUIRED || s == SENSE_SCAN_TIMEOUT) {
                /* Check if sub-states 0x110/0x120/0x121 are active */
                if (*scan_buf == 0x0110 || *scan_buf == 0x0120 ||
                    *scan_buf == 0x0121) {
                    goto done;
                }
                *scan_buf = 0;
            }
        }
    }

done:
    pop_context();
}


/* ====================================================================
 * HANDLER 2: REQUEST SENSE (0x03) -- FW:0x021866
 *
 * Returns 18-byte SCSI fixed-format sense data describing the last error.
 *
 * CDB: [03 00 00 00 LL 00]
 *      LL = allocation length (max bytes to return, typically 18)
 * ==================================================================== */

void handler_request_sense(void)  /* FW:0x021866 */
{
    push_context();
    uint8_t local_buf[0x108];  /* stack frame for sense response */

    uint16_t *sense_word = (uint16_t *)SENSE_RESULT;  /* er3 */
    uint8_t  *cdb = (uint8_t *)CDB_BUFFER;            /* er4 */
    uint8_t  *response = local_buf;                    /* er5 = sp */

    /* -- CDB validation -- */
    if (cdb[1] & 0x1F) {
        *sense_word = SENSE_INVALID_CDB;
        goto done;
    }
    for (int i = 2; i < 4; i++) {
        if (cdb[i] != 0) {
            *sense_word = SENSE_INVALID_CDB;
            goto done;
        }
    }
    if (cdb[5] != 0) {
        *sense_word = SENSE_INVALID_CDB;
        goto done;
    }

    /* -- Determine peripheral qualifier -- */
    uint8_t pq;
    if (*(uint8_t *)PERIPH_QUALIFIER) {
        pq = *(uint8_t *)PERIPH_QUAL_SRC;
    } else {
        pq = cdb[1] & 0xE0;
    }

    if (pq != 0) {
        /* Non-zero peripheral qualifier: return LUN not supported sense */
        build_sense_response(response, SENSE_LUN_NOT_SUPP2);  /* FW:0x0111F4 */
        goto send_response;
    }

    /* -- Build sense data from last error -- */
    /* Copy 19 bytes from CDB_RECV_BUFFER (0x4007DE) to response buffer.
     * This is the stored sense data from the last command error.
     * The firmware maintains sense data at 0x4007DE continuously. */
    for (int i = 0; i < 19; i++) {
        response[i] = ((uint8_t *)CDB_RECV_BUFFER)[i];
    }

send_response:
    {
        /* Clamp response length to allocation length from CDB[4] */
        uint8_t alloc_len = cdb[4];
        uint16_t send_len = alloc_len;
        if (send_len > 19) {
            /* Zero-pad beyond 19 bytes */
            for (int i = 19; i < send_len; i++)
                response[i] = 0;
        }

        /* Send response via USB */
        usb_state_setup(*(uint8_t *)EXEC_MODE);
        usb_data_transfer(response, send_len);
    }

done:
    pop_context();
}


/* ====================================================================
 * HANDLER 3: INQUIRY (0x12) -- FW:0x025E18
 *
 * Returns device identification. Supports standard INQUIRY and VPD pages.
 * Device type: 0x06 (Scanner).
 *
 * CDB: [12 EVPD PAGE 00 ALLOC CMDDT]
 *      EVPD = bit 0 of byte 1 (enable VPD page mode)
 *      PAGE = byte 2 (VPD page code when EVPD=1)
 *      ALLOC = byte 4 (allocation length)
 *      CMDDT = bit 7 of byte 5
 * ==================================================================== */

void handler_inquiry(void)  /* FW:0x025E18 */
{
    push_context();
    uint8_t stack_vars[0x0C];  /* local stack frame */

    uint8_t *adapter = (uint8_t *)ADAPTER_TYPE;   /* er3 -> 0x400773 */
    uint8_t *resp    = (uint8_t *)INQUIRY_RESPONSE; /* er4 -> 0x4008A2 */
    uint8_t *cdb     = (uint8_t *)CDB_BUFFER;      /* er6 -> 0x4007B6 */

    /* -- CDB validation -- */
    /* Bits 1-4 of CDB[1] are reserved, must be zero */
    if (cdb[1] & 0x1E) {
        *(uint16_t *)SENSE_RESULT = SENSE_INVALID_CDB;
        goto epilogue;
    }
    /* CDB[3] must be zero */
    if (cdb[3] != 0) {
        *(uint16_t *)SENSE_RESULT = SENSE_INVALID_CDB;
        goto epilogue;
    }
    /* CDB[5] bits 0-5 must be zero (CMDDT area) */
    if (cdb[5] & 0x3F) {
        *(uint16_t *)SENSE_RESULT = SENSE_INVALID_CDB;
        goto epilogue;
    }

    /* Save CMDDT flag (bit 7 of CDB[5]) */
    *(uint8_t *)VENDOR_CMDDT_FLAG = (cdb[5] & 0x80) ? 1 : 0;

    /* -- Check EVPD bit -- */
    uint8_t evpd = cdb[1] & 0x01;

    if (!evpd) {
        /* Standard INQUIRY (EVPD=0, page_code must be 0) */
        if (cdb[2] != 0) {
            *(uint16_t *)SENSE_RESULT = SENSE_INVALID_CDB;
            goto epilogue;
        }
        build_standard_inquiry();  /* FW:0x02605A */
        goto send_response;
    }

    /* -- VPD page mode (EVPD=1) -- */
    uint8_t adapter_type = *adapter;
    uint8_t page_code = cdb[2];

    /* Special case: no adapter or adapter type 0xFF */
    if (adapter_type == 0 || adapter_type == 0xFF) {
        if (page_code == 0x00) {
            /* VPD page 0x00: supported VPD pages list */
            resp[1] = page_code;
            resp[2] = 0;
            resp[3] = 2;
            resp[4] = 0;
            resp[5] = 0xC1;
            send_inquiry_response(6);  /* FW:0x026E36 */
            goto send_response;
        }
        if (page_code == 0xC1) {
            /* VPD page 0xC1: special direct response */
            resp[1] = page_code;
            resp[2] = 0;
            build_vpd_c1_response();  /* FW:0x02625E */
            goto send_response;
        }
        /* Unknown VPD page for no-adapter state */
        *(uint16_t *)SENSE_RESULT = SENSE_INVALID_CDB;
        goto epilogue;
    }

    /* -- Two-level VPD dispatch for adapters -- */

    /* Level 1: Search standard VPD table at FW:0x49C20 (8 entries x 6 bytes) */
    for (int i = 0; i < 8; i++) {
        uint8_t tbl_page = *(uint8_t *)(0x49C20 + i * 6);
        if (tbl_page == 0xFF)
            break;  /* end of standard table */
        if (tbl_page == page_code) {
            /* Found in standard table -- copy page code to response */
            resp[1] = page_code;
            resp[2] = 0;
            /* Call the handler function pointer from table[i].handler */
            void (*vpd_handler)(void) =
                (void (*)(void))(*(uint32_t *)(0x49C22 + i * 6));
            vpd_handler();
            goto send_response;
        }
    }

    /* Level 2: Search adapter-specific VPD table at FW:0x49C74 */
    /* Each adapter has 5 entries, each 6 bytes, at offset adapter_type * 0x1E */
    uint32_t adapter_tbl_base = 0x49C92 + (uint32_t)adapter_type * 0x1E;
    /* Note: firmware does 0x49C92 not 0x49C74 because it pre-subtracts 0x1E
     * and starts indexing from 0 */

    for (int i = 0; ; i++) {
        uint8_t tbl_page = *(uint8_t *)(adapter_tbl_base + i * 6 - 0x1E);
        if (tbl_page == 0xFF) {
            /* No match -- invalid page for this adapter */
            *(uint16_t *)SENSE_RESULT = SENSE_INVALID_CDB;
            goto epilogue;
        }
        if (tbl_page == page_code) {
            resp[1] = page_code;
            resp[2] = 0;
            void (*vpd_handler)(void) =
                (void (*)(void))(*(uint32_t *)(adapter_tbl_base + i * 6 - 0x1E + 2));
            vpd_handler();
            goto send_response;
        }
    }

send_response:
    {
        /* Determine device type byte:
         * If peripheral qualifier is set -> 0x7F (LUN not present)
         * Else -> 0x06 (scanner device) */
        uint8_t pq;
        if (*(uint8_t *)PERIPH_QUALIFIER) {
            pq = *(uint8_t *)PERIPH_QUAL_SRC;
        } else {
            pq = cdb[1] & 0xE0;
        }
        resp[0] = (pq != 0) ? 0x7F : 0x06;

        /* Send response: alloc_len from CDB[4] */
        uint16_t alloc_len = cdb[4];
        usb_state_setup(*(uint8_t *)EXEC_MODE);
        usb_data_transfer(resp, alloc_len);
    }

epilogue:
    pop_context();
}


/* ====================================================================
 * HANDLER 4: MODE SELECT (0x15) -- FW:0x02194A
 *
 * Receives mode page data from host to configure scanner settings.
 *
 * CDB: [15 FLAGS 00 00 PARM_LEN 00]
 *      FLAGS byte 1 & 0x1F = sub-mode selector (must be 0x10 for supported mode)
 *      PARM_LEN = parameter list length (byte 4)
 * ==================================================================== */

void handler_mode_select(void)  /* FW:0x02194A */
{
    push_context();
    uint8_t stack_buf[0x10A];  /* local receive buffer */

    uint8_t  *mode_data = (uint8_t *)MODE_DATA_BUFFER;  /* er3 -> 0x400DAA */
    uint8_t  *mode_params = (uint8_t *)MODE_PARAMS;     /* er4 -> 0x400D8E */
    uint8_t  *recv_buf = stack_buf;                      /* er5 = sp */
    uint16_t *sense = (uint16_t *)SENSE_RESULT;          /* er6 -> 0x4007B0 */

    uint8_t *cdb = (uint8_t *)CDB_BUFFER;

    /* -- CDB validation -- */
    uint8_t flags = cdb[1] & 0x1F;
    if (flags != 0x10) {
        /* Only mode 0x10 is supported */
        *sense = SENSE_INVALID_CDB;
        goto done;
    }

    /* Check CDB bytes 2-3 are zero (loop check) */
    for (int i = 2; i < 4; i++) {
        if (cdb[i] != 0) {
            *sense = SENSE_INVALID_CDB;
            goto done;
        }
    }
    if (cdb[5] != 0) {
        *sense = SENSE_INVALID_CDB;
        goto done;
    }

    /* -- Get parameter list length -- */
    uint8_t param_len = cdb[4];  /* 0x4007BA */

    if (param_len == 0) {
        /* Zero length: nothing to do */
        goto done;
    }

    /* Validate parameter list length: must be 0x04, 0x0C, or 0x14 */
    if (param_len != 0x14 && param_len != 0x0C && param_len != 0x04) {
        *sense = SENSE_PARAM_LIST_LEN;  /* 0x4E */
        goto done;
    }

    /* -- Receive mode page data from host -- */
    usb_state_setup(*(uint8_t *)EXEC_MODE);
    usb_data_receive(recv_buf, param_len);

    if (*sense != 0)
        goto done;  /* transfer error */

    /* Validate received bytes 1-2 are zero (header area) */
    if (recv_buf[1] != 0 || recv_buf[2] != 0) {
        *sense = SENSE_INVALID_PARAM;  /* 0x53 */
        goto done;
    }

    /* Adjust param_len: subtract 4 for header */
    param_len -= 4;

    /* Validate remaining parameter bytes 4 through (4+param_len) */
    for (int i = 4; i < 4 + param_len; i++) {
        if (recv_buf[i] != 0) {  /* Reserved bytes must be zero */
            *sense = SENSE_INVALID_PARAM;
            goto done;
        }
    }

    /* -- Copy mode data to scanner state -- */
    /* Process mode page header (byte 3 = page code | PS bit) */
    uint8_t page_code_byte = recv_buf[3];
    /* ... mode page processing based on page code ... */

    /* Copy received parameters to MODE_DATA_BUFFER and MODE_PARAMS */
    /* Details vary by mode page; standard page 0x03 has resolution
     * and scan area dimensions. */

done:
    pop_context();
}


/* ====================================================================
 * HANDLER 5: RESERVE (0x16) -- FW:0x021E3E
 *
 * Standard SCSI RESERVE(6). Claims the scanner for exclusive use.
 * No data transfer. Simple CDB validation only.
 *
 * CDB: [16 00 00 00 00 00]
 * ==================================================================== */

void handler_reserve(void)  /* FW:0x021E3E */
{
    push_context();

    uint8_t *cdb = (uint8_t *)CDB_BUFFER;

    /* CDB[1] & 0x1F must be zero */
    if (cdb[1] & 0x1F) {
        *(uint16_t *)SENSE_RESULT = SENSE_INVALID_CDB;
        goto done;
    }

    /* CDB bytes 2-5 must be zero */
    for (int i = 2; i <= 5; i++) {
        if (cdb[i] != 0) {
            *(uint16_t *)SENSE_RESULT = SENSE_INVALID_CDB;
            goto done;
        }
    }

    /* Reserve the device (set internal reservation flag) */
    /* No explicit action needed beyond returning Good status */

done:
    pop_context();
}


/* ====================================================================
 * HANDLER 6: RELEASE (0x17) -- FW:0x021EA0
 *
 * Standard SCSI RELEASE(6). Releases reservation.
 *
 * CDB: [17 00 00 00 00 00]
 * ==================================================================== */

void handler_release(void)  /* FW:0x021EA0 */
{
    push_context();

    uint8_t *cdb = (uint8_t *)CDB_BUFFER;

    if (cdb[1] & 0x1F) {
        *(uint16_t *)SENSE_RESULT = SENSE_INVALID_CDB;
        goto done;
    }

    for (int i = 2; i <= 5; i++) {
        if (cdb[i] != 0) {
            *(uint16_t *)SENSE_RESULT = SENSE_INVALID_CDB;
            goto done;
        }
    }

    /* Release the device reservation */

done:
    pop_context();
}


/* ====================================================================
 * HANDLER 7: MODE SENSE (0x1A) -- FW:0x021F1C
 *
 * Returns scanner mode pages. Supports page 0x03 and 0x3F.
 *
 * CDB: [1A FLAGS PAGE 00 ALLOC 00]
 *      FLAGS bits 0-2: reserved (must be 0)
 *      FLAGS bit 3: DBD (disable block descriptors)
 *      PAGE bits 0-5: page code
 *      PAGE bits 6-7: page control (PC): 0=current, 1=changeable, 2=default, 3=saved
 *      ALLOC = byte 4: allocation length (0 -> 256)
 * ==================================================================== */

void handler_mode_sense(void)  /* FW:0x021F1C */
{
    push_context();
    uint8_t response[0x100];  /* stack frame */

    uint8_t *cdb = (uint8_t *)CDB_BUFFER;

    /* -- CDB validation -- */
    if (cdb[1] & 0x07) {
        *(uint16_t *)SENSE_RESULT = SENSE_INVALID_CDB;
        goto done;
    }
    if (cdb[3] != 0 || cdb[5] != 0) {
        *(uint16_t *)SENSE_RESULT = SENSE_INVALID_CDB;
        goto done;
    }

    uint8_t page_code = cdb[2] & 0x3F;
    uint8_t page_control = (cdb[2] >> 6) & 0x03;  /* PC field */
    uint8_t alloc_len = cdb[4];
    if (alloc_len == 0) alloc_len = 0;  /* 0 means 256 in some contexts */

    /* Supported pages: 0x03 (device-specific) and 0x3F (all pages) */
    if (page_code != 0x03 && page_code != 0x3F) {
        *(uint16_t *)SENSE_RESULT = SENSE_INVALID_CDB;
        goto done;
    }

    /* -- Page Control dispatch -- */
    uint8_t *page_src;
    switch (page_control) {
    case 0:  /* Current values */
        page_src = (uint8_t *)MODE_PAGE_CURRENT;  /* RAM 0x400D2A */
        break;
    case 1:  /* Changeable values */
        page_src = (uint8_t *)MODE_PAGE_CHANGE;   /* RAM 0x400D32 */
        break;
    case 2:  /* Default values */
        page_src = (uint8_t *)0x0168AF;            /* Flash defaults */
        break;
    case 3:  /* Saved values -- NOT SUPPORTED */
        *(uint16_t *)SENSE_RESULT = SENSE_SAVE_NOT_SUPP;  /* 0x59 */
        goto done;
    }

    /* -- Build response -- */
    /* Mode parameter header (3 bytes from 0x400D26) */
    response[0] = ((uint8_t *)MODE_HEADER)[0];  /* mode data length */
    response[1] = ((uint8_t *)MODE_HEADER)[1];  /* medium type */
    response[2] = ((uint8_t *)MODE_HEADER)[2];  /* device-specific parameter */
    response[3] = 0;  /* block descriptor length (0 when DBD=1) */

    /* Copy mode page data (8 bytes) */
    for (int i = 0; i < 8; i++) {
        response[4 + i] = page_src[i];
    }

    /* Total response length = header(4) + page data(8) = 12 bytes */
    uint16_t send_len = 12;
    if (send_len > alloc_len && alloc_len != 0)
        send_len = alloc_len;

    /* Send response */
    usb_state_setup(*(uint8_t *)EXEC_MODE);
    usb_data_transfer(response, send_len);

done:
    pop_context();
}


/* ====================================================================
 * HANDLER 8: SCAN (0x1B) -- FW:0x0220B8
 *
 * Initiates a scan operation. The most complex standard SCSI handler
 * (~1800 bytes). Supports 6 operation types.
 *
 * CDB: [1B 00 00 00 XFER_LEN 00]
 *      XFER_LEN = byte 4: scan data length / window ID count
 *
 * Exec mode 0x00 (direct): handler manages its own USB data transfer
 * because SCAN has a data-out phase (window ID list from host).
 * ==================================================================== */

void handler_scan(void)  /* FW:0x0220B8 */
{
    push_context();
    uint8_t scan_descriptor[0x3C];  /* stack: scan descriptor buffer */

    uint8_t *cdb = (uint8_t *)CDB_BUFFER;

    /* -- CDB validation -- */
    if (cdb[1] & 0x1F) {
        *(uint16_t *)SENSE_RESULT = SENSE_INVALID_CDB;
        goto done;
    }
    for (int i = 2; i < 4; i++) {  /* bytes 2-3 must be zero */
        if (cdb[i] != 0) {
            *(uint16_t *)SENSE_RESULT = SENSE_INVALID_CDB;
            goto done;
        }
    }
    if (cdb[5] != 0) {
        *(uint16_t *)SENSE_RESULT = SENSE_INVALID_CDB;
        goto done;
    }

    /* Check exec_mode byte at 0x4007BA (CDB byte 4 offset) */
    uint8_t transfer_len = cdb[4];
    if (transfer_len > 4) {
        *(uint16_t *)SENSE_RESULT = SENSE_INVALID_PARAM;  /* 0x53 */
        goto done;
    }

    /* -- Receive scan window ID list from host -- */
    usb_state_setup(2);  /* exec mode 2 = data-out */
    usb_data_receive(scan_descriptor, transfer_len);

    if (*(uint16_t *)SENSE_RESULT != 0)
        goto done;

    /* -- Extract operation code from scan descriptor -- */
    uint8_t operation = scan_descriptor[0];

    /* Validate operation code against max allowed for current adapter */
    uint8_t max_ops = *(uint8_t *)SCAN_MAX_OPS;
    if (operation > max_ops && operation != SCAN_OP_EJECT) {
        *(uint16_t *)SENSE_RESULT = SENSE_INVALID_PARAM;
        goto done;
    }

    /* -- Dispatch by operation type -- */
    switch (operation) {
    case SCAN_OP_PREVIEW:     /* 0: Preview scan */
    case SCAN_OP_FINE_SINGLE: /* 1: Fine scan, single pass */
    case SCAN_OP_FINE_MULTI:  /* 2: Fine scan, multi-pass */
    case SCAN_OP_CALIBRATION: /* 3: Calibration scan */
        /* Set scan active flag */
        *(uint8_t *)SCAN_ACTIVE_FLAG = 1;
        *(uint8_t *)SCAN_OP_STATE = operation;

        /* Configure motor speed based on resolution and operation */
        /* Trigger scan start via internal task dispatch */
        /* The scan engine runs asynchronously; host polls with
         * TEST UNIT READY and retrieves data with READ. */
        break;

    case SCAN_OP_MOVE:        /* 4: Move to position */
        /* Position parameters from scan_descriptor[1..] */
        /* Dispatch motor task 0x0440 (relative move) */
        break;

    case SCAN_OP_EJECT:       /* 9: Eject film */
        /* Dispatch motor task 0x0430 (home/eject) */
        *(uint16_t *)SCANNER_STATE = 0x0080;  /* set ejecting state */
        break;

    default:
        *(uint16_t *)SENSE_RESULT = SENSE_INVALID_PARAM;
        break;
    }

done:
    pop_context();
}


/* ====================================================================
 * HANDLER 9: RECEIVE DIAGNOSTIC (0x1C) -- FW:0x023856
 *
 * Returns diagnostic results. Companion to SEND DIAGNOSTIC.
 * Supports diagnostic pages 0x05, 0x06, and 0x38 (vendor).
 * Also returns state-specific data for eject/film-advance states.
 *
 * CDB: [1C 00 PAGE ALLOC_MSB ALLOC_LSB 00]
 *      PAGE = byte 2: diagnostic page code
 *      ALLOC = bytes 3-4: allocation length (16-bit big-endian)
 * ==================================================================== */

void handler_receive_diagnostic(void)  /* FW:0x023856 */
{
    push_context();
    uint8_t response[0x106];  /* large response buffer */

    uint8_t *cdb = (uint8_t *)CDB_BUFFER;
    uint16_t *sense = (uint16_t *)SENSE_RESULT;
    uint16_t *cmd_result = (uint16_t *)CMD_RESULT_STATUS;

    /* -- CDB validation -- */
    if (cdb[1] & 0x1F) {
        *sense = SENSE_INVALID_CDB;
        goto done;
    }
    for (int i = 2; i < 4; i++) {
        if (cdb[i] != 0) {
            *sense = SENSE_INVALID_CDB;
            goto done;
        }
    }

    /* Get allocation length (CDB bytes 3-4, big-endian) */
    uint16_t alloc_len = ((uint16_t)cdb[3] << 8) | cdb[4];
    uint8_t offset = 0;  /* response byte counter */

    /* -- Check scanner diagnostic state -- */
    uint16_t diag_state = *cmd_result;

    if (diag_state == 0) {
        /* No diagnostic pending */
        *sense = SENSE_CMD_SEQ_ERROR;
        goto done;
    }

    /* Check for special states: 0x8000, 0x80FA, 0x80FB, 0x80FC */
    if (diag_state == 0x8000) {
        /* Standard diagnostic result page */
        /* Build response: [page_code(from *cmd_result+1), 0, 0, 2, 0, 0xFA] */
        response[0] = (diag_state >> 8) & 0xFF;
        response[1] = 0;
        response[2] = 0;
        response[3] = 2;
        response[4] = 0;
        response[5] = 0xFA;
        offset = 6;
    }
    else if (diag_state == 0x80FA) {
        /* FA page: motor/eject diagnostic results */
        response[0] = (diag_state >> 8) & 0xFF;
        response[1] = 0;
        response[2] = 0;
        response[3] = 2;
        /* Bytes 4-5: motor state from 0x4062E4/E5 */
        response[4] = *(uint8_t *)0x4062E4;
        response[5] = *(uint8_t *)0x4062E5;
        offset = 6;
    }
    else if (diag_state == 0x80FB) {
        /* FB page: extended scan status (52 bytes = 0x34 + header) */
        response[0] = (diag_state >> 8) & 0xFF;
        response[1] = 0;
        response[2] = 0;
        response[3] = 0x34;
        /* Copy 52 bytes of scan state from RAM 0x4062FA onward */
        for (int i = 0; i < 52; i++) {
            response[4 + i] = *(uint8_t *)(0x4062FA + i);
        }
        offset = 56;
    }
    else if (diag_state == 0x80FC) {
        /* FC page: adapter status (1 byte payload) */
        response[0] = (diag_state >> 8) & 0xFF;
        /* Check adapter type for position sensor data */
        uint8_t adapter = *(uint8_t *)ADAPTER_TYPE;
        if (adapter == 7 || adapter == 1 || adapter == 4 || adapter == 5) {
            check_adapter_position();
            uint8_t sensor = *(uint8_t *)0x4062DA;
            if (sensor & 0x08)
                response[0] |= 0x01;  /* set bit 0 */
        }
        /* Check GPIO port 6 bit 6 for film-present */
        /* ... (bit test on hardware port register) ... */
        offset = 1;
    }

    /* -- Send diagnostic response to host -- */
    uint16_t send_len = offset;
    if (send_len > alloc_len)
        send_len = alloc_len;

    usb_state_setup(*(uint8_t *)EXEC_MODE);
    usb_data_transfer(response, send_len);

done:
    pop_context();
}


/* ====================================================================
 * HANDLER 10: SEND DIAGNOSTIC (0x1D) -- FW:0x023D32
 *
 * Requests scanner self-test or sends diagnostic parameters.
 * State-dependent: same CDB triggers different firmware actions
 * depending on current scanner state.
 *
 * CDB: [1D FLAGS 00 PARM_MSB PARM_LSB 00]
 *      FLAGS bit 2: SelfTest (host always sends 0x04)
 *      PARM = bytes 3-4: parameter list length (0 for self-test)
 *
 * Supports diagnostic page codes 0x05, 0x06, 0x38 when PF=1.
 * ==================================================================== */

void handler_send_diagnostic(void)  /* FW:0x023D32 */
{
    push_context();
    uint8_t recv_buf[0x102];  /* receive buffer */

    uint16_t *cmd_result = (uint16_t *)CMD_RESULT_STATUS;  /* er3 -> 0x4007B4 */
    uint8_t  *cdb = (uint8_t *)CDB_BUFFER;                 /* er4 -> 0x4007B6 */
    uint16_t *sense = (uint16_t *)SENSE_RESULT;             /* er5 -> 0x4007B0 */
    /* er6 = sp + 1 (recv buffer pointer) */

    /* -- CDB validation -- */
    uint8_t flags = cdb[1];

    /* Only SelfTest (0x04) and PF (0x10) modes are supported */
    if (flags != 0x04 && flags != 0x10) {
        *sense = SENSE_INVALID_CDB;
        goto done;
    }

    /* Check CDB bytes 2-3 are zero, byte 5 is zero */
    for (int i = 2; i < 4; i++) {
        if (cdb[i] != 0) {
            *sense = SENSE_INVALID_CDB;
            goto done;
        }
    }
    if (cdb[5] != 0) {
        *sense = SENSE_INVALID_CDB;
        goto done;
    }

    /* Get parameter list length */
    uint8_t param_len = cdb[4];

    if (flags == 0x04) {
        /* -- SelfTest mode -- */
        if (param_len != 0) {
            *sense = SENSE_INVALID_CDB;
            goto done;
        }

        /* Store pending result */
        *cmd_result = *(uint16_t *)SENSE_AUX;

        /* Check scan buffer state for pending conditions */
        uint16_t buf_state = *(uint16_t *)SCAN_BUFFER_STATE;
        if (buf_state == 0x0110 || buf_state == 0x0120 || buf_state == 0x0121) {
            /* Expected state during init -- proceed */
            goto done;
        }

        /* Clear pending state and signal test complete */
        *(uint16_t *)SENSE_AUX = 0;
        goto done;
    }

    /* -- PF mode (flags == 0x10): diagnostic page data -- */
    /* Validate parameter list length */
    if (param_len == 0) {
        *cmd_result = 0x8000;  /* generic diagnostic complete */
        goto done;
    }

    /* Supported page codes: 0x05, 0x06, 0x38 */
    /* Must match parameter list length requirements */
    if (param_len != 4 && param_len != 5 && param_len != 6 && param_len != 0x38) {
        *sense = SENSE_PARAM_LIST_LEN;
        goto done;
    }

    /* Receive diagnostic data from host */
    usb_state_setup(*(uint8_t *)EXEC_MODE);
    usb_data_receive(recv_buf, param_len);

    if (*sense != 0)
        goto done;

    /* Dispatch by page code (first byte of received data) */
    uint8_t page_code = recv_buf[0];

    /* Check if page code is allowed for current adapter type */
    if (page_code != 0xFB && page_code != 0xFC) {
        uint8_t adapter = *(uint8_t *)ADAPTER_TYPE;
        if (adapter != 7) {  /* not factory test jig */
            *sense = SENSE_INVALID_CDB;
            goto done;
        }
    }

    switch (page_code) {
    case 0x00:
        /* Self-test result page */
        if (recv_buf[1] != 0 || recv_buf[2] != 0 || recv_buf[3] != 0) {
            *sense = SENSE_INVALID_PARAM;
            goto done;
        }
        *cmd_result = 0x8000;
        break;

    case 0xFA:
        /* Motor/eject diagnostic */
        if (recv_buf[1] != 0 || recv_buf[2] != 0 || recv_buf[3] != 0x02) {
            *sense = SENSE_INVALID_PARAM;
            goto done;
        }
        /* Store motor parameters */
        *(uint8_t *)0x4062E2 = recv_buf[4];
        *(uint8_t *)0x4062E3 = recv_buf[5];
        /* Trigger motor action */
        *(uint16_t *)SCANNER_FLAGS = 0x40FA;
        dispatch_internal_event();
        *cmd_result = 0x80FA;
        break;

    case 0xFB:
        /* Extended scan diagnostic */
        if (recv_buf[1] != 0 || recv_buf[2] != 0 || recv_buf[3] != 0x34) {
            *sense = SENSE_INVALID_PARAM;
            goto done;
        }
        *cmd_result = 0x80FB;
        break;

    case 0xFC:
        /* Adapter sensor diagnostic */
        if (recv_buf[1] != 0 || recv_buf[2] != 0 || recv_buf[3] != 0x01) {
            *sense = SENSE_INVALID_PARAM;
            goto done;
        }
        *cmd_result = 0x80FC;
        break;

    default:
        *sense = SENSE_INVALID_PARAM;
        break;
    }

done:
    pop_context();
}


/* ====================================================================
 * HANDLER 11: SET WINDOW (0x24) -- FW:0x026E38
 *
 * Receives window descriptor data defining scan parameters.
 * Configures resolution, bit depth, scan area, color mode, etc.
 *
 * CDB: [24 00 00 00 00 00 LEN_MSB LEN_MID LEN_LSB 80]
 *      LEN = bytes 6-8: transfer length (24-bit big-endian)
 *      Byte 9 = 0x80: Nikon vendor control flag
 *
 * This is the most important command for scan configuration.
 * ==================================================================== */

void handler_set_window(void)  /* FW:0x026E38 */
{
    push_context();
    uint8_t recv_buf[0x64];  /* stack: 100-byte receive buffer */

    uint8_t  *window_store = (uint8_t *)WINDOW_PARAMS;  /* er3 -> 0x4009C2 */
    /* er5 = sp + 0x1D (points into recv_buf for window descriptor) */
    uint8_t  *cdb = (uint8_t *)CDB_BUFFER;

    /* -- CDB validation -- */
    if (cdb[1] & 0x1F) {
        *(uint16_t *)SENSE_RESULT = SENSE_INVALID_CDB;
        goto done;
    }
    for (int i = 2; i < 6; i++) {
        if (cdb[i] != 0) {
            *(uint16_t *)SENSE_RESULT = SENSE_INVALID_CDB;
            goto done;
        }
    }

    /* CDB[9] (0x4007BF) low 7 bits must be zero (vendor flag in bit 7 OK) */
    if (cdb[9] & 0x7F) {
        *(uint16_t *)SENSE_RESULT = SENSE_INVALID_CDB;
        goto done;
    }

    /* -- Extract transfer length (24-bit big-endian from CDB[6..8]) -- */
    uint32_t transfer_len = ((uint32_t)cdb[6] << 16) |
                            ((uint32_t)cdb[7] << 8)  |
                             (uint32_t)cdb[8];

    if (transfer_len == 0) {
        /* Zero-length: nothing to do */
        goto done;
    }

    /* Validate transfer length range: 8 <= len <= 66 (0x42) */
    if (transfer_len < 8 || transfer_len > 0x42) {
        *(uint16_t *)SENSE_RESULT = SENSE_INVALID_CDB;
        goto done;
    }

    /* -- Receive window descriptor from host -- */
    usb_state_setup(*(uint8_t *)EXEC_MODE);
    usb_data_receive(recv_buf, (uint16_t)transfer_len);

    if (*(uint16_t *)SENSE_RESULT != 0)
        goto done;

    /* Subtract window parameter header size (8 bytes) */
    transfer_len -= 8;

    /* Validate: window descriptor length field (bytes 6-7 of header)
     * must match remaining transfer length */
    uint16_t desc_len = ((uint16_t)recv_buf[6] << 8) | recv_buf[7];
    if (desc_len != transfer_len) {
        *(uint16_t *)SENSE_RESULT = SENSE_INVALID_PARAM;
        goto done;
    }

    if (transfer_len == 0)
        goto done;

    /* Check vendor flag bit (CDB[9] bit 7 = 0x80) */
    uint8_t vendor_ext = (cdb[9] & 0x80) ? 1 : 0;
    if (!vendor_ext) {
        /* Without vendor flag, window ID 9 not allowed */
        if (recv_buf[0x25] == 9) {
            *(uint16_t *)SENSE_RESULT = SENSE_INVALID_CDB;
            goto done;
        }
    }

    /* -- Resolution calculation -- */
    /* If max_resolution == 0x4B0 (1200 DPI base): */
    uint16_t max_res = *(uint16_t *)MAX_RESOLUTION;

    if (max_res == 0x04B0) {  /* 1200 DPI */
        /* Formula: (scan_resolution + 2) * 0x6C6 */
        uint8_t res_code = *(uint8_t *)RESOLUTION_SETTING;
        uint32_t step = ((uint32_t)res_code + 2) * 0x6C6;  /* 1734 */
        *(uint32_t *)RESOLUTION_X_STEP = step;
        *(uint32_t *)RESOLUTION_Y_STEP = step;
        *(uint32_t *)RESOLUTION_Z_STEP = step;
        /* Auxiliary calc: res_code * 0x537 */
        *(uint32_t *)RESOLUTION_AUX = (uint32_t)res_code * 0x537;
    }
    else if (max_res == 0x0FA0) {  /* 4000 DPI */
        /* Formula: (scan_resolution + 2) * 0x1747 */
        uint8_t res_code = *(uint8_t *)RESOLUTION_SETTING;
        uint32_t step = ((uint32_t)res_code + 2) * 0x1747;  /* 5959 */
        *(uint32_t *)RESOLUTION_X_STEP = step;
        *(uint32_t *)RESOLUTION_Y_STEP = step;
        *(uint32_t *)RESOLUTION_Z_STEP = step;
        *(uint32_t *)RESOLUTION_AUX = (uint32_t)res_code * 0x1165;
    }

    /* -- Parse and store window descriptor fields -- */
    /* Point past the 8-byte header to the window descriptor data */
    uint8_t *wd = recv_buf + 8;

    /* Parse standard SCSI window descriptor fields:
     * wd[0]    = window ID
     * wd[2-3]  = X resolution (big-endian)
     * wd[4-5]  = Y resolution
     * wd[6-9]  = upper-left X
     * wd[10-13] = upper-left Y
     * wd[14-17] = width
     * wd[18-21] = height
     * wd[25]   = image composition (0=BW, 2=gray, 5=RGB)
     * wd[26]   = bits per pixel
     * wd[33+]  = Nikon vendor extensions
     */
    uint16_t validated = parse_window_descriptor(wd, (uint16_t)transfer_len);

    /* Check for validation errors */
    if (validated < transfer_len) {
        if (*(uint16_t *)SENSE_RESULT == SENSE_INVALID_PARAM) {
            goto done;  /* parse_window_descriptor set the error */
        }
    }

    /* Copy validated descriptor to window parameter storage (0x4009C2) */
    /* The descriptor is stored at an offset based on window ID:
     * ID 9 -> offset 0xE8
     * ID 4 -> offset 0x122
     * Other IDs -> offset = ID * 0x3A
     */
    uint8_t win_id = wd[0];
    uint32_t store_offset;
    if (win_id == 9) {
        store_offset = 0xE8;
    } else if (wd[8] == 4) {  /* special sub-window ID */
        store_offset = 0x122;
    } else {
        store_offset = (uint32_t)win_id * 0x3A;
    }

    uint8_t *dest = window_store + store_offset;
    for (uint16_t i = 0; i < validated; i++) {
        dest[i] = wd[i + 1];  /* skip window ID byte */
    }

done:
    pop_context();
}


/* ====================================================================
 * HANDLER 12: GET WINDOW (0x25) -- FW:0x0272F6
 *
 * Returns the window descriptor previously set by SET WINDOW.
 * Mirrors the SET WINDOW data structure.
 *
 * CDB: [25 00 00 00 00 WIN_ID LEN_MSB LEN_MID LEN_LSB 80]
 *      WIN_ID = byte 5: window identifier
 *      LEN = bytes 6-8: allocation length
 * ==================================================================== */

void handler_get_window(void)  /* FW:0x0272F6 */
{
    push_context();
    uint8_t response[0x64];  /* response buffer */

    uint8_t *window_store = (uint8_t *)WINDOW_PARAMS;
    uint8_t *cdb = (uint8_t *)CDB_BUFFER;

    /* -- CDB validation (same pattern as SET WINDOW) -- */
    if (cdb[1] & 0x1F) {
        *(uint16_t *)SENSE_RESULT = SENSE_INVALID_CDB;
        goto done;
    }
    /* ... validate reserved bytes ... */

    /* Extract window ID and allocation length */
    uint8_t win_id = cdb[5];
    uint32_t alloc_len = ((uint32_t)cdb[6] << 16) |
                         ((uint32_t)cdb[7] << 8)  |
                          (uint32_t)cdb[8];

    /* Look up stored window descriptor */
    uint32_t store_offset = (uint32_t)win_id * 0x3A;
    uint8_t *src = window_store + store_offset;

    /* Build response: 8-byte header + window descriptor */
    /* Header bytes 0-5: reserved (zero) */
    for (int i = 0; i < 6; i++) response[i] = 0;
    /* Header bytes 6-7: window descriptor length */
    uint16_t desc_len = 0x3A;  /* standard descriptor size */
    response[6] = (desc_len >> 8) & 0xFF;
    response[7] = desc_len & 0xFF;

    /* Copy stored descriptor */
    for (int i = 0; i < desc_len; i++) {
        response[8 + i] = src[i];
    }

    uint16_t send_len = 8 + desc_len;
    if (send_len > alloc_len)
        send_len = (uint16_t)alloc_len;

    usb_state_setup(*(uint8_t *)EXEC_MODE);
    usb_data_transfer(response, send_len);

done:
    pop_context();
}


/* ====================================================================
 * HANDLER 13: READ(10) (0x28) -- FW:0x023F10
 *
 * Reads scan data, calibration data, or other scanner data.
 * Primary command for retrieving scanned image data after SCAN.
 *
 * CDB: [28 00 DTC 00 00 DTQ LEN_MSB LEN_MID LEN_LSB 80]
 *      DTC = byte 2: Data Type Code (what kind of data)
 *      DTQ = byte 5: Data Type Qualifier (sub-type / channel)
 *      LEN = bytes 6-8: transfer length (24-bit big-endian)
 *      Byte 9 = 0x80: Nikon vendor flag
 *
 * Permission flags 0x0054: only allowed during active read state.
 * ==================================================================== */

void handler_read_10(void)  /* FW:0x023F10 */
{
    push_context();
    uint8_t response[0x200];  /* stack: response buffer (varies by DTC) */

    uint8_t *cdb = (uint8_t *)CDB_BUFFER;

    /* -- CDB validation -- */
    if (cdb[1] & 0x1F) {
        *(uint16_t *)SENSE_RESULT = SENSE_INVALID_CDB;
        goto done;
    }
    if (cdb[3] != 0 || cdb[4] != 0) {
        *(uint16_t *)SENSE_RESULT = SENSE_INVALID_CDB;
        goto done;
    }

    /* Extract fields */
    uint8_t dtc = cdb[2];      /* Data Type Code */
    uint8_t dtq = cdb[5];      /* Data Type Qualifier */
    uint32_t transfer_len = ((uint32_t)cdb[6] << 16) |
                            ((uint32_t)cdb[7] << 8)  |
                             (uint32_t)cdb[8];

    /* -- DTC dispatch --
     * Firmware walks the READ DTC table at FW:0x49AD8 (15 entries x 12 bytes).
     * Each entry: [dtc_value:8, qualifier_category:8, max_size:16, handler_offset:32, ...]
     * Table terminated by 0xFF.
     */
    uint8_t *dtc_entry = (uint8_t *)READ_DTC_TABLE;
    int found = 0;

    while (*dtc_entry != 0xFF) {
        if (*dtc_entry == dtc) {
            found = 1;
            break;
        }
        dtc_entry += 12;  /* 12-byte stride */
    }

    if (!found) {
        *(uint16_t *)SENSE_RESULT = SENSE_INVALID_CDB;
        goto done;
    }

    /* -- Validate qualifier against category -- */
    uint8_t qual_cat = dtc_entry[1];
    switch (qual_cat) {
    case 0x00:  /* No qualifier needed -- ignore DTQ */
        break;
    case 0x01:  /* Single value -- DTQ must match table */
        if (dtq != dtc_entry[2]) {
            *(uint16_t *)SENSE_RESULT = SENSE_INVALID_CDB;
            goto done;
        }
        break;
    case 0x03:  /* Channel select: 0-3 */
        if (dtq > 3) {
            *(uint16_t *)SENSE_RESULT = SENSE_INVALID_CDB;
            goto done;
        }
        break;
    case 0x10:  /* Two-mode: 0 or 1 */
        if (dtq > 1) {
            *(uint16_t *)SENSE_RESULT = SENSE_INVALID_CDB;
            goto done;
        }
        break;
    case 0x30:  /* Three-mode: 0, 1, or 3 (skips 2) */
        if (dtq != 0 && dtq != 1 && dtq != 3) {
            *(uint16_t *)SENSE_RESULT = SENSE_INVALID_CDB;
            goto done;
        }
        break;
    }

    /* -- Validate transfer length against max -- */
    uint16_t max_size = ((uint16_t)dtc_entry[2] << 8) | dtc_entry[3];
    if (transfer_len > max_size && max_size != 0) {
        *(uint16_t *)SENSE_RESULT = SENSE_INVALID_CDB;
        goto done;
    }

    /* -- DTC sub-handler dispatch at FW:0x0240E2 -- */
    switch (dtc) {
    case DTC_IMAGE_DATA:    /* 0x00: Scan image pixels */
        /* Transfer from ASIC buffer RAM (0x800000+) or buffer RAM (0xC00000+)
         * via ISP1581 DMA engine. The scan engine has already filled the
         * buffer; this just ships it to the host. */
        /* ... DMA transfer logic ... */
        break;

    case DTC_GAMMA_LUT:     /* 0x03: Gamma/LUT table readback */
        /* Read LUT data from ASIC LUT memory */
        break;

    case DTC_SCAN_AREA:     /* 0x81: Scan area info (8 bytes) */
        /* Return film frame dimensions */
        break;

    case DTC_CALIBRATION:   /* 0x84: Calibration data (6 bytes) */
        /* Return current calibration values */
        break;

    case DTC_SCAN_PARAMS:   /* 0x87: Scan parameters (24 bytes) */
        /* Return current scan configuration status */
        break;

    case DTC_BOUNDARY_CAL:  /* 0x88: Boundary/per-channel cal (644 bytes) */
        /* Return per-channel calibration boundary data */
        break;

    case DTC_EXPOSURE_GAIN: /* 0x8A: Exposure/gain (14 bytes) */
        /* Return exposure time and gain values per channel */
        break;

    case DTC_OFFSET_DARK:   /* 0x8C: Offset/dark current (10 bytes) */
        /* Sub-handler at FW:0x24BB4 */
        /* Reads from RAM 0x40107C (word) and 0x40108C (word) */
        break;

    case DTC_EXT_SCANLINE:  /* 0x8D: Extended scan line data */
        break;

    case DTC_FOCUS_MEASURE: /* 0x8E: Focus measurement data */
        /* Sub-handler at FW:0x24CDE */
        /* Reads focus data from 0x405282 */
        break;

    case DTC_HISTOGRAM:     /* 0x8F: Histogram/profile (324 bytes) */
        break;

    case DTC_CCD_CHAR:      /* 0x90: CCD characterization (54 bytes) */
        /* Sub-handler at FW:0x24E84 */
        /* Validates adapter_type must be 0x06 or 0x07 */
        break;

    case DTC_MOTOR_STATUS:  /* 0x92: Motor/positioning (10 bytes) */
        /* Sub-handler at FW:0x24F82 */
        /* Copies 10 bytes from MOTOR_STATE_BLOCK (0x400B20) */
        break;

    case DTC_ADAPTER_INFO:  /* 0x93: Adapter/film info (12 bytes) */
        /* Sub-handler at FW:0x24FC4 */
        /* Copies 12 bytes from 0x60042 (adapter identification) */
        break;

    case DTC_EXT_CONFIG:    /* 0xE0: Extended configuration (1030 bytes) */
        break;

    default:
        *(uint16_t *)SENSE_RESULT = SENSE_INVALID_CDB;
        break;
    }

    /* -- Send response data to host -- */
    if (*(uint16_t *)SENSE_RESULT == 0) {
        usb_state_setup(*(uint8_t *)EXEC_MODE);
        usb_data_transfer(response, (uint16_t)transfer_len);
    }

done:
    pop_context();
}


/* ====================================================================
 * HANDLER 14: WRITE/SEND(10) (0x2A) -- FW:0x025506
 *
 * Sends data to scanner: calibration, LUTs, motor commands, config.
 * Mirror of READ but with data flowing host -> device.
 *
 * CDB: [2A 00 DTC 00 00 DTQ LEN_MSB LEN_MID LEN_LSB 00]
 *      DTC = byte 2: Data Type Code
 *      DTQ = byte 5: Data Type Qualifier
 *      LEN = bytes 6-8: transfer length
 *      Byte 9 = 0x00 (no vendor flag for WRITE)
 *
 * 7 supported DTCs vs READ's 15.
 * ==================================================================== */

void handler_write_10(void)  /* FW:0x025506 */
{
    push_context();
    uint8_t recv_buf[0x200];  /* receive buffer */

    uint8_t *cdb = (uint8_t *)CDB_BUFFER;

    /* -- CDB validation (same pattern as READ) -- */
    if (cdb[1] & 0x1F) {
        *(uint16_t *)SENSE_RESULT = SENSE_INVALID_CDB;
        goto done;
    }
    if (cdb[3] != 0 || cdb[4] != 0) {
        *(uint16_t *)SENSE_RESULT = SENSE_INVALID_CDB;
        goto done;
    }

    uint8_t dtc = cdb[2];
    uint8_t dtq = cdb[5];
    uint32_t transfer_len = ((uint32_t)cdb[6] << 16) |
                            ((uint32_t)cdb[7] << 8)  |
                             (uint32_t)cdb[8];

    /* -- DTC dispatch (FW:0x025622) --
     * Firmware walks WRITE DTC table at FW:0x49B98 (7 entries x 10 bytes).
     * Each entry: [dtc_value:8, qualifier_category:8, max_size:16, ...]
     * Same validation logic as READ for qualifiers and sizes.
     */

    /* -- Validate and receive data -- */
    usb_state_setup(*(uint8_t *)EXEC_MODE);
    usb_data_receive(recv_buf, (uint16_t)transfer_len);

    if (*(uint16_t *)SENSE_RESULT != 0)
        goto done;

    /* -- DTC sub-handler dispatch at FW:0x025622 -- */
    switch (dtc) {
    case 0x03:  /* Gamma/LUT upload (up to 32768 bytes) */
        /* FW:0x025650 */
        /* Write LUT data to ASIC LUT memory for hardware tone mapping */
        break;

    case 0x84:  /* Calibration data upload (6 bytes) */
        /* FW:0x025722 */
        /* Store calibration override values */
        break;

    case 0x85:  /* Extended calibration (WRITE-only, no READ counterpart) */
        /* FW:0x025830 */
        /* Per-pixel gain/offset correction data */
        break;

    case 0x88:  /* Boundary / per-channel calibration (644 bytes) */
        /* FW:0x0258F0 */
        break;

    case 0x8F:  /* Histogram / profile upload (324 bytes) */
        /* FW:0x02591C */
        break;

    case 0x92:  /* Motor / positioning control (4 bytes) */
        /* FW:0x025908 */
        /* Payload: [motor_id, op_mode, direction_flags, step_count]
         *   motor_id: 0x01=scan motor, 0x02=focus motor
         *   direction_flags: bit 0=direction, bits 4-7=speed profile
         * Writes to 0x400790 (motor_state) and dispatches via FW:0x25B6A */
        if (transfer_len != 4) {
            *(uint16_t *)SENSE_RESULT = SENSE_INVALID_CDB;
            goto done;
        }
        /* Validate motor ID and direction byte */
        if (recv_buf[0] != 0x01 && recv_buf[0] != 0x02) {
            *(uint16_t *)SENSE_RESULT = SENSE_INVALID_PARAM;
            goto done;
        }
        /* Store and execute motor command */
        *(uint8_t *)0x400790 = recv_buf[0];
        /* ... dispatch motor subroutine ... */
        break;

    case 0xE0:  /* Extended configuration upload (1024 bytes) */
        /* FW:0x02591C (shares entry with 0x8F) */
        break;

    default:
        *(uint16_t *)SENSE_RESULT = SENSE_INVALID_CDB;
        break;
    }

done:
    pop_context();
}


/* ====================================================================
 * HANDLER 15: WRITE BUFFER (0x3B) -- FW:0x02837C
 *
 * Standard SCSI WRITE BUFFER. Used for firmware updates (not normal
 * NikonScan scanning workflow). A separate firmware update utility
 * likely uses this command.
 *
 * CDB: [3B MODE BUF_ID OFF_MSB OFF_MID OFF_LSB LEN_MSB LEN_MID LEN_LSB 00]
 *      MODE = byte 1: write buffer mode
 *      BUF_ID = byte 2: buffer identifier
 *      OFF = bytes 3-5: buffer offset (24-bit)
 *      LEN = bytes 6-8: transfer length (24-bit)
 * ==================================================================== */

void handler_write_buffer(void)  /* FW:0x02837C */
{
    push_context();

    uint8_t *cdb = (uint8_t *)CDB_BUFFER;

    /* -- CDB validation -- */
    uint8_t mode = cdb[1] & 0x1F;
    uint8_t buf_id = cdb[2];

    /* Extract buffer offset and transfer length */
    uint32_t offset = ((uint32_t)cdb[3] << 16) |
                      ((uint32_t)cdb[4] << 8)  |
                       (uint32_t)cdb[5];
    uint32_t length = ((uint32_t)cdb[6] << 16) |
                      ((uint32_t)cdb[7] << 8)  |
                       (uint32_t)cdb[8];

    /* Validate mode (supported modes are device-specific) */
    /* Validate buffer ID and offset/length against flash boundaries */

    if (length == 0)
        goto done;

    /* Receive data from host */
    usb_state_setup(*(uint8_t *)EXEC_MODE);
    usb_data_receive((void *)(0x400000 + offset), (uint16_t)length);
    /* Note: actual write destination depends on mode and buf_id */

    /* For firmware update mode, data would be written to flash.
     * The firmware uses the flash controller to erase and program
     * sectors in the MBM29F400B chip. */

done:
    pop_context();
}


/* ====================================================================
 * HANDLER 16: READ BUFFER (0x3C) -- FW:0x028884
 *
 * Standard SCSI READ BUFFER. Reads firmware/diagnostic data.
 *
 * CDB: [3C MODE BUF_ID OFF_MSB OFF_MID OFF_LSB LEN_MSB LEN_MID LEN_LSB 00]
 * ==================================================================== */

void handler_read_buffer(void)  /* FW:0x028884 */
{
    push_context();

    uint8_t *cdb = (uint8_t *)CDB_BUFFER;

    uint8_t mode = cdb[1] & 0x1F;
    uint8_t buf_id = cdb[2];
    uint32_t offset = ((uint32_t)cdb[3] << 16) |
                      ((uint32_t)cdb[4] << 8)  |
                       (uint32_t)cdb[5];
    uint32_t length = ((uint32_t)cdb[6] << 16) |
                      ((uint32_t)cdb[7] << 8)  |
                       (uint32_t)cdb[8];

    /* Validate mode and buffer ID */
    /* The firmware uses a lookup table at FW:0x4A114 to validate
     * the buffer ID and compute the actual source address.
     * Table format: [buf_id -> (base_addr:32, max_size:32)] */

    if (length == 0)
        goto done;

    /* Send buffer data to host */
    usb_state_setup(*(uint8_t *)EXEC_MODE);
    usb_data_transfer((void *)(0x400000 + offset), (uint16_t)length);

done:
    pop_context();
}


/* ====================================================================
 * HANDLER 17: VENDOR C0 -- Status Query -- FW:0x028AB4
 *
 * The simplest handler (~80 bytes). Checks scanner abort/completion
 * state. No data transfer.
 *
 * CDB: [C0 00 00 00 00 00]
 * ==================================================================== */

void handler_vendor_c0(void)  /* FW:0x028AB4 */
{
    push_context();

    uint8_t *cdb = (uint8_t *)CDB_BUFFER;

    /* CDB validation: bytes 1-5 must be zero */
    if (cdb[1] & 0x1F) {
        *(uint16_t *)SENSE_RESULT = SENSE_INVALID_CDB;
        goto done;
    }
    for (int i = 2; i <= 5; i++) {
        if (cdb[i] != 0) {
            *(uint16_t *)SENSE_RESULT = SENSE_INVALID_CDB;
            goto done;
        }
    }

    /* Check abort flag at SCANNER_FLAGS bit 6 */
    uint16_t flags = *(uint16_t *)SCANNER_FLAGS;
    if (flags & 0x0040) {
        /* Abort was requested: set response pending (bit 7) */
        *(uint16_t *)SCANNER_FLAGS = flags | 0x0080;
        /* Clear transfer count */
        *(uint16_t *)SENSE_AUX = 0;
    }

    /* No data transfer -- status only */

done:
    pop_context();
}


/* ====================================================================
 * HANDLER 18: VENDOR C1 -- Trigger Action -- FW:0x028B08
 *
 * Action dispatcher. Reads subcommand code from VENDOR_SUBCOMMAND
 * (set previously by E0) and dispatches to the appropriate operation.
 * ~730 bytes, 23 subcommand codes.
 *
 * CDB: [C1 00 00 00 00 00]
 *
 * The E0 -> C1 -> E1 cycle:
 *   E0 writes parameters to vendor registers
 *   C1 triggers the operation using those parameters
 *   E1 reads back results
 * ==================================================================== */

void handler_vendor_c1(void)  /* FW:0x028B08 */
{
    push_context();

    uint8_t *cdb = (uint8_t *)CDB_BUFFER;

    /* CDB validation: bytes 1-5 must be zero */
    if (cdb[1] & 0x1F) {
        *(uint16_t *)SENSE_RESULT = SENSE_INVALID_CDB;
        goto done;
    }
    for (int i = 2; i <= 5; i++) {
        if (cdb[i] != 0) {
            *(uint16_t *)SENSE_RESULT = SENSE_INVALID_CDB;
            goto done;
        }
    }

    /* Read subcommand code (previously set by E0 handler) */
    uint8_t subcmd = *(uint8_t *)VENDOR_SUBCOMMAND;

    /* -- Subcommand dispatch -- */
    switch (subcmd) {
    case 0x40: case 0x41: case 0x42: case 0x43:
        /* Scan operation variants 0-3 */
        /* Trigger scan with parameters written by E0 */
        /* Dispatches to scan engine via internal task codes 0x0800+ */
        break;

    case 0x44:
        /* Motor: move to position */
        /* Uses position data from E0 (5 bytes at vendor regs) */
        break;

    case 0x45: case 0x46: case 0x47:
        /* Calibration operation variants */
        /* Trigger CCD/LED calibration with E0 parameters */
        break;

    case 0x80:
        /* Lamp on/off control */
        /* Toggle scanner LED/lamp power */
        /* No parameters needed (trigger-only) */
        break;

    case 0x81:
        /* Motor initialization */
        /* Home motor, calibrate encoder, find reference position */
        break;

    case 0x91:
        /* Step motor command */
        /* Direction + step count from E0 (5 bytes) */
        break;

    case 0xA0:
        /* CCD/sensor setup */
        /* Configure CCD timing and integration from E0 (9 bytes) */
        break;

    case 0xB0: case 0xB1:
        /* State change triggers */
        break;

    case 0xB3:
        /* Write configuration data (13 bytes from E0) */
        break;

    case 0xB4:
        /* Write extended config (9 bytes from E0) */
        break;

    case 0xC0:
        /* Gain calibration */
        /* Apply gain values from E0 (5 bytes) */
        break;

    case 0xC1:
        /* Offset calibration */
        /* Apply offset values from E0 (5 bytes) */
        break;

    case 0xD0: case 0xD1:
        /* Diagnostic triggers (no data) */
        break;

    case 0xD2:
        /* Diagnostic with data (5 bytes from E0) */
        break;

    case 0xD5:
        /* Extended diagnostic (5 bytes from E0) */
        break;

    case 0xD6:
        /* Write persistent settings to flash (5 bytes from E0) */
        break;

    default:
        *(uint16_t *)SENSE_RESULT = SENSE_INVALID_CDB;
        break;
    }

done:
    pop_context();
}


/* ====================================================================
 * HANDLER 19: VENDOR D0 -- Phase Query -- FW:0x013748
 *
 * USB protocol phase query. The ONLY handler in the shared module
 * region (0x10000-0x17FFF). Permission flags 0x07FF (always allowed).
 *
 * This is NOT a scanner command -- it is a USB transport mechanism.
 * The host USB driver (NKDUSCAN.dll) sends opcode 0xD0 to poll for
 * command completion status. LS5000.md3 never builds this CDB.
 *
 * CDB: [D0 ...] (minimal -- opcode only matters)
 * ==================================================================== */

void handler_vendor_d0(void)  /* FW:0x013748 */
{
    /*
     * This handler is extremely small (only a few instructions).
     * It reads the current USB transaction phase from USB_PHASE (0x40049C)
     * and the in-progress flag from USB_IN_PROGRESS (0x40049A), then
     * returns the phase byte to the host via the ISP1581 bulk-in endpoint.
     *
     * The host driver polls with D0 to determine:
     *   - Is the device ready for data transfer?
     *   - Has the command completed?
     *   - Is there sense data to retrieve?
     */

    /* Read current phase and return to host */
    uint8_t phase = *(uint8_t *)USB_PHASE;

    /* The actual implementation at FW:0x013748:
     *   mov.b r0l, r0h        ; r0h = r0l (copy phase byte)
     *   mov.b @0x40049A, r0l  ; r0l = USB in-progress flag
     * The caller (usb_state_setup at 0x1374A) then writes the phase
     * byte to the ISP1581 endpoint data register (0x600020).
     */
}


/* ====================================================================
 * HANDLER 20: VENDOR E0 -- Data Out to Vendor Registers -- FW:0x028E16
 *
 * Writes configuration/control data to scanner vendor registers.
 * First command in the E0 -> C1 -> E1 cycle.
 *
 * CDB: [E0 00 SUBCMD 00 00 00 LEN_MSB LEN_MID LEN_LSB 00]
 *      SUBCMD = byte 2: register / sub-command identifier
 *      LEN = bytes 6-8: transfer length (24-bit big-endian)
 *
 * The sub-command byte maps to the vendor register table at FW:0x4A134.
 * ==================================================================== */

void handler_vendor_e0(void)  /* FW:0x028E16 */
{
    push_context();
    uint8_t recv_buf[0x18];  /* receive buffer (max 13 bytes payload) */

    uint8_t *cdb = (uint8_t *)CDB_BUFFER;

    /* -- CDB validation -- */
    if (cdb[3] != 0 || cdb[4] != 0 || cdb[5] != 0) {
        *(uint16_t *)SENSE_RESULT = SENSE_INVALID_CDB;
        goto done;
    }
    /* Check CDB[9] (cmd_category) must be zero */
    if (cdb[9] != 0) {
        *(uint16_t *)SENSE_RESULT = SENSE_INVALID_CDB;
        goto done;
    }

    uint8_t subcmd = cdb[2];  /* register / sub-command ID */
    uint32_t transfer_len = ((uint32_t)cdb[6] << 16) |
                            ((uint32_t)cdb[7] << 8)  |
                             (uint32_t)cdb[8];

    /* -- Register table lookup at FW:0x4A134 -- */
    /* Table: 23 entries, each 2 bytes: [reg_id:8, max_data_len:8]
     * Terminated by 0xFF marker. */
    uint8_t *reg_entry = (uint8_t *)VENDOR_REG_TABLE;
    int found = 0;
    uint8_t max_len = 0;

    while (*reg_entry != 0xFF) {
        if (*reg_entry == subcmd) {
            max_len = reg_entry[1];
            found = 1;
            break;
        }
        reg_entry += 2;
    }

    if (!found) {
        *(uint16_t *)SENSE_RESULT = SENSE_INVALID_CDB;
        goto done;
    }

    /* Validate transfer length against max */
    if (transfer_len > max_len) {
        *(uint16_t *)SENSE_RESULT = SENSE_INVALID_CDB;
        goto done;
    }

    /* Store the sub-command code for C1 to reference */
    *(uint8_t *)VENDOR_SUBCOMMAND = subcmd;

    if (transfer_len == 0) {
        /* Trigger-only command (max_len = 0): no data to receive */
        goto done;
    }

    /* -- Receive register data from host -- */
    usb_state_setup(*(uint8_t *)EXEC_MODE);
    usb_data_receive(recv_buf, (uint16_t)transfer_len);

    if (*(uint16_t *)SENSE_RESULT != 0)
        goto done;

    /* -- Store received data to vendor register storage -- */
    /* Data layout (from received bytes):
     *   byte[0]:    register sub-address or parameter code
     *   byte[1-4]:  32-bit register address (for some sub-commands)
     *   byte[5-8]:  32-bit data value
     *   byte[9-10]: additional parameters
     *
     * The exact interpretation depends on the sub-command:
     *   0x40-0x47: scan/cal/motor parameters stored at 0x400D** area
     *   0x91:      motor step: direction + count (5 bytes)
     *   0xA0:      CCD setup: timing parameters (9 bytes)
     *   0xB3-0xB4: configuration data
     *   0xC0-0xC1: calibration gain/offset values
     *   0xD2/D5/D6: diagnostic/persistent data
     */

    /* For scan-related sub-commands (0x40-0x47), the firmware also
     * computes resolution step values using the formula:
     *   step = (scan_resolution + 2) * multiplier
     * where multiplier is 0x6C6 (1200 DPI base) or 0x1747 (4000 DPI base)
     */

done:
    pop_context();
}


/* ====================================================================
 * HANDLER 21: VENDOR E1 -- Data In from Vendor Registers -- FW:0x0295EA
 *
 * Reads configuration/status data from scanner vendor registers.
 * Last command in the E0 -> C1 -> E1 cycle (reads results).
 * Mirror of E0 but data flows device -> host.
 *
 * CDB: [E1 00 SUBCMD 00 00 00 LEN_MSB LEN_MID LEN_LSB 00]
 *      SUBCMD = byte 2: register / sub-command identifier
 *      LEN = bytes 6-8: allocation length
 * ==================================================================== */

void handler_vendor_e1(void)  /* FW:0x0295EA */
{
    push_context();
    uint8_t response[0x20];  /* response buffer */

    uint8_t *cdb = (uint8_t *)CDB_BUFFER;

    /* -- CDB validation (same as E0) -- */
    if (cdb[3] != 0 || cdb[4] != 0 || cdb[5] != 0) {
        *(uint16_t *)SENSE_RESULT = SENSE_INVALID_CDB;
        goto done;
    }
    if (cdb[9] != 0) {
        *(uint16_t *)SENSE_RESULT = SENSE_INVALID_CDB;
        goto done;
    }

    uint8_t subcmd = cdb[2];
    uint32_t alloc_len = ((uint32_t)cdb[6] << 16) |
                         ((uint32_t)cdb[7] << 8)  |
                          (uint32_t)cdb[8];

    /* -- Same register table lookup as E0 -- */
    uint8_t *reg_entry = (uint8_t *)VENDOR_REG_TABLE;
    int found = 0;
    uint8_t max_len = 0;

    while (*reg_entry != 0xFF) {
        if (*reg_entry == subcmd) {
            max_len = reg_entry[1];
            found = 1;
            break;
        }
        reg_entry += 2;
    }

    if (!found) {
        *(uint16_t *)SENSE_RESULT = SENSE_INVALID_CDB;
        goto done;
    }

    if (alloc_len > max_len) {
        *(uint16_t *)SENSE_RESULT = SENSE_INVALID_CDB;
        goto done;
    }

    if (alloc_len == 0)
        goto done;

    /* -- Read register data and build response -- */
    /* The data source mirrors E0's data destination:
     *   0x40-0x47: current scan/cal/motor parameter values
     *   0x91:      current motor position and state (5 bytes)
     *   0xA0:      current CCD setup values (9 bytes)
     *   0xC0-0xC1: current gain/offset calibration results
     *   0xD2:      diagnostic result data
     * These values may have been updated by the C1 trigger action.
     */

    /* Fill response buffer from the appropriate RAM location */
    /* ... register-specific read logic ... */

    /* -- Send response to host -- */
    usb_state_setup(*(uint8_t *)EXEC_MODE);
    usb_data_transfer(response, (uint16_t)alloc_len);

done:
    pop_context();
}


/* ====================================================================
 * END OF HANDLER PSEUDOCODE
 *
 * Summary of the 21 SCSI handlers:
 *
 *   Standard SCSI commands (17, matching LS5000.md3 host-side CDB builders):
 *     0x00 TEST UNIT READY  -- Scanner readiness state machine (~700 bytes)
 *     0x12 INQUIRY          -- Device ID + VPD pages, adapter-specific (~580 bytes)
 *     0x15 MODE SELECT      -- Receive mode page data (~500 bytes)
 *     0x16 RESERVE          -- Claim device for exclusive use (~60 bytes)
 *     0x17 RELEASE          -- Release device reservation (~60 bytes)
 *     0x1A MODE SENSE        -- Return mode pages (page 0x03, 0x3F) (~420 bytes)
 *     0x1B SCAN             -- Initiate scan operation, 6 op types (~1800 bytes)
 *     0x1C RECEIVE DIAG     -- Return diagnostic results (~1244 bytes)
 *     0x1D SEND DIAGNOSTIC  -- Self-test / diagnostic params (~478 bytes)
 *     0x24 SET WINDOW       -- Configure scan parameters (resolution, area, depth)
 *     0x25 GET WINDOW       -- Read back window parameters
 *     0x28 READ(10)         -- Read scan/calibration data (15 DTCs)
 *     0x2A WRITE/SEND(10)   -- Write calibration/LUT/motor data (7 DTCs)
 *     0xC0 Vendor Status    -- Check abort/completion state (~80 bytes)
 *     0xC1 Vendor Trigger   -- Dispatch 23 subcommands (~730 bytes)
 *     0xE0 Vendor Data Out  -- Write to vendor register table (~480 bytes)
 *     0xE1 Vendor Data In   -- Read from vendor register table (~430 bytes)
 *
 *   Transport-layer commands (handled by NKDUSCAN.dll, not LS5000.md3):
 *     0x03 REQUEST SENSE    -- Return 18-byte sense data (~230 bytes)
 *     0xD0 Phase Query      -- USB phase polling (shared module, tiny)
 *
 *   Firmware-update commands (not used by NikonScan normal workflow):
 *     0x3B WRITE BUFFER     -- Write firmware data to flash
 *     0x3C READ BUFFER      -- Read firmware/diagnostic buffers
 *
 * Key architectural patterns:
 *   - All handlers begin with push_context (0x016458) and end with
 *     pop_context (0x016436) + rts
 *   - CDB validation always checks reserved bits/bytes, returning
 *     sense 0x0050 (Invalid Field in CDB) on any non-zero reserved field
 *   - Error is signaled by writing an internal sense index to SENSE_RESULT
 *     (0x4007B0); the REQUEST SENSE handler translates this to standard
 *     SCSI sense data using the 148-entry table at FW:0x16DEE
 *   - Data-in handlers call usb_state_setup (0x1374A) then
 *     usb_data_transfer (0x014090)
 *   - Data-out handlers call usb_state_setup then usb_data_receive (0x13E20)
 *   - The vendor E0/C1/E1 trio forms a write-trigger-read cycle for
 *     all scanner hardware control (focus, exposure, calibration, motors)
 *
 * ==================================================================== */
