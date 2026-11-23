# Mutineer-eX File Formats

All text files use the ATASCII end of line (155, `$9B`). "Line" below
means text followed by 155. Numbers are written as text, as `PRINT #`
writes them.

The drives are set with CONFIG: *data* = setting 9, *messages* =
setting 10, *text* = setting 11, *downloads* = setting 12.

## BBS.CFG (always D1:)

Written by CONFIG and read by the BBS and CONFIG
(`lib/settings.bas`). One value per line, in this order:

| Line | Value | Example |
|------|-------|---------|
| 1 | Mutineer-eX configuration signature | `MUTINREX CFG 1` |
| 2 | Sysop account name | `SYSOP` |
| 3 | Printer log, 1 or 0 | `1` |
| 4 | Carrier watch, 1 or 0 | `1` |
| 5 | Idle hang-up, minutes | `5` |
| 6 | XIO 36 baud code (8=300, 10=1200, 12=2400, 13=4800, 14=9600, 15=19200) | `15` |
| 7 | Modem init string | `ATE0 Q0 V1 S2=255 S4=24 S7=15` |
| 8 | Download chunk, bytes | `1024` |
| 9 | XMODEM buffer, blocks | `8` |
| 10 | Data drive | `D1:` |
| 11 | Messages drive | `D1:` |
| 12 | Text drive | `D1:` |
| 13 | Downloads drive | `D1:` |
| 14 | R: backend: 0 = existing/none, 1 = legacy RS232.COM, 2 = RVRFULL, 3 = RVRTWOW, 4 = NHAND/FujiNet | `0` |
| 15 | Start the BBS from `eosauto.bat`, 1 or 0 | `1` |
| 16 | Start it with X (cartridge off), 1 or 0 | `0` |
| 17 | Clock: 0 = manual, 1 = current EOS/JIFFY, 2 = APETime, 3 = R-Time 8 | `0` |
| 18 | RAM cache: 1 = load selected files from their explicit EOS/SDX RAM-disk targets, 0 = use configured disk drives | `0` |

## eosauto.bat (D1:)

The EOS start-up batch, written by CONFIG from its settings 13 to 17 (see the
Sysop Guide, *Start-up with EOS*).

## RAMCACHE.CFG (always D1:)

Written by RDCONF. The current first line is `MUTINREX RAMCACHE 2`; every
following line maps one exact disk source to its runtime RAM path:

```text
D1:mainbbs.com|O:mainbbs.com
D1:mainbbs.com|DO:mainbbs.com
```

RDCONF writes the first form on EOS and the second on SpartaDOS X, where
exBASIC reaches drive O through the D: CIO handler. Version-1 source-only
manifests remain readable and are upgraded on save. A listed file never
probes or falls back to its disk source. RDCONF accounts for file and
directory overhead before allowing the manifest and startup files to be saved.

## DOORS.DAT (data drive)

Door catalog read by `DOORS.COM`, one ATASCII line per door:

```
KEY|LEVEL|DISPLAY NAME|PATH
```

`KEY` is one character, `LEVEL` is the minimum caller access level 1–9,
and `PATH` is a full configured path or a filename resolved through the cache
manifest and then D1:. Example:
The bundled catalog contains `B|1|Blackjack Casino|bjack.com` and
`S|1|Lucky Slots|slots.com`.
Malformed records are ignored.

## BJHI10.TXT, SLOTHI10.TXT (data drive)

Blackjack and Lucky Slots each keep at most ten ATASCII text records,
sorted from the highest peak bankroll to the lowest:

```
250|SYSOP
175|ANOTHER CALLER
```

The score is the highest bankroll reached during that visit to the door,
not merely the amount held when the player quits. Game doors rewrite these
files through `.TMP` and `.BAK` files so the live leaderboard is not removed
until a complete replacement is ready. INIT deliberately preserves scores.

## BBSDATE.TXT, BBSTIME.TXT (D1:)

For automatic clock modes, written at start-up by `DATE /T` and `TIME /T`
in `eosauto.bat`, then read and deleted by the BBS. The BBS takes the first
three numbers of each line:
month, day, year (or year, month, day when the first number is above 31)
and hours, minutes, seconds (with AM/PM if present). The BBS keeps the low
two year digits from EOS and always writes/displays the year as `20YY`.

`APETIME.TXT` is the redirected status from `APETIME.COM`. APETime mode
accepts the EOS snapshot only when this file contains APETime's successful
timestamp; a missing SIO host therefore falls back to manual entry instead
of accepting a stale JIFFY clock.

## SYSTEM.MET (data drive)

Caller-log state, written by INIT and updated by the
BBS. It has three lines:

| Line | Variable | Meaning |
|------|----------|---------|
| 1 | `CSect` | NOTE sector of the end marker `*` in CALLERS.DAT |
| 2 | `CByte` | NOTE byte of that marker |
| 3 | `CallNo` | Number of calls so far |

