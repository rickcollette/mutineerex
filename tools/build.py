"""Builds Mutineer-eX: the programs and the EOS work disk.

Usage:  python tools/build.py [--no-disk]

  build/WFC.XEX            wait-for-call module
                           (includes login/register)
  build/MAINBBS.XEX        main BBS loop
  build/MESSAGE.XEX        message bases
  build/FILES.XEX          file bases
  build/DOORS.XEX          door catalog and launcher
  build/BJACK.XEX          blackjack game door
  build/SLOTS.XEX          three-reel slot-machine door
  build/REMMS.COM          REMMS 1.10 resident serial/session manager
  drivers/RS232.COM        legacy Atari 850 post-boot loader
  build/RVRFULL.SYS        full-handshake R-Verter EOS device driver
  build/RVRTWOW.SYS        two-wire R-Verter EOS device driver
  build/NHAND.SYS          FujiNet EOS device driver
  build/TDAPE.COM          transient APETime helper
  build/CONFIG.XEX         four-part administration console
  build/INIT.XEX           one-time board initialization
  disk/mutinrex-v<VERSION>.atr  exOS 0.4 work disk (native EOSFS v2 format)

The programs are named .COM on the disk. EOS loads exactly one R: backend
from eossys.sys with DEVICE, then eosauto.bat starts REMMS.COM and WFC.COM.
exBASIC RUN chains the remaining modules.

Every screen has an ASCII text/*.txt file and a native ATASCII
text/*.ata file. Both versions are copied to disk as NAME.TXT and
NAME.ATA. See tools/atascii.py for editing the binary .ata files.
"""
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TOOLS = r"C:\Program Files\exBASIC Studio Contributors\exBASIC Studio\tools"
EXBASIC = os.environ.get("EXBASIC", os.path.join(TOOLS, "exbasic", "exbasic.exe"))
# exOS 0.4 uses native EOSFS v2 ($47) with extent maps and 44-byte directory
# entries. Keep the former 16 MiB capacity while building the filesystem from
# scratch with exOS's own writer.
DISK_SECTORS = 65535
DISK_SECTOR_SIZE = 256
ATR_SIZE = 16_776_592
PRODUCT_NAME = "Mutineer-eX"
PRODUCT_ID = "mutinrex"
VOLUME_NAME = "MUTINREX"
FORBIDDEN_BRANDS = (
    "ex" + "AMIS",
    "exA." + "M.I.S.",
    "AMIS" + " CFG",
    "AMIS" + "_exBASIC",
)


def read_version():
    """Return the release version shared by packaging and documentation."""
    with open(os.path.join(ROOT, "VERSION"), encoding="ascii") as f:
        version = f.read().strip()
    if not re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", version):
        sys.exit("VERSION must contain a semantic version such as 1.0.0")
    return version


VERSION = read_version()
ATR_RELATIVE_PATH = "disk/%s-v%s.atr" % (PRODUCT_ID, VERSION)


def audit_branding():
    """Reject retired branding in maintained source and packaged screens."""
    ignored_dirs = {".git", "build", "disk", "listings", "original", "tmp"}
    checked_suffixes = {
        ".asm", ".ata", ".bas", ".md", ".ps1", ".py", ".txt"
    }
    failures = []
    for directory, dirs, files in os.walk(ROOT):
        dirs[:] = [name for name in dirs if name not in ignored_dirs]
        for name in files:
            if os.path.splitext(name)[1].lower() not in checked_suffixes:
                continue
            filename = os.path.join(directory, name)
            with open(filename, "rb") as f:
                contents = f.read().lower()
            for retired in FORBIDDEN_BRANDS:
                if retired.lower().encode("ascii") in contents:
                    failures.append("%s contains %s" %
                                    (os.path.relpath(filename, ROOT), retired))
    if failures:
        sys.exit("retired branding remains:\n  " + "\n  ".join(failures))


def audit_packaged_branding(atr):
    """Reject retired branding in filenames or bytes shipped in the ATR."""
    volume = sdfs.Volume(atr)
    entries = volume.check()
    if volume.errors:
        sys.exit("invalid release ATR: " + "; ".join(volume.errors))
    failures = []
    for filename, entry in entries:
        candidate = filename.encode("latin-1") + b"\0" + entry.get("data", b"")
        lowered = candidate.lower()
        for retired in FORBIDDEN_BRANDS:
            if retired.lower().encode("ascii") in lowered:
                failures.append("%s contains %s" % (filename, retired))
    if failures:
        sys.exit("retired branding was packaged:\n  " + "\n  ".join(failures))

