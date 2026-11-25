# REMMS module architecture

The live BBS is five separately compiled core exBASIC executables. Login and
registration run inside WFC so answering a call does not require another
disk load:

```
WFC (wait + login/register) -> MAINBBS -> MESSAGE -> MAINBBS
                                      \-> FILES   -> MAINBBS
                                      \-> DOORS   -> MAINBBS
                                            \-> door -> DOORS

Failed login loops inside WFC; MAINBBS returns to WFC after goodbye or a
lost carrier.
```

`RUN "D1:NAME.COM"` (or the explicit `O:` EOS / `DO:` SDX target selected by
RDCONF) replaces the current executable. The modules are linked
at `$4000`, above REMMS 1.10 (`$1E00` through `$3CFE`). CONFIG and
INIT remain at `$2000`; run them before REMMS, or after quitting WFC and then
cold-restart before starting the BBS again.

## Startup

exOS starts the board in this order:

```
DEVICE D1:RVRFULL  ; in eossys.sys; or RVRTWOW/NHAND/none
D1:remms.com
D1:wfc.com
```

CONFIG setting 17 enables the platform RAM cache. RDCONF selects individual
cache files or whole `.COM`, `.ATA`, `.TXT`, `.V52`, `.RIP`, and `.IG` groups.
At cold startup, `eosauto.bat` uses `cp` to populate the selected set and
starts selected modules from RAM.
Database, message, and file area storage stays on its configured physical
drive. The live message and file modules resolve `D1:AREAS.CFG` on each module
load; CONFIG and INIT are offline owners of registry updates and migrations.
REMMS installs an EOS-only CIO `O:` bridge for exBASIC. SpartaDOS X
already exposes shell drive O through the D: CIO handler, so runtime mappings
use `DO:` while SDX shell commands use `O:`.
The module chain does not silently fall back to D1 if a cached copy is missing.
Use compatible PORTB/XE
extended RAM; Altirra 1088K is the verified configuration.

`tools/build.py` assembles REMMS from `RESOURCES/REMMS/src/remms_sdx.asm` with
the bundled `tools/mads.exe`. BBS modules discover the public ABI through the
16-byte `RLOC` locator at `$3EB0`, inside REMMS's MEMLO-protected allocation.
It publishes locator version, REMMS version, session contract and the
API/public/session/end pointers. Version 1.10 is also in the public block and
the session block identifies contract 9. The Mutineer-eX build uses exBASIC's
USR convention (arguments on the CPU stack, return in A/X), not Atari BASIC's
argument-count/FR0 convention.

There is no page-three discovery mirror. DOS and PBI executable loaders may
reuse that memory during a module handoff, so the protected locator is the
only supported discovery contract.

## Resident handoff

Caller state survives every `RUN` in REMMS's session block. Mutineer-eX uses the
documented fields for name, address, ATASCII/line-feed/expert modes, online
state, current message base, access level, user number, current app and next
app. Published BASIC scratch byte `+96` records Mutineer-eX local-login mode;
`+88` remains REMMS's console-snoop field. App IDs are:

| ID | Module |
|----|--------|
| 1 | WFC |
| 2 | LOGIN state inside WFC |
| 3 | MAINBBS |
| 4 | MESSAGE |
| 5 | FILES |
| 6 | DOORS |
| 7 | Active door program |

The date/time and circular caller-log pointer use an identical exBASIC
`COMMON` declaration in every module. Identity and access do not depend on
COMMON; they are reloaded from REMMS on every module entry.

Normal caller I/O goes through REMMS-routed E:. REMMS owns the R: IOCB,
answers on `RING`, detects `CONNECT`/`NO CARRIER`, mirrors online output to
the Atari screen, and restores the caller route after a module load. XMODEM
temporarily selects the remote-only route so binary bytes are not echoed to
the local display.

Before every `RUN`, the shared loader prints `Loading MODULENAME...` and an
animated `| / - \` twiddler through the routed E: channel. Both the caller
and the local console therefore get visible feedback during module changes.

## Door contract

`DOORS.COM` reads `DOORS.DAT` from the configured data drive. Each ATASCII
line is `KEY|LEVEL|NAME|PATH`, for example:

```
B|1|Blackjack Casino|BJACK.COM
S|1|Lucky Slots|SLOTS.COM
```

The key is one character, level is 1–9, name is displayed to the caller,
and path is either a full EOS path or a filename. A filename is searched on
the RAM disk first when caching is active, then on D1:. The module hides
entries above the caller's access level and checks the level again before
launching.

An Atari executable replaces its caller and normally returns to EOS, not to
the BBS. A returning Mutineer-eX door must attach to REMMS as app 7, use routed
E: for caller I/O, then `RunModule` `DOORS.COM` as app 6. See
`src/door_blackjack.bas` and `src/door_slots.bas` for complete interactive
games, and
`src/door_scores.bas` for their persistent top-ten implementation. A legacy executable without
this return chain can still be cataloged, but it exits to the EOS prompt
when it finishes.
