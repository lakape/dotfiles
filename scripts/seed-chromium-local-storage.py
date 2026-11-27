"""Write a minimal LevelDB holding Chromium Local Storage entries for one origin.

T3 Code imports the Local Storage of an older ("V1") profile once, on the first
start of a new profile, and keeps every key that already exists. t3code-speech.nix
uses this to preselect the dictation destination on a fresh install.

The files follow the LevelDB log and manifest format (CRC32C-checked records,
one write batch), which is what T3 Code's reader and LevelDB recovery expect.

Usage: seed-chromium-local-storage.py <leveldb dir> <origin> <key> <value> [<key> <value> ...]
"""

import os
import struct
import sys
import tempfile

LOG_NUMBER = 3
MANIFEST_NUMBER = 2


def crc32c(data):
    crc = 0xFFFFFFFF
    for byte in data:
        crc ^= byte
        for _ in range(8):
            crc = (crc >> 1) ^ 0x82F63B78 if crc & 1 else crc >> 1
    return crc ^ 0xFFFFFFFF


def masked_crc(data):
    crc = crc32c(data)
    return (((crc >> 15) | (crc << 17)) + 0xA282EAD8) & 0xFFFFFFFF


def log_record(payload):
    """One FULL record; it has to fit into the first 32 KiB block."""
    if len(payload) > 32768 - 7:
        sys.exit("payload too large for a single log record")
    data = b"\x01" + payload
    return struct.pack("<IH", masked_crc(data), len(payload)) + data


def varint(number):
    out = bytearray()
    while True:
        byte = number & 0x7F
        number >>= 7
        out.append(byte | (0x80 if number else 0))
        if not number:
            return bytes(out)


def length_prefixed(data):
    return varint(len(data)) + data


def chromium_string(text):
    """Chromium prefixes stored strings with 1 (Latin-1) or 0 (UTF-16LE)."""
    try:
        return b"\x01" + text.encode("latin-1")
    except UnicodeEncodeError:
        return b"\x00" + text.encode("utf-16-le")


def main():
    if len(sys.argv) < 5 or len(sys.argv) % 2 != 1:
        sys.exit(__doc__)
    directory, origin = sys.argv[1], sys.argv[2]
    items = list(zip(sys.argv[3::2], sys.argv[4::2]))

    batch = struct.pack("<QI", 1, len(items))
    for key, value in items:
        raw_key = b"_" + origin.encode() + b"\x00" + chromium_string(key)
        batch += b"\x01" + length_prefixed(raw_key) + length_prefixed(chromium_string(value))

    version_edit = (
        varint(1) + length_prefixed(b"leveldb.BytewiseComparator")
        + varint(2) + varint(LOG_NUMBER)
        + varint(3) + varint(LOG_NUMBER + 1)
        + varint(4) + varint(len(items))
    )

    parent = os.path.dirname(os.path.abspath(directory))
    os.makedirs(parent, mode=0o700, exist_ok=True)
    staging = tempfile.mkdtemp(dir=parent, prefix=".leveldb-")
    files = {
        "CURRENT": f"MANIFEST-{MANIFEST_NUMBER:06d}\n".encode(),
        f"MANIFEST-{MANIFEST_NUMBER:06d}": log_record(version_edit),
        f"{LOG_NUMBER:06d}.log": log_record(batch),
    }
    for name, data in files.items():
        with open(os.path.join(staging, name), "wb") as file:
            file.write(data)
    os.rename(staging, directory)


if __name__ == "__main__":
    main()
