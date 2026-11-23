#!/usr/bin/env python3
"""Boot RDCONF against a real EOS O: RAM disk and validate its planner."""
from __future__ import annotations

import os
import sys
import time
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MUTINEER = Path(os.environ.get("MUTINEER_ROOT", r"D:\ATARI\atari-mutineer"))
sys.path.insert(0, str(MUTINEER / "tools"))
sys.path.insert(0, str(ROOT / "tools"))

import run_altirra_850  # type: ignore  # noqa: E402
from run_mutineer_telnet_test import stop_process_tree  # type: ignore  # noqa: E402
from altirra_debug import read_screen  # noqa: E402
from exos_bbs_test import atascii_lines, screen_to_text  # noqa: E402
import sdfs  # noqa: E402


def make_case(target: Path) -> None:
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
        "D1:", "D1:", "D1:", "D1:", "0", "1", "0", "1", "1",
    )
    files["eossys.sys"] = atascii_lines(
        "SET PATH=CAR:;D1:", "DEVICE JIFFY", "DEVICE RAMDISK"
    )
    files["eosauto.bat"] = atascii_lines("SET PATH=CAR:;D1:", "D1:rdconf.com")
    sdfs.build(str(target), 65535, 256, files,
               volname="MUTINREX", eosfs=True)


def main() -> int:
    run_altirra_850.validate_canonical_runtime()
    work = ROOT / "tmp" / "mutinrex-rdconf-test"
    work.mkdir(parents=True, exist_ok=True)
    atr = work / "rdconf.atr"
    profile = work / "rdconf.ini"
    log = work / "rdconf.log"
    make_case(atr)
    run_altirra_850.write_profile(profile, 7081, inbound=False)
    profile.write_text(
        profile.read_text(encoding="utf-8").replace(
            '"Memory mode" = 4', '"Memory mode" = 6'
        ),
        encoding="utf-8",
    )
    command = [
        str(run_altirra_850.ALTIRRA.resolve()),
        "/portablealt:" + str(profile.resolve()),
        "/cart", str((ROOT / "EOS.car").resolve()),
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
            if "RAMDISK FILE PLANNER" in screen_text and "CHOICE >" in screen_text:
                break
            if "ERROR-" in screen_text or "Illegal instruction hit" in proc.debugger_text():
                detail = " | ".join(
                    line.strip() for line in screen_text.splitlines() if line.strip()
                )
                raise RuntimeError("RDCONF stopped before its planner: " + detail)
            proc.debugger_command("g")
            time.sleep(0.75)
        else:
            raise RuntimeError("RDCONF planner was not reached: " +
                               " | ".join(x.strip() for x in screen_text.splitlines()
                                          if x.strip()))
        if "O: CAPACITY" not in screen_text:
            failures.append("RDCONF did not detect the installed O: RAM disk")
        if "RESULT      FITS" not in screen_text:
            failures.append("default RAMCACHE.CFG was not reported as fitting")
        for extension in ("COM", "ATA", "TXT", "V52", "RIP", "IG"):
            if "ALL ." + extension + " FILES" not in screen_text:
                failures.append(f".{extension} group was not displayed")
    except Exception as exc:
        failures.append(str(exc))
    finally:
        if proc is not None:
            stop_process_tree(proc)
    print("RDCONF EOS PLANNER: " + ("FAIL" if failures else "PASS"))
    for failure in failures:
        print("RDCONF EOS PLANNER: " + failure)
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
