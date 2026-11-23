# Modding Mutineer-eX

How the program is built, how it is organized, the limits of exBASIC
that shape the code, and recipes for the usual changes.

Read the exBASIC manual too (in the Studio installation,
`tools/exbasic/manual`, start with `README.md`): exBASIC is not Atari
BASIC. `C-differences.md` is the most useful chapter for this program.

## 1. Building

| Command | Result |
|---------|--------|
| `python tools/build.py` | REMMS, all BBS programs, and versioned EOSFS and SDFS 2.1 work images |
| `python tools/build.py --no-disk` | The resident and executable programs only |
| `python tools/exos_remms_test.py` | Hidden Altirra/debugger acceptance for RVRFULL, RVRTWOW and NHAND through the real exOS DEVICE loader |
| `python tools/exos_bbs_test.py` | Persistent cold-boot WFC acceptance for NONE, RVRFULL, RVRTWOW and NHAND |

The WFC and CONFIG builds check their heap against the memory left while
`EOS.car` is mapped. A build that would fail at startup with `ERROR- 2` is
rejected. The file and user editors stream rewrites through
`FILES.TMP` and `USERS.TMP`; do not replace that with a whole-file array,
because the cartridge leaves too little main RAM for it.

The compiler is called as:

```
exbasic -t:atari -I:src -I:lib -S:16384 -no-native -g -o build/WFC.XEX src/wfc.bas src/fixed_strings.asm
```

`build.py` finds the compiler in the default Studio installation folder and
uses `tools/mads.exe` for REMMS. Set `EXBASIC` or `MADS` to use other copies.
The 16 MB ATR is built from scratch as native EOSFS v2 revision `$47`. Its
boot sectors, 63-entry extent-map header, allocation hint, optimizer and skew
fields match an image made by exOS 0.4's `FORMAT /QQ`. `build.py` checks those
formatter invariants and the resulting size; `python tools/sdfs.py check
disk/mutinrex-eos-v<VERSION>.atr` checks its directory, extent maps, bitmap and
free-sector count.

The REMMS acceptance test defaults to the full source tree at
`D:\ATARI\atari-mutineer` (override with `MUTINEER_ROOT`) and uses only
`D:\ALTIRRA\Altirra64.exe`. It verifies the physical R: handler, REMMS E:/R:
wrappers, public version 1.10, session contract 9 and `$3CFF` MEMLO.
The BBS acceptance additionally verifies `BBS.CFG`, the WFC dashboard,
HATABS, REMMS installation state, and `BASIC_TOP <= MEMTOP`. The REMMS jump
table uses the Atari BASIC USR ABI; BBS code must call it through
`REMMS_CALL0` or `REMMS_CALL1` in `src/fixed_strings.asm`, never directly.

Add `-g` to get a label file (`.lbl`). `EXB_FREE` in it is where the free
memory starts; the program must end well below `$BC1F`.

### Start address

REMMS 1.10 occupies `$1E00-$3CFE`; all live BBS modules load at `$4000`.
CONFIG and INIT stay at `$2000` for heap space and
must not be run over a live REMMS installation without a cold restart before
the next BBS run.

## 2. Source layout

```
src/wfc.bas        wait for call/local logon/quit plus login/register
src/login_flow.bas terminal negotiation and login/register flow
src/mainbbs.bas    main BBS command loop
src/message_module.bas  message bases
src/files_module.bas    file bases and transfers
src/doors_module.bas    access-filtered door catalog and launcher
src/door_loop.bas       DOORS.DAT parsing, listing and launch flow
src/door_blackjack.bas  Blackjack game door with session bankroll and deck
src/door_slots.bas      three-reel Lucky Slots game door
src/door_scores.bas     shared persistent top-ten score routines
src/module_*.bas   shared declarations, COMMON state and attachment
src/remms.bas      REMMS discovery, API and session handoff
src/clock.bas      the clock and calendar
src/modem.bas      R: device, caller input/output, text sending, log check
src/files.bas      reading files into Buf, CONFIG, the F command
src/messages.bas   message index, reading, writing, editor, K and M
src/callers.bas    CALLERS.DAT and the C command
src/transfer.bas   D and U, text and XMODEM
src/users.bas      accounts: login, registration, passwords
src/session.bas    start up, waiting for calls, logon, command menu, chat
src/config.bas     CONFIG.COM main administration menu
src/config_*.bas   general, message-base, file-area and user managers
src/init.bas       INIT.COM one-time default board creation
lib/settings.bas   the settings and BBS.CFG, shared by both programs
```

