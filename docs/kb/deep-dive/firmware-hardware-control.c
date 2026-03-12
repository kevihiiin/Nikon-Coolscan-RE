/*
 * Nikon LS-50 / LS-5000 Firmware Hardware Control — C Pseudocode
 * ==============================================================
 *
 * CPU:     Hitachi H8/3003 (H8/300H family), 24-bit address bus, big-endian
 * Flash:   512KB MBM29F400B TSOP48 at 0x000000
 * ASIC:    Custom scanner ASIC at 0x200000 (172 registers, 8 blocks)
 * RAM:     128KB external at 0x400000
 * USB:     Philips ISP1581 at 0x600000
 * CCD:     Tri-linear R/G/B + IR (Digital ICE), 4095 active elements
 * Motors:  2 stepper motors (scan carriage + autofocus)
 *
 * Source: Reverse-engineered from firmware binary dump.
 * Addresses cited as FW:0xXXXXX refer to flash offsets.
 *
 * This file is organized into sections:
 *   1. Hardware Register Definitions
 *   2. RAM State Variables
 *   3. Data Tables (flash-resident)
 *   4. Interrupt Handlers (all 15 active vectors)
 *   5. Motor Control Subsystem
 *   6. CCD / ASIC Control
 *   7. Lamp Control
 *   8. Calibration
 *   9. Scan Pipeline
 *  10. USB / ISP1581 Interface
 *  11. Boot & Initialization
 *  12. Main Loop & Context System
 */

#include <stdint.h>

/* ======================================================================
 * SECTION 1: HARDWARE REGISTER DEFINITIONS
 * ====================================================================== */

/* --- H8/3003 On-Chip I/O Registers (0xFFFF20 - 0xFFFFFF) --- */

/* Timer Start Register — controls which ITU channels are running */
#define TSTR    (*(volatile uint8_t *)0xFFFF60)
  /* Bit 0: ITU0 (encoder capture, 3 start sites)
   * Bit 1: ITU1 (position feedback, 1 start)
   * Bit 2: ITU2 (motor mode dispatcher, 11 start / 15 stop — per-movement)
   * Bit 3: ITU3 (DMA burst coordination, 4 start)
   * Bit 4: ITU4 (system tick, 1 start / 0 stop — once at init, never stopped) */

/* ITU Timer Control Registers */
#define TCR0    (*(volatile uint8_t *)0xFFFF64)  /* ITU0 control */
#define TCR2    (*(volatile uint8_t *)0xFFFF78)  /* ITU2 control (motor) */
#define TCNT2   (*(volatile uint16_t*)0xFFFF7A)  /* ITU2 counter */
#define GRA2    (*(volatile uint16_t*)0xFFFF7C)  /* ITU2 compare A */
#define GRB2    (*(volatile uint16_t*)0xFFFF7E)  /* ITU2 compare B */
#define TCR3    (*(volatile uint8_t *)0xFFFF82)  /* ITU3 control */
#define TCNT3   (*(volatile uint16_t*)0xFFFF84)  /* ITU3 counter */
#define GRA3    (*(volatile uint16_t*)0xFFFF86)  /* ITU3 compare A */
#define TSR4    (*(volatile uint8_t *)0xFFFF95)  /* ITU4 status (system tick reads this) */
#define TCNT4   (*(volatile uint16_t*)0xFFFF96)  /* ITU4 counter */
#define GRA4    (*(volatile uint16_t*)0xFFFF98)  /* ITU4 compare A */
#define TIER2   (*(volatile uint8_t *)0xFFFF79)  /* ITU2 interrupt enable */
#define TIER3   (*(volatile uint8_t *)0xFFFF83)  /* ITU3 interrupt enable */

/* DMA Transfer Control Registers */
#define DTCR    (*(volatile uint8_t *)0xFFFF2F)  /* DMA channel 0B transfer control */
  /* Bit 3: DEND0B completion flag (cleared by ISR) */

/* GPIO Port Registers */
#define PORT_A_DR   (*(volatile uint8_t *)0xFFFFA3)  /* Port A data: motor stepper phases */
#define PORT_3_DDR  (*(volatile uint8_t *)0xFFFF84)  /* Port 3 DDR: motor direction (bit 0) */
#define PORT_7_DR   (*(volatile uint8_t *)0xFFFF8E)  /* Port 7 data: adapter/sensor input */
#define PORT_9_DR   (*(volatile uint8_t *)0xFFFFC8)  /* Port 9 data: encoder input / phase out */
#define PORT_4_DDR  (*(volatile uint8_t *)0xFFFF85)  /* Port 4 DDR: lamp control (bit 0) */
  /* Lamp: BCLR #0 = ON (open-drain, active-low), BSET #0 = OFF */

/* Bus State Controller */
#define ABWCR   (*(volatile uint8_t *)0xFFFFF2)  /* Bus width: 0x0B */
#define WCR     (*(volatile uint8_t *)0xFFFFF4)  /* Wait states: 0xBA */
#define WCER    (*(volatile uint8_t *)0xFFFFF5)  /* Wait control enable: 0x00 */
#define BRCR    (*(volatile uint8_t *)0xFFFFF8)  /* Bus release: 0x00 */
#define CSCR    (*(volatile uint8_t *)0xFFFFF9)  /* Chip select: 0x30 */

/* Port Direction Registers (from I/O init table) */
#define P1DDR   (*(volatile uint8_t *)0xFFFFD4)  /* Port 1 DDR: 0xFF (all output) */
#define P2DDR   (*(volatile uint8_t *)0xFFFFD5)  /* Port 2 DDR: 0x01 (bit 0 output) */
#define P3DDR_DIR (*(volatile uint8_t *)0xFFFFD6) /* Port 3 DDR: 0x00 (all input) */
#define P4DDR_DIR (*(volatile uint8_t *)0xFFFFD7) /* Port 4 DDR: 0x01 (bit 0 output) */

/* Watchdog Timer */
#define WDT_TCSR (*(volatile uint16_t*)0xFFFFA8) /* Watchdog: write 0x5A00 to reset */

/* A/D Converter */
#define ADCSR   (*(volatile uint8_t *)0xFFFFE8)  /* A/D Control/Status (bit 7 = ADF) */
#define ADDRA   (*(volatile uint16_t*)0xFFFFE0)  /* A/D Data Register A */

/* SCI0/SCI1 (polled, not interrupt-driven) */
#define SCI0_SMR (*(volatile uint8_t *)0xFFFFB0) /* Serial mode */
#define SCI0_BRR (*(volatile uint8_t *)0xFFFFB1) /* Bit rate */
#define SCI0_SSR (*(volatile uint8_t *)0xFFFFB4) /* Serial status */
#define SCI0_RDR (*(volatile uint8_t *)0xFFFFB5) /* Receive data */
#define SCI0_TDR (*(volatile uint8_t *)0xFFFFB3) /* Transmit data */

/* CCR manipulation macros (H8/300H) */
#define ENABLE_INTERRUPTS()   asm("andc #0x7F, ccr")
#define DISABLE_INTERRUPTS()  asm("orc  #0x80, ccr")

/* --- Custom Scanner ASIC Registers (0x200000+) --- */

/* Block 0x00: System Control / DAC / ADC */
#define ASIC_MASTER_CTRL  (*(volatile uint8_t *)0x200001)  /* Master enable/reset. Init=0x80 */
  /* Write 0x02: configure / trigger DMA
   * Write 0x20: start scan
   * Write 0x80: master enable/reset
   * Write 0xC0: DMA acknowledge */
#define ASIC_STATUS       (*(volatile uint8_t *)0x200002)  /* Status (read) */
  /* Bit 3: DMA busy (poll until clear) */
#define ASIC_STATUS_2     (*(volatile uint8_t *)0x200003)  /* Status/control */
#define ASIC_INT_CONFIG   (*(volatile uint8_t *)0x200008)  /* Interrupt configuration */
#define ASIC_INT_MASK     (*(volatile uint8_t *)0x20000F)  /* Interrupt mask */
#define ASIC_DMA_CTRL     (*(volatile uint8_t *)0x200020)  /* DMA control */
#define ASIC_DMA_STATUS   (*(volatile uint8_t *)0x200028)  /* DMA status */
#define ASIC_RAM_TEST_A   (*(volatile uint8_t *)0x200041)  /* RAM test register A */
#define ASIC_RAM_TEST_B   (*(volatile uint8_t *)0x200042)  /* RAM test register B */
#define ASIC_INIT_44      (*(volatile uint8_t *)0x200044)  /* Init: 0x00 */
#define ASIC_INIT_45      (*(volatile uint8_t *)0x200045)  /* Init: 0x00 */
#define ASIC_INIT_46      (*(volatile uint8_t *)0x200046)  /* Init: 0xFF */

/* DAC/ADC Configuration (CCD analog front-end) */
#define ASIC_DAC_MASTER   (*(volatile uint8_t *)0x2000C0)  /* DAC master config. Init=0x52 */
#define ASIC_DAC_CTRL     (*(volatile uint8_t *)0x2000C1)  /* DAC control. Init=0x04 */
#define ASIC_DAC_MODE     (*(volatile uint8_t *)0x2000C2)  /* DAC mode register (16 code refs!) */
  /* 0x20: init/basic mode
   * 0x22: normal scanning mode
   * 0xA2: calibration mode (bit 7 = calibration enable) */
#define ASIC_ADC_CTRL     (*(volatile uint8_t *)0x2000C4)  /* ADC control */
#define ASIC_ADC_READBACK (*(volatile uint8_t *)0x2000C6)  /* ADC readback (read-only) */
#define ASIC_DAC_FINE     (*(volatile uint8_t *)0x2000C7)  /* DAC fine control */
  /* LS-50: 0x08, LS-5000: 0x00  (selected by model_flag at 0x404E96) */

/* Block 0x01: DMA Channel Configuration */
#define ASIC_DMA_CH0_SRC  (*(volatile uint8_t *)0x200100)  /* DMA ch0 source. Init=0x3F */
#define ASIC_DMA_CH0_DST  (*(volatile uint8_t *)0x200101)  /* DMA ch0 dest. Init=0x3F */
#define ASIC_MOTOR_DMA    (*(volatile uint8_t *)0x200102)  /* Motor DMA control. Init=0x04 */
  /* Written at 5 sites in motor code */
#define ASIC_DMA_CH_MODE  (*(volatile uint8_t *)0x200103)  /* DMA channel mode. Init=0x01 */
#define ASIC_DMA_CH1_SRC  (*(volatile uint8_t *)0x200104)  /* Init=0x30 */
#define ASIC_DMA_CH1_DST  (*(volatile uint8_t *)0x200105)  /* Init=0x32 */
#define ASIC_DMA_CH2_SRC  (*(volatile uint8_t *)0x200106)  /* Init=0x34 */
#define ASIC_DMA_CH2_DST  (*(volatile uint8_t *)0x200107)  /* Init=0x36 */
#define ASIC_DMA_CH3_SRC  (*(volatile uint8_t *)0x20010C)  /* Init=0x20 */
#define ASIC_DMA_CH3_DST  (*(volatile uint8_t *)0x20010D)  /* Init=0x22 */
#define ASIC_DMA_CH4_SRC  (*(volatile uint8_t *)0x20010E)  /* Init=0x24 */
#define ASIC_DMA_CH4_DST  (*(volatile uint8_t *)0x20010F)  /* Init=0x26 */
#define ASIC_DMA_CH5_SRC  (*(volatile uint8_t *)0x200114)  /* Init=0x00 */
#define ASIC_DMA_CH5_DST  (*(volatile uint8_t *)0x200115)  /* Init=0x08 */
#define ASIC_DMA_CH6_SRC  (*(volatile uint8_t *)0x200116)  /* Init=0x10 */
#define ASIC_DMA_CH6_DST  (*(volatile uint8_t *)0x200117)  /* Init=0x18 */

/* DMA Buffer/Transfer Control */
#define ASIC_DMA_ENABLE   (*(volatile uint8_t *)0x200140)  /* DMA enable. Init=0x01 */
#define ASIC_DMA_MODE     (*(volatile uint8_t *)0x200141)  /* DMA mode. Init=0x01 */
#define ASIC_DMA_XFER_CFG (*(volatile uint8_t *)0x200142)  /* DMA transfer config. Init=0x04 */
  /* LS-50 coarse gain=0x64 (100), LS-5000 coarse gain=0xB4 (180) */
#define ASIC_BUF_CTRL     (*(volatile uint8_t *)0x200143)  /* Buffer control. Init=0x01 */
#define ASIC_BUF_MODE     (*(volatile uint8_t *)0x200144)  /* Buffer mode. Init=0x04 */
#define ASIC_BUF_ADDR_HI  (*(volatile uint8_t *)0x200147)  /* Buffer addr [23:16] */
#define ASIC_BUF_ADDR_MID (*(volatile uint8_t *)0x200148)  /* Buffer addr [15:8] */
#define ASIC_BUF_ADDR_LO  (*(volatile uint8_t *)0x200149)  /* Buffer addr [7:0] */
  /* Typical: 0x80, 0x00, 0x00 => ASIC RAM at 0x800000 */
#define ASIC_XFER_CNT_HI  (*(volatile uint8_t *)0x20014B)  /* Transfer count [23:16] */
#define ASIC_XFER_CNT_MID (*(volatile uint8_t *)0x20014C)  /* Transfer count [15:8]. Init=0x40 */
#define ASIC_XFER_CNT_LO  (*(volatile uint8_t *)0x20014D)  /* Transfer count [7:0] */
#define ASIC_DMA_STATUS_2 (*(volatile uint8_t *)0x20014E)  /* DMA status 2 */
#define ASIC_DMA_CTRL_2   (*(volatile uint8_t *)0x20014F)  /* DMA control 2. Init=0x04 */
#define ASIC_DMA_INT_EN   (*(volatile uint8_t *)0x200150)  /* DMA interrupt enable. Init=0x03 */
#define ASIC_COARSE_GAIN2 (*(volatile uint8_t *)0x200152)  /* Ch2 coarse gain (cal) */
#define ASIC_FINE_GAIN2   (*(volatile uint8_t *)0x200153)  /* Ch2 fine gain (cal) */

/* Motor Drive Registers */
#define ASIC_MOTOR_CFG    (*(volatile uint8_t *)0x200181)  /* Motor drive config. Init=0x0D */
#define ASIC_MOTOR_A_BASE ((volatile uint8_t *)0x200182)   /* Motor drive ch A: 4 pairs */
  /* 0x200182-0x200189: 4 register pairs (high/low), coil drive signals */
#define ASIC_MOTOR_CFG_B  (*(volatile uint8_t *)0x200193)  /* Motor config B. Init=0x0E */
#define ASIC_MOTOR_B_BASE ((volatile uint8_t *)0x200194)   /* Motor drive ch B: 4 pairs */
  /* 0x200194-0x20019B: 4 register pairs (high/low) */
#define ASIC_MOTOR_AUX_A  (*(volatile uint8_t *)0x2001A4)  /* Motor auxiliary config */
#define ASIC_MOTOR_AUX_B  (*(volatile uint8_t *)0x2001A5)
#define ASIC_MOTOR_AUX_C  (*(volatile uint8_t *)0x2001A6)

