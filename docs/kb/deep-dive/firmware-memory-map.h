/**
 * firmware-memory-map.h -- Nikon LS-50 (Coolscan V) Firmware Memory Map
 *
 * Complete address definitions for the H8/3003-based LS-50 scanner firmware.
 * All addresses are 24-bit (H8/300H address space). Big-endian byte order.
 *
 * Source: Reverse-engineered from LS-50 firmware binary (MBM29F400B, 512KB).
 * See firmware-memory-map.md for detailed descriptions and cross-references.
 *
 * Usage: #include this file in any LS-50 driver or analysis tool.
 */

#ifndef NIKON_LS50_MEMORY_MAP_H
#define NIKON_LS50_MEMORY_MAP_H

/* ========================================================================
 * 1. FLASH ROM (0x000000-0x07FFFF, 512KB)
 * ======================================================================== */

#define FLASH_BASE              0x000000
#define FLASH_SIZE              0x080000  /* 512KB */

/* Vector table: 64 x 4-byte vectors */
#define FLASH_VECTOR_TABLE      0x000000
#define FLASH_VECTOR_TABLE_END  0x0000FF

/* Boot code */
#define FLASH_BOOT_CODE         0x000100
#define FLASH_BOOT_CODE_END     0x00018A
#define FLASH_NMI_HANDLER       0x000182
#define FLASH_DEFAULT_ISR       0x000186

/* Settings areas (mostly erased) */
#define FLASH_SETTINGS_A        0x004000
#define FLASH_SETTINGS_A_END    0x005FFF
#define FLASH_SETTINGS_B        0x006000
#define FLASH_SETTINGS_B_END    0x007FFF

/* Shared module (ISP1581 USB, response manager, context switch) */
#define FLASH_SHARED_MODULE     0x010000
#define FLASH_SHARED_MODULE_END 0x017FFF

/* Main firmware code */
#define FLASH_MAIN_FW           0x020000
#define FLASH_MAIN_FW_END       0x044FFF

/* Data tables region */
#define FLASH_DATA_TABLES       0x045000
#define FLASH_DATA_TABLES_END   0x0528BE

/* Log areas (usage telemetry) */
#define FLASH_LOG_AREA_1        0x060000
#define FLASH_LOG_AREA_1_END    0x063FFF
#define FLASH_LOG_AREA_2        0x070000
#define FLASH_LOG_AREA_2_END    0x07FFFF

/* Key data table addresses */
#define FW_IO_INIT_TABLE        0x02001C  /* 132 entries x 6 bytes */
#define FW_SCSI_DISPATCH_TABLE  0x049834  /* 21 entries x 10 bytes */
#define FW_TASK_TABLE           0x049910  /* 97 entries x 4 bytes */
#define FW_READ_DTC_TABLE       0x049AD8  /* 15 entries x 12 bytes */
#define FW_WRITE_DTC_TABLE      0x049B98  /* 7 entries x 10 bytes */
#define FW_VENDOR_REG_TABLE     0x049C0C  /* 23 entries x 3 bytes */
#define FW_SENSE_XLAT_TABLE     0x049C4E  /* Sense code translation */
#define FW_STRING_PTR_TABLE     0x049F48  /* String pointer table */
#define FW_ADAPTER_TABLE        0x049E50  /* 8 adapter entries */
#define FW_ASIC_RAM_BANK_TABLE  0x04A114  /* 16 bank addresses */
#define FW_CCD_CHAR_PTR_TABLE   0x04A37E  /* CCD characterization pointers */
#define FW_ASIC_REG_ADDR_TABLE  0x04A3A4  /* ASIC register address table */
#define FW_CCD_CHAR_SECTION_1   0x04A8BC  /* CCD cal data section 1 (16385B) */
#define FW_CCD_CHAR_SECTION_2   0x04E8BD  /* CCD cal data section 2 (16385B) */
#define FW_CCD_CHAR_END_MARKER  0x0528BE  /* 0xFF end marker */
#define FW_SPEED_RAMP_TABLE     0x04A624  /* Speed ramp profiles */
#define FW_SCAN_MODE_DISPATCH   0x04A624  /* Scan mode dispatch table */

/* USB descriptor locations in flash */
#define FW_USB11_DEV_DESC       0x0170FA  /* USB 1.1 device descriptor */
#define FW_USB20_DEV_DESC       0x01710C  /* USB 2.0 device descriptor */
#define FW_USB_CONFIG_DESC      0x01711E  /* Configuration descriptor */
#define FW_USB_IFACE_DESC       0x017127  /* Interface descriptor */
#define FW_USB_EP1_DESC         0x017130  /* EP1 OUT Bulk descriptor */
#define FW_USB_EP2_DESC         0x017137  /* EP2 IN Bulk descriptor */
#define FW_USB_INQUIRY_STRING   0x0170D6  /* INQUIRY string with serial */

/* Key firmware function addresses */
#define FW_MAIN_ENTRY           0x020600  /* Main firmware entry */
#define FW_SCSI_DISPATCH        0x020B48  /* SCSI opcode dispatch */
#define FW_TASK_EXECUTOR        0x020DD6  /* Task code executor */
#define FW_CONTEXT_SWITCHER     0x010876  /* TRAPA #0 context switch */
#define FW_RESPONSE_MANAGER     0x01374A  /* USB response manager */
#define FW_FLASH_PROGRAM        0x03A300  /* Flash programming routine */
#define FW_MODEL_CONFIG         0x0142AA  /* LS-50 vs LS-5000 config */
#define FW_USB_RAM_CODE_SRC     0x0124BA  /* Source for RAM-resident USB code */

/* ========================================================================
 * 2. EXTERNAL RAM (0x400000-0x41FFFF, 128KB)
 * ======================================================================== */

#define RAM_BASE                0x400000
#define RAM_SIZE                0x020000  /* 128KB */

/* --- 2.1 System Core (0x400000-0x4000FF) --- */
#define RAM_CMD_PENDING         0x400082  /* USB command pending (1=waiting) */
#define RAM_USB_BUS_RESET       0x400084  /* USB bus reset detected */
#define RAM_USB_REINIT          0x400085  /* USB re-init needed */
#define RAM_ERROR_FLAG          0x400086  /* General error flag */
#define RAM_USB_STATE_CTR       0x400088  /* USB state tracking counter (16-bit) */

/* --- 2.2 Task System (0x400490-0x4004BF) --- */
#define RAM_TASK_COMPLETE       0x400492  /* Task completion flag */
#define RAM_TASK_ACTIVE         0x400493  /* Task in-progress flag */
#define RAM_USB_TXN_ACTIVE      0x40049A  /* USB transaction active */
#define RAM_EXEC_MODE           0x40049B  /* Current SCSI exec mode */
#define RAM_XFER_PHASE          0x40049C  /* USB transfer phase */
#define RAM_CMD_COMPLETE_CTR    0x40049D  /* Command completion counter */
#define RAM_TASK_RESULT         0x40049E  /* Task result/status (32-bit) */
#define RAM_WRITE_BUF_AREA      0x4004B0  /* WRITE BUFFER staging area */

