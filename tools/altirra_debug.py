#!/usr/bin/env python3
"""Reliable read-only Altirra debugger memory access for acceptance tests."""
from __future__ import annotations

import time

from run_wfc_dashboard_test import read_memory as _read_memory  # type: ignore


def read_memory(proc, address: int, length: int, attempts: int = 3) -> bytes:
    """Retry debugger-console synchronization failures, not test assertions."""
    for attempt in range(1, attempts + 1):
        try:
            return _read_memory(proc, address, length)
        except RuntimeError:
            if attempt == attempts or proc.poll() is not None:
                raise
            time.sleep(0.5)
    raise AssertionError("unreachable")


def read_screen(proc) -> tuple[int, bytes]:
    pointer = read_memory(proc, 0x0058, 2)
    base = int.from_bytes(pointer, "little")
    if not 0x1000 <= base <= 0xBFFF:
        raise RuntimeError(f"implausible SAVMSC screen address: ${base:04X}")
    return base, read_memory(proc, base, 40 * 24)
