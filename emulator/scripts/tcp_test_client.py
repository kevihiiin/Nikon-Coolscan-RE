#!/usr/bin/env python3
"""TCP test client for the Coolscan emulator bridge.

Phase 5: Full scan sequence test (init + scan + image data retrieval).

Frame protocol:
  [2B length BE] [1B type] [payload]

Host->Emulator types:
  0x01 = CDB (up to 16 bytes)
  0x02 = Phase Query
  0x04 = Sense Query
  0x05 = Data-In Query (drain ISP1581 EP2 IN)
  0x06 = Data-Out Inject (push to ISP1581 EP1 OUT)
  0x07 = Completion Poll (check cmd_pending)

Emulator->Host types:
  0x81 = Phase Byte (1 byte)
  0x82 = Data-In auto-push (variable, from EP2 IN)
  0x83 = Sense Data (18 bytes)
  0x84 = Data-In response (variable, from EP2 IN query)
  0x85 = Completion Status (4 bytes: done, sk, asc, has_data)
  0x86 = Data-Out ACK (1 byte)
"""

import socket
import struct
import sys
import time

DEFAULT_PORT = 6581
TIMEOUT = 5.0


def send_frame(sock, msg_type, payload=b""):
    """Send a framed message: [length:2 BE][type:1][payload]"""
    header = struct.pack(">HB", len(payload), msg_type)
    sock.sendall(header + payload)


def recv_frame(sock, timeout=TIMEOUT):
    """Receive a framed message. Returns (msg_type, payload) or (None, None) on timeout."""
    sock.settimeout(timeout)
    try:
        header = b""
        while len(header) < 3:
            chunk = sock.recv(3 - len(header))
            if not chunk:
                return None, None
            header += chunk
        length, msg_type = struct.unpack(">HB", header)
        payload = b""
        while len(payload) < length:
            chunk = sock.recv(length - len(payload))
            if not chunk:
                break
            payload += chunk
        return msg_type, payload
    except socket.timeout:
        return None, None


def recv_all_frames(sock, timeout=0.5):
    """Receive all pending frames (with short timeout between)."""
    frames = []
    while True:
        msg_type, payload = recv_frame(sock, timeout=timeout)
        if msg_type is None:
            break
        frames.append((msg_type, payload))
    return frames


def wait_completion(sock, max_polls=50, poll_interval=0.2):
    """Poll for command completion. Returns (done, sense_key, asc, has_data).
    Also collects any auto-pushed data-in responses."""
    collected_data = []
    for i in range(max_polls):
        send_frame(sock, 0x07)
        # Read responses until we get a completion status
        for _ in range(10):  # Read up to 10 frames per poll
            msg_type, payload = recv_frame(sock, timeout=1.0)
            if msg_type is None:
                break
            if msg_type == 0x85 and len(payload) >= 4:
                done, sk, asc, has_data = payload[0], payload[1], payload[2], payload[3]
                if done:
                    return True, sk, asc, has_data, collected_data
            elif msg_type in (0x82, 0x84):
                collected_data.append(payload)
                print(f"  [auto-push] {len(payload)} bytes data-in")
            # else: ignore other frame types
        time.sleep(poll_interval)
    return False, 0, 0, 0, collected_data


def query_data_in(sock):
    """Request data-in from ISP1581 EP2 IN FIFO."""
    send_frame(sock, 0x05)
    msg_type, payload = recv_frame(sock, timeout=2.0)
    if msg_type == 0x84:
        return payload
    # Might get auto-pushed data (0x82) instead
    if msg_type == 0x82:
        return payload
    return b""


def query_sense(sock):
    """Query sense data. Returns (sense_key, asc, ascq)."""
    send_frame(sock, 0x04)
    msg_type, payload = recv_frame(sock, timeout=2.0)
    if msg_type == 0x83 and len(payload) >= 14:
        sk = payload[2] & 0x0F
        asc = payload[12]
        ascq = payload[13]
        return sk, asc, ascq
    return None, None, None


