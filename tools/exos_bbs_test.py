#!/usr/bin/env python3
"""Boot Mutineer-eX under exOS with every packaged REMMS backend.

Each case is a newly built, writable EOSFS image containing a persistent
BBS.CFG and SYSTEM.MET.  The driver-free case prefers headless Atari800 and
falls back to the canonical Altirra runtime.  Every case must reach a complete
WFC dashboard without a CPU crash.
"""
from __future__ import annotations

import os
import re
import sys
import time
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MUTINEER = Path(os.environ.get("MUTINEER_ROOT", r"D:\ATARI\atari-mutineer"))
sys.path.insert(0, str(MUTINEER / "tools"))

import run_altirra_850  # type: ignore  # noqa: E402
from run_mutineer_telnet_test import stop_process_tree  # type: ignore  # noqa: E402
from altirra_debug import (  # noqa: E402
    read_memory as alt_read_memory,
    read_screen as alt_read_screen,
)

from atari800_smoke import Emulator, emulator_available  # noqa: E402
import sdfs  # noqa: E402


CASES = (("NONE", 0), ("RVRFULL", 2), ("RVRTWOW", 3), ("NHAND", 4))


def labels(path: Path) -> dict[str, int]:
    result: dict[str, int] = {}
    for line in path.read_text(encoding="ascii", errors="replace").splitlines():
        match = re.match(r"^al\s+([0-9A-Fa-f]{6})\s+\.([^\s]+)$", line)
        if match:
            result[match.group(2)] = int(match.group(1), 16)
            continue
        match = re.match(
            r"^\S+\s+([0-9A-Fa-f]{4})\s+([A-Za-z_][A-Za-z0-9_]*)$", line
        )
        if match:
            result[match.group(2)] = int(match.group(1), 16)
    return result


def atascii_lines(*values: str) -> bytes:
    return ("\x9b".join(values) + "\x9b").encode("latin-1")


def make_case(driver: str, driver_number: int, target: Path) -> None:
    version = (ROOT / "VERSION").read_text(encoding="ascii").strip()
    source = ROOT / "disk" / f"mutinrex-eos-v{version}.atr"
    volume = sdfs.Volume(str(source))
    entries = volume.check()
    if volume.errors:
        raise RuntimeError("release ATR is invalid: " + "; ".join(volume.errors))
    files = {
        name.lstrip("/"): entry["data"]
        for name, entry in entries
        if not entry["status"] & sdfs.ST_DIR
    }
    files["BBS.CFG"] = atascii_lines(
        "MUTINREX CFG 1", "SYSOP", "0", "1", "5", "15",
        "ATE0 Q0 V1 S2=255 S4=24 S7=15", "1024", "8",
        "D1:", "D1:", "D1:", "D1:", str(driver_number),
        "1", "0", "1", "0",
    )
    files["SYSTEM.MET"] = atascii_lines("1", "0", "0")
    files["BBSDATE.TXT"] = atascii_lines("11/22/2026")
    files["BBSTIME.TXT"] = atascii_lines("12:00:00")
    system = ["SET PATH=CAR:;D1:", "DEVICE JIFFY"]
    if driver != "NONE":
        system.append(f"DEVICE D1:{driver}")
    files["eossys.sys"] = atascii_lines(*system)
    files["eosauto.bat"] = atascii_lines(
        "SET PATH=CAR:;D1:", "D1:remms.com", "D1:wfc.com"
    )
    sdfs.build(str(target), 65535, 256, files, volname="MUTINREX", eosfs=True)


def read_memory(emulator: Emulator, address: int, length: int) -> bytes:
    reply = emulator.request({"op": "readMemory", "address": address,
                              "length": length})
    return bytes.fromhex(reply["data"])


def number(emulator: Emulator, symbols: dict[str, int], name: str) -> int:
    raw = read_memory(emulator, symbols[name], 2)
    return raw[0] | raw[1] << 8


def screen_to_text(data: bytes) -> str:
    result = []
    for value in data:
        value &= 0x7F
        if value < 0x40:
            result.append(chr(value + 0x20))
        elif value >= 0x60:
            result.append(chr(value))
        else:
            result.append(".")
    return "".join(result)


