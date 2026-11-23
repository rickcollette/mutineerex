# exOS WFC startup failure: reproduction, diagnosis, and resolution

Status: resolved and regression-tested on November 22, 2026.

This document records the exact launch that originally produced exOS
`ERROR- 2`, the later page-zero crashes exposed while enabling EOS R: drivers,
and the memory locations needed to debug either class of failure. Mutineer-eX
is adapted to exOS; EOS and the REMMS 1.10 ABI are unchanged.

## Exact release and launch

Build and check the release image:

```powershell
python tools/build.py
python tools/sdfs.py check disk/mutinrex-eos-v<VERSION>.atr
python tools/exos_bbs_test.py
python tools/exos_remms_test.py
```

The EOS release artifact is `disk/mutinrex-eos-v<VERSION>.atr`: 65,535 sectors of 256
bytes, 16,776,592 bytes total, EOSFS v2 revision `$47`, volume `MUTINREX`.

At cold boot, exOS reads these files in this order:

```text
D1:eossys.sys
  SET PATH=CAR:;D1:
  DEVICE JIFFY
  DEVICE D1:RVRFULL       (or RVRTWOW or NHAND when selected)

D1:eosauto.bat
  SET PATH=CAR:;D1:
  D1:remms.com
  D1:wfc.com
```

`REMMS.COM` publishes REMMS 1.10 and session contract 9. `WFC.COM` then:

1. loads `D1:BBS.CFG` and rejects every tag except `MUTINREX CFG 1`;
2. discovers REMMS through `$03E8-$03F7`;
3. checks EOS `HATABS` for an installed R: handler;
4. installs the REMMS E:/R: wrappers only when R: exists;
5. opens E: and K:, reads `SYSTEM.MET`, and draws `WFC.ATA`;
6. enters REMMS wait-call mode, or stays in local-console mode if no R:
   backend is installed.

The boot acceptance test creates persistent initialized images for NONE,
RVRFULL, RVRTWOW, and NHAND. It does not depend on emulator copy-on-write
changes made by INIT:

```powershell
python tools/exos_bbs_test.py
```

Expected result:

```text
NONE: PASS
RVRFULL: PASS
RVRTWOW: PASS
NHAND: PASS
```

## Original `ERROR- 2`

The original WFC image reserved the message editor buffer, file-transfer
buffer, and a nearly all-free-memory general buffer in every independently
loaded module. With the EOS cartridge mapped at `$A000-$BFFF`, Atari OS
`MEMTOP` was `$9C1F`. exBASIC startup advanced `BASIC_TOP` to `$9D0C`, 237
bytes beyond `MEMTOP`, and returned runtime error 2 (out of memory) to EOS.

The fix is entirely in Mutineer-eX:

- WFC is compiled without native expansion to reduce its resident image.
- only MESSAGE allocates `MsgText(1935)`;
- only FILES allocates `Blk(131)`;
- the common `Buf` calculation keeps 1,500 bytes of EOS runtime headroom;
- WFC includes only message-base metadata code, not the full message editor.

Current no-driver cold-boot values after WFC reaches its dashboard are:

```text
EXB_FREE   $8726
BASIC_TOP  $9744
MEMTOP     $9C1F
MEMLO      $3EAB
RUNAD      $40CE
SAVMSC     $9C40
```

`BASIC_TOP` is stable at `$9744` after the dashboard event loop is running,
1,243 bytes below `MEMTOP`, so the old `ERROR- 2` launch is resolved. The
buffer allocator initially reserves 1,500 bytes; one later exBASIC local
string allocation accounts for the additional 256 bytes.

## The second failure: REMMS `USR` ABI

After the heap fix, launching with an EOS R: driver exposed a separate crash.
The CPU stopped on an illegal opcode in page zero (`$0027` or `$01A0`,
depending on the build). This was not an EOS or driver defect.

REMMS 1.10 intentionally exposes the Atari BASIC `USR` convention:

- the top stack byte is an argument count;
- each argument is below it as high byte then low byte when pulled;
- the result is returned in Atari floating-point register `FR0` at
  `$00D4-$00D5`.

exBASIC uses a different convention:

- there is no argument-count byte;
- the callee pulls two bytes for every declared argument;
- the result must be in A (low) and X (high).

Directly executing `USR(RemmsApi)` therefore made REMMS pull the exBASIC
return address as an argument count. Its final `RTS` used unrelated stack
bytes and jumped into page zero.

`src/fixed_strings.asm` now exports two Mutineer-eX adapters:

| Address | Symbol | Purpose |
| --- | --- | --- |
| `$7E38` | `REMMS_CALL0` | exBASIC call to a zero-argument REMMS entry |
| `$7E4C` | `REMMS_CALL1` | exBASIC call to a one-argument REMMS entry |

The adapters remove the exBASIC arguments, construct the Atari BASIC stack
frame, jump through the published REMMS entry, copy `FR0` to A/X, and return
to exBASIC. REMMS, its public jump table, session block, and all three EOS
drivers remain unchanged.

The close call also passes its required policy argument explicitly:

```text
REMMS_CALL1(RemmsApi + 12, 0)
```

## Current WFC symbols