`main.bas` includes the others at its end. The order matters for
globals (see [Variables](#variables)).

### Flow

```
main:  Init()                      date/time, SYSTEM.MET, K:, P:
       DO
         WaitRing()                hang up, ATZ, wait for a ring/SELECT/OPTION
         Session()                 one call
           Logon()                 terminal type, WELC, UserLogin(), LogCaller(), BULL
           DO: prompt, GLine(), DoCommand(letter) LOOP until Bye or Lost
       LOOP
       SaveSystemMeta()
```

Main commands are dispatched by `DoMainCommand`; the message, file and door
modules dispatch their own area commands. When a command returns, the caller is
back at the same menu. The 1983 program left
commands with `GOTO MAIN`; here they just `RETURN`.

### Global state

| Variable | Meaning |
|----------|---------|
| `LocalMode` | 1 when the sysop is logged on at the keyboard; the "modem" channel is then E: |
| `Lost` | Set when the line is lost (error 139), idle too long, or R: fails. Every input function returns at once (GetChr returns 24, CTRL-X) and the session ends |
| `Bye` | Set by G; ends the session |
| `AMode`, `LMode` | R: translation (32 = none, ATASCII; 0 = ASCII) and line feeds (64) |
| `XMode` | Expert mode |
| `Bel`, `Bs`, `Del` | The bell, backspace and delete line codes of the caller's terminal |
| `Il` | Maximum length of the next `GLine` |
| `L$` | The line the caller typed (from `GLine`); also the command line |
| `Name$`, `Addr$`, `UserLevel` | The logged on user and access level 1–9 |
| `ActiveBase`, `BaseLevel()` | Current message base and the discovered minimum levels for A–Z |
| `Buf()`, `BufLen`, `BufSize` | The big byte buffer: text files, the message index, transfers |
| `MsgText()`, `MsgLines` | The lines of the message being read or written |
| `FileName$` | File for `ReadFile`, `ShowTextFile` and the transfers |
| `S$`, `T$` | Work strings |

### I/O channels

| Channel | Use |
|---------|-----|
| #1 `FileCh` | Disk files |
| #2 `ModemCh` | R: (or E: in local mode) |
| #3 `KbdCh` | K:, the sysop keyboard |
| #4 `LogCh` | P:, the log printer, open all the time |

### The modem rules

* **Close the modem before any disk or printer access** with
  `CloseModem()`, and open it again with `OpenModem()` before talking to
  the caller. The R: concurrent mode and SIO disk access can't run at the
  same time. `ReadFile()` does it by itself.
* `OpenModem()` sets the translation and line feeds from `AMode` and
  `LMode`: call it again after changing them.
* Read the caller with `GetChr()` (one character) or `GLine()` (a line in
  `L$`), never with `GET #ModemCh` directly: they handle the local
  keyboard, the lost line and the idle time.
* Send long text with `SendBuf()` (Buf), `SendRaw()` or `SendLine()`:
  they send 8 characters at a time and let the caller pause (CTRL-S) or
  stop (CTRL-X). Short lines can use `PRINT #ModemCh`.
* After a loop that waits for the caller, test `Lost`.
* `PRINT #ModemCh,` (with the comma) sends only an end of line.

## 3. exBASIC limits that shape the code

### Strings are at most 255 characters

The 1983 program kept whole files in `BUFFER$` and the message being
written in `MSG$(2100)`. Here they are byte arrays:

* `Buf` is a `BYTE` array sized at start from the free memory. Use
  `BGET`/`BPUT` with `ADR(Buf)`, `MOVE`, `MSET` and `PEEK`.
* `MsgText` keeps each line as an exBASIC string: a length byte and 120
  characters, 121 bytes per line. `$(ADR(MsgText) + (K - 1) * 121)` *is*
  line K as a string, and `StoreLine(K)` copies `S$` into it with `MOVE`.

### Compact strings

An ordinary exBASIC string variable takes 256 bytes the first time it is assigned, and so
does every *hidden string*: each `+` expression, `LEFT$`, `MID$`,
`RIGHT$`, `UCASE$`... in each function. String parameters and `LOCAL`
strings are separate variables too.

So the BBS code:

* builds strings with `=+` (no hidden string) and slices `S$[start, len]`
  (a temporary buffer), never with `+` or `LEFT$`;
* passes data to functions in globals (`FileName$`, `S$`, `T$`) instead
  of string parameters (`SendLine(Text$)` is the one exception);
* prints with `;` between items instead of joining them.

`fixed_strings.asm` points the BBS globals at buffers sized like the
original AMIS fields: 120 characters for a command/message line, 40 for a
name, 33 for a subject, 10 for an `MM/DD/YYYY` date, 8 for a time, and so on. Disk input is
read through a full-size scratch string and clipped before it enters a
compact field. Keep each buffer size and every assignment limit in sync.

`main.bas` allocates `Buf` after the compact strings and fixed arrays and
leaves 1500 bytes for function-local/compiler temporary strings. A normal
EOS launch fits with the cartridge mapped. `X D1:wfc.com` remains an
optional way to add 8 KB to `Buf` for a larger message index or file
chunk. If a new local or hidden string causes `ERROR- 2`, increase the
reserve (and accept a smaller `Buf`).

### The variable table holds 256 variables

All integer and string variables, globals and the parameters and `LOCAL`s
of every function, share a table of 512 bytes (2 bytes each, 6 for a
floating point variable). The compiler stops with `too many variables`
when it is full.

The BBS is effectively at that ceiling: about 510 of the 512 bytes are
used, leaving one ordinary 2-byte slot. Before adding a parameter or
`LOCAL`, reuse an existing scratch/global value when its lifetime cannot
overlap, or convert a leaf function to `Q1`–`Q6`. The caller-list batching,
for example, reuses `Buf`, `Dir`, `From` and `Upto` instead of allocating a
second record table and counters.

To save room, the small functions that call no other function
(`UpdateClock`, `NextDay`, `RecNum`, `ParseRange`, `SameName`,
`SetInverse`, `StartConcurrent`, `BufAdd`, `ReadChunk`, `PadBlock`,
`LogCheck`) use the shared globals `Q1` to `Q6` instead of locals.

**Rule:** only a function that calls nothing (except another Q function
using other Q variables, like `UpdateClock` → `NextDay`, which uses `Q4`)
may use `Q1`–`Q6`, and no function may keep a value in them across a
call. When the table is full again, convert more leaf functions the same
way, or reuse existing globals.

### No GOTO, GOSUB, TRAP

* Each `GOSUB` target of the original is a `FUNC`; `GOTO` back is a
  `DO`/`LOOP`, `GOTO MAIN` is `RETURN`.
* There is no `TRAP`: check `ERR()` right after the operation and keep it
  in a variable (`St = ERR()`), because the next I/O changes it.
* A failed `OPEN` keeps the channel reserved: `CLOSE` before every `OPEN`.

### Integers are 16 bits

Variables without `%` are integers from -32768 to 32767. Sector numbers
from NOTE above 32767 are negative: split them with `& $7FFF` as in
`SaveMessage`. `TIME` differences are valid for 9 minutes; the clock
relies on `UpdateClock()` being called from the waiting loops.

### Syntax details that bite

* `IF (A AND B) OR (C AND D)` with a parenthesis right after `IF` can be
  read as a function call: split the test or reorder it.
* `PRINT #ch` alone is an error; write `PRINT #ch,`.
* `INPUT #ch, A, B` reads one line per variable.

## 4. Recipes

### Add a command

1. Choose the main, message, or file menu and pick a free letter in that
   menu. Letters can be reused in different menus (M modifies a message
   inside the message area, but opens that area from the main menu).
2. Write the function in the right file, for example in `session.bas`:

   ```basic
   ' V: shows the version of the board
   FUNC ShowVersion()
     PRINT #ModemCh; "Mutineer-eX 1.0.0 - exBASIC BBS"
   ENDFUNC
   ```

3. Call it from `DoCommand`, `MessageMenu`, or `FileMenu` as appropriate
   (the letter's ATASCII code, V = 86):

   ```basic
     ELIF C = 86
       ShowVersion()
   ```

4. Add a main letter to `SetPrompt()`, or add an area letter to that
   submenu's printed choices. Describe it in both ASCII and ATASCII
   versions of `FUNC` and `HELP`.
5. Build and check the variable table and memory.

A command that reads arguments typed after its letter (like `R 5-9`)
finds the command line in `L$`; `L$[3]` is the text after the letter and
one separator.

### Add a text screen

Write the ASCII `text/NAME.txt` and native ATASCII `text/NAME.ata`, add
`"NAME"` to `SCREENS` in `tools/build.py`, and show it with:

```basic
FileName$ = TextDrive$ : FileName$ =+ "NAME"
ShowTextFile()
```

`ShowTextFile` appends `.TXT` or `.ATA` for the detected terminal. Use
`tools/atascii.py` to convert a binary `.ata` file to and from an editable
brace-notation file.

### Add a setting

1. In `lib/settings.bas`: add the variable to the `DIM`, its default to
   `DefaultSettings`, and a line to **both** `LoadSettings` and
   `SaveSettings`, at the end so the order of the other lines does not
   change. Change `CfgTag$` (for example `MUTINREX CFG 2`) if old files must
   not be read with the new layout: with a different tag, the program uses
   the defaults.
2. In `src/config.bas`: show it in `ShowMenu`, add a number to the menu
   check (`Choice <= 15`) and a branch in `EditSetting`. A setting that
   changes the start-up goes into `WriteStartup` too.
3. Use it in the BBS, and document it in the Sysop Guide.

### Change what users may do

The rights are decided in a few places:

| Where | Rule |
|-------|------|
| `CanChange()` in `messages.bas` | Who may K and M a message: level 8/9 or the author |
| `UserLogin()` in `users.bas` | Login, the three tries, the reserved sysop name |
| `Register()` in `users.bas` | Registration, the 4 character rule and initial level 1 |
| `ManageUsers()` in `users.bas` | Level-9 user-level changes |
| `Upload()` / `DeleteFile()` | Level-8/9 file moderation |
| `DoCommand()` in `session.bas` | Which commands exist |

The level is stored as `PASSWORD,LEVEL` on the third line of each
`USERS.DAT` record. `FindUser()` requires this complete form and a level
from 0 through 9; 0 is a disabled account. A `*` line follows the last
record in the 100-sector database.

### Change the message limits

16 lines of 120 characters are fixed by `MsgText(1935)` (16 × 121 bytes),
the checks in `AddLines` (16, 13 and 17) and `ShowMessage` (16), and
`Il = 120`. Lines longer than 120 would need a bigger slot size in
`StoreLine` and every `* 121`.

### Use the 1983 code as a reference

`listings/AMIS.BBS.lst` is the original program. The functions name the
line or routine they replace (`GLINE`, `OPM`, `CLM`, `RFILE`, `UPDT`,
line 9000...), so you can compare the behavior.

## 5. Testing

* Local mode (SELECT on the waiting screen) runs everything except the
  modem: logon, messages, files. XMODEM is disabled in local mode.
* With the Studio emulator profile, telnet to `localhost 9097` to call the
  board through the emulated modem.
* Keep copies of the versioned EOS and SDX ATRs with test data; `build.py` replaces them.