/* CCD Line Timing */
#define ASIC_LINE_MODE    (*(volatile uint8_t *)0x2001C0)  /* Line timing mode. Init=0x03 */
#define ASIC_LINE_CTRL    (*(volatile uint8_t *)0x2001C1)  /* Line timing control */
  /* Write 0x80: trigger DMA. Referenced from 0x3C274 */
#define ASIC_PIXEL_CLK    (*(volatile uint8_t *)0x2001C2)  /* Pixel clock divider. Init=0x0F */
#define ASIC_LINE_PER_LO  (*(volatile uint8_t *)0x2001C3)  /* Line period low. Init=0x98 */
#define ASIC_LINE_PER_HI  (*(volatile uint8_t *)0x2001C4)  /* Line period high. Init=0x00 */
#define ASIC_INT_START    (*(volatile uint8_t *)0x2001C5)  /* Integration start. Init=0x19 */
#define ASIC_INT_CFG      (*(volatile uint8_t *)0x2001C6)  /* Integration config. Init=0x0F */
#define ASIC_INT_END      (*(volatile uint8_t *)0x2001C7)  /* Integration end. Init=0x69 */
#define ASIC_RD_START     (*(volatile uint8_t *)0x2001C8)  /* Readout start. Init=0x00 */
#define ASIC_RD_CFG       (*(volatile uint8_t *)0x2001C9)  /* Readout config. Init=0x18 */
#define ASIC_CAL_CFG1     (*(volatile uint8_t *)0x2001CA)  /* Calibration config 1 */
#define ASIC_CAL_CFG2     (*(volatile uint8_t *)0x2001CB)  /* Calibration config 2 */

/* Block 0x02: CCD Data Channel Configuration (4 channels, stride-8) */
#define ASIC_CH_MASTER    (*(volatile uint8_t *)0x200200)  /* Channel master. Init=0x00 */
#define ASIC_CH0_CFG      (*(volatile uint8_t *)0x200204)  /* Channel 0 (Red). Init=0x04 */
#define ASIC_CH0_MODE     (*(volatile uint8_t *)0x200205)  /* Channel 0 mode. Init=0x03 */
/* 0x200214-0x200215: Channel 0 pair B */
/* 0x20021C-0x20021D: Channel 1 (Green) */
/* 0x200224-0x200225: Channel 1 pair B */
/* 0x20022C-0x20022D: Channel 2 (Blue) */
/* 0x200255: Channel 2 extended */
/* 0x20025D: Channel 3 (IR) */
/* 0x200265: Channel 3 extended */
/* 0x20026D: Channel master extended */

/* Block 0x04: CCD Timing / Analog Gain */
#define ASIC_CCD_MODE     (*(volatile uint8_t *)0x200400)  /* CCD master mode. Init=0x20 */
#define ASIC_CCD_PIXCLK   (*(volatile uint8_t *)0x200401)  /* CCD pixel clock. Init=0x0A */
#define ASIC_CCD_CTRL     (*(volatile uint8_t *)0x200402)  /* CCD control. Init=0x00 */
#define ASIC_CCD_CFG_A    (*(volatile uint8_t *)0x200404)  /* CCD config A. Init=0x00 */
#define ASIC_CCD_MASK     (*(volatile uint8_t *)0x200405)  /* CCD data mask. Init=0xFF */
#define ASIC_CCD_ENABLE   (*(volatile uint8_t *)0x200406)  /* CCD enable. Init=0x01 */

/* CCD Integration Timing (5 groups of 6 registers each, 0x200408-0x200425) */
/* Group 1: Transfer gate timing */
#define ASIC_INT_GRP1_BASE ((volatile uint8_t *)0x200408)
  /* Init: 0x01, 0x41, 0x00, 0x09, 0x00, 0x19 */
/* Group 2: Integration window */
#define ASIC_INT_GRP2_BASE ((volatile uint8_t *)0x20040E)
  /* Init: 0x01, 0x2B, 0x00, 0x0D, 0x00, 0x15 */
/* Group 3: Second integration (same as group 2) */
#define ASIC_INT_GRP3_BASE ((volatile uint8_t *)0x200414)
/* Group 4: Readout timing */
#define ASIC_INT_GRP4_BASE ((volatile uint8_t *)0x20041A)
  /* Init: 0x01, 0x29, 0x00, 0x02, 0x00, 0x20 */
/* Group 5: Reset/clamp timing */
#define ASIC_INT_GRP5_BASE ((volatile uint8_t *)0x200420)
  /* Init: 0x01, 0x2F, 0x00, 0x05, 0x00, 0x1D */

/* Analog Gain (init-only: set during I/O table, never changed at runtime) */
#define ASIC_GAIN_MODE    (*(volatile uint8_t *)0x200456)  /* Gain channel select. Init=0x00 */
#define ASIC_GAIN_CH1     (*(volatile uint8_t *)0x200457)  /* Analog gain ch1. Init=0x63 (99) */
#define ASIC_GAIN_CH2     (*(volatile uint8_t *)0x200458)  /* Analog gain ch2. Init=0x63 (99) */

/* Per-Channel CCD Config (4 channels at stride 8, 0x20046D-0x200487) */
/* Each: offset, start, end.  Init: 0x00, 0x01, 0x2B for all channels */
#define ASIC_CH_RED_BASE   ((volatile uint8_t *)0x20046D) /* Chan 0 (Red) */
#define ASIC_CH_GREEN_BASE ((volatile uint8_t *)0x200475) /* Chan 1 (Green) */
#define ASIC_CH_BLUE_BASE  ((volatile uint8_t *)0x20047D) /* Chan 2 (Blue) */
#define ASIC_CH_IR_BASE    ((volatile uint8_t *)0x200485) /* Chan 3 (IR/ICE) */

/* Init-only blocks (zero runtime code references, set from I/O init table) */
/* Block 0x09: 0x200910 */
/* Block 0x0A: 0x200A81-0x200AF2 (4 regs) */
/* Block 0x0C: 0x200C82 */
/* Block 0x0F: 0x200F20-0x200FC0 (4 regs) */


/* --- ISP1581 USB Controller Registers (0x600000+) --- */
#define ISP_INT_STATUS   (*(volatile uint16_t*)0x600008)  /* Interrupt status */
#define ISP_MODE         (*(volatile uint16_t*)0x60000C)  /* Mode register */
  /* Bit 4: SOFTCT — soft-connect control (1=disconnected, 0=connected) */
#define ISP_DMA_REG      (*(volatile uint16_t*)0x600018)  /* DMA control/direction */
  /* 0x8000 = host-read direction */
#define ISP_EP_INDEX     (*(volatile uint16_t*)0x60001C)  /* Endpoint index/control */
#define ISP_DATA_PORT    (*(volatile uint16_t*)0x600020)  /* Endpoint data (bulk R/W) */
#define ISP_EP_CTRL      (*(volatile uint16_t*)0x60002C)  /* Endpoint/DMA config */
  /* 0x0005 = bulk DMA mode */
#define ISP_DMA_COUNT    (*(volatile uint16_t*)0x600084)  /* DMA transfer count */
#define ISP_CHIP_ID      (*(volatile uint16_t*)0x600084)  /* Chip ID (init check) */


/* --- Memory Region Pointers --- */
#define ASIC_RAM_BASE    ((volatile uint8_t *)0x800000)  /* 224KB CCD line buffer */
#define ASIC_RAM_BANK2   ((volatile uint8_t *)0x808000)
#define ASIC_RAM_BANK3   ((volatile uint8_t *)0x810000)
#define ASIC_RAM_BANK4   ((volatile uint8_t *)0x818000)
  /* Banks 5-16: 0x820000-0x836000 at 8KB spacing */
#define ASIC_RAM_END     ((volatile uint8_t *)0x838000)  /* Boundary marker */

#define BUFFER_RAM_BANK_A ((volatile uint8_t *)0xC00000) /* 32KB ping buffer */
#define BUFFER_RAM_BANK_B ((volatile uint8_t *)0xC08000) /* 32KB pong buffer */

/* On-chip RAM (used for interrupt trampolines) */
#define TRAMPOLINE_BASE  ((volatile uint8_t *)0xFFFD10)
  /* 12 x 4-byte JMP instructions installed at runtime */


/* ======================================================================
 * SECTION 2: RAM STATE VARIABLES (External RAM at 0x400000)
 * ====================================================================== */

/* USB / Command State */
static volatile uint8_t  cmd_pending;       /* 0x400082: USB command pending */
static volatile uint8_t  usb_reset_flag;    /* 0x400084: USB bus reset event */
static volatile uint8_t  usb_reinit_flag;   /* 0x400085: USB re-init needed */
static volatile uint8_t  usb_error_flag;    /* 0x400086: USB error */
static volatile uint8_t  task_complete;     /* 0x400492: task completion flag */
static volatile uint8_t  task_active;       /* 0x400493: task execution active */
static volatile uint8_t  usb_txn_active;    /* 0x40049A: USB transaction in progress */
static volatile uint8_t  exec_mode;         /* 0x40049B: current SCSI exec mode */
static volatile uint8_t  xfer_phase;        /* 0x40049C: USB transfer phase */
static volatile uint8_t  cmd_counter;       /* 0x40049D: command completion counter */

/* Context Switch */
static volatile uint16_t ctx_switch_state;  /* 0x400764: context switch state word */
static volatile uint32_t ctx_sp_save[2];    /* 0x400766: SP save (2 contexts x 4B) */

/* System Flags */
static volatile uint8_t  boot_flag;         /* 0x400772: 0=cold, 1=warm restart */
static volatile uint8_t  adapter_type_gpio; /* 0x400773: current command state / adapter */
  /* 0x04 = scan data ready
   * 0x05 = calibration data */
static volatile uint8_t  motor_mode;        /* 0x400774: ITU2 dispatch selector */
  /* 2 = scan motor step
   * 3 = AF motor step
   * 4 = encoder/special
   * 6 = alt scan motor (reverse?) */
static volatile uint8_t  scanner_state_flags; /* 0x400776 */
  /* Bit 6: abort requested
   * Bit 7: response/scan active */
static volatile uint16_t task_code;         /* 0x400778: current task code */
static volatile uint16_t scan_progress;     /* 0x40077A: scan progress state */
static volatile uint16_t state_machine_var; /* 0x40077C: scanner state machine */
static volatile uint32_t exposure_R;        /* 0x40077E: R channel exposure timing */
static volatile uint32_t exposure_G;        /* 0x400782: G channel exposure timing */
static volatile uint32_t task_remaining;    /* 0x40078C: task remaining work count */
static volatile uint8_t  gpio_shadow;       /* 0x400791: GPIO shadow (23 refs) */
static volatile uint32_t task_budget;       /* 0x400896: task time budget */

/* SCSI */
static volatile uint16_t sense_code;        /* 0x4007B0: SCSI sense code */
static volatile uint8_t  scsi_opcode;       /* 0x4007B6: current SCSI opcode */
static volatile uint8_t  cdb_buffer[16];    /* 0x4007DE: CDB receive buffer */

/* Motor State */
static volatile uint16_t motor_ramp_config; /* 0x400CC8: ramp table selector */
static volatile uint16_t motor_speed_param; /* 0x400C0E: current speed parameter */
static volatile uint16_t motor_step_count;  /* 0x4052E2: current step position */
static volatile uint16_t motor_target_pos;  /* 0x4052E4: target position */
static volatile uint16_t motor_current_speed;/* 0x4052E6: current timer period */
static volatile uint16_t motor_accel_index; /* 0x4052E8: accel ramp table index */
static volatile uint8_t  motor_enable_flag; /* 0x4052EA: motor enabled */
static volatile uint8_t  motor_running_flag;/* 0x4052EB: motor currently running */
static volatile uint8_t  motor_state;       /* 0x4052EC: motor state machine */
static volatile uint8_t  motor_direction2;  /* 0x4052ED: direction (secondary) */
static volatile uint8_t  motor_error_flag;  /* 0x4052EE: error / buffer_status */
  /* Also used as buffer_status: 3 = buffer full, ready for USB */

/* Scan Pipeline */
static volatile uint8_t  scan_mode_dma;     /* 0x4052D6: ITU3 ISR dispatch mode */
  /* 1 = scan line callback
   * 2 = set state 3, trigger next DMA
   * 6 = cleanup */
static volatile uint8_t  scan_status_byte;  /* 0x4052EF: scan status */
static volatile uint8_t  scan_active_flag;  /* 0x4052F1: scan in progress */
static volatile uint8_t  scan_complete;     /* 0x405302: all lines scanned */

/* Encoder */
static volatile uint8_t  encoder_enable;    /* 0x405300: encoder enabled */
static volatile uint8_t  encoder_mode;      /* 0x405306: encoder mode */
static volatile uint8_t  encoder_state;     /* 0x40530A: encoder state */
  /* 0xD1 = special mode (triggers extra processing in ISR) */
static volatile uint16_t encoder_count;     /* 0x40530E: pulse count */
static volatile uint16_t encoder_delta;     /* 0x405314: inter-pulse delta */
static volatile uint32_t encoder_timestamp; /* 0x405318: timestamp of last event */
static volatile uint16_t encoder_last_capture;/* 0x40531A: previous capture value */

/* DMA / USB Transfer */
static volatile uint16_t dma_burst_counter; /* 0x406374: DMA burst countdown */
static volatile uint8_t  xfer_state;        /* 0x4062E6: USB transfer state */
static volatile uint32_t scan_desc_ptr;     /* 0x406370: scan descriptor pointer */
static volatile uint16_t line_counter;      /* 0x4064E6: remaining scan lines */
static volatile uint32_t system_timestamp;  /* 0x40076E: ITU4 tick counter */

/* Calibration */
static volatile uint8_t  lamp_state;        /* 0x400082: lamp state (0=off, 1=on) */
static volatile uint8_t  lamp_active;       /* 0x400E5F: lamp/soft-reset flag */
static volatile uint8_t  model_flag;        /* 0x404E96: LS-50 vs LS-5000 */
  /* 0 = LS-50, nonzero = LS-5000 */
static volatile uint8_t  adapter_type_byte; /* 0x400F22: adapter bitmask */
  /* 0x04=Mount, 0x08=Strip, 0x20=240, 0x40=Feeder */

/* USB Session */
static volatile uint8_t  usb_session_state; /* 0x407DC7: USB session (2=ready) */
/* ... many more at 0x407Dxx block ... */

/* Channel descriptors — per-channel pixel geometry */
/* 0x405342-0x40535A: 4 x {start=0x02F5 (757), size=0x0299 (665)} */


/* ======================================================================
 * SECTION 3: DATA TABLES (Flash-Resident)
 * ====================================================================== */

/*
 * I/O Init Table at FW:0x2001C (132 entries x 6 bytes each)
 * Format: [address:32] [pad:8] [value:8]
 * Covers 30 CPU registers + 48 ASIC core + 54 CCD/channel registers.
 * Last entry: 0x200001 = 0x80 (ASIC master enable).
 */
