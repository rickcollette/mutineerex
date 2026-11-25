#!/usr/bin/env python3
"""Reliable Altirra debugger control and memory access for acceptance tests."""
from __future__ import annotations

import time

from run_wfc_dashboard_test import read_memory as _read_memory  # type: ignore


def _stopped(proc) -> bool:
    return any(
        window["class"] == "AltirraMainWindow"
        and "[stopped]" in str(window["title"]).casefold()
        for window in proc.window_snapshot()
    )


def halt_execution(proc, attempts: int = 5, timeout: float = 5.0) -> None:
    """Halt Altirra and verify that the asynchronous F8 command landed."""
    if _stopped(proc):
        return
    for _attempt in range(attempts):
        proc.debugger_run_break()
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            if _stopped(proc):
                return
            if proc.poll() is not None:
                raise RuntimeError("Altirra exited before debugger halt")
            time.sleep(0.05)
    titles = [
        str(window["title"])
        for window in proc.window_snapshot()
        if window["class"] == "AltirraMainWindow"
    ]
    raise RuntimeError(
        "Altirra did not enter debugger halt state: " + repr(titles)
    )


def send_debugger_command(proc, command: str, timeout: float = 3.0) -> None:
    """Submit one debugger command and wait until Altirra consumes its text."""
    marker = "Altirra> " + command
    prior = proc.debugger_text().count(marker)
    proc.debugger_command(command)
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if proc.debugger_text().count(marker) > prior:
            # The command edit is clear once the console echoes the command.
            # A short settle prevents the next WM_SETTEXT from racing the
            # current command's parser on a busy private desktop.
            time.sleep(0.05)
            return
        if proc.poll() is not None:
            raise RuntimeError(
                "Altirra exited before debugger command completed: " + command
            )
        time.sleep(0.02)
    raise RuntimeError("Altirra did not accept debugger command: " + command)


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