def collect_data_in(sock, auto_data):
    """Collect all data-in bytes from auto-push frames and explicit query.

    Combines data from wait_completion's auto_data, any additional auto-pushed
    frames still in the socket buffer, and falls back to an explicit query
    if nothing was collected.
    """
    data = b"".join(auto_data)
    frames = recv_all_frames(sock, timeout=0.3)
    for ft, fp in frames:
        if ft in (0x82, 0x84):
            data += fp
    if not data:
        data = query_data_in(sock)
    return data


def inject_data_out(sock, data):
    """Inject data-out payload into ISP1581 EP1 OUT FIFO."""
    send_frame(sock, 0x06, data)
    msg_type, payload = recv_frame(sock, timeout=2.0)
    if msg_type == 0x86:
        return True
    return False


def hex_dump(data, prefix="  ", width=16):
    """Pretty hex dump."""
    for i in range(0, len(data), width):
        chunk = data[i:i+width]
        hex_part = " ".join(f"{b:02X}" for b in chunk)
        ascii_part = "".join(chr(b) if 32 <= b < 127 else "." for b in chunk)
        print(f"{prefix}{i:04X}: {hex_part:<{width*3}}  {ascii_part}")


# --- SCSI command builders ---

def send_tur(sock):
    """TEST UNIT READY (opcode 0x00) — no data transfer."""
    print("\n=== TEST UNIT READY ===")
    cdb = bytes(6)  # All zeros
    send_frame(sock, 0x01, cdb)

    done, sk, asc, has_data, auto_data = wait_completion(sock)
    if done:
        sense_sk, sense_asc, sense_ascq = query_sense(sock)
        if sense_sk == 0 and sense_asc == 0:
            print("  Result: GOOD (sense 00/00/00)")
            return True
        else:
            print(f"  Result: CHECK CONDITION (sense {sense_sk:X}/{sense_asc:02X}/{sense_ascq:02X})")
            return False
    else:
        print("  Result: TIMEOUT (cmd_pending never cleared)")
        return False


def send_inquiry(sock, alloc_len=36, evpd=False, page_code=0):
    """INQUIRY (opcode 0x12) — data-in command, returns device identification."""
    print(f"\n=== INQUIRY (alloc_len={alloc_len}, evpd={evpd}, page={page_code:02X}) ===")
    cdb = bytes([
        0x12,
        0x01 if evpd else 0x00,
        page_code,
        0x00,
        alloc_len & 0xFF,
        0x00,
    ])
    send_frame(sock, 0x01, cdb)

    done, sk, asc, has_data, auto_data = wait_completion(sock)
    if not done:
        print("  Result: TIMEOUT")
        return None

    data = collect_data_in(sock, auto_data)
    sense_sk, sense_asc, sense_ascq = query_sense(sock)

    if data:
        print(f"  Response: {len(data)} bytes")
        hex_dump(data)
        if len(data) >= 36 and not evpd:
            dev_type = data[0] & 0x1F
            vendor = data[8:16].decode("ascii", errors="replace").strip()
            product = data[16:32].decode("ascii", errors="replace").strip()
            revision = data[32:36].decode("ascii", errors="replace").strip()
            print(f"  Device Type: 0x{dev_type:02X} ({'Scanner' if dev_type == 6 else 'Other'})")
            print(f"  Vendor: '{vendor}'")
            print(f"  Product: '{product}'")
            print(f"  Revision: '{revision}'")
    else:
        print("  No data-in response received")

    if sense_sk is not None:
        if sense_sk == 0:
            print(f"  Sense: GOOD ({sense_sk:X}/{sense_asc:02X}/{sense_ascq:02X})")
        else:
            print(f"  Sense: {sense_sk:X}/{sense_asc:02X}/{sense_ascq:02X}")

    return data


