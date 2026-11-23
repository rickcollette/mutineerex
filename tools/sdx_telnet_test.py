#!/usr/bin/env python3
"""Register a caller and chain modules through NHAND/FujiNet on SDX or EOS."""
from __future__ import annotations

import os
import shutil
import socket
import subprocess
import sys
import time
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MUTINEER = Path(os.environ.get("MUTINEER_ROOT", r"D:\ATARI\atari-mutineer"))
SDX_CART = Path(os.environ.get("SDX_CART", r"D:\ALTIRRA\SDX450_maxflash8.car"))
FUJINET = Path(os.environ.get("FUJINET_EXE", r"D:\ATARI\fujinet-pc\fujinet.exe"))
FUJINET_SD = Path(os.environ.get("FUJINET_SD", r"D:\ATARI\fujinet-pc\SD"))
NETSIOHUB = Path(os.environ.get(
    "NETSIOHUB_ROOT",
    r"D:\ATARI\fujinet-emulator-bridge\fujinet-bridge",
))
sys.path.insert(0, str(MUTINEER / "tools"))
sys.path.insert(0, str(ROOT / "tools"))

import run_altirra_850  # type: ignore  # noqa: E402
from run_mutineer_telnet_test import stop_process_tree  # type: ignore  # noqa: E402
from altirra_debug import read_memory, read_screen  # noqa: E402

from exos_bbs_test import atascii_lines, screen_to_text  # noqa: E402
import sdfs  # noqa: E402


PORT = 6507
IMAGE_PLATFORM = "sdx"
CART = SDX_CART
CALLER_NAME = "SDXN"
TRANSPORT = "fujinet"
DRIVER_NAME = "NHAND"
DRIVER_NUMBER = 4
USE_RAMDISK = False
CALL_READY_TIMEOUT = 240.0
PROGRAMS = ("wfc", "mainbbs", "message", "files", "doors", "bjack", "slots")
CORE = PROGRAMS[:5]
SCREENS = ("WFC", "WELC", "BULL", "FUNC", "HELP", "MESGM", "FILEM", "NEWU")


class Wire:
    def __init__(self, sock: socket.socket):
        self.sock = sock
        self.data = bytearray()

    def expect(self, marker: bytes, timeout: float) -> None:
        deadline = time.monotonic() + timeout
        while marker.lower() not in self.data.lower():
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                raise TimeoutError(
                    f"timeout waiting for {marker!r}; received {bytes(self.data[-300:])!r}"
                )
            self.sock.settimeout(min(2.0, remaining))
            try:
                chunk = self.sock.recv(4096)
            except socket.timeout:
                continue
            if not chunk:
                raise ConnectionError(f"socket closed waiting for {marker!r}")
            self.data.extend(chunk)

    def send_line(self, value: str) -> None:
        time.sleep(0.8)
        for byte in value.encode("ascii"):
            self.sock.sendall(bytes((byte,)))
            time.sleep(0.01)
        self.sock.sendall(b"\x9b" if TRANSPORT == "rverter" else b"\r")


def connect(timeout: float = 180.0) -> socket.socket:
    deadline = time.monotonic() + timeout
    last_error: OSError | None = None
    while time.monotonic() < deadline:
        try:
            return socket.create_connection(("127.0.0.1", PORT), timeout=3.0)
        except OSError as exc:
            last_error = exc
            time.sleep(0.5)
    raise TimeoutError(f"port {PORT} did not accept a connection: {last_error}")


def wait_for_log(path: Path, marker: bytes, process: subprocess.Popen,
                 timeout: float, restart=None) -> subprocess.Popen:
    """Wait until FujiNet and the Atari have completed a specific handshake."""
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if process.poll() is not None:
            if restart is None:
                raise RuntimeError("FujiNet exited during startup")
            time.sleep(0.5)
            process = restart()
        try:
            if marker in path.read_bytes():
                return process
        except OSError:
            pass
        time.sleep(0.1)
    raise TimeoutError(f"FujiNet log did not contain {marker!r}")


