/*
 * ============================================================================
 * NIKON LS-50 / COOLSCAN V — FIRMWARE SCAN ENGINE
 * ============================================================================
 *
 * Deep-dive C pseudocode reconstruction of the scanner's hot path: the code
 * that actually captures CCD image data, line by line, during a scan.
 *
 * Status:   Complete
 * Phase:    4 (Firmware)
 * Updated:  2026-03-12
 * Confidence: High (decoded from raw H8/300H binary analysis, cross-referenced
 *            with ASIC register map, ISP1581 datasheet, and host-side KB)
 *
 * Source binary: binaries/firmware/Nikon LS-50 MBM29F400B TSOP48.bin (512KB)
 * CPU: Hitachi H8/3003 (H8/300H core), 24-bit address, big-endian
 * Clock: 20 MHz main oscillator (typical for H8/3003 applications)
 *
 * References:
 *   docs/kb/components/firmware/scan-pipeline.md
 *   docs/kb/components/firmware/scan-state-machine.md
 *   docs/kb/components/firmware/calibration.md
 *   docs/kb/components/firmware/motor-control.md
 *   docs/kb/components/firmware/asic-registers.md
 *   docs/kb/components/firmware/isp1581-usb.md
 *   docs/kb/components/firmware/main-loop.md
 *   docs/kb/components/firmware/data-tables.md
 *
 * ============================================================================
 *
 * TABLE OF CONTENTS
 *
 *   1. Hardware Architecture Overview
 *   2. Memory Map & Register Summary
 *   3. State Variables (RAM)
 *   4. CCD Sensor & Analog Front-End
 *   5. ASIC DMA Engine
 *   6. Interrupt Service Routines
 *   7. Scan Entry & Initialization (F12, F2)
 *   8. Inner Scan Loop (Pre-function State Machine @ 0x40000)
 *   9. Scan Step Core (F1 @ 0x40318)
 *  10. Pixel Processing (@ 0x36C90)
 *  11. DMA Burst Coordination (ITU3 ISR @ 0x2D536)
 *  12. USB Transfer Pipeline
 *  13. Multi-Pass Scanning (F8 @ 0x42E2A)
 *  14. Color Channel Handling
 *  15. Resolution Scaling
 *  16. Shading Correction & Calibration
 *  17. Error Detection & Recovery
 *  18. Timing Diagrams
 *  19. Buffer Layout & Geometry
 *  20. Complete Scan Sequence Walkthrough
 *
 * ============================================================================
 */


/* ============================================================================
 * 1. HARDWARE ARCHITECTURE OVERVIEW
 * ============================================================================
 *
 * The LS-50 scanner hardware consists of:
 *
 *   H8/3003 CPU (24-bit, big-endian, ~20 MHz)
 *       |
 *       +-- Flash ROM (512KB @ 0x000000)      Firmware code + data tables
 *       +-- External RAM (128KB @ 0x400000)    CPU working memory, state vars
 *       +-- Custom ASIC (@ 0x200000)           CCD timing, ADC, motor, DMA
 *       |       |
 *       |       +-- ASIC RAM (224KB @ 0x800000)   CCD line buffer
 *       |       +-- CCD sensor (tri-linear RGB + IR)
 *       |       +-- Stepper motor driver
 *       |       +-- Analog front-end (DAC/ADC)
 *       |
 *       +-- Buffer RAM (64KB @ 0xC00000)       USB staging area
 *       +-- ISP1581 USB 2.0 (@ 0x600000)      Host communication
 *
 * Data flow during scan:
 *
 *   CCD --> ASIC AFE --> ASIC DMA --> ASIC RAM (0x800000)
 *       --> CPU pixel extract --> Buffer RAM (0xC00000)
 *       --> ISP1581 DMA --> USB bulk-in --> Host PC
 *
 * KEY DESIGN INSIGHT: The firmware performs MINIMAL pixel processing.
 * Only bit extraction (14-bit CCD data from 16-bit words) is done in
 * firmware. ALL image processing -- dark subtraction, white normalization,
 * gamma, color balance, Digital ICE -- is performed HOST-SIDE by NikonScan.
 */


/* ============================================================================
 * 2. MEMORY MAP & REGISTER SUMMARY
 * ============================================================================ */

/* --- H8/3003 CPU Registers (I/O space: 0xFFFFxx) --- */
#define TSTR        0xFFFF60  /* Timer Start Register (bits 0-4 = ITU0-4) */
#define TCNT2       0xFFFF72  /* ITU2 counter */
#define GRB2        0xFFFF78  /* ITU2 compare B */
#define TIER2       0xFFFF70  /* ITU2 interrupt enable */
#define TSR4        0xFFFF95  /* ITU4 status (system tick) */
#define PORT_A_DR   0xFFFFA3  /* Port A data: stepper motor phase output */
#define PORT_7_DR   0xFFFF8E  /* Port 7 data: adapter/sensor status input */
#define PORT_9_DR   0xFFFFC8  /* Port 9 data: encoder input + phase output */

/* --- Custom ASIC Registers (base: 0x200000) --- */
/* Block 0x00: System/DAC */
#define ASIC_MASTER_CTRL   0x200001  /* Master enable/reset */
#define ASIC_STATUS        0x200002  /* Status (bit 3 = DMA busy) */
#define ASIC_DAC_CONFIG    0x2000C0  /* CCD analog front-end master config */
#define ASIC_DAC_CTRL      0x2000C1  /* DAC/ADC control */
#define ASIC_DAC_MODE      0x2000C2  /* DAC mode: 0x22=scan, 0xA2=cal */
#define ASIC_DAC_FINE      0x2000C7  /* Fine DAC: 0x08(LS-50), 0x00(LS-5000) */

/* Block 0x01: DMA/Motor/Timing */
#define ASIC_MOTOR_DMA     0x200102  /* Motor DMA control */
#define ASIC_DMA_ENABLE    0x200140  /* DMA enable */
#define ASIC_DMA_MODE      0x200141  /* DMA mode */
#define ASIC_DMA_CONFIG    0x200142  /* DMA transfer config */
#define ASIC_DMA_ADDR_HI   0x200147  /* Buffer address[23:16] */
#define ASIC_DMA_ADDR_MID  0x200148  /* Buffer address[15:8] */
#define ASIC_DMA_ADDR_LO   0x200149  /* Buffer address[7:0] */
#define ASIC_DMA_CNT_HI    0x20014B  /* Transfer count[23:16] */
#define ASIC_DMA_CNT_MID   0x20014C  /* Transfer count[15:8] (init: 0x40) */
#define ASIC_DMA_CNT_LO    0x20014D  /* Transfer count[7:0] */
#define ASIC_MOTOR_CFG_A   0x200181  /* Motor drive config A */
#define ASIC_LINE_TIMING_MODE 0x2001C0  /* CCD line timing mode */
#define ASIC_LINE_TIMING_CTRL 0x2001C1  /* Line timing trigger */
#define ASIC_PIXEL_CLK_DIV 0x2001C2  /* Pixel clock divider */
#define ASIC_LINE_PERIOD_LO 0x2001C3  /* Line period (low byte) */
#define ASIC_LINE_PERIOD_HI 0x2001C4  /* Line period (high byte) */
#define ASIC_INTEG_START   0x2001C5  /* Integration start offset */
#define ASIC_INTEG_CONFIG  0x2001C6  /* Integration configuration */
#define ASIC_INTEG_END     0x2001C7  /* Integration end offset */

/* Block 0x04: CCD channel control */
#define ASIC_CCD_MASTER    0x200400  /* CCD master mode */
#define ASIC_GAIN_MODE     0x200456  /* Gain channel select */
#define ASIC_GAIN_CH1      0x200457  /* Analog gain (99 default) */
#define ASIC_GAIN_CH2      0x200458  /* Analog gain (99 default) */
/* Per-channel timing windows (stride-8, channels 0-3 = R/G/B/IR): */
#define ASIC_CH_BASE(n)    (0x20046D + (n) * 8)  /* Per-channel base */

/* --- Memory Regions --- */
#define ASIC_RAM_BASE      0x800000  /* 224KB CCD line buffer */
#define ASIC_RAM_BANK_B    0x818000  /* Secondary bank (32KB offset) */
#define BUFFER_RAM_BASE    0xC00000  /* 64KB USB staging, bank A */
#define BUFFER_RAM_BANK_B  0xC08000  /* USB staging, bank B (32KB offset) */
#define CPU_RAM_BASE       0x400000  /* 128KB CPU external RAM */

/* --- ISP1581 USB Controller Registers (base: 0x600000) --- */
#define ISP_INT_STATUS     0x600008  /* Interrupt status */
#define ISP_MODE           0x60000C  /* Mode register (bit 4 = SOFTCT) */
#define ISP_DMA_REG        0x600018  /* DMA control/direction */
#define ISP_DMA_CNT        0x60001C  /* DMA transfer count / endpoint index */
#define ISP_DATA_PORT      0x600020  /* Bulk data read/write */
#define ISP_DMA_CONFIG     0x60002C  /* DMA mode configuration */
#define ISP_CHIP_ID        0x600084  /* Chip identification */


/* ============================================================================
 * 3. STATE VARIABLES (RAM @ 0x400000+)
 * ============================================================================
 *
 * These RAM variables coordinate the scan pipeline across the main loop,
 * interrupt handlers, and the coroutine contexts. Listed in functional groups.
 */

/* --- Core scan state --- */
volatile uint8_t  cmd_state;        /* @ 0x400773: 1=scan, 4=scan-data-ready, 5=cal */
volatile uint8_t  motor_mode;       /* @ 0x400774: ITU2 dispatch (2/3/4/6) */
volatile uint16_t state_flags;      /* @ 0x400776: bit 7 = scan active flag */
volatile uint16_t task_code;        /* @ 0x400778: current 16-bit task code */
volatile uint16_t scan_progress;    /* @ 0x40077A: progress/DMA state */
volatile uint16_t scanner_state;    /* @ 0x40077C: state machine variable */
volatile uint32_t saved_desc;       /* @ 0x40078C: saved scan descriptor */
volatile uint8_t  gpio_shadow;      /* @ 0x400791: motor direction shadow */

