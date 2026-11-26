' ====================================================================
' Download file-area manager
' ====================================================================

FUNC FileAreaManager()
  DO
    CLS
    PRINT "         FILE AREAS"
    PRINT "         ----------"
    PRINT " L LIST CONTROLLED FILES"
    PRINT " P EDIT AREA PATHS"
    PRINT " A ADD COPIED FILE"
    PRINT " E EDIT FILE ENTRY"
    PRINT " R REMOVE FILE"
    PRINT " X BACK"
    PRINT
    INPUT "CHOICE >"; In$
    In$ = UCASE$(In$)
    IF In$ = "L"
      ListControlledFiles()
    ELIF In$ = "P"
      EditFileAreaPath()
    ELIF In$ = "A"
      AddControlledFile()
    ELIF In$ = "E"
      EditControlledFile()
    ELIF In$ = "R"
      RemoveControlledFile()
    ELIF In$ = "X"
      RETURN
    ENDIF
  LOOP
ENDFUNC

FUNC ValidStem()
  LOCAL I, C
  IF LEN(Name$) < 1 OR LEN(Name$) > 7 THEN RETURN 0
  FOR I = 1 TO LEN(Name$)
    C = PEEK(ADR(Name$) + I)
    IF NOT ((C >= 65 AND C <= 90) OR (C >= 48 AND C <= 57)) THEN RETURN 0
  NEXT I
  RETURN 1
ENDFUNC

FUNC ValidControlled()
  LOCAL P, C
  P = INSTR(Target$, ".")
  IF P < 2 OR P > 8 OR P <> LEN(Target$) - 3 THEN RETURN 0
  Name$ = Target$[1, P - 1]
  IF NOT ValidStem() THEN RETURN 0
  C = PEEK(ADR(Target$) + P + 1)
  IF C <> 71 AND C <> 65 AND C <> 84 AND C <> 82 AND C <> 85 THEN RETURN 0
  C = PEEK(ADR(Target$) + P + 2)
  IF C <> 67 AND C <> 69 AND C <> 88 AND C <> 66 AND C <> 84 AND C <> 85 THEN RETURN 0
  C = PEEK(ADR(Target$) + P + 3)
  RETURN C >= 49 AND C <= 57
ENDFUNC

FUNC ControlledExists()
  Value = FileStorageArea(Target$)
  IF Value < 0 OR ResolveFileArea(Value) <> 1 THEN Status = AreaError : RETURN 0
  F$ = AreaPath$ : F$ =+ Target$
  RETURN FileExists()
ENDFUNC

FUNC CatalogFind()
  LOCAL P, Code
  Desc$ = "No description available."
  CLOSE #2
  F$ = FileDrive$ : F$ =+ "FILES.DAT"
  OPEN #2, 4, 0, F$
  Code = ERR()
  IF Code = 1
    DO
      INPUT #2, S$
      Code = ERR()
      IF Code <> 1 THEN EXIT
      P = INSTR(S$, "|")
      IF P > 1 AND UCASE$(S$[1, P - 1]) = Target$
        Desc$ = S$[P + 1, 70]
        IF Desc$ = "" THEN Desc$ = "No description available."
        EXIT
      ENDIF
    LOOP
  ENDIF
  CLOSE #2
ENDFUNC