/* --- 2.3 Reservation (0x4006B3) --- */
#define RAM_RESERVE_STATE       0x4006B3  /* RESERVE/RELEASE state byte */

/* --- 2.4 Context Switch / Coroutine (0x400760-0x400775) --- */
#define RAM_CTX_SWITCH_STATE    0x400764  /* Context switch state (16-bit) */
#define RAM_CTX_A_SP_SAVE       0x400766  /* Context A saved SP (32-bit) */
#define RAM_CTX_B_SP_SAVE       0x40076A  /* Context B saved SP (32-bit) */
#define RAM_SYS_TIMESTAMP       0x40076E  /* Global timestamp (32-bit, ITU4 ticks) */
#define RAM_TIMER_CAPTURE       0x400770  /* Timer capture value (16-bit) */
#define RAM_BOOT_FLAG           0x400772  /* Boot mode (0=cold, 1=warm) */
#define RAM_CMD_STATE           0x400773  /* Command/pipeline state (4=scan, 5=cal) */
#define RAM_MOTOR_MODE          0x400774  /* ITU2 dispatch selector (2/3/4/6) */

/* --- 2.5 Scanner State Machine (0x400776-0x4007AF) --- */
#define RAM_STATE_FLAGS         0x400776  /* State flags (bit6=abort, bit7=response) (16-bit) */
#define RAM_TASK_CODE           0x400778  /* Current task code (16-bit) */
#define RAM_SCAN_PROGRESS       0x40077A  /* Scan progress / DMA state (16-bit) */
#define RAM_SCANNER_STATE       0x40077C  /* Scanner state machine (16-bit) */
#define RAM_RED_EXPOSURE        0x40077E  /* Red channel exposure (32-bit) */
#define RAM_GRN_EXPOSURE        0x400782  /* Green channel exposure (32-bit) */
#define RAM_TASK_REMAINING      0x40078C  /* Remaining work counter (32-bit) */
#define RAM_GAIN_ADJUST         0x400790  /* Gain adjustment factor */
#define RAM_GPIO_SHADOW         0x400791  /* GPIO shadow register (23 refs) */

/* --- 2.6 SCSI State (0x4007B0-0x4007FF) --- */
#define RAM_SENSE_CODE          0x4007B0  /* Internal sense code (16-bit) */
#define RAM_XFER_COUNT          0x4007B2  /* Transfer byte count (16-bit) */
#define RAM_SCSI_PARAM_A        0x4007B4  /* SCSI parameter A (16-bit) */
#define RAM_SCSI_OPCODE         0x4007B6  /* Current SCSI opcode (CDB byte 0) */
#define RAM_CDB_BYTE1           0x4007B7  /* CDB byte 1 */
#define RAM_CDB_PARAMS          0x4007B8  /* CDB parameter area */
#define RAM_SCAN_EXEC_MODE      0x4007BA  /* SCAN exec mode byte */
#define RAM_CMD_CATEGORY        0x4007BF  /* Command category byte */
#define RAM_USB_TIMEOUT         0x4007D6  /* USB timeout timer (16-bit) */
#define RAM_CDB_BUFFER          0x4007DE  /* CDB receive buffer (16 bytes) */
#define RAM_CDB_BUFFER_SIZE     16

/* --- 2.7 INQUIRY / Sense (0x400877-0x4008FF) --- */
#define RAM_ADDL_SENSE          0x400877  /* Additional sense qualifier */
#define RAM_SENSE_INFO          0x400880  /* Sense information byte */
#define RAM_INQUIRY_BUF         0x4008A2  /* INQUIRY response buffer (~96 bytes) */

/* --- 2.8 Task Budget (0x400896) --- */
#define RAM_TASK_BUDGET         0x400896  /* Task time budget (32-bit) */
#define RAM_TASK_BUDGET_INIT    0x40089A  /* Initial budget for accounting (32-bit) */

/* --- 2.9 SET WINDOW / Scan Config (0x4009C2-0x400AFF) --- */
#define RAM_WINDOW_DESC         0x4009C2  /* SET WINDOW descriptor data */
#define RAM_WINDOW_PARAMS       0x4009EC  /* Window parameter table */
#define RAM_WINDOW_BUF_A        0x400AAA  /* Window buffer A */
#define RAM_WINDOW_BUF_B        0x400AE4  /* Window buffer B */
#define RAM_BUFFER_STAGING      0x400B24  /* Buffer staging area */
#define RAM_CAL_VALUE_A         0x400B8A  /* Calibration value A (16-bit) */
#define RAM_CAL_VALUE_B         0x400B8C  /* Calibration value B (16-bit) */

/* --- 2.10 Motor Speed / Ramp (0x400C0E-0x400CFF) --- */
#define RAM_MOTOR_SPEED_PARAM   0x400C0E  /* Current speed parameter (16-bit) */
#define RAM_MOTOR_RAMP_CONFIG   0x400CC8  /* Ramp table selector (16-bit) */

/* --- 2.11 MODE SENSE / MODE SELECT (0x400D26-0x400DAF) --- */
#define RAM_MODE_HEADER         0x400D26  /* Mode page header (32-bit) */
#define RAM_MODE_CURRENT        0x400D2A  /* Current mode page values (8 bytes) */
#define RAM_MODE_CHANGEABLE     0x400D32  /* Changeable mode page values (8 bytes) */
#define RAM_MAX_OPERATIONS      0x400D3C  /* Max ops for current adapter */
#define RAM_SCAN_CONFIG_EXT     0x400D3D  /* Extended scan config */
#define RAM_SCAN_OP_ACTIVE      0x400D43  /* Scan operation active flag */
#define RAM_SCAN_PARAMS_BUF     0x400D45  /* Scan parameters (READ DTC 0x87) */
#define RAM_C1_SUBCMD           0x400D63  /* C1 subcommand code */
#define RAM_SCAN_RESOLUTION     0x400D8E  /* Resolution / DMA config */
#define RAM_RESOLUTION_X        0x400D9A  /* Resolution X component (16-bit) */
#define RAM_RESOLUTION_Y        0x400D9E  /* Resolution Y component (16-bit) */
#define RAM_MODE_SELECT_BUF     0x400DAA  /* MODE SELECT data buffer */

/* --- 2.12 Scan State / Control (0x400E5F-0x400EFF) --- */
#define RAM_SOFT_RESET          0x400E5F  /* Soft-reset request flag */
#define RAM_MOTOR_BUSY_FLAG     0x400E79  /* Motor busy indicator */
#define RAM_SCAN_OP_STATE       0x400E7A  /* Scan operation state */
#define RAM_INIT_RESULT         0x400E80  /* Init result storage */
#define RAM_COLOR_MODE          0x400E92  /* Color mode (6=special IR) */
#define RAM_POSITIONING_FLAG    0x400ED6  /* Motor positioning in progress */

