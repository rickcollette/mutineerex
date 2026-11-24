' ====================================================================
' INIT - one-time Mutineer-eX board creation
' ====================================================================
' Creates default settings, one GENERAL message base, an empty user
' database, a 100-sector caller/user area and its SYSTEM.MET bookmark.
' All later administration belongs in CONFIG.COM.

INCLUDE "settings.bas"

DIM Blank(124) BYTE
DIM Status, K, MSect, MByte, CSect, CByte
Blank(124) = 155
InitSettings()
DefaultSettings()
F$ = ""

GRAPHICS 0
POKE 82, 1
CLS
PRINT "       Mutineer-eX 1.0.8 INIT"
PRINT "       ----------------------"
PRINT
PRINT "THIS CREATES A NEW BOARD ON D1:."
PRINT "IT REPLACES MESSAGE, USER AND CALLER"
PRINT "DATA ALREADY ON THE DEFAULT DRIVES."
PRINT
PRINT "CONTINUE (Y/N) >";
IF NOT InitYes() THEN END

Status = SaveSettings()
IF Status = 1 THEN Status = InitWriteStartup()
IF Status <> 1 THEN InitFail() : END

' Remove every existing message base before making GENERAL (A, level 1).
F$ = MsgDrive$ : F$ =+ "MESSAGE.D??" : XIO 33, #1, 0, 0, F$
F$ = MsgDrive$ : F$ =+ "MESSAGE.I??" : XIO 33, #1, 0, 0, F$
F$ = MsgDrive$ : F$ =+ "MESSAGE.M??" : XIO 33, #1, 0, 0, F$

' OPEN for output does not reliably return an existing SDFS file's sector
' chain to the free list.  Delete all fixed databases first so INIT is safe
' to run again on an already initialized board (and after a partial INIT).
F$ = DataDrive$ : F$ =+ "CALLERS.DAT" : XIO 33, #1, 0, 0, F$
F$ = DataDrive$ : F$ =+ "USERS.DAT" : XIO 33, #1, 0, 0, F$
F$ = DataDrive$ : F$ =+ "SYSTEM.MET" : XIO 33, #1, 0, 0, F$

F$ = MsgDrive$ : F$ =+ "MESSAGE.DA1"
CLOSE #1
OPEN #1, 8, 0, F$
Status = ERR()
IF Status <> 1 THEN InitFail() : END
NOTE #1, MSect, MByte
Status = ERR()
IF Status <> 1 THEN CLOSE #1 : InitFail() : END
InitFill100()
IF Status <> 1 THEN InitFail() : END

F$ = MsgDrive$ : F$ =+ "MESSAGE.IA1"
OPEN #1, 8, 0, F$
Status = ERR()
CLOSE #1
IF Status <> 1 THEN InitFail() : END

F$ = MsgDrive$ : F$ =+ "MESSAGE.MA1"
OPEN #1, 8, 0, F$
PRINT #1; "GENERAL"
PRINT #1; "General discussion"
PRINT #1; MSect
PRINT #1; MByte
PRINT #1; 0
PRINT #1; 0
Status = ERR()
CLOSE #1
IF Status <> 1 THEN InitFail() : END

' The fixed caller/user activity area is 100 sectors.
F$ = DataDrive$ : F$ =+ "CALLERS.DAT"
OPEN #1, 8, 0, F$
Status = ERR()
IF Status <> 1 THEN InitFail() : END
NOTE #1, CSect, CByte
Status = ERR()
IF Status <> 1 THEN CLOSE #1 : InitFail() : END
InitFill100()
IF Status <> 1 THEN InitFail() : END

F$ = DataDrive$ : F$ =+ "USERS.DAT"
OPEN #1, 8, 0, F$
Status = ERR()
IF Status <> 1 THEN InitFail() : END
InitFill100()
IF Status <> 1 THEN InitFail() : END
' Put the end marker at the beginning without shrinking the allocation.
OPEN #1, 12, 0, F$
PRINT #1; "*"
Status = ERR()
CLOSE #1
IF Status <> 1 THEN InitFail() : END

F$ = DataDrive$ : F$ =+ "SYSTEM.MET"
OPEN #1, 8, 0, F$
PRINT #1; CSect
PRINT #1; CByte
PRINT #1; 0
Status = ERR()
CLOSE #1
IF Status <> 1 THEN InitFail() : END

PRINT
PRINT "INITIALIZATION COMPLETE"
PRINT "GENERAL MESSAGE BASE: 100 SECTORS"
PRINT "CALLER/USER AREA:      100 SECTORS"
PRINT "USER DATABASE:         100 SECTORS"
PRINT
PRINT "RUN CONFIG TO CUSTOMIZE THE BOARD."
POKE 82, 2
END

FUNC InitYes()
  LOCAL C
  DO
    GET C
    IF C > 96 THEN C = C - 32
  LOOP UNTIL C = 89 OR C = 78
  PRINT CHR$(C)
  RETURN C = 89
ENDFUNC

FUNC InitFill100()
  Status = 1
  FOR K = 1 TO 100
    BPUT #1, ADR(Blank), 125
    Status = ERR()
    IF Status <> 1 THEN EXIT
  NEXT K
  CLOSE #1
ENDFUNC

FUNC InitWriteStartup()
  CLOSE #1
  OPEN #1, 8, 0, "D1:eosauto.bat"
  PRINT #1; "; Written by Mutineer-eX INIT"
  PRINT #1; "SET PATH=CAR:;D1:"
  ' CONFIG selects an EOS R: device; NONE also supports a preloaded handler.
  PRINT #1; "D1:remms.com"
  ' The safe default is manual time: JIFFY has no battery-backed state.
  PRINT #1; "D1:wfc.com"
  Status = ERR()
  CLOSE #1
  RETURN Status
ENDFUNC

FUNC InitFail()
  PRINT
  PRINT "ERROR "; Status; " CREATING"
  PRINT F$
  PRINT "INITIALIZATION STOPPED"
  POKE 82, 2
ENDFUNC