def write_fujinet_config(path: Path) -> None:
    path.write_text(
        """[General]
devicename=MutineerSDXE2E
hsioindex=8
rotationsounds=0
configenabled=0
boot_mode=0
status_wait_enabled=1
printer_enabled=0

[WiFi]
enabled=1
SSID=Mutineer Test
passphrase=

[Network]
sntpserver=pool.ntp.org

[Modem]
modem_enabled=0
sniffer_enabled=0

[ENABLE]
enable_device_slot_1=0
enable_device_slot_2=0
enable_device_slot_3=0
enable_device_slot_4=0
enable_device_slot_5=0
enable_device_slot_6=0
enable_device_slot_7=0
enable_device_slot_8=0
enable_apetime=1
enable_pclink=0

[BOIP]
enabled=1
host=localhost
port=

[Serial]
port=
""",
        encoding="utf-8",
    )


def make_case(target: Path) -> None:
    version = (ROOT / "VERSION").read_text(encoding="ascii").strip()
    source = ROOT / "disk" / f"mutinrex-{IMAGE_PLATFORM}-v{version}.atr"
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
        "D1:", "D1:", "D1:", "D1:", str(DRIVER_NUMBER), "1", "0", "1",
        "1" if USE_RAMDISK else "0",
    )
    files["SYSTEM.MET"] = atascii_lines("1", "0", "0")
    files["USERS.DAT"] = b"*\x9b" + bytes(4096)
    files["CALLERS.DAT"] = b"*\x9b" + bytes(4096)
    files["BBSDATE.TXT"] = atascii_lines("11/23/2026")
    files["BBSTIME.TXT"] = atascii_lines("12:00:00")
    if IMAGE_PLATFORM == "eos":
        system = ["SET PATH=CAR:;D1:", "DEVICE JIFFY"]
        if USE_RAMDISK:
            system.append("DEVICE RAMDISK")
        system.append(f"DEVICE D1:{DRIVER_NAME}")
        files["eossys.sys"] = atascii_lines(*system)
        startup = ["SET PATH=CAR:;D1:"]
        if USE_RAMDISK:
            startup.append("FORMAT /QQ O:")
            startup.extend(f"cp D1:{name}.com O:{name}.com" for name in PROGRAMS)
            startup.extend(
                f"cp D1:{name}.{extension} O:{name}.{extension}"
                for name in SCREENS for extension in ("TXT", "ATA")
            )
            # A successful caller journey cannot be using a hidden D1 fallback.
            startup.extend(f"REN D1:{name}.com {name}.bak" for name in CORE)
            startup.append("SET PATH=CAR:;O:;D1:")
        startup.extend(("D1:remms.com", "DO:wfc.com" if USE_RAMDISK else "D1:wfc.com"))
        files["eosauto.bat"] = atascii_lines(*startup)
    else:
        startup = []
        if USE_RAMDISK:
            startup.extend(
                f"COPY D1:{name}.COM O:{name}.COM" for name in PROGRAMS
            )
            startup.extend(
                f"COPY D1:{name}.{extension} O:{name}.{extension}"
                for name in SCREENS for extension in ("TXT", "ATA")
            )
            # A successful caller journey cannot use a hidden D1 fallback.
            startup.extend(f"RENAME D1:{name}.COM {name}.BAK" for name in CORE)
        startup.extend((
            f"D1:{DRIVER_NAME}.COM",
            "D1:REMMS.COM",
            "O:WFC.COM" if USE_RAMDISK else "D1:WFC.COM",
        ))
        files["AUTOEXEC.BAT"] = atascii_lines(*startup)
    sdfs.build(str(target), 65535, 256, files,
               volname="MUTINREX", eosfs=IMAGE_PLATFORM == "eos")


