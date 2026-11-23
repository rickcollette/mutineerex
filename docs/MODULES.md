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

`RUN "D1:NAME.COM"` (or `RUN "O:NAME.COM"` with the CONFIG RAM cache) replaces the current executable. The modules are linked
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

CONFIG setting 17 can add EOS's `O:` RAM disk. At cold startup,
`eosauto.bat` uses `cp` to copy the five core modules, the bundled doors and all
`.TXT`/`.ATA` screens to it,
then searches `O:` before D1: for WFC and starts all later modules from RAM.
Database, message, and file area storage stays on its configured physical
drive. Each module validates the complete cached program set before selecting
`O:` and falls back to D1: if the copy is incomplete. Use compatible PORTB/XE
extended RAM; Altirra 1088K is the verified configuration.

`tools/build.py` assembles REMMS from `RESOURCES/REMMS/src/remms_sdx.asm` with
the bundled `tools/mads.exe`. The public REMMS ABI is discovered at `$03E8`:
signature `REM` and API/public/end/session pointers. Version 1.10 is in the
public block and the session block identifies contract 9. The Mutineer-eX
build uses exBASIC's USR convention (arguments on the CPU stack, return in
A/X), not Atari BASIC's argument-count/FR0 convention.

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
