#!/usr/bin/env python3
"""Cold-boot the SDX release with every packaged REMMS backend."""
from __future__ import annotations

import os
import sys
import time
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MUTINEER = Path(os.environ.get("MUTINEER_ROOT", r"D:\ATARI\atari-mutineer"))
SDX_CART = Path(os.environ.get("SDX_CART", r"D:\ALTIRRA\SDX450_maxflash8.car"))
sys.path.insert(0, str(MUTINEER / "tools"))
sys.path.insert(0, str(ROOT / "tools"))

import run_altirra_850  # type: ignore  # noqa: E402
from run_mutineer_telnet_test import stop_process_tree  # type: ignore  # noqa: E402
from altirra_debug import read_memory, read_screen  # noqa: E402

from exos_bbs_test import (  # noqa: E402
    alt_number,
    atascii_lines,
    labels,
    screen_to_text,
    validate_state,
)
import sdfs  # noqa: E402


CASES = (
    ("NONE", 0), ("RHND850", 1), ("RVRFULL", 2),
    ("RVRTWOW", 3), ("NHAND", 4),
)


def make_case(driver: str, driver_number: int, target: Path,
              manual_clock: bool = False) -> None:
    version = (ROOT / "VERSION").read_text(encoding="ascii").strip()
    source = ROOT / "disk" / f"mutinrex-sdx-v{version}.atr"
    volume = sdfs.Volume(str(source))
    entries = volume.check()
    if volume.errors:
        raise RuntimeError("release ATR is invalid: " + "; ".join(volume.errors))
    files = {
        name.lstrip("/"): entry["data"]
        for name, entry in entries
        if not entry["status"] & sdfs.ST_DIR
    }
    clock_source = "0" if manual_clock else "1"
    files["BBS.CFG"] = atascii_lines(
        "MUTINREX CFG 1", "SYSOP", "0", "1", "5", "15",
        "ATE0 Q0 V1 S2=255 S4=24 S7=15", "1024", "8",
        "D1:", "D1:", "D1:", "D1:", str(driver_number),
        "1", "0", clock_source, "0",
    )
    files["SYSTEM.MET"] = atascii_lines("1", "0", "0")
    if manual_clock:
        files.pop("BBSDATE.TXT", None)
        files.pop("BBSTIME.TXT", None)
    else:
        files["BBSDATE.TXT"] = atascii_lines("11/23/2026")
        files["BBSTIME.TXT"] = atascii_lines("12:00:00")
    startup = []
    if driver != "NONE":
        startup.append(f"D1:{driver}.COM")
    startup.extend(("D1:REMMS.COM", "D1:WFC.COM"))
    files["AUTOEXEC.BAT"] = atascii_lines(*startup)
    sdfs.build(str(target), 65535, 256, files,
               volname="MUTINREX", eosfs=False)


def run_case(driver: str, driver_number: int, work: Path, index: int,
             symbols: dict[str, int]) -> list[str]:
    failures: list[str] = []
    atr = work / f"{driver.lower()}.atr"
    profile = work / f"{driver.lower()}.ini"
    debug_log = work / f"{driver.lower()}.log"
    make_case(driver, driver_number, atr)
    run_altirra_850.write_profile(profile, 6990 + index, inbound=False)
    command = [
        str(run_altirra_850.ALTIRRA.resolve()),
        "/portablealt:" + str(profile.resolve()),
        "/cart", str(SDX_CART.resolve()),
        "/debug",
        "/debugcmd", ".logopen " + str(debug_log.resolve()),
        "/debugcmd", ".loadsym " + str((ROOT / "build" / "REMMS.lst").resolve()),
        "/debugcmd", ".loadsym " + str((ROOT / "build" / "REMMS.lab").resolve()),
        "/debugcmd", "g",
        "/disk", str(atr.resolve()),
    ]
    proc = None
    try:
        proc = run_altirra_850.launch_isolated(command, run_altirra_850.ALTIRRA.parent)
        deadline = time.monotonic() + 150
        while time.monotonic() < deadline:
            debugger = proc.debugger_text()
            if driver == "NONE":
                ready = "REMMS WFC console ready" in debugger
            else:
                ready = ("REMMS fresh modem sync begin" in debugger or
                         "REMMS open failure" in debugger)
            if ready:
                break
            if "Illegal instruction hit" in debugger:
                tail = " | ".join(debugger.splitlines()[-20:])
                raise RuntimeError("CPU stopped before WFC: " + tail)
            time.sleep(0.1)
        else:
            tail = " | ".join(proc.debugger_text().splitlines()[-20:])
            raise RuntimeError("WFC did not reach its ready state: " + tail)
        proc.debugger_run_break()
        time.sleep(0.8)
        _, screen = read_screen(proc)
        screen_text = "\n".join(
            screen_to_text(screen[offset:offset + 40])
            for offset in range(0, len(screen), 40)
        )
        cfg_status = alt_number(proc, symbols, "fb_var_CFGSTATUS")
        serial_ready = alt_number(proc, symbols, "fb_var_SERIALREADY")
        ready = alt_number(proc, symbols, "fb_var_012_WFCMODEMINFO_READY")
        configured = alt_number(proc, symbols, "fb_var_RDRIVER")
        basic_top = alt_number(proc, symbols, "BASIC_TOP")
        memtop = int.from_bytes(read_memory(proc, 0x02E5, 2), "little")
        public = alt_number(proc, symbols, "fb_var_REMMSPUBLIC")
        installed = read_memory(proc, public + 12, 1)[0]
        hatabs = read_memory(proc, 0x031A, 36)
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