/* --- Scan control --- */
volatile uint8_t  scan_op_type;     /* @ 0x40530A: operation type (0x03/0x04/0x12-0x15) */
volatile uint8_t  scan_mode_flag;   /* @ 0x405308: scan mode selector */
volatile uint16_t scan_line_remain; /* @ 0x4064E6: remaining scan lines */
volatile uint8_t  scan_status;      /* @ 0x4052EE: 3=buffer full, ready for USB */
volatile uint8_t  scan_status_b;    /* @ 0x4052EF: secondary status byte */
volatile uint8_t  scan_active;      /* @ 0x4052F1: scan in progress flag */
volatile uint8_t  scan_complete;    /* @ 0x405302: all lines scanned */
volatile uint8_t  scan_result;      /* @ 0x4052F3: scan result status */

/* --- DMA control --- */
volatile uint8_t  dma_burst_counter;/* @ 0x406374: ITU3 ISR counts down per burst */
volatile uint8_t  dma_mode;         /* @ 0x4052D6: DMA mode (1/2/3/4/6) */
volatile uint32_t scan_desc_ptr;    /* @ 0x406370: scan descriptor pointer */
volatile uint8_t  dma_channel_flag; /* @ 0x406337: channel processing flag */
volatile uint16_t dma_scan_desc;    /* @ 0x4052D4: DMA scan descriptor word */

/* --- USB transfer --- */
volatile uint8_t  xfer_state;       /* @ 0x4062E6: USB transfer in progress */
volatile uint8_t  usb_busy;         /* @ 0x40049A: USB endpoint busy flag */
volatile uint32_t timestamp;        /* @ 0x40076E: ITU4 system tick (32-bit) */

/* --- Channel descriptors --- */
volatile uint16_t chan_desc_a[12];   /* @ 0x406E3A: channel table A (11 refs) */
volatile uint16_t chan_desc_b[12];   /* @ 0x406E62: channel table B (12 refs) */
volatile uint16_t chan_geom[8];      /* @ 0x405342: per-channel pixel geometry */
/* Values: 0x02F5 (757) and 0x0299 (665) = active pixels / margins */

/* --- Motor state --- */
volatile uint16_t motor_step_count; /* @ 0x4052E2: current step position */
volatile uint16_t motor_target_pos; /* @ 0x4052E4: target position */
volatile uint16_t motor_speed;      /* @ 0x4052E6: current timer period */
volatile uint8_t  motor_enable;     /* @ 0x4052EA: motor enabled */
volatile uint8_t  motor_running;    /* @ 0x4052EB: currently stepping */

/* --- Calibration --- */
volatile uint8_t  model_type;       /* @ 0x404E96: 0=LS-50, non-0=LS-5000 */
volatile uint8_t  adapter_type;     /* @ 0x400F22: adapter bitmask (0x04-0x40) */

/* --- Configuration area (host-written via SCSI SET WINDOW/E0) --- */
volatile uint8_t  scan_config[32];  /* @ 0x400F30-0x400F55: scan parameters */
volatile uint16_t dpi_setting;      /* @ 0x400F26: requested resolution (DPI) */


/* ============================================================================
 * 4. CCD SENSOR & ANALOG FRONT-END
 * ============================================================================
 *
 * The LS-50 uses a tri-linear CCD with 4 parallel output channels:
 *   - Red line   (channel 0)
 *   - Green line (channel 1)
 *   - Blue line  (channel 2)
 *   - IR line    (channel 3, for Digital ICE dust/scratch removal)
 *
 * CCD specifications (from firmware constants):
 *   - Active elements per line: 4095 (2^12 - 1, from characterization data)
 *   - Output bit depth: 14 bits (packed in 16-bit words)
 *   - Maximum optical resolution: 4000 DPI
 *   - Active pixel window: 757 start, 665 width (from channel descriptors)
 *
 * The CCD is physically a single chip with 4 linear arrays. The ASIC handles
 * the clocking (transfer gate, integration, readout, reset) for all 4 lines
 * simultaneously, producing interleaved data.
 *
 * Tri-linear geometry note: The 3 color lines are physically offset by a
 * small distance on the CCD die. During scanning, the motor must advance
 * the film past all 3 lines. The firmware does NOT compensate for this
 * offset; the host software de-skews the color channels.
 */

/* CCD channel remap table at FW:0x4A520 (48 bytes, 8 repetitions):
 * {04, 01, 02, 03, 05, 00} -- maps physical channels to logical colors.
 * This handles the ASIC's interleaved CCD readout order. */
static const uint8_t ccd_remap[6] = {0x04, 0x01, 0x02, 0x03, 0x05, 0x00};

/*
 * Analog front-end initialization (done once at scan start):
 *
 *   ASIC_DAC_CONFIG (0x2000C0) = 0x52   CCD analog master config
 *   ASIC_DAC_CTRL   (0x2000C1) = 0x04   ADC control
 *   ASIC_DAC_MODE   (0x2000C2) = 0x22   Normal scan mode
 *   ASIC_GAIN_CH1   (0x200457) = 0x63   Default gain = 99
 *   ASIC_GAIN_CH2   (0x200458) = 0x63   Default gain = 99
 *
 * For calibration scans:
 *   ASIC_DAC_MODE   (0x2000C2) = 0xA2   Calibration mode (bit 7 set)
 */


/* ============================================================================
 * 5. ASIC DMA ENGINE
 * ============================================================================
 *
 * The custom ASIC contains a multi-channel DMA engine that transfers digitized
 * CCD data from the analog front-end into ASIC RAM (0x800000). The CPU
 * programs the DMA through registers at 0x200140-0x20014D.
 *
 * DMA operates in burst mode: each burst transfers a fixed-size block
 * (typically 16KB = 0x4000 bytes). A full CCD line may require multiple
 * bursts. The ITU3 timer ISR counts bursts to detect line completion.
 */

/* DMA configuration -- FW:0x035C7E */
void asic_dma_configure(uint32_t dest_addr, uint16_t transfer_count)
{
    /* --- Source: FW:0x035C7E --- */
    /* Set 24-bit destination address in ASIC RAM */
    *(volatile uint8_t *)ASIC_DMA_ADDR_HI  = (dest_addr >> 16) & 0xFF;
    *(volatile uint8_t *)ASIC_DMA_ADDR_MID = (dest_addr >> 8)  & 0xFF;
    *(volatile uint8_t *)ASIC_DMA_ADDR_LO  = (dest_addr >> 0)  & 0xFF;

    /* Set 24-bit transfer count */
    *(volatile uint8_t *)ASIC_DMA_CNT_HI  = (transfer_count >> 16) & 0xFF;
    *(volatile uint8_t *)ASIC_DMA_CNT_MID = (transfer_count >> 8)  & 0xFF;
    *(volatile uint8_t *)ASIC_DMA_CNT_LO  = (transfer_count >> 0)  & 0xFF;
}

/* DMA trigger and wait -- central to the inner scan loop */
void asic_dma_trigger_and_wait(void)
{
    /* Trigger ASIC DMA: write 0x02 to master control */
    *(volatile uint8_t *)ASIC_MASTER_CTRL = 0x02;

    /* Poll ASIC status register bit 3 until DMA complete */
    while (*(volatile uint8_t *)ASIC_STATUS & 0x08) {
        /* DMA still busy -- yield to other coroutine context */
        yield();  /* JSR @0x0109E2 = TRAPA #0 */
    }
}


/* ============================================================================
 * 6. INTERRUPT SERVICE ROUTINES
 * ============================================================================
 *
 * Five ISRs are active during scanning:
 *
 *   Vec 13 (IRQ1)  -> ISP1581 USB interrupt    (CDB reception, USB events)
 *   Vec 15 (IRQ3)  -> Encoder ISR @ 0x033444   (motor shaft position feedback)
 *   Vec 32 (IMIA2) -> ITU2 ISR @ 0x010B76      (motor step timing)
 *   Vec 36 (IMIA3) -> ITU3 ISR @ 0x02D536      (DMA burst countdown)
 *   Vec 40 (IMIA4) -> ITU4 ISR @ 0x010A16      (system tick, USB poll)
 *   Vec 45 (DEND0B)-> DMA end @ 0x02CEF2       (H8 DMA ch0 complete)
 *   Vec 47 (DEND1B)-> DMA end @ 0x02E10A       (H8 DMA ch1 complete)
 *
 * The scan hot path is coordinated by ITU3 (burst counting) and ITU4
 * (USB transfer polling). The motor ISR (ITU2) runs concurrently to
 * advance the film one step per scan line.
 */


/* ============================================================================
 * 7. SCAN ENTRY & INITIALIZATION
 * ============================================================================
 *
 * A scan is initiated by the host sending SCSI SCAN (0x1B) or vendor
 * command C1 with subcode 0x40-0x47. This sets a task code at @0x400778
 * (e.g., 0x0830 for fine 8-bit scan, strip adapter). The main loop's
 * task dispatcher routes to the scan entry point.
 *
 * Entry flow:
 *   Host SCSI --> C1 handler (0x28B08)
 *     --> Sets task code 0x08xx in @0x40077E
 *     --> Main loop reads it
 *     --> Task dispatch (0x20DBA) looks up handler index in table @0x49910
 *     --> Adapter dispatch (0x3C400) selects entry point A/B/C/D
 *     --> Entry: F12(init) --> adapter config --> F2(orchestrator)
 */

/* F12: Common Scan Initialization -- FW:0x044E40 (1216 bytes) */
void scan_common_init(void)
{
    /* --- Source: FW:0x044E40 --- */
    /* push_context (save ER3-ER6) */

    /* Initialize scan parameter area */
    *(volatile uint8_t *)0x400F34 = 0x0E;   /* Scan config flags */
    *(volatile uint8_t *)0x400F4A = 0x01;   /* Channel count */
    *(volatile uint8_t *)0x400F4B = 0x00;   /* Multi-pass flag */

    /* Read adapter configuration from host-written params */
    uint8_t adapter_cfg = *(volatile uint8_t *)0x400F55;

    /* Determine scan mode from cmd_state:
     *   0x01 -> scan data mode
     *   0x02 -> calibration mode
     *   0x03 -> preview mode
     *   0x04 -> scan data ready
     *   0x05 -> calibration data ready
     *   0x06 -> extended mode
     *   0x07 -> batch mode
     *   0xFF -> abort
     */
    uint8_t cs = *(volatile uint8_t *)0x400773;
    switch (cs) {
    case 0x01:  /* Scan data mode */
        /* Configure for scan -- fall through to resolution setup */
        break;
    case 0x02:  /* Calibration */
        /* Route to calibration entry at 0x3C460 */
        break;
    case 0x03:  /* Preview */
    case 0x04:  /* Scan ready */
    case 0x05:  /* Cal data */
        /* Various initialization paths */
        break;
    }

    /* Compute pixel clock timing:
     *   clock_period = 1000000 / dpi_setting
     *   result stored for CCD integration time calculation */
    uint32_t period = timing_compute(1000000, 640);
    /* ... store to scan config area ... */

    /* Configure USB data transfer for scan data */
    usb_transfer_setup(0x12360);  /* JSR @0x012360 */

    /* Set adapter-specific scan parameters */
    scan_area_init();

    /* pop_context + RTS */
}

