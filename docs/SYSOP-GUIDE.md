# Mutineer-eX Sysop Guide

This guide is for the system operator (sysop): what Mutineer-eX needs, how to
make the work disk, how to set the board up the first time, how to run
it every day and what to do when something goes wrong.

## 1. What you need

| Item | Notes |
|------|-------|
| Atari 8-bit computer with 48 KB or more, or an emulator | The exBASIC Studio emulator profile *Atari 800XL (NTSC)* is set up for Mutineer-eX |
| exOS 0.4 cartridge | Its DOS gives the D: device with NOTE and POINT (needed by the message and caller files), the start-up batch, the clock, and an `RS232` command for a physical Atari 850 |
| An EOSFS v2 work disk | `disk/mutinrex-eos-v<VERSION>.atr`, volume `MUTINREX` |
| An R: device | A preloaded emulator R:, an R-Verter using `RVRFULL.sys`/`RVRTWOW.sys`, or FujiNet using `NHAND.sys` |
| A Hayes compatible modem | Real or emulated; Mutineer-eX sends `ATZ`, the init string, `ATA` to answer and drops DTR to hang up |
| A printer on P: (optional) | The activity log, as on the original board |

### The emulator setup in exBASIC Studio

The Studio profile *Atari 800XL (NTSC)* has EOS on and an R: device in
`rverter` mode with a modem, listening on TCP port **9097** at 19200
baud. To call your board from the PC, connect a telnet client to
`localhost` port 9097 while Mutineer-eX is waiting for a call: the emulated
modem gives a RING, Mutineer-eX answers, and you see the logon.

Mount `disk/mutinrex-eos-v<VERSION>.atr` as drive 1 in the profile.

### The emulator setup in Altirra

For an R-Verter device select **RVRFULL** only when DTR and carrier wiring are
present; select **RVRTWOW** for RX/TX-only hardware. For FujiNet select
**NHAND**, which exposes an inbound TCP listener through the N: device.
CONFIG writes the corresponding `DEVICE D1:name` line and requires a cold
restart. Altirra's preloaded/high-level R: modes use **NONE**.

The old `RS232.COM` choice remains for legacy Atari 850 experiments, but it is
not one of the converted REMMS 1.10 drivers and is not part of the exOS driver
acceptance suite.