typedef struct {
    uint32_t address;
    uint8_t  _pad;
    uint8_t  value;
} io_init_entry_t;
/* const io_init_entry_t io_init_table[132]; @ FW:0x2001C */

/*
 * SCSI Handler Table at FW:0x49834 (21 entries x 10 bytes each)
 */
typedef struct {
    uint8_t  opcode;
    uint8_t  _pad1;
    uint16_t perm_flags;
    void   (*handler)(void);  /* 32-bit function pointer */
    uint8_t  exec_mode;       /* 0=direct, 1=USB setup, 2=data-out, 3=data-in */
    uint8_t  _pad2;
} scsi_handler_entry_t;
/* const scsi_handler_entry_t scsi_table[21]; @ FW:0x49834 */

/*
 * Internal Task Table at FW:0x49910 (97 entries x 4 bytes each)
 */
typedef struct {
    uint16_t task_code;
    uint16_t handler_index;
} task_entry_t;
/* const task_entry_t task_table[97]; @ FW:0x49910 */

/*
 * Speed Ramp Table at FW:0x16C38 (33 entries x 16-bit)
 * Linear ramp from 56 to 312, step 8.
 * These are timer compare values: smaller = faster stepping.
 */
static const uint16_t speed_ramp_linear[33] = {
     56,  64,  72,  80,  88,  96, 104, 112, 120, 128,
    136, 144, 152, 160, 168, 176, 184, 192, 200, 208,
    216, 224, 232, 240, 248, 256, 264, 272, 280, 288,
    296, 304, 312
};
/* Additional variant ramp tables at FW:0x0459D2+ for different adapters/resolutions */

/*
 * Stepper Motor Phase Tables — unipolar 4-phase wave drive
 */
static const uint8_t stepper_phase_fwd[4] = { 0x01, 0x02, 0x04, 0x08 }; /* FW:0x16E92 */
static const uint8_t stepper_phase_rev[4] = { 0x08, 0x04, 0x02, 0x01 }; /* FW:0x4A8A8 */
/* Each step activates exactly one coil (wave drive / single-phase excitation).
 * Step sequence: Phase_A -> Phase_B -> Phase_/A -> Phase_/B */

/*
 * CCD Channel Remap Table at FW:0x4A520 (48 entries)
 * 6-entry repeating: {04, 01, 02, 03, 05, 00} x 8
 * Maps physical CCD channels to logical color channels.
 */

/*
 * CCD Characterization Data at FW:0x4A8BC-0x528BD (~32KB)
 * Factory-programmed analog correction levels (0x00-0x0B).
 * Two sections, each 16,385 bytes with 4095 groups x 4 bytes.
 * Pointer table at FW:0x4A37E.
 */

/*
 * READ DTC Table at FW:0x49AD8 (15 entries x 12 bytes)
 * WRITE DTC Table at FW:0x49B98 (7 entries x 10 bytes)
 * Vendor Register Table at FW:0x4A134 (23 entries x 2 bytes)
 */


/* ======================================================================
 * SECTION 4: INTERRUPT HANDLERS (All 15 Active Vectors)
 * ======================================================================
 *
 * Vector Table (0x000000-0x0000FF): 64 x 32-bit entries.
 * Active handlers use RAM trampolines (4-byte JMP instructions in on-chip RAM).
 * The trampoline architecture allows runtime modification of ISR targets.
 *
 * All 49 inactive vectors point to 0x000186 (default: tight loop).
 */

/* --- Vec 0: Reset (0x000100) --- */
/* See Section 11: Boot & Initialization */

/* --- Vec 7: NMI (0x000182) --- */
void __attribute__((interrupt)) isr_nmi(void)  /* FW:0x000182 */
{
    /* Non-maskable interrupt: infinite loop (halt on fatal error) */
    for (;;) ;
}

/* --- Vec 8: TRAP #0 — Context Switch (0x010876) --- */
/*
 * Cooperative yield mechanism. The TRAPA #0 instruction pushes CCR+PC
 * onto the current stack, then vectors here.
 *
 * Trampoline: 0xFFFD10 -> JMP @0x010876
 * Called via yield stub at FW:0x0109E2: { TRAPA #0; RTS }
 */
void __attribute__((interrupt)) isr_trap0_context_switch(void)  /* FW:0x010876 */
{
    /* Save all registers of yielding context onto its stack */
    /* (push ER0-ER6 = 7 x 4 bytes = 28 bytes) */
    ENABLE_INTERRUPTS();

    /* Reset watchdog */
    WDT_TCSR = 0x5A00;

    /* Check boot flag and bank select for validity */
    uint8_t bflag = *(volatile uint8_t *)0x400772;
    uint8_t bsel  = *(volatile uint8_t *)0x004001;

    DISABLE_INTERRUPTS();

    /* Swap stack pointers between contexts */
    uint16_t ctx_state = *(volatile uint16_t *)0x400764;
    /* Toggle ctx_state between 0 and 1 */
    /* Save current SP to ctx_sp_save[old_ctx] */
    /* Load SP from ctx_sp_save[new_ctx] */
    *(volatile uint16_t *)0x400764 = ctx_state ^ 1;

    ENABLE_INTERRUPTS();

    /* Restore all registers of resumed context (pop ER0-ER6) */
    /* RTE: atomically pops CCR+PC from new context's stack,
     * resuming the other coroutine exactly where it yielded. */
}

/* --- Vec 13: IRQ1 — ISP1581 USB Interrupt (0x014E00) --- */
/*
 * Trampoline: 0xFFFD3C -> JMP @0x014E00
 * Fires when USB data arrives or bus events occur.
 */
void __attribute__((interrupt)) isr_irq1_usb(void)  /* FW:0x014E00 */
{
    uint16_t int_status = ISP_INT_STATUS;

    if (int_status & (1 << 3)) {
        /* Endpoint event: CDB data arrived on bulk-out */
        /* Read CDB bytes from ISP1581 data register */
        usb_endpoint_read(cdb_buffer, 16);  /* FW:0x012258 */

        /* Extract SCSI opcode */
        scsi_opcode = cdb_buffer[0];
        /* Set command pending flag for main loop */
        cmd_pending = 1;
    }

    if (int_status & (1 << 0)) {
        /* USB bus reset detected */
        usb_reset_flag = 1;
    }

    /* Clear handled interrupt bits */
    ISP_INT_STATUS = int_status;
    /* RTE at FW:0x014EA4 */
}

/* --- Vec 15: IRQ3 — Motor Encoder Pulse (0x033444) --- */
/*
 * Trampoline: 0xFFFD14 -> JMP @0x033444
 * External interrupt from optical encoder on motor shaft.
 * Provides position counting and speed measurement.
 */
void __attribute__((interrupt)) isr_irq3_encoder(void)  /* FW:0x033444 */
{
    /* Increment encoder pulse count */
    encoder_count++;                           /* 0x40530E */

    /* Measure inter-pulse timing for speed feedback */
    uint16_t current_timer = *(volatile uint16_t *)0x400770;
    uint16_t delta = current_timer - encoder_last_capture;
    encoder_delta = delta;                     /* 0x405314: speed measurement */

    /* Record timestamp of this event */
    encoder_timestamp = system_timestamp;      /* copy 0x40076E -> 0x405318 */

    /* Check for special processing mode */
    if (encoder_state == 0xD1) {               /* 0x40530A */
        encoder_special_processing();          /* BSR 0x033A0C */
    }

    /* RTE at FW:0x033492 */
}

/* --- Vec 16/17: IRQ4/IRQ5 — External Interrupt (0x014D4A) --- */
/*
 * Trampoline: 0xFFFD18 -> JMP @0x014D4A
 * Shared handler for two external interrupts.
 * Likely adapter detection or hardware status monitoring.
 */
void __attribute__((interrupt)) isr_irq4_irq5_shared(void)  /* FW:0x014D4A */
{
    /* Shared external interrupt handling */
    /* ... hardware status check ... */
    /* RTE at FW:0x014DFE */
}

/* --- Vec 19: IRQ7 — Motor Step Completion / Scan Segment Init (0x02B544) --- */
/*
 * Trampoline: 0xFFFD38 -> JMP @0x02B544
 * 392 bytes. Fires on limit switch or auxiliary encoder event.
 * Integrates encoder data and initiates motor operations.
 */
void __attribute__((interrupt)) isr_irq7_motor_complete(void)  /* FW:0x02B544 */
{
    /* Read I/O register (8-bit timer counter) */
    uint8_t timer_val = *(volatile uint8_t *)0xFFFF3C;

    /* Clear motor state variables */
    motor_accel_index = 0;                  /* 0x4052E8 */
    motor_state = 0;                        /* 0x4052EC */
    motor_direction2 = 0;                   /* 0x4052ED */

    /* Read motor enable status */
    if (motor_enable_flag) {                /* 0x4052EA */
        /* Set task code for motor positioning */
        task_code = 0x0310;                 /* 0x400778 */

        /* Initialize scan config variables */
        /* ... writes to 0x400E9x range ... */
        /* ... calibration values to 0x400B8A, 0x400B8C ... */

        /* Call motor_setup to begin next movement */
        motor_setup();                      /* FW:0x02E158 */
    }

    /* RTE at FW:0x02B6CC */
}

/* --- Vec 32: IMIA2 (ITU2 Compare A) — Motor Mode Dispatcher (0x010B76) --- */
/*
 * Trampoline: 0xFFFD1C -> JMP @0x010B76
 * THE motor interrupt. Fired by ITU2 compare match on each motor step.
 * Reads motor_mode and dispatches to the appropriate handler.
 * Started/stopped per motor movement (11 start / 15 stop sites).
 */
void __attribute__((interrupt)) isr_itu2_motor_dispatch(void)  /* FW:0x010B76 */
{
    uint8_t mode = motor_mode;              /* 0x400774 */

    switch (mode) {
    case 2:
        motor_scan_step();                  /* FW:0x02E268: scan motor step */
        break;
    case 3:
        motor_af_step();                    /* FW:0x02EDC0: AF motor step */
        break;
    case 4:
        motor_encoder_special();            /* FW:0x03337E: encoder/special */
        break;
    case 6:
        motor_scan_step_alt();              /* FW:0x02E276: alt scan (reverse?) */
        break;
    default:
        /* No-op: spurious or uninitialized mode */
        break;
    }

    /* RTE at FW:0x010BCC */
}

/* --- Vec 36: IMIA3 (ITU3 Compare A) — DMA Burst Coordinator (0x02D536) --- */
/*
 * Trampoline: 0xFFFD20 -> JMP @0x02D536
 * Manages CCD line DMA completion via burst counting.
 * NOT a DMA completion interrupt itself; coordinates timer-based DMA.
 */
void __attribute__((interrupt)) isr_itu3_dma_coordinator(void)  /* FW:0x02D536 */
{
    /* Clear DMA channel 0 interrupt flag */
    DTCR &= ~(1 << 0);

    /* Decrement burst counter */
    dma_burst_counter--;                    /* 0x406374 */

    if (dma_burst_counter != 0) {
        return; /* More bursts remaining for this scan line */
    }

    /* Full CCD line transfer complete — dispatch by mode */
    uint8_t mode = scan_mode_dma;           /* 0x4052D6 */

    switch (mode) {
    case 1:
        /* Scan line callback: process completed line */
        scan_line_callback();               /* FW:0x2CEB2 */
        break;
    case 2:
        /* Set state 3 (buffer full), trigger next DMA */
        motor_error_flag = 3;               /* 0x4052EE = 3 (buffer full) */
        /* Re-trigger ASIC DMA for next line */
        break;
    case 6:
        /* Cleanup after scan completes */
        scan_dma_cleanup();                 /* FW:0x2D4B2 */
        break;
    }

    /* RTE at FW:0x02D596 */
}

/* --- Vec 40: IMIA4 (ITU4 Compare A) — System Tick Timer (0x010A16) --- */
/*
 * Trampoline: 0xFFFD24 -> JMP @0x010A16
 * Started ONCE at init (BSET #4, TSTR at FW:0x010A10), never stopped.
 * Global timestamp + periodic USB transfer polling.
 */
void __attribute__((interrupt)) isr_itu4_system_tick(void)  /* FW:0x010A16 */
{
    /* Clear ITU4 compare match flag */
    uint8_t tsr = TSR4;
    TSR4 = tsr & ~(1 << 0);

    /* Increment global timestamp */
    system_timestamp++;                     /* 0x40076E (32-bit) */

    /* --- USB transfer polling (pull model) --- */
    if (xfer_state != 0) {                  /* 0x4062E6 */
        /* Active transfer: continue it */
        usb_continue_transfer();
        return;
    }

    /* Check for new scan data ready */
    uint8_t cmd_st = adapter_type_gpio;     /* 0x400773 */

    if (cmd_st == 0x04) {
        /* Scan data ready: check buffer status */
        if (motor_error_flag == 3) {        /* 0x4052EE == 3: buffer full */
            transfer_scan_data();           /* FW:0x10B3E */
        }
    } else if (cmd_st == 0x05) {
        /* Calibration data ready */
        if (motor_error_flag == 3) {
            transfer_scan_data();
        }
    }

    /* RTE at FW:0x010ABA */
}

/* --- Vec 45: DEND0B — DMA Channel 0B Transfer End (0x02CEF2) --- */
/*
 * Trampoline: 0xFFFD28 -> JMP @0x02CEF2
 * Hardware DMA completion for channel 0B.
 */
void __attribute__((interrupt)) isr_dma_ch0b_end(void)  /* FW:0x02CEF2 */
{
    /* Clear DEND0B flag (bit 3 of DTCR at 0xFFFF2F) */
    DTCR &= ~(1 << 3);

    /* Access scan state variables */
    uint8_t mode = scan_mode_dma;           /* 0x4052D6 */
    /* ... update 0x4064E8, 0x406338 ... */

    /* Signal DMA completion to pipeline */
}

/* --- Vec 47: DEND1B — DMA Channel 1B Transfer End (0x02E10A) --- */
/*
 * Trampoline: 0xFFFD2C -> JMP @0x02E10A
 * Hardware DMA completion for channel 1B.
 */
void __attribute__((interrupt)) isr_dma_ch1b_end(void)  /* FW:0x02E10A */
{
    /* Access motor/scan state */
    /* ... reads 0x4052E4-0x4052EB (motor target, speed, enable) ... */

    /* RTE at FW:0x02E156 */
}

/* --- Vec 49: Timer/CCD — CCD Line Readout (0x02E9F8) --- */
/*
 * Trampoline: 0xFFFD30 -> JMP @0x02E9F8
 * H8/3003-specific timer interrupt managing CCD line readout timing.
 * Coordinates ASIC DMA-to-USB pipeline during active scanning.
 */