/* Adapter entry points -- FW:0x40630-0x4065C (4 entries, 12 bytes each) */
/* All follow the same pattern: */
void scan_entry_strip(void)     /* Entry A @ 0x40630, adapter=0x08 (Strip) */
{
    scan_common_init();           /* JSR @0x044E40 (F12) */
    adapter_config_strip();       /* JSR @0x04536E */
    /* JMP @0x040660 (F2) -- tail call to scan orchestrator */
}
void scan_entry_mount(void)     /* Entry B @ 0x4063C, adapter=0x04 (Mount) */
{
    scan_common_init();           /* JSR @0x044E40 (F12) */
    adapter_config_mount();       /* JSR @0x045390 */
    /* JMP @0x040660 (F2) */
}
void scan_entry_240(void)       /* Entry C @ 0x40648, adapter=0x20 (240/APS) */
{
    scan_common_init();           /* JSR @0x044E40 (F12) */
    adapter_config_240();         /* JSR @0x0453CA */
    /* JMP @0x040660 (F2) */
}
void scan_entry_feeder(void)    /* Entry D @ 0x40654, adapter=0x40 (Feeder) */
{
    scan_common_init();           /* JSR @0x044E40 (F12) */
    adapter_config_feeder();      /* JSR @0x0453D6 */
    /* JMP @0x040660 (F2) */
}

/* F2: Scan Orchestrator -- FW:0x040660 (670 bytes)
 *
 * This is the central coordinator. It sequences the entire scan operation:
 * calibration loop, ASIC configuration, DMA setup, pixel transfer setup,
 * resolution configuration, and then enters the scan pipeline.
 */
void scan_orchestrator(void)
{
    /* --- Source: FW:0x040660 --- */
    /* push_context */

    /* Phase 1: Calibration stabilization loop */
    do {
        calibration_check(0x039C6C);  /* Run calibration until stable */
    } while (cal_not_stable);

    /* Phase 2: Read command state and configure */
    uint8_t cs = *(volatile uint8_t *)0x400773;
    if (cs == 0x01 || cs == 0x04) {
        /* Scan data mode -- proceed with scan */
    } else if (cs == 0x05) {
        /* Calibration data -- different pipeline */
        goto cal_path;
    } else {
        /* Other states -- alternative path at 0x407BE */
        goto alt_path;
    }

    /* Phase 3: Configure ASIC and DMA for scan */
    scan_asic_config();    /* F3 @ 0x408FE: ASIC channel setup */
    scan_dma_program();    /* F4 @ 0x411E8: DMA register programming */
    scan_pixel_setup();    /* F5 @ 0x414E4: CCD pixel transfer config */
    scan_resolution();     /* F6 @ 0x41EE8: resolution/adapter setup */

    /* Phase 4: Start scan pipeline functions */
    scan_pipeline_init(0x2D4E2);   /* Initialize DMA mode + burst counter */
    scan_pipeline_start(0x2D598);  /* Arm the DMA engine */
    scan_pipeline_run(0x2D7AE);    /* Configure per-line DMA descriptors */

    /* Phase 5: Configure motor and ASIC timing */
    motor_asic_setup(0x358EC);     /* ASIC motor register config */
    asic_timing_config(0x37D18);   /* CCD timing parameters */
    ccd_channel_setup(0x37338);    /* Per-channel CCD windows */

    /* Phase 6: Start the actual motor + CCD scan
     * After this, the scan runs interrupt-driven:
     *   - ITU2 steps the motor
     *   - ITU3 counts DMA bursts
     *   - ASIC DMA fills ASIC RAM with CCD data
     *   - The inner scan loop (0x40000) processes each line
     *   - ITU4 polls for USB transfer readiness
     */

    /* Enable timer interrupts for scan operation */
    *(volatile uint8_t *)0xFF7A |= 0x04;   /* BSET #2 -- timer port setup */
    *(volatile uint8_t *)0xFF7B |= 0x04;   /* BSET #2 -- timer port setup */
    *(volatile uint8_t *)TSTR  |= 0x04;    /* Start ITU2 (motor timer) */
    *(volatile uint8_t *)0xFF47 |= 0x04;   /* Additional timer enable */

    /* Enter inner scan loop -- processes each line until complete */
    inner_scan_loop();  /* @ 0x40000 */

    /* Phase 7: Scan complete -- cleanup */
    scan_cleanup();

    /* pop_context + RTS */
}


/* ============================================================================
 * 8. INNER SCAN LOOP (Pre-function State Machine @ 0x40000)
 * ============================================================================
 *
 * This 792-byte block is the HOT PATH -- called repeatedly during an active
 * scan to process each CCD line. It is NOT a standard function (no
 * push_context/pop_context). It runs inline within the scan orchestrator.
 *
 * The loop coordinates:
 *   1. Motor stepping (via task code checks)
 *   2. ASIC DMA trigger and wait
 *   3. Pixel processing (via F1)
 *   4. Scan line counting
 *   5. Yield between lines for USB transfer
 *
 * Key state variables polled:
 *   @0x400778 (task_code):  0x0300=abs move, 0x0310=rel move,
 *                           0x0320=scan dir, 0x0330=stall
 *   @0x400776 (state_flags): bit 7 = scan active
 *   @0x40078C (saved_desc): saved scan descriptor
 *   @0x400896 (counter):    line/DMA counter
 *   @0x406E6A (line_desc):  current scan line descriptor
 */

void inner_scan_loop(void)
{
    /* --- Source: FW:0x040000 - 0x040317 (792 bytes) --- */
    /* This is the core per-line loop.  */

    while (1) {

        /* ---- Step 1: Read scan line descriptor ---- */
        uint16_t line_desc = *(volatile uint16_t *)0x406E6A;
        uint16_t line_count = *(volatile uint16_t *)0x4064E6;

        /* Check if model is LS-5000 for model-specific behavior */
        uint8_t model = *(volatile uint8_t *)0x404E96;

        /* ---- Step 2: Configure next scan line ---- */
        /* Call ASIC function with scan descriptor */
        asic_configure_line(0x035A9A);  /* JSR @0x035A9A */

        /* Save scan descriptor for recovery */
        *(volatile uint32_t *)0x40078C = *(volatile uint32_t *)0x406E6A;

        /* ---- Step 3: Check motor state ---- */
        /* The scan loop must wait for motor positioning before capturing
         * each line. Motor operations run on ITU2 interrupts. */
        uint16_t tc = *(volatile uint16_t *)0x400778;

check_motor:
        if (tc == 0x0300) {
            /* Absolute motor positioning in progress */
            /* Check if motor done via counter at 0x400896 */
            if (*(volatile uint32_t *)0x400896 == 0) {
                goto motor_done;
            }
            /* Motor still moving -- yield and retry */
            yield();  /* JSR @0x0109E2 */
            goto check_motor;
        }
        if (tc == 0x0310) {
            /* Relative motor positioning */
            /* Same wait pattern */
            if (*(volatile uint32_t *)0x40078C == 0) {
                goto motor_done;
            }
            yield();
            goto check_motor;
        }

        /* Check bit 7 of state_flags -- if clear, scan is paused */
        if (!(*(volatile uint16_t *)0x400776 & 0x80)) {
            goto scan_done;
        }

motor_done:
        /* ---- Step 4: Trigger ASIC DMA for this line ---- */
        /* Write 0x02 to ASIC master control to start CCD capture + DMA */
        *(volatile uint8_t *)ASIC_MASTER_CTRL = 0x02;

        /* Poll ASIC status register bit 3: DMA busy */
        while (*(volatile uint8_t *)ASIC_STATUS & 0x08) {
            yield();  /* Don't spin -- yield to USB handler */
        }

        /* ---- Step 5: DMA complete -- process this line ---- */
        /* Write 0x81 to status register to acknowledge DMA completion
         * and configure post-DMA state */
        *(volatile uint8_t *)0x404EB7 = 0x81;

        /* Read scan parameters from stack frame for F1 */
        uint8_t  param_a = stack_frame[0x27];
        uint16_t param_b = *(uint16_t *)(stack_frame + 0x28);
        uint16_t param_c = *(uint16_t *)(stack_frame + 0x2A);

        /* Call F1: Scan Step Core -- processes one scan line */
        scan_step_core(param_a, param_b, param_c);  /* JSR @0x040318 */

        /* ---- Step 6: Update scan status ---- */
        *(volatile uint8_t *)0x4052EF = 0;   /* Clear secondary status */
        *(volatile uint8_t *)0x4052F1 = 0;   /* Clear active flag (will be re-set) */

        /* ---- Step 7: Check task code for continuation ---- */
        tc = *(volatile uint16_t *)0x400778;
        if (tc == 0x0300 || tc == 0x0310) {
            /* Motor still positioning -- wait again */
            goto check_motor;
        }

        /* ---- Step 8: Check for motor stall or direction change ---- */
        if (tc == 0x0320) {
            /* Scan direction change requested */
            /* Set result flag and reconfigure direction */
            *(volatile uint8_t *)0x4052F3 = 0x01;
            *(volatile uint8_t *)0x400E92 = 0x06;
            break;  /* Exit inner loop -- orchestrator handles re-entry */
        }
        if (tc == 0x0330) {
            /* Motor stall / buffer overflow */
            /* Emergency stop and re-sync */
            break;
        }

        /* ---- Step 9: Update progress for multi-step state machine ---- */
        /* This handles the extended state checks for multi-pass and
         * DMA buffer management */

        /* Check remaining line count for channel sequencing */
        uint16_t remaining = *(volatile uint16_t *)0x4058FC;
        if (remaining <= 0x0F) {
            /* Near end of scan -- special handling */
            /* Check stack variable at offset 0x3F for end condition */
        }

        /* Check for abort conditions */
        if (*(volatile uint16_t *)0x400776 & 0x80) {
            goto scan_done;
        }

        /* More checks for 0x0300/0x0310/0x0320 task codes... */
        /* These handle complex interleaving where motor positioning
         * and DMA can overlap. */

        /* ---- Step 10: Check line counter and advance ---- */

        /* Read scan descriptor, check if more lines needed */
        uint16_t desc_word = *(volatile uint16_t *)0x4064E6;
        if (desc_word == 0) {
            /* No more lines -- scan complete */
            goto scan_done;
        }

        /* Decrement line counter, loop back */
        /* The actual decrement happens in the DMA completion handler */

        /* Advance motor one step for next line:
         * This is implicit -- ITU2 motor timer fires per-step,
         * synchronized with the CCD integration time. The ASIC
         * coordinates motor stepping with CCD readout timing. */

    } /* end while(1) per-line loop */

scan_done:
    /* Signal scan completion */
    *(volatile uint8_t *)0x4052F1 = 0;   /* Clear scan active */
    return;
}


