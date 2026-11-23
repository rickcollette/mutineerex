#!/usr/bin/env python3
"""Run the NHAND/FujiNet caller and module journey from the SDX O: cache."""
from __future__ import annotations

import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

import sdx_telnet_test as test  # noqa: E402


test.CALLER_NAME = "SDXR"
test.USE_RAMDISK = True


if __name__ == "__main__":
    raise SystemExit(test.main())