void __attribute__((interrupt)) isr_ccd_line_readout(void)  /* FW:0x02E9F8 */
{
    /* Read 8-bit timer register */
    uint8_t timer = *(volatile uint8_t *)0xFFFF4C;

    /* Trigger ASIC DMA for next CCD line */
    ASIC_MASTER_CTRL = 0x02;               /* DMA trigger */
    ASIC_LINE_CTRL = 0x80;                 /* CCD timing trigger */

    /* Update pixel transfer state */
    if (scan_active_flag) {                 /* 0x4052F1 */
        /* Read pixel/line descriptors */
        /* ... 0x405284, 0x405288, 0x4058FC, 0x4062DC, 0x406DB6 ... */

        /* Manage scan line counter and DMA pipeline */
        line_counter--;                     /* 0x4064E6 */
    }

    /* RTE */
}

/* --- Vec 60: ADI — A/D Conversion Complete (0x02EDDE) --- */
/*
 * Trampoline: 0xFFFD34 -> JMP @0x02EDDE
 * Fires when A/D conversion is done (ADCSR bit 7 = ADF).
 * Used for analog measurements (lamp intensity, CCD temperature, etc.).
 */
void __attribute__((interrupt)) isr_adc_complete(void)  /* FW:0x02EDDE */
{
    /* Test ADF flag (ADCSR bit 7) */
    if (ADCSR & 0x80) {
        /* Read A/D result */
        uint16_t adc_value = ADDRA;

        /* Clear ADF flag */
        ADCSR &= ~0x80;

        /* Store result for calibration or lamp monitoring */
        /* ... */
    }

    /* RTE at FW:0x02EE94 */
}


/* ======================================================================
 * SECTION 5: MOTOR CONTROL SUBSYSTEM
 * ====================================================================== */

/*
 * Two stepper motors:
 *   SCAN Motor — drives scanning carriage along the film strip
 *   AF Motor   — positions autofocus lens
 *
 * Both use timer-interrupt-based stepper sequences with acceleration ramps.
 * Unipolar 4-phase wave drive (single-phase excitation), full-step mode.
 *
 * Autofocus is HOST-DRIVEN: firmware provides only basic positioning.
 * The contrast-based AF algorithm runs entirely in NikonScan on the host.
 */

/*
 * Motor timer setup and movement start.
 * FW:0x02E158
 *
 * Configures ITU2 timer and initiates a motor movement.
 * Called from IRQ7 handler, task dispatch, and SCSI command handlers.
 */
void motor_setup(void)  /* FW:0x02E158 */
{
    /* Step 1: Enable motor */
    motor_enable_flag = 1;                  /* 0x4052EA */

    /* Step 2: Clear ITU1 compare register (stop position feedback) */
    GRA1 = 0;

    /* Step 3: Stop ITU1 */
    TSTR &= ~(1 << 1);                     /* BCLR #1, TSTR */

    /* Step 4: Load ramp configuration */
    uint16_t ramp_cfg = motor_ramp_config;  /* 0x400CC8 */

    /* Step 5: Calculate initial timer period */
    uint32_t period;
    period = math_multiply(ramp_cfg, 1000000);  /* jsr @0x0163EA */
    period = math_divide(period, 640);          /* jsr @0x015CCC */

    /* Step 6: Load timer counter */
    TCNT3 = (uint16_t)period;

    /* Step 7: Set motor direction */
    gpio_shadow = /* direction value */0;   /* 0x400791 */

    /* Step 8: Configure compare register for step timing */
    GRB2 = (uint16_t)period;

    /* Step 9: Set motor mode for ITU2 dispatcher */
    /* Mode: 2=scan, 3=AF, 4=encoder, 6=alt scan */
    motor_mode = 2;                         /* 0x400774 (example: scan) */

    /* Step 10: Configure interrupt enable */
    TIER3 = /* enable compare match A */ 0x01;

    /* Step 11: START ITU2 — motor begins stepping */
    TSTR |= (1 << 2);                      /* BSET #2, TSTR */
}

/*
 * Motor stop.
 * Called when motor reaches target position or on abort.
 */
void motor_stop(void)
{
    /* Stop ITU2 */
    TSTR &= ~(1 << 2);                     /* BCLR #2, TSTR */

    motor_running_flag = 0;                 /* 0x4052EB */
    motor_enable_flag = 0;                  /* 0x4052EA */

    /* De-energize motor coils */
    PORT_A_DR = 0x00;
}

/*
 * Scan motor step handler (mode 2).
 * FW:0x02E268
 *
 * Called from ITU2 ISR when motor_mode == 2.
 * Drives one step of the scan carriage motor.
 */
void motor_scan_step(void)  /* FW:0x02E268 */
{
    /* Call main motor step engine */
    motor_step_engine(MOTOR_SCAN);          /* FW:0x02DEEE */
}

/*
 * Alternative scan motor step handler (mode 6).
 * FW:0x02E276
 *
 * Possibly reverse direction scanning.
 */
void motor_scan_step_alt(void)  /* FW:0x02E276 */
{
    motor_step_engine(MOTOR_SCAN_REVERSE);  /* FW:0x02DEEE */
}

/*
 * AF motor step handler (mode 3).
 * FW:0x02EDC0
 *
 * Drives one step of the autofocus motor.
 */
void motor_af_step(void)  /* FW:0x02EDC0 */
{
    motor_step_engine(MOTOR_AF);            /* FW:0x02DEEE */
}

/*
 * Main motor step engine — core of all stepper motor movement.
 * FW:0x02DEEE
 *
 * Implements acceleration/deceleration ramp profiles.
 * Updates step position, applies phase output, reloads timer.
 */
#define MOTOR_SCAN         0
#define MOTOR_SCAN_REVERSE 1
#define MOTOR_AF           2

void motor_step_engine(int motor_id)  /* FW:0x02DEEE */
{
    /* Read current state */
    uint16_t step_pos = motor_step_count;     /* 0x4052E2 */
    uint16_t target   = motor_target_pos;     /* 0x4052E4 */
    uint16_t accel_idx = motor_accel_index;   /* 0x4052E8 */
    uint8_t  direction = motor_direction2;    /* 0x4052ED */
    uint8_t  state     = motor_state;         /* 0x4052EC */

    /* Calculate remaining distance */
    uint16_t remaining = (direction == 0) ?
                         (target - step_pos) :
                         (step_pos - target);

    if (remaining == 0) {
        /* At target: stop motor */
        motor_stop();
        motor_error_flag = 0;               /* 0x4052EE: clear error/done flag */
        return;
    }

    /* --- Acceleration / Deceleration Ramp --- */
    uint16_t timer_period;

    /* Deceleration zone: remaining steps < ramp table entries used */
    if (remaining <= accel_idx) {
        /* Decelerate: traverse ramp table forward (higher values = slower) */
        accel_idx--;
        timer_period = speed_ramp_linear[accel_idx]; /* FW:0x16C38 */
        state = 2; /* decelerating */
    }
    /* Acceleration zone: haven't reached cruise speed yet */
    else if (accel_idx < 32 && state == 0) {
        accel_idx++;
        timer_period = speed_ramp_linear[32 - accel_idx]; /* reverse traverse */
        if (accel_idx >= 32) {
            state = 1; /* cruising */
        }
    }
    /* Cruise: maintain constant speed */
    else {
        timer_period = motor_current_speed;   /* 0x4052E6 */
    }

    /* --- Output Stepper Phase --- */
    const uint8_t *phase_table;
    if (direction == 0) {
        phase_table = stepper_phase_fwd;      /* FW:0x16E92: 01 02 04 08 */
    } else {
        phase_table = stepper_phase_rev;      /* FW:0x4A8A8: 08 04 02 01 */
    }
    uint8_t phase_idx = step_pos & 0x03;      /* 4-step cycle */
    PORT_A_DR = phase_table[phase_idx];        /* Write to Port A (motor output) */

    /* --- Update Position --- */
    if (direction == 0) {
        step_pos++;
    } else {
        step_pos--;
    }

    /* --- Reload Timer for Next Step --- */
    GRB2 = timer_period;
    /* ITU2 will fire again after this many timer ticks */

    /* --- Store Updated State --- */
    motor_step_count  = step_pos;
    motor_accel_index = accel_idx;
    motor_current_speed = timer_period;
    motor_state = state;

    /* Restart ITU2 if movement not complete */
    TSTR |= (1 << 2);                       /* BSET #2, TSTR */
}

/*
 * Encoder special processing handler (mode 4).
 * FW:0x03337E
 *
 * Called from ITU2 ISR for encoder-related operations.
 * Used during homing or precision positioning.
 */
void motor_encoder_special(void)  /* FW:0x03337E */
{
    /* Read encoder count for position determination */
    uint16_t enc = encoder_count;            /* 0x40530E */

    /* Compare against reference position for home detection */
    /* ... */

    /* Update motor state based on encoder feedback */
}

/*
 * ASIC motor register configuration.
 * FW:0x035600
 *
 * Programs the custom ASIC motor drive registers.
 * The ASIC acts as an intermediary between CPU timer-driven steps
 * and the actual motor driver hardware.
 */
void asic_motor_configure(void)  /* FW:0x035600 */
{
    /* Configure motor drive group A (0x200182-0x200189) */
    ASIC_MOTOR_CFG = 0x0D;

    /* Write 4 register pairs for coil drive signals */
    for (int i = 0; i < 8; i++) {
        ASIC_MOTOR_A_BASE[i] = /* drive signal values */0;
    }

    /* Configure motor drive group B (0x200194-0x20019B) */
    ASIC_MOTOR_CFG_B = 0x0E;
    for (int i = 0; i < 8; i++) {
        ASIC_MOTOR_B_BASE[i] = /* drive signal values */0;
    }

    /* Auxiliary motor config */
    ASIC_MOTOR_AUX_A = /* config */0;
    ASIC_MOTOR_AUX_B = /* config */0;
    ASIC_MOTOR_AUX_C = /* config */0;
}

/*
 * Motor home / reference position seek.
 * Task code 0x0430, handler index 0x002C.
 *
 * Drives motor until home sensor (limit switch on IRQ7) is triggered.
 */
void motor_home(void)
{
    /* Set mode for reverse direction */
    motor_mode = 6;                          /* Alt scan motor (reverse) */
    motor_direction2 = 1;                    /* Reverse direction */

    /* Set target far beyond actual range to ensure home sensor fires */
    motor_target_pos = 0xFFFF;

    /* Start motor — IRQ7 will fire when limit switch is hit */
    motor_setup();

    /* The IRQ7 handler (0x02B544) will stop the motor and
     * set task_code = 0x0310 for fine positioning */
}

/*
 * Motor relative move.
 * Task code 0x0440, handler index 0x002B.
 */
void motor_move_relative(int16_t steps)
{
    if (steps >= 0) {
        motor_direction2 = 0;               /* Forward */
        motor_target_pos = motor_step_count + steps;
    } else {
        motor_direction2 = 1;               /* Reverse */
        motor_target_pos = motor_step_count + steps; /* steps is negative */
    }

    motor_mode = 2;                          /* Scan motor mode */
    motor_setup();
}

/*
 * Motor absolute move.
 * Task code 0x0450, handler index 0x007F.
 */
void motor_move_absolute(uint16_t position)
{
    if (position > motor_step_count) {
        motor_direction2 = 0;
        motor_target_pos = position;
    } else if (position < motor_step_count) {
        motor_direction2 = 1;
        motor_target_pos = position;
    } else {
        return; /* Already at position */
    }

    motor_mode = 2;
    motor_setup();
}

/*
 * Motor stop/reset.
 * Task code 0x0400, handler index 0x0030.
 */
void motor_stop_reset(void)
{
    motor_stop();
    motor_step_count = 0;
    motor_target_pos = 0;
    motor_accel_index = 0;
    motor_state = 0;
    motor_error_flag = 0;
}


/* ======================================================================
 * SECTION 6: CCD / ASIC CONTROL
 * ====================================================================== */

/*
 * CCD timing and readout configuration.
 * FW:0x03C274
 *
 * Configures CCD integration timing through ASIC line timing registers.
 */
void ccd_timing_configure(uint16_t exposure_us, uint8_t n_channels)
{
    /* Set CCD line timing mode */
    ASIC_LINE_MODE = 0x03;

    /* Pixel clock divider */
    ASIC_PIXEL_CLK = 0x0F;

    /* Line period (determines scan speed) */
    uint16_t line_period = exposure_us; /* computed from resolution */
    ASIC_LINE_PER_LO = line_period & 0xFF;
    ASIC_LINE_PER_HI = (line_period >> 8) & 0xFF;

    /* Integration window (CCD charge accumulation time) */
    ASIC_INT_START = 0x19;
    ASIC_INT_CFG   = 0x0F;
    ASIC_INT_END   = 0x69;

    /* Readout timing */
    ASIC_RD_START = 0x00;
    ASIC_RD_CFG   = 0x18;

    /* Per-channel timing (R/G/B/IR) */
    /* Each channel: offset=0x00, start=0x01, end=0x2B */
    for (int ch = 0; ch < 4; ch++) {
        volatile uint8_t *base;
        switch (ch) {
            case 0: base = ASIC_CH_RED_BASE; break;
            case 1: base = ASIC_CH_GREEN_BASE; break;
            case 2: base = ASIC_CH_BLUE_BASE; break;
            case 3: base = ASIC_CH_IR_BASE; break;
        }
        base[0] = 0x00; /* offset */
        base[1] = 0x01; /* start */
        base[2] = 0x2B; /* end */
    }
}

/*
 * CCD line-by-line scan readout.
 * Part of the scan pipeline at FW:0x36C90-0x37A8C.
 *
 * Reads 16-bit CCD data from ASIC RAM, extracts significant bits,
 * processes in blocks, writes to Buffer RAM for USB transfer.
 *
 * The CCD produces 14-bit data packed in 16-bit words.
 * Firmware does MINIMAL processing: only bit extraction.
 * All real image processing happens host-side in NikonScan.
 */
void ccd_pixel_process(uint8_t channel)  /* FW:0x36C90 */
{
    volatile uint16_t *src = (volatile uint16_t *)ASIC_RAM_BASE;
    volatile uint16_t *dst = (volatile uint16_t *)BUFFER_RAM_BANK_A;

    /* Channel descriptor: 757 pixels start, 665 pixel count */
    uint16_t pixel_start = 0x02F5; /* 757: CCD line offset */
    uint16_t pixel_count = 0x0299; /* 665: active pixel count */

    /* Adjust source for channel (tri-linear CCD + IR) */
    src += channel * pixel_start;

    /* Process in blocks with yield between blocks */
    uint16_t remaining = pixel_count;
    while (remaining > 0) {
        uint16_t block_size = (remaining > 4096) ? 4096 : remaining;

        for (uint16_t i = 0; i < block_size; i++) {
            uint16_t raw = *src++;

            /* Extract 14-bit data from 16-bit CCD word */
            /* shlr.w: shift right to remove padding bits */
            uint16_t pixel = raw >> 2;  /* 14-bit -> right-aligned */

            *dst++ = pixel;
        }

        remaining -= block_size;

        /* Yield between blocks to allow USB/timer servicing */
        yield();  /* jsr @0x0109E2 (TRAPA #0) */
    }
}

/*
 * Multi-sampling (multiple CCD exposures averaged).
 * Part of the scan state machine, groups 7-8 (multi-pass scan).
 * FW:0x42E2A (F8: Multi-pass scan orchestrator, 3790 bytes)
 *
 * Multiple CCD exposures per line improve dynamic range.
 * Complex interleaving of: capture, USB transfer, re-calibration.
 */
