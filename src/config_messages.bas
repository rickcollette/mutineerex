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
  LOCAL I, R
  FOR I = 0 TO 25
    BasePresent(I) = 0
    BaseLevel(I) = 0
  NEXT I
  R = FindAreaRegistry()
  IF R < 0 THEN Status = AreaError : PRINT "AREAS.CFG ERROR "; AreaError : RETURN
  IF R = 0
    CLOSE #1
    F$ = MsgDrive$ : F$ =+ "MESSAGE.M??"
    OPEN #1, 6, 0, F$
    IF ERR() <> 1 THEN CLOSE #1 : RETURN
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
    RETURN
  ENDIF
  OpenAreaRegistry(R)
  DO
    INPUT #6, AreaLine$
    IF ERR() <> 1 THEN EXIT
    IF AreaLine$[1, 1] = "M"
      ParseAreaRecord()
      I = AreaKind - 6
      BasePresent(I) = 1
      BaseLevel(I) = AreaLevel
    ENDIF
  LOOP
  CLOSE #6
ENDFUNC

FUNC MakeBasePath(Role)
  F$ = AreaPath$
  F$ =+ "MESSAGE."
  F$ =+ CHR$(Role)
  F$ =+ CHR$(65 + BaseId)
  F$ =+ STR$(BaseMin)
ENDFUNC

FUNC ReadConfigBase()
  Status = ResolveMessageArea(BaseId)
  IF Status <> 1 THEN IF Status < 0 THEN Status = AreaError ELSE Status = 170 : RETURN
  BaseMin = AreaLevel
  BaseLevel(BaseId) = BaseMin
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
      IF Status = 1
        PRINT CHR$(65 + I); "  "; BaseMin; " "; Msgs; " "; BaseName$
        PRINT "   "; AreaPath$
      ENDIF
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
  AreaPath$ = MsgDrive$
  IF NOT NormalizeAreaPath() THEN Status = 18 : ShowError() : RETURN
  IF NOT AskStoragePath() THEN PauseForKey() : RETURN
  Target$ = AreaPath$
  Count = AskNumber(100, 1, 9999)
  CreateConfigBase()
  IF Status = 1
    IF SaveAreaRegistry(1)
      PRINT "BASE "; CHR$(65 + BaseId); " CREATED"
    ELSE
      AreaPath$ = Target$
      DeleteBaseFiles()
      PRINT "REGISTRY SAVE FAILED; BASE NOT ADDED"
      ShowError()
      RETURN
    ENDIF
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

' Builds F$ for the old root (Which=0) or destination root (Which=1).
FUNC MakeMoveBasePath(Which, Role, Level)
  IF Which = 0 THEN F$ = OldName$ ELSE F$ = Target$
  F$ =+ "MESSAGE." : F$ =+ CHR$(Role)
  F$ =+ CHR$(65 + BaseId) : F$ =+ STR$(Level)
ENDFUNC

FUNC DeleteMoveBase()
  MakeMoveBasePath(1, 68, BaseMin) : XIO 33, #1, 0, 0, F$
  MakeMoveBasePath(1, 73, BaseMin) : XIO 33, #1, 0, 0, F$
  MakeMoveBasePath(1, 77, BaseMin) : XIO 33, #1, 0, 0, F$
ENDFUNC

FUNC CountBaseBlocks(OldLevel)
  LOCAL Code, Got
  Count = 0
  MakeMoveBasePath(0, 68, OldLevel)
  CLOSE #1 : OPEN #1, 4, 0, F$
  Status = ERR()
  IF Status <> 1 THEN CLOSE #1 : RETURN 0
  DO
    BGET #1, ADR(Blank), 125
    Code = ERR() : Got = DPEEK($358)
    IF Got > 0 THEN INC Count
    IF Code <> 1 OR Got = 0 THEN EXIT
  LOOP
  CLOSE #1
  IF Code <> 1 AND Code <> 136 THEN Status = Code : RETURN 0
  Status = 1
  RETURN Count > 0
ENDFUNC

FUNC DestinationBaseFree()
  MakeMoveBasePath(1, 68, BaseMin)
  IF FileExists() THEN Status = 171 : RETURN 0
  MakeMoveBasePath(1, 73, BaseMin)
  IF FileExists() THEN Status = 171 : RETURN 0
  MakeMoveBasePath(1, 77, BaseMin)
  IF FileExists() THEN Status = 171 : RETURN 0
  RETURN 1
ENDFUNC

