' Shared run-time declarations for the Mutineer-eX modules. Every module uses
' the same field layout, while REMMS owns the serial handler and session state.

INCLUDE "settings.bas"

FileCh = 1
ModemCh = 2
KbdCh = 3
LogCh = 4

DIM LocalMode, AMode, LMode, XMode, Lost, Bye, LogOk
DIM ControlChar(2) BYTE, Il
DIM MSect, MByte, Msgs, HMsg
DIM BufSize, BufLen, BFlag, NoteSect, NoteByte, St, MsgLines
DIM From, Upto, Dir, NoEcho, RawText, UserLevel, CfgStatus
DIM ActiveBase, FileCategory, RemmsApi, RemmsPublic, RemmsSession, SerialReady
DIM CurrentApp, NextApp, UserNumber
DIM Q1, Q2, Q3, Q4, Q5, Q6

Q1 = USR(@BIND_FIXED_STRINGS)
InitSettings()

L$ = ""
S$ = ""
T$ = ""
Spec$ = ""
Name$ = ""
Addr$ = ""
Prompt$ = ""
NowDate$ = ""
NowTime$ = ""
MsgNo$ = ""
Subj$ = ""
Marker$ = ""
MDate$ = ""
MTime$ = ""
From$ = ""
ToWho$ = ""
FileName$ = ""
BaseName$ = ""
BaseDesc$ = ""
CtrlMsg$ = "CTRL<S>=PAUSE, ANY KEY=RESUME, CTRL<X>=QUIT."
MIF$ = ""
MDF$ = ""
CDF$ = ""
UserFile$ = ""
SystemFile$ = ""
UserPass$ = ""

CfgStatus = LoadSettings()
CDF$ = DataDrive$ : CDF$ =+ "CALLERS.DAT"
UserFile$ = DataDrive$ : UserFile$ =+ "USERS.DAT"
SystemFile$ = DataDrive$ : SystemFile$ =+ "SYSTEM.MET"
ActiveBase = -2

' CONFIG formats EOS's O: drive and copies only the
' sources selected in D1:RAMCACHE.CFG.  ramcache.bas resolves every access
' against that manifest; selection is authoritative and never a probe/fallback.
FileName$ = ""

' Allocate only the large work areas used by this independently loaded
' module.  EOS leaves MEMTOP at $9C1F while its cartridge is mapped; making
' every module reserve both buffers caused exBASIC ERROR- 2 at startup.
Q1 = 0
IF ModuleImage = 4 THEN Q1 = 1935
DIM MsgText(Q1) BYTE
Q1 = 0
IF ModuleImage = 5 THEN Q1 = 131
DIM Blk(Q1) BYTE
DIM BaseLevel(25) BYTE
DIM BasePresent(25) BYTE

DATA MonthDays() BYTE = 0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31

IF FRE() > 32000
  BufSize = 30000
ELIF FRE() > 2556
  ' Manifest lookup, module progress text, and the resident EOS O: bridge all
  ' need transient string/compiler headroom during every module transition.
  BufSize = FRE() - 2300
ELSE
  ' A 256-byte buffer is enough for the WFC screens and caller records and
  ' avoids unsigned wraparound when the EOS cartridge leaves little memory.
  BufSize = 256
ENDIF
DIM Buf(BufSize) BYTE

INCLUDE "ramcache.bas"