void ccd_multipass_scan(int n_passes)
{
    for (int pass = 0; pass < n_passes; pass++) {
        /* Configure ASIC timing for this pass */
        asic_timing_setup();                /* FW:0x3718A */

        /* Perform calibration between passes if needed */
        if (pass > 0) {
            calibration_interpass();        /* FW:0x39C6C, 0x39E0C, 0x3A00E */
        }

        /* Capture one CCD line */
        ASIC_MASTER_CTRL = 0x02;            /* Trigger DMA */
        while (ASIC_STATUS & 0x08) {        /* Poll DMA busy bit 3 */
            yield();
        }
        ASIC_MASTER_CTRL = 0xC0;            /* DMA acknowledge */

        /* Transfer to Buffer RAM via USB pipeline */
        usb_transfer_setup();               /* FW:0x12360, 0x12398 */
    }

    /* Average samples (done host-side by NikonScan) */
}

/*
 * Analog gain setting.
 * The ASIC analog front-end has per-channel gain control.
 * Registers 0x200457/0x200458 are set ONCE at init (value 99 = 0x63).
 * Runtime gain adjustment uses 0x200142/0x200152 during calibration.
 */
void ccd_set_analog_gain(uint8_t ch1_gain, uint8_t ch2_gain)
{
    /* These are written only during I/O init table processing */
    ASIC_GAIN_MODE = 0x00;
    ASIC_GAIN_CH1  = ch1_gain;  /* Default: 99 (0x63) */
    ASIC_GAIN_CH2  = ch2_gain;  /* Default: 99 (0x63) */
}

/*
 * IR LED switching for Digital ICE.
 * The CCD has a 4th channel for infrared detection.
 * Channel 3 (IR) at ASIC register 0x200485 is configured
 * identically to visible channels but captures the IR signal
 * used by Digital ICE dust/scratch removal on the host.
 *
 * No special IR LED switching in firmware; the IR channel
 * is always active. ICE processing happens entirely in
 * NikonScan (ICEDLL.dll / ICENKNL1.dll).
 */


/* ======================================================================
 * SECTION 7: LAMP CONTROL
 * ====================================================================== */

/*
 * The LS-50 uses a white LED lamp (not fluorescent tube).
 * Controlled via Port 4 DDR bit 0 (open-drain pattern).
 *
 * BCLR #0 @ 0xFF85 = ON  (set to input, external pull-up activates lamp)
 * BSET #0 @ 0xFF85 = OFF (set to output, drives pin low = lamp off)
 *
 * 6 lamp-ON write sites in firmware, all with identical code pattern.
 */

/*
 * Lamp ON.
 * Pattern found at FW:0x2C66A, 0x2D2E8, 0x2D3C2, 0x2D4EE, 0x2D53E, 0x2D670
 */
void lamp_on(void)
{
    /* Write status value */
    *(volatile uint8_t *)0x400791 = PORT_4_DDR;  /* Save GPIO state to shadow */

    /* LAMP ON: clear bit 0 of Port 4 DDR (active-low / open-drain) */
    PORT_4_DDR &= ~(1 << 0);  /* BCLR #0, @0xFF85 */

    /* Clear adjacent port register */
    *(volatile uint16_t *)0xFFFF86 = 0x0000;
}

/*
 * Lamp OFF.
 * Inverse of lamp_on: set bit 0 of Port 4 DDR high.
 */
void lamp_off(void)
{
    PORT_4_DDR |= (1 << 0);   /* BSET #0, @0xFF85 */
}

/*
 * Lamp state machine.
 * FW:0x13C6E — called from C1/0x80 handler.
 */
void lamp_state_machine(void)  /* FW:0x13C6E */
{
    if (lamp_state != 0) {
        return; /* Already active */
    }

    lamp_state = 1;  /* 0x400082 = active */

    /* Configure timer control (BSET on TCSR at 0xFF60) */
    /* Read device status from 0x407DC7 */

    /* Warmup: the LED lamp requires minimal warmup compared to
     * fluorescent tubes used in older scanners. The firmware
     * uses the lamp_state variable to track the warmup period
     * and prevent scanning before the lamp output stabilizes. */
}

/*
 * C1 Subcommand 0x80: Lamp/Exposure Control.
 * FW:0x28BC4
 *
 * Controls lamp state and per-channel exposure parameters.
 * Called from the C1 vendor command dispatch chain.
 */
void c1_lamp_exposure_control(void)  /* FW:0x28BC4 */
{
    /* Initialize lamp state machine */
    lamp_state_machine();                    /* jsr @0x13C6E */

    /* Set lamp active flag */
    lamp_active = 1;                         /* 0x400E5F */

    /* Continue to exposure parameter setup (FW:0x28E10) */

    /* Extract per-channel exposure from CDB:
     *   CDB[0x02-0x05]: Channel 0 (Red) exposure
     *   CDB[0x06-0x09]: Channel 1 (Green) exposure
     *   CDB[0x0A-0x0B]: Channel identifier
     */
    uint32_t red_exp   = (cdb_buffer[2] << 24) | (cdb_buffer[3] << 16) |
                         (cdb_buffer[4] << 8)  | cdb_buffer[5];
    uint32_t green_exp = (cdb_buffer[6] << 24) | (cdb_buffer[7] << 16) |
                         (cdb_buffer[8] << 8)  | cdb_buffer[9];

    /* Gain calculation (DIVXU.B at FW:0x28BE7) */
    /* Division for exposure normalization */
    exposure_R = red_exp;                    /* 0x40077E */
    exposure_G = green_exp;                  /* 0x400782 */

    /* Lamp hardware control via secondary handler table */
    lamp_hw_control();                       /* FW:0x2C46E */
}

/*
 * Lamp hardware control (secondary handler).
 * FW:0x2C46E
 *
 * Called from C1/0x80 via the secondary dispatch table at 0x4A134.
 * Performs the actual GPIO toggle to turn the lamp on/off.
 */
void lamp_hw_control(void)  /* FW:0x2C46E */
{
    lamp_on();
}


/* ======================================================================
 * SECTION 8: CALIBRATION
 * ====================================================================== */

/*
 * Calibration overview:
 *   - Dark frame subtraction: CCD reads with lamp off to measure dark current
 *   - White reference: CCD reads with lamp on to measure illumination uniformity
 *   - Gain/offset adjustment: ASIC DAC registers tuned per-channel
 *
 * ALL pixel-level correction (gamma, LUT, color balance) is HOST-SIDE.
 * Firmware only handles analog front-end calibration.
 *
 * Task codes: 0x0500 (primary), 0x0501 (secondary), 0x0502 (shared)
 */

/*
 * DAC mode register control.
 * FW:0x2000C2
 *
 * The calibration mode gate: setting bit 7 enables calibration readings.
 */
void calibration_set_mode(uint8_t mode)
{
    /* Mode values:
     *   0x20 = init/basic (set during USB bus reset at FW:0x13AD9)
     *   0x22 = normal scanning
     *   0xA2 = calibration (bit 7 = calibration enable)
     */
    ASIC_DAC_MODE = mode;
}

/*
 * Model-specific DAC configuration.
 * FW:0x142AA
 *
 * LS-50 and LS-5000 have different analog front-end characteristics.
 */
void calibration_model_configure(void)  /* FW:0x142AA */
{
    ASIC_MASTER_CTRL = 0x02;               /* ASIC command = configure */
    ASIC_DAC_MODE = 0xA2;                  /* Enter calibration mode */

    if (model_flag == 0) {
        /* LS-50 */
        ASIC_DAC_FINE = 0x08;
        ASIC_DMA_XFER_CFG = 0x64;         /* Coarse gain = 100 */
    } else {
        /* LS-5000 */
        ASIC_DAC_FINE = 0x00;
        ASIC_DMA_XFER_CFG = 0xB4;         /* Coarse gain = 180 */
    }
}

/*
 * Calibration routine 1.
 * FW:0x3D12D
 *
 * All 4 calibration routines follow the same pattern:
 *   1. Enter calibration mode (DAC = 0xA2)
 *   2. Read calibration parameters from RAM
 *   3. Write to ASIC calibration registers
 *   4. Perform calibration scan (read CCD via Buffer RAM)
 *   5. Compute per-channel min/max
 *   6. Update calibration results in RAM
 */
void calibration_routine_1(void)  /* FW:0x3D12D */
{
    /* Step 1: Enter calibration mode */
    ASIC_DAC_MODE = 0xA2;

    /* Step 2: Read calibration parameters from RAM */
    /* Parameters at 0x400F56-0x400F9D (calibration config area) */
    uint8_t cal_param1 = *(volatile uint8_t *)0x400F56;
    uint8_t cal_param2 = *(volatile uint8_t *)0x400F58;

    /* Step 3: Write to ASIC calibration registers */
    ASIC_CAL_CFG1 = cal_param1;            /* 0x2001CA */
    ASIC_CAL_CFG2 = cal_param2;            /* 0x2001CB */
    *(volatile uint8_t *)0x20014E = /* config */0;
    ASIC_COARSE_GAIN2 = /* gain */0;       /* 0x200152 */
    ASIC_FINE_GAIN2 = /* fine */0;         /* 0x200153 */

    /* Step 4: Perform calibration scan (read CCD data via Buffer RAM) */
    /* Ping-pong buffering:
     *   Bank A: 0xC00000 (primary)
     *   Bank B: 0xC08000 (secondary)
     */
    volatile uint16_t *cal_buffer = (volatile uint16_t *)BUFFER_RAM_BANK_A;

    /* Trigger CCD capture with calibration DAC settings */
    ASIC_MASTER_CTRL = 0x02;               /* Trigger DMA */
    while (ASIC_STATUS & 0x08) {           /* Poll DMA busy */
        yield();
    }
    ASIC_MASTER_CTRL = 0xC0;               /* DMA acknowledge */

    /* Step 5: Compute per-channel min/max from CCD data */
    uint16_t min_val = 0xFFFF;
    uint16_t max_val = 0x0000;

    /* Processing limit: 16384 words (32KB), enough for 2 channels x 8192 pixels */
    for (int i = 0; i < 16384; i++) {
        uint16_t pixel = cal_buffer[i];
        if (pixel < min_val) min_val = pixel;
        if (pixel > max_val) max_val = pixel;
    }

    /* Step 6: Update calibration results in RAM */
    *(volatile uint16_t *)0x400F0A = min_val; /* Channel result 1 */
    *(volatile uint16_t *)0x400F12 = max_val; /* Channel result 2 */
}

/*
 * Calibration routines 2-4 follow the same pattern as routine 1.
 *
 * FW:0x3DE51  — Calibration routine 2
 * FW:0x3EEF9  — Calibration routine 3
 * FW:0x3F897  — Calibration routine 4
 *
 * Differences are in which calibration parameters are read/written
 * and which channels are processed.
 */
void calibration_routine_2(void);  /* FW:0x3DE51 */
void calibration_routine_3(void);  /* FW:0x3EEF9 */
void calibration_routine_4(void);  /* FW:0x3F897 */

/*
 * Factory CCD characterization data access.
 * Reads per-CCD-element correction levels from flash.
 *
 * Pointer table at FW:0x4A37E.
 * Data at FW:0x4A8BC-0x528BD (~32KB).
 *
 * 11 distinct correction levels (0x00-0x0B).
 * 4095 groups x 4 bytes per section (4 sub-elements per CCD pixel).
 * Monotonic edge-to-center decay (vignetting compensation).
 *
 * This data is factory-programmed and NEVER modified at runtime.
 * The flash programming routine at FW:0x3A300 only writes to
 * log areas (0x60000, 0x70000).
 */
void read_ccd_correction_table(uint8_t section, uint8_t *output)
{
    /* Read pointer from table at FW:0x4A37E */
    /* Section 0 and 1 point to the same address (0x4A8BC) */
    /* Section 2 points to 0x4E8BD */
    uint32_t ptr;
    switch (section) {
    case 0:
    case 1:
        ptr = 0x0004A8BC;
        break;
    case 2:
        ptr = 0x0004E8BD;
        break;
    }

    volatile uint8_t *data = (volatile uint8_t *)ptr;

    /* Read length header (0x3FFF = 16383 bytes of payload) */
    uint16_t length = (data[0] << 8) | data[1];
    data += 2;

    /* Read correction levels: 4095 groups x 4 bytes */
    for (int group = 0; group < 4095; group++) {
        /* Each group: 4 identical bytes (one per CCD sub-element) */
        /* Values range 0x00 (center, minimal correction) to 0x0B (edge, max) */
        for (int sub = 0; sub < 4; sub++) {
            *output++ = *data++;
        }
    }
}

/*
 * Gain calibration (adapter-type-dependent).
 * Referenced from debug string "GAIN" at FW:0x49EF7.
 * FW:0x26514
 */
void calibration_gain_adjust(void)  /* FW:0x26514 */
{
    /* Load GAIN string pointer indexed by adapter type */
    uint8_t adapter = *(volatile uint8_t *)0x400773;

    if (adapter == 0x02) {
        /* Strip holder: apply specific gain factor */
        uint8_t gain_factor = *(volatile uint8_t *)0x400790;
        /* Compute adjusted gain */
        uint32_t adjusted = math_multiply(gain_factor, /* base */100);
        /* Apply to ASIC */
    }
}

/*
 * Shading correction and dark frame subtraction.
 * These are calibration scan variants that use the same pipeline
 * as normal scanning but with different DAC mode settings.
 *
 * Dark frame: DAC mode 0xA2 with lamp OFF -> measures CCD dark current
 * White ref:  DAC mode 0xA2 with lamp ON  -> measures illumination profile
 *
 * The host subtracts dark from white to get per-pixel gain correction.
 * The firmware just provides the raw CCD data; all math is host-side.
 */
void calibration_dark_frame(void)
{
    lamp_off();
    ASIC_DAC_MODE = 0xA2;                  /* Calibration mode */

    /* Capture dark frame */
    ASIC_MASTER_CTRL = 0x02;
    while (ASIC_STATUS & 0x08) yield();
    ASIC_MASTER_CTRL = 0xC0;

    /* Data available in ASIC RAM for host to read via READ(10) DTC 0x84 */
}

void calibration_white_reference(void)
{
    lamp_on();
    ASIC_DAC_MODE = 0xA2;                  /* Calibration mode */

    /* Wait for lamp to stabilize (LED warmup is fast) */
    /* ... brief delay ... */

    /* Capture white reference frame */
    ASIC_MASTER_CTRL = 0x02;
    while (ASIC_STATUS & 0x08) yield();
    ASIC_MASTER_CTRL = 0xC0;

    /* Data available for host to read */
}


/* ======================================================================
 * SECTION 9: SCAN PIPELINE
 * ====================================================================== */