Rebuild before trusting these addresses. `build/WFC.lbl` and
`build/WFC.lst` are canonical for the packaged `WFC.COM`.

| Address | Symbol or use |
| --- | --- |
| `$4000` | WFC executable load base |
| `$40CE` | exBASIC run entry, written to `RUNAD` |
| `$590C` | `RemmsHasR` |
| `$5931` | `RemmsMode` |
| `$5957` | `RemmsOpen` |
| `$5966` | `RemmsClose` |
| `$5975` | `RemmsStatus` |
| `$59A1` | `RemmsGet` |
| `$59D7` | `RemmsPut` |
| `$59ED` | `RemmsConsole`, called through `REMMS_CALL0` |
| `$5D1E` | `AttachModule` |
| `$77D5` | `WfcDrawScreen` bytecode entry |
| `$799E` | `WfcModemInfo` bytecode entry |
| `$79F5` | `WaitForCall` bytecode entry |
| `$7E38` | exBASIC-to-REMMS zero-argument adapter |
| `$7E4C` | exBASIC-to-REMMS one-argument adapter |
| `$7F70` | WFC `Ready` value |
| `$7FA4` | configured `RDriver` |
| `$7FBC` | `LocalMode` |
| `$7FD6` | `BufSize` |
| `$7FD8` | `BufLen` |
| `$7FF0` | `CfgStatus` |
| `$7FF6` | discovered REMMS API pointer |
| `$7FF8` | discovered REMMS public-block pointer |
| `$7FFA` | discovered REMMS session pointer |
| `$7FFC` | `SerialReady` |
| `$804C` | `Buf` array descriptor |
| `$8726` | `EXB_FREE`, first byte after linked WFC storage |

The WFC function labels are exBASIC bytecode addresses, not native 6502
instruction addresses. Do not set Altirra CPU breakpoints on them. Use data
watchpoints, REMMS trace symbols, or the native adapter addresses instead.

## Fixed Atari OS, EOS, and REMMS locations

| Address/range | Meaning |
| --- | --- |
| `$000A-$000B` | `DOSVEC` |
| `$000C-$000D` | `DOSINI` |
| `$0058-$0059` | `SAVMSC`, display-memory pointer |
| `$006A` | `RAMTOP` |
| `$009C-$009D` | exBASIC `BASIC_TOP` pointer |
| `$00D4-$00D5` | Atari `FR0`, REMMS USR return value |
| `$02E0-$02E1` | `RUNAD` |
| `$02E2-$02E3` | `INITAD` |
| `$02E5-$02E6` | Atari OS `MEMTOP` |
| `$02E7-$02E8` | Atari OS/EOS `MEMLO` |
| `$02FC` | `CH`, last keyboard code |
| `$0300-$030B` | device control block (`DCB`) |
| `$031A-$0339` | device handler table (`HATABS`), twelve 3-byte entries |
| `$0340-$03BF` | eight 16-byte IOCBs |
| `$03E8-$03F7` | REMMS discovery record |
| `$1E00-$1E3B` | REMMS public API jump table |
| `$1E60-$1E9F` | REMMS public state block |
| `$1EB0-$200F` | REMMS session block, contract version 9 |
| `$3EAB` | first byte after the current REMMS resident allocation (`REMMS_END`) |
| `$A000-$BFFF` | mapped 8 KiB EOS cartridge bank |
| `$D01F` | `CONSOL` hardware register |
| `$D40B` | ANTIC `VCOUNT` |
| `$E456` | Atari OS `CIOV` |
| `$E459` | Atari OS `SIOV` |

The REMMS entry points are:

| Address | Entry |
| --- | --- |
| `$1E00` | install/init |
| `$1E03` | mode |
| `$1E06` | route |
| `$1E09` | open |
| `$1E0C` | close/suspend |
| `$1E0F` | status |
| `$1E12` | get |
| `$1E15` | put |
| `$1E18` | console |
| `$1E1B` | text get |
| `$1E1E/$1E21/$1E24` | pager begin/put/end |
| `$1E27` | reset |
| `$1E2A` | event |
| `$1E2D/$1E30` | text begin/end |
| `$1E33` | fail |
| `$1E36` | detach |
| `$1E39` | console configuration |

The exact REMMS internal labels are generated in `build/REMMS.lab`; the
source-correlated trace map is `build/REMMS.lst`.

## Useful live checks

At WFC, inspect the following in one debugger stop:

```text
009C L2   exBASIC BASIC_TOP
02E5 L4   OS MEMTOP and MEMLO
031A L36  HATABS; an installed backend must have one R entry
03E8 L16  REMMS discovery record
1E60 L64  REMMS public state, including installed/open/error fields
1EB0 L352 session contract 9
7F70 L2   WFC Ready
7FA4 L2   configured RDriver
7FF0 L2   BBS.CFG load status (1 is success)
7FF6 L8   REMMS pointers and SerialReady
```

The driver-free mode intentionally has no R: entry, REMMS installed flag 0,
`SerialReady=0`, and WFC `Ready=0`; the dashboard remains operational for
local logon. Driver modes must have exactly one R: entry, installed flag 1,
and `SerialReady=1`. A physical open can still report offline when the
corresponding hardware is absent; that is a valid WFC state, not a boot
failure.
