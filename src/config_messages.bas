' ====================================================================
' Message-base CRUD
' ====================================================================

FUNC MessageBaseManager()
  DO
    CLS
    PRINT "       MESSAGE BASES"
    PRINT "       -------------"
    PRINT " L LIST BASES"
    PRINT " A ADD BASE"
    PRINT " E EDIT BASE"
    PRINT " C CLEAR ALL MESSAGES"
    PRINT " R REMOVE BASE"
    PRINT " X BACK"
    PRINT
    INPUT "CHOICE >"; In$
    In$ = UCASE$(In$)
    IF In$ = "L"
      ListBases()
    ELIF In$ = "A"
      AddBase()
    ELIF In$ = "E"
      EditBase()
    ELIF In$ = "C"
      ClearBase()
    ELIF In$ = "R"
      RemoveBase()
    ELIF In$ = "X"
      RETURN
    ENDIF
  LOOP
ENDFUNC

FUNC DiscoverConfigBases()
  LOCAL I
  FOR I = 0 TO 25
    BasePresent(I) = 0
    BaseLevel(I) = 0
  NEXT I
  CLOSE #1
  F$ = MsgDrive$ : F$ =+ "MESSAGE.M??"
  OPEN #1, 6, 0, F$
  IF ERR() <> 1 THEN RETURN
  DO
    INPUT #1, S$
    Status = ERR()
    IF Status <> 1 OR INSTR(S$, "FREE SECTORS") > 0 THEN EXIT
    IF LEN(S$) >= 13
      Value = PEEK(ADR(S$) + 11)
      Count = PEEK(ADR(S$) + 12)
      K = PEEK(ADR(S$) + 13) - 48
      IF Value = 77 AND Count >= 65 AND Count <= 90 AND K >= 1 AND K <= 9
        BasePresent(Count - 65) = 1
        BaseLevel(Count - 65) = K
      ENDIF
    ENDIF
  LOOP
  CLOSE #1
ENDFUNC

FUNC MakeBasePath(Role)
  F$ = MsgDrive$
  F$ =+ "MESSAGE."
  F$ =+ CHR$(Role)
  F$ =+ CHR$(65 + BaseId)
  F$ =+ STR$(BaseMin)
ENDFUNC

FUNC ReadConfigBase()
  BaseMin = BaseLevel(BaseId)
  MakeBasePath(77)
  CLOSE #1
  OPEN #1, 4, 0, F$
  Status = ERR()
  IF Status = 1
    INPUT #1, BaseName$
    INPUT #1, BaseDesc$
    INPUT #1, MSect
    INPUT #1, MByte
    INPUT #1, Msgs
    INPUT #1, HMsg
    Status = ERR()
    IF Status = 136 THEN Status = 1
  ENDIF
  CLOSE #1
ENDFUNC

FUNC SaveConfigBase()
  MakeBasePath(77)
  CLOSE #1
  OPEN #1, 8, 0, F$
  Status = ERR()
  IF Status = 1
    PRINT #1; BaseName$
    PRINT #1; BaseDesc$
    PRINT #1; MSect
    PRINT #1; MByte
    PRINT #1; Msgs
    PRINT #1; HMsg
    Status = ERR()
  ENDIF
  CLOSE #1
ENDFUNC

FUNC ListBases()
  LOCAL I
  CLS
  PRINT "ID LV MSGS NAME"
  PRINT "-- -- ---- --------------------------"
  DiscoverConfigBases()
  FOR I = 0 TO 25
    IF BasePresent(I)
      BaseId = I
      ReadConfigBase()
      IF Status = 1 THEN PRINT CHR$(65 + I); "  "; BaseMin; " "; Msgs; " "; BaseName$
    ENDIF
  NEXT I
  PauseForKey()
ENDFUNC

FUNC AskBaseId()
  PRINT "BASE LETTER A-Z >";
  INPUT ; In$
  In$ = UCASE$(In$)
  IF LEN(In$) <> 1
    BaseId = -1
    RETURN
  ENDIF
  BaseId = PEEK(ADR(In$) + 1) - 65
  IF BaseId < 0 OR BaseId > 25 THEN BaseId = -1
ENDFUNC

FUNC AskBaseText()
  DO
    PRINT "NAME (32 CHARACTERS) >";
    INPUT ; BaseName$
  LOOP UNTIL BaseName$ <> ""
  BaseName$ = BaseName$[1, 32]
  DO
    PRINT "DESCRIPTION (70 CHARACTERS) >";
    INPUT ; BaseDesc$
  LOOP UNTIL BaseDesc$ <> ""
  BaseDesc$ = BaseDesc$[1, 70]
  BaseMin = AskNumber(1, 1, 9)
ENDFUNC

FUNC FillBaseData()
  Status = 1
  FOR K = 1 TO Count
    BPUT #1, ADR(Blank), 125
    Status = ERR()
    IF Status <> 1 THEN EXIT
  NEXT K
  CLOSE #1
ENDFUNC

