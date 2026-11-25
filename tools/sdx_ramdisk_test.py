#!/usr/bin/env python3
"""Prove the SDX RAM cache boots and chains modules from O: only."""
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
from altirra_debug import (  # noqa: E402
    halt_execution,
    read_memory,
    read_screen,
    send_debugger_command,
)

from exos_bbs_test import atascii_lines, labels, screen_to_text  # noqa: E402
import sdfs  # noqa: E402


CORE = ("wfc", "mainbbs", "message", "files", "doors")
PROGRAMS = CORE + ("bjack", "slots")
SCREENS = ("WFC", "WELC", "BULL", "FUNC", "HELP", "MESGM", "FILEM", "NEWU")


def release_files() -> dict[str, bytes]:
    version = (ROOT / "VERSION").read_text(encoding="ascii").strip()
    source = ROOT / "disk" / f"mutinrex-sdx-v{version}.atr"
    volume = sdfs.Volume(str(source))
    entries = volume.check()
    if volume.errors:
        raise RuntimeError("release ATR is invalid: " + "; ".join(volume.errors))
    return {
        name.lstrip("/"): entry["data"]
        for name, entry in entries
        if not entry["status"] & sdfs.ST_DIR
    }


def make_case(target: Path) -> None:
    files = release_files()
    files["BBS.CFG"] = atascii_lines(
        "MUTINREX CFG 1", "SYSOP", "0", "1", "5", "15",
        "ATE0 Q0 V1 S2=255 S4=24 S7=15", "1024", "8",
        "D1:", "D1:", "D1:", "D1:", "0", "1", "0", "1", "1",
    )
    files["SYSTEM.MET"] = atascii_lines("1", "0", "0")
    files["BBSDATE.TXT"] = atascii_lines("11/23/2026")
    files["BBSTIME.TXT"] = atascii_lines("12:00:00")
    startup: list[str] = [
        "ECHO MUTINEER-EX STARTS IN 5 SECONDS",
        "ECHO PRESS ANY KEY TO DROP TO DOS",
        "SETERRNO 0",
        "D1:BOOTWAIT.COM",
        "IF NOT ERROR 170",
    ]
    startup.extend(
        command
        for name in PROGRAMS
        for command in (
            f"ECHO COPYING D1:{name}.COM -> RAMDISK:{name}.COM",
            f"COPY D1:{name}.COM O:{name}.COM",
        )
    )
    startup.extend(
        command
        for name in SCREENS
        for extension in ("TXT", "ATA")
        for command in (
            f"ECHO COPYING D1:{name}.{extension} -> RAMDISK:{name}.{extension}",
            f"COPY D1:{name}.{extension} O:{name}.{extension}",
        )
    )
    startup.append("DIR O: >>D1:RAMDIR.TXT")
    # A successful run cannot be using an implicit D1 fallback.
    startup.extend(f"RENAME D1:{name}.COM {name}.BAK" for name in CORE)
    startup.extend(("D1:REMMS.COM", "O:WFC.COM"))
    startup.append("FI")
    files["AUTOEXEC.BAT"] = atascii_lines(*startup)
    sdfs.build(str(target), 65535, 256, files,
               volname="MUTINREX", eosfs=False)


def run_key_gate_case(work: Path) -> list[str]:
    """Press a normal key and prove AUTOEXEC stops at a clean SDX prompt."""
    failures: list[str] = []
    atr = work / "boot-gate.atr"
    profile = work / "boot-gate.ini"
    log = work / "boot-gate.log"
    files = release_files()
    files["AUTOEXEC.BAT"] = atascii_lines(
        "ECHO MUTINEER-EX STARTS IN 5 SECONDS",
        "ECHO PRESS ANY KEY TO DROP TO DOS",
        "SETERRNO 0",
        "D1:BOOTWAIT.COM",
        "IF NOT ERROR 170",
        "ECHO BOOT GATE CONTINUED",
        "FI",
    )
    sdfs.build(str(atr), 65535, 256, files,
               volname="MUTINREX", eosfs=False)
    run_altirra_850.write_profile(profile, 7081, inbound=False)
    command = [
        str(run_altirra_850.ALTIRRA.resolve()),
        "/portablealt:" + str(profile.resolve()),
        "/cart", str(SDX_CART.resolve()),
        "/debug",
        "/debugcmd", ".logopen " + str(log.resolve()),
        "/debugcmd", "g",
        "/bootrw", str(atr.resolve()),
    ]
    proc = None
    try:
        proc = run_altirra_850.launch_isolated(command, run_altirra_850.ALTIRRA.parent)
        deadline = time.monotonic() + 90
        while time.monotonic() < deadline:
            time.sleep(0.25)
            halt_execution(proc)
            _, screen = read_screen(proc)
            screen_text = "\n".join(
                screen_to_text(screen[offset:offset + 40])
                for offset in range(0, len(screen), 40)
            )
            if "PRESS ANY KEY TO DROP TO DOS" in screen_text:
                # Inactive Windows key messages do not reliably reach CH.
                # Inject Atari's L key code into the normal keyboard latch.
                send_debugger_command(proc, "eb $02FC 00")
                proc.debugger_command("g")
                break
            proc.debugger_command("g")
        else:
            raise RuntimeError("SDX startup key prompt was not displayed")

        time.sleep(2.0)
        halt_execution(proc)
        _, screen = read_screen(proc)
        screen_text = "\n".join(
            screen_to_text(screen[offset:offset + 40])
            for offset in range(0, len(screen), 40)
        )
        if "BOOT GATE CONTINUED" in screen_text:
            failures.append("ordinary key did not stop AUTOEXEC.BAT")
        if "D1:" not in screen_text:
            proc.debugger_command("r")
            time.sleep(0.2)
            debugger_tail = " | ".join(proc.debugger_text().splitlines()[-8:])
            failures.append(
                "ordinary key did not return to the SDX prompt: "
                + " | ".join(x.strip() for x in screen_text.splitlines() if x.strip())
                + " :: " + debugger_tail
            )
        if read_memory(proc, 0x02FC, 1)[0] != 0xFF:
            failures.append("startup key remained in the Atari keyboard latch")
    except Exception as exc:
        failures.append(str(exc))
    finally:
        if proc is not None:
            stop_process_tree(proc)
    return failures


