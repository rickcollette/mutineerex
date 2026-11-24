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
  drivers/RHND850.COM      Atari 850 resident R: handler
  drivers/RS232.COM        legacy Atari 850 bootstrap retained for reference
  build/RVRFULL.SYS        full-handshake R-Verter EOS device driver
  build/RVRTWOW.SYS        two-wire R-Verter EOS device driver
  build/NHAND.SYS          FujiNet EOS device driver
  build/TDAPE.COM          transient APETime helper
  build/CONFIG.XEX         four-part administration console
  build/RDCONF.XEX         RAM-disk capacity planner and file picker
  build/INIT.XEX           one-time board initialization
  disk/mutinrex-eos-v<VERSION>.atr  exOS work disk (native EOSFS v2 format)
  disk/mutinrex-sdx-v<VERSION>.atr  SpartaDOS X work disk (SDFS 2.1 format)

The programs use lowercase .com names on the case-sensitive EOSFS disk. EOS
loads exactly one R: backend from eossys.sys with DEVICE, then eosauto.bat
starts remms.com and wfc.com.
The SDX image packages the same relocatable backends as uppercase .COM files.
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
_TOOL_ROOTS = (
    r"C:\Program Files\exBASIC Studio Contributors\exBASIC Studio\tools",
    os.path.expandvars(r"%LOCALAPPDATA%\Programs\exBASIC Studio\tools"),
    os.path.expandvars(r"%LOCALAPPDATA%\Programs\exBASIC Studio personal-rick\tools"),
)
TOOLS = next((candidate for candidate in _TOOL_ROOTS
              if os.path.isdir(candidate)), _TOOL_ROOTS[0])
EXBASIC = os.environ.get("EXBASIC", os.path.join(TOOLS, "exbasic", "exbasic.exe"))
# exOS 0.4 uses native EOSFS v2 ($47) with extent maps and 44-byte directory
# entries. Keep the former 16 MiB capacity while reproducing the metadata and
# boot sectors emitted by exOS FORMAT.
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
EOS_ATR_RELATIVE_PATH = "disk/%s-eos-v%s.atr" % (PRODUCT_ID, VERSION)
SDX_ATR_RELATIVE_PATH = "disk/%s-sdx-v%s.atr" % (PRODUCT_ID, VERSION)
SOURCE_VERSION = re.compile(rb"Mutineer-eX ([0-9]+\.[0-9]+\.[0-9]+)")


def audit_source_versions():
    """Keep compiled on-screen banners aligned with the release artifact."""
    failures = []
    source_root = os.path.join(ROOT, "src")
    for name in sorted(os.listdir(source_root)):
        if not name.lower().endswith(".bas"):
            continue
        filename = os.path.join(source_root, name)
        with open(filename, "rb") as f:
            contents = f.read()
        for match in SOURCE_VERSION.finditer(contents):
            found = match.group(1).decode("ascii")
            if found != VERSION:
                failures.append("src/%s displays %s" % (name, found))
    text_root = os.path.join(ROOT, "text")
    for name in sorted(os.listdir(text_root)):
        if not name.lower().endswith(".txt"):
            continue
        filename = os.path.join(text_root, name)
        with open(filename, "rb") as f:
            contents = f.read()
        for match in SOURCE_VERSION.finditer(contents):
            found = match.group(1).decode("ascii")
            if found != VERSION:
                failures.append("text/%s displays %s" % (name, found))
    if failures:
        sys.exit("source banners do not match VERSION %s:\n  %s\n"
                 "run tools/build_all.py so the release bump updates them" %
                 (VERSION, "\n  ".join(failures)))


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


def audit_packaged_branding(atr, expect_eos):
    """Reject malformed filesystem metadata and retired packaged branding."""
    volume = sdfs.Volume(atr)
    entries = volume.check()
    if volume.errors:
        sys.exit("invalid release ATR: " + "; ".join(volume.errors))
    failures = []
    if volume.eosfs != expect_eos:
        failures.append("filesystem is %s, expected %s" %
                        ("EOSFS" if volume.eosfs else "SDFS",
                         "EOSFS" if expect_eos else "SDFS"))
    if expect_eos:
        expected_mapents = (volume.seclen - 4) // 4
        if volume.header_mapents != expected_mapents:
            failures.append("EOSFS header has %d extent slots, expected %d" %
                            (volume.header_mapents, expected_mapents))
        boot = (volume.img.sector(1) + volume.img.sector(2) +
                volume.img.sector(3))
        expected_boot = sdfs.EOSFS_BOOTCODE
        if (boot[6:9] != expected_boot[6:9] or
                boot[44:] != expected_boot[44:]):
            failures.append("EOSFS boot sectors do not match EOS FORMAT")
    elif volume.version != 0x21:
        failures.append("SDFS revision is $%02X, expected $21" % volume.version)
    alloc_hint = volume.boot[18] | volume.boot[19] << 8
    if alloc_hint and alloc_hint in volume.bitmap_used():
        failures.append("EOSFS allocation hint points at used sector %d" %
                        alloc_hint)
    for filename, entry in entries:
        candidate = filename.encode("latin-1") + b"\0" + entry.get("data", b"")
        lowered = candidate.lower()
        for retired in FORBIDDEN_BRANDS:
            if retired.lower().encode("ascii") in lowered:
                failures.append("%s contains %s" % (filename, retired))
    if failures:
        sys.exit("invalid release ATR:\n  " + "\n  ".join(failures))