/*
 * Complete scan data flow:
 *
 *   CCD Sensor (tri-linear R/G/B + IR)
 *       |
 *       v
 *   ASIC Analog Front-End (0x200000)
 *       |  DAC config: 0x2000C0-C7
 *       |  Integration timing: 0x200408-425
 *       |  Per-channel windows: 0x20046D-487
 *       |  Analog gain: 0x200457-458
 *       v
 *   ASIC Internal DMA -> ASIC RAM (0x800000, 224KB)
 *       |  Config: 0x200142-14D
 *       |  Trigger: write 0x80 to 0x2001C1
 *       |  Poll: read 0x200002 bit 3 until clear
 *       |  Ack: write 0xC0 to 0x200001
 *       v
 *   CPU Pixel Processing (FW:0x36C90)
 *       |  Read 16-bit from ASIC RAM
 *       |  shlr.w for 14-bit extraction
 *       |  Process in 4KB-16KB blocks
 *       |  Yield (TRAPA #0) between blocks
 *       v
 *   Buffer RAM (0xC00000, 64KB) — ping-pong banks A/B
 *       v
 *   ISP1581 USB Controller (0x600000)
 *       |  DMA_REG: 0x8000 = host-read
 *       |  DMA config: mode 5 = bulk
 *       v
 *   USB Bulk-In Pipe -> Host PC
 *       (NikonScan reads via NKDUSCAN.dll)
 */

/*
 * ASIC DMA configuration functions.
 */

/* Configure DMA buffer address (24-bit). FW:0x035C7E */
void asic_dma_set_buffer(uint32_t address)  /* FW:0x035C7E */
{
    ASIC_BUF_ADDR_HI  = (address >> 16) & 0xFF;
    ASIC_BUF_ADDR_MID = (address >> 8)  & 0xFF;
    ASIC_BUF_ADDR_LO  = address & 0xFF;
}

/* Read current DMA position, reconfigure. FW:0x035D58 */
void asic_dma_reconfigure(void)  /* FW:0x035D58 */
{
    uint32_t pos = ((uint32_t)ASIC_BUF_ADDR_HI << 16) |
                   ((uint32_t)ASIC_BUF_ADDR_MID << 8) |
                   ASIC_BUF_ADDR_LO;
    /* Reconfigure for next transfer block */
}

/* Set transfer count and trigger DMA. FW:0x035D92 */
void asic_dma_start(uint32_t count)  /* FW:0x035D92 */
{
    ASIC_XFER_CNT_HI  = (count >> 16) & 0xFF;
    ASIC_XFER_CNT_MID = (count >> 8)  & 0xFF;
    ASIC_XFER_CNT_LO  = count & 0xFF;

    /* Trigger DMA */
    ASIC_LINE_CTRL = 0x80;
}

/*
 * Scan line callback — called when a complete CCD line has been DMA'd.
 * FW:0x2CEB2
 *
 * Called from ITU3 ISR (Vec 36) when dma_burst_counter reaches 0.
 */
void scan_line_callback(void)  /* FW:0x2CEB2 */
{
    /* Read scan descriptor */
    uint32_t desc = scan_desc_ptr;          /* 0x406370 */

    /* Update operation type */
    gpio_shadow = /* new op type */0;       /* 0x400791 */

    /* Clear/reset DMA status */
    /* Re-trigger ASIC DMA for next line */
    ASIC_MASTER_CTRL = 0x02;                /* BSET #0, @er6 */

    /* Signal buffer full when ready */
    motor_error_flag = 3;                   /* 0x4052EE = 3 (buffer full) */
}

/*
 * Transfer scan data to USB.
 * FW:0x10B3E
 *
 * Called from ITU4 system tick ISR when scan data is ready.
 * Dispatches by transfer mode.
 */
void transfer_scan_data(void)  /* FW:0x10B3E */
{
    /* Dispatch by current transfer mode (reuses motor mode codes) */
    uint8_t mode = motor_mode;              /* 0x400774 */
    switch (mode) {
    case 2:
        /* Block transfer */
        break;
    case 3:
        /* Streaming transfer */
        break;
    case 4:
        /* Scan line transfer (pixel processing) */
        break;
    case 6:
        /* Calibration transfer */
        break;
    }
}

/*
 * SCAN handler — SCSI opcode 0x1B.
 * FW:0x0220B8, ~1800 bytes.
 *
 * Initiates a scan operation based on CDB parameters.
 * This is the most complex standard SCSI command handler.
 */
void scsi_scan_handler(void)  /* FW:0x0220B8 */
{
    /* Validate CDB: bytes 2-5 must be zero */
    if (cdb_buffer[2] | cdb_buffer[3] | cdb_buffer[4] | cdb_buffer[5]) {
        sense_code = 0x0050; /* Invalid CDB field */
        return;
    }

    /* Extract scan operation code from CDB */
    uint8_t operation = cdb_buffer[4]; /* Operation type:
                                        * 0 = Preview scan
                                        * 1 = Fine scan (single pass)
                                        * 2 = Fine scan (multi-pass)
                                        * 3 = Calibration scan
                                        * 4 = Move to position
                                        * 9 = Eject film */

    if (operation > 4 && operation != 9) {
        sense_code = 0x0053; /* Invalid parameter */
        return;
    }

    /* Set up USB response */
    usb_response_manager(2);                /* FW:0x1374A with exec mode 2 */

    /* Mark scan active */
    *(volatile uint8_t *)0x400D43 = 1;      /* scan operation active */

    /* Dispatch to scan state machine */
    /* The scan state machine at FW:0x40000-0x45300 handles the rest */

    /* Adapter-specific entry points: */
    /* Strip  (0x08): FW:0x40630 */
    /* Mount  (0x04): FW:0x4063C */
    /* 240    (0x20): FW:0x40648 */
    /* Feeder (0x40): FW:0x40654 */
}

/*
 * SCAN handler — inner scan loop (pre-function state machine).
 * FW:0x40000-0x40317 (792 bytes).
 *
 * Processes each CCD line during an active scan.
 * This is inline code, not a function (no push/pop context frame).
 */
void scan_inner_loop(void)  /* FW:0x40000 */
{
    while (1) {
        /* Read scan descriptor */
        uint16_t desc = *(volatile uint16_t *)0x406E6A;

        /* Configure next scan line via ASIC */
        asic_configure_line();              /* FW:0x35A9A */

        /* Check task state for motor operations */
        uint16_t ts = task_code;            /* 0x400778 */

        switch (ts) {
        case 0x0300: /* Absolute motor positioning */
        case 0x0310: /* Relative motor positioning */
            /* Wait for motor to reach position, yield */
            yield();
            continue;

        case 0x0320: /* Scan direction set */
            /* Update scan direction parameter */
            break;

        case 0x0330: /* Scan buffer stall */
            /* Wait for USB to drain buffer, yield */
            yield();
            continue;
        }

        /* Check scan active flag */
        if (!(scanner_state_flags & 0x80)) { /* bit 7 */
            break; /* Scan cancelled */
        }

        /* Trigger ASIC DMA for this CCD line */
        ASIC_MASTER_CTRL = 0x02;
        while (ASIC_STATUS & 0x08) {        /* Poll DMA busy (bit 3) */
            yield();
        }

        /* Process pixels */
        ccd_pixel_process(/* current channel */0);  /* FW:0x40318 (F1) */

        /* Update scan status */
        scan_status_byte = /* new status */0;  /* 0x4052EF */
        scan_active_flag = 1;                  /* 0x4052F1 */

        /* Check if all lines scanned */
        if (line_counter == 0) {
            break;
        }
    }
}

/*
 * Scan entry point — adapter-specific dispatch.
 * FW:0x40630-0x4065C (4 entries x 12 bytes each)
 *
 * Each entry: F12 (common init) -> mode setup -> F2 (orchestrator)
 */
void scan_entry_strip(void)   /* FW:0x40630, adapter_type=0x08 */
{
    scan_common_init();                     /* F12: FW:0x044E40 */
    scan_mode_strip_setup();                /* FW:0x04536E */
    scan_orchestrator();                    /* F2:  FW:0x040660 (tail call) */
}

void scan_entry_mount(void)   /* FW:0x4063C, adapter_type=0x04 */
{
    scan_common_init();
    scan_mode_mount_setup();                /* FW:0x045390 */
    scan_orchestrator();
}

void scan_entry_240(void)     /* FW:0x40648, adapter_type=0x20 */
{
    scan_common_init();
    scan_mode_240_setup();                  /* FW:0x0453CA */
    scan_orchestrator();
}

void scan_entry_feeder(void)  /* FW:0x40654, adapter_type=0x40 */
{
    scan_common_init();
    scan_mode_feeder_setup();               /* FW:0x0453D6 */
    scan_orchestrator();
}

/*
 * Scan orchestrator (F2).
 * FW:0x040660-0x0408FD (670 bytes).
 *
 * Central coordinator: sequences the scan operation by calling
 * F3 (config), F4 (DMA setup), F5 (pixel transfer), F6 (resolution).
 */
void scan_orchestrator(void)  /* FW:0x040660 */
{
    /* Calibration loop: iterate until calibration stabilizes */
    while (!calibration_stable()) {         /* FW:0x039C6C */
        calibration_iterate();              /* FW:0x039C8A */
    }

    /* Check command state */
    uint8_t cs = adapter_type_gpio;         /* 0x400773 */

    if (cs == 0x01 || cs == 0x04) {
        /* Scan data mode: proceed with scan */

        /* F3: ASIC channel configuration (2282 bytes) */
        scan_config_asic_channels();        /* FW:0x408FE */

        /* F4: DMA register programming (764 bytes) */
        scan_program_dma();                 /* FW:0x411E8 */

        /* F5: CCD pixel transfer (2498 bytes) */
        scan_pixel_transfer();              /* FW:0x414E4 */

        /* F6: Resolution/adapter-specific setup (2630 bytes) */
        scan_resolution_setup();            /* FW:0x41EE8 */

        /* Scan pipeline functions */
        scan_pipeline_phase1();             /* FW:0x2D4E2 */
        scan_pipeline_phase2();             /* FW:0x2D598 */
        scan_pipeline_phase3();             /* FW:0x2D7AE */

        /* Motor/ASIC functions */
        asic_motor_configure();             /* FW:0x0358EC */
        motor_position_for_scan();          /* FW:0x037D18 */
        ccd_line_timing();                  /* FW:0x037338 */

    } else if (cs == 0x05) {
        /* Calibration data mode */
        scan_calibration_variant();
    }
}

/*
 * Common scan initialization (F12).
 * FW:0x044E40-0x045300 (1216 bytes).
 *
 * Called by all 4 adapter entry points as the first step.
 */
void scan_common_init(void)  /* FW:0x044E40 */
{
    /* Adapter detection and configuration */
    uint8_t adapter = adapter_type_byte;    /* 0x400F22 */

    /* ASIC base configuration */
    asic_timing_setup();                    /* FW:0x3718A */

    /* Timing computation (calls F11 internally) */
    uint16_t pixel_period = scan_timing_compute(); /* FW:0x44DCE */

    /* Scan area parameter initialization */
    /* References 0x400F30-0x400F34 (scan config area) */

    /* USB data transfer setup */
    usb_transfer_setup();                   /* FW:0x12360 */
}

/*
 * Timing computation (F11).
 * FW:0x044DCE-0x044E3F (114 bytes).
 *
 * Computes pixel clock timing from resolution setting.
 */
uint16_t scan_timing_compute(void)  /* FW:0x044DCE */
{
    /* Microsecond timing computation */
    uint32_t us_period = math_multiply(/* resolution */, 1000000); /* FW:0x0163EA */
    uint32_t pixel_clk = math_divide(us_period, /* divisor */);   /* FW:0x015CF2 */

    return (uint16_t)pixel_clk;
}


/* ======================================================================
 * SECTION 10: USB / ISP1581 INTERFACE
 * ====================================================================== */

/*
 * ISP1581 USB 2.0 High-Speed device controller.
 * Code concentrated at FW:0x12200-0x15200 (~3,750 bytes total).
 * Endpoints: EP1 OUT Bulk (CDB/data-out), EP2 IN Bulk (data-in).
 */

/*
 * USB soft-connect/disconnect.
 * FW:0x0139C0 / 0x0139D0
 */
void usb_disconnect(void)  /* FW:0x0139C0 */
{
    uint16_t mode = ISP_MODE;
    mode |= (1 << 4);                      /* Set SOFTCT bit = disconnected */
    ISP_MODE = mode;
}

void usb_reconnect(void)  /* FW:0x0139D0 */
{
    uint16_t mode = ISP_MODE;
    mode &= ~(1 << 4);                     /* Clear SOFTCT bit = connected */
    ISP_MODE = mode;
}

/*
 * USB bus reset handler.
 * FW:0x013A20
 */
void usb_bus_reset_handler(void)  /* FW:0x013A20 */
{
    /* Reset ASIC-side USB interface */
    ASIC_MASTER_CTRL = 0x02;

    /* Initialize USB timeout timer at 0x4007D6 */

    /* Clear all USB state variables (0x407Dxx block) */
    /* ... zero out 0x407D2E - 0x407DE0 ... */

    /* Install ISP1581 endpoint callback table from flash to RAM */
    /* Flash source -> RAM at 0x400DC8 */

    /* Configure endpoints */
    isp1581_endpoint_configure();           /* FW:0x015280 */

    /* Re-enable ASIC USB path */
    ASIC_DAC_MODE = 0x20;                  /* 0x2000C2 = init mode */
}

/*
 * Read from USB endpoint (bulk-out).
 * FW:0x012258
 *
 * ISP1581 data register is 16-bit. USB data is byte-oriented.
 * Handles byte-swapping: ISP1581 is little-endian, H8/3003 is big-endian.
 */
void usb_endpoint_read(uint8_t *dest, uint16_t byte_count)  /* FW:0x012258 */
{
    uint16_t words = byte_count >> 1;
    int odd = byte_count & 1;

    for (uint16_t i = 0; i < words; i++) {
        uint16_t w = ISP_DATA_PORT;         /* Read 16-bit from 0x600020 */
        *dest++ = w & 0xFF;                 /* Low byte first (LE USB data) */
        *dest++ = (w >> 8) & 0xFF;          /* High byte */
    }

    if (odd) {
        uint16_t w = ISP_DATA_PORT;
        *dest++ = w & 0xFF;                 /* Only low byte for odd count */
    }
}

/*
 * Write to USB endpoint (bulk-in).
 * FW:0x0122C4
 */
void usb_endpoint_write(uint8_t *src, uint16_t byte_count)  /* FW:0x0122C4 */
{
    ISP_EP_INDEX = byte_count;              /* Write count to endpoint index */

    uint16_t words = byte_count >> 1;
    int odd = byte_count & 1;

    for (uint16_t i = 0; i < words; i++) {
        uint16_t w = *src++;                /* Low byte */
        w |= ((uint16_t)*src++) << 8;       /* High byte (pack to LE word) */
        ISP_DATA_PORT = w;                  /* Write to 0x600020 */
    }

    if (odd) {
        uint16_t w = *src++;
        ISP_DATA_PORT = w;                  /* Write final odd byte */
    }
}

/*
 * USB response manager.
 * FW:0x01374A
 *
 * Manages USB bulk-in response transfers.
 * Coordinates ISP1581 DMA for scan data and command responses.
 */