If the board hangs up as soon as a caller connects, turn **Carrier watch**
off in CONFIG (see [CONFIG](#4-config-the-settings)): some modems and
emulators don't report the carrier detect line.

## 2. Building the work disk

From the project folder:

```
python tools/build.py
```

This compiles REMMS 1.10, all three EOS communications drivers, the five core
BBS modules, bundled doors and two administration programs, then writes the
tested native EOSFS v2 work disk `disk/mutinrex-eos-v<VERSION>.atr`. The image uses the maximum 65,535-sector geometry
(about 16 MB) and leaves ample room for INIT's three 100-sector data areas.
The build uses the filesystem writer synchronized from exOS v0.4. The files:

| File | What it is |
|------|------------|
| `remms.com` | Full REMMS 1.10 resident modem routing and session-9 handoff |
| `RVRFULL.sys` | EOS device for a full-handshake R-Verter (`$1F` capabilities) |
| `RVRTWOW.sys` | EOS device for a two-wire R-Verter (`$19` capabilities) |
| `NHAND.sys` | EOS device mapping REMMS R: operations to a FujiNet N: TCP listener |
| `TDAPE.COM` | Transient direct APETime helper from the matched REMMS source |
| `wfc.com` | Wait for call plus login and registration; starts the module chain |
| `mainbbs.com` | Main command loop |
| `message.com` | Message bases |
| `files.com` | File bases and transfers |
| `doors.com` | Access-filtered door catalog and launcher |
| `bjack.com` | Blackjack game door with a session bankroll |
| `slots.com` | Lucky Slots three-reel game door |
| `config.com` | General, message-base, file-area and user administration (`CONFIG`) |
| `init.com` | One-time creation of a new board (`INIT`) |
| `RS232.COM` | Legacy Atari 850 bootstrap retained separately from the EOS-native REMMS drivers |
| `apetime.com` | Gets PC date/time from an APE, AspeQt or RespeQt SIO host; CONFIG checks whether it succeeded |
| `eossys.sys` | Loads the selected R-Verter/NHAND backend, clock, and optional RAM disk through exOS `DEVICE` lines |
| `eosauto.bat` | Lowercase exOS startup file; the pristine image adds D1: to `PATH`, and INIT/CONFIG replace it with the BBS startup |
| `WELC.TXT` / `WELC.ATA` | ASCII/ATASCII welcome screens |
| `BULL.TXT` / `BULL.ATA` | Bulletin shown after logon and by main command B |
| `NEWU.TXT` / `NEWU.ATA` | New-user information |
| `FUNC.TXT` / `FUNC.ATA` | Main command list (main command ?) |
| `HELP.TXT` / `HELP.ATA` | Command help (main command H) |
| `MESGM.TXT` / `MESGM.ATA` | Message-area submenu (main command M) |
| `FILEM.TXT` / `FILEM.ATA` | File-area submenu (main command F) |
| `FILES.DAT` | Controlled download names and descriptions used by the categorized file list |
| `DOORS.DAT` | `KEY|LEVEL|NAME|PATH` door catalog on the data drive |
| `BJHI10.TXT`, `SLOTHI10.TXT` | Persistent top-ten game scores on the data drive |
| `TEST.TT1` | Sample level-1 tool/text download |

`python tools/build.py --no-disk` builds only the programs. Studio can
edit the source, but the BBS build must include `src/fixed_strings.asm`;
use the build script.

Building the disk again replaces it, and with it the messages, callers
and users on it. Keep a copy of a disk in use, or copy only the new
programs to it.

## 3. First-time setup

Do these steps once, in this order.

### Step 1: INIT

Type `D1:/init.com` at the exOS prompt and confirm the destructive warning. INIT is
only for a new board. It writes the default `D1:BBS.CFG` and
`D1:eosauto.bat`, creates message base A as **GENERAL** at access level 1,
allocates 100 sectors for that base, creates a 100-sector `USERS.DAT`, and
allocates a 100-sector circular `CALLERS.DAT` plus `SYSTEM.MET`.

Running INIT again replaces all message bases, users and caller history on
the default D1: drives. Routine administration never requires INIT.

### Step 2: CONFIG

Type `D1:/config.com`. Its main menu has four managers:

1. **General Config** — the basic BBS, modem, drive and startup settings.
2. **Message Bases** — list, add, edit, clear or remove any A–Z base. Editing
   changes its name, description or minimum access level while retaining
   messages. Clear recreates the selected base and deletes its messages.
3. **File Areas** — register a file already copied to the downloads drive,
   assign its controlled name/category/type/level and description, edit the
   entry, or remove the entry and physical file.
4. **User Editor** — list, create, fully edit, approve, ban or remove users.
   A banned user is stored at level 0 and cannot log in.

In General Config, at least review **1 SYSOP**, **13 R DRIVER**, **16 CLOCK**, **17 RAM CACHE**, and the
four drive settings. Press **S** there to write `D1:BBS.CFG` and
both lowercase startup files. Cold-restart after changing item 13.
`BBS.CFG` itself always stays on D1:.

### Step 3: the sysop account

Type `D1:/remms.com` then `D1:/wfc.com` (or restart the computer to let exOS start them), and when the waiting screen
appears press **SELECT**: this logs you on at the keyboard (local mode).
Press RETURN, enter the sysop account name you set in CONFIG, answer Y to
register, and choose a 4 character password. Do this before allowing public
calls: the first account registered is user 1 and is always level 9.

The configured sysop name can only be registered at the keyboard, never by a
caller. Both user 1 and the configured account are always level 9 and cannot
be downgraded. Logged on with either, you can moderate every message and file
and change user access levels with Z. CONFIG's User Editor can instead
create the sysop before the first BBS run; the first user and the configured
sysop are forced to level 9.

## 4. CONFIG managers

### General Config

| # | Setting | Default | Meaning |
|---|---------|---------|---------|
| 1 | Sysop account | `SYSOP` | User name with sysop rights; also the name the Y (yell) command calls |
| 2 | Printer log | ON | Log the activity on P:. If the printer doesn't answer, the BBS turns the log off by itself and says so on the screen |
| 3 | Carrier watch | ON | The R: handler reports a lost carrier (error 139) and the BBS hangs up. Turn it off if the modem or emulator has no carrier detect |
| 4 | Idle hang-up | 5 minutes | Hang up when the caller types nothing for this long |
| 5 | Baud rate | 19200 (code 15) | Speed between the Atari and the modem: 300, 1200, 2400, 4800, 9600 or 19200 |
| 6 | Modem init | `ATE0 Q0 V1 S2=255 S4=24 S7=15` | Sent after `ATZ` when the BBS starts waiting for a call. Keep echo off (`E0`) and textual result codes enabled (`Q0 V1`) |
| 7 | Download chunk | 1024 bytes | Bytes read from the disk at a time during a download |
| 8 | XMODEM buffer | 8 blocks | Blocks of 128 bytes received before they are written to the disk during an XMODEM upload |
| 9 | Users/callers drive | `D1:` | `SYSTEM.MET`, `USERS.DAT`, `CALLERS.DAT` |
| 10 | Messages drive | `D1:` | `MESSAGE.DIL`, `MESSAGE.IIL`, `MESSAGE.MIL` bases |
| 11 | Text screens drive | `D1:` | Paired `.TXT` and `.ATA` versions of `WELC`, `BULL`, `FUNC`, `HELP`, `MESGM`, `FILEM`, `NEWU` |
| 12 | Downloads drive | `D1:` | Controlled `NAME.CTL` files |
| 13 | R: driver | NONE | NONE: use an already installed emulator R:. RVRFULL: R-Verter with DTR/carrier wiring. RVRTWOW: RX/TX-only R-Verter. NHAND: FujiNet N: TCP server. RS232 is the retained legacy 850 bootstrap. Cold-restart after changing this setting. |
| 14 | Start the BBS | ON | The start-up batch starts the BBS, with the date and time of the EOS clock |
| 15 | Start with X | OFF | Direct start fits because the BBS uses field-sized strings. Turn this on to switch the EOS cartridge off and give the message/file buffer 8 KB more room. |
| 16 | Clock source | MANUAL | MANUAL asks at every BBS start; EOS/JIFFY trusts the current volatile clock; APETIME asks an APE-family SIO host; R-TIME 8 uses a persistent hardware/emulated RTC. |
| 17 | RAM cache | OFF | Adds EOS's `O:` RAM disk, copies all five core modules, bundled doors and `.TXT`/`.ATA` screens there during startup, and runs the module chain from RAM. Use compatible PORTB/XE extended RAM; Altirra 1088K is the verified recommendation. Cold-restart after saving. Database and download files remain on their configured disk drives. |

A drive is written like `D1:` or `D2:`; a folder of the DOS can be given
too, ending with `>` or `\`, for example `D1:>BBS>`.

**D** restores defaults, **S** saves settings and startup, and **X** returns
to CONFIG's main menu. CONFIG itself does not initialize or erase the whole
board.

The BBS reads `BBS.CFG` when it starts. If the file is missing it uses
the defaults and says `NO D1:BBS.CFG, USING DEFAULTS`. Settings 9 and 10
must match the drives containing the files. Change and save drive settings
before using the other CONFIG managers on those drives.

### Message Bases

Each base uses an A–Z ID and a minimum access level from 1 through 9. Add
asks for its ID, name, description, level and sector allocation. Edit keeps
the data and messages. Clear deletes every message in the chosen base and
asks for its new allocation. Remove deletes the base's three files.

### File Areas

Copy a file to the configured downloads drive first, then choose **Add
Copied File**. CONFIG renames it into the controlled `NAME.CTL` convention
and updates `FILES.DAT`. Edit can change its name, category, type, access
level and description. Remove deletes both the controlled file and its
catalog entry.

### Doors

Main command **D** loads the door menu. `DOORS.DAT` contains one door per
line in this form:

```
B|1|Blackjack Casino|BJACK.COM
S|1|Lucky Slots|SLOTS.COM
```

The fields are the selection key, minimum access level, display name and
program path. A filename without a drive is loaded from the RAM disk when
caching is enabled, then from D1:. Use a full path such as `D2:GAME.COM`
for a door stored elsewhere. Blackjack supplies a complete game: 100 starting credits, bets from
1 through 100, hit/stand/double, blackjack paying 3:2, and a dealer that
stands on 17. Lucky Slots accepts bets from 1 through 10 and pays for
cherries, triples, bells, bars and sevens. Each game starts a visit with
100 credits and saves the caller's highest bankroll in `BJHI10.TXT` or
`SLOTHI10.TXT`; only the best ten records are retained. See
`docs/MODULES.md` for the complete door contract.

### User Editor

New and Edit manage the complete three-line user record: name, city,
four-character password and level. Approve sets level 1; Ban sets level 0;
Remove deletes the record. User 1 and the configured sysop cannot be banned
or removed and remain level 9.

## 5. Running the board

### Start-up with EOS

When CONFIG saves, it writes `D1:eossys.sys` and `D1:eosauto.bat`. exOS's
native filesystem is case-sensitive, so these OS-owned startup names stay
lowercase. The system file selects JIFFY for MANUAL, EOS/JIFFY and APETIME,
or RTIME8 for R-TIME 8; loads the selected R-Verter/NHAND `.sys` backend;
and adds `DEVICE RAMDISK` when setting 17 is on. A system-driver
change takes effect after a cold restart. The batch file EOS runs
when the computer starts (EOS does not run `AUTORUN.SYS`). Selecting
RVRFULL, for example, adds `DEVICE D1:RVRFULL` to the system file. The
startup batch holds:

```
; Written by Mutineer-eX CONFIG
SET PATH=CAR:;D1:
D1:remms.com
SET DAYTIME=1
D1:wfc.com
```

1. exOS loads `RVRFULL.sys`, `RVRTWOW.sys`, or `NHAND.sys` while processing
   `eossys.sys`. Native EOSFS is case-sensitive: exOS appends lowercase
   `.sys`, which is why the packaged extensions are lowercase.
2. The default MANUAL mode writes no clock snapshot, so the BBS asks for
   `mm/dd/yyyy` and `hh:mm:ss`. Other modes add `DATE /T` and `TIME /T`.
   APETIME first runs `D1:apetime.com`; if its SIO host does not answer,
   the BBS falls back to the manual questions. R-TIME 8 requires the device
   to be present when EOS cold-starts.
3. `D1:remms.com` installs the resident modem/session layer; `D1:wfc.com`
   starts the BBS module chain. With setting 15 on, the WFC line
   is prefixed with `X`.

With RAM cache on, the batch uses exOS's `cp` command to copy `wfc.com`,
`mainbbs.com`, `message.com`, `files.com`, `doors.com`, `bjack.com`,
`slots.com`, and the eight paired `.TXT`/`.ATA` screens to `O:`, sets the
command search path to `CAR:;O:;D1:`, and
starts `wfc.com`. EOS therefore starts the RAM copy when it is present and
falls back to D1: if the RAM disk could not be installed. Each module also
verifies that the complete five-program core set is present before using the
cache, so an incomplete copy falls back to D1: for later module loading. The
configured data, messages and downloads drives are not changed. In Altirra,
select the 1088K memory configuration; this is verified to leave enough
EOS-compatible banks for the complete cache. Some smaller expansion layouts
are not recognized by EOS's RAM-disk driver.

For Altirra, add an **R-Time 8** device to the active machine's device tree,
select R-TIME 8 in CONFIG item 16, save, and perform a cold reset. Merely
selecting the CONFIG option cannot create the emulated hardware; without the
device EOS reports that R-Time 8 is not present. APETime is for an APE,
AspeQt or RespeQt SIO host and is not provided by Altirra's normal virtual
disk drives.

For an automatic source, the BBS reads the two files, deletes them and
starts without asking. With settings 13 and 14 both off, CONFIG deletes the batch.
CONFIG owns `eosauto.bat`: put your own start-up commands in
`autoexec.bat` instead, which exOS runs only when there is no
`eosauto.bat`, or add them to CONFIG.

### Starting by hand

After the selected device has loaded during a cold start, type these commands
at the EOS prompt:

```
D1:remms.com
D1:wfc.com
```

Do not start two R: backends in one boot. If the R: handler is already
resident, use CONFIG item 13 NONE. The direct BBS start works with the EOS
cartridge mapped. Prefix the second command with `X ` only when you want the
larger message/file buffer.

If item 13 is NONE and no preloaded R: exists, WFC deliberately starts in
`OFFLINE / LOCAL LOGON ONLY` mode. SELECT still starts a keyboard session;
no physical REMMS serial entry point is called.

When the date files are missing, the BBS asks:

1. `Enter date mm/dd/yyyy` — for example `11/17/2026`. Only years
   `2000`–`2099` are accepted; a two-digit year read from EOS is displayed
   with the `20` prefix.
2. `Enter time hh:mm:ss` — 24 hour time, for example `20:15:00`.
3. `WORK DISK IN` — press RETURN when the disk with the data files is in
   the drive.

With a converted backend, put its `DEVICE D1:name` line in `eossys.sys` and
cold-restart before starting REMMS. With a preloaded emulator handler, set
CONFIG item 13 to NONE and start REMMS followed by WFC.

The clock then runs from the computer's frame counter (50 or 60 per
second, PAL or NTSC is detected), and the date changes at midnight.

### The waiting screen

The BBS hangs up the modem (drops DTR), resets it with `ATZ`, sends the
init string and shows:

```
nn MESSAGES, LAST MESSAGE # nn
TIME: hh:mm:ss   DATE: mm/dd/yyyy
SELECT = LOCAL LOGON   OPTION = QUIT
```

| Key | Action |
|-----|--------|
| SELECT | Log on at the keyboard (local mode), to use the board yourself or to register the sysop account. The modem is taken off hook (`AT H1 M0`) so callers get a busy line |
| OPTION | Takes the modem off hook, saves the counters and quits to DOS |
| (a call) | When the modem sends anything (RING), the BBS answers with `ATA` and starts the logon when the modem stops talking. If no connection comes in 60 seconds, it goes back to waiting |

If the R: device can't be opened, the screen says
`R: NOT READY, ONLY LOCAL LOGON WORKS`.

### During a call

Everything the caller types appears on your screen, and you can type to
the caller at any moment too: your keys go to the BBS as if the caller
typed them.

* **Hold SELECT** until the BBS next asks the caller for a line (the
  menu prompt, for example) to start the **chat mode**. Both of you type;
  CTRL-X (by either) ends it and the caller is back at the menu.
* When a caller uses **Y** (yell), the Atari beeps for a few seconds
  showing the caller's name: press SELECT to chat.
* In local mode, after reading a message the BBS asks `PRINT <Y/N>` to
  print it on the log printer.

The call ends when the caller uses G (good-bye), when the line is lost,
or after the idle time. The BBS then hangs up and waits for the next
call.

### The log

With the printer log on, P: gets a line for each event, as in the
original:

```
===== 11/17/26 ===== 20:15:00 =====
LOGGED ON name FROM city ON date AT time.  CALLER # n SECTOR # n
NEW USER name FROM city
MSG #:0012.  SUBJ:...  FROM:...  TO:...     (and the lines)
CHANGED MSG #:0012 BY name
KILLED MSG 0012 BY name
DL D1:FILE.TT1 20:31:02     (XDL, UP, XUP for the other transfers)
BAD PASSWORD FOR name AT time
LINE LOST AT time
LOGGED-OFF AT time
Error- n FILE name
```

The comments a caller leaves with G go to the log too.

## 6. Users

A caller logs on with a name (3 to 40 characters) and a password of
exactly **4 characters** (letters are not case sensitive). A name not in
`USERS.DAT` can register: the caller gives the city, checks the data and
chooses the password twice. Three wrong passwords end the call.

`USERS.DAT` is a preallocated 100-sector file with three lines per user:
name, city, and `PASSWORD,LEVEL`; `*` marks the end. User 1 is always level
9 and later callers start at level 1. Use CONFIG's User Editor to list,
create, rename, edit, approve, ban or remove accounts. The editor maintains
the marker and allocation. Main command Z remains available to level-9
operators for quick access-level changes.

### Access levels

| Level | Role |
|-------|------|
| 9 | SysOp: unrestricted, including Z user-level maintenance |
| 8 | CoSysOp: moderates all messages and manages files, but cannot edit users |
| 2–7 | Regular approved levels; visible bases/files depend on their minimum-level digit |
| 1 | New, not yet approved; can use resources explicitly marked level 1 |
| 0 | Banned/disabled; the account remains reserved but cannot log in |

## 7. Messages

There can be up to 26 message bases, A through Z. From the main menu, M
opens the message area; J there lists and selects the bases allowed by
the caller's level. Every base consists of `MESSAGE.DIL`,
`MESSAGE.IIL` and `MESSAGE.MIL`, where I is its ID and L is its minimum
level—for example `MESSAGE.DA1`, `MESSAGE.IA1`, `MESSAGE.MA1`.

Users can read and post in every base visible to them. A message can be
modified or killed by its author; levels 8 and 9 can moderate any message.
A message has a subject, recipient (or ALL), and up to 16 lines.

Messages are numbered from 0001 up; a modified message keeps its number.

Each `MESSAGE.DIL` is filled from the start and does not grow: the BBS says
`MESSAGE FILE FULL, NOT SAVED` when there is no room. A killed or
modified message leaves its old text in the file (only the index
forgets it). The original 1983 `MESSAGE.COM` compacting utility is not
ported; the current `MESSAGE.COM` is the live message-base module. Until a
new compactor is added, when the file is full, run CONFIG and choose I again
(this erases all messages and the callers list).

Each index (`MESSAGE.IIL`) is loaded in memory when used, 40 bytes per
message; the free memory limits it to a few hundred messages.

## 8. Text screens and downloads

Every text screen has two independent files in `text/`. The `.txt` file
is plain ASCII for ASCII callers. The `.ata` file is native binary
ATASCII for Atari terminals and local mode. Edit `.txt` with any text
editor. To edit `.ata`, convert it to the readable brace notation, edit
that temporary file, and convert it back:

```
python tools/atascii.py totext text/WELC.ata welc-ata-edit.txt
python tools/atascii.py toatari welc-ata-edit.txt text/WELC.ata
```

Rebuild the disk afterward. Keep lines to 38 characters for 40-column
callers. CONFIG setting 11 must point to both versions.

In the temporary editable ATASCII representation, special characters
are written in braces:

| Write | For |
|-------|-----|
| `{7D}` | Any ATASCII code in hexadecimal: `{7D}` clear screen, `{FD}` buzzer, `{1C}`..`{1F}` cursor moves, `{12}` horizontal line... |
| `{12*38}` | A code repeated: 38 horizontal lines |
| `{i}TEXT{/i}` | Inverse video text |
| `{7B}`, `{7D}` | The characters `{` and `}` themselves |
| `{NOEOL}` | At the very end: the file has no final RETURN |

ATASCII graphics belong in `.ata`; use an ASCII alternative in `.txt`.
The BBS selects the correct version after detecting the terminal.

Downloads use `NAME.CTL`, with a one-to-seven character name. C is category
(`G` game, `A` application, `T` tool, `R` archiver, `U` unknown), T is type
(`C` COM, `E` EXE, `X` XEX, `B` BAS, `T` text, `U` unknown), and L is the
minimum level. Thus `PACMAN.GC1` is a game/COM visible at level 1. Main
command F opens the file area; its F and D commands hide or reject files
above the caller's level. The file list starts with the Text Files view;
file-area command J selects Text Files, Games, Applications, Tools,
Archivers, or Unknown. Each table row shows the full controlled filename,
its category, and a description wrapped for 40 columns.

Descriptions are stored on the downloads drive in `FILES.DAT`, one record
per line in this form:

```
PACMAN.GC1|Pacman is a classic Atari 8-bit game.
```

Keep descriptions to 70 characters. Files without a record display
`No description available.` Levels 8 and 9 use U to upload and V to delete
controlled files; those commands add or remove the corresponding catalog
record automatically.

## 9. Troubleshooting

| Symptom | What to do |
|---------|------------|
| `CAN'T READ D1:SYSTEM.MET, ERROR 170` at the start | Run CONFIG and choose I, or check setting 9 (users/callers drive) |
| `NO D1:BBS.CFG, USING DEFAULTS` | Run CONFIG and save |
| WFC says `OFFLINE / LOCAL LOGON ONLY` | No R: handler is installed. SELECT starts a local keyboard session; for remote calls select RVRFULL, RVRTWOW or NHAND and cold-restart, or preload an emulator R: and select NONE. |
| exOS reports `File D1:NAME.sys 170` | Native EOSFS names are case-sensitive and DEVICE appends lowercase `.sys`. Use the packaged `RVRFULL.sys`, `RVRTWOW.sys` or `NHAND.sys` name exactly |
| The modem answers but WFC remains at `RING 1` | Use the current `REMMS.COM` and `WFC.COM`. REMMS requires modem result codes; keep `Q0 V1` in CONFIG item 6 so the modem reports `CONNECT` in text form |
| `ERROR- 2` immediately when loading CONFIG | The disk has an older CONFIG.COM that used a 16 KB rewrite buffer; rebuild with `python tools/build.py` and copy the new program |
| `ERROR- 2` immediately when loading a BBS module | A custom build omitted `src/fixed_strings.asm` or was linked below REMMS; rebuild with `python tools/build.py` and copy all five core modules |
| `ERROR 162 CREATING D1:CALLERS.DAT` during INIT | The disk is full, usually because an older INIT was run again without releasing the existing database chains. Use the current `INIT.COM`; it explicitly deletes `CALLERS.DAT`, `USERS.DAT` and `SYSTEM.MET` before recreating them. |
| `ls -la` shows no files and `INIT` gives error 170 | Rebuild the disk with the current `tools/build.py`, then run `python tools/sdfs.py check disk/mutinrex-eos-v<VERSION>.atr`; Mutineer-eX requires EOSFS v2 revision `$47` |
| `ls -la` gives a disk error | The work image is damaged. Rebuild it, or use `python tools/sdfs.py check` to identify directory, extent-map or bitmap corruption |
| `CAN'T OPEN R:` during a call | The R: device stopped answering; the call ends |
| The caller is dropped at once | Turn Carrier watch off in CONFIG |
| `SYSTEM ERROR --- TRY AGAIN.` | A required `.TXT` or `.ATA` screen is missing or a disk error; the log shows the error and filename |
| `PRINTER LOG OFF, ERROR 138` | No printer: the log is off until the next start. Set Printer log OFF in CONFIG to stop trying |
| `ERROR- 19` when loading the BBS | DOS or the R: handler uses memory where the program loads; type `MEM` to see MEMLO, then rebuild with a higher start address (`-S:` option, see MODDING.md) |
| Very few messages fit, `MESSAGE INDEX FULL` early | The BBS runs with the EOS cartridge on: turn setting 15 (Start with X) on |
| The BBS asks the date at every start | MANUAL is selected, or the automatic source failed. For APETIME, check the APE/AspeQt/RespeQt SIO connection; for R-TIME 8, add the RTC to the emulator/hardware and cold restart |
| The date is old after the machine was offline | Do not use EOS/JIFFY, which is volatile. Select MANUAL, APETIME, or R-TIME 8 in CONFIG item 16 and save |
| `MESSAGE FILE FULL` / `MESSAGE INDEX FULL` | See [Messages](#7-messages) |
| The clock is wrong after a long disk operation | The clock counts frames; anything that blocks for more than 9 minutes loses time. Restart to set it again |