' Rewrites FILES.DAT through FILES.TMP.  Streaming the records keeps
' CONFIG usable with EOS's cartridge mapped; a whole-file RAM buffer does
' not fit below MEMTOP.  Target$ is removed; NewName$ is also removed to
' prevent duplicates.  DeleteFlag=0 appends NewName$|Desc$.
FUNC CatalogRewrite(DeleteFlag)
  LOCAL P, Code
  F$ = FileDrive$ : F$ =+ "FILES.DAT"
  S$ = FileDrive$ : S$ =+ "FILES.TMP"
  XIO 33, #2, 0, 0, S$
  CLOSE #2
  OPEN #2, 8, 0, S$
  Status = ERR()
  IF Status <> 1 THEN RETURN
  CLOSE #1
  OPEN #1, 4, 0, F$
  Code = ERR()
  Status = 1
  IF Code = 1
    DO
      INPUT #1, T$
      Code = ERR()
      IF Code <> 1
        IF Code <> 136 THEN Status = Code
        EXIT
      ENDIF
      P = INSTR(T$, "|")
      Name$ = ""
      IF P > 1 THEN Name$ = UCASE$(T$[1, P - 1])
      Found = 0
      IF P > 1 AND Name$ = Target$ THEN Found = 1
      IF P > 1 AND Name$ = NewName$ THEN Found = 1
      IF NOT Found
        PRINT #2; T$
        Status = ERR()
        IF Status <> 1 THEN EXIT
      ENDIF
    LOOP
  ELIF Code <> 170
    Status = Code
  ENDIF
  CLOSE #1
  IF Status <> 1 THEN CLOSE #2 : RETURN
  IF NOT DeleteFlag
    T$ = NewName$ : T$ =+ "|" : T$ =+ Desc$
    PRINT #2; T$
    Status = ERR()
  ENDIF
  CLOSE #2
  IF Status <> 1 THEN RETURN

  ' Keep the old catalog until the completed temporary file is ready.
  ' F$ is FILES.DAT, S$ is FILES.TMP and T$ is FILES.BAK.
  T$ = FileDrive$ : T$ =+ "FILES.BAK"
  XIO 33, #1, 0, 0, T$
  In$ = S$ : S$ = T$
  MoveFile()
  S$ = In$
  Code = Status
  IF Code <> 1 AND Code <> 170 THEN RETURN
  In$ = F$ : F$ = S$ : S$ = In$
  MoveFile()
  IF Status <> 1 AND Code = 1
    Code = Status
    F$ = T$
    MoveFile()
    Status = Code
  ENDIF
  IF Status = 1 THEN XIO 33, #1, 0, 0, T$
ENDFUNC

FUNC CategoryName$(C)
  IF C = 71 THEN RETURN "GAME"
  IF C = 65 THEN RETURN "APP"
  IF C = 84 THEN RETURN "TOOL"
  IF C = 82 THEN RETURN "ARCHIVER"
  RETURN "UNKNOWN"
ENDFUNC

FUNC ListControlledFiles()
  LOCAL C, Y, L, I, A
  CLS
  PRINT "CONTROLLED DOWNLOADS"
  PRINT
  Count = 0
  FOR A = 0 TO 5
    Status = ResolveFileArea(A)
    IF Status <> 1 THEN PRINT "AREAS.CFG ERROR "; AreaError : PauseForKey() : RETURN
    PRINT AreaTitle$(A); ": "; AreaPath$
    F$ = AreaPath$ : F$ =+ "*.???"
    CLOSE #1
    OPEN #1, 6, 0, F$
    IF ERR() = 1
      DO
        INPUT #1, S$
        Status = ERR()
        IF Status <> 1 OR INSTR(S$, "FREE SECTORS") > 0 THEN EXIT
        IF LEN(S$) >= 13
          C = PEEK(ADR(S$) + 11)
          Y = PEEK(ADR(S$) + 12)
          L = PEEK(ADR(S$) + 13) - 48
          IF (C = 71 OR C = 65 OR C = 84 OR C = 82 OR C = 85) AND (Y = 67 OR Y = 69 OR Y = 88 OR Y = 66 OR Y = 84 OR Y = 85) AND L >= 1 AND L <= 9
            Target$ = ""
            FOR I = 3 TO 10
              IF PEEK(ADR(S$) + I) <> 32 THEN Target$ =+ CHR$(PEEK(ADR(S$) + I))
            NEXT I
            Target$ =+ "." : Target$ =+ S$[11, 3]
            IF FileStorageArea(Target$) = A
              CatalogFind()
              PRINT Target$; " "; CategoryName$(C); " L"; L
              PRINT "  "; Desc$
              INC Count
            ENDIF
          ENDIF
        ENDIF
      LOOP
      CLOSE #1
    ELSE
      CLOSE #1
      PRINT "  CANNOT READ DIRECTORY"
    ENDIF
  NEXT A
  IF Count = 0 THEN PRINT "NO CONTROLLED FILES"
  PauseForKey()
ENDFUNC