def main() -> int:
    run_altirra_850.validate_canonical_runtime()
    required = [CART]
    if TRANSPORT == "fujinet":
        required.extend((FUJINET, FUJINET_SD, NETSIOHUB / "netsiohub"))
    missing = [str(path) for path in required if not path.exists()]
    if missing:
        raise SystemExit("missing required path(s): " + ", ".join(missing))
    work = ROOT / "tmp" / f"mutinrex-{IMAGE_PLATFORM}-telnet-test"
    work.mkdir(parents=True, exist_ok=True)
    atr = work / "nhand.atr"
    profile = work / "Altirra.ini"
    debug_log = work / "altirra.log"
    transcript = work / "transcript.bin"
    fujinet_config = work / "fujinet.ini"
    fujinet_log_path = work / "fujinet.log"
    hub_log_path = work / "netsiohub.log"
    make_case(atr)
    if TRANSPORT == "fujinet":
        write_fujinet_config(fujinet_config)
    run_altirra_850.write_profile(
        profile, PORT, inbound=True, serial_device=TRANSPORT
    )
    if USE_RAMDISK:
        profile.write_text(
            profile.read_text(encoding="utf-8").replace(
                '"Memory mode" = 4', '"Memory mode" = 6'
            ),
            encoding="utf-8",
        )
    global_ini = run_altirra_850.ALTIRRA_INI
    saved_ini = global_ini.read_bytes() if global_ini.exists() else None
    shutil.copy2(profile, global_ini)
    command = [
        str(run_altirra_850.ALTIRRA.resolve()),
        "/portable",
        "/cart", str(CART.resolve()),
        "/debug",
        "/debugcmd", ".logopen " + str(debug_log.resolve()),
        "/debugcmd", "g",
        "/bootrw", str(atr.resolve()),
    ]
    proc = None
    fujinet_proc = None
    hub_proc = None
    fujinet_log = None
    hub_log = None
    wire = None
    failures: list[str] = []
    try:
        if TRANSPORT == "fujinet":
            hub_log = hub_log_path.open("wb")
            hub_proc = subprocess.Popen(
                [sys.executable, "-m", "netsiohub"],
                cwd=NETSIOHUB,
                stdout=hub_log,
                stderr=subprocess.STDOUT,
                creationflags=subprocess.CREATE_NO_WINDOW,
            )
            time.sleep(1.0)
            if hub_proc.poll() is not None:
                raise RuntimeError("NetSIO hub exited during startup")
        proc = run_altirra_850.launch_isolated(command, run_altirra_850.ALTIRRA.parent)
        if TRANSPORT == "fujinet":
            fujinet_log = fujinet_log_path.open("wb")
            def start_fujinet():
                return subprocess.Popen(
                    [str(FUJINET), "-c", str(fujinet_config), "-s", str(FUJINET_SD)],
                    cwd=FUJINET.parent,
                    stdout=fujinet_log,
                    stderr=subprocess.STDOUT,
                    creationflags=subprocess.CREATE_NO_WINDOW,
                )

            fujinet_proc = start_fujinet()
            # Connecting on NHAND's first network STATUS can queue RING while
            # REMMS is still clearing its startup state.  Wait for the first
            # confirmed idle listener poll, then introduce the caller.
            fujinet_proc = wait_for_log(
                fujinet_log_path,
                b"sio_status_channel() - BW: 0 C: 0",
                fujinet_proc,
                240.0,
                restart=start_fujinet,
            )
            deadline = time.monotonic() + 240.0
            last_error: OSError | None = None
            while True:
                if fujinet_proc.poll() is not None:
                    fujinet_proc = start_fujinet()
                try:
                    sock = socket.create_connection(("127.0.0.1", PORT), timeout=3.0)
                    break
                except OSError as exc:
                    last_error = exc
                if time.monotonic() >= deadline:
                    raise TimeoutError(
                        f"port {PORT} did not accept a connection: {last_error}"
                    )
                time.sleep(0.5)
        else:
            sock = connect(timeout=240.0)
        ready_deadline = time.monotonic() + CALL_READY_TIMEOUT
        while True:
            candidate = Wire(sock)
            try:
                # NHAND's inbound listener is single-shot.  Keep the first
                # accepted connection while the BBS finishes booting; closing
                # it merely because the prompt took 30 seconds leaves no
                # listener for a reconnect.
                candidate.expect(
                    b"HIT <RETURN>",
                    max(1.0, ready_deadline - time.monotonic()),
                )
                wire = candidate
                break
            except ConnectionError:
                sock.close()
                if time.monotonic() >= ready_deadline:
                    raise
                sock = connect(timeout=ready_deadline - time.monotonic())
        with sock:
            wire.send_line("")
            wire.expect(b"Do you require Line Feeds", 30.0)
            wire.send_line("N")
            wire.expect(b"Enter your Name >", 30.0)
            wire.send_line(CALLER_NAME)
            wire.expect(b"Register as a new user", 45.0)
            wire.send_line("Y")
            wire.expect(b"From City,State >", 45.0)
            wire.send_line("CHI")
            wire.expect(b"CORRECT", 45.0)
            wire.send_line("Y")
            wire.expect(b"Choose a 4 character password >", 45.0)
            wire.send_line("T123")
            wire.expect(b"Type it again >", 45.0)
            wire.send_line("T123")
            wire.expect(b"A,B,C,D,F,G,H,L,M,T,W,X,Y,Z,? >", 60.0)
            wire.send_line("M")
            wire.expect(b"Preparing MESSAGE", 45.0)
            source = (b"RAMDISK:message.com" if USE_RAMDISK
                      else b"D1:message.com")
            wire.expect(b"Loading MESSAGE from " + source, 45.0)
            wire.expect(b"MESSAGE >", 120.0)
            wire.send_line("X")
            wire.expect(b"Preparing MAINBBS", 45.0)
            source = (b"RAMDISK:mainbbs.com" if USE_RAMDISK
                      else b"D1:mainbbs.com")
            wire.expect(b"Loading MAINBBS from " + source, 45.0)
            if b"\x00" in wire.data:
                failures.append("remote transcript contained NUL bytes")
    except Exception as exc:
        failures.append(f"{type(exc).__name__}: {exc}")
        if proc is not None:
            try:
                proc.debugger_run_break()
                time.sleep(0.5)
                _, screen = read_screen(proc)
                screen_text = "\n".join(
                    screen_to_text(screen[offset:offset + 40])
                    for offset in range(0, len(screen), 40)
                ).strip()
                failures.append("console at failure: " + " | ".join(
                    line.rstrip() for line in screen_text.splitlines()
                    if line.strip()
                ))
                hatabs = read_memory(proc, 0x031A, 36)
                devices = []
                for offset in range(0, len(hatabs), 3):
                    if hatabs[offset]:
                        address = hatabs[offset + 1] | hatabs[offset + 2] << 8
                        devices.append(f"{chr(hatabs[offset])}:${address:04X}")
                failures.append("HATABS at failure: " + ", ".join(devices))
                anchors = read_memory(proc, 0x03EC, 8)
                public = anchors[2] | anchors[3] << 8
                session = anchors[6] | anchors[7] << 8
                public_state = read_memory(proc, public, 12)
                session_state = read_memory(proc, session, 161)
                failures.append(
                    "REMMS at failure: "
                    f"public={public_state.hex(' ')}; "
                    f"online={session_state[87]} "
                    f"physical={session_state[139]} "
                    f"connection={session_state[140]} "
                    f"event={session_state[141]}/{session_state[142]} "
                    f"cio={session_state[143]} "
                    f"wfc={session_state[154]} "
                    f"profile={session_state[157]} "
                    f"rings={session_state[160]}/{session_state[159]}"
                )
            except Exception as debug_exc:
                failures.append(f"could not read failure console: {debug_exc}")
    finally:
        if wire is not None:
            transcript.write_bytes(wire.data)
        if proc is not None:
            try:
                stop_process_tree(proc)
            finally:
                if proc.poll() is None:
                    proc.terminate()
                    try:
                        proc.wait(timeout=5)
                    except subprocess.TimeoutExpired:
                        proc.kill()
                        proc.wait(timeout=5)
        if fujinet_proc is not None:
            fujinet_proc.terminate()
            try:
                fujinet_proc.wait(timeout=10)
            except subprocess.TimeoutExpired:
                fujinet_proc.kill()
        if hub_proc is not None:
            hub_proc.terminate()
            try:
                hub_proc.wait(timeout=10)
            except subprocess.TimeoutExpired:
                hub_proc.kill()
        if fujinet_log is not None:
            fujinet_log.close()
        if hub_log is not None:
            hub_log.close()
        if saved_ini is None:
            global_ini.unlink(missing_ok=True)
        else:
            global_ini.write_bytes(saved_ini)
    label = IMAGE_PLATFORM.upper() + " " + DRIVER_NAME + " TELNET"
    print(label + ": " + ("FAIL" if failures else "PASS"))
    if wire is not None:
        print(f"{label}: received {len(wire.data)} bytes; NUL={b'\x00' in wire.data}")
    for failure in failures:
        print(label + ": " + failure)
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
