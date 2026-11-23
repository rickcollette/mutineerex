' ====================================================================
' Download file-area manager
' ====================================================================

FUNC FileAreaManager()
  DO
    CLS
    PRINT "         FILE AREAS"
    PRINT "         ----------"
    PRINT " L LIST CONTROLLED FILES"
    PRINT " A ADD COPIED FILE"
    PRINT " E EDIT FILE ENTRY"
    PRINT " R REMOVE FILE"
    PRINT " X BACK"
    PRINT
    INPUT "CHOICE >"; In$
    In$ = UCASE$(In$)
    IF In$ = "L"
      ListControlledFiles()
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
  F$ = FileDrive$ : F$ =+ Target$
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
  T$ = FileDrive$ : T$ =+ "FILES.BAK"
  XIO 33, #1, 0, 0, T$
  In$ = F$ : In$ =+ ",FILES.BAK"
  XIO 32, #1, 0, 0, In$
  Code = ERR()
  IF Code <> 1 AND Code <> 170 THEN Status = Code : RETURN
  In$ = S$ : In$ =+ ",FILES.DAT"
  XIO 32, #1, 0, 0, In$
  Status = ERR()
  IF Status <> 1 AND Code = 1
    In$ = T$ : In$ =+ ",FILES.DAT"
    XIO 32, #1, 0, 0, In$
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
  LOCAL C, Y, L, I
  CLS
  PRINT "CONTROLLED DOWNLOADS ON "; FileDrive$
  PRINT
  F$ = FileDrive$ : F$ =+ "*.???"
  CLOSE #1
  OPEN #1, 6, 0, F$
  IF ERR() <> 1 THEN PRINT "CANNOT READ DIRECTORY" : PauseForKey() : RETURN
  Count = 0
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
        CatalogFind()
        PRINT Target$; " "; CategoryName$(C); " L"; L
        PRINT "  "; Desc$
        INC Count
      ENDIF
    ENDIF
  LOOP
  CLOSE #1
  IF Count = 0 THEN PRINT "NO CONTROLLED FILES"
  PauseForKey()
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
  F$ = FileDrive$ : F$ =+ OldName$
  S$ = F$ : S$ =+ "," : S$ =+ NewName$
  XIO 32, #1, 0, 0, S$
  Status = ERR()
ENDFUNC

FUNC AddControlledFile()
  CLS
  PRINT "COPY THE FILE TO "; FileDrive$
  PRINT "BEFORE ADDING IT HERE."
  PRINT "CURRENT DISK NAME >";
  INPUT ; OldName$
  OldName$ = UCASE$(OldName$)
  IF OldName$ = "" THEN RETURN
  F$ = FileDrive$ : F$ =+ OldName$
  IF NOT FileExists() THEN PRINT "FILE NOT FOUND" : PauseForKey() : RETURN
  AskFileMetadata()
  Target$ = NewName$
  IF OldName$ <> NewName$ AND ControlledExists()
    PRINT "TARGET FILE ALREADY EXISTS" : PauseForKey() : RETURN
  ENDIF
  IF OldName$ <> NewName$
    RenameControlledFile()
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
  F$ = FileDrive$ : F$ =+ Target$
  XIO 33, #1, 0, 0, F$
  Status = ERR()
  IF Status <> 1 THEN ShowError() : RETURN
  NewName$ = ""
  CatalogRewrite(1)
  IF Status = 1 THEN PRINT "FILE REMOVED" ELSE ShowError()
  PauseForKey()
ENDFUNC