/* ============================================================================
 * 9. SCAN STEP CORE (F1 @ 0x40318, 792 bytes)
 * ============================================================================
 *
 * Processes a SINGLE scan line after DMA has transferred CCD data into
 * ASIC RAM. This function extracts pixels from the ASIC RAM buffer,
 * handles multi-channel interleaving, and manages the per-line state
 * progression.
 *
 * Called from the inner scan loop at 0x400E2 via JSR @0x040318.
 */
void scan_step_core(uint8_t param_a, uint16_t param_b, uint16_t param_c)
{
    /* --- Source: FW:0x040318 - 0x04062F (792 bytes) --- */
    /* push_context -- saves ER3-ER6 */
    /* Stack frame: 0x14 bytes local */

    /* er3 -> 0x405298: scan step state */
    /* er5 -> 0x405288: channel output position */
    /* er6 -> 0x405290: channel input position */

    /* Read current scan configuration */
    uint16_t config_word = *(volatile uint16_t *)0x4052FE;
    uint16_t scan_desc = *(volatile uint16_t *)0x405284;

    /* Check if IR channel is enabled */
    uint8_t ir_enabled = *(volatile uint8_t *)0x4074B8;

    /* Per-channel processing loop:
     * For each enabled channel (R, G, B, and optionally IR):
     *   1. Read pixel data from ASIC RAM at the channel's offset
     *   2. Apply bit extraction (14-bit from 16-bit CCD words)
     *   3. Write processed data to output buffer
     *   4. Update channel position counters
     */

    for (int channel = 0; channel < 4; channel++) {
        /* Skip IR channel if not enabled */
        if (channel == 3 && !ir_enabled) continue;

        /* Read source position from channel descriptor */
        uint16_t src_offset = chan_desc_a[channel * 2];
        uint16_t pix_count  = chan_desc_a[channel * 2 + 1];

        /* Calculate source address in ASIC RAM */
        uint32_t src_addr = ASIC_RAM_BASE + src_offset;

        /* Calculate destination in output buffer */
        uint16_t dst_offset = *(volatile uint16_t *)(0x405288 + channel * 2);
        uint32_t dst_addr = BUFFER_RAM_BASE + dst_offset;

        /* Process pixels for this channel */
        for (uint16_t px = 0; px < pix_count; px++) {
            /* Read 16-bit CCD word from ASIC RAM */
            uint16_t raw = *(volatile uint16_t *)(src_addr + px * 2);

            /* Bit extraction: 14-bit ADC result in 16-bit word
             *
             * The CCD produces 14-bit data. The ASIC packs this into
             * 16-bit words with 2 unused MSBs. The firmware extracts
             * the significant bits via shift-right:
             *
             *   For 14-bit mode: pixel = raw & 0x3FFF  (mask top 2 bits)
             *   For 8-bit mode:  pixel = raw >> 6       (keep top 8 of 14)
             *
             * The H8/300H shlr.w instruction is used for the shift.
             */
            uint16_t pixel;
            if (bit_depth_14) {
                pixel = raw & 0x3FFF;     /* 14-bit output */
            } else {
                pixel = (raw >> 6) & 0xFF; /* 8-bit output */
            }

            /* Write to output buffer */
            *(volatile uint16_t *)(dst_addr + px * 2) = pixel;
        }

        /* Update channel position for next line */
        *(volatile uint16_t *)(0x405288 + channel * 2) += pix_count * 2;
    }

    /* Update scan step state */
    *(volatile uint16_t *)0x405282 = scan_desc + 1;

    /* Check if this line completed a full scan frame */
    /* (for multi-pass modes, multiple CCD reads per output line) */

    /* pop_context + RTS */
}


/* ============================================================================
 * 10. PIXEL PROCESSING (@ 0x36C90 - 0x37A8C)
 * ============================================================================
 *
 * The pixel processing code reads raw 16-bit CCD data from ASIC RAM
 * (0x800000) and writes processed data to Buffer RAM (0xC00000) for
 * USB transfer. Processing is MINIMAL -- just bit extraction and
 * channel demux.
 *
 * The code processes data in fixed-size blocks with yield() calls between
 * blocks, allowing the USB transfer (ITU4 system tick) to service
 * pending transfers. This prevents the USB host from timing out during
 * long scans.
 *
 * Block sizes observed in the binary:
 *   Block 1:  0x1000  (4096 bytes)   -- process + yield
 *   Block 2:  0x2000  (8192 bytes)   -- process + yield
 *   Block 3:  0x3000  (12288 bytes)  -- process + yield
 *   Block 4:  0x3FC1  (16321 bytes)  -- near-full block + yield
 *   Block 5:  0x4000  (16384 bytes)  -- full block (final)
 */
void pixel_processing(void)
{
    /* --- Source: FW:0x036C90 - 0x037A8C --- */

    /* Load ASIC RAM base for source data */
    uint32_t asic_base = 0x800000;

    /* Check operation type for channel count */
    uint8_t op_type = *(volatile uint8_t *)0x4062E1;
    if (op_type >= 0x03) {
        /* Multi-channel mode -- process all 4 channels */
        goto multichannel;
    }

    /* --- Block 1: 4KB --- */
    /* Process 4096 bytes (2048 pixels) */
    pixel_block_process(asic_base, 0x1000);
    yield();  /* JSR @0x0109E2 -- let USB transfer proceed */

    /* --- Block 2: 8KB --- */
    pixel_block_process(asic_base + 0x1000, 0x2000);
    yield();

    /* --- Block 3: 12KB --- */
    pixel_block_process(asic_base + 0x2000, 0x3000);
    yield();

    /* --- Block 4: ~16KB --- */
    /* Merge with remaining processing */
    pixel_block_process(asic_base + 0x3000, 0x3FC1);
    yield();

    /* --- Block 5: 16KB --- */
    /* Final block completes the scan line */
    pixel_block_process(asic_base + 0x3FC1, 0x4000);

    /* If 14-bit mode and multi-channel: process more data */
    if (op_type == 0x03) {
        /* Extended processing for 14-bit RGB+IR */
        /* Uses both ASIC RAM banks (0x800000 and 0x418000) */
        goto extended_processing;
    }

    return;

multichannel:
    /* Load channel remap table from flash */
    uint32_t remap_ptr = *(volatile uint32_t *)0x4A37E;

    /* For each channel (R, G, B, IR): */
    for (int ch = 0; ch < 4; ch++) {
        /* Read correction level from characterization table */
        uint8_t correction = *(volatile uint8_t *)(remap_ptr++);

        /* Read pixel data from channel's ASIC RAM section */
        /* Each channel occupies a separate region in ASIC RAM:
         *   Channel 0 (R): 0x800000 + offset_R
         *   Channel 1 (G): 0x800000 + offset_G
         *   Channel 2 (B): 0x800000 + offset_B
         *   Channel 3 (IR): 0x800000 + offset_IR
         *
         * Offsets determined by scan_desc_ptr setup.
         */

        /* Process blocks with yields between them */
        pixel_block_process(channel_src, 0x1000);
        yield();
        pixel_block_process(channel_src + 0x1000, 0x2000);
        yield();
        pixel_block_process(channel_src + 0x2000, 0x3000);
        yield();
        pixel_block_process(channel_src + 0x3000, 0x4000);
    }
    return;

extended_processing:
    /* For 14-bit output, additional processing passes are needed.
     * The dual-bank scheme uses:
     *   Primary bank:   0x800000 (even lines or R/G)
     *   Secondary bank: 0x418000 (odd lines or B/IR)
     *
     * This allows the ASIC to fill one bank while the CPU reads
     * the other -- classic double-buffering.
     */
    pixel_block_process(0x418000, 0x1000);
    yield();
    /* ... additional passes ... */
    return;
}

/* Individual pixel block processor -- the innermost loop */
void pixel_block_process(uint32_t src_base, uint32_t block_size)
{
    /*
     * H8/300H inner loop (decoded from binary at 0x36C90+):
     *
     *   mov.l  #src_base, er6        ; Source pointer
     *   mov.b  @er4+, r0l            ; Read byte
     *   shlr.w r0                    ; Shift right (14->8 bit extraction)
     *   mov.b  r0l, @er5             ; Write to dest
     *   inc.l  #1, er5               ; Advance dest
     *   cmp.l  #end_addr, er4        ; Check block boundary
     *   bcs    loop                  ; Continue if not done
     *
     * The shlr.w (shift logical right word) is the key instruction
     * that extracts significant bits from the 16-bit CCD words.
     *
     * For 14-bit output: shlr.w is NOT applied (raw 14-bit value kept)
     * For 8-bit output:  6x shlr.w reduces 14 bits to 8 bits
     */
    uint16_t *src = (uint16_t *)src_base;
    uint16_t *end = (uint16_t *)(src_base + block_size);

    while (src < end) {
        uint16_t raw_pixel = *src++;
        /* Extract significant bits based on output bit depth */
        /* This is the ONLY processing the firmware does on pixel data */
        /* Store to output buffer (implied destination from registers) */
    }
}


/* ============================================================================
 * 11. DMA BURST COORDINATION (ITU3 ISR @ 0x2D536)
 * ============================================================================
 *
 * The ITU3 compare match ISR fires when each DMA burst completes. It
 * implements a two-level dispatch:
 *   Level 1: Burst countdown (multiple bursts per CCD line)
 *   Level 2: Mode-based dispatch when a full line is captured
 *
 * This is the mechanism that detects "one complete CCD line has been
 * DMA'd into ASIC RAM" and triggers per-line processing.
 */