# An 8 KB bank of EOS.car is mapped at $A000-$BFFF.  In GRAPHICS 0 the
# last byte below the screen is therefore about $9C1F.  CONFIG must leave
# enough heap for every compiler string, its small fixed arrays and some
# runtime headroom; otherwise it exits with ERROR- 2 before showing a menu.
EOS_CART_MEMTOP = 0x9C1F
CONFIG_ARRAY_BYTES = 125 + 26 + 26
CONFIG_HEAP_SAFETY = 1024
WFC_ARRAY_BYTES = 1 + 1 + 26 + 26 + 13
WFC_HEAP_RESERVE = 1500

sys.path.insert(0, os.path.join(ROOT, "tools"))
import atascii  # noqa: E402
import sdfs  # noqa: E402

PROGRAMS = [
    ("src/wfc.bas", "build/WFC.XEX", "wfc.com", ["src/fixed_strings.asm"]),
    ("src/mainbbs.bas", "build/MAINBBS.XEX", "mainbbs.com", ["src/fixed_strings.asm"]),
    ("src/message_module.bas", "build/MESSAGE.XEX", "message.com", ["src/fixed_strings.asm"]),
    ("src/files_module.bas", "build/FILES.XEX", "files.com", ["src/fixed_strings.asm"]),
    ("src/doors_module.bas", "build/DOORS.XEX", "doors.com", ["src/fixed_strings.asm"]),
    ("src/door_blackjack.bas", "build/BJACK.XEX", "bjack.com", ["src/fixed_strings.asm"]),
    ("src/door_slots.bas", "build/SLOTS.XEX", "slots.com", ["src/fixed_strings.asm"]),
    ("src/config.bas", "build/CONFIG.XEX", "config.com", []),
    ("src/init.bas", "build/INIT.XEX", "init.com", []),
]
SCREENS = ["WFC", "WELC", "BULL", "FUNC", "HELP", "MESGM", "FILEM",
           "NEWU"]
ATASCII_DOWNLOADS = [("TEST.UDL.txt", "TEST.TT1")]
FILE_CATALOG = ("FILES.dat", "FILES.DAT")
DOOR_CATALOG = ("DOORS.dat", "DOORS.DAT")
HIGH_SCORE_FILES = [("BJHI10.txt", "BJHI10.TXT"),
                    ("SLOTHI10.txt", "SLOTHI10.TXT")]
DRIVER_FILES = [
    ("drivers/RS232.COM", "rs232.com"),
    # exOS DEVICE appends lowercase `.sys`; native EOSFS names are case
    # sensitive, so the on-disk extensions must match exactly.
    ("build/RVRFULL.SYS", "rvrfull.sys"),
    ("build/RVRTWOW.SYS", "rvrtwow.sys"),
    ("build/NHAND.SYS", "nhand.sys"),
    ("build/REMMS.COM", "remms.com"),
    ("build/TDAPE.COM", "tdape.com"),
]
TOOLKIT_FILES = [("/apetime.com", "apetime.com")]
EOS_TOOLKIT = "RESOURCES/EOSTK.atr"
# CONFIG rewrites this as DEVICE RTIME8 when that clock source is selected.
# JIFFY is the safe initial driver because it needs no optional RTC hardware.
EOS_SYSTEM_FILES = [
    ("eossys.sys", b"SET PATH=CAR:;D1:\x9bDEVICE JIFFY\x9b"),
    ("eosauto.bat", b"SET PATH=CAR:;D1:\x9b"),
]


def path(rel):
    return os.path.join(ROOT, *rel.split("/"))


def toolkit_file(name):
    """Read one file from the exOS release's native EOSFS toolkit disk."""
    volume = sdfs.Volume(path(EOS_TOOLKIT))
    for filename, entry in volume.check():
        if filename.lower() == name.lower() and not entry["status"] & sdfs.ST_DIR:
            if volume.errors:
                sys.exit("invalid exOS toolkit image: " + "; ".join(volume.errors))
            return entry["data"]
    sys.exit("missing %s in %s" % (name, EOS_TOOLKIT))


MADS = os.environ.get("MADS", path("tools/mads.exe"))


