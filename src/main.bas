' ====================================================================
' AMIS BBS - Atari Message and Information System
' ====================================================================
' exBASIC port of AMIS.BBS 04/17/83, revised by Larry Burdeno and
' Jim Steinbrecher, original version by Tom Giese.
'
' Needs the R: handler (850 interface or compatible) loaded before the
' program runs, and a Hayes compatible modem.  The work disk in drive 1
' holds CONFIG, message-base files, CALLERS.DAT, the text files
' WELC/BULL/FUNC/HELP/MESGM/FILEM/NEWU .TXT/.ATA screens and
' MESSAGE.DIL / MESSAGE.IIL / MESSAGE.MIL message bases.
'
' While waiting for a call:  SELECT = local logon at the keyboard,
'                            OPTION = save and quit to DOS.
' During a call the sysop can press SELECT to break into chat.
'
' Differences from the Atari BASIC version:
'  - The clock runs from the OS frame counter instead of the clock
'    interrupt that AUTORUN.SYS installed in page 4.
'  - The R: concurrent input buffer is an array, not page 6.
'  - Big strings (BUFFER$, MSG$) are byte arrays.
'  - Errors are checked with ERR() instead of TRAP.

' ---------- Settings (set with CONFIG.XEX, kept in D1:BBS.CFG) ----------
INCLUDE "settings.bas"

' ---------- I/O channels ----------
FileCh = 1
ModemCh = 2
KbdCh = 3
LogCh = 4

' ---------- Global state ----------
DIM LocalMode, AMode, LMode, XMode, Lost, Bye, LogOk
DIM ControlChar(2) BYTE, Il             ' bell, backspace, delete
DIM CallNo, CSect, CByte, MSect, MByte, Msgs, HMsg
DIM Hour, Minute, Second, Day, Month, Year, Jiffy, LastTick, Fps
DIM BufSize, BufLen, BFlag, NoteSect, NoteByte, St, MsgLines
DIM From, Upto, Dir, NoEcho, RawText, UserLevel, CfgStatus
DIM ActiveBase
DIM FileCategory
DIM Q1, Q2, Q3, Q4, Q5, Q6    ' scratch of the small functions that call no others

' Bind exBASIC strings to the original AMIS field sizes instead of
' allowing every assigned string to reserve 256 bytes.
Q1 = USR(@BIND_FIXED_STRINGS)
InitSettings()

L$ = ""            ' line typed by the caller (and the command line)
S$ = ""            ' work strings
T$ = ""
Spec$ = ""         ' rest of a message number list, like "1-5,9"
Name$ = ""         ' caller name and city
Addr$ = ""
Prompt$ = ""
NowDate$ = ""      ' MM/DD/YYYY and HH:MM:SS of the clock
NowTime$ = ""
MsgNo$ = ""        ' fields of a message (and of a caller record)
Subj$ = ""
Marker$ = ""       ' + and * markers in CALLERS.DAT
MDate$ = ""
MTime$ = ""
From$ = ""
ToWho$ = ""
FileName$ = ""
BaseName$ = ""     ' active message base name and description
BaseDesc$ = ""
CtrlMsg$ = "CTRL<S>=PAUSE, ANY KEY=RESUME, CTRL<X>=QUIT."
CfgStatus = LoadSettings()
MIF$ = ""                     ' active base index path
MDF$ = ""                     ' active base data path
CDF$ = DataDrive$             ' callers, a circular file
CDF$ =+ "CALLERS.DAT"
UserFile$ = DataDrive$        ' user names, cities and passwords
UserFile$ =+ "USERS.DAT"
SystemFile$ = DataDrive$      ' caller count and CALLERS.DAT position
SystemFile$ =+ "SYSTEM.MET"
UserPass$ = ""
ActiveBase = -2

' ---------- Arrays ----------
DIM RBuf(255) BYTE            ' R: concurrent mode input buffer
DIM MsgText(1935) BYTE        ' 16 lines of a message, 121 bytes each
DIM Blk(131) BYTE             ' one XMODEM block
DIM BaseLevel(25) BYTE        ' minimum level of bases A through Z
DIM BasePresent(25) BYTE

' PLA, PLA, TAX, JMP CIOV: calls CIO for the IOCB given to USR
DATA CioCall() BYTE = $68, $68, $AA, $4C, $56, $E4
DATA MonthDays() BYTE = 0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31

' The file buffer (BUFFER$ of the original) takes the free memory after
' the compact strings and fixed arrays, leaving room for temporaries.
IF FRE() > 32000
  BufSize = 30000
ELSE
  BufSize = FRE() - 2300
ENDIF
DIM Buf(BufSize) BYTE

' ---------- Main program ----------
Init()
DO
  Answered = WaitRing()
  IF Answered = 0 THEN EXIT
  IF Answered <> 3 THEN Session()
LOOP
SaveSystemMeta()
POKE 752, 0
END

INCLUDE "clock.bas"
INCLUDE "modem.bas"
INCLUDE "files.bas"
INCLUDE "messages.bas"
INCLUDE "callers.bas"
INCLUDE "transfer.bas"
INCLUDE "users.bas"
INCLUDE "session.bas"
