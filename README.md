# Mutineer-eX — an exBASIC BBS for exOS and SpartaDOS X

Mutineer/eX is a port of **AMIS** (Atari Message and Information System), the
1983 Atari BASIC bulletin board system by Tom Giese, revised by Larry
Burdeno and Jim Steinbrecher, to [exBASIC](https://exbasic.atari8.com) for Atari 8-bit
computers. It keeps the look and the commands of the original and adds
user accounts with passwords, message ownership (create, read, update,
delete) and a setup program.

| Document | For |
|----------|-----|
| [docs/SYSOP-GUIDE.md](docs/SYSOP-GUIDE.md) | Setting up and running a board: disks, CONFIG, the sysop account, daily operation, troubleshooting |
| [docs/SDX-GUIDE.md](docs/SDX-GUIDE.md) | SpartaDOS X image, driver selection and startup sequence |
| [docs/USER-COMMANDS.md](docs/USER-COMMANDS.md) | What callers see and the commands they use |
| [docs/MODDING.md](docs/MODDING.md) | Changing the program: source layout, building, exBASIC limits, adding commands and settings |
| [docs/MODULES.md](docs/MODULES.md) | REMMS ABI, resident session handoff, module flow and door contract |
| [docs/FILE-FORMATS.md](docs/FILE-FORMATS.md) | Every data file on the work disk, byte by byte |
| [docs/EOS-ERROR-2-REPRO.md](docs/EOS-ERROR-2-REPRO.md) | Resolved exOS startup/REMMS ABI diagnosis, exact launch sequence, live memory values and debugger address map |

## Quick start

Clone `https://github.com/rickcollette/mutinrex.git`, then:

1. Build: `python tools/build.py`. This makes an EOSFS image at
   `disk/mutinrex-eos-v<VERSION>.atr` and an SDFS 2.1 image at
   `disk/mutinrex-sdx-v<VERSION>.atr`. Both use a 65,535-sector, 16 MB geometry and contain
   the programs, text screens and a controlled sample download.
   `eossys.sys` initially activates exOS's hardware-independent JIFFY
   clock. The image includes the complete REMMS 1.10/session-9 core plus
   the Atari 850 handler `RHND850.COM` and the EOS device drivers
   `RVRFULL.sys`, `RVRTWOW.sys` and `NHAND.sys`.
   CONFIG item 16 can select manual entry, APETime, the current
   JIFFY value, or an R-Time 8 and rewrites the clock setup automatically.
   CONFIG item 17 can use exOS's `O:` RAM disk; CONFIG item 5 opens RDCONF's
   capacity-aware individual and extension-group cache picker. Altirra 1088K
   is recommended.
2. Mount the matching image as D1:. On SpartaDOS X, CONFIG item 13 can select
   **850 + MODEM**, **R-VERTER FULL + MODEM**,
   **R-VERTER 2-WIRE + MODEM**, **FUJINET**, or an existing R: handler.
   On exOS, use an existing R:, R-Verter, or FujiNet. Cold-restart after the
   startup files have been saved.
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
| `src/config.bas`, `src/config_*.bas`, `src/rdconf.bas` | CONFIG administration console, its four managers, and the offline RAM-disk planner/picker |
| `src/init.bas` | One-time INIT program for a new board |
| `lib/settings.bas` | Settings shared by the BBS and CONFIG (`D1:BBS.CFG`) |
| `text/*.txt`, `text/*.ata` | Paired ASCII and native ATASCII text screens; TEST.UDL.txt is the sample download source |
| `text/FILES.dat` | Download names and descriptions used by the 40-column categorized file list |
| `text/BJHI10.txt`, `text/SLOTHI10.txt` | Persistent top-ten score files for the bundled game doors |
| `tools/build.py` | Builds the programs plus EOSFS and SDX disk images; also emits complete WFC debugger maps as `build/WFC.lbl` and `build/WFC.lst` |
| `tools/build_all.py` | Increments `VERSION` (patch by default), builds both variants, validates both ATRs, and runs the EOS/SDX driver, cold-boot, RAM-disk, and TCP caller suites |
| `tools/release.py` | Bumps the version, validates both platforms, creates the release commit/tag, pushes, and publishes both ATRs plus checksums |
| `VERSION` | Mutineer-eX product and release-artifact version |
| `tools/atascii.py` | Converts text screens between PC text and ATASCII |
| `tools/atrx.py`, `tools/detok.py` | Extract files from a DOS 2 ATR and list tokenized Atari BASIC programs |
| `tools/sdfs.py` | Build, check, list and extract EOSFS v2 and SpartaDOS SDFS ATR images; synchronized with exOS v0.4 |
| `tools/carfs.py` | List and extract the CAR: files of an EOS cartridge image |
| `drivers/RHND850.COM` | Supported resident R: handler for a real or emulated Atari 850 |
| `drivers/RS232.COM` | Legacy Atari 850 bootstrap retained for reference |
| `tools/exos_remms_test.py` | Hidden Altirra/debugger acceptance for every EOS-native REMMS backend |
| `tools/exos_bbs_test.py`, `tools/sdx_bbs_test.py` | Persistent EOSFS/SDFS cold-boot acceptance for WFC; SDX also covers the Atari 850 handler |
| `tools/eos_ramdisk_test.py` | Formats and catalogs O:, removes every D1 core module name, and proves WFC boots with the RAM-cache flag active |
| `tools/eos_telnet_test.py`, `tools/sdx_telnet_test.py`, `tools/sdx_ramdisk_telnet_test.py` | Real NHAND/FujiNet TCP registration and MESSAGE/MAINBBS module-chain journeys, including no-D1-fallback RAM-disk paths on EOS and SDX |
| `EOS.car` | Verified exOS v0.7 release cartridge used by emulator smoke tests |
| `RESOURCES/EOSTK.atr` | Verified exOS v0.7 toolkit; the build extracts `apetime.com` from it |
| `RESOURCES/EOSMAINT.atr`, `RESOURCES/SHA256SUMS.txt` | exOS v0.7 maintenance image and release checksums |
| `original/` | The files of the 1983 disk, as extracted |
| `listings/` | Listings of the original Atari BASIC programs |
| `disk/mutinrex-eos-v<VERSION>.atr` | The versioned exOS work disk (EOSFS v2 revision `$47`, volume `MUTINREX`) |
| `disk/mutinrex-sdx-v<VERSION>.atr` | The versioned SpartaDOS X work disk (SDFS 2.1, volume `MUTINREX`) |

## Publishing a release

Commit the feature/fix changes to publish, make sure `gh auth status` shows the
GitHub account that owns the repository, and run from a clean worktree:

```
python tools/release.py
```

The script increments the patch version by default, synchronizes maintained
version banners, rebuilds and checks both images, runs the complete EOS and SDX
acceptance matrix, commits the version change, creates `v<VERSION>`, atomically
pushes the current branch and tag to `origin`, and publishes both ATRs plus
`SHA256SUMS.txt` on GitHub. Use `--bump minor`, `--bump major`, or `--bump none`
when appropriate. Use `--dry-run` to perform the local build/package, print the
remote commands, and restore the source version afterward. The script refuses
dirty trees, conflicting tags, non-fast-forward branches, and existing releases
rather than overwriting them.

## Status

Ported: the BBS (`AMIS.BBS`) as five REMMS modules, with separate INIT
and CONFIG utilities. CONFIG compacts active message data when a base path or
access level is moved; the original standalone message-file compactor
(also named `MESSAGE.COM` on the 1983 disk; the new module now uses that
filename) is still not ported. Also not ported are `CALLERS.COM` (trims the callers list),
`EXPAND.BAS` (makes the data files bigger) and `AUTODIAL` (a phone list
editor, not part of the BBS).