/* ITU3 ISR -- Vec 36 (IMIA3) @ FW:0x02D536 */
void __attribute__((interrupt)) itu3_isr(void)
{
    /* --- Source: FW:0x02D536 --- */
    /* Push ER0, ER1 */

    /* Clear ITU3 DMA interrupt flag */
    /* BCLR #0, @DTCR (clear DMA transfer complete) */
    *(volatile uint8_t *)0xFF85 &= ~0x01;

    /* Read and decrement burst counter */
    uint8_t burst_count = *(volatile uint8_t *)0x406374;
    burst_count--;
    *(volatile uint8_t *)0x406374 = burst_count;

    if (burst_count != 0) {
        /* More bursts needed for this line -- return and wait */
        /* Pop ER0, ER1 + RTE */
        return;
    }

    /* ---- All bursts for this line are complete ---- */

    /* Read DMA mode to dispatch */
    uint8_t mode = *(volatile uint8_t *)0x4052D6;

    switch (mode) {
    case 1:
        /* Mode 1: Scan line callback
         * A complete CCD line has been captured. Call the scan line
         * completion handler which updates state and optionally
         * triggers the next line's DMA. */
        scan_line_callback();  /* @ 0x02CEB2 */
        break;

    case 2:
        /* Mode 2: Set state 3 and trigger next DMA
         * Buffer is full -- signal to USB transfer system */
        *(volatile uint8_t *)0x4052EE = 3;  /* scan_status = buffer full */
        /* Re-trigger ASIC DMA for next line */
        break;

    case 3:
        /* Mode 3: Streaming transfer continuation */
        /* Check remaining lines and continue or complete */
        {
            uint16_t lines = *(volatile uint16_t *)0x4064E6;
            if (lines > 0) {
                /* More lines: configure next burst */
                *(volatile uint8_t *)0x406374 = next_burst_count;
            } else {
                /* Scan complete */
                *(volatile uint8_t *)0x4052EE = 4;
            }
        }
        break;

    case 6:
        /* Mode 6: Cleanup/calibration DMA
         * Call cleanup handler */
        dma_cleanup();  /* @ 0x02D4B2 */
        break;
    }

    /* Pop ER0, ER1 + RTE */
}


/* Scan Line Callback -- FW:0x02CEB2
 *
 * Called by ITU3 ISR (mode 1) when a complete CCD line has been
 * DMA'd into ASIC RAM. This is the bridge between the hardware
 * DMA system and the software scan loop.
 */
void scan_line_callback(void)
{
    /* --- Source: FW:0x02CEB2 --- */

    /* Clear GPIO shadow bits for this operation */
    uint8_t gpio = *(volatile uint8_t *)0x400791;

    /* Read scan descriptor from DMA state */
    uint16_t desc = *(volatile uint16_t *)0x406370;

    /* Update operation type */
    *(volatile uint8_t *)0x400791 = gpio;

    /* Clear DMA status bits */
    /* ... */

    /* Check channel flag for multi-channel processing */
    uint8_t ch_flag = *(volatile uint8_t *)0x406337;
    if (ch_flag == 0x01) {
        /* Single channel done */
        *(volatile uint8_t *)0x4052DA = 0x01;
    } else if (ch_flag == 0x02) {
        /* Multi-channel: check completion */
        *(volatile uint8_t *)0x4052DA = 0x01;
    }

    /* Check secondary channel flag */
    uint8_t ch_flag2 = *(volatile uint8_t *)0x4052DB;
    if (ch_flag2 != 0) {
        /* Manage channel sequencing for RGB+IR */
        /* Route to 0x2D4B8 or 0x2D3B8 for channel progression */
    }

    /* Update scan status for main loop and USB transfer system */
    uint8_t status = *(volatile uint8_t *)0x4052DA;
    if (status == 0x01) {
        /* This line is ready -- main loop can process it */
    }

    /* Check if all lines complete */
    uint8_t complete = *(volatile uint8_t *)0x4052E1;
    if (complete == 0x01) {
        /* Signal scan completion */
        *(volatile uint8_t *)0x4052E1 = 0;
    }

    /* Re-trigger ASIC DMA for next line (BSET #0, @er6) */
    /* This starts the CCD capture for the next scan line */
}


/* ============================================================================
 * 12. USB TRANSFER PIPELINE
 * ============================================================================
 *
 * Scan data is transferred to the host via USB bulk-in transfers.
 * The transfer system uses a PULL model: the ITU4 system tick ISR
 * periodically checks if scan data is ready and initiates transfers.
 *
 * Data flow:
 *   ASIC RAM (0x800000) --> CPU pixel extract --> Buffer RAM (0xC00000)
 *   Buffer RAM --> ISP1581 DMA --> USB bulk-in pipe --> Host
 *
 * The host reads data with SCSI READ(10) (opcode 0x28, DTC 0x00).
 * Each READ request retrieves one or more scan lines.
 */

/* ITU4 System Tick ISR -- Vec 40 (IMIA4) @ FW:0x010A16
 *
 * This is a periodic timer interrupt (~1ms period) that:
 *   1. Increments the global timestamp at 0x40076E
 *   2. Polls for scan data ready to transfer via USB
 *   3. Initiates USB transfers when data is available
 *
 * It is started ONCE at system init and never stopped.
 */
void __attribute__((interrupt)) itu4_system_tick(void)
{
    /* --- Source: FW:0x010A16 --- */

    /* Clear ITU4 interrupt flag */
    /* Read TSR4, clear compare match flag */

    /* Increment global 32-bit timestamp */
    (*(volatile uint32_t *)0x40076E)++;

    /* Check if USB transfer is already in progress */
    uint8_t xfer = *(volatile uint8_t *)0x4062E6;
    if (xfer != 0) {
        /* Transfer active: continue servicing it */
        continue_usb_transfer();
        return;
    }

    /* Check command state for scan data availability */
    uint8_t cs = *(volatile uint8_t *)0x400773;
    if (cs == 0x04) {
        /* State 4: scan data ready */
        /* Check scan status for buffer full */
        if (*(volatile uint8_t *)0x4052EE == 0x03) {
            /* Buffer full -- push data to USB */
            push_to_usb();  /* JSR @0x010B3E */
        }
    } else if (cs == 0x05) {
        /* State 5: calibration data ready */
        push_cal_to_usb();
    }

    /* RTE */
}

/* Transfer mode dispatch -- FW:0x010B3E
 *
 * Routes to mode-specific USB transfer handlers.
 * The transfer mode is set during scan initialization based on
 * the scan type (preview, fine, multi-pass).
 */
void push_to_usb(void)
{
    uint8_t mode = *(volatile uint8_t *)0x4052D6;
    switch (mode) {
    case 2: block_transfer(0x02E268);   break;  /* Block mode */
    case 3: stream_transfer(0x02EDC0);  break;  /* Streaming mode */
    case 4: scanline_transfer(0x3337E); break;  /* Per-line mode */
    case 6: cal_transfer(0x02E276);     break;  /* Calibration mode */
    }
}

/* Response Manager -- FW:0x1374A
 *
 * Manages USB bulk-in transfers for all data types (scan data,
 * sense data, command responses). For scan data, it:
 *   1. Checks if USB endpoint is free
 *   2. Configures ISP1581 DMA
 *   3. Starts bulk transfer
 *   4. Returns (transfer completes asynchronously)
 */
void usb_response_manager(uint8_t phase)
{
    /* --- Source: FW:0x01374A --- */

    /* Check if USB endpoint is busy */
    if (*(volatile uint8_t *)0x40049A != 0) {
        return;  /* Endpoint still busy from previous transfer */
    }

    /* Store command phase */
    *(volatile uint8_t *)0x407DC6 = phase;

    /* Setup ISP1581 DMA for response */
    isp1581_dma_setup();  /* JSR @0x013C70 */

    /* Wait for DMA ready */
    yield();  /* JSR @0x109E2 */

    /* Mark endpoint as active */
    *(volatile uint8_t *)0x40049A = 0x01;
    /* Increment transfer counter */
    (*(volatile uint8_t *)0x40049D)++;
}

/* ISP1581 DMA Setup -- FW:0x013C70 */
void isp1581_dma_setup(void)
{
    /* --- Source: FW:0x013C70 --- */

    /* Configure ISP1581 DMA direction and mode */
    /* ... check endpoint status, clear state ... */

    /* Setup transfer parameters */
    /* JSR @0x013D68 */
}

/* ISP1581 Bulk Transfer Start -- FW:0x013F3A */
void isp1581_bulk_start(uint16_t *data, uint32_t byte_count)
{
    /* --- Source: FW:0x013F3A --- */

    /* Configure DMA direction: host-read (device -> host) */
    *(volatile uint16_t *)ISP_DMA_REG = 0x8000;

    /* Set DMA mode: bulk endpoint */
    *(volatile uint16_t *)ISP_DMA_CONFIG = 0x0005;

    /* Enable DMA transfer */
    *(volatile uint16_t *)ISP_DMA_CNT = 0x0001;

    /* Write first data word to DATA_PORT to prime the pipe */
    *(volatile uint16_t *)ISP_DATA_PORT = data[0];

    /* ISP1581 DMA engine handles the rest automatically.
     * The USB controller will:
     *   1. Read sequential words from the data source
     *   2. Pack into USB bulk-in packets (512 bytes for USB 2.0)
     *   3. Send to host when packets are ready
     *   4. Generate interrupt on completion
     *
     * Note: ISP1581 is little-endian, H8/3003 is big-endian.
     * The firmware handles byte-swapping in the endpoint
     * read/write functions at 0x012258 and 0x0122C4.
     */
}


/* ============================================================================
 * 13. MULTI-PASS SCANNING (F8 @ 0x42E2A, 3790 bytes)
 * ============================================================================
 *
 * Multi-pass scanning captures multiple CCD exposures per scan line
 * to improve dynamic range and reduce noise. The firmware averages
 * multiple reads at different exposure times.
 *
 * Multi-pass is enabled by scan groups 7-8 (task codes 0x0870-0x0884)
 * and extended multi-sample groups 9-B (0x0891-0x08B4).
 *
 * F8 is the largest scan function (3790 bytes) because it must manage:
 *   - Multiple CCD exposures per motor position
 *   - USB data transfer interleaving between passes
 *   - Re-calibration between passes (exposure drift compensation)
 *   - Timing adjustment for different exposure durations
 */
