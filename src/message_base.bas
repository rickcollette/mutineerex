' Message-base discovery and metadata shared by WFC and MESSAGE.

' Builds the paths for base From (0=A through 25=Z)
FUNC BuildBasePaths()
  T$ = STR$(BaseLevel(From))
  MDF$ = MsgDrive$
  MDF$ =+ "MESSAGE.D"
  MDF$ =+ CHR$(65 + From)
  MDF$ =+ T$
  MIF$ = MsgDrive$
  MIF$ =+ "MESSAGE.I"
  MIF$ =+ CHR$(65 + From)
  MIF$ =+ T$
  FileName$ = MsgDrive$
  FileName$ =+ "MESSAGE.M"
  FileName$ =+ CHR$(65 + From)
  FileName$ =+ T$
ENDFUNC

' Finds the MESSAGE.MIL files and records their IDs and minimum levels
FUNC DiscoverBases()
  FOR Q1 = 0 TO 25
    BasePresent(Q1) = 0
    BaseLevel(Q1) = 0
  NEXT Q1
  CLOSE #FileCh
  S$ = MsgDrive$
  S$ =+ "MESSAGE.M??"
  OPEN #FileCh, 6, 0, S$
  IF ERR() <> 1 THEN RETURN
  DO
    INPUT #FileCh, S$
    Q2 = ERR()
    IF Q2 <> 1 OR INSTR(S$, "FREE SECTORS") > 0 THEN EXIT
    IF LEN(S$) >= 13
      Q2 = PEEK(ADR(S$) + 11)
      Q3 = PEEK(ADR(S$) + 12)
      Q4 = PEEK(ADR(S$) + 13) - 48
      IF Q2 = 77 AND Q3 >= 65 AND Q3 <= 90 AND Q4 >= 1 AND Q4 <= 9
        BasePresent(Q3 - 65) = 1
        BaseLevel(Q3 - 65) = Q4
      ENDIF
    ENDIF
  LOOP
  CLOSE #FileCh
ENDFUNC

' Loads one base's metadata and makes it active; the modem is already closed
FUNC ReadBaseMeta(K)
  From = K
  BuildBasePaths()
  OPEN #FileCh, 4, 0, FileName$
  St = ERR()
  IF St = 1
    INPUT #FileCh, S$
    BaseName$ = S$[1, 32]
    INPUT #FileCh, S$
    BaseDesc$ = S$[1, 70]
    INPUT #FileCh, MSect
    INPUT #FileCh, MByte
    INPUT #FileCh, Msgs
    INPUT #FileCh, HMsg
    St = ERR()
    IF St = 136 THEN St = 1
  ENDIF
  CLOSE #FileCh
  IF St = 1
    ActiveBase = K
  ENDIF
ENDFUNC

' Writes the counters and descriptive text of the active base
FUNC SaveBaseMeta()
  IF ActiveBase < 0 THEN RETURN
  From = ActiveBase
  BuildBasePaths()
  CLOSE #FileCh
  OPEN #FileCh, 8, 0, FileName$
  PRINT #FileCh; BaseName$
  PRINT #FileCh; BaseDesc$
  PRINT #FileCh; MSect
  PRINT #FileCh; MByte
  PRINT #FileCh; Msgs
  PRINT #FileCh; HMsg
  CLOSE #FileCh
ENDFUNC

' Selects A, or the first base visible to this user.
FUNC LoadDefaultBase()
  CloseModem()
  DiscoverBases()
  Q6 = -1
  Dir = 0
  FOR Q5 = 0 TO 25
    IF BasePresent(Q5) THEN Dir = 1
    IF Q6 < 0 AND BasePresent(Q5) AND BaseLevel(Q5) <= UserLevel THEN Q6 = Q5
  NEXT Q5
  IF Q6 >= 0 THEN ReadBaseMeta(Q6)
  OpenModem()
  IF Q6 < 0
    ActiveBase = -2
    IF Dir
      BaseName$ = "No accessible base"
      BaseDesc$ = "Ask the SysOp for access"
    ELSE
      BaseName$ = "No message bases"
      BaseDesc$ = "Run INIT or add a base in CONFIG"
    ENDIF
    MIF$ = ""
    MDF$ = ""
  ENDIF
ENDFUNC