void usb_response_manager(uint8_t phase)  /* FW:0x01374A */
{
    /* Check if USB transaction already active */
    if (usb_txn_active) {                   /* 0x40049A */
        return; /* Abort: already sending */
    }

    /* Store command phase */
    *(volatile uint8_t *)0x407DC6 = phase;

    /* Setup ISP1581 DMA for response */
    isp1581_dma_setup();                    /* FW:0x13C70 */

    /* Wait for DMA completion */
    while (/* DMA busy */) {
        yield();                            /* jsr @0x109E2 */
    }

    /* Mark transaction active */
    usb_txn_active = 1;

    /* Increment transfer counter */
    cmd_counter++;                          /* 0x40049D */
}

/*
 * ISP1581 DMA setup for bulk transfer.
 * FW:0x013C70
 */
void isp1581_dma_setup(void)  /* FW:0x013C70 */
{
    /* Configure DMA direction and mode */
    ISP_DMA_REG = 0x8000;                  /* Direction = host-read */
    ISP_EP_CTRL = 0x0005;                  /* DMA mode = bulk endpoint */
    ISP_DMA_COUNT = 0x0001;                /* Enable transfer */
}

/*
 * ISP1581 bulk transfer start.
 * FW:0x013F3A
 */
void isp1581_bulk_transfer_start(uint16_t *data, uint16_t count)  /* FW:0x013F3A */
{
    ISP_DMA_REG = 0x8000;                  /* DMA direction = host-read */
    ISP_EP_CTRL = 0x0005;                  /* DMA mode = bulk endpoint */
    ISP_DMA_COUNT = 0x0001;                /* Enable */

    /* Write first data word to kick off transfer */
    ISP_DATA_PORT = data[0];
}

/*
 * RAM-resident USB code.
 * FW:0x012486 copies 414 bytes from flash 0x124BA to RAM 0x4010A0.
 *
 * During high-speed USB DMA, executing from flash may conflict
 * with DMA bus accesses. Critical USB handler code runs from RAM
 * to avoid bus contention.
 */
void usb_install_ram_code(void)  /* FW:0x012486 */
{
    volatile uint8_t *src = (volatile uint8_t *)0x124BA;
    volatile uint8_t *dst = (volatile uint8_t *)0x4010A0;

    /* Copy 414 bytes (0x19E) word-by-word */
    for (int i = 0; i < 414; i += 2) {
        *(volatile uint16_t *)(dst + i) = *(volatile uint16_t *)(src + i);
    }

    /* Jump tables redirect to RAM code:
     * 0x01247E: JMP @0x4010A0
     * 0x012482: JMP @0x4011A2
     */
}


/* ======================================================================
 * SECTION 11: BOOT & INITIALIZATION
 * ====================================================================== */

/*
 * Reset vector entry point.
 * FW:0x000100
 *
 * The H8/3003 reads the 32-bit address at vector 0 (0x000000),
 * which is 0x00000100, and begins executing here.
 */
void __attribute__((noreturn)) reset_entry(void)  /* FW:0x000100 */
{
    /* Initialize stack pointer to top of on-chip RAM */
    /* mov.l #0xFFFF00, er7 */

    /* Disable all interrupts */
    DISABLE_INTERRUPTS();  /* ldc.b #0xC0, ccr */

    /* Write state flag = 0 (cold boot) */
    *(volatile uint8_t *)0xFFFD4C = 0x00;

    /* Jump to bank select */
    goto bank_select;
}

/*
 * Alternate boot entry (soft-reset / watchdog).
 * FW:0x000112
 *
 * Not reached from normal reset. Entered from warm restart.
 * Copies bootstrap data from flash to on-chip RAM (currently all 0xFF/erased).
 */
void __attribute__((noreturn)) warm_restart_entry(void)  /* FW:0x000112 */
{
    /* mov.l #0xFFFF00, er7 */
    DISABLE_INTERRUPTS();

    /* Write state flag = 1 (warm restart) */
    *(volatile uint8_t *)0xFFFD4C = 0x01;

    /* Copy bootstrap data (currently erased, no-op) */
    /* Flash 0x4006B4 -> RAM 0xFFFD50 (8 bytes) */
    /* Flash 0x4006BC -> RAM 0xFFFD58 (160 bytes) */
    /* Flash 0x40075C -> RAM 0xFFFDF8 (8 bytes) */

    goto bank_select;
}

/*
 * Bank select — chooses between main and backup firmware.
 * FW:0x00016E
 */
bank_select:
void __attribute__((noreturn)) bank_select_dispatch(void)  /* FW:0x00016E */
{
    uint8_t bank = *(volatile uint8_t *)0x4001;  /* Hardware register */

    if (bank == 0x00) {
        /* Normal: jump to main firmware */
        main_firmware_entry();              /* FW:0x020334 */
    } else {
        /* Alternate: jump to backup firmware */
        backup_firmware_entry();            /* FW:0x010334 */
    }
}

/*
 * Main firmware entry.
 * FW:0x020334
 */
void __attribute__((noreturn)) main_firmware_entry(void)  /* FW:0x020334 */
{
    /* Double-check bank select */
    if (*(volatile uint8_t *)0x4001 != 0x00) {
        backup_firmware_entry();
    }
    if (*(volatile uint8_t *)0x4000 & 0x01) {
        backup_firmware_entry();
    }

    /* Reset watchdog */
    WDT_TCSR = 0x5A00;

    /* --- I/O Register Initialization Table --- */
    /* 132 entries at FW:0x2001C, each 6 bytes: [addr:32][pad:8][val:8] */
    /* Configures: BSC, GPIO directions, timer registers, ASIC registers */
    const io_init_entry_t *entry = (const io_init_entry_t *)0x2001C;
    const io_init_entry_t *end   = (const io_init_entry_t *)0x20334;

    while (entry < end) {
        volatile uint8_t *reg = (volatile uint8_t *)entry->address;
        *reg = entry->value;
        entry++;
    }
    /* Last entry: ASIC_MASTER_CTRL (0x200001) = 0x80 (master enable) */

    /* --- RAM Test --- */
    /* Writes 0x55AA55AA / 0xAA55AA55 complementary patterns,
     * verifies readback for the entire external RAM region.
     * Memory region table at FW:0x207A8.
     * Resets watchdog between tests. */
    ram_test();                             /* FW:0x203BA-0x20460 */

    /* Relocate SP from on-chip to external RAM */
    /* mov.l #0x40F800, er7 */

    /* Peripheral initialization */
    peripheral_init();                      /* FW:0x015EAA */

    /* --- Install Interrupt Trampolines --- */
    /* 12 JMP instructions written to on-chip RAM (0xFFFD10-0xFFFD3C).
     * The flash vector table points to these RAM locations.
     * Each trampoline is 4 bytes: 5A xx xx xx = JMP @target.
     * Installed using eepmov.b (byte copy from inline flash data).
     *
     * Trampoline map:
     *   0xFFFD10: JMP @0x010876 (TRAP #0, context switch)
     *   0xFFFD14: JMP @0x033444 (IRQ3, encoder)
     *   0xFFFD18: JMP @0x014D4A (IRQ4/IRQ5, shared)
     *   0xFFFD1C: JMP @0x010B76 (IMIA2, motor dispatch)
     *   0xFFFD20: JMP @0x02D536 (IMIA3, DMA coordinator)
     *   0xFFFD24: JMP @0x010A16 (IMIA4, system tick)
     *   0xFFFD28: JMP @0x02CEF2 (DEND0B, DMA ch0)
     *   0xFFFD2C: JMP @0x02E10A (DEND1B, DMA ch1)
     *   0xFFFD30: JMP @0x02E9F8 (Vec 49, CCD line readout)
     *   0xFFFD34: JMP @0x02EDDE (Vec 60, ADI)
     *   0xFFFD38: JMP @0x02B544 (IRQ7, motor complete)
     *   0xFFFD3C: JMP @0x014E00 (IRQ1, ISP1581 USB)
     */
    install_trampolines();                  /* FW:0x204C4-0x205F7 */

    /* --- Transition to Main Loop --- */

    /* Clear shared state */
    system_timestamp = 0;                   /* FW:0x0109FA */

    /* Set initialized flag */
    boot_flag = 1;                          /* 0x400772 */

    /* >>> ENABLE INTERRUPTS FOR THE FIRST TIME <<< */
    ENABLE_INTERRUPTS();                    /* FW:0x020608: ANDC #0x7F, CCR */

    /* One-time hardware init (with interrupts enabled) */
    hardware_init_with_irq();               /* FW:0x02A188 */

    /* Disable interrupts again for context system setup */
    DISABLE_INTERRUPTS();

    /* Reset boot flag for first-boot descriptor selection */
    boot_flag = 0;

    /* Register main loop entry point */
    register_context_a();                   /* FW:0x0107BC */

    /* Initialize ASIC/DMA state */
    asic_dma_init();                        /* FW:0x010BCE */

    /* >>> ENTER CONTEXT SYSTEM — NEVER RETURNS <<< */
    enter_context_system();                 /* FW:0x0107EC -> JMP */
}

/*
 * Install interrupt trampolines into on-chip RAM.
 * FW:0x204C4-0x205F7
 *
 * Each trampoline uses eepmov.b to copy 4 bytes of inline JMP instruction
 * data from the flash code stream to the on-chip RAM trampoline address.
 */
void install_trampolines(void)  /* FW:0x204C4 */
{
    /* Example for first trampoline: */
    /* Destination: 0xFFFD10 */
    /* Source data: { 0x5A, 0x01, 0x08, 0x76 } = JMP @0x010876 */
    /* eepmov.b copies 4 bytes */

    /* The H8/300H eepmov.b instruction:
     *   ER5 = source address
     *   ER6 = destination address
     *   R4L = byte count
     *   Copies [ER5] -> [ER6], R4L bytes, incrementing both pointers */

    static const struct {
        uint32_t ram_addr;
        uint32_t target;
    } trampoline_table[12] = {
        { 0xFFFD10, 0x010876 }, /* TRAP #0: context switch */
        { 0xFFFD14, 0x033444 }, /* IRQ3: encoder */
        { 0xFFFD18, 0x014D4A }, /* IRQ4/5: shared */
        { 0xFFFD1C, 0x010B76 }, /* IMIA2: motor dispatch */
        { 0xFFFD20, 0x02D536 }, /* IMIA3: DMA coordinator */
        { 0xFFFD24, 0x010A16 }, /* IMIA4: system tick */
        { 0xFFFD28, 0x02CEF2 }, /* DEND0B: DMA ch0 */
        { 0xFFFD2C, 0x02E10A }, /* DEND1B: DMA ch1 */
        { 0xFFFD30, 0x02E9F8 }, /* Vec 49: CCD readout */
        { 0xFFFD34, 0x02EDDE }, /* Vec 60: ADI */
        { 0xFFFD38, 0x02B544 }, /* IRQ7: motor complete */
        { 0xFFFD3C, 0x014E00 }, /* IRQ1: ISP1581 USB */
    };

    for (int i = 0; i < 12; i++) {
        volatile uint8_t *dest = (volatile uint8_t *)trampoline_table[i].ram_addr;
        uint32_t target = trampoline_table[i].target;

        /* Write JMP @target instruction (H8/300H encoding: 5A xx xx xx) */
        dest[0] = 0x5A;
        dest[1] = (target >> 16) & 0xFF;
        dest[2] = (target >> 8) & 0xFF;
        dest[3] = target & 0xFF;
    }
}


/* ======================================================================
 * SECTION 12: MAIN LOOP & CONTEXT SYSTEM
 * ====================================================================== */

/*
 * Two-context cooperative coroutine system.
 *
 * Context A (0x207F2): Main firmware loop — control plane
 *   Stack: 0x410000 (top of 128KB RAM)
 *   Handles: SCSI commands, state transitions, USB responses
 *
 * Context B (0x29B16): Background processing — data plane
 *   Stack: 0x40D000 (52KB below Context A)
 *   Handles: DMA transfers, motor/CCD coordination, long-running data flows
 *   21 yield calls across 0x29B16-0x2C400
 *
 * Neither context can preempt the other.
 * Only hardware interrupts (timers, DMA, USB) can interrupt either.
 * Cooperation via TRAPA #0 (yield at FW:0x109E2).
 */

/*
 * Context system initialization.
 * FW:0x0107EC
 *
 * Creates two execution contexts with separate stacks.
 * Entered by JMP from main_firmware_entry — never returns.
 */
void __attribute__((noreturn)) enter_context_system(void)  /* FW:0x0107EC */
{
    /* Select entry point table based on boot flag */
    struct { uint32_t stack_base; void (*entry)(void); } *table;

    if (boot_flag == 0) {
        /* Table A (first boot):
         *   Context A: stack=0x410000, entry=0x0207F2 (main loop)
         *   Context B: stack=0x40D000, entry=0x029B16 (USB handler) */
        /* table = (void *)0x0107CC; */
    } else {
        /* Table B (warm restart):
         *   Context A: stack=0x410000, entry=0x010C46 (alt main loop)
         *   Context B: stack=0x40D000, entry=0x029B16 (USB handler, same) */
        /* table = (void *)0x0107DC; */
    }

    /* For each context: create stack frame with entry point as return addr */
    /* Push entry point + 7 zero registers (ER0-ER6) */
    /* Save SP to ctx_sp_save[] */

    /* Clear context switch state */
    ctx_switch_state = 0;                   /* 0x400764 */

    /* Load Context A's saved SP */
    /* Pop registers, RTE into Context A entry point */
    /* --- Never returns --- */
}

/*
 * Yield stub — cooperative context switch.
 * FW:0x0109E2
 */
void yield(void)  /* FW:0x0109E2 */
{
    /* TRAPA #0 — pushes CCR+PC, vectors to context switch handler */
    /* On return (from other context's yield), RTS back to caller */
    asm("trapa #0");
}

/*
 * Utility stubs in the shared module.
 * FW:0x109E0-0x109FA
 */
void disable_interrupts_stub(void) { DISABLE_INTERRUPTS(); } /* FW:0x109EA */
void enable_interrupts_stub(void)  { ENABLE_INTERRUPTS();  } /* FW:0x109EE */
uint8_t read_ccr(void)  { uint8_t r; asm("stc ccr, %0" : "=r"(r)); return r; }
void write_ccr(uint8_t v) { asm("ldc %0, ccr" :: "r"(v)); }

/*
 * Main loop — Context A.
 * FW:0x0207F2
 *
 * Simple polling loop with cooperative yielding.
 * This is the firmware's primary execution thread.
 */