def send_request_sense(sock, alloc_len=18):
    """REQUEST SENSE (opcode 0x03) — data-in command."""
    print(f"\n=== REQUEST SENSE (alloc_len={alloc_len}) ===")
    cdb = bytes([0x03, 0x00, 0x00, 0x00, alloc_len & 0xFF, 0x00])
    send_frame(sock, 0x01, cdb)

    done, sk, asc, has_data, auto_data = wait_completion(sock)
    if not done:
        print("  Result: TIMEOUT")
        return None

    data = collect_data_in(sock, auto_data)

    if data:
        print(f"  Response: {len(data)} bytes")
        hex_dump(data)
        if len(data) >= 14:
            sk = data[2] & 0x0F
            asc_val = data[12]
            ascq_val = data[13]
            print(f"  Sense Key={sk:X}, ASC={asc_val:02X}, ASCQ={ascq_val:02X}")
    else:
        print("  No data-in response (reading from RAM sense instead)")
        sk, asc_val, ascq_val = query_sense(sock)
        if sk is not None:
            print(f"  RAM Sense: Key={sk:X}, ASC={asc_val:02X}, ASCQ={ascq_val:02X}")
    return data


def send_mode_sense(sock, page_code=0x03, alloc_len=36):
    """MODE SENSE(6) (opcode 0x1A) — data-in command."""
    print(f"\n=== MODE SENSE (page=0x{page_code:02X}, alloc_len={alloc_len}) ===")
    cdb = bytes([
        0x1A,
        0x18,  # DBD=1 (bit 3), Nikon extension (bit 4)
        page_code,
        0x00,
        alloc_len & 0xFF,
        0x00,
    ])
    send_frame(sock, 0x01, cdb)

    done, sk, asc, has_data, auto_data = wait_completion(sock)
    if not done:
        print("  Result: TIMEOUT")
        return None

    frames = recv_all_frames(sock, timeout=0.3)
    data = b""
    for ft, fp in frames:
        if ft in (0x82, 0x84):
            data += fp
    if not data:
        data = query_data_in(sock)

    sense_sk, sense_asc, sense_ascq = query_sense(sock)

    if data:
        print(f"  Response: {len(data)} bytes")
        hex_dump(data)
    else:
        print("  No data-in response")

    if sense_sk is not None:
        if sense_sk == 0:
            print(f"  Sense: GOOD")
        else:
            print(f"  Sense: {sense_sk:X}/{sense_asc:02X}/{sense_ascq:02X}")
    return data


def send_mode_select(sock, mode_data):
    """MODE SELECT(6) (opcode 0x15) — data-out command."""
    print(f"\n=== MODE SELECT ({len(mode_data)} bytes) ===")
    hex_dump(mode_data)

    cdb = bytes([
        0x15,
        0x10,  # PF=1 (page format)
        0x00,
        0x00,
        len(mode_data) & 0xFF,
        0x00,
    ])
    send_frame(sock, 0x01, cdb)

    # Inject data-out payload for the command
    if mode_data:
        inject_data_out(sock, mode_data)

    done, sk, asc, has_data, auto_data = wait_completion(sock)
    recv_all_frames(sock, timeout=0.3)
    sense_sk, sense_asc, sense_ascq = query_sense(sock)
    if sense_sk is not None:
        if sense_sk == 0:
            print(f"  Sense: GOOD")
        else:
            print(f"  Sense: {sense_sk:X}/{sense_asc:02X}/{sense_ascq:02X}")
    return done


def send_set_window(sock, window_data):
    """SET WINDOW (opcode 0x24) — data-out command (80 bytes typical)."""
    print(f"\n=== SET WINDOW ({len(window_data)} bytes) ===")

    xfer_len = len(window_data)
    cdb = bytes([
        0x24,
        0x00, 0x00, 0x00, 0x00, 0x00,
        (xfer_len >> 16) & 0xFF,
        (xfer_len >> 8) & 0xFF,
        xfer_len & 0xFF,
        0x80,  # Nikon control flag
    ])
    send_frame(sock, 0x01, cdb)

    # Inject the window descriptor as data-out
    if window_data:
        inject_data_out(sock, window_data)

    done, sk, asc, has_data, auto_data = wait_completion(sock)
    recv_all_frames(sock, timeout=0.3)
    sense_sk, sense_asc, sense_ascq = query_sense(sock)
    if sense_sk is not None:
        if sense_sk == 0:
            print(f"  Sense: GOOD")
        else:
            print(f"  Sense: {sense_sk:X}/{sense_asc:02X}/{sense_ascq:02X}")
    return done