# An 8 KB bank of EOS.car is mapped at $A000-$BFFF.  In GRAPHICS 0 the
# last byte below the screen is therefore about $9C1F.  CONFIG must leave
# enough heap for every compiler string, its small fixed arrays and some
# runtime headroom; otherwise it exits with ERROR- 2 before showing a menu.
EOS_CART_MEMTOP = 0x9C1F
CONFIG_ARRAY_BYTES = 125 + 26 + 26
CONFIG_HEAP_SAFETY = 1024
WFC_ARRAY_BYTES = 1 + 1 + 26 + 26 + 13
WFC_HEAP_RESERVE = 2300
RDCONF_ARRAY_BYTES = 4608 + 192 + 96 + 255 + 3
RDCONF_HEAP_SAFETY = 2048

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
    ("src/rdconf.bas", "build/RDCONF.XEX", "rdconf.com", ["src/rdconf_strings.asm"]),
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
    ("drivers/RHND850.COM", "rhnd850.com"),
    ("drivers/RS232.COM", "rs232.com"),
    # exOS DEVICE appends lowercase `.sys`; native EOSFS names are case
    # sensitive, so the on-disk extensions must match exactly.
    ("build/RVRFULL.SYS", "RVRFULL.sys"),
    ("build/RVRTWOW.SYS", "RVRTWOW.sys"),
    ("build/NHAND.SYS", "NHAND.sys"),
    ("build/REMMS.COM", "remms.com"),
    ("build/TDAPE.COM", "tdape.com"),
]
SDX_DRIVER_RENAMES = {
    "RVRFULL.sys": "RVRFULL.COM",
    "RVRTWOW.sys": "RVRTWOW.COM",
    "NHAND.sys": "NHAND.COM",
}
TOOLKIT_FILES = [("/apetime.com", "apetime.com")]
EOS_TOOLKIT = "RESOURCES/EOSTK.atr"
# CONFIG rewrites this as DEVICE RTIME8 when that clock source is selected.
# JIFFY is the safe initial driver because it needs no optional RTC hardware.
EOS_SYSTEM_FILES = [
    ("eossys.sys", b"SET PATH=CAR:;D1:\x9bDEVICE JIFFY\x9b"),
    ("eosauto.bat", b"SET PATH=CAR:;D1:\x9b"),
]
EOS_PLATFORM_MARKER = ("EOS.ENV", b"MUTINREX EOS 1\x9b")
SDX_PLATFORM_MARKER = ("SDX.ENV", b"MUTINREX SDX 1\x9b")
def ramcache_default(target_prefix):
    """Build explicit source-to-runtime cache mappings for one platform."""
    sources = [
        "D1:wfc.com", "D1:mainbbs.com", "D1:message.com",
        "D1:files.com", "D1:doors.com", "D1:bjack.com", "D1:slots.com",
    ]
    sources += [
        "D1:%s.%s" % (name, extension)
        for name in SCREENS for extension in ("TXT", "ATA")
    ]
    lines = ["MUTINREX RAMCACHE 2"]
    lines += [source + "|" + target_prefix + source.split(":", 1)[1]
              for source in sources]
    return ("\x9b".join(lines) + "\x9b").encode("latin-1")


SHARED_CONFIG_FILES = []


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
    if src == "src/files_module.bas":
        # The automatic optimizer probes six layouts.  Its native-all and
        # hot-with-extended-instructions candidates cannot fit below $BC20,
        # so they emit ld65 overflow errors before the successful candidate.
        # Select that known-good candidate directly: one link, no false
        # overflow diagnostics, and the same hot-path native code as before.
        cmd += ["-native:hot", "-no-ext"]
    if src == "src/wfc.bas":
        # EOS keeps its cartridge mapped at $A000-$BFFF while starting WFC.
        # exBASIC allocates default string storage before BASIC can call the
        # compact-string binder, so the native-heavy image crosses MEMTOP and
        # exits to EOS with ERROR- 2.  Bytecode leaves startup headroom while
        # preserving the REMMS ABI and all WFC behavior.
        cmd.append("-no-native")
    if src == "src/rdconf.bas":
        # RDCONF runs while the EOS cartridge is mapped and holds the full
        # candidate table plus directory strings.  Bytecode leaves about
        # 1.3 KB more runtime heap than the optimizer's mixed native image.
        cmd.append("-no-native")
    # Keep debugger symbols/listings for the two programs whose available
    # memory is constrained by the mapped EOS cartridge.  WFC's symbols are
    # also the canonical address map for diagnosing the startup ERROR- 2.
    if out in ("build/CONFIG.XEX", "build/WFC.XEX", "build/RDCONF.XEX"):
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
    """Build the matched REMMS 1.10 core and every R: backend."""
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
    # Every module keeps this transient headroom for manifest lookups and
    # module handoff; WFC is the smallest-heap build and therefore the audit.
    if before_buffer <= WFC_HEAP_RESERVE + 256:
        sys.exit("WFC has only %d bytes before Buf under EOS; reduce its "
                 "linked image" % before_buffer)
    print("  EOS WFC pre-buffer heap: %d bytes; runtime reserve: %d" %
          (before_buffer, WFC_HEAP_RESERVE))