' F$ is the source and S$ the destination.  The destination is removed on
' every error; the source is never changed here.
FUNC CopyFileVerified()
  LOCAL Code, Got1, Got2, I
  CLOSE #1 : CLOSE #2
  OPEN #1, 4, 0, F$
  Status = ERR()
  IF Status <> 1 THEN CLOSE #1 : RETURN 0
  OPEN #2, 8, 0, S$
  Status = ERR()
  IF Status <> 1 THEN CLOSE #1 : CLOSE #2 : RETURN 0
  DO
    BGET #1, ADR(Blank), 125
    Code = ERR()
    Got1 = DPEEK($358)
    IF Got1 > 0
      BPUT #2, ADR(Blank), Got1
      Status = ERR()
      IF Status <> 1 THEN EXIT
    ENDIF
    IF Code <> 1 OR Got1 = 0 THEN EXIT
  LOOP
  CLOSE #1 : CLOSE #2
  IF Status <> 1 OR (Code <> 1 AND Code <> 136)
    IF Status = 1 THEN Status = Code
    XIO 33, #2, 0, 0, S$
    RETURN 0
  ENDIF
  OPEN #1, 4, 0, F$ : Code = ERR()
  OPEN #2, 4, 0, S$ : Status = ERR()
  IF Code <> 1 OR Status <> 1 THEN CLOSE #1 : CLOSE #2 : XIO 33, #2, 0, 0, S$ : RETURN 0
  DO
    BGET #1, ADR(Blank), 125 : Code = ERR() : Got1 = DPEEK($358)
    BGET #2, ADR(MoveBuf), 125 : Status = ERR() : Got2 = DPEEK($368)
    IF Got1 <> Got2 THEN Status = 18 : EXIT
    FOR I = 0 TO Got1 - 1
      IF Blank(I) <> MoveBuf(I) THEN Status = 18 : EXIT
    NEXT I
    IF Status = 18 OR Code <> 1 OR Got1 = 0 THEN EXIT
  LOOP
  CLOSE #1 : CLOSE #2
  IF Got1 = Got2 AND (Code = 136 OR Got1 = 0) AND (Status = 136 OR Got2 = 0) THEN Status = 1
  IF Status <> 1 THEN XIO 33, #2, 0, 0, S$ : RETURN 0
  RETURN 1
ENDFUNC

' Moves F$ to S$, a full path in the same folder.  SpartaDOS X 4.49e fails
' every CIO rename (XIO 32) with error 165 (fixed in 4.49f), so when DOS
' cannot rename, copy and verify the file and then delete F$.  Returns 1
' when moved; Status is 170 when F$ does not exist.  Uses #1, #2 and
' AreaLine$; F$ and S$ are kept.
FUNC MoveFile()
  LOCAL P
  P = LEN(S$)
  DO
    IF P = 0 THEN EXIT
    IF PEEK(ADR(S$) + P) = 58 OR PEEK(ADR(S$) + P) = 62 THEN EXIT
    DEC P
  LOOP
  AreaLine$ = F$ : AreaLine$ =+ "," : AreaLine$ =+ S$[P + 1]
  XIO 32, #1, 0, 0, AreaLine$
  Status = ERR()
  IF Status = 1 OR Status = 170 THEN RETURN Status = 1
  IF NOT CopyFileVerified() THEN RETURN 0
  XIO 33, #1, 0, 0, F$
  Status = ERR()
  IF Status = 1 THEN RETURN 1
  XIO 33, #2, 0, 0, S$
  RETURN 0
ENDFUNC

FUNC AskFileMetadata()
  DO
    PRINT "BBS NAME, 1-7 LETTERS/DIGITS >";
    INPUT ; Name$
    Name$ = UCASE$(Name$)
  LOOP UNTIL ValidStem()
  DO
    PRINT "CATEGORY G GAME, A APP, T TOOL,"
    PRINT "R ARCHIVER, U UNKNOWN >";
    INPUT ; S$
    S$ = UCASE$(S$)
  LOOP UNTIL LEN(S$) = 1 AND INSTR("GATRU", S$) > 0
  DO
    PRINT "TYPE C COM, E EXE, X XEX, B BAS,"
    PRINT "T TEXT, U UNKNOWN >";
    INPUT ; T$
    T$ = UCASE$(T$)
  LOOP UNTIL LEN(T$) = 1 AND INSTR("CEXBTU", T$) > 0
  UserLevel = AskNumber(1, 1, 9)
  NewName$ = Name$ : NewName$ =+ "." : NewName$ =+ S$ : NewName$ =+ T$ : NewName$ =+ STR$(UserLevel)