/* --- 2.13 Adapter / Film (0x400F00-0x400FFF) --- */
#define RAM_CAL_RESULT_R        0x400F0A  /* Calibration result: Red (16-bit) */
#define RAM_CAL_RESULT_G        0x400F12  /* Calibration result: Green (16-bit) */
#define RAM_CAL_RESULT_B        0x400F1A  /* Calibration result: Blue (16-bit) */
#define RAM_ADAPTER_TYPE        0x400F22  /* Adapter bitmask (0x04/0x08/0x20/0x40) */
#define RAM_CAL_PARAMS_START    0x400F56  /* Calibration parameter block start */
#define RAM_ADAPTER_DESC        0x400FAE  /* Adapter descriptor data */
#define RAM_CAL_PARAMS_END      0x400F9D  /* Calibration parameter block end */

/* --- 2.14 USB Code in RAM (0x4010A0) --- */
#define RAM_USB_CODE            0x4010A0  /* RAM-resident USB handler (414 bytes) */
#define RAM_USB_CODE_SIZE       414
#define RAM_USB_CODE_ALT        0x4011A2  /* Alternate entry point */

/* --- 2.15 Model Flag (0x404E48-0x404E96) --- */
#define RAM_MODEL_CONFIG_A      0x404E48  /* Model configuration A (32-bit) */
#define RAM_MODEL_CONFIG_B      0x404E4C  /* Model configuration B (32-bit) */
#define RAM_MODEL_PARAMS        0x404E50  /* Model parameter array */
#define RAM_MODEL_FLAG          0x404E96  /* LS-50=0, LS-5000=nonzero */

/* --- 2.16 Scan Pipeline State (0x405000-0x4065FF) --- */
#define RAM_PIXEL_DESC_A        0x405284  /* Pixel descriptor A */
#define RAM_PIXEL_DESC_B        0x405288  /* Pixel descriptor B */
#define RAM_EXPOSURE_PARAM_B    0x4052A6  /* Exposure parameter B */
#define RAM_DMA_MODE            0x4052D6  /* ITU3 ISR dispatch mode (1/2/3/4/6) */
#define RAM_MOTOR_STEP_COUNT    0x4052E2  /* Current step position (16-bit) */
#define RAM_MOTOR_TARGET_POS    0x4052E4  /* Target position (16-bit) */
#define RAM_MOTOR_CURRENT_SPEED 0x4052E6  /* Current timer period (16-bit) */
#define RAM_MOTOR_ACCEL_INDEX   0x4052E8  /* Accel ramp table index (16-bit) */
#define RAM_MOTOR_ENABLE        0x4052EA  /* Motor enabled flag */
#define RAM_MOTOR_RUNNING       0x4052EB  /* Motor running flag */
#define RAM_MOTOR_STATE         0x4052EC  /* Motor state machine */
#define RAM_MOTOR_DIRECTION     0x4052ED  /* Motor direction */
#define RAM_SCAN_STATUS         0x4052EE  /* Buffer status (3=full/ready) */
#define RAM_SCAN_STATUS_EXT     0x4052F0  /* Extended scan status */
#define RAM_SCAN_ACTIVE         0x4052F1  /* Scan active flag */
#define RAM_SCAN_PHASE          0x4052F2  /* Scan phase indicator */
#define RAM_ENCODER_ENABLE      0x405300  /* Encoder subsystem enable */
#define RAM_RECV_DIAG_STATE     0x405301  /* RECEIVE DIAGNOSTIC state */
#define RAM_SCAN_COMPLETE       0x405302  /* Scan complete flag */
#define RAM_ENCODER_MODE        0x405306  /* Encoder operating mode */
#define RAM_ENCODER_STATE       0x40530A  /* Encoder state (0xD1=special) */
#define RAM_ENCODER_COUNT       0x40530E  /* Encoder pulse count (16-bit) */
#define RAM_ENCODER_DELTA       0x405314  /* Inter-pulse delta (16-bit) */
#define RAM_ENCODER_TIMESTAMP   0x405318  /* Last encoder event time (32-bit) */
#define RAM_ENCODER_LAST_CAP    0x40531A  /* Previous timer capture (16-bit) */
#define RAM_CHAN_DESCRIPTORS     0x405342  /* Per-channel pixel descriptors */
#define RAM_LINE_COUNTER_ISR    0x4058FC  /* Line counter (ISR side, 16-bit) */

/* --- 2.17 DMA / Diagnostics (0x406200-0x406400) --- */
#define RAM_MOTOR_COORD_DATA    0x4062DA  /* Motor coordination state */
#define RAM_CHANNEL_DATA_A      0x4062DC  /* Channel data register A (16-bit) */
#define RAM_CHANNEL_DATA_B      0x4062DD  /* Channel data register B */
#define RAM_XFER_ACTIVE         0x4062E6  /* USB transfer in progress */
#define RAM_DIAG_VAL_0          0x4062FC  /* Diagnostic value 0 (16-bit) */
#define RAM_DIAG_VAL_1          0x4062FE  /* Diagnostic value 1 (16-bit) */
#define RAM_DIAG_VAL_2          0x406300  /* Diagnostic value 2 (16-bit) */
#define RAM_DIAG_VAL_3          0x406304  /* Diagnostic value 3 (16-bit) */
#define RAM_DIAG_VAL_4          0x406306  /* Diagnostic value 4 (16-bit) */
#define RAM_DIAG_VAL_5          0x406308  /* Diagnostic value 5 (16-bit) */
#define RAM_DIAG_VAL_6          0x40630C  /* Diagnostic value 6 (16-bit) */
#define RAM_DIAG_VAL_7          0x40630E  /* Diagnostic value 7 (16-bit) */
#define RAM_DIAG_VAL_8          0x406310  /* Diagnostic value 8 (16-bit) */
#define RAM_DIAG_VAL_9          0x406314  /* Diagnostic value 9 (16-bit) */
#define RAM_DIAG_VAL_10         0x406316  /* Diagnostic value 10 (16-bit) */
#define RAM_DIAG_VAL_11         0x406318  /* Diagnostic value 11 (16-bit) */
#define RAM_DIAG_VAL_12         0x40631C  /* Diagnostic value 12 (16-bit) */
#define RAM_DIAG_VAL_13         0x40631E  /* Diagnostic value 13 (16-bit) */
#define RAM_DIAG_VAL_14         0x406320  /* Diagnostic value 14 (16-bit) */
#define RAM_DIAG_VAL_15         0x406324  /* Diagnostic value 15 (16-bit) */
#define RAM_DIAG_VAL_16         0x406326  /* Diagnostic value 16 (16-bit) */
#define RAM_DIAG_VAL_17         0x406328  /* Diagnostic value 17 (16-bit) */
#define RAM_ADAPTER_STATE       0x40632F  /* Adapter state indicator */
#define RAM_DMA_STATE_VARS      0x406338  /* DMA state variables */
#define RAM_SCAN_DESC_PTR       0x406370  /* Scan descriptor pointer (32-bit) */
#define RAM_DMA_BURST_COUNTER   0x406374  /* DMA burst countdown (16-bit) */
#define RAM_LINES_REMAINING     0x4064E6  /* Remaining scan lines (16-bit) */
#define RAM_DMA_LINE_STATE      0x4064E8  /* DMA per-line state */
#define RAM_CHANNEL_STATE       0x406DB6  /* CCD channel state data */