def compile_program(src, out, modules):
    cmd = [EXBASIC, "-t:atari", "-I:" + path("src"), "-I:" + path("lib"),
           "-o", path(out)]
    # REMMS 1.10 occupies $1E00-$3CFE. The live BBS modules load above it;
    # CONFIG and INIT run before REMMS (or after WFC quits) and keep their
    # lower address because CONFIG needs the extra EOS-cartridge heap.
    if src not in ("src/config.bas", "src/init.bas"):
        cmd.append("-S:16384")
    if src == "src/message_module.bas":
        # The message editor is just over the address-space limit when its
        # hottest paths are expanded to native 6502; bytecode is smaller.
        cmd.append("-no-native")
    if src == "src/wfc.bas":
        # EOS keeps its cartridge mapped at $A000-$BFFF while starting WFC.
        # exBASIC allocates default string storage before BASIC can call the
        # compact-string binder, so the native-heavy image crosses MEMTOP and
        # exits to EOS with ERROR- 2.  Bytecode leaves startup headroom while
        # preserving the REMMS ABI and all WFC behavior.
        cmd.append("-no-native")
    # Keep debugger symbols/listings for the two programs whose available
    # memory is constrained by the mapped EOS cartridge.  WFC's symbols are
    # also the canonical address map for diagnosing the startup ERROR- 2.
    if out in ("build/CONFIG.XEX", "build/WFC.XEX"):
        cmd.append("-g")
    cmd += [path(src)] + [path(module) for module in modules]
    print(">", os.path.basename(src))
    result = subprocess.run(cmd, capture_output=True, text=True)
    for line in (result.stdout + result.stderr).splitlines():
        if not line.startswith(("BAS compile", "ASM assemble", "LINK")):
            print("  " + line)
    if result.returncode != 0:
        sys.exit("compile failed: " + src)


def assemble(source, output, defines=()):
    """Assemble one REMMS component, retaining labels/listing for audits."""
    stem = os.path.splitext(os.path.basename(output))[0]
    cmd = [MADS, os.path.basename(source)]
    cmd += ["-d:" + define for define in defines]
    cmd += ["-o:" + path(output),
            "-l:" + path("build/" + stem + ".lst"),
            "-t:" + path("build/" + stem + ".lab")]
    print("> " + os.path.basename(source))
    result = subprocess.run(cmd, cwd=path(os.path.dirname(source)),
                            capture_output=True, text=True)
    for line in (result.stdout + result.stderr).splitlines():
        if line.strip():
            print("  " + line)
    if result.returncode != 0:
        sys.exit("compile failed: " + source)


def compile_remms():
    """Build the matched REMMS 1.10 core and every EOS R: backend."""
    assemble("RESOURCES/REMMS/src/remms_sdx.asm", "build/REMMS.COM")
    assemble("RESOURCES/REMMS/rverter/rvrhand.asm", "build/RVRFULL.SYS",
             ("RVR_FULL=1",))
    assemble("RESOURCES/REMMS/rverter/rvrhand.asm", "build/RVRTWOW.SYS",
             ("RVR_FULL=0",))
    assemble("RESOURCES/REMMS/nhand/nhand.asm", "build/NHAND.SYS")
    assemble("RESOURCES/REMMS/td/tdape.asm", "build/TDAPE.COM")


def verify_config_heap():
    """Reject CONFIG builds that cannot run while EOS.car is mapped."""
    with open(path("build/CONFIG.lbl"), encoding="ascii") as f:
        labels = f.read()
    match = re.search(r"^al ([0-9A-Fa-f]{6}) \.EXB_FREE$", labels, re.MULTILINE)
    if not match:
        sys.exit("can't find EXB_FREE in build/CONFIG.lbl")
    free_start = int(match.group(1), 16)

    with open(path("build/CONFIG.lst"), encoding="utf-8") as f:
        string_count = sum("; string variable" in line for line in f)
    required = string_count * 256 + CONFIG_ARRAY_BYTES + CONFIG_HEAP_SAFETY
    available = EOS_CART_MEMTOP + 1 - free_start
    if required > available:
        sys.exit("CONFIG needs %d heap bytes but EOS.car leaves %d; "
                 "reduce arrays or strings" % (required, available))
    print("  EOS cartridge heap margin: %d bytes" % (available - required))


def verify_wfc_heap():
    """Ensure WFC reaches its EOS-aware dynamic-buffer allocation safely."""
    with open(path("build/WFC.lbl"), encoding="ascii") as f:
        labels = f.read()
    match = re.search(r"^al ([0-9A-Fa-f]{6}) \.EXB_FREE$", labels, re.MULTILINE)
    if not match:
        sys.exit("can't find EXB_FREE in build/WFC.lbl")
    free_start = int(match.group(1), 16)
    available = EOS_CART_MEMTOP + 1 - free_start
    before_buffer = available - WFC_ARRAY_BYTES
    # module_env selects FRE()-1500 only above 1756; below that threshold it
    # falls back to 256 bytes. Reject a WFC that silently loses the intended
    # EOS reserve before it can allocate Buf.
    if before_buffer <= WFC_HEAP_RESERVE + 256:
        sys.exit("WFC has only %d bytes before Buf under EOS; reduce its "
                 "linked image" % before_buffer)
    print("  EOS WFC pre-buffer heap: %d bytes; runtime reserve: %d" %
          (before_buffer, WFC_HEAP_RESERVE))


