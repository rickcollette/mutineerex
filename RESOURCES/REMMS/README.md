# REMMS

## exOS packaging in Mutineer-eX

Mutineer-eX carries the full REMMS 1.10/session-9 source and builds the three
current communications backends as native exOS device files:

```text
RVRFULL.sys   R-Verter with DTR/carrier wiring
RVRTWOW.sys   R-Verter RX/TX two-wire profile
NHAND.sys     FujiNet N: TCP server backend
```

The code retains MADS's `blk sparta` relocatable encoding because current
exOS deliberately implements that loader ABI. `eossys.sys` selects exactly
one backend with `DEVICE D1:name`. The lowercase `.sys` extension is required
because exOS appends lowercase `.sys` and native EOSFS filenames are
case-sensitive. `REMMS.COM` then loads at `$1E00-$3CFE` after the backend.

Run `python tools/build.py` from the Mutineer-eX repository root to build the
matched core, every backend and the final EOSFS image. Run
`python tools/exos_remms_test.py` for debugger-only exOS loader acceptance.

REMMS is a clean resident modem/input layer for Mutineer BBS. It is not a
drop-in MMS ABI clone. The BBS side should be adjusted to this API so local
console operation is explicit and cannot be blocked by modem state.

## Why This Exists

The WFC failure mode points at the wrong state model:

- MMS mixes local keyboard routing with modem/session lifecycle checks.
- MOE and Carina keep local operator input separate from remote modem input.
- REMMS keeps that separation explicit: local mode never polls `R:`, while a
  connected blocking remote read waits for remote text and leaves local
  START/SELECT/OPTION handling to the independent console/event path.

REMMS follows the MOE rule directly:

```text
mode = local: never poll/check/read/write modem from local input paths
mode = host: poll R: only after explicit host open; no bytes means retry/event pump
```

## Build

```powershell
.\remms\build.ps1
```

Default assembler path:

```text
D:\Mad-Assembler-2.1.6\bin\windows_x86_64\mads.exe
```

Output:

```text
remms\build\REMMS.COM
remms\build\REMMS.LST
remms\build\REMMS.LAB
remms\build\RVRFULL.COM
remms\build\RVRTWOW.COM
remms\build\NHAND.COM
remms\build\TDAPE.COM
```

The two R-Verter files are compact SDX-relocatable direct-POKEY `R:` backends
that fit in RHND850's pre-REMMS allocation. See
[rverter/README.md](rverter/README.md) for wiring profiles, packaging,
capability semantics, and debugger acceptance.

`NHAND.COM` is the compact FujiNet backend. It converts REMMS's inbound modem
flow into FujiNet N: TCP server operations and exposes the FujiNet realtime
clock through XIO 43. See [nhand/README.md](nhand/README.md).

`TDAPE.COM` is WFC's transient direct-APETime SIO helper. The holdover clock is
embedded at the tail of `REMMS.COM`. Its deferred VBI advances a private
six-byte shadow because SpartaDOS disk CIO uses COMTAB's clock fields as file
timestamp workspace. BASIC calls GET at `$3BFB` to restore the shadow into
COMTAB before reading it; WFC calls SET at `$3C1F` after acquiring and seeding
a source. Packaging loads the selected communications handler and `REMMS.COM`;
there is no separate clock binary. Stock `DEVICE JIFFY` is excluded because
its allocation conflicts with Mutineer's BASIC program space.

## Resident Model

- Default base is `$1E00`.
- Loading the COM installs REMMS through `INITAD` and raises `MEMLO`.
- REMMS wraps `E:`, `K:`, and `R:` while retaining validated original vectors.
- The E:/K: wrappers remain installed in every route and directly chain the
  saved handler vectors for local operations.
- `R:` is opened only by the explicit host-open API.
- Local mode is the default after install and after close.

Do not reload a new REMMS binary over an already active REMMS instance. Reboot
Altirra before loading a rebuilt resident, or add an explicit restore/uninstall
path before supporting live reloads.