FUNC CreateConfigBase()
  MakeBasePath(68)
  CLOSE #1
  OPEN #1, 8, 0, F$
  Status = ERR()
  IF Status <> 1 THEN RETURN
  NOTE #1, MSect, MByte
  Status = ERR()
  IF Status <> 1 THEN CLOSE #1 : RETURN
  FillBaseData()
  IF Status <> 1 THEN RETURN
  MakeBasePath(73)
  OPEN #1, 8, 0, F$
  Status = ERR()
  CLOSE #1
  IF Status <> 1 THEN RETURN
  Msgs = 0 : HMsg = 0
  SaveConfigBase()
ENDFUNC

FUNC AddBase()
  CLS
  DiscoverConfigBases()
  AskBaseId()
  IF BaseId < 0 THEN RETURN
  IF BasePresent(BaseId)
    PRINT "BASE ALREADY EXISTS"
    PauseForKey()
    RETURN
  ENDIF
  AskBaseText()
  Count = AskNumber(100, 1, 9999)
  CreateConfigBase()
  IF Status = 1
    PRINT "BASE "; CHR$(65 + BaseId); " CREATED"
  ELSE
    ShowError()
    RETURN
  ENDIF
  PauseForKey()
ENDFUNC

FUNC RenameBaseFile(Role, OldLevel, NewLevel)
  BaseMin = OldLevel
  MakeBasePath(Role)
  S$ = F$
  S$ =+ ",MESSAGE."
  S$ =+ CHR$(Role)
  S$ =+ CHR$(65 + BaseId)
  S$ =+ STR$(NewLevel)
  XIO 32, #1, 0, 0, S$
  Status = ERR()
ENDFUNC

FUNC RenameBase(OldLevel, NewLevel)
  RenameBaseFile(68, OldLevel, NewLevel)
  IF Status <> 1 THEN BaseMin = OldLevel : RETURN
  RenameBaseFile(73, OldLevel, NewLevel)
  IF Status <> 1
    Count = Status
    RenameBaseFile(68, NewLevel, OldLevel)
    Status = Count
    BaseMin = OldLevel
    RETURN
  ENDIF
  RenameBaseFile(77, OldLevel, NewLevel)
  IF Status <> 1
    Count = Status
    RenameBaseFile(73, NewLevel, OldLevel)
    RenameBaseFile(68, NewLevel, OldLevel)
    Status = Count
    BaseMin = OldLevel
  ELSE
    BaseMin = NewLevel
  ENDIF
ENDFUNC

FUNC EditBase()
  CLS
  DiscoverConfigBases()
  AskBaseId()
  IF BaseId < 0 OR NOT BasePresent(BaseId)
    PRINT "BASE NOT FOUND" : PauseForKey() : RETURN
  ENDIF
  ReadConfigBase()
  IF Status <> 1 THEN ShowError() : RETURN
  Value = BaseMin
  PRINT "NAME: "; BaseName$
  PRINT "NEW NAME, RETURN=KEEP >";
  INPUT ; In$
  IF In$ <> "" THEN BaseName$ = In$[1, 32]
  PRINT "DESCRIPTION: "; BaseDesc$
  PRINT "NEW DESCRIPTION, RETURN=KEEP >";
  INPUT ; In$
  IF In$ <> "" THEN BaseDesc$ = In$[1, 70]
  BaseMin = AskNumber(BaseMin, 1, 9)
  IF BaseMin <> Value
    RenameBase(Value, BaseMin)
    IF Status <> 1
      PRINT "COULD NOT CHANGE ACCESS LEVEL"
      ShowError()
      RETURN
    ENDIF
  ENDIF
  SaveConfigBase()
  IF Status = 1 THEN PRINT "BASE UPDATED" ELSE ShowError()
  PauseForKey()
ENDFUNC

FUNC DeleteBaseFiles()
  MakeBasePath(68) : XIO 33, #1, 0, 0, F$
  MakeBasePath(73) : XIO 33, #1, 0, 0, F$
  MakeBasePath(77) : XIO 33, #1, 0, 0, F$
  Status = ERR()
ENDFUNC

FUNC ClearBase()
  CLS
  DiscoverConfigBases()
  AskBaseId()
  IF BaseId < 0 OR NOT BasePresent(BaseId) THEN PRINT "BASE NOT FOUND" : PauseForKey() : RETURN
  ReadConfigBase()
  IF Status <> 1 THEN ShowError() : RETURN
  PRINT "DELETE EVERY MESSAGE IN "; BaseName$
  PRINT "CONTINUE (Y/N) >";
  IF NOT AskYes() THEN RETURN
  Count = AskNumber(100, 1, 9999)
  DeleteBaseFiles()
  CreateConfigBase()
  IF Status = 1 THEN PRINT "BASE CLEARED" ELSE ShowError()
  PauseForKey()
ENDFUNC

FUNC RemoveBase()
  CLS
  DiscoverConfigBases()
  AskBaseId()
  IF BaseId < 0 OR NOT BasePresent(BaseId) THEN PRINT "BASE NOT FOUND" : PauseForKey() : RETURN
  ReadConfigBase()
  PRINT "REMOVE "; BaseName$; " AND ALL MESSAGES"
  PRINT "CONTINUE (Y/N) >";
  IF NOT AskYes() THEN RETURN
  DeleteBaseFiles()
  IF Status = 1 OR Status = 170 THEN PRINT "BASE REMOVED" ELSE ShowError()
  PauseForKey()
ENDFUNC