/* --- 2.18 Channel Descriptor Tables (0x406E3A) --- */
#define RAM_CHAN_DESC_A          0x406E3A  /* Channel descriptor table A (40 bytes) */
#define RAM_CHAN_DESC_B          0x406E62  /* Channel descriptor table B (40 bytes) */

/* --- 2.19 Exposure Parameters (0x407400) --- */
#define RAM_EXPOSURE_PARAM_A    0x4074DE  /* Exposure parameter A */
#define RAM_EXPOSURE_PARAM_C    0x407626  /* Exposure parameter C */

/* --- 2.20 USB Session State Block (0x407D00-0x407DFF) --- */
#define RAM_USB_CONFIG_STATE    0x407D2E  /* USB configuration state */
#define RAM_USB_XFER_PROGRESS   0x407D30  /* USB transfer in progress */
#define RAM_USB_EP_STATE        0x407D32  /* USB endpoint state */
#define RAM_USB_CONNECTION      0x407DC3  /* USB connection state */
#define RAM_CMD_PHASE           0x407DC6  /* Current command phase */
#define RAM_USB_SESSION         0x407DC7  /* USB session (2=connected+configured) */
#define RAM_USB_RETRY_COUNTER   0x407DC8  /* USB retry counter */
#define RAM_USB_XFER_REQ        0x407DCC  /* USB transfer requirements */
#define RAM_USB_XFER_CONFIG     0x407DCE  /* USB transfer config */
#define RAM_SCAN_USB_STATE      0x407DD2  /* Scan USB state block */
#define RAM_EP_STALL_FLAGS      0x407DD8  /* Endpoint stall flags */
#define RAM_INT_MASK_PRIORITY   0x407DD9  /* Interrupt mask/priority */
#define RAM_USB_DMA_STATE       0x407DDB  /* USB DMA state */
#define RAM_USB_DMA_DIRECTION   0x407DDC  /* USB DMA direction */
#define RAM_USB_DMA_COMPLETE    0x407DDD  /* USB DMA completion flag */
#define RAM_USB_RESET_FLAG      0x407DDE  /* USB bus reset flag */
#define RAM_USB_CONNECTED       0x407DE0  /* USB connected flag */

/* --- 2.21 Stack Areas --- */
#define RAM_CTX_B_STACK_BASE    0x40D000  /* Context B stack (grows down) */
#define RAM_INITIAL_SP          0x40F800  /* Initial SP after relocation */
#define RAM_CTX_A_STACK_BASE    0x410000  /* Context A stack (grows down) */

/* ========================================================================
 * 3. CUSTOM ASIC REGISTERS (0x200000-0x200FFF)
 * ======================================================================== */

#define ASIC_BASE               0x200000

/* --- 3.1 Block 0x00: System Control (0x200000-0x2000C7) --- */
#define ASIC_MASTER_ENABLE      0x200001  /* Master enable/reset (init: 0x80) */
#define ASIC_STATUS             0x200002  /* Status register (bit 3=DMA busy) */
#define ASIC_STATUS_CTRL        0x200003  /* Status/control */
#define ASIC_INT_CONFIG         0x200008  /* Interrupt config */
#define ASIC_INT_MASK           0x20000F  /* Interrupt mask/status */
#define ASIC_DMA_CONTROL        0x200020  /* DMA control */
#define ASIC_DMA_STATUS         0x200028  /* DMA status */
#define ASIC_RAM_TEST_A         0x200041  /* RAM test register A */
#define ASIC_RAM_TEST_B         0x200042  /* RAM test register B */
#define ASIC_CTRL_A             0x200044  /* Control A (init: 0x00) */
#define ASIC_CTRL_B             0x200045  /* Control B (init: 0x00) */
#define ASIC_MASK_REG           0x200046  /* Mask register (init: 0xFF) */
#define ASIC_STATIC_53          0x200053  /* Static config (init-only) */
#define ASIC_STATIC_5A          0x20005A  /* Static config (init-only) */
#define ASIC_STATIC_69          0x200069  /* Static config (init-only) */
#define ASIC_STATIC_6B          0x20006B  /* Static config (init-only) */
#define ASIC_STATIC_6F          0x20006F  /* Static config (init-only) */
#define ASIC_STATIC_8C          0x20008C  /* Static config triplet (init-only) */
#define ASIC_STATIC_8D          0x20008D  /* Static config triplet (init-only) */
#define ASIC_STATIC_8E          0x20008E  /* Static config triplet (init-only) */
#define ASIC_STATIC_AD          0x2000AD  /* Static config pair (init-only) */
#define ASIC_STATIC_AE          0x2000AE  /* Static config pair (init-only) */
#define ASIC_DAC_MASTER         0x2000C0  /* DAC/ADC master config (init: 0x52) */
#define ASIC_DAC_CTRL           0x2000C1  /* DAC/ADC control (init: 0x04) */
#define ASIC_DAC_MODE           0x2000C2  /* DAC mode: 0x20=init, 0x22=scan, 0xA2=cal */
#define ASIC_ADC_CTRL           0x2000C4  /* ADC control */
#define ASIC_ADC_READBACK       0x2000C6  /* ADC readback (read-only) */
#define ASIC_DAC_FINE           0x2000C7  /* DAC fine: 0x08 (LS-50), 0x00 (LS-5000) */

/* DAC mode values */
#define ASIC_DAC_MODE_INIT      0x20
#define ASIC_DAC_MODE_SCAN      0x22
#define ASIC_DAC_MODE_CAL       0xA2