ENDFUNC

FUNC RenameControlledFile()
  Value = FileStorageArea(OldName$)
  Status = ResolveFileArea(Value)
  IF Status <> 1 THEN Status = AreaError : RETURN
  F$ = AreaPath$ : F$ =+ OldName$
  K = FileStorageArea(NewName$)
  Status = ResolveFileArea(K)
  IF Status <> 1 THEN Status = AreaError : RETURN
  S$ = AreaPath$ : S$ =+ NewName$
  IF F$[1, LEN(F$) - LEN(OldName$)] = S$[1, LEN(S$) - LEN(NewName$)]
    MoveFile()
  ELSE
    IF NOT CopyFileVerified() THEN RETURN
    Status = 1
  ENDIF
ENDFUNC

FUNC RollbackControlledRename()
  LOCAL OldArea, NewArea
  OldArea = FileStorageArea(OldName$)
  NewArea = FileStorageArea(NewName$)
  IF ResolveFileArea(OldArea) <> 1 THEN RETURN
  F$ = AreaPath$ : F$ =+ OldName$
  IF ResolveFileArea(NewArea) <> 1 THEN RETURN
  S$ = AreaPath$ : S$ =+ NewName$
  IF F$[1, LEN(F$) - LEN(OldName$)] = S$[1, LEN(S$) - LEN(NewName$)]
    T$ = F$ : F$ = S$ : S$ = T$
    MoveFile()
  ELSE
    XIO 33, #1, 0, 0, S$
  ENDIF
ENDFUNC

FUNC ControlledNameFromDirectory()
  LOCAL I
  NewName$ = ""
  FOR I = 3 TO 10
    IF PEEK(ADR(S$) + I) <> 32 THEN NewName$ =+ CHR$(PEEK(ADR(S$) + I))
  NEXT I
  NewName$ =+ "." : NewName$ =+ S$[11, 3]
ENDFUNC

FUNC RemoveCopiedAreaFiles(N)
  F$ = OldName$ : F$ =+ "*.???"
  CLOSE #5 : OPEN #5, 6, 0, F$
  IF ERR() <> 1 THEN CLOSE #5 : RETURN
  DO
    INPUT #5, S$
    IF ERR() <> 1 OR INSTR(S$, "FREE SECTORS") > 0 THEN EXIT
    IF LEN(S$) >= 13
      ControlledNameFromDirectory()
      IF FileStorageArea(NewName$) = N
        F$ = Target$ : F$ =+ NewName$
        XIO 33, #1, 0, 0, F$
      ENDIF
    ENDIF
  LOOP
  CLOSE #5
ENDFUNC

