"""List and extract the CAR: files of an EOS cartridge image (EOS.car).

Usage:
  python carfs.py list    EOS.car [PATTERN]
  python carfs.py extract EOS.car NAME.EXT OUT_FILE
  python carfs.py extract-all EOS.car OUT_DIR

The CAR: directory entries are 24 bytes:
  bank, $08 (in use), offset in the 8 KB bank (2), size (3),
  name (8), extension (3), date (3), time (3)
found by scanning the image (this is reverse engineered, not from a
specification: check what you extract).
"""
import fnmatch
import os
import re
import sys

ENTRY = re.compile(rb"([\x00-\x7f])\x08(..)(...)([A-Z0-9_ ]{8})([A-Z0-9_ ]{3})(...)(...)", re.S)


def entries(data):
    seen = set()
    for m in ENTRY.finditer(data):
        bank = m.group(1)[0]
        off = int.from_bytes(m.group(2), "little")
        size = int.from_bytes(m.group(3), "little")
        name = m.group(4).decode().rstrip()
        ext = m.group(5).decode().rstrip()
        if not name or off >= 0x2000 or size == 0 or size > 0x40000:
            continue
        full = name + ("." + ext if ext else "")
        if full in seen:
            continue
        seen.add(full)
        yield full, bank, off, size


def file_data(data, bank, off, size):
    start = bank * 0x2000 + off
    return data[start:start + size]


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(1)
    data = open(sys.argv[2], "rb").read()
    if data[:4] == b"CART":
        data = data[16:]
    if sys.argv[1] == "list":
        pat = sys.argv[3] if len(sys.argv) > 3 else "*"
        for full, bank, off, size in entries(data):
            if fnmatch.fnmatch(full, pat):
                print("%-12s bank %3d  offset $%04X  %6d bytes" % (full, bank, off, size))
    elif sys.argv[1] == "extract":
        want = sys.argv[3].upper()
        for full, bank, off, size in entries(data):
            if full == want:
                open(sys.argv[4], "wb").write(file_data(data, bank, off, size))
                print("wrote", sys.argv[4], size, "bytes")
                return
        sys.exit("not found: " + want)
    elif sys.argv[1] == "extract-all":
        out = sys.argv[3]
        os.makedirs(out, exist_ok=True)
        for full, bank, off, size in entries(data):
            dest = os.path.join(out, full)
            open(dest, "wb").write(file_data(data, bank, off, size))
            print(full, size)


if __name__ == "__main__":
    main()