## Discovery Record

REMMS publishes a small record at `$03E8` for BASIC/loader code:

| Offset | Meaning |
| --- | --- |
| `+0..+2` | Signature: `REM` |
| `+3` | Major version |
| `+4..+5` | API jump-table address |
| `+6..+7` | Public state address |
| `+8..+9` | Resident end address |
| `+10..+11` | BBS session block address |

## API

REMMS 1.10 exposes this compact jump table at the published API address:

| Offset | BASIC Call | Meaning |
| --- | --- | --- |
| `+00` | `USR(API)` | install/reinstall handlers |
| `+03` | `USR(API+3,mode)` | set mode: `0=local`, `1=host` |
| `+06` | `USR(API+6,route)` | set output route: `0=local`, `1=remote`, `2=both` |
| `+09` | `USR(API+9,policy)` | open `R:`; `0=connected resume`, `1=fresh WFC` |
| `+12` | `USR(API+12)` | close `R:` and return to local mode |
| `+15` | `USR(API+15)` | remote bytes waiting, or `0` in local mode |
| `+18` | `USR(API+18)` | exact raw remote byte or a structured `$010x` result |
| `+21` | `USR(API+21,byte)` | transmit one byte to `R:` in host mode |
| `+24` | `USR(API+24)` | local console command poll |
| `+27` | `USR(API+27)` | canonical translated text byte or a structured result |
| `+30/+33/+36` | `PBEGIN` / `PPUT` / `PEND` | one resident pager operation |
| `+39` | `RRESET` | reset only after physical ownership is reconciled |
| `+42` | `REVENT` | perform one synchronous event-pump pass |
| `+45/+48` | `TBEGIN` / `TEND` | begin/end resident text ownership |
| `+51` | `RFAIL(reason)` | record failure and reconcile the modem owner |
| `+54` | `RDETACH` | detach REMMS and restore saved handlers |
| `+57` | `RCONCFG(snoop)` | configure local console mirroring |

Public byte `RPUB+63` is shared WFC/time-date metadata. Bit 0 records whether
the WFC screen image is loaded, bits 1-3 hold TD status (`0` uninitialized,
`1` synchronized, `2` holdover, `3` invalid), and bits 4-6 hold the source
(`0` none, `1` NHAND, `2` APETime, `3` RTime8, `4` WiModem, `5` manual).
Bit 7 records an active RIPscrip caller. Writers preserve the other fields.

RIP is a negotiated text-compatible mode, not a third `AMODE` value. Its
invariant is `AMODE=0`, `LMODE=1`, and `RPUB+63` bit 7 set. WFC sends the raw
`ESC[!` probe, accepts `RIPSCRIPxxyyvs` at version 1.54 or newer, then sends
`ESC[2!`; rejection and downgrade send `ESC[1!`.

Use raw `+18/+21` for terminal detection, XMODEM, and other binary protocols.
Use translated `+27`, or the wrapped `E:`/`K:` input path, for commands and
line editing.

`RGET` returns bytes `0..255`, `$0100` no data, `$0101` carrier loss, `$0103`
fatal I/O, or `$0104` timeout. `RPUT` returns zero or the corresponding
carrier/fatal/timeout result. Printable data, including literal or split
`NO CARRIER`, is never interpreted by these raw APIs.

In ASCII mode, text input maps BEL `07` to ATASCII `FD`, BS `08` to `7E`, TAB
`09` to `7F`, a lone LF `0A` to a space, FF `0C` to clear `7D`, CR `0D` to EOL
`9B`, and `1C..1F` to spaces. CRLF and CRNUL are coalesced to one EOL. Ctrl-C
and Ctrl-S are discarded. ATASCII mode passes text bytes through, while an
optional transport LF/NUL following native ATASCII EOL is coalesced so it
cannot appear as a graphics character in the next input field.