FUNC RelocateFileArea(N)
  LOCAL Code
  BaseId = N
  Status = ResolveFileArea(N)
  IF Status <> 1 THEN Status = AreaError : RETURN 0
  OldName$ = AreaPath$
  IF NOT AskStoragePath() THEN RETURN 0
  Target$ = AreaPath$
  IF Target$ = OldName$ THEN RETURN SaveAreaRegistry(0)
  F$ = OldName$ : F$ =+ "*.???"
  CLOSE #5 : OPEN #5, 6, 0, F$
  Status = ERR()
  IF Status <> 1 THEN CLOSE #5 : RETURN 0
  DO
    INPUT #5, S$
    Code = ERR()
    IF Code <> 1 OR INSTR(S$, "FREE SECTORS") > 0 THEN EXIT
    IF LEN(S$) >= 13
      ControlledNameFromDirectory()
      IF FileStorageArea(NewName$) = N
        F$ = Target$ : F$ =+ NewName$
        IF FileExists()
          Status = 171
          CLOSE #5
          RETURN 0
        ENDIF
      ENDIF
    ENDIF
  LOOP
  CLOSE #5
  IF Code <> 1 AND Code <> 136
    Status = Code
    RETURN 0
  ENDIF
  ' No destination conflicts exist.  Copy and verify the entire area.
  F$ = OldName$ : F$ =+ "*.???"
  OPEN #5, 6, 0, F$
  Status = ERR()
  IF Status <> 1 THEN CLOSE #5 : RETURN 0
  DO
    INPUT #5, S$
    Code = ERR()
    IF Code <> 1 OR INSTR(S$, "FREE SECTORS") > 0 THEN EXIT
    IF LEN(S$) >= 13
      ControlledNameFromDirectory()
      IF FileStorageArea(NewName$) = N
        F$ = OldName$ : F$ =+ NewName$
        S$ = Target$ : S$ =+ NewName$
        IF NOT CopyFileVerified()
          CLOSE #5
          RemoveCopiedAreaFiles(N)
          RETURN 0
        ENDIF
      ENDIF
    ENDIF
  LOOP
  CLOSE #5
  IF Code <> 1 AND Code <> 136
    Status = Code
    RemoveCopiedAreaFiles(N)
    RETURN 0
  ENDIF
  IF NOT SaveAreaRegistry(0)
    RemoveCopiedAreaFiles(N)
    RETURN 0
  ENDIF
  ' The registry now makes the verified copies authoritative.
  F$ = OldName$ : F$ =+ "*.???"
  OPEN #5, 6, 0, F$
  IF ERR() = 1
    DO
      INPUT #5, S$
      IF ERR() <> 1 OR INSTR(S$, "FREE SECTORS") > 0 THEN EXIT
      IF LEN(S$) >= 13
        ControlledNameFromDirectory()
        IF FileStorageArea(NewName$) = N
          F$ = OldName$ : F$ =+ NewName$
          XIO 33, #1, 0, 0, F$
        ENDIF
      ENDIF
    LOOP
  ENDIF
  CLOSE #5
  Status = 1
  RETURN 1
ENDFUNC

FUNC EditFileAreaPath()
  LOCAL I
  CLS
  FOR I = 0 TO 5
    Status = ResolveFileArea(I)
    IF Status <> 1 THEN PRINT "AREAS.CFG ERROR "; AreaError : PauseForKey() : RETURN
    PRINT I; " "; AreaTitle$(I); " "; AreaPath$
  NEXT I
  BaseId = AskNumber(0, 0, 5)
  IF RelocateFileArea(BaseId)
    PRINT AreaTitle$(BaseId); " PATH UPDATED"
  ELSE
    PRINT "AREA MOVE FAILED; ORIGINAL FILES REMAIN ACTIVE"
    ShowError()
    RETURN
  ENDIF
  PauseForKey()
ENDFUNC

FUNC AddControlledFile()
  CLS
  PRINT "COPY THE FILE TO ITS CONFIGURED AREA"
  PRINT "BEFORE ADDING IT HERE."
  PRINT "CURRENT DISK NAME >";
  INPUT ; OldName$
  OldName$ = UCASE$(OldName$)
  IF OldName$ = "" THEN RETURN
  ' New imports are staged in the legacy FileDrive$ catalog location.
  F$ = FileDrive$ : F$ =+ OldName$
  IF NOT FileExists() THEN PRINT "FILE NOT FOUND" : PauseForKey() : RETURN
  AskFileMetadata()
  ' Move the staged payload to the area derived from the encoded name.
  Target$ = NewName$
  Value = FileStorageArea(NewName$)
  Status = ResolveFileArea(Value)
  IF Status <> 1 THEN Status = AreaError : ShowError() : RETURN
  S$ = AreaPath$ : S$ =+ NewName$
  F$ = FileDrive$ : F$ =+ OldName$
  IF F$ <> S$
    T$ = F$
    F$ = S$
    IF FileExists() THEN PRINT "TARGET FILE ALREADY EXISTS" : PauseForKey() : RETURN
    F$ = T$
    IF F$[1, LEN(F$) - LEN(OldName$)] = S$[1, LEN(S$) - LEN(NewName$)]
      MoveFile()
    ELSE
      CopyFileVerified()
      IF Status = 1 THEN XIO 33, #1, 0, 0, F$
    ENDIF
    IF Status <> 1 THEN ShowError() : RETURN
  ENDIF
  PRINT "DESCRIPTION (70 CHARACTERS) >";
  INPUT ; Desc$
  IF Desc$ = "" THEN Desc$ = "No description available."
  Desc$ = Desc$[1, 70]
  Target$ = NewName$
  CatalogRewrite(0)
  IF Status = 1 THEN PRINT "FILE ADDED AS "; NewName$ ELSE ShowError()
  PauseForKey()