def validate_state(driver: str, driver_number: int, cfg_status: int,
                   serial_ready: int, ready: int, configured: int,
                   basic_top: int, memtop: int, installed: int,
                   hatabs: bytes, screen_text: str) -> list[str]:
    failures: list[str] = []
    r_count = sum(hatabs[offset] == ord("R") for offset in range(0, 36, 3))
    if cfg_status != 1:
        failures.append(f"BBS.CFG status was {cfg_status}, expected 1")
    if configured != driver_number:
        failures.append(f"RDriver was {configured}, expected {driver_number}")
    expected_serial = int(driver != "NONE")
    if serial_ready != expected_serial:
        failures.append(f"SerialReady was {serial_ready}, expected {expected_serial}")
    if installed != expected_serial:
        failures.append(f"REMMS installed flag was {installed}, expected {expected_serial}")
    if r_count != expected_serial:
        failures.append(f"R: handler count was {r_count}, expected {expected_serial}")
    if driver == "NONE" and ready != 0:
        failures.append(f"driver-free WFC reported Ready={ready}")
    if basic_top > memtop:
        failures.append(f"BASIC top ${basic_top:04X} exceeds MEMTOP ${memtop:04X}")
    if "Mutineer-eX" not in screen_text:
        failures.append("Mutineer-eX dashboard branding was not in screen memory")
    return failures


def run_case(driver: str, driver_number: int, work: Path,
             symbols: dict[str, int]) -> list[str]:
    failures: list[str] = []
    atr = work / f"{driver.lower()}.atr"
    make_case(driver, driver_number, atr)
    emulator = Emulator(str(atr.resolve()))
    try:
        screen = b""
        screen_text = ""
        for _ in range(24):
            emulator.frames(50)
            screen_base = int.from_bytes(read_memory(emulator, 0x0058, 2), "little")
            if not 0x1000 <= screen_base <= 0xBFFF:
                continue
            screen = read_memory(emulator, screen_base, 40 * 24)
            screen_text = "\n".join(
                screen_to_text(screen[offset:offset + 40])
                for offset in range(0, len(screen), 40)
            )
            if "Mutineer-eX" in screen_text and "MODEM" in screen_text:
                break
        else:
            raise RuntimeError("WFC dashboard was not reached")
        # Keep running after the first complete draw. This exercises repeated
        # zero-argument REMMS console calls through the exBASIC ABI shim and
        # catches the former bad-RTS/page-zero crash.
        emulator.frames(120)
        screen_base = int.from_bytes(read_memory(emulator, 0x0058, 2), "little")
        screen = read_memory(emulator, screen_base, 40 * 24)
        screen_text = "\n".join(
            screen_to_text(screen[offset:offset + 40])
            for offset in range(0, len(screen), 40)
        )
        cfg_status = number(emulator, symbols, "fb_var_CFGSTATUS")
        serial_ready = number(emulator, symbols, "fb_var_SERIALREADY")
        ready = number(emulator, symbols, "fb_var_012_WFCMODEMINFO_READY")
        configured = number(emulator, symbols, "fb_var_RDRIVER")
        basic_top = number(emulator, symbols, "BASIC_TOP")
        memtop = int.from_bytes(read_memory(emulator, 0x02E5, 2), "little")
        public = number(emulator, symbols, "fb_var_REMMSPUBLIC")
        installed = read_memory(emulator, public + 12, 1)[0]
        hatabs = read_memory(emulator, 0x031A, 36)
        failures.extend(validate_state(
            driver, driver_number, cfg_status, serial_ready, ready, configured,
            basic_top, memtop, installed, hatabs, screen_text
        ))
        emulator.save(str(work / f"{driver.lower()}.png"))
    except Exception as exc:
        failures.append(str(exc))
    finally:
        emulator.close()
    return failures


def alt_number(proc, symbols: dict[str, int], name: str) -> int:
    return int.from_bytes(alt_read_memory(proc, symbols[name], 2), "little")


