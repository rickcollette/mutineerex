#!/usr/bin/env python3
"""Increment VERSION, build both OS variants, and run the full test suite.

The default is a patch release bump. Use ``--bump minor`` or
``--bump major`` for other release types, and ``--bump none`` to rebuild the
current version without changing VERSION.
"""
from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
VERSION_FILE = ROOT / "VERSION"
PRODUCT_ID = "mutinrex"
SOURCE_VERSION = re.compile(r"(Mutineer-eX )[0-9]+\.[0-9]+\.[0-9]+")


class BuildError(RuntimeError):
    pass


def run(command: list[str]) -> None:
    print("+ " + subprocess.list2cmdline(command), flush=True)
    result = subprocess.run(command, cwd=ROOT)
    if result.returncode:
        raise BuildError(
            "%s failed with exit code %d" % (command[0], result.returncode)
        )


def read_version() -> str:
    version = VERSION_FILE.read_text(encoding="ascii").strip()
    if not re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", version):
        raise BuildError(
            "VERSION must contain a stable semantic version such as 1.0.0"
        )
    return version


def next_version(version: str, part: str) -> str:
    if part == "none":
        return version
    major, minor, patch = (int(value) for value in version.split("."))
    if part == "major":
        return "%d.0.0" % (major + 1)
    if part == "minor":
        return "%d.%d.0" % (major, minor + 1)
    return "%d.%d.%d" % (major, minor, patch + 1)


def write_version(version: str) -> None:
    VERSION_FILE.write_text(version + "\n", encoding="ascii", newline="\n")


def sync_source_versions(version: str) -> dict[Path, bytes]:
    """Update maintained source/screen banners and retain rollback contents."""
    originals: dict[Path, bytes] = {}
    sources = list((ROOT / "src").glob("*.bas"))
    sources += list((ROOT / "text").glob("*.txt"))
    for source in sorted(sources):
        original = source.read_bytes()
        text = original.decode("ascii")
        updated = SOURCE_VERSION.sub(r"\g<1>" + version, text)
        if updated != text:
            originals[source] = original
            source.write_text(updated, encoding="ascii", newline="")
    return originals


def build_and_test(version: str, skip_runtime_tests: bool) -> tuple[Path, Path]:
    run([sys.executable, "tools/build.py"])
    eos_atr = ROOT / "disk" / ("%s-eos-v%s.atr" % (PRODUCT_ID, version))
    sdx_atr = ROOT / "disk" / ("%s-sdx-v%s.atr" % (PRODUCT_ID, version))
    for atr in (eos_atr, sdx_atr):
        if not atr.is_file():
            raise BuildError("build did not produce " + str(atr))
        run([sys.executable, "tools/sdfs.py", "check", str(atr)])
    if not skip_runtime_tests:
        run([sys.executable, "tools/exos_remms_test.py"])
        run([sys.executable, "tools/exos_bbs_test.py"])
        run([sys.executable, "tools/rdconf_test.py"])
        run([sys.executable, "tools/sdx_rdconf_test.py"])
        run([sys.executable, "tools/sdx_rdconf_planner_test.py"])
        run([sys.executable, "tools/eos_ramdisk_test.py"])
        run([sys.executable, "tools/eos_telnet_test.py"])
        run([sys.executable, "tools/sdx_bbs_test.py"])
        run([sys.executable, "tools/sdx_ramdisk_test.py"])
        run([sys.executable, "tools/sdx_telnet_test.py"])
        run([sys.executable, "tools/sdx_ramdisk_telnet_test.py"])
    return eos_atr, sdx_atr


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--bump",
        choices=("major", "minor", "patch", "none"),
        default="patch",
        help="version component to increment (default: patch)",
    )
    parser.add_argument(
        "--skip-runtime-tests",
        action="store_true",
        help="build and validate the ATR without running emulator suites",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    original = ""
    changed = False
    source_originals: dict[Path, bytes] = {}
    try:
        original = read_version()
        version = next_version(original, args.bump)
        changed = version != original
        if changed:
            write_version(version)
            print("VERSION: %s -> %s" % (original, version), flush=True)
        else:
            print("VERSION: %s (unchanged)" % version, flush=True)
        source_originals = sync_source_versions(version)
        if source_originals:
            print("Updated %d source banner(s) to %s" %
                  (len(source_originals), version), flush=True)
        atrs = build_and_test(version, args.skip_runtime_tests)
        for atr in atrs:
            print("Built and validated " + str(atr.relative_to(ROOT)))
        return 0
    except (BuildError, OSError) as exc:
        for source, contents in source_originals.items():
            try:
                source.write_bytes(contents)
            except OSError as restore_error:
                print("Could not restore %s: %s" % (source, restore_error),
                      file=sys.stderr)
        if changed:
            try:
                write_version(original)
                print("Restored VERSION to " + original, file=sys.stderr)
            except OSError as restore_error:
                print("Could not restore VERSION: " + str(restore_error),
                      file=sys.stderr)
            else:
                # build.py keeps only the declared version's two ATRs.  A
                # failed bumped test run has already built the candidate pair,
                # so regenerate the restored version and remove that failed
                # candidate from disk/ as part of rollback.
                result = subprocess.run(
                    [sys.executable, "tools/build.py"], cwd=ROOT
                )
                if result.returncode:
                    print("Could not restore the %s disk images" % original,
                          file=sys.stderr)
        print("build-all: " + str(exc), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