def build_default_window_descriptor():
    """Build a minimal 80-byte Nikon window descriptor for SET WINDOW."""
    wd = bytearray(80)
    # Window parameter header (8 bytes)
    wd[0:2] = b'\x00\x00'  # Reserved
    wd[6:8] = struct.pack(">H", 72)  # Window descriptor length = 72

    # Window descriptor (72 bytes starting at offset 8)
    # [8] Window ID = 0
    wd[8] = 0x00
    # [10-11] X resolution = 300 DPI
    struct.pack_into(">H", wd, 10, 300)
    # [12-13] Y resolution = 300 DPI
    struct.pack_into(">H", wd, 12, 300)
    # [14-17] X upper left = 0
    # [18-21] Y upper left = 0
    # [22-25] Width = 1 inch = 1200 (in 1/1200 inch units)
    struct.pack_into(">I", wd, 22, 1200)
    # [26-29] Height = 1 inch = 1200
    struct.pack_into(">I", wd, 26, 1200)
    # [30] Brightness = 128
    wd[30] = 128
    # [31] Threshold = 128
    wd[31] = 128
    # [32] Contrast = 128
    wd[32] = 128
    # [33] Image composition = 5 (RGB)
    wd[33] = 5
    # [34] Bits per pixel = 8
    wd[34] = 8
    # [46] Padding type = 0
    # Nikon extensions start at higher offsets
    return bytes(wd)


def send_reserve(sock):
    """RESERVE (opcode 0x16) — claim exclusive access."""
    print("\n=== RESERVE ===")
    cdb = bytes([0x16, 0x00, 0x00, 0x00, 0x00, 0x00])
    send_frame(sock, 0x01, cdb)
    done, sk, asc, has_data, auto_data = wait_completion(sock)
    recv_all_frames(sock, timeout=0.3)
    sense_sk, sense_asc, sense_ascq = query_sense(sock)
    if sense_sk == 0:
        print("  Result: GOOD")
        return True
    else:
        print(f"  Result: {sense_sk:X}/{sense_asc:02X}/{sense_ascq:02X}")
        return False


def send_diagnostic(sock):
    """SEND DIAGNOSTIC (opcode 0x1D) — self test / calibration."""
    print("\n=== SEND DIAGNOSTIC ===")
    cdb = bytes([0x1D, 0x04, 0x00, 0x00, 0x00, 0x00])  # SelfTest bit
    send_frame(sock, 0x01, cdb)
    done, sk, asc, has_data, auto_data = wait_completion(sock)
    recv_all_frames(sock, timeout=0.3)
    sense_sk, sense_asc, sense_ascq = query_sense(sock)
    if sense_sk == 0:
        print("  Result: GOOD")
        return True
    else:
        print(f"  Result: {sense_sk:X}/{sense_asc:02X}/{sense_ascq:02X}")
        return False


def send_get_window(sock, alloc_len=88):
    """GET WINDOW (opcode 0x25) — read back window descriptor."""
    print(f"\n=== GET WINDOW (alloc_len={alloc_len}) ===")
    cdb = bytes([
        0x25, 0x00, 0x00, 0x00, 0x00, 0x00,
        (alloc_len >> 16) & 0xFF,
        (alloc_len >> 8) & 0xFF,
        alloc_len & 0xFF,
        0x00,
    ])
    send_frame(sock, 0x01, cdb)
    done, sk, asc, has_data, auto_data = wait_completion(sock)
    data = collect_data_in(sock, auto_data)
    if data:
        print(f"  Response: {len(data)} bytes")
        hex_dump(data[:48])  # First 48 bytes
    else:
        print("  No data-in response")
    return data