def run_driver_case(driver: str, driver_number: int, work: Path, index: int,
                    symbols: dict[str, int]) -> list[str]:
    failures: list[str] = []
    atr = work / f"{driver.lower()}.atr"
    profile = work / f"{driver.lower()}.ini"
    debug_log = work / f"{driver.lower()}.log"
    remms_symbols = labels(ROOT / "build" / "REMMS.lab")
    console_ready = remms_symbols["REMMS_CONSOLE_READY"]
    make_case(driver, driver_number, atr)
    run_altirra_850.write_profile(profile, 6890 + index, inbound=False)
    command = [
        str(run_altirra_850.ALTIRRA.resolve()),
        "/portablealt:" + str(profile.resolve()),
        "/cart", str((ROOT / "EOS.car").resolve()),
        "/debug",
        "/debugcmd", ".logopen " + str(debug_log.resolve()),
        "/debugcmd", ".loadsym " + str((ROOT / "build" / "REMMS.lst").resolve()),
        "/debugcmd", ".loadsym " + str((ROOT / "build" / "REMMS.lab").resolve()),
        "/debugcmd", f"bp ${console_ready:04X}",
        "/debugcmd", "g",
        "/disk", str(atr.resolve()),
    ]
    proc = None
    try:
        proc = run_altirra_850.launch_isolated(command, run_altirra_850.ALTIRRA.parent)
        if not proc.wait_for_debugger_text("Breakpoint 0 set", 10):
            raise RuntimeError("WFC console breakpoint was not armed")
        if not proc.wait_for_debugger_text(f"{console_ready:04X}:", 120):
            debugger = proc.debugger_text()
            tail = " | ".join(debugger.splitlines()[-20:])
            raise RuntimeError("WFC did not reach its console loop: " + tail)
        time.sleep(0.25)
        _, screen = alt_read_screen(proc)
        screen_text = "\n".join(
            screen_to_text(screen[offset:offset + 40])
            for offset in range(0, len(screen), 40)
        )
        cfg_status = alt_number(proc, symbols, "fb_var_CFGSTATUS")
        serial_ready = alt_number(proc, symbols, "fb_var_SERIALREADY")
        ready = alt_number(proc, symbols, "fb_var_012_WFCMODEMINFO_READY")
        configured = alt_number(proc, symbols, "fb_var_RDRIVER")
        basic_top = alt_number(proc, symbols, "BASIC_TOP")
        memtop = int.from_bytes(alt_read_memory(proc, 0x02E5, 2), "little")
        public = alt_number(proc, symbols, "fb_var_REMMSPUBLIC")
        installed = alt_read_memory(proc, public + 12, 1)[0]
        hatabs = alt_read_memory(proc, 0x031A, 36)
        failures.extend(validate_state(
            driver, driver_number, cfg_status, serial_ready, ready, configured,
            basic_top, memtop, installed, hatabs, screen_text
        ))
        if run_altirra_850.process_owns_foreground(proc.pid):
            failures.append("Altirra acquired the interactive foreground")
        proc.flush_debug_log()
    except Exception as exc:
        failures.append(str(exc))
    finally:
        if proc is not None:
            stop_process_tree(proc)
    return failures


def main() -> int:
    run_altirra_850.validate_canonical_runtime()
    required = (ROOT / "disk", ROOT / "EOS.car", ROOT / "build" / "WFC.lbl")
    missing = [str(item) for item in required if not item.exists()]
    if missing:
        raise SystemExit("missing required path(s): " + ", ".join(missing))
    symbols = labels(ROOT / "build" / "WFC.lbl")
    work = ROOT / "tmp" / "mutinrex-exos-bbs-test"
    work.mkdir(parents=True, exist_ok=True)
    all_failures: list[str] = []
    selected = set(filter(None, os.environ.get(
        "EXOS_BBS_DRIVERS", ",".join(name for name, _ in CASES)
    ).upper().split(",")))
    for index, (driver, driver_number) in enumerate(CASES):
        if driver not in selected:
            continue
        if driver == "NONE" and emulator_available():
            failures = run_case(driver, driver_number, work, symbols)
        else:
            failures = run_driver_case(
                driver, driver_number, work, index, symbols
            )
        print(f"{driver}: {'FAIL' if failures else 'PASS'}")
        all_failures += [f"{driver}: {failure}" for failure in failures]
    for failure in all_failures:
        print(failure)
    return 1 if all_failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