ASCII output maps ATASCII EOL to CR plus the configured optional LF, `7E` to
BS, `7F` to one space, `FD` to BEL, and `7D` to `ESC[2J ESC[H`. This corrects
MOE's unreachable bell branch.

Console poll returns:

| Return | Input |
| --- | --- |
| `0` | none |
| `1` | START |
| `2` | SELECT |
| `3` | OPTION |
| `1` | keyboard alias `L` |
| `2` | keyboard alias `S` |
| `3` | keyboard alias `!` |

## BBS WFC Rule

WFC should poll local console command first. When START enters local BBS mode:

```text
USR(API+3,0)   ; mode local
USR(API+6,0)   ; output local
```

Local mode is the key invariant. In that state REMMS status/get paths return
without touching `R:`, so a missing modem cannot bounce the operator back to
WFC or poison later local key checks.

## BBS Session Block

Runtime BASIC modules use the session pointer from `$03F2/$03F3`. The block is
REMMS-owned state, not an MMS ABI:

| Offset | Meaning |
| --- | --- |
| `+0..+1` | Magic/version: `77`, `9` |
| `+2..+83` | user name/address strings |
| `+84..+87` | terminal modes and online state |
| `+90..+93` | requested and return app keys |
| `+102` | current app handle |
| `+123..+127` | access/user/time fields |
| `+128..+138` | resident pager configuration and state |
| `+139..+158` | lifecycle, event, CIO, text, and ownership telemetry |
| `+159..+160` | answer-rings setting (`1..9`) and current ring count |
| `+163..+337` | versioned transfer/file-store control workspace |
| `+338..+339` | transfer mark-session token |
| `+340..+351` | message service control block |

## Concurrent R: Buffer And XMODEM Helper

XIO 40 uses a 128-byte concurrent input buffer at `$03FD..$047C`. XMODEM and
YMODEM load native transfer protocol binaries under `transfer/build` through
APPMGR. They use the REMMS transfer service table published in the discovery
record, leaving protocol bytes on the raw API.

`REMMS.COM` and the protocol COM files are a matched build set. Package and
validate them together; the resident end must remain at or below `$3CFF`.
REMMS 1.10, including the embedded unified TD clock, ends exactly at the
authoritative `$3CFF` ceiling. The BASIC memory check independently enforces
headroom below screen workspace.

Translated text uses a separate 64-byte FIFO overlaid on the inactive transfer
path workspace. Ordinary input stops at 60 bytes; the final four bytes are
reserved for pager controls. The emulated 850 can rotate an unpaced snapshot
at the 64-byte boundary even when XIO 40 was given a larger buffer. REMMS
therefore rejects any single text snapshot at or above 60 bytes, rebuilds the
concurrent stream, and reports a recoverable overflow. BASIC
restarts the entire field, so a shortened prefix is never accepted.

Disk suspension closes `R:` and the next `TBEGIN` discards stale typeahead and
the translated FIFO before reopening input. REMMS does not emit in-band
XOFF/XON markers; modern ASCII and RIP terminals can render them as visible
triangle or punctuation glyphs. Callers and tests wait for the complete live
prompt instead of a transport marker.

## Page-Six Menu Helpers

The matched `REMMS.COM` also installs two nonresident BASIC accelerators in
page six without raising `MEMLO`:

- `$0601`: emit a buffered menu. The local editor receives one CIO buffer
  operation; the remote side remains on `remms_output_shared` so ASCII EOL and
  clear translation, ATASCII transparency, and carrier failure are unchanged.
- `$06C4`: read up to the requested count from disk IOCB #1 into a BASIC
  string and return CIO's actual transferred-byte count.

The first helper ends before `$06C4`; the reader ends before scratch at
`$06FA`. `remms_contract_check.py` validates those assembled label boundaries
to prevent silent overlapping MADS segments. Disk-backed menu readers use the
bulk helpers without retaining an in-memory menu cache; paged documents
continue through the resident byte/pager path.
