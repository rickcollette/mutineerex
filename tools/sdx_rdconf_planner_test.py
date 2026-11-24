#!/usr/bin/env python3
"""Boot the RDCONF file picker against SDX's native O: RAM disk."""
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
from exos_bbs_test import screen_to_text  # noqa: E402
from sdx_rdconf_test import make_case  # noqa: E402


def main() -> int:
    run_altirra_850.validate_canonical_runtime()
    work = ROOT / "tmp" / "mutinrex-sdx-rdconf-planner-test"
    work.mkdir(parents=True, exist_ok=True)
    atr = work / "planner.atr"
    profile = work / "planner.ini"
    log = work / "planner.log"
    make_case(atr, apply=False)
    run_altirra_850.write_profile(profile, 7084, inbound=False)
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
                raise RuntimeError("RDCONF stopped before the SDX planner")
            proc.debugger_command("g")
            time.sleep(0.75)
        else:
            raise RuntimeError("SDX RDCONF planner was not reached: " +
                               " | ".join(x.strip() for x in screen_text.splitlines()
                                          if x.strip()))
        if "O: CAPACITY" not in screen_text:
            failures.append("RDCONF did not measure the SDX O: RAM disk")
        if "RESULT      FITS" not in screen_text:
            failures.append("default SDX RAMCACHE.CFG was not reported as fitting")
        for extension in ("COM", "ATA", "TXT", "V52", "RIP", "IG"):
            if "ALL ." + extension + " FILES" not in screen_text:
                failures.append(f".{extension} group was not displayed")
        for number, extension in ((1, "COM"), (2, "ATA"), (3, "TXT")):
            if f"{number} [NONE] ALL .{extension} FILES" in screen_text:
                failures.append(f".{extension} files were not discovered and selected")
        if "SELECTED    0 SECTORS" in screen_text:
            failures.append("RDCONF discovered no files")
    except Exception as exc:
        failures.append(str(exc))
    finally:
        if proc is not None:
            stop_process_tree(proc)
    print("RDCONF SDX PLANNER: " + ("FAIL" if failures else "PASS"))
    for failure in failures:
        print("RDCONF SDX PLANNER: " + failure)
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