def run_manual_clock_case(work: Path, index: int,
                          symbols: dict[str, int]) -> list[str]:
    """Prove an offline 850 boot reads the clock from the local editor."""
    failures: list[str] = []
    atr = work / "rhnd850-manual-clock.atr"
    profile = work / "rhnd850-manual-clock.ini"
    debug_log = work / "rhnd850-manual-clock.log"
    make_case("RHND850", 1, atr, manual_clock=True)
    run_altirra_850.write_profile(profile, 6990 + index, inbound=False)
    command = [
        str(run_altirra_850.ALTIRRA.resolve()),
        "/portablealt:" + str(profile.resolve()),
        "/cart", str(SDX_CART.resolve()),
        "/debug",
        "/debugcmd", ".logopen " + str(debug_log.resolve()),
        "/debugcmd", "g",
        "/disk", str(atr.resolve()),
    ]
    proc = None
    try:
        proc = run_altirra_850.launch_isolated(
            command, run_altirra_850.ALTIRRA.parent
        )
        deadline = time.monotonic() + 90
        screen_text = ""
        while time.monotonic() < deadline:
            time.sleep(1)
            proc.debugger_run_break()
            time.sleep(0.25)
            _, screen = read_screen(proc)
            screen_text = "\n".join(
                screen_to_text(screen[offset:offset + 40])
                for offset in range(0, len(screen), 40)
            )
            if "Enter date mm/dd/yyyy" in screen_text:
                break
            if "Illegal instruction hit" in proc.debugger_text():
                raise RuntimeError("CPU stopped before the manual clock prompt")
            proc.debugger_run_break()
        else:
            raise RuntimeError("manual clock prompt was not reached")

        prompt_count = screen_text.count("Enter date mm/dd/yyyy")
        if prompt_count != 1:
            failures.append(
                f"manual clock prompt appeared {prompt_count} times, expected once"
            )
        public = alt_number(proc, symbols, "fb_var_REMMSPUBLIC")
        mode, route = read_memory(proc, public + 7, 2)
        if mode != 0 or route != 0:
            failures.append(
                f"manual clock used REMMS mode/route {mode}/{route}, expected 0/0"
            )
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
    required = (
        ROOT / "disk", SDX_CART, ROOT / "build" / "WFC.lbl",
        ROOT / "build" / "REMMS.lst", ROOT / "build" / "REMMS.lab",
    )
    missing = [str(item) for item in required if not item.exists()]
    if missing:
        raise SystemExit("missing required path(s): " + ", ".join(missing))
    symbols = labels(ROOT / "build" / "WFC.lbl")
    work = ROOT / "tmp" / "mutinrex-sdx-bbs-test"
    work.mkdir(parents=True, exist_ok=True)
    selected = set(filter(None, os.environ.get(
        "SDX_BBS_DRIVERS", ",".join(name for name, _ in CASES)
    ).upper().split(",")))
    all_failures: list[str] = []
    for index, (driver, driver_number) in enumerate(CASES):
        if driver not in selected:
            continue
        failures = run_case(driver, driver_number, work, index, symbols)
        print(f"{driver}: {'FAIL' if failures else 'PASS'}")
        all_failures += [f"{driver}: {failure}" for failure in failures]
    if "RHND850" in selected:
        failures = run_manual_clock_case(work, len(CASES), symbols)
        print(f"RHND850-MANUAL-CLOCK: {'FAIL' if failures else 'PASS'}")
        all_failures += [
            f"RHND850-MANUAL-CLOCK: {failure}" for failure in failures
        ]
    for failure in all_failures:
        print(failure)
    return 1 if all_failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