/* --- 3.2 Block 0x01: DMA/Motor/Timing (0x200100-0x2001CB) --- */
#define ASIC_DMA_CH0_SRC        0x200100  /* DMA ch0 source (init: 0x3F) */
#define ASIC_DMA_CH0_DST        0x200101  /* DMA ch0 dest (init: 0x3F) */
#define ASIC_MOTOR_DMA_CTRL     0x200102  /* Motor DMA control (init: 0x04) */
#define ASIC_DMA_CH_MODE        0x200103  /* DMA channel mode (init: 0x01) */
#define ASIC_DMA_CH1_SRC        0x200104  /* DMA ch1 source (init: 0x30) */
#define ASIC_DMA_CH1_DST        0x200105  /* DMA ch1 dest (init: 0x32) */
#define ASIC_DMA_CH2_SRC        0x200106  /* DMA ch2 source (init: 0x34) */
#define ASIC_DMA_CH2_DST        0x200107  /* DMA ch2 dest (init: 0x36) */
#define ASIC_DMA_CH3_SRC        0x20010C  /* DMA ch3 source (init: 0x20) */
#define ASIC_DMA_CH3_DST        0x20010D  /* DMA ch3 dest (init: 0x22) */
#define ASIC_DMA_CH4_SRC        0x20010E  /* DMA ch4 source (init: 0x24) */
#define ASIC_DMA_CH4_DST        0x20010F  /* DMA ch4 dest (init: 0x26) */
#define ASIC_DMA_CH5_SRC        0x200114  /* DMA ch5 source (init: 0x00) */
#define ASIC_DMA_CH5_DST        0x200115  /* DMA ch5 dest (init: 0x08) */
#define ASIC_DMA_CH6_SRC        0x200116  /* DMA ch6 source (init: 0x10) */
#define ASIC_DMA_CH6_DST        0x200117  /* DMA ch6 dest (init: 0x18) */
#define ASIC_DMA_ENABLE         0x200140  /* DMA enable (init: 0x01) */
#define ASIC_DMA_MODE           0x200141  /* DMA mode (init: 0x01) */
#define ASIC_DMA_XFER_CFG       0x200142  /* DMA transfer config / ch1 coarse gain */
#define ASIC_BUF_CONTROL        0x200143  /* Buffer control (init: 0x01) */
#define ASIC_BUF_MODE           0x200144  /* Buffer mode (init: 0x04) */
#define ASIC_BUF_ADDR_0         0x200147  /* Buffer address byte 0 */
#define ASIC_BUF_ADDR_1         0x200148  /* Buffer address byte 1 */
#define ASIC_BUF_ADDR_2         0x200149  /* Buffer address byte 2 */
#define ASIC_XFER_COUNT_0       0x20014B  /* Transfer count byte 0 */
#define ASIC_XFER_COUNT_1       0x20014C  /* Transfer count byte 1 */
#define ASIC_XFER_COUNT_2       0x20014D  /* Transfer count byte 2 */
#define ASIC_DMA_STATUS_2       0x20014E  /* DMA status / multi-ch config */
#define ASIC_DMA_CTRL_2         0x20014F  /* DMA control 2 (init: 0x04) */
#define ASIC_DMA_INT_ENABLE     0x200150  /* DMA interrupt enable (init: 0x03) */
#define ASIC_CH2_COARSE_GAIN    0x200152  /* Ch2 coarse gain (calibration) */
#define ASIC_CH2_FINE_GAIN      0x200153  /* Ch2 fine gain (calibration) */

/* Motor drive registers */
#define ASIC_MOTOR_CFG_A        0x200181  /* Motor drive config A (init: 0x0D) */
#define ASIC_MOTOR_CH_A0        0x200182  /* Motor drive channel A pair 0 */
#define ASIC_MOTOR_CH_A1        0x200184  /* Motor drive channel A pair 1 */
#define ASIC_MOTOR_CH_A2        0x200186  /* Motor drive channel A pair 2 */
#define ASIC_MOTOR_CH_A3        0x200188  /* Motor drive channel A pair 3 */
#define ASIC_MOTOR_CFG_B        0x200193  /* Motor drive config B (init: 0x0E) */
#define ASIC_MOTOR_CH_B0        0x200194  /* Motor drive channel B pair 0 */
#define ASIC_MOTOR_CH_B1        0x200196  /* Motor drive channel B pair 1 */
#define ASIC_MOTOR_CH_B2        0x200198  /* Motor drive channel B pair 2 */
#define ASIC_MOTOR_CH_B3        0x20019A  /* Motor drive channel B pair 3 */
#define ASIC_MOTOR_AUX_A        0x2001A4  /* Motor auxiliary config A */
#define ASIC_MOTOR_AUX_B        0x2001A5  /* Motor auxiliary config B */
#define ASIC_MOTOR_AUX_C        0x2001A6  /* Motor auxiliary config C */

/* Line timing / CCD integration */
#define ASIC_LINE_TIMING_MODE   0x2001C0  /* Line timing mode (init: 0x03) */
#define ASIC_LINE_TIMING_CTRL   0x2001C1  /* Line timing control */
#define ASIC_PIXEL_CLK_DIV      0x2001C2  /* Pixel clock divider (init: 0x0F) */
#define ASIC_LINE_PERIOD_LO     0x2001C3  /* Line period low (init: 0x98) */
#define ASIC_LINE_PERIOD_HI     0x2001C4  /* Line period high (init: 0x00) */
#define ASIC_INTEG_START        0x2001C5  /* Integration start (init: 0x19) */
#define ASIC_INTEG_CONFIG       0x2001C6  /* Integration config (init: 0x0F) */
#define ASIC_INTEG_END          0x2001C7  /* Integration end (init: 0x69) */
#define ASIC_READOUT_START      0x2001C8  /* Readout start (init: 0x00) */
#define ASIC_READOUT_CONFIG     0x2001C9  /* Readout config (init: 0x18) */
#define ASIC_CAL_CONFIG_1       0x2001CA  /* Calibration config 1 */
#define ASIC_CAL_CONFIG_2       0x2001CB  /* Calibration config 2 */

/* --- 3.3 Block 0x02: CCD Data Channels (0x200200-0x20026D) --- */
#define ASIC_CH_MASTER_CFG      0x200200  /* Channel master config (init: 0x00) */
#define ASIC_CH0_RED_CFG        0x200204  /* Ch0 (Red) config (init: 0x04) */
#define ASIC_CH0_RED_MODE       0x200205  /* Ch0 (Red) mode (init: 0x03) */
#define ASIC_CH0_RED_PAIR_B_0   0x200214  /* Ch0 pair B register 0 */
#define ASIC_CH0_RED_PAIR_B_1   0x200215  /* Ch0 pair B register 1 */
#define ASIC_CH1_GRN_CFG       0x20021C  /* Ch1 (Green) config */
#define ASIC_CH1_GRN_MODE      0x20021D  /* Ch1 (Green) mode */
#define ASIC_CH1_GRN_PAIR_B_0  0x200224  /* Ch1 pair B register 0 */
#define ASIC_CH1_GRN_PAIR_B_1  0x200225  /* Ch1 pair B register 1 */
#define ASIC_CH2_BLU_CFG       0x20022C  /* Ch2 (Blue) config */
#define ASIC_CH2_BLU_MODE      0x20022D  /* Ch2 (Blue) mode */
#define ASIC_CH2_BLU_EXT       0x200255  /* Ch2 extended */
#define ASIC_CH3_IR_CFG        0x20025D  /* Ch3 (IR) config */
#define ASIC_CH3_IR_EXT        0x200265  /* Ch3 extended */
#define ASIC_CH_MASTER_EXT     0x20026D  /* Channel master extended */

