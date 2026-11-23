# Mutineer-eX for Callers

What a caller sees when calling a Mutineer-eX board, and the commands.

## Logging on

1. **HIT <RETURN>** — the board finds out your terminal: an Atari
   terminal (ATASCII) sends RETURN as 155, any other terminal (ASCII)
   sends 13. ASCII callers are asked **Do you require Line Feeds**: answer
   Y if all the text appears on one line.
2. The **welcome screen**.
3. **Enter your Name** — at least 3 characters.
   * A registered user then gives the **Password** (4 characters, shown
     as `*`). Three wrong passwords end the call.
   * A new name can **register**: give your city, check the data, choose a
      4 character password and type it again. After the board's first,
      level-9 sysop account, new accounts begin at access level 1; the sysop
      can approve a higher level.
4. Your **caller number** and the **bulletin**. CTRL-X during the bulletin
   switches to the expert mode (short prompts).
5. The **command prompt**:

```
A,B,C,D,F,G,H,L,M,T,W,X,Y,Z, or ? >
```

Type **M** for the message-area submenu or **F** for the file-area
submenu. In either submenu, **X** returns to the main prompt and **?**
repeats that submenu. Some message commands take their argument on the
same line, after one character: `R 5-9`, `K 12`.

## Keys

| Key | Action |
|-----|--------|
| CTRL-S | Pauses the text; any key goes on |
| CTRL-X | Stops the text being sent |
| Backspace (or DELETE in ASCII mode) | Deletes the last character typed |
| CTRL-X (ASCII) / SHIFT-DELETE (ATASCII) | Deletes the line typed |
| RETURN on an empty line | Leaves the current command |

## Main commands

| Cmd | Name | What it does |
|-----|------|--------------|
| A | ASCII/ATASCII | Switches the character set. The board asks you to hit RETURN: an Atari terminal answers in ATASCII and the board switches to ATASCII |
| B | Bulletin | Shows the bulletin again |
| C | Callers | Lists the callers from a date (MM/DD/YYYY, years 2000–2099) |
| D | Doors | Lists doors available at your access level and launches one |
| F | File areas | Opens the file-area submenu |
| G | Good-bye | Leave comments for the sysop if you want, and hang up |
| H | Help | Explains the commands |
| L | Line feeds | Turns the extra line feeds on or off |
| M | Message areas | Opens the message-area submenu |
| T | Time | The date and time of the board |
| W | Welcome | Shows the welcome screen again |
| X | Expert | Short prompt `OK >` instead of the command list |
| Y | Yell | Calls the sysop for a chat |
| Z | User level | Level 9: changes an account's access level; level 0 disables the account |
| ? | Commands | The list of commands |

## Message-area commands

| Cmd | Name | What it does |
|-----|------|--------------|
| E | Enter | Writes a new message: subject, recipient (RETURN = ALL), then the lines, two RETURNs to end, then **A**dd, **E**dit a line, **L**ist, **Q**uit (drop it) or **S**ave |
| J | Jump base | Lists accessible message bases and selects one |
| K | Kill | Deletes one of **your** messages (levels 8 and 9 can moderate any) |
| M | Modify | Changes the subject and lines of one of **your** messages; it keeps its number |
| Q | Quick scan | Lists the numbers and subjects of the messages |
| R | Retrieve | Reads messages |
| S | Summary | Shows the headers of the messages (date, author, recipient, subject) |
| X | Main menu | Returns to the main command prompt |
| ? | Commands | Repeats the message-area menu |

## File-area commands

| Cmd | Name | What it does |
|-----|------|--------------|
| D | Download | Sends an accessible controlled file: give its full `NAME.CTL`, then Y for XMODEM or N to list it as text |
| F | Files | Lists accessible files in the current category with wrapped descriptions; Text Files is selected when the file area opens |
| I | Info | Compatibility alias for F |
| J | Category | Selects Text Files, Games, Applications, Tools, Archivers, or Unknown, then lists that category |
| U | Upload | Level 8/9: uploads a new controlled `NAME.CTL` file |
| V | Delete file | Level 8/9: deletes a controlled file |
| X | Main menu | Returns to the main command prompt |
| ? | Commands | Repeats the file-area menu |

## Door commands

The door list is generated from the doors available at your access level.
Press the letter shown beside a door to launch it, **?** to show the list
again, or **X** to return to the main command prompt.

## Message numbers

Message commands use the base selected with J. A base is visible only when
its minimum level is no higher than the caller's access level.

Q, R and S ask `Msg# From-To`. You can give:

| Input | Messages |
|-------|----------|
| `5` | number 5 |
| `1-10` | 1 to 10, up |
| `10-1` | 10 to 1, down |
| `1,7,20-25` | several, separated by any character |

CTRL-X stops the list and asks again; RETURN goes back to the prompt.

## Transfers

XMODEM is the original checksum XMODEM with 128 byte blocks. The board
pads the last block with bytes whose value is the number of bytes used
in it and removes that padding on upload, so files keep their exact
size between Mutineer-eX boards and Atari terminal programs of the time that
use the same convention (AMODEM). Download in ATASCII mode for binary
files.