def send_scan(sock, op_type=0):
    """SCAN (opcode 0x1B) — initiate scan."""
    print(f"\n=== SCAN (op_type={op_type}) ===")
    cdb = bytes([0x1B, 0x00, 0x00, 0x00, op_type, 0x00])
    send_frame(sock, 0x01, cdb)
    done, sk, asc, has_data, auto_data = wait_completion(sock)
    recv_all_frames(sock, timeout=0.3)
    sense_sk, sense_asc, sense_ascq = query_sense(sock)
    if sense_sk == 0:
        print("  Result: GOOD (scan started)")
        return True
    else:
        print(f"  Result: {sense_sk:X}/{sense_asc:02X}/{sense_ascq:02X}")
        return False


def send_read(sock, dtc, qualifier=0, xfer_len=4096):
    """READ(10) (opcode 0x28) — read data by DTC."""
    print(f"\n=== READ DTC=0x{dtc:02X} q={qualifier} len={xfer_len} ===")
    cdb = bytes([
        0x28, 0x00,
        dtc,
        0x00, 0x00,
        qualifier,
        (xfer_len >> 16) & 0xFF,
        (xfer_len >> 8) & 0xFF,
        xfer_len & 0xFF,
        0x80,  # Control
    ])
    send_frame(sock, 0x01, cdb)
    done, sk, asc, has_data, auto_data = wait_completion(sock)
    data = collect_data_in(sock, auto_data)
    sense_sk, sense_asc, sense_ascq = query_sense(sock)
    if data:
        print(f"  Response: {len(data)} bytes")
        if len(data) <= 64:
            hex_dump(data)
    if sense_sk and sense_sk != 0:
        print(f"  Sense: {sense_sk:X}/{sense_asc:02X}/{sense_ascq:02X}")
    return data


def send_write(sock, dtc, qualifier=0, data=b""):
    """WRITE(10) (opcode 0x2A) — write data by DTC."""
    print(f"\n=== WRITE DTC=0x{dtc:02X} q={qualifier} len={len(data)} ===")
    xfer_len = len(data)
    cdb = bytes([
        0x2A, 0x00,
        dtc,
        0x00, 0x00,
        qualifier,
        (xfer_len >> 16) & 0xFF,
        (xfer_len >> 8) & 0xFF,
        xfer_len & 0xFF,
        0x00,
    ])
    send_frame(sock, 0x01, cdb)
    # Inject data-out
    if data:
        inject_data_out(sock, data)
    done, sk, asc, has_data, auto_data = wait_completion(sock)
    recv_all_frames(sock, timeout=0.3)
    sense_sk, sense_asc, sense_ascq = query_sense(sock)
    if sense_sk == 0:
        print("  Result: GOOD")
        return True
    else:
        print(f"  Result: {sense_sk:X}/{sense_asc:02X}/{sense_ascq:02X}")
        return False


def run_init_sequence(sock):
    """Run the full NikonScan initialization sequence."""
    print("=" * 60)
    print("COOLSCAN EMULATOR — PHASE 4 SCSI INIT SEQUENCE TEST")
    print("=" * 60)

    # 1. TEST UNIT READY
    tur_ok = send_tur(sock)
    if not tur_ok:
        print("\nTUR failed — scanner not ready, aborting sequence")
        return

    # 2. INQUIRY (standard)
    inq_data = send_inquiry(sock)

    # 3. REQUEST SENSE
    send_request_sense(sock)

    # 4. MODE SENSE page 0x03 (device-specific parameters)
    send_mode_sense(sock, page_code=0x03)

    # 5. MODE SENSE page 0x3F (all pages)
    send_mode_sense(sock, page_code=0x3F, alloc_len=255)

    # 6. MODE SELECT (send back mode data — minimal)
    # Build a minimal mode parameter block
    mode_data = bytes([
        0x00,  # Mode data length (ignored for MODE SELECT)
        0x00,  # Medium type
        0x00,  # Device-specific parameter
        0x00,  # Block descriptor length
    ])
    send_mode_select(sock, mode_data)

    # 7. SET WINDOW (scan parameters)
    window = build_default_window_descriptor()
    send_set_window(sock, window)

    print("\n" + "=" * 60)
    print("INIT SEQUENCE COMPLETE")
    print("=" * 60)


