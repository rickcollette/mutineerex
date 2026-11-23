# NHAND

`NHAND.COM` is the compact FujiNet backend for REMMS. It installs as `R:` so
the BBS and REMMS keep their existing 850-shaped call flow, while the handler
translates those calls directly to FujiNet's network SIO device `$71`.

The sole handler source is `nhand.asm`; it is the file built and packaged as
`NHAND.COM`.

## Mutineer inbound-BBS mapping

| REMMS/R: operation | NHAND/FujiNet operation |
| --- | --- |
| `OPEN "R:"` | Open `N:TCP://:6507` as a listening TCP server |
| STATUS finds a waiting peer | Queue modem result `RING` |
| REMMS sends `ATA` | FujiNet `NET_ACCEPT` (`$41`) |
| Accepted caller | Queue `CONNECT 19200`, enter raw data mode |
| R: GET/PUT | FujiNet `NET_READ`/`NET_WRITE` |
| Remote socket closes | Return CIO 139 so REMMS performs carrier-loss recovery |
| XIO 34 with AUX1 `$80` | FujiNet `NET_CLOSE_CLIENT` (`$63`) |
| CIO CLOSE/OPEN during a BASIC handoff | Preserve the FujiNet listener and client |

Preserving the network channel across CIO CLOSE/OPEN is essential: REMMS
rebuilds its R: stream after CONNECT and across application RUN transitions.
Only the explicit hangup operation closes the current client, and it leaves the
server listening for the next caller.

The handler accepts the 850 setup calls REMMS issues: XIO 34, 36, 38, and 40.
XIO 40 supplies REMMS's 128-byte page-four receive buffer, so NHAND does not
reserve a duplicate receive queue.

XIO 42 identifies the backend through `DVSTAT`:

```text
N H 1 $19
```

The `$19` capability byte advertises an external buffer, explicit hangup, and
drain support. It deliberately omits physical DTR and CRX carrier wiring.

## FujiNet realtime clock

XIO 43 sends APETime `GETTIME` (`$93`) to FujiNet clock device `$45`. The six
returned bytes are written to the BASIC string passed to XIO:

```text
day, month, two-digit year, hour, minute, second
```

WFC identifies NHAND with XIO 42 and uses XIO 43 as the first source in the
unified time/date acquisition sequence. WFC validates the six fields, seeds the
REMMS shadow clock, and every BBS consumer refreshes and reads the SpartaDOS
COMTAB facade. If NHAND is not
installed, WFC next tries the transient direct-APETime helper, RTime8,
WiModem232, and finally local manual entry.

The WFC XIO calls use AUX1 `$0D` to preserve IOCB #5's update/read-write mode.
Using zero here rewrites the live R: IOCB and makes the next GET fail with CIO
`$83`.

## Size and placement

The handler is assembled as a SpartaDOS X relocatable block and occupies the
same pre-REMMS allocation as RHND850 and RVRFULL.

| Build | Resident bytes | Limit |
| --- | ---: | ---: |
| `NHAND.COM` | 1,205 (`$04B5`) | 1,281 (`$0501`) |

At the canonical `$1002` MEMLO, the resident range ends at `$14B7` exclusive,
below fixed-address REMMS. FujiNet still clocks a 256-byte OPEN frame, but the
frame starts at the NUL-terminated resident listener specification; the
firmware stops parsing at that NUL, so no duplicate 256-byte buffer is needed.

## Build and package

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File remms\build.ps1
python tools\nhand_handler_check.py
python tools\package_mutineer_atr.py --no-version-bump --skip-runtime-build --full-package --r-handler fujinet
python tools\inspect_mutineer_atr.py --full-package --r-handler fujinet --atr source\atr\atari-mutineer-v<VERSION>-16mb-fujinet.atr
```

Or use `make mutineer-atr-fujinet`.

The universal ATR also contains NHAND. Run `D1:STARTFN` at its SDX prompt, or
copy `STARTFN.BAT` over `AUTOEXEC.BAT` and cold-boot to make FujiNet permanent.
Do not load NHAND together with RHND850 or either R-Verter handler.

## Firmware references

The implementation is matched to these authoritative files under
`third_party/fujinet-firmware`:

- `include/fujiDeviceID.h`: network `$71`, clock `$45`
- `include/fujiCommandID.h`: OPEN/READ/WRITE/STATUS/ACCEPT/CLOSE CLIENT and
  APETime `$93`
- `lib/device/NDevice/NDevice.cpp`: four-byte network STATUS layout
- `lib/network-protocol/TCP.cpp`: `TCP://:port` listener, pending-client STATUS,
  ACCEPT, and CLOSE CLIENT behavior
- `lib/device/fujiClock/fujiClock.cpp`: six-byte APETime ordering

Live socket acceptance is available through the custom Altirra
`netsio.atdevice` profile plus the local NetSIO hub and FujiNet-PC. The
2026-10-31 `doors` run passed registration/login, Blackjack, multi-character
input, cash-out, application handoffs, logoff, REMMS lifecycle validation, and
APETime with zero REMMS failures. Its result and debugger evidence are in
`results/mutineer-telnet/20261101T023421466995Z/`.