void __attribute__((noreturn)) main_loop(void)  /* FW:0x0207F2 */
{
    /* Save callee-saved registers (push_context at FW:0x016458) */

    /* Pre-loop setup */
    volatile uint16_t *scan_prog  = (volatile uint16_t *)0x40077A;
    volatile uint8_t  *usb_reset  = (volatile uint8_t  *)0x400084;
    volatile uint8_t  *usb_reinit = (volatile uint8_t  *)0x400085;
    volatile uint8_t  *state_flags = (volatile uint8_t *)0x400776;

    /* One-time shared module init */
    shared_module_init();                    /* FW:0x010D22 */

    /* USB configuration with timeout */
    usb_configure_with_timeout(50);          /* FW:0x01233A */
    usb_enable_endpoints();                  /* FW:0x0126EE */

    for (;;) {
        /* === Step 1: Check USB connection === */
        if (usb_session_state != 0x02) {     /* 0x407DC7 != 2 */
            usb_reestablish_session(0x005C); /* FW:0x013836, timeout=92 */
        }

        /* === Step 2: Process scan state === */
        uint16_t sp = *scan_prog;
        uint16_t ss = task_code;
        process_scan_state(sp, ss);          /* FW:0x0133A4 */

        /* === Step 3: Handle USB bus reset === */
        if (*usb_reset) {
            usb_bus_reset_handler();          /* FW:0x013A20 */
        }

        /* === Step 4: Scanner state machine === */
        scanner_state_machine();             /* FW:0x0208AC */

        /* === Step 5: Handle USB re-init === */
        if (*usb_reinit) {
            *usb_reinit = 0;
            if (*(volatile uint8_t *)0x400086) {
                sense_code = 0x0061;         /* USB comm error */
            }
            if (*state_flags & 0x40) {       /* Abort bit */
                *state_flags |= 0x80;        /* Set response-pending */
            }
            if (!*usb_reset) {
                usb_soft_reconnect();        /* FW:0x013BB4 */
            }
        }

        /* === Step 6: Check for SCSI command === */
        uint8_t cmd_ready = usb_check_command(); /* FW:0x013C70 */

        if (!cmd_ready) {
            /* No command: YIELD to Context B */
            yield();                         /* FW:0x0109E2 (TRAPA #0) */
            continue;                        /* After wakeup, re-poll */
        }

        /* === Step 7: Process SCSI command === */
        scanner_state_machine();             /* Re-check state */
        scsi_dispatch();                     /* FW:0x020AE2 */

        /* === Step 8: Check for soft-reset === */
        if (lamp_active == 0x01) {           /* 0x400E5F */
            usb_disconnect();                /* FW:0x012F5A */
            disable_interrupts_stub();
            warm_restart_entry();            /* FW:0x000112 — reinit everything */
            /* Never reaches here */
        }
    }
}

/*
 * SCSI command dispatch.
 * FW:0x020AE2
 *
 * Called from main loop when a SCSI command is available.
 */
void scsi_dispatch(void)  /* FW:0x020AE2 */
{
    /* Clear sense code (no error) */
    sense_code = 0;                          /* 0x4007B0 */
    *(volatile uint8_t *)0x400877 = 0;       /* Additional sense */

    /* Check if USB command is ready */
    if (!usb_command_ready()) {              /* FW:0x013690 */
        return;
    }

    /* Clear execution state */
    cmd_counter = 0;                         /* 0x40049D */
    usb_txn_active = 0;                      /* 0x40049A */
    xfer_phase = 0;                          /* 0x40049C */

    /* If sense already set from previous error, skip handler lookup */
    if (sense_code != 0) {
        goto send_response;
    }

    /* Look up SCSI handler in table at FW:0x49834 */
    scsi_handler_lookup();                   /* FW:0x020B48 */

send_response:
    /* Signal command-complete phase via USB */
    usb_response_manager(1);                 /* FW:0x01374A */

    /* Post-dispatch cleanup */
    post_dispatch_cleanup();                 /* FW:0x01117A */
}

/*
 * SCSI handler lookup.
 * FW:0x020B48
 *
 * Linear search through the 21-entry handler table at FW:0x49834.
 * 10-byte stride per entry.
 */
void scsi_handler_lookup(void)  /* FW:0x020B48 */
{
    const scsi_handler_entry_t *entry = (const scsi_handler_entry_t *)0x49834;
    uint8_t opcode = scsi_opcode;            /* 0x4007B6 */

    /* Linear scan for matching opcode */
    while (entry->handler != NULL) {
        if (entry->opcode == opcode) {
            /* Found: check permissions */
            uint16_t perms = entry->perm_flags;
            /* ... extensive state/permission checking at 0x20B70-0x20D90 ... */

            /* USB state setup if exec mode requires it */
            if (entry->exec_mode == 0x01) {
                usb_response_manager(/* phase */1);
            }

            /* Store exec mode for reference */
            exec_mode = entry->exec_mode;    /* 0x40049B */

            /* >>> CALL THE SCSI HANDLER <<< */
            entry->handler();

            return;
        }
        entry++; /* Next entry (10-byte stride) */
    }

    /* Opcode not found: set ILLEGAL REQUEST sense */
    sense_code = 0x0050;
}

/*
 * Internal task dispatch.
 * FW:0x020DBA
 *
 * Maps a 16-bit task code to a handler index via linear search
 * through the 97-entry task table at FW:0x49910.
 */
uint16_t task_dispatch(uint16_t code)  /* FW:0x020DBA */
{
    const task_entry_t *entry = (const task_entry_t *)0x49910;

    while (entry->task_code != 0x0000) {
        if (entry->task_code == code) {
            return entry->handler_index;
        }
        entry++;
    }

    return 0; /* Not found */
}

/*
 * Task execution with budget system.
 * FW:0x020DD6
 *
 * Prevents any single long-running task from starving SCSI processing.
 * Each task gets a time budget; when exhausted, the task yields.
 */
void task_execute(void)  /* FW:0x020DD6 */
{
    uint32_t budget = task_budget;            /* 0x400896 */
    *(volatile uint32_t *)0x40089A = budget;  /* Save initial budget */

    task_active = 1;                          /* 0x400493 */

    while (budget > 0) {
        uint32_t remaining = task_remaining;  /* 0x40078C */
        if (remaining == 0) {
            /* No work: check for errors or USB events */
            if (sense_code != 0) break;
            if (usb_reinit_flag) {
                task_active = 0;
                return;
            }
            /* Idle: yield to other context */
            yield();
            continue;
        }

        /* Execute one unit of work (DMA transfer or task step) */
        uint32_t work_done = execute_work_unit(); /* FW:0x0140F2 */
        budget -= work_done;

        if (budget == 0) {
            /* Budget exhausted */
            task_complete = 1;               /* 0x400492 */
        }
    }

    task_active = 0;
    task_budget = budget;
}

/*
 * Context B — background processing loop.
 * FW:0x029B16
 *
 * Data plane: monitors task progress, manages DMA, coordinates motor/CCD.
 * 21 yield points across the 0x29B16-0x2C400 region.
 */
void __attribute__((noreturn)) context_b_loop(void)  /* FW:0x029B16 */
{
    volatile uint16_t *scan_prog  = (volatile uint16_t *)0x40077A;
    volatile uint8_t  *state_flags = (volatile uint8_t *)0x400776;
    volatile uint16_t *state_var   = (volatile uint16_t *)0x40077C;

    for (;;) {
        uint16_t tc = task_code;             /* 0x400778 */

        /* Task code monitoring: different states require different processing */
        switch (tc) {
        case 0x0010:
            /* Set scan progress to 0x2000, call handler, yield */
            *scan_prog = 0x2000;
            yield();
            break;

        case 0x0110:
        case 0x0120:
        case 0x0121:
            /* Init sequence monitoring */
            /* ... monitor hardware init progress ... */
            yield();
            break;

        case 0x2000:
        case 0x3000:
            /* Scan/recovery monitoring */
            /* Check sub-states: 0x0110, 0x0120, 0x0121 */
            /* ... manage DMA and motor coordination ... */
            yield();
            break;

        default:
            /* Check ASIC DMA status */
            /* Check adapter state (0x400F22, 0x40632F) */
            /* Check USB busy (0x400773) */

            /* Idle: yield to Context A */
            yield();
            break;
        }
    }
}


/* ======================================================================
 * HELPER / MATH FUNCTIONS (Referenced throughout the firmware)
 * ====================================================================== */

/*
 * Math library functions used by motor, scan, and calibration code.
 * These are generic 32-bit arithmetic routines for the H8/300H.
 */

uint32_t math_multiply(uint32_t a, uint32_t b);  /* FW:0x0163EA */
uint32_t math_divide(uint32_t a, uint32_t b);    /* FW:0x015CCC */
uint32_t math_divide_2(uint32_t a, uint32_t b);  /* FW:0x015DB4 */
uint32_t math_divide_3(uint32_t a, uint32_t b);  /* FW:0x015CF2 */

/* push_context: saves ER3-ER6 to stack */
void push_context(void);  /* FW:0x016458 */

/* pop_context: restores ER3-ER6 from stack */
void pop_context(void);   /* FW:0x016436 */


/* ======================================================================
 * ASIC INITIALIZATION SEQUENCE (from I/O Init Table at FW:0x2001C)
 * ======================================================================
 *
 * The I/O init table writes 132 registers in this order:
 *
 * --- CPU Registers (30 entries) ---
 * BSC config: ABWCR=0x0B, WCR=0xBA, WCER=0x00, BRCR=0x00, CSCR=0x30
 * Port DDR:   P1=0xFF, P2=0x01, P3=0x00, P4=0x01
 * SCI config: SCI0/SCI1 mode registers
 * Timer:      TSTR=0xE0 (enable ITU2/3/4), TCR0=0xA0
 * DMA:        DTCR configuration
 * Port data:  Port A = 0x00, Port 9 = 0xA0
 *
 * --- ASIC Core Registers (48 entries) ---
 * System:     0x200044=0x00, 0x200045=0x00, 0x200046=0xFF
 * DAC/ADC:    0x2000C0=0x52, 0x2000C1=0x04
 * DMA ch:     0x200100=0x3F ... 0x200117=0x18 (7 channel pairs)
 * Buffer:     0x200140=0x01 ... 0x20014F=0x04
 * Motor:      0x200181=0x0D, 0x200193=0x0E
 * Line timing: 0x2001C0=0x03 ... 0x2001C9=0x18
 *
 * --- CCD/Channel Registers (54 entries) ---
 * Channel master: 0x200200=0x00, 0x200204=0x04, 0x200205=0x03
 * CCD master:     0x200400=0x20, 0x200401=0x0A, 0x200402=0x00
 * CCD mask:       0x200405=0xFF, 0x200406=0x01
 * Integration:    0x200408-0x200425 (5 groups, 30 values)
 * Gain:           0x200456=0x00, 0x200457=0x63, 0x200458=0x63
 * Per-channel:    0x20046D-0x200487 (4 channels x 3 regs)
 *
 * --- Init-only blocks (set once, never referenced by runtime code) ---
 * Block 0x09: 0x200910
 * Block 0x0A: 0x200A81-0x200AF2
 * Block 0x0C: 0x200C82
 * Block 0x0F: 0x200F20-0x200FC0
 *
 * --- Final entry ---
 * 0x200001 = 0x80 (ASIC master enable — LAST step)
 */


/* ======================================================================
 * ADAPTER DETECTION AND FILM HANDLING
 * ======================================================================
 *
 * 8 adapter types detected via GPIO Port 7 (0xFFFF8E):
 *   0: (none)    — bare mount, no adapter
 *   1: Mount     — SA-21 slide mount adapter
 *   2: Strip     — SF-210 strip film adapter
 *   3: 240       — IA-20(s) APS/IX240 adapter
 *   4: Feeder    — SA-30 roll film adapter
 *   5: 6Strip    — SF-210 in 6-strip mode
 *   6: 36Strip   — SF-210 in 36-exposure mode
 *   7: Test      — factory test jig (zero VPD pages)
 *
 * Film holders (inserted into adapters):
 *   FH-3  — standard 35mm strip holder
 *   FH-G1 — glass holder for curled/warped film
 *   FH-A1 — medical/special slide holder
 *
 * Positioning reference objects per adapter:
 *   SA_OBJECT, 240_OBJECT, 240_HEAD, FD_OBJECT, 6SA_OBJECT, 36SA_OBJECT
 *
 * Calibration parameters:
 *   DA_COARSE, DA_FINE, EXP_TIME, GAIN
 *
 * Adapter dispatch at FW:0x3C400:
 *   0x04 (Mount)  -> entry B (FW:0x4063C)
 *   0x08 (Strip)  -> entry A (FW:0x40630)
 *   0x20 (240)    -> entry C (FW:0x40648)
 *   0x40 (Feeder) -> entry D (FW:0x40654)
 */

/*
 * Adapter detection.
 * Reads GPIO Port 7 to determine inserted adapter type.
 * Called 16 times in firmware (14 in SCAN handler).
 */
uint8_t detect_adapter(void)
{
    return PORT_7_DR;                        /* 0xFFFF8E */
}


/* ======================================================================
 * FLASH PROGRAMMING
 * ======================================================================
 *
 * The flash programming function at FW:0x3A300 supports multiple
 * flash chip variants. Only used to write usage telemetry logs
 * to areas at 0x60000 and 0x70000.
 *
 * Config value at 0x4A3EC determines sector size and unlock address:
 *   0x200 -> 512B sector, unlock=0x1C7
 *   0x400 -> 1KB sector, unlock=0x333
 *   0x800 -> 2KB sector, unlock=0x555
 *   0xFFF -> 4KB sector, unlock=0x1FFF (active: MBM29F400B top-boot)
 *
 * The CCD characterization data (0x4A8BC-0x528BD) is NEVER written
 * at runtime. It was factory-programmed and is read-only during operation.
 */

/*
 * Flash log record format (32 bytes per record):
 *
 *   [0]    0xAA header marker
 *   [1]    0x01 type (usage telemetry, only type observed)
 *   [2-3]  16-bit sequence counter (big-endian)
 *   [4-5]  16-bit slow counter (lamp degradation metric)
 *   [6-7]  16-bit step counter (motor position, increments by 256)
 *   [8-9]  16-bit usage counter (cumulative scan time)
 *   [10-13] 32-bit config (hardware/firmware revision, always 7)
 *   [14-17] 32-bit lamp time (upper byte = lamp hours)
 *   [18-29] 12 bytes reserved (usually zero)
 *   [30]   0x00 padding
 *   [31]   0x55 footer marker
 *
 * Area 2 (0x70000) fills first (2048 records), then wraps to Area 1 (0x60000).
 * This unit has logged ~24,500 usage events.
 */


/* ======================================================================
 * END OF FIRMWARE HARDWARE CONTROL PSEUDOCODE
 *
 * Summary of hardware control:
 *   - 15 active interrupt handlers (context switch, USB, encoder,
 *     motor dispatch, DMA x3, system tick, CCD readout, ADC, IRQ4/5)
 *   - 2 stepper motors with 4-phase wave drive and acceleration ramps
 *   - Custom ASIC with 172 registers across 8 blocks
 *   - Tri-linear CCD with R/G/B + IR channels (4095 active elements)
 *   - LED lamp with open-drain GPIO control
 *   - ISP1581 USB 2.0 controller with DMA bulk transfers
 *   - Two-context cooperative coroutine system
 *   - Data-driven initialization (132-entry I/O init table)
 *   - Minimal firmware-side image processing (all correction is host-side)
 *
 * Total firmware size: ~314KB used of 512KB flash.
 * Estimated ~660 functions, 304 unique call targets.
 * ====================================================================== */