def verify_rdconf_heap():
    """Keep RDCONF clear of ERROR-2 with SDX/EOS and handlers resident."""
    with open(path("build/RDCONF.lbl"), encoding="ascii") as f:
        labels = f.read()
    match = re.search(r"^al ([0-9A-Fa-f]{6}) \.EXB_FREE$", labels, re.MULTILINE)
    if not match:
        sys.exit("can't find EXB_FREE in build/RDCONF.lbl")
    free_start = int(match.group(1), 16)
    available = EOS_CART_MEMTOP + 1 - free_start
    required = RDCONF_ARRAY_BYTES + RDCONF_HEAP_SAFETY
    if required > available:
        sys.exit("RDCONF needs %d heap bytes but a mapped cartridge leaves %d; "
                 "reduce arrays or linked data" % (required, available))
    print("  cartridge heap margin after RDCONF arrays: %d bytes" %
          (available - required))


def main():
    audit_branding()
    audit_source_versions()
    os.makedirs(path("build"), exist_ok=True)
    compile_remms()
    for src, out, _, modules in PROGRAMS:
        compile_program(src, out, modules)
        if out == "build/WFC.XEX":
            verify_wfc_heap()
        if out == "build/RDCONF.XEX":
            verify_rdconf_heap()
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
    for disk_name, contents in SHARED_CONFIG_FILES:
        dest = os.path.join(stage, disk_name)
        with open(dest, "wb") as g:
            g.write(contents)
        files.append(dest)
    os.makedirs(path("disk"), exist_ok=True)
    contents = {}
    for filename in files:
        with open(filename, "rb") as f:
            contents[os.path.basename(filename)] = f.read()
    contents["RAMCACHE.CFG"] = ramcache_default("O:")
    contents[EOS_PLATFORM_MARKER[0]] = EOS_PLATFORM_MARKER[1]

    eos_atr = path(EOS_ATR_RELATIVE_PATH)
    print("> " + EOS_ATR_RELATIVE_PATH)
    sdfs.build(eos_atr, DISK_SECTORS, DISK_SECTOR_SIZE, contents,
               volname=VOLUME_NAME, eosfs=True)
    if os.path.getsize(eos_atr) != ATR_SIZE:
        sys.exit("wrong EOS ATR size after template build")
    audit_packaged_branding(eos_atr, True)

    sdx_contents = {}
    eos_only = {name for name, _ in EOS_SYSTEM_FILES}
    eos_only.add(EOS_PLATFORM_MARKER[0])
    for name, data in contents.items():
        if name in eos_only:
            continue
        sdx_contents[SDX_DRIVER_RENAMES.get(name, name).upper()] = data
    sdx_contents["RAMCACHE.CFG"] = ramcache_default("DO:")
    sdx_contents[SDX_PLATFORM_MARKER[0]] = SDX_PLATFORM_MARKER[1]
    sdx_atr = path(SDX_ATR_RELATIVE_PATH)
    print("> " + SDX_ATR_RELATIVE_PATH)
    sdfs.build(sdx_atr, DISK_SECTORS, DISK_SECTOR_SIZE, sdx_contents,
               volname=VOLUME_NAME, eosfs=False)
    if os.path.getsize(sdx_atr) != ATR_SIZE:
        sys.exit("wrong SDX ATR size after template build")
    audit_packaged_branding(sdx_atr, False)

    # A versioned build is a complete two-image release.  Remove older ATRs
    # only after both current images have been built and audited successfully,
    # so disk/ cannot misleadingly contain stale release candidates.
    keep = {os.path.abspath(eos_atr), os.path.abspath(sdx_atr)}
    for name in os.listdir(path("disk")):
        if not re.fullmatch(r"mutinrex-(?:(?:eos|sdx)-)?v[0-9]+\.[0-9]+\.[0-9]+\.atr",
                            name, re.IGNORECASE):
            continue
        candidate = os.path.abspath(path("disk/" + name))
        if candidate not in keep:
            os.remove(candidate)
            print("  Removed stale " + os.path.relpath(candidate, ROOT))


if __name__ == "__main__":
    main()