void multi_pass_scan_orchestrator(void)
{
    /* --- Source: FW:0x042E2A - 0x043CF7 --- */
    /* push_context, stack frame = 0x50 bytes */

    /* Read adapter and scan configuration */
    uint8_t adapter = *(volatile uint8_t *)0x400F5B;
    uint16_t config = *(volatile uint16_t *)0x400F3A;

    /* Initialize multi-pass parameters:
     *   - Pass count (typically 2 or 4)
     *   - Exposure time per pass
     *   - Accumulation buffer setup
     */

    /* Read scan geometry from host parameters */
    uint8_t scan_type = *(volatile uint8_t *)0x400F56;
    uint16_t line_count = scan_line_count();

    /* Main multi-pass loop:
     * For each motor position (scan line):
     *   For each pass:
     *     1. Set exposure parameters for this pass
     *     2. Trigger CCD capture via ASIC
     *     3. Wait for DMA completion
     *     4. Accumulate data into averaging buffer
     *   Combine passes (average/sum)
     *   Transfer result to USB staging buffer
     */

    for (uint16_t line = 0; line < line_count; line++) {

        /* Recalibrate if needed (every N lines to track drift) */
        if ((line % cal_interval) == 0) {
            calibration_recheck();  /* JSR @0x039C6C */
        }

        /* For each exposure pass: */
        for (int pass = 0; pass < pass_count; pass++) {

            /* Configure exposure time for this pass */
            exposure_timing_set(pass);  /* JSR @0x03718A */

            /* Trigger CCD capture */
            *(volatile uint8_t *)ASIC_MASTER_CTRL = 0x02;

            /* Wait for DMA completion */
            while (*(volatile uint8_t *)ASIC_STATUS & 0x08) {
                yield();
            }

            /* Accumulate pixel data from this pass */
            /* The accumulation is done in 32-bit arithmetic to
             * prevent overflow when summing multiple 14-bit values */
        }

        /* Average the accumulated data:
         *   result[px] = sum[px] / pass_count
         * This reduces random noise by sqrt(pass_count). */

        /* Transfer averaged line to USB staging buffer */
        usb_transfer_line();  /* JSR @0x012360, 0x012398 */

        /* Advance motor one step for next line position */
        /* Motor stepping is handled by ITU2 interrupts */
    }

    /* pop_context + RTS */
}


/* ============================================================================
 * 14. COLOR CHANNEL HANDLING
 * ============================================================================
 *
 * The CCD is a tri-linear sensor with 4 output channels. During scanning,
 * all 4 channels are read simultaneously in each CCD cycle, but they
 * must be demultiplexed and stored separately.
 *
 * Channel layout in ASIC RAM (0x800000, 224KB total):
 *
 *   The 224KB is divided into banks with different granularities:
 *     Banks 1-4:   32KB each (0x800000, 0x808000, 0x810000, 0x818000)
 *     Banks 5-16:  8KB each  (0x820000 through 0x836000)
 *
 *   Total: 16 usable banks (from ASIC RAM bank descriptor table at 0x49A94)
 *
 * Channel assignment per scan mode:
 *
 *   RGB (no ICE):  3 channels -> 3 banks
 *     Bank 1 (0x800000): Red
 *     Bank 2 (0x808000): Green
 *     Bank 3 (0x810000): Blue
 *
 *   RGB+IR (with ICE):  4 channels -> 4 banks
 *     Bank 1 (0x800000): Red
 *     Bank 2 (0x808000): Green
 *     Bank 3 (0x810000): Blue
 *     Bank 4 (0x818000): IR (infrared for Digital ICE)
 *
 *   Grayscale: 1 channel -> 1 bank
 *     Bank 1 (0x800000): Green (used as luminance)
 *
 * Per-channel descriptors at 0x405342-0x40535A:
 *   Each descriptor is 6 bytes:
 *     Bytes 0-1: Start offset (0x02F5 = 757 pixels)
 *     Bytes 2-3: End offset   (0x02F5 = 757 pixels)
 *     Bytes 4-5: Width        (0x0299 = 665 pixels)
 *
 *   The start/end/width values define the active pixel window within
 *   the CCD line. Pixels outside this window are dark reference pixels
 *   (used for black level calibration by the host software).
 *
 * CCD channel remap table at FW:0x4A520:
 *   {04, 01, 02, 03, 05, 00} x 8 repetitions
 *   Maps physical ASIC readout order to logical color channels.
 *   The ASIC reads CCD lines in a hardware-determined order that
 *   differs from the logical R,G,B,IR sequence.
 */


/* ============================================================================
 * 15. RESOLUTION SCALING
 * ============================================================================
 *
 * The LS-50 supports resolutions from 150 DPI to 4000 DPI.
 * Resolution affects the scan loop in several ways:
 *
 * 1. MOTOR STEP SIZE:
 *    At 4000 DPI (max), one motor step = one scan line.
 *    At lower resolutions, the motor may step multiple times per
 *    captured line (skip lines for speed), or the ASIC may bin
 *    adjacent CCD elements optically.
 *
 *    Speed ramp table selection depends on resolution:
 *      High res (4000/2700 DPI): Fine ramp table @ 0x459D2
 *      Medium res (1350 DPI):    Medium ramp @ 0x45C3A
 *      Low res (600/300 DPI):    Coarse ramp @ 0x45EA2
 *
 * 2. CCD INTEGRATION TIME:
 *    Computed at FW:0x44DCE (F11: Timing Computation):
 *      period_us = 1000000 / dpi_setting    (microseconds per pixel)
 *      Then adjusted by: period_us * 640    (CCD element count factor)
 *
 *    Higher resolution = shorter integration time per pixel
 *    = more noise but finer spatial detail.
 *
 *    The ASIC timing registers (0x200408-0x200425) define 5 timing
 *    phases per CCD readout cycle:
 *      Phase 1: Transfer gate (0x408-40D)
 *      Phase 2: Integration window (0x40E-413)
 *      Phase 3: Second integration (0x414-419, usually = Phase 2)
 *      Phase 4: Readout (0x41A-41F)
 *      Phase 5: Reset/clamp (0x420-425)
 *
 * 3. DATA VOLUME:
 *    At 4000 DPI, 14-bit RGB+IR:
 *      pixels_per_line = 4095
 *      bytes_per_pixel = 2 (16-bit word)
 *      channels = 4
 *      bytes_per_line = 4095 * 2 * 4 = 32,760 bytes
 *
 *    At 4000 DPI, 8-bit RGB:
 *      bytes_per_line = 4095 * 1 * 3 = 12,285 bytes
 *
 *    Preview mode (low res):
 *      Typically 600 DPI, 8-bit RGB
 *      bytes_per_line = ~3000 bytes
 *
 * 4. SCAN GROUP SELECTION (task code):
 *    Preview:          Groups 0-2 (0x0800-0x0820), handler 0x0022
 *    Fine 8-bit:       Group 3 (0x0830-0x0834)
 *    Fine 8-bit+ICE:   Group 4 (0x0840-0x0844)
 *    Fine 14-bit:      Group 5 (0x0850-0x0854)
 *    Fine 14-bit+ICE:  Group 6 (0x0860-0x0864)
 *    Multi-pass:       Group 7 (0x0870-0x0874)
 *    Multi-pass+ICE:   Group 8 (0x0880-0x0884)
 *    Extended multi:   Groups 9-B (0x0891-0x08B4)
 *
 *    The variant suffix (0-4) selects the adapter type:
 *      0 = base/default, 1-4 = strip/mount/240/feeder
 *
 * Resolution setup is handled by F6 (0x41EE8-0x4292D, 2630 bytes):
 *   - Reads host-configured DPI from scan parameters
 *   - Computes motor step multiplier
 *   - Configures ASIC pixel clock divider (0x2001C2)
 *   - Sets CCD integration timing registers
 *   - Adjusts DMA transfer count for the line width
 *   - Configures per-channel pixel windows
 */


/* ============================================================================
 * 16. SHADING CORRECTION & CALIBRATION
 * ============================================================================
 *
 * KEY INSIGHT: The firmware does NOT perform shading correction.
 * All calibration correction is done HOST-SIDE by NikonScan software.
 *
 * What the firmware DOES do:
 *
 * 1. ANALOG FRONT-END CALIBRATION (before scan starts):
 *    - Sets DAC mode to 0xA2 (calibration enable)
 *    - Reads CCD with lamp on white reference strip
 *    - Reads CCD with lamp off (dark frame)
 *    - Computes per-channel min/max values
 *    - Adjusts analog gain (coarse + fine DAC) to maximize ADC range
 *    - Stores calibration results in RAM for host to read via SCSI READ
 *
 *    Four calibration routines (same pattern):
 *      0x3D12D, 0x3DE51, 0x3EEF9, 0x3F897
 *    Each writes 0xA2 to 0x2000C2, reads CCD, computes min/max.
 *
 * 2. CCD CHARACTERIZATION DATA (read from flash):
 *    Factory-programmed analog correction levels at 0x4A8BC-0x528BD
 *    (~32KB). This is a per-element correction table with 11 distinct
 *    levels (0x00-0x0B), NOT a binary defect map.
 *
 *    The firmware reads this data via pointer table at 0x4A37E and
 *    uses it to set per-element analog offsets in the ASIC AFE before
 *    scanning. This compensates for:
 *      - CCD dark current non-uniformity
 *      - Optical vignetting
 *      - Lens shading
 *
 * 3. CALIBRATION DATA TRANSFER TO HOST:
 *    The host reads calibration data via:
 *      SCSI READ (0x28), DTC 0x84 (Calibration Data)
 *      SCSI READ (0x28), DTC 0x88 (Boundary/Per-Channel Cal)
 *      SCSI READ (0x28), DTC 0x8A (Exposure/Gain)
 *      SCSI READ (0x28), DTC 0x8C (Offset/Dark Current)
 *
 *    NikonScan then uses these to build correction matrices for:
 *      - Dark frame subtraction
 *      - White normalization (flat-field correction)
 *      - Per-channel gain equalization
 *      - Gamma correction
 *      - Color balance
 *
 * 4. MODEL-SPECIFIC ANALOG SETTINGS:
 *    The LS-50 and LS-5000 share firmware but have different CCD sensors
 *    with different analog characteristics:
 *
 *    | Parameter          | LS-50 (flag=0) | LS-5000 (flag!=0) |
 *    |--------------------|----------------|-------------------|
 *    | Fine DAC (0x2000C7)|     0x08       |       0x00        |
 *    | Coarse gain (0x142)|     0x64 (100) |       0xB4 (180)  |
 *
 *    Model detected via flag at RAM 0x404E96.
 */