' Rebuild active index records and message bodies at Target$.  UserLevel is
' the old access level.  The destination data file keeps Count 125-byte
' allocation blocks even though killed and superseded bodies are compacted.
FUNC RebuildMessageBase()
  LOCAL Code, Got, Lines, I, Sect, Bt, Records
  IF NOT CountBaseBlocks(UserLevel) THEN RETURN 0
  IF NOT DestinationBaseFree() THEN RETURN 0

  MakeMoveBasePath(1, 68, BaseMin)
  OPEN #3, 8, 0, F$
  Status = ERR()
  IF Status <> 1 THEN CLOSE #3 : RETURN 0
  NOTE #3, CSect, CByte
  FOR I = 1 TO Count
    BPUT #3, ADR(MoveBuf), 125
    Status = ERR()
    IF Status <> 1 THEN EXIT
  NEXT I
  CLOSE #3
  IF Status <> 1 THEN DeleteMoveBase() : RETURN 0

  MakeMoveBasePath(0, 68, UserLevel) : OPEN #1, 4, 0, F$
  Status = ERR()
  MakeMoveBasePath(0, 73, UserLevel) : OPEN #2, 4, 0, F$
  IF Status = 1 THEN Status = ERR()
  MakeMoveBasePath(1, 68, BaseMin) : OPEN #3, 12, 0, F$
  IF Status = 1 THEN Status = ERR()
  MakeMoveBasePath(1, 73, BaseMin) : OPEN #4, 8, 0, F$
  IF Status = 1 THEN Status = ERR()
  IF Status <> 1 THEN CLOSE #1 : CLOSE #2 : CLOSE #3 : CLOSE #4 : DeleteMoveBase() : RETURN 0
  POINT #3, CSect, CByte
  DO
    BGET #2, ADR(Blank), 40
    Code = ERR() : Got = DPEEK($368)
    IF Got = 0 THEN EXIT
    IF Got <> 40 THEN Status = 18 : EXIT
    Sect = Blank(37) * 256 + Blank(38)
    Bt = Blank(39)
    POINT #1, Sect, Bt
    NOTE #3, MSect, MByte
    K = (MSect & $7FFF) / 256
    IF MSect < 0 THEN K = K + 128
    Blank(37) = K
    Blank(38) = MSect & 255
    Blank(39) = MByte
    FOR I = 1 TO 6
      INPUT #1, S$
      Status = ERR()
      IF Status <> 1 THEN EXIT
      PRINT #3; S$
    NEXT I
    IF Status <> 1 THEN EXIT
    INPUT #1, Lines
    Status = ERR()
    IF Status <> 1 THEN EXIT
    PRINT #3; Lines
    FOR I = 1 TO Lines
      INPUT #1, S$
      Status = ERR()
      IF Status <> 1 THEN EXIT
      PRINT #3; S$
    NEXT I
    IF Status <> 1 THEN EXIT
    BPUT #4, ADR(Blank), 40
    Status = ERR()
    IF Status <> 1 THEN EXIT
    INC Records
  LOOP
  IF Status = 1 AND Code <> 1 AND Code <> 136 THEN Status = Code
  NOTE #3, MSect, MByte
  CLOSE #1 : CLOSE #2 : CLOSE #3 : CLOSE #4
  IF Status <> 1 OR Records <> Msgs
    IF Status = 1 THEN Status = 18
    DeleteMoveBase()
    RETURN 0
  ENDIF

  MakeMoveBasePath(1, 77, BaseMin)
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
  IF Status <> 1 THEN DeleteMoveBase() : RETURN 0
  RETURN 1
ENDFUNC

FUNC ValidateMovedBase()
  LOCAL Code, Got, Records, Sect, Bt, N
  MakeMoveBasePath(1, 68, BaseMin) : OPEN #1, 4, 0, F$
  Status = ERR()
  MakeMoveBasePath(1, 73, BaseMin) : OPEN #2, 4, 0, F$
  IF Status = 1 THEN Status = ERR()
  IF Status <> 1 THEN CLOSE #1 : CLOSE #2 : RETURN 0
  DO
    BGET #2, ADR(Blank), 40
    Code = ERR() : Got = DPEEK($368)
    IF Got = 0 THEN EXIT
    IF Got <> 40 THEN Status = 18 : EXIT
    Sect = Blank(37) * 256 + Blank(38) : Bt = Blank(39)
    POINT #1, Sect, Bt
    INPUT #1, S$
    Status = ERR()
    IF Status <> 1 THEN EXIT
    N = VAL(S$)
    Value = (Blank(0) - 48) * 1000 + (Blank(1) - 48) * 100 + (Blank(2) - 48) * 10 + Blank(3) - 48
    IF N <> Value THEN Status = 18 : EXIT
    INC Records
  LOOP
  CLOSE #1 : CLOSE #2
  IF Status = 1 AND Code <> 1 AND Code <> 136 THEN Status = Code
  IF Status = 1 AND Records <> Msgs THEN Status = 18
  RETURN Status = 1
ENDFUNC

FUNC RelocateMessageBase(OldLevel)
  UserLevel = OldLevel
  IF NOT EnsureAreaFolder() THEN Status = AreaError : RETURN 0
  IF NOT RebuildMessageBase() THEN RETURN 0
  IF NOT ValidateMovedBase() THEN DeleteMoveBase() : RETURN 0
  IF NOT SaveAreaRegistry(1) THEN DeleteMoveBase() : RETURN 0
  ' Only after the registry names the validated rebuild do we remove source.
  MakeMoveBasePath(0, 68, OldLevel) : XIO 33, #1, 0, 0, F$
  MakeMoveBasePath(0, 73, OldLevel) : XIO 33, #1, 0, 0, F$
  MakeMoveBasePath(0, 77, OldLevel) : XIO 33, #1, 0, 0, F$
  Status = 1
  RETURN 1
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
  OldName$ = AreaPath$
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
  AreaPath$ = OldName$
  IF NOT AskStoragePath() THEN PauseForKey() : RETURN
  Target$ = AreaPath$
  IF BaseMin <> Value OR Target$ <> OldName$
    IF NOT RelocateMessageBase(Value)
      PRINT "BASE MOVE FAILED; ORIGINAL BASE REMAINS ACTIVE"
      ShowError()
      RETURN
    ENDIF
  ELSE
    AreaPath$ = OldName$
    SaveConfigBase()
  ENDIF
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
  OldName$ = AreaPath$
  PRINT "REMOVE "; BaseName$; " AND ALL MESSAGES"
  PRINT "CONTINUE (Y/N) >";
  IF NOT AskYes() THEN RETURN
  Target$ = AreaPath$
  IF NOT SaveAreaRegistry(-1) THEN PRINT "REGISTRY UPDATE FAILED" : ShowError() : RETURN
  AreaPath$ = OldName$
  DeleteBaseFiles()
  IF Status = 1 OR Status = 170 THEN PRINT "BASE REMOVED" ELSE ShowError()
  PauseForKey()
ENDFUNC