/* --- 3.4 Block 0x04: CCD Timing/Gain (0x200400-0x200487) --- */
#define ASIC_CCD_MASTER_MODE    0x200400  /* CCD master mode (init: 0x20) */
#define ASIC_CCD_PIXEL_CLK      0x200401  /* CCD pixel clock (init: 0x0A) */
#define ASIC_CCD_CONTROL        0x200402  /* CCD control (init: 0x00) */
#define ASIC_CCD_CONFIG_A       0x200404  /* CCD config A (init: 0x00) */
#define ASIC_CCD_DATA_MASK      0x200405  /* CCD data mask (init: 0xFF) */
#define ASIC_CCD_ENABLE         0x200406  /* CCD enable (init: 0x01) */

/* Integration timing groups (6 bytes each: start_lo, start_hi, end_lo, end_hi, mode, ctrl) */
#define ASIC_INTEG_GRP1_BASE    0x200408  /* Transfer gate timing */
#define ASIC_INTEG_GRP2_BASE    0x20040E  /* Integration window */
#define ASIC_INTEG_GRP3_BASE    0x200414  /* Second integration */
#define ASIC_INTEG_GRP4_BASE    0x20041A  /* Readout timing */
#define ASIC_INTEG_GRP5_BASE    0x200420  /* Reset/clamp timing */

/* Analog gain (init-only, no runtime writes) */
#define ASIC_GAIN_CH_SELECT     0x200456  /* Gain channel select (init: 0x00) */
#define ASIC_ANALOG_GAIN_CH1    0x200457  /* Analog gain ch1 (init: 0x63 = 99) */
#define ASIC_ANALOG_GAIN_CH2    0x200458  /* Analog gain ch2 (init: 0x63 = 99) */

/* Per-channel timing (3 bytes each: mode, lo, hi) */
#define ASIC_CH0_RED_TIMING     0x20046D  /* Red timing (init: 00/01/2B) */
#define ASIC_CH1_GRN_TIMING     0x200475  /* Green timing (init: 00/01/2B) */
#define ASIC_CH2_BLU_TIMING     0x20047D  /* Blue timing (init: 00/01/2B) */
#define ASIC_CH3_IR_TIMING      0x200485  /* IR timing (init: 00/01/2B) */

/* --- 3.5 Blocks 0x09-0x0F: Static Config (init-only, zero runtime refs) --- */
#define ASIC_STATIC_0910        0x200910
#define ASIC_STATIC_0A81        0x200A81
#define ASIC_STATIC_0A8C        0x200A8C
#define ASIC_STATIC_0AE0        0x200AE0
#define ASIC_STATIC_0AF2        0x200AF2
#define ASIC_STATIC_0C82        0x200C82
#define ASIC_STATIC_0F20        0x200F20
#define ASIC_STATIC_0F60        0x200F60
#define ASIC_STATIC_0FA0        0x200FA0
#define ASIC_STATIC_0FC0        0x200FC0

/* ========================================================================
 * 4. ISP1581 USB CONTROLLER (0x600000-0x6000FF)
 * ======================================================================== */

#define ISP1581_BASE            0x600000

/* ISP1581 registers (H8 addresses = ISP1581_BASE + offset) */
#define ISP1581_INT_STATUS      0x600008  /* Interrupt Status (R/W) */
#define ISP1581_MODE            0x60000C  /* Mode (bit 4=SOFTCT soft-connect) */
#define ISP1581_DMA_CONFIG      0x600018  /* DMA Configuration (W) */
#define ISP1581_EP_INDEX        0x60001C  /* Endpoint Index/Count (W) */
#define ISP1581_EP_DATA         0x600020  /* Endpoint Data Port (R/W, 16-bit) */
#define ISP1581_DMA_MODE        0x60002C  /* DMA Mode Config (W) */
#define ISP1581_DMA_COUNT       0x600084  /* DMA Transfer Count (W) */

/* ISP1581 mode register bits */
#define ISP1581_MODE_SOFTCT     (1 << 4)  /* Soft-connect enable */

/* ISP1581 DMA mode values */
#define ISP1581_DMA_MODE_BULK   0x05      /* Mode 5 = bulk transfer */

/* ========================================================================
 * 5. ASIC RAM (0x800000-0x83FFFF, 256KB physical, 224KB accessible)
 * ======================================================================== */

#define ASIC_RAM_BASE           0x800000
#define ASIC_RAM_TOTAL_SIZE     0x040000  /* 256KB physical */
#define ASIC_RAM_FW_SIZE        0x038000  /* 224KB firmware-accessible */

/* ASIC RAM banks (4 x 32KB + 12 x 8KB = 224KB) */
#define ASIC_RAM_BANK_1         0x800000  /* 32KB -- CCD line buffer */
#define ASIC_RAM_BANK_2         0x808000  /* 32KB -- CCD line buffer */
#define ASIC_RAM_BANK_3         0x810000  /* 32KB -- CCD line buffer */
#define ASIC_RAM_BANK_4         0x818000  /* 32KB -- Pixel processing */
#define ASIC_RAM_BANK_5         0x820000  /* 8KB */
#define ASIC_RAM_BANK_6         0x822000  /* 8KB */
#define ASIC_RAM_BANK_7         0x824000  /* 8KB */
#define ASIC_RAM_BANK_8         0x826000  /* 8KB */
#define ASIC_RAM_BANK_9         0x828000  /* 8KB */
#define ASIC_RAM_BANK_10        0x82A000  /* 8KB */
#define ASIC_RAM_BANK_11        0x82C000  /* 8KB */
#define ASIC_RAM_BANK_12        0x82E000  /* 8KB */
#define ASIC_RAM_BANK_13        0x830000  /* 8KB */
#define ASIC_RAM_BANK_14        0x832000  /* 8KB */
#define ASIC_RAM_BANK_15        0x834000  /* 8KB */
#define ASIC_RAM_BANK_16        0x836000  /* 8KB */
#define ASIC_RAM_BOUNDARY       0x838000  /* Boundary marker (not data storage) */

/* ========================================================================
 * 6. BUFFER RAM (0xC00000-0xC0FFFF, 64KB)
 * ======================================================================== */

#define BUFFER_RAM_BASE         0xC00000
#define BUFFER_RAM_SIZE         0x010000  /* 64KB */
#define BUFFER_RAM_BANK_A       0xC00000  /* 32KB -- Active scan/calibration data */
#define BUFFER_RAM_BANK_B       0xC08000  /* 32KB -- Ping-pong alternate */

/* ========================================================================
 * 7. H8/3003 ON-CHIP I/O REGISTERS (0xFFFF20-0xFFFFFF)
 * ======================================================================== */

