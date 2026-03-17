#!/usr/bin/env python3
"""TCP test client for the Coolscan emulator bridge.

Frame protocol:
  [2B length BE] [1B type] [payload]

Host->Emulator types:
  0x01 = CDB (up to 32 bytes)
  0x02 = Phase Query
  0x04 = Sense Query

Emulator->Host types:
  0x81 = Phase Byte (1 byte)
  0x82 = Data In (variable)
  0x83 = Sense Data (18 bytes)
"""

import socket
import struct
import sys
import time

DEFAULT_PORT = 6581

def send_frame(sock, msg_type, payload=b""):
    header = struct.pack(">HB", len(payload), msg_type)
    sock.sendall(header + payload)

def recv_frame(sock, timeout=5.0):
    sock.settimeout(timeout)
    try:
        header = sock.recv(3)
        if len(header) < 3:
            return None, None
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

def send_tur(sock):
    """Send TEST UNIT READY CDB [00 00 00 00 00 00]"""
    print("Sending TEST UNIT READY...")
    cdb = bytes(6)  # All zeros
    send_frame(sock, 0x01, cdb)

def send_inquiry(sock):
    """Send INQUIRY CDB [12 00 00 00 24 00]"""
    print("Sending INQUIRY...")
    cdb = bytes([0x12, 0x00, 0x00, 0x00, 0x24, 0x00])
    send_frame(sock, 0x01, cdb)

def send_phase_query(sock):
    """Send phase query (0xD0)"""
    print("Sending Phase Query...")
    send_frame(sock, 0x02)

def send_sense_query(sock):
    """Send sense query (0x06)"""
    print("Sending Sense Query...")
    send_frame(sock, 0x04)

def main():
    port = int(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_PORT

    print(f"Connecting to 127.0.0.1:{port}...")
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.connect(("127.0.0.1", port))
    print("Connected!")

    # Give the emulator time to init
    time.sleep(0.5)

    # Send TUR
    send_tur(sock)
    time.sleep(1.0)

    # Query phase
    send_phase_query(sock)
    msg_type, payload = recv_frame(sock, timeout=2.0)
    if msg_type:
        print(f"Response: type=0x{msg_type:02X}, {len(payload)} bytes: {payload.hex()}")
    else:
        print("No phase response received (timeout)")

    # Query sense
    send_sense_query(sock)
    msg_type, payload = recv_frame(sock, timeout=2.0)
    if msg_type:
        print(f"Sense: type=0x{msg_type:02X}, {len(payload)} bytes: {payload.hex()}")
        if len(payload) >= 14:
            sk = payload[2] & 0x0F
            asc = payload[12]
            ascq = payload[13]
            print(f"  Sense Key={sk:X}, ASC={asc:02X}, ASCQ={ascq:02X}")
    else:
        print("No sense response received (timeout)")

    sock.close()
    print("Done.")

if __name__ == "__main__":
    main()
