# Mutineer-eX — an exBASIC BBS for exOS

Mutineer/eX is a port of **AMIS** (Atari Message and Information System), the
1983 Atari BASIC bulletin board system by Tom Giese, revised by Larry
Burdeno and Jim Steinbrecher, to [exBASIC](https://exbasic.atari8.com) for Atari 8-bit
computers. It keeps the look and the commands of the original and adds
user accounts with passwords, message ownership (create, read, update,
delete) and a setup program.

| Document | For |
|----------|-----|
| [docs/SYSOP-GUIDE.md](docs/SYSOP-GUIDE.md) | Setting up and running a board: disks, CONFIG, the sysop account, daily operation, troubleshooting |
| [docs/USER-COMMANDS.md](docs/USER-COMMANDS.md) | What callers see and the commands they use |
| [docs/MODDING.md](docs/MODDING.md) | Changing the program: source layout, building, exBASIC limits, adding commands and settings |
| [docs/MODULES.md](docs/MODULES.md) | REMMS ABI, resident session handoff, module flow and door contract |
| [docs/FILE-FORMATS.md](docs/FILE-FORMATS.md) | Every data file on the work disk, byte by byte |
| [docs/EOS-ERROR-2-REPRO.md](docs/EOS-ERROR-2-REPRO.md) | Resolved exOS startup/REMMS ABI diagnosis, exact launch sequence, live memory values and debugger address map |

## Quick start

Clone `https://github.com/rickcollette/mutinrex.git`, then:

1. Build: `python tools/build.py`. This makes
   `disk/mutinrex-v1.0.0.atr` in exOS 0.4's native EOSFS v2 format. It uses a
   65,535-sector, 16 MB geometry and contains
   the programs, text screens and a controlled sample download.
   `eossys.sys` initially activates exOS's hardware-independent JIFFY
   clock. The image includes the complete REMMS 1.10/session-9 core plus
   the EOS device drivers `RVRFULL.sys`, `RVRTWOW.sys` and `NHAND.sys`.
   CONFIG item 16 can select manual entry, APETime, the current
   JIFFY value, or an R-Time 8 and rewrites the clock setup automatically.
   CONFIG item 17 can use exOS's `O:` RAM disk and cache the five core
   modules, bundled doors and all text screens there; Altirra 1088K is recommended.
2. Mount the image as D1: in an exOS 0.4 machine. Use CONFIG item 13 to
   select a preloaded R:, full-handshake R-Verter, two-wire R-Verter, or
   FujiNet/NHAND backend, then cold-restart so exOS can load the device.
3. Type `D1:/init.com` once. It writes the default configuration, a 100-sector
   General message base, a 100-sector user database and a 100-sector caller
   activity area. Then run `D1:/config.com` to manage general settings, message
   bases, file areas and users.
4. Cold-restart after saving CONFIG. exOS loads the selected `.sys` backend
   from `eossys.sys`, then `eosauto.bat` starts `remms.com` and `wfc.com`.
   Press SELECT on the waiting screen and register the sysop account at the
   keyboard. Setting 15 can optionally use EOS's `X` command for a larger
   message/file buffer. Emulator users whose R: handler is already installed
   should leave CONFIG item 13 at NONE.

## What is in this folder

| Path | Contents |
|------|----------|
| `src/wfc.bas`, `src/mainbbs.bas`, `src/message_module.bas`, `src/files_module.bas`, `src/doors_module.bas` | The five independently loaded core BBS modules; WFC includes login/register |
| `src/door_blackjack.bas`, `src/door_slots.bas`, `text/DOORS.dat` | Blackjack and Lucky Slots doors plus their catalog |
| `src/remms.bas`, `RESOURCES/REMMS/` | exBASIC client and full REMMS 1.10/session-9 source, including all current communications drivers |
| `src/fixed_strings.asm` | Compact string storage plus the exBASIC-to-REMMS USR ABI adapters shared by the modules |
| `src/config.bas`, `src/config_*.bas` | CONFIG administration console and its four managers |
| `src/init.bas` | One-time INIT program for a new board |
| `lib/settings.bas` | Settings shared by the BBS and CONFIG (`D1:BBS.CFG`) |
| `text/*.txt`, `text/*.ata` | Paired ASCII and native ATASCII text screens; TEST.UDL.txt is the sample download source |
| `text/FILES.dat` | Download names and descriptions used by the 40-column categorized file list |
| `text/BJHI10.txt`, `text/SLOTHI10.txt` | Persistent top-ten score files for the bundled game doors |
| `tools/build.py` | Builds the programs and disk image; also emits complete WFC debugger maps as `build/WFC.lbl` and `build/WFC.lst` |
| `VERSION` | Mutineer-eX product and release-artifact version |
| `tools/atascii.py` | Converts text screens between PC text and ATASCII |
| `tools/atrx.py`, `tools/detok.py` | Extract files from a DOS 2 ATR and list tokenized Atari BASIC programs |
| `tools/sdfs.py` | Build, check, list and extract EOSFS v2 and SpartaDOS SDFS ATR images; synchronized with exOS v0.4 |
| `tools/carfs.py` | List and extract the CAR: files of an EOS cartridge image |
| `drivers/RS232.COM` | Legacy Atari 850 post-boot bootstrap; separate from the three current EOS-native REMMS backends |
| `tools/exos_remms_test.py` | Hidden Altirra/debugger acceptance for every EOS-native REMMS backend |
| `tools/exos_bbs_test.py` | Persistent EOSFS cold-boot acceptance for WFC with no R: and with all three EOS backends |
| `EOS.car` | Verified exOS v0.4 release cartridge used by emulator smoke tests |
| `RESOURCES/EOSTK.atr` | Verified exOS v0.4 toolkit; the build extracts `apetime.com` from it |
| `RESOURCES/EOSMAINT.atr`, `RESOURCES/SHA256SUMS.txt` | exOS v0.4 maintenance image and release checksums |
| `original/` | The files of the 1983 disk, as extracted |
| `listings/` | Listings of the original Atari BASIC programs |
| `disk/mutinrex-v1.0.0.atr` | The built exOS 0.4 work disk (EOSFS v2 revision `$47`, volume `MUTINREX`) |

## Status

Ported: the BBS (`AMIS.BBS`) as five REMMS modules, with separate INIT
and CONFIG utilities. Not ported yet: the original message-file compactor
(also named `MESSAGE.COM` on the 1983 disk; the new module now uses that
filename), `CALLERS.COM` (trims the callers list),
`EXPAND.BAS` (makes the data files bigger) and `AUTODIAL` (a phone list
editor, not part of the BBS).
