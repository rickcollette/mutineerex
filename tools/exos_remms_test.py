#!/usr/bin/env python3
"""Debugger-only exOS loader acceptance for REMMS and every R: backend.

The test boots a private copy of the native EOSFS disk for each driver, lets
eossys.sys load it with DEVICE, then stops after REMMS installation and reads
the loader state from Altirra's debugger. No emulator window is activated.
"""
from __future__ import annotations

import os
import re
import shutil
import sys
import time
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MUTINEER = Path(os.environ.get("MUTINEER_ROOT", r"D:\ATARI\atari-mutineer"))
sys.path.insert(0, str(MUTINEER / "tools"))

import run_altirra_850  # type: ignore  # noqa: E402
from run_mutineer_telnet_test import stop_process_tree  # type: ignore  # noqa: E402
from run_wfc_dashboard_test import read_memory, read_screen, screen_to_text  # type: ignore  # noqa: E402

import sdfs  # noqa: E402


DRIVERS = ("RVRFULL", "RVRTWOW", "NHAND")
BREAK_AFTER_INSTALL = 0x239A
TEST_STUB = 0x9000


def labels(path: Path) -> dict[str, int]:
    result: dict[str, int] = {}
    for line in path.read_text(encoding="ascii", errors="replace").splitlines():
        match = re.match(r"^\S+\s+([0-9A-Fa-f]{4})\s+([A-Za-z_][A-Za-z0-9_]*)$", line)
        if match:
            result[match.group(2)] = int(match.group(1), 16)
    return result


def run_case(driver: str, work: Path, index: int) -> list[str]:
    failures: list[str] = []
    atr = work / (driver.lower() + ".atr")
    profile = work / (driver.lower() + ".ini")
    debug_log = work / (driver.lower() + ".log")
    version = (ROOT / "VERSION").read_text(encoding="ascii").strip()
    shutil.copyfile(ROOT / "disk" / f"mutinrex-v{version}.atr", atr)
    system = "SET PATH=CAR:;D1:\x9bDEVICE JIFFY\x9b"
    startup = "D1:remms.com\x9b"
    system += f"DEVICE D1:{driver}\x9b"
    system = system.encode("latin-1")
    sdfs.overwrite(str(atr), "eossys.sys", system)
    sdfs.overwrite(str(atr), "eosauto.bat", startup.encode("latin-1"))
    run_altirra_850.write_profile(profile, 6795 + index, inbound=False)
    command = [
        str(run_altirra_850.ALTIRRA.resolve()),
        "/portablealt:" + str(profile.resolve()),
        "/cart", str((ROOT / "EOS.car").resolve()),
        "/debug",
        "/debugcmd", ".logopen " + str(debug_log.resolve()),
        "/debugcmd", f"bp ${BREAK_AFTER_INSTALL:04X}",
        "/disk", str(atr.resolve()),
    ]
    proc = None
    try:
        proc = run_altirra_850.launch_isolated(command, run_altirra_850.ALTIRRA.parent)
        if not proc.wait_for_debugger_text("Breakpoint 0 set", 10):
            raise RuntimeError("install breakpoint was not armed")
        proc.debugger_command("g")
        if not proc.wait_for_debugger_text(f"{BREAK_AFTER_INSTALL:04X}:", 90):
            raise RuntimeError("REMMS post-install breakpoint was not reached")
        time.sleep(0.5)
        discovery = read_memory(proc, 0x03E8, 14)
        session = discovery[10] | discovery[11] << 8
        memlo = read_memory(proc, 0x02E7, 2)
        hatabs = read_memory(proc, 0x031A, 36)
        rslots = [i for i in range(0, 36, 3) if hatabs[i] == ord("R")]
        public = discovery[6] | discovery[7] << 8
        if discovery[:3] != b"REM":
            failures.append(f"bad discovery record {discovery[:4]!r}")
        if public == 0 or read_memory(proc, public, 7) != b"REMMS\x01\x0A":
            failures.append("REMMS 1.10 public block was not published")
        if session == 0 or read_memory(proc, session, 2) != bytes((77, 9)):
            failures.append("REMMS session contract 9 was not published")
        if memlo != bytes((0xFF, 0x3C)):
            failures.append(f"MEMLO was ${memlo[1]:02X}{memlo[0]:02X}, expected $3CFF")
        if len(rslots) != 1:
            failures.append(f"expected one R: handler, found {len(rslots)}")
            _, screen = read_screen(proc)
            lines = [screen_to_text(screen[i:i + 40]).rstrip()
                     for i in range(0, len(screen), 40)]
            failures.append("screen: " + " | ".join(line for line in lines if line))
        symbols = labels(ROOT / "build" / "REMMS.lab")
        install = symbols["REMMS_INSTALL"]
        stub = bytes((0x20, install & 0xFF, install >> 8,
                      0x4C, (TEST_STUB + 3) & 0xFF, (TEST_STUB + 3) >> 8))
        proc.debugger_command(
            f"eb ${TEST_STUB:04X} " + " ".join(f"{value:02X}" for value in stub))
        proc.debugger_command(f"bp ${TEST_STUB + 3:04X}")
        proc.debugger_command(f"r pc ${TEST_STUB:04X}")
        proc.debugger_command("g")
        if not proc.wait_for_debugger_text(f"{TEST_STUB + 3:04X}:", 20):
            raise RuntimeError("REMMS API install did not return")
        wrapped = read_memory(proc, 0x031A, 36)
        tables = {wrapped[i]: wrapped[i + 1] | wrapped[i + 2] << 8
                  for i in range(0, 36, 3) if wrapped[i]}
        if tables.get(ord("E")) != symbols["REMMS_E_TABLE"]:
            failures.append("REMMS did not wrap E:")
        if tables.get(ord("R")) != symbols["REMMS_R_TABLE"]:
            failures.append("REMMS did not wrap R:")
        if read_memory(proc, public + 12, 1) != b"\x01":
            failures.append("REMMS public installed flag was not set")
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
    work = ROOT / "tmp" / "mutinrex-exos-remms-test"
    work.mkdir(parents=True, exist_ok=True)
    all_failures: list[str] = []
    drivers = tuple(filter(None, os.environ.get(
        "EXOS_REMMS_DRIVERS", ",".join(DRIVERS)).upper().split(",")))
    for index, driver in enumerate(drivers):
        failures = run_case(driver, work, index)
        print(f"{driver}: {'FAIL' if failures else 'PASS'}")
        all_failures += [f"{driver}: {failure}" for failure in failures]
    for failure in all_failures:
        print(failure)
    return 1 if all_failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