The NOTE values are bookmarks given by the DOS: never compute them, only
store and give them back to POINT. They are only valid for the disk and
DOS on which they were made.

## USERS.DAT (data drive)

INIT preallocates 100 sectors. Records occupy the beginning of the file in
registration order, with three lines per user:

```
name        up to 40 characters, as typed when registering
city        up to 40 characters
password,level    4 uppercase characters, comma, access level 0 through 9
```

Names are compared without regard to case. The first record is user 1 and is
always treated as level 9; later users are appended at level 1. Every record
must contain the comma and a level from 0 through 9. Level 0 is banned or
disabled and cannot log in. The account named by the SysOp setting is always
treated as level 9. A line containing only `*` follows the last record; the
remaining preallocated bytes are unused. Older grow-as-needed files without
the marker remain readable and receive a marker when updated.

## CALLERS.DAT (data drive)

Made by INIT as 100 sectors of empty lines (124 zero bytes and an EOL,
which is one sector with DOS 2). The BBS writes in it with POINT in update
mode, so it never grows:

```
+           start of a caller
name
city
date        MM/DD/YYYY
time        HH:MM:SS
...         more callers
*           end marker, at CSect/CByte
```

A record that does not fit before the end of the file is written again at
the start (the file is circular). The C command starts reading after the
end marker, at the first `+`, which is the oldest caller still in the
file.

## MESSAGE.DIL message bases (messages drive)

Each base has ID `A` through `Z` and minimum access level `1` through `9`.
The three-character extension is `DIL`: `D` is the file role, `I` the base
ID and `L` the minimum level. For base A at level 1:

| File | Purpose |
|------|---------|
| `MESSAGE.DA1` | Message data |
| `MESSAGE.IA1` | Message index |
| `MESSAGE.MA1` | Metadata and counters |

A caller cannot list or select a base whose final digit is above their
access level.

### `MESSAGE.MIL`

Six ATASCII text lines:

1. base name;
2. description;
3. NOTE sector at the end of used data;
4. NOTE byte at the end of used data;
5. number of indexed messages;
6. highest message number assigned in this base.

### `MESSAGE.IIL`

The message index is 40 bytes per message, in message-number order, with
no separator or end-of-line bytes between records.

| Bytes | Contents |
|-------|----------|
| 0–3 | Message number, 4 ASCII digits (`0012`) |
| 4–36 | Subject, 33 characters padded with spaces |
| 37 | High byte of the NOTE sector of the message in `MESSAGE.DIL` |
| 38 | Low byte of that sector |
| 39 | NOTE byte of the message |

A killed message is removed from the index; a modified message points to
its new copy.

### `MESSAGE.DIL`

Made by INIT or CONFIG's Message Bases manager as empty lines like CALLERS.DAT. Messages are written from
the start, each one at `MSect`/`MByte`, and that position moves to the
end of the new message:

```
number      0012
subject
date        MM/DD/YYYY
time        HH:MM:SS
from        author (the user name)
to          recipient or ALL
lines       number of lines, 1 to 16
line 1      up to 120 characters
...
```

The text of killed and modified messages stays in the file until it is
compacted.

## Text screens (text drive)

Each screen base name (`WELC`, `BULL`, `NEWU`, `FUNC`, `HELP`, `MESGM`,
`FILEM`) has two files. `NAME.TXT` is ASCII with CR line
endings; `NAME.ATA` is native ATASCII with `$9B` line endings and may use
ATASCII graphics or inverse characters. ASCII terminals receive `.TXT`;
ATASCII terminals and local mode receive `.ATA`. `MESGM` and `FILEM` are
the message-area and file-area menus.

## Controlled files (downloads drive)

Files use `NAME.CTL`: a name of one to seven letters/digits, followed by a
three-character control extension:

| Position | Values |
|----------|--------|
| C — category | `G` game, `A` application, `T` tool, `R` archiver, `U` unknown |
| T — type | `C` COM, `E` EXE, `X` XEX, `B` BAS, `T` text, `U` unknown |
| L — minimum level | `1` through `9` |

For example, `PACMAN.GC1` is a game, COM file, visible and downloadable by
levels 1 through 9. Files above the caller's level are absent from listings
and cannot be downloaded. Only levels 8 and 9 can upload or delete files.

`FILES.DAT` is an ATASCII line-oriented catalog on the downloads drive.
Each record connects a complete controlled filename to its description:

```
PACMAN.GC1|Pacman is a classic Atari 8-bit game.
```

Descriptions are limited to 70 characters. The BBS wraps them into the
19-character description column of the 40-column file table. A controlled
file without a catalog record is shown as `No description available.`
Level-8/9 uploads prompt for a description and update this file; deleting a
download removes its record.

The file area initially selects Text Files (files whose type byte is `T`).
The other views use the category byte: Games `G`, Applications `A`, Tools
`T`, Archivers `R`, and Unknown `U`. Thus a tool/text file can be found in
both the Text Files and Tools views.