/* --- 7.1 Integrated Timer Unit (ITU) --- */
#define H8_TSTR                 0xFFFF60  /* Timer start register */
#define H8_TCR0                 0xFFFF62  /* ITU0 timer control (init: 0x98) */
#define H8_TIOR0                0xFFFF64  /* ITU0 timer I/O control (init: 0xA0) */
#define H8_TCR2                 0xFFFF6E  /* ITU2 timer control (init: 0xC1, motor) */
#define H8_TCR3                 0xFFFF78  /* ITU3 timer control (init: 0xA3, DMA) */
#define H8_TCR4                 0xFFFF82  /* ITU4 timer control (init: 0xA3, tick) */
#define H8_TOCR                 0xFFFF92  /* Timer output control (init: 0xA0) */
#define H8_TSR4                 0xFFFF95  /* ITU4 timer status */

/* Timer start register bits */
#define H8_TSTR_ITU0            (1 << 0)
#define H8_TSTR_ITU1            (1 << 1)
#define H8_TSTR_ITU2            (1 << 2)
#define H8_TSTR_ITU3            (1 << 3)
#define H8_TSTR_ITU4            (1 << 4)

/* --- 7.2 GPIO Port Data Registers --- */
#define H8_P1DR                 0xFFFF80  /* Port 1 data */
#define H8_P3DDR                0xFFFF82  /* Port 3 data direction */
#define H8_P3DR                 0xFFFF84  /* Port 3 data (motor direction bit 0) */
#define H8_P4DDR                0xFFFF85  /* Port 4 DDR (lamp: BCLR=ON, BSET=OFF) */
#define H8_P4DR                 0xFFFF86  /* Port 4 data */
#define H8_P7DR                 0xFFFF8E  /* Port 7 data (adapter detect, input) */
#define H8_PADR                 0xFFFFA3  /* Port A data (motor stepper: 01/02/04/08) */
#define H8_P9DR                 0xFFFFC8  /* Port 9 data (encoder in + stepper out) */

/* Motor stepper phase values (written to PADR) */
#define MOTOR_PHASE_1           0x01
#define MOTOR_PHASE_2           0x02
#define MOTOR_PHASE_3           0x04
#define MOTOR_PHASE_4           0x08

/* --- 7.3 DMA Controller --- */
#define H8_DMAOR                0xFFFF90  /* DMA operation register (init: 0xC0) */
#define H8_DTCR0B               0xFFFF2F  /* DMA ch0 transfer control */

/* --- 7.4 Serial Communication Interface (SCI) --- */
#define H8_SCI0_BRR             0xFFFFC9  /* SCI0 baud rate (init: 0x80) */
#define H8_SCI0_SMR             0xFFFFCB  /* SCI0 serial mode (init: 0x80, async 8N1) */
#define H8_SCI1_BRR             0xFFFFCD  /* SCI1 baud rate (init: 0xF4) */
#define H8_SCI1_SMR             0xFFFFCF  /* SCI1 serial mode (init: 0xE0) */

/* --- 7.5 Bus State Controller (BSC) --- */
#define H8_ABWCR                0xFFFFF2  /* Bus width per area (init: 0x0B) */
#define H8_ASTCR                0xFFFFF3  /* Access state control (init: 0x00) */
#define H8_WCR                  0xFFFFF4  /* Wait state config (init: 0xBA) */
#define H8_WCER                 0xFFFFF5  /* Wait control enable (init: 0x00) */
#define H8_BRDR                 0xFFFFF6  /* Bus release data */
#define H8_BRCR                 0xFFFFF8  /* Bus release control (init: 0x00) */
#define H8_CSCR                 0xFFFFF9  /* Chip select control (init: 0x30) */

/* --- 7.6 Port Direction Registers (DDR) --- */
#define H8_P3DR_INIT            0xFFFFD0  /* Port 3 initial data (init: 0xC3) */
#define H8_P4DR_INIT            0xFFFFD1  /* Port 4 initial data (init: 0xFF) */
#define H8_P5DDR                0xFFFFD2  /* Port 5 direction (init: 0xC0) */
#define H8_P6DDR                0xFFFFD3  /* Port 6 direction (init: 0x3F) */
#define H8_P7DDR                0xFFFFD4  /* Port 7 direction (init: 0xFF) */
#define H8_P8DDR                0xFFFFD5  /* Port 8 direction (init: 0x01) */
#define H8_P9DDR                0xFFFFD6  /* Port 9 direction (init: 0x00) */
#define H8_PADDR                0xFFFFD7  /* Port A direction (init: 0x01) */
#define H8_P1DDR                0xFFFFEC  /* Port 1 direction (init: 0x85) */
#define H8_P2DDR                0xFFFFED  /* Port 2 direction (init: 0xFF) */
#define H8_P3DDR_ALT            0xFFFFEE  /* Port 3 direction (init: 0xF1) */
#define H8_P4DDR_ALT            0xFFFFEF  /* Port 4 direction (init: 0x48) */

/* --- 7.7 Watchdog Timer --- */
#define H8_WDT_TCSR             0xFFFFA8  /* Watchdog (write 0x5A00 to reset) */
#define H8_WDT_RESET_VALUE      0x5A00

/* --- 7.8 A/D Converter --- */
#define H8_ADCSR                0xFFFFE8  /* ADC control/status (bit 7=ADF) */
#define H8_ADCSR_ADF            (1 << 7)  /* A/D conversion complete flag */

/* ========================================================================
 * 8. ON-CHIP RAM (0xFFFD00-0xFFFD5F)
 * ======================================================================== */

#define ONCHIP_RAM_BASE         0xFFFD00

/* Interrupt trampolines (each is a 4-byte JMP instruction) */
#define TRAMP_TRAP0             0xFFFD10  /* TRAP #0 -> context switch (0x010876) */
#define TRAMP_IRQ3              0xFFFD14  /* IRQ3 -> encoder ISR (0x033444) */
#define TRAMP_IRQ4_5            0xFFFD18  /* IRQ4/5 -> ISP1581 ISR (0x014D4A) */
#define TRAMP_ITU2_CMPA         0xFFFD1C  /* ITU2 CmpA -> motor ISR (0x010B76) */
#define TRAMP_ITU3_CMPA         0xFFFD20  /* ITU3 CmpA -> DMA ISR (0x02D536) */
#define TRAMP_ITU4_CMPA         0xFFFD24  /* ITU4 CmpA -> tick ISR (0x010A16) */
#define TRAMP_DEND0B            0xFFFD28  /* DEND0B -> DMA end ISR (0x02CEF2) */
#define TRAMP_DEND1B            0xFFFD2C  /* DEND1B -> DMA end ISR (0x02E10A) */
#define TRAMP_VEC49             0xFFFD30  /* Vec49 -> scan ISR (0x02E9F8) */
#define TRAMP_ADI               0xFFFD34  /* ADI -> ADC ISR (0x02EDDE) */
#define TRAMP_IRQ7              0xFFFD38  /* IRQ7 -> cal ISR (0x02B544) */
#define TRAMP_IRQ1              0xFFFD3C  /* IRQ1 -> USB ISR (0x014E00) */