/* ============================================================================
 * 17. ERROR DETECTION & RECOVERY
 * ============================================================================
 *
 * The firmware detects several error conditions during scanning:
 *
 * 1. DMA TIMEOUT:
 *    The inner scan loop polls ASIC status bit 3 (DMA busy) with
 *    yield() calls between polls. If DMA takes too long, the system
 *    tick timer (ITU4) can detect the stall via timestamp comparison.
 *
 * 2. MOTOR STALL:
 *    The encoder ISR at 0x033444 measures time between encoder pulses.
 *    If the inter-pulse delta (at 0x405314) exceeds a threshold,
 *    the motor has stalled. Task code 0x0330 represents this state.
 *    The inner scan loop checks for 0x0330 and exits cleanly.
 *
 * 3. BUFFER OVERRUN:
 *    If the CCD DMA fills ASIC RAM faster than the CPU can extract
 *    pixels, the burst counter (0x406374) underflows. The ITU3 ISR
 *    detects this and routes to mode 6 (cleanup at 0x2D4B2).
 *
 * 4. USB TRANSFER STALL:
 *    If the host stops reading USB bulk-in data, Buffer RAM fills up.
 *    The scan loop yield() calls give the ITU4 tick a chance to detect
 *    this, but ultimately the scan will pause waiting for buffer space.
 *
 * 5. HOST ABORT:
 *    The host can abort a scan by sending SCSI SCAN (0x1B) with abort
 *    flag, or by USB bus reset. The main loop checks bit 6 of
 *    state_flags (0x400776) for abort requests.
 *
 * Recovery task codes:
 *   0x0F20: Post-scan cleanup and recovery
 *   Used after normal completion or error conditions.
 *
 * Sense codes set on scan errors:
 *   0x0050: Not ready (scanner state invalid)
 *   0x0007: Generic error
 *   0x0008: Timeout
 *   0x0009: Motor error
 *   0x0061: USB communication error
 *   0x0079: Adapter error
 *   0x007A: Film holder error
 */


/* ============================================================================
 * 18. TIMING DIAGRAMS
 * ============================================================================
 *
 * === SINGLE SCAN LINE TIMING (estimated, 4000 DPI, 14-bit RGB) ===
 *
 * The CCD integration time and motor step timing are synchronized.
 * At maximum resolution, one motor step = one scan line.
 *
 * CPU clock: 20 MHz (assumed typical for H8/3003)
 * USB 2.0 bulk bandwidth: 480 Mbps theoretical, ~35 MB/s practical
 *
 * Time estimates per line at 4000 DPI, 14-bit RGB+IR:
 *   Motor step:         ~250 us (one step at scan speed)
 *   CCD integration:    ~500 us (varies with exposure setting)
 *   ASIC DMA to RAM:    ~200 us (32KB at ASIC bus speed)
 *   CPU pixel extract:  ~1.5 ms (4095 px * 4 ch * ~90 ns/byte)
 *   USB bulk transfer:  ~1.0 ms (32KB at ~35 MB/s)
 *   Overhead:           ~100 us (yield, state updates)
 *   TOTAL per line:     ~3.5 ms
 *   Lines per second:   ~285
 *
 * For a 35mm film frame (36mm x 24mm) at 4000 DPI:
 *   Lines = 24mm / (25.4mm/4000DPI) = ~3780 lines
 *   Scan time = 3780 * 3.5ms = ~13.2 seconds (single pass, RGB+IR)
 *   (Real scans take longer due to calibration, motor accel/decel)
 *
 *
 * === PIPELINE TIMING DIAGRAM ===
 *
 * The scan engine uses pipeline parallelism. While one line's data is
 * being transferred to the host via USB, the next line is being captured.
 *
 * Time -->
 *
 * Line N:
 *   [Motor Step N]
 *   [--- CCD Integrate ---]
 *   [ASIC DMA N to ASIC RAM]
 *                          [CPU Extract N]
 *                                         [USB Send N]
 *
 * Line N+1:
 *            [Motor Step N+1]
 *            [--- CCD Integrate N+1 ---]
 *            [ASIC DMA N+1 to ASIC RAM]
 *                                      [CPU Extract N+1]
 *                                                       [USB Send N+1]
 *
 * The key overlap:
 *   - Motor + CCD capture of line N+1 starts while CPU processes line N
 *   - USB transfer of line N happens while CCD captures line N+1
 *   - ASIC RAM double-banking (0x800000 / 0x818000) enables this overlap
 *
 *
 * === COOPERATIVE SCHEDULING DIAGRAM ===
 *
 * The two coroutine contexts interleave via TRAPA #0 (yield):
 *
 * Context A (Main Loop, SCSI commands):
 *   [Check USB] [Check Scan] [Dispatch CMD] [YIELD] ...
 *
 * Context B (Background, data management):
 *   ... [YIELD] [Monitor DMA] [Motor coord] [YIELD] ...
 *
 * Hardware Interrupts (preempt either context):
 *   IRQ1: USB packet received
 *   ITU2: Motor step timing
 *   ITU3: DMA burst complete
 *   ITU4: System tick (USB transfer poll)
 *   IRQ3: Encoder pulse (motor position)
 *
 *
 * === DMA BURST TIMING ===
 *
 * A single CCD line transfer may require multiple DMA bursts.
 *
 * Burst size: 16KB (0x4000 bytes, from ASIC_DMA_CNT_MID init = 0x40)
 * Line data: ~32KB for 4-channel 14-bit (4095 px * 2 bytes * 4 ch)
 * Bursts per line: 2 (for 32KB total)
 *
 * ITU3 ISR fires after each burst, decrements burst_counter (0x406374).
 * When counter reaches 0, the full line is ready.
 *
 *   [Burst 1: 16KB] --> ITU3 ISR: counter-- (=1, not done)
 *   [Burst 2: 16KB] --> ITU3 ISR: counter-- (=0, LINE DONE!)
 *                         --> scan_line_callback()
 *                         --> set scan_status = 3
 */


/* ============================================================================
 * 19. BUFFER LAYOUT & GEOMETRY
 * ============================================================================
 *
 * === ASIC RAM (224KB @ 0x800000) ===
 *
 * Primary storage for raw CCD data. Organized as banks:
 *
 *   Bank  Address   Size   Use
 *   ----  --------  -----  --------
 *   1     0x800000  32KB   CCD data, channel 0 (Red)
 *   2     0x808000  32KB   CCD data, channel 1 (Green)
 *   3     0x810000  32KB   CCD data, channel 2 (Blue)
 *   4     0x818000  32KB   CCD data, channel 3 (IR) / double-buffer
 *   5-16  0x820000  8KB ea Per-line sub-buffers for finer granularity
 *
 * For double-buffering during scan:
 *   While ASIC DMA writes to bank 1-4 (current line),
 *   CPU reads from the secondary bank at 0x418000 (previous line).
 *   The roles swap each line.
 *
 *
 * === Buffer RAM (64KB @ 0xC00000) ===
 *
 * USB staging area. Processed pixel data is written here before
 * being DMA'd to the ISP1581 USB controller.
 *
 *   Bank A: 0xC00000 (32KB)  -- active transfer buffer
 *   Bank B: 0xC08000 (32KB)  -- ping-pong alternate
 *
 * During calibration, Buffer RAM is used for cal data with
 * ping-pong buffering between Bank A and Bank B.
 *
 *
 * === CPU RAM Scan State (@ 0x400000+) ===
 *
 * The scan engine uses approximately 2KB of CPU RAM for state:
 *
 *   0x400773-0x400796: Core scan state (36 bytes)
 *   0x4052D4-0x405310: DMA and channel state (60 bytes)
 *   0x405342-0x40535A: Channel descriptors (24 bytes)
 *   0x4058FC-0x405910: Extended scan state (20 bytes)
 *   0x4062E0-0x406400: DMA control block (288 bytes)
 *   0x406E3A-0x406E8A: Channel descriptor tables (80 bytes)
 *
 *
 * === Data Format in USB Transfer ===
 *
 * The firmware packages scan data for USB transfer as follows:
 *
 * For 14-bit RGB (host reads via SCSI READ, DTC 0x00):
 *   Each pixel: 16-bit word, little-endian on USB
 *   Channel order: R, G, B (interleaved by channel, not by pixel)
 *   Line structure: [R_line][G_line][B_line]
 *   Total per line: pixels * 2 bytes * 3 channels
 *
 * For 14-bit RGB+IR (with Digital ICE):
 *   Same as above but: [R_line][G_line][B_line][IR_line]
 *   Total per line: pixels * 2 bytes * 4 channels
 *
 * For 8-bit RGB:
 *   Each pixel: 1 byte
 *   Same channel-interleaved layout
 *   Total per line: pixels * 1 byte * 3 channels
 *
 * The host software (LS5000.md3) knows the channel layout from the
 * SET WINDOW parameters and reconstructs the image accordingly.
 */


