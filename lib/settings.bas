' ====================================================================
' BBS settings, shared by the BBS (main.bas) and CONFIG (config.bas)
' ====================================================================
' The settings are kept in D1:BBS.CFG, a text file with one value per
' line, in the order of SaveSettings.  CONFIG.COM writes it; the BBS
' reads it when it starts.

DIM SysopName$, ModemInit$, DataDrive$, MsgDrive$, TextDrive$, FileDrive$
DIM UsePrinter, CarrierWatch, IdleMinutes, BaudCode, ChunkSize, NumSect
DIM RDriver, AutoStart
DIM StartOption(2) BYTE                 ' 0 = UseX, 1 = ClockSource, 2 = RAM cache

' Kept in a function so the BBS can bind its strings to compact buffers
' before their first assignment.  CONFIG uses normal exBASIC strings.
FUNC InitSettings()
  CfgFile$ = "D1:BBS.CFG"
  CfgTag$ = "MUTINREX CFG 1"
ENDFUNC

' Sets the default value of every setting
FUNC DefaultSettings()
  SysopName$ = "SYSOP"                  ' user account of the sysop
  UsePrinter = 1                        ' log the activity on P:
  CarrierWatch = 1                      ' R: reports a lost carrier
  IdleMinutes = 5                       ' hang up after this long idle
  BaudCode = 15                         ' XIO 36 code, 15 = 19200 baud
  ModemInit$ = "ATE0 Q0 V1 S2=255 S4=24 S7=15"
  ChunkSize = 1024                      ' bytes read for a download
  NumSect = 8                           ' XMODEM blocks before a write
  DataDrive$ = "D1:"                    ' SYSTEM.MET, USERS.DAT, CALLERS.DAT
  MsgDrive$ = "D1:"                     ' MESSAGE.DIL/IIL/MIL bases
  TextDrive$ = "D1:"                    ' WELC, BULL, FUNC, HELP, NEWU...
  FileDrive$ = "D1:"                    ' NAME.CTL controlled files
  RDriver = 0                           ' choose existing R:, 850, R-Verter or FujiNet
  AutoStart = 1                         ' eosauto.bat starts the BBS
  StartOption(2) = 0                    ' copy live modules/screens to O:
  StartOption(0) = 0                    ' direct start; X is optional extra memory
  StartOption(1) = 0                    ' 0 manual, 1 JIFFY, 2 APETime, 3 R-Time 8
ENDFUNC

' Reads the settings from CfgFile$ on channel 1.  Returns 1, or the error
' (then the values not read keep their defaults)
FUNC LoadSettings()
  LOCAL Code
  LOCAL Value$
  DefaultSettings()
  CLOSE #1
  OPEN #1, 4, 0, CfgFile$
  Code = ERR()
  IF Code = 1
    INPUT #1, Value$
    IF Value$ <> CfgTag$
      Code = 18
    ELSE
      INPUT #1, Value$
      SysopName$ = Value$[1, 40]
      INPUT #1, UsePrinter
      INPUT #1, CarrierWatch
      INPUT #1, IdleMinutes
      INPUT #1, BaudCode
      INPUT #1, Value$
      ModemInit$ = Value$[1, 80]
      INPUT #1, ChunkSize
      INPUT #1, NumSect
      INPUT #1, Value$
      DataDrive$ = Value$[1, 30]
      INPUT #1, Value$
      MsgDrive$ = Value$[1, 30]
      INPUT #1, Value$
      TextDrive$ = Value$[1, 30]
      INPUT #1, Value$
      FileDrive$ = Value$[1, 30]
      INPUT #1, RDriver
      INPUT #1, AutoStart
      INPUT #1, StartOption(0)
      INPUT #1, StartOption(1)
      INPUT #1, StartOption(2)
      Code = ERR()
    ENDIF
  ENDIF
  CLOSE #1
  IF Code <> 1
    DefaultSettings()
  ENDIF
  RETURN Code
ENDFUNC

' Writes the settings to CfgFile$ on channel 1.  Returns 1 or the error
FUNC SaveSettings()
  LOCAL Code
  CLOSE #1
  OPEN #1, 8, 0, CfgFile$
  PRINT #1; CfgTag$
  PRINT #1; SysopName$
  PRINT #1; UsePrinter
  PRINT #1; CarrierWatch
  PRINT #1; IdleMinutes
  PRINT #1; BaudCode
  PRINT #1; ModemInit$
  PRINT #1; ChunkSize
  PRINT #1; NumSect
  PRINT #1; DataDrive$
  PRINT #1; MsgDrive$
  PRINT #1; TextDrive$
  PRINT #1; FileDrive$
  PRINT #1; RDriver
  PRINT #1; AutoStart
  PRINT #1; StartOption(0)
  PRINT #1; StartOption(1)
  PRINT #1; StartOption(2)
  Code = ERR()
  CLOSE #1
  IF Code = 1 THEN Code = ERR()
  RETURN Code
ENDFUNC