/* Boot state in on-chip RAM */
#define ONCHIP_BOOT_STATE       0xFFFD4C  /* 0=normal, 1=warm restart */
#define ONCHIP_SAVED_STATE_A    0xFFFD4D  /* Saved from 0x4006B2 */
#define ONCHIP_SAVED_STATE_B    0xFFFD4E  /* Saved from 0x4006B3 */
#define ONCHIP_SAVED_BLOCK      0xFFFD50  /* Saved from 0x4006B4 (8 bytes) */

/* ========================================================================
 * 9. ADAPTER TYPE BITMASK VALUES
 * ======================================================================== */

#define ADAPTER_SA21            0x04  /* SA-21 Strip Film Adapter */
#define ADAPTER_MA21            0x08  /* MA-21 Slide Mount Adapter */
#define ADAPTER_IA20            0x20  /* IA-20(1) APS IX240 Adapter */
#define ADAPTER_FH3             0x40  /* FH-3 / FH-G1 / FH-A1 Holder */

/* ========================================================================
 * 10. SCSI TASK CODE RANGES
 * ======================================================================== */

#define TASK_TUR_CLASS          0x0000  /* TEST UNIT READY related */
#define TASK_INQUIRY_CLASS      0x0100  /* INQUIRY / identification */
#define TASK_SCAN_CLASS         0x0200  /* SCAN operations */
#define TASK_POSITION_CLASS     0x0300  /* OBJECT POSITION / motor */
#define TASK_FEED_CLASS         0x0400  /* FEED (film advance) */
#define TASK_CAL_CLASS          0x0500  /* Calibration */
#define TASK_MOTOR_CLASS        0x0600  /* Direct motor control */
#define TASK_LAMP_CLASS         0x0700  /* Lamp on/off */
#define TASK_FOCUS_CLASS        0x0800  /* Autofocus */
#define TASK_EJECT_CLASS        0x0E00  /* Eject operations */
#define TASK_DIAG_CLASS         0x1000  /* Diagnostic / self-test */

/* ========================================================================
 * 11. SCSI READ/WRITE DATA TYPE CODES (DTC)
 * ======================================================================== */

/* READ (0x28) Data Type Codes */
#define DTC_READ_IMAGE          0x00  /* Image data */
#define DTC_READ_GAMMA_LUT      0x03  /* Gamma/LUT table */
#define DTC_READ_STATUS         0x80  /* Scanner status */
#define DTC_READ_BUTTON         0x81  /* Button status */
#define DTC_READ_FILM_TYPE      0x82  /* Film type info */
#define DTC_READ_FOCUS          0x83  /* Focus data */
#define DTC_READ_CAL            0x84  /* Calibration data */
#define DTC_READ_SCAN_PARAMS    0x87  /* Scan parameters */
#define DTC_READ_BOUNDARY       0x88  /* Boundary data */
#define DTC_READ_DETECT_INFO    0x8A  /* Detection info */
#define DTC_READ_AE_DATA        0x8B  /* Auto-exposure data */
#define DTC_READ_AF_STATUS      0x8C  /* Autofocus status */
#define DTC_READ_EXT_CONFIG     0xE0  /* Extended configuration */
#define DTC_READ_UNKNOWN_E1     0xE1  /* Unknown E1 */
#define DTC_READ_LOG            0xE2  /* Internal log data */

/* WRITE (0x2A) Data Type Codes */
#define DTC_WRITE_GAMMA_LUT     0x03  /* Gamma/LUT table */
#define DTC_WRITE_CAL           0x84  /* Calibration data */
#define DTC_WRITE_EXT_CAL       0x85  /* Extended calibration (WRITE-only) */
#define DTC_WRITE_BOUNDARY      0x88  /* Boundary data */
#define DTC_WRITE_EXT_CONFIG    0xE0  /* Extended configuration */
#define DTC_WRITE_UNKNOWN_E1    0xE1  /* Unknown E1 */
#define DTC_WRITE_LOG           0xE2  /* Internal log data */

/* ========================================================================
 * 12. USB DESCRIPTOR CONSTANTS
 * ======================================================================== */

#define USB_VID                 0x04B0  /* Nikon Corporation */
#define USB_PID_LS50            0x4001  /* LS-50 (Coolscan V) */
#define USB_PID_LS40            0x4000  /* LS-40 */
#define USB_PID_LS5000          0x4002  /* LS-5000 (Super Coolscan 5000) */
#define USB_BCD_DEVICE          0x0102  /* Device version 1.02 */
#define USB_CLASS_VENDOR        0xFF    /* Vendor-specific class */
#define USB_EP1_OUT_ADDR        0x01    /* EP1 OUT Bulk (CDB/data-out) */
#define USB_EP2_IN_ADDR         0x82    /* EP2 IN Bulk (phase/data-in/sense) */
#define USB_EP1_MAXPKT_FS       64      /* Full-speed max packet */
#define USB_EP2_MAXPKT_FS       64
#define USB_EP1_MAXPKT_HS       512     /* High-speed max packet */
#define USB_EP2_MAXPKT_HS       512

/* ========================================================================
 * 13. MOTOR MODE SELECTOR VALUES (RAM_MOTOR_MODE)
 * ======================================================================== */

#define MOTOR_MODE_SCAN         2       /* Normal scan stepping */
#define MOTOR_MODE_AF           3       /* Autofocus movement */
#define MOTOR_MODE_ENCODER      4       /* Encoder-based positioning */
#define MOTOR_MODE_ALT          6       /* Alternate stepping mode */

/* ========================================================================
 * 14. SENSE CODE CONSTANTS
 * ======================================================================== */

/* Sense keys */
#define SENSE_NO_SENSE          0x00
#define SENSE_NOT_READY         0x02
#define SENSE_ILLEGAL_REQUEST   0x05
#define SENSE_UNIT_ATTENTION    0x06
#define SENSE_ABORTED_COMMAND   0x0B

/* Common ASC/ASCQ pairs (LS-50 specific) */
#define ASC_NO_ADDITIONAL       0x0000
#define ASC_NOT_READY           0x0401  /* Becoming ready */
#define ASC_INVALID_CDB         0x2400  /* Invalid field in CDB */
#define ASC_INVALID_PARAM       0x2600  /* Invalid field in parameter list */
#define ASC_POWER_ON            0x2900  /* Power-on / bus reset */
#define ASC_COMMAND_SEQUENCE    0x2C00  /* Command sequence error */

#endif /* NIKON_LS50_MEMORY_MAP_H */