def main():
    audit_branding()
    os.makedirs(path("build"), exist_ok=True)
    compile_remms()
    for src, out, _, modules in PROGRAMS:
        compile_program(src, out, modules)
        if out == "build/WFC.XEX":
            verify_wfc_heap()
        if out == "build/CONFIG.XEX":
            verify_config_heap()
    if "--no-disk" in sys.argv:
        return
    stage = path("build/disk")
    if os.path.isdir(stage):
        for old in os.listdir(stage):
            os.remove(os.path.join(stage, old))
    os.makedirs(stage, exist_ok=True)
    files = []
    for _, out, name, _ in PROGRAMS:
        dest = os.path.join(stage, name)
        with open(path(out), "rb") as f, open(dest, "wb") as g:
            g.write(f.read())
        files.append(dest)
    for source_name, disk_name in DRIVER_FILES:
        dest = os.path.join(stage, disk_name)
        with open(path(source_name), "rb") as f, open(dest, "wb") as g:
            g.write(f.read())
        files.append(dest)
    for source_name, disk_name in TOOLKIT_FILES:
        dest = os.path.join(stage, disk_name)
        with open(dest, "wb") as g:
            g.write(toolkit_file(source_name))
        files.append(dest)
    for name in SCREENS:
        # Host .txt uses normal newlines. Disk ASCII uses CR so the
        # caller's optional R: line-feed setting remains authoritative.
        with open(path("text/" + name + ".txt"), encoding="ascii") as f:
            ascii_data = f.read().replace("\r\n", "\n").replace("\r", "\n")
        dest = os.path.join(stage, name + ".TXT")
        with open(dest, "wb") as g:
            g.write(ascii_data.replace("\n", "\r").encode("ascii"))
        files.append(dest)
        dest = os.path.join(stage, name + ".ATA")
        template = path("text/" + name + ".ata.txt")
        if os.path.exists(template):
            with open(template, encoding="ascii") as f, open(dest, "wb") as g:
                g.write(atascii.to_atari(f.read()))
        else:
            with open(path("text/" + name + ".ata"), "rb") as f, open(dest, "wb") as g:
                g.write(f.read())
        files.append(dest)
    for source_name, disk_name in ATASCII_DOWNLOADS:
        dest = os.path.join(stage, disk_name)
        with open(path("text/" + source_name), encoding="ascii") as f, open(dest, "wb") as g:
            g.write(atascii.to_atari(f.read()))
        files.append(dest)
    source_name, disk_name = FILE_CATALOG
    dest = os.path.join(stage, disk_name)
    with open(path("text/" + source_name), encoding="ascii") as f, open(dest, "wb") as g:
        g.write(atascii.to_atari(f.read()))
    files.append(dest)
    source_name, disk_name = DOOR_CATALOG
    dest = os.path.join(stage, disk_name)
    with open(path("text/" + source_name), encoding="ascii") as f, open(dest, "wb") as g:
        g.write(atascii.to_atari(f.read()))
    files.append(dest)
    for source_name, disk_name in HIGH_SCORE_FILES:
        dest = os.path.join(stage, disk_name)
        with open(path("text/" + source_name), encoding="ascii") as f, open(dest, "wb") as g:
            g.write(atascii.to_atari(f.read()))
        files.append(dest)
    for disk_name, contents in EOS_SYSTEM_FILES:
        dest = os.path.join(stage, disk_name)
        with open(dest, "wb") as g:
            g.write(contents)
        files.append(dest)
    os.makedirs(path("disk"), exist_ok=True)
    atr = path(ATR_RELATIVE_PATH)
    print("> " + ATR_RELATIVE_PATH)
    contents = {}
    for filename in files:
        with open(filename, "rb") as f:
            contents[os.path.basename(filename)] = f.read()
    sdfs.build(atr, DISK_SECTORS, DISK_SECTOR_SIZE, contents,
               volname=VOLUME_NAME, eosfs=True)
    if os.path.getsize(atr) != ATR_SIZE:
        sys.exit("wrong ATR size after template build")
    audit_packaged_branding(atr)


if __name__ == "__main__":
    main()
