#!/usr/bin/env python3
"""Run the NHAND/FujiNet caller and RAM-disk module journey under EOS."""
from __future__ import annotations

import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

import sdx_telnet_test as test  # noqa: E402


test.IMAGE_PLATFORM = "eos"
test.CART = ROOT / "EOS.car"
test.CALLER_NAME = "EOSN"
test.TRANSPORT = "fujinet"
test.DRIVER_NAME = "NHAND"
test.DRIVER_NUMBER = 4
test.USE_RAMDISK = True


if __name__ == "__main__":
    raise SystemExit(test.main())