/* ============================================================================
 * 20. COMPLETE SCAN SEQUENCE WALKTHROUGH
 * ============================================================================
 *
 * This section traces a complete fine scan at 4000 DPI, 14-bit, RGB+IR,
 * strip adapter, from host command to final data transfer.
 *
 * === PHASE 1: HOST SETUP ===
 *
 * 1. Host sends SCSI SET WINDOW (0x24):
 *    - Resolution: 4000 DPI
 *    - Bit depth: 14
 *    - Color mode: RGB + IR
 *    - Scan area: [x_start, y_start, width, height]
 *    Firmware stores parameters in RAM @ 0x400D45+
 *
 * 2. Host sends SCSI E0 (Vendor Data Out):
 *    - Subcode 0x40-0x47: Scan control parameters
 *    - Exposure settings, gain values
 *    Firmware stores in vendor register area
 *
 * 3. Host sends SCSI C1 (Vendor Trigger):
 *    - Subcode 0x40: Initiate scan
 *    - Sets 32-bit task code at @0x40077E
 *    - For this scan: task code = 0x0861 (fine 14-bit+ICE, strip adapter)
 *      (Group 6 = fine 14-bit+ICE, variant 1 = strip)
 *
 *
 * === PHASE 2: FIRMWARE INITIALIZATION ===
 *
 * 4. Main loop picks up task code 0x0861:
 *    - Task dispatch (0x20DBA) searches table @ 0x49910
 *    - Finds handler index 0x0034 (Group 6, variant 1)
 *    - Adapter dispatch (0x3C400) selects Entry A (strip, 0x40630)
 *
 * 5. Entry A executes:
 *    a. F12 (0x44E40): Common scan initialization
 *       - Set scan config flags
 *       - Compute timing: period = 1000000 / 4000 = 250 us/pixel
 *       - Configure USB transfer for scan data
 *
 *    b. Adapter config (0x4536E): Strip-specific parameters
 *       - Set motor parameters for strip holder geometry
 *       - Configure scan area boundaries
 *
 *    c. Jump to F2 (0x40660): Scan orchestrator
 *
 * 6. F2 orchestrator:
 *    a. Calibration loop:
 *       - DAC mode = 0xA2 (calibration)
 *       - Capture dark frame (lamp off, CCD read)
 *       - Capture white reference (lamp on, white strip)
 *       - Compute per-channel gain adjustments
 *       - Repeat until gain values stabilize (usually 2-3 iterations)
 *
 *    b. ASIC configuration (F3, 0x408FE):
 *       - Set per-channel CCD timing windows
 *       - Configure pixel clock divider for 4000 DPI
 *       - Set integration time (250 us)
 *       - Program analog gain registers
 *
 *    c. DMA programming (F4, 0x411E8):
 *       - Set DMA destination: 0x800000 (ASIC RAM bank 1)
 *       - Set transfer count: 32760 bytes (4095 * 2 * 4 channels)
 *       - Configure burst count: 2 (two 16KB bursts per line)
 *       - Set burst counter initial value: 2 -> @0x406374
 *
 *    d. CCD pixel transfer setup (F5, 0x414E4):
 *       - Configure per-channel source offsets in ASIC RAM
 *       - Set output buffer pointers
 *       - Configure channel remap from physical to logical order
 *
 *    e. Resolution setup (F6, 0x41EE8):
 *       - Configure motor step size for 4000 DPI
 *       - Select speed ramp table (fine ramp @ 0x459D2)
 *       - Set scan area boundaries in motor step coordinates
 *
 *    f. Initialize scan pipeline:
 *       - Set DMA mode = 1 (scan line mode)
 *       - Set DAC mode = 0x22 (normal scan)
 *       - Arm the DMA engine
 *       - Configure motor for scan direction
 *
 *    g. Start timers:
 *       - Start ITU2 (motor stepping)
 *       - ITU3 already armed for DMA burst counting
 *       - ITU4 already running (system tick)
 *
 *
 * === PHASE 3: SCANNING (per-line hot loop) ===
 *
 * 7. Inner scan loop (0x40000) runs for each line:
 *
 *    For line_number = 0 to total_lines:
 *
 *    a. MOTOR STEP:
 *       ITU2 fires, steps motor one position.
 *       Motor ISR writes stepper phase to Port A (0xFFFFA3).
 *       Encoder ISR (IRQ3) counts pulses for position feedback.
 *       Inner loop checks task_code for motor completion.
 *
 *    b. CCD CAPTURE:
 *       Write 0x02 to ASIC_MASTER_CTRL (0x200001).
 *       ASIC begins CCD integration cycle:
 *         - Transfer gate opens (Phase 1 timing)
 *         - Integration window (Phase 2 timing, ~250 us)
 *         - Readout (Phase 4 timing)
 *         - ADC converts analog to 14-bit digital
 *
 *    c. ASIC DMA:
 *       ASIC DMA engine transfers digitized CCD data to ASIC RAM.
 *       Configuration: addr = 0x800000, count = 32760 bytes.
 *       Two 16KB bursts required.
 *
 *       Burst 1 completes -> ITU3 ISR fires
 *         burst_counter = 2 - 1 = 1 (not done, return)
 *
 *       Burst 2 completes -> ITU3 ISR fires
 *         burst_counter = 1 - 1 = 0 (DONE!)
 *         Mode 1 -> call scan_line_callback (0x2CEB2)
 *         scan_status (0x4052EE) = 3 (buffer full)
 *
 *    d. CPU PIXEL EXTRACTION:
 *       Inner loop detects DMA complete (status bit 3 clear).
 *       Calls F1 (scan_step_core @ 0x40318):
 *         For each channel (R, G, B, IR):
 *           Read 16-bit CCD words from ASIC RAM
 *           Extract 14-bit pixel values (mask top 2 bits)
 *           Write to channel-separated output buffers
 *
 *       Then calls pixel_processing (0x36C90):
 *         Process in 4KB-16KB blocks with yield() between blocks
 *         Allows USB transfer to proceed concurrently
 *
 *    e. USB TRANSFER:
 *       ITU4 system tick detects scan_status == 3.
 *       Calls push_to_usb (0x10B3E):
 *         Response manager (0x1374A) checks endpoint availability
 *         ISP1581 DMA configured: direction = host-read (0x8000)
 *         DMA mode = bulk (0x0005)
 *         Transfer starts from Buffer RAM (0xC00000)
 *         ISP1581 handles USB packet formation automatically
 *         Host reads data via SCSI READ (0x28), DTC 0x00
 *
 *    f. NEXT LINE:
 *       scan_status cleared
 *       ASIC DMA re-armed for next line (bank swap if double-buffered)
 *       burst_counter reset to 2
 *       Motor step already in progress for next line
 *       Loop back to (a)
 *
 *
 * === PHASE 4: COMPLETION ===
 *
 * 8. Line counter reaches 0:
 *    - scan_complete (0x405302) set to 1
 *    - Inner loop exits
 *    - F2 orchestrator performs cleanup:
 *      - Stop ITU2 (motor timer)
 *      - Clear DMA state
 *      - Set DAC mode back to idle
 *      - Motor return to park position
 *    - Recovery task (0x0F20) runs for post-scan cleanup
 *
 * 9. Host detects scan completion:
 *    - SCSI TEST UNIT READY (0x00) returns no sense
 *    - Host reads remaining buffered scan data via SCSI READ
 *    - Scan operation complete
 *
 *
 * === SUMMARY: KEY FIRMWARE ADDRESSES ===
 *
 * | Address   | Size   | Function                                    |
 * |-----------|--------|---------------------------------------------|
 * | 0x2CEB2   | ~320B  | Scan line callback (DMA line complete)      |
 * | 0x2D4E2   | ~180B  | Scan pipeline init (DMA mode setup)         |
 * | 0x2D536   | ~200B  | ITU3 ISR (DMA burst countdown)              |
 * | 0x2D598   | ~100B  | Scan pipeline start (DMA arm)               |
 * | 0x2D7AE   | ~350B  | DMA descriptor management                   |
 * | 0x2EC00   | ~2KB   | SCAN command handler (SCSI 0x1B)            |
 * | 0x35C7E   | ~128B  | ASIC DMA buffer config                      |
 * | 0x35D58   | ~58B   | ASIC DMA address config                     |
 * | 0x35D92   | ~40B   | ASIC DMA count + trigger                    |
 * | 0x36C90   | ~3.5KB | Pixel processing (bit extraction)           |
 * | 0x40000   | 792B   | INNER SCAN LOOP (per-line hot path)         |
 * | 0x40318   | 792B   | F1: Scan step core (per-line processing)    |
 * | 0x40630   | 48B    | Scan entry points (4 adapter types)         |
 * | 0x40660   | 670B   | F2: Scan orchestrator (central coordinator) |
 * | 0x408FE   | 2282B  | F3: ASIC channel configuration              |
 * | 0x411E8   | 764B   | F4: DMA register programming                |
 * | 0x414E4   | 2498B  | F5: CCD pixel transfer config               |
 * | 0x41EE8   | 2630B  | F6: Resolution/adapter setup                |
 * | 0x4292E   | 1276B  | F7: Calibration scan routine                |
 * | 0x42E2A   | 3790B  | F8: Multi-pass scan orchestrator            |
 * | 0x43D2A   | 184B   | F9: Scan parameter computation              |
 * | 0x43DE2   | 4076B  | F10: Full scan pipeline (direct mode)       |
 * | 0x44DCE   | 114B   | F11: Timing computation                     |
 * | 0x44E40   | 1216B  | F12: Common scan initialization             |
 * | 0x010A16  | ~128B  | ITU4 ISR (USB transfer polling)             |
 * | 0x010B76  | ~64B   | ITU2 ISR (motor step dispatch)              |
 * | 0x01374A  | ~190B  | USB response manager                        |
 * | 0x013C70  | ~260B  | ISP1581 DMA setup                           |
 * | 0x013F3A  | ~200B  | ISP1581 bulk transfer start                 |
 * | 0x033444  | ~100B  | Encoder ISR (motor position feedback)       |
 *
 * Total scan engine code: ~20KB (state machine) + ~3.5KB (pixel proc)
 *                        + ~2KB (DMA/pipeline) + ~2KB (USB transfer)
 *                        + ~1KB (ISRs) = ~28.5KB
 *
 */


/* ============================================================================
 * END OF DOCUMENT
 *
 * This pseudocode reconstruction covers the complete scan engine of the
 * Nikon LS-50 firmware. Combined with the KB docs for ASIC registers,
 * motor control, ISP1581 USB, and SCSI commands, this provides sufficient
 * detail for a driver developer to implement a compatible scan engine.
 *
 * Key takeaways for driver writers:
 *
 * 1. The firmware is a THIN LAYER between CCD hardware and USB.
 *    It does almost no image processing -- just bit extraction.
 *    ALL calibration, color correction, and image processing is
 *    done host-side in NikonScan (DRAG/ICE DLLs).
 *
 * 2. The scan engine is INTERRUPT-DRIVEN with cooperative yielding.
 *    Five timer/DMA ISRs coordinate the motor, CCD, DMA, and USB
 *    subsystems. The main CPU loop only handles per-line state
 *    transitions and pixel extraction.
 *
 * 3. DOUBLE-BUFFERING is used at two levels:
 *    - ASIC RAM (0x800000 / 0x818000) for CCD data
 *    - Buffer RAM (0xC00000 / 0xC08000) for USB staging
 *    This allows capture and transfer to overlap.
 *
 * 4. The PROTOCOL is identical across all scan modes.
 *    Preview, fine, multi-pass -- they all use the same SCSI
 *    commands and data format. Only the firmware-internal pipeline
 *    configuration changes (via task code groups 0-B).
 *
 * 5. TIMING IS CRITICAL. The motor step rate, CCD integration time,
 *    DMA burst timing, and USB transfer rate must all be balanced.
 *    The firmware achieves this through the ITU timer system and
 *    the burst counter mechanism.
 *
 * ============================================================================
 */