def run_scan_sequence(sock):
    """Run the full scan sequence: init + reserve + calibrate + scan + read image data."""
    print("=" * 60)
    print("COOLSCAN EMULATOR — PHASE 5 FULL SCAN SEQUENCE TEST")
    print("=" * 60)

    # 1. TUR
    if not send_tur(sock):
        print("\nTUR failed — aborting")
        return

    # 2. INQUIRY
    send_inquiry(sock)

    # 3. REQUEST SENSE (clear any pending)
    send_request_sense(sock)

    # 4. RESERVE (exclusive access)
    send_reserve(sock)

    # 5. MODE SELECT
    mode_data = bytes([0x00, 0x00, 0x00, 0x00])
    send_mode_select(sock, mode_data)

    # 6. SEND DIAGNOSTIC (self-test / calibration)
    send_diagnostic(sock)

    # 7. SET WINDOW (configure scan: 300 DPI, 1x1 inch, 8-bit RGB)
    window = build_default_window_descriptor()
    send_set_window(sock, window)

    # 8. GET WINDOW (verify settings)
    send_get_window(sock)

    # 9. READ scan parameters
    send_read(sock, dtc=0x87, xfer_len=24)

    # 10. READ calibration boundary
    send_read(sock, dtc=0x88, qualifier=0x00, xfer_len=644)

    # 11. WRITE gamma LUT (identity)
    lut = bytes(range(256)) * 3  # 768 bytes: R, G, B identity LUTs
    send_write(sock, dtc=0x03, qualifier=0x00, data=lut)

    # 12. SCAN (initiate)
    if not send_scan(sock, op_type=0):
        print("\nSCAN failed — aborting")
        return

    # 13. READ image data in chunks
    print("\n=== READING IMAGE DATA ===")
    total_bytes = 0
    chunk_count = 0
    while True:
        data = send_read(sock, dtc=0x00, qualifier=0x00, xfer_len=4096)
        if not data:
            break
        total_bytes += len(data)
        chunk_count += 1
        print(f"  Chunk {chunk_count}: {len(data)} bytes (total: {total_bytes})")
        if len(data) < 4096:
            # Short read = last chunk
            break

    print(f"\n  Total image data: {total_bytes} bytes in {chunk_count} chunks")

    # 14. Final REQUEST SENSE
    send_request_sense(sock)

    print("\n" + "=" * 60)
    print(f"SCAN SEQUENCE COMPLETE — {total_bytes} bytes of image data retrieved")
    print("=" * 60)


def main():
    port = int(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_PORT
    mode = sys.argv[2] if len(sys.argv) > 2 else "init"

    print(f"Connecting to 127.0.0.1:{port}...")
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.connect(("127.0.0.1", port))
    print("Connected!")

    # Give the emulator time to reach main loop
    time.sleep(0.5)

    if mode == "init":
        run_init_sequence(sock)
    elif mode == "scan":
        run_scan_sequence(sock)
    elif mode == "tur":
        send_tur(sock)
    elif mode == "inquiry":
        send_inquiry(sock)
    elif mode == "sense":
        send_request_sense(sock)
    elif mode == "modesense":
        send_mode_sense(sock)
    else:
        print(f"Unknown mode: {mode}")
        print("Usage: tcp_test_client.py [port] [init|tur|inquiry|sense|modesense|scan]")

    sock.close()
    print("\nDone.")


if __name__ == "__main__":
    main()
