#!/usr/bin/env python3
"""Validate that RDCONF writes an SDX-native RAM-cache AUTOEXEC.BAT."""
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
from altirra_debug import read_screen  # noqa: E402
from exos_bbs_test import atascii_lines, screen_to_text  # noqa: E402
import sdfs  # noqa: E402


def make_case(target: Path, apply: bool = True) -> None:
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
    files["BBS.CFG"] = atascii_lines(
        "MUTINREX CFG 1", "SYSOP", "0", "1", "5", "15",
        "ATE0 Q0 V1 S2=255 S4=24 S7=15", "1024", "8",
        "D1:", "D1:", "D1:", "D1:", "1", "1", "0", "1", "1",
    )
    if apply:
        files["RAMCACHE.APPLY"] = atascii_lines("1")
    # Transfer batch control once so AUTOEXEC.BAT itself is not held open
    # while RDCONF replaces it, matching a sysop launching CONFIG later.
    # The release image initially has no AUTOEXEC.BAT.  Remove the one-shot
    # launcher before entering RDCONF so this exercises first-time creation,
    # not only replacement of an existing startup file.
    files["BOOTCONF.BAT"] = atascii_lines(
        "DEL D1:AUTOEXEC.BAT", "D1:RDCONF.COM"
    )
    files["AUTOEXEC.BAT"] = atascii_lines("-BOOTCONF")
    sdfs.build(str(target), 65535, 256, files,
               volname="MUTINREX", eosfs=False)


def main() -> int:
    run_altirra_850.validate_canonical_runtime()
    work = ROOT / "tmp" / "mutinrex-sdx-rdconf-test"
    work.mkdir(parents=True, exist_ok=True)
    atr = work / "rdconf.atr"
    profile = work / "rdconf.ini"
    log = work / "rdconf.log"
    make_case(atr)
    run_altirra_850.write_profile(profile, 7083, inbound=False)
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
        "/debugcmd", "g",
        "/bootrw", str(atr.resolve()),
    ]
    proc = None
    failures: list[str] = []
    screen_text = ""
    try:
        proc = run_altirra_850.launch_isolated(command, run_altirra_850.ALTIRRA.parent)
        time.sleep(1.0)
        if proc.poll() is not None:
            raise RuntimeError(f"Altirra exited early with status {proc.returncode}")
        deadline = time.monotonic() + 180
        while time.monotonic() < deadline:
            proc.debugger_run_break()
            time.sleep(0.35)
            _, screen = read_screen(proc)
            screen_text = "\n".join(
                screen_to_text(screen[offset:offset + 40])
                for offset in range(0, len(screen), 40)
            )
            if "Mutineer-eX" in screen_text and "CONFIG" in screen_text and "CHOICE >" in screen_text:
                break
            if "STARTUP SAVE ERROR" in screen_text:
                raise RuntimeError("RDCONF reported: " + " | ".join(
                    x.strip() for x in screen_text.splitlines() if x.strip()
                ))
            if "ERROR-" in screen_text or "Illegal instruction hit" in proc.debugger_text():
                raise RuntimeError("RDCONF stopped while writing SDX startup")
            proc.debugger_command("g")
            time.sleep(0.75)
        else:
            raise RuntimeError("CONFIG was not reached after RDCONF apply: " +
                               " | ".join(x.strip() for x in screen_text.splitlines()
                                          if x.strip()))
        # Let SDX commit its buffered directory/data sectors before detaching
        # the writable ATR from the private emulator process.
        proc.debugger_command("g")
        time.sleep(2.0)
        proc.debugger_run_break()
        time.sleep(0.5)
    except Exception as exc:
        failures.append(str(exc))
    finally:
        if proc is not None:
            stop_process_tree(proc)
    volume = sdfs.Volume(str(atr))
    entries = volume.check()
    by_name = {name.lower(): entry["data"] for name, entry in entries}
    startup = by_name.get("/autoexec.bat", b"").decode("latin-1", errors="replace").upper()
    expected = (
        "ECHO MUTINEER-EX STARTS IN 5 SECONDS",
        "ECHO PRESS BREAK FOR THE SDX PROMPT",
        "PAUSE 5",
        "FORMAT /QQ O: MUTINREX",
        "ECHO COPYING D1:WFC.COM -> RAMDISK:WFC.COM",
        "COPY D1:WFC.COM O:WFC.COM",
        "D1:RHND850.COM",
        "D1:REMMS.COM",
        "O:WFC.COM",
    )
    for line in expected:
        if line not in startup:
            failures.append(f"AUTOEXEC.BAT is missing {line}")
    if "/eossys.sys" in by_name or "/eosauto.bat" in by_name:
        failures.append("RDCONF wrote EOS startup files on the SDX image")
    if "/ramcache.apply" in by_name:
        failures.append("RAMCACHE.APPLY was not consumed")
    print("RDCONF SDX STARTUP: " + ("FAIL" if failures else "PASS"))
    for failure in failures:
        print("RDCONF SDX STARTUP: " + failure)
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