ENDFUNC

FUNC EditControlledFile()
  LOCAL P
  CLS
  PRINT "CONTROLLED NAME.CTL >";
  INPUT ; Target$
  Target$ = UCASE$(Target$)
  IF NOT ValidControlled() OR NOT ControlledExists() THEN PRINT "FILE NOT FOUND" : PauseForKey() : RETURN
  OldName$ = Target$
  CatalogFind()
  P = INSTR(Target$, ".")
  Name$ = Target$[1, P - 1]
  S$ = Target$[P + 1, 1]
  T$ = Target$[P + 2, 1]
  UserLevel = VAL(Target$[P + 3, 1])
  PRINT "NAME: "; Name$; "  NEW, RETURN=KEEP >";
  INPUT ; In$
  IF In$ <> "" THEN Name$ = UCASE$(In$)
  IF NOT ValidStem() THEN PRINT "BAD NAME" : PauseForKey() : RETURN
  PRINT "CATEGORY "; S$; "  NEW, RETURN=KEEP >";
  INPUT ; In$
  In$ = UCASE$(In$)
  IF In$ <> "" THEN S$ = In$
  IF LEN(S$) <> 1 OR INSTR("GATRU", S$) = 0 THEN PRINT "BAD CATEGORY" : PauseForKey() : RETURN
  PRINT "TYPE "; T$; "  NEW, RETURN=KEEP >";
  INPUT ; In$
  In$ = UCASE$(In$)
  IF In$ <> "" THEN T$ = In$
  IF LEN(T$) <> 1 OR INSTR("CEXBTU", T$) = 0 THEN PRINT "BAD TYPE" : PauseForKey() : RETURN
  UserLevel = AskNumber(UserLevel, 1, 9)
  NewName$ = Name$ : NewName$ =+ "." : NewName$ =+ S$ : NewName$ =+ T$ : NewName$ =+ STR$(UserLevel)
  PRINT "DESCRIPTION: "; Desc$
  PRINT "NEW DESCRIPTION, RETURN=KEEP >";
  INPUT ; In$
  IF In$ <> "" THEN Desc$ = In$[1, 70]
  IF OldName$ <> NewName$
    Target$ = NewName$
    IF ControlledExists() THEN PRINT "TARGET FILE EXISTS" : PauseForKey() : RETURN
    RenameControlledFile()
    IF Status <> 1 THEN ShowError() : RETURN
  ENDIF
  Target$ = OldName$
  CatalogRewrite(0)
  IF Status = 1 AND OldName$ <> NewName$
    Value = FileStorageArea(OldName$)
    IF ResolveFileArea(Value) = 1
      F$ = AreaPath$ : F$ =+ OldName$
      XIO 33, #1, 0, 0, F$
    ENDIF
  ELIF Status <> 1 AND OldName$ <> NewName$
    RollbackControlledRename()
  ENDIF
  IF Status = 1 THEN PRINT "FILE ENTRY UPDATED" ELSE ShowError()
  PauseForKey()
ENDFUNC

FUNC RemoveControlledFile()
  CLS
  PRINT "CONTROLLED NAME.CTL >";
  INPUT ; Target$
  Target$ = UCASE$(Target$)
  IF NOT ValidControlled() OR NOT ControlledExists() THEN PRINT "FILE NOT FOUND" : PauseForKey() : RETURN
  PRINT "DELETE "; Target$; " (Y/N) >";
  IF NOT AskYes() THEN RETURN
  Value = FileStorageArea(Target$)
  IF ResolveFileArea(Value) <> 1 THEN Status = AreaError : ShowError() : RETURN
  F$ = AreaPath$ : F$ =+ Target$
  XIO 33, #1, 0, 0, F$
  Status = ERR()
  IF Status <> 1 THEN ShowError() : RETURN
  NewName$ = ""
  CatalogRewrite(1)
  IF Status = 1 THEN PRINT "FILE REMOVED" ELSE ShowError()
  PauseForKey()
ENDFUNC