def main() -> int:
    run_altirra_850.validate_canonical_runtime()
    symbols = labels(ROOT / "build" / "WFC.lbl")
    work = ROOT / "tmp" / "mutinrex-sdx-ramdisk-test"
    work.mkdir(parents=True, exist_ok=True)
    gate_failures = run_key_gate_case(work)
    atr = work / "ramdisk.atr"
    profile = work / "ramdisk.ini"
    log = work / "ramdisk.log"
    make_case(atr)
    run_altirra_850.write_profile(profile, 7082, inbound=False)
    profile.write_text(
        profile.read_text(encoding="utf-8").replace(
            '"Memory mode" = 4', '"Memory mode" = 6'
        ),
        encoding="utf-8",
    )
    command = [
        str(run_altirra_850.ALTIRRA.resolve()),
        "/portablealt:" + str(profile.resolve()),
        "/cart", str(SDX_CART.resolve()),
        "/debug",
        "/debugcmd", ".logopen " + str(log.resolve()),
        "/debugcmd", ".loadsym " + str((ROOT / "build" / "REMMS.lst").resolve()),
        "/debugcmd", "g",
        "/bootrw", str(atr.resolve()),
    ]
    proc = None
    failures: list[str] = list(gate_failures)
    try:
        proc = run_altirra_850.launch_isolated(command, run_altirra_850.ALTIRRA.parent)
        deadline = time.monotonic() + 240
        while time.monotonic() < deadline:
            debugger = proc.debugger_text()
            if "REMMS WFC console ready" in debugger:
                break
            if "Illegal instruction hit" in debugger:
                raise RuntimeError("CPU stopped before WFC")
            time.sleep(0.1)
        else:
            tail = " | ".join(proc.debugger_text().splitlines()[-20:])
            raise RuntimeError("SDX RAM-cached WFC did not start: " + tail)
        halt_execution(proc)
        start_option = int.from_bytes(
            read_memory(proc, symbols["fb_var_STARTOPTION"], 2), "little"
        )
        ram_enabled = read_memory(proc, start_option + 2, 1)[0]
        module_image = int.from_bytes(
            read_memory(proc, symbols["fb_var_MODULEIMAGE"], 2), "little"
        )
        _, screen = read_screen(proc)
        screen_text = "\n".join(
            screen_to_text(screen[offset:offset + 40])
            for offset in range(0, len(screen), 40)
        )
        if ram_enabled != 1:
            failures.append(f"RAM cache flag fell back to {ram_enabled}")
        if module_image != 1:
            failures.append(f"running module was {module_image}, expected WFC (1)")
        if "Mutineer-eX" not in screen_text:
            failures.append("WFC dashboard was not visible")
        proc.flush_debug_log()
    except Exception as exc:
        failures.append(str(exc))
    finally:
        if proc is not None:
            stop_process_tree(proc)
    volume = sdfs.Volume(str(atr))
    entries = volume.check()
    names = {name.lower() for name, _ in entries}
    for name in CORE:
        if f"/{name}.com" in names:
            failures.append(f"D1:{name}.COM still exists; fallback was possible")
        if f"/{name}.bak" not in names:
            failures.append(f"D1:{name}.BAK was not created")
    ramdir = next((entry["data"] for name, entry in entries
                   if name.lower() == "/ramdir.txt"), b"")
    catalog = ramdir.decode("latin-1", errors="replace").upper()
    if not catalog:
        failures.append("D1:RAMDIR.TXT was not written")
    for name in PROGRAMS:
        if f"\x9b{name.upper():<8} COM" not in catalog:
            failures.append(f"O:{name}.COM was not listed after copying")
    print("SDX RAMDISK: " + ("FAIL" if failures else "PASS"))
    for failure in failures:
        print("SDX RAMDISK: " + failure)
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
