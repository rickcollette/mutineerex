' ====================================================================
' Offline user editor.  Level 0 is a disabled/banned account.
' ====================================================================

FUNC UserEditor()
  DO
    CLS
    PRINT "         USER EDITOR"
    PRINT "         -----------"
    PRINT " L LIST USERS"
    PRINT " N NEW USER"
    PRINT " E EDIT USER"
    PRINT " A APPROVE USER (LEVEL 1)"
    PRINT " B BAN USER (LEVEL 0)"
    PRINT " R REMOVE USER"
    PRINT " X BACK"
    PRINT
    INPUT "CHOICE >"; In$
    In$ = UCASE$(In$)
    IF In$ = "L"
      ListConfigUsers()
    ELIF In$ = "N"
      AddConfigUser()
    ELIF In$ = "E"
      EditConfigUser()
    ELIF In$ = "A"
      SetConfigUserAccess(1)
    ELIF In$ = "B"
      SetConfigUserAccess(0)
    ELIF In$ = "R"
      RemoveConfigUser()
    ELIF In$ = "X"
      RETURN
    ENDIF
  LOOP
ENDFUNC

FUNC ConfigUserExists(CheckName$)
  LOCAL Code
  F$ = DataDrive$ : F$ =+ "USERS.DAT"
  CLOSE #1
  OPEN #1, 4, 0, F$
  IF ERR() <> 1 THEN RETURN 0
  DO
    INPUT #1, S$
    Code = ERR()
    IF Code <> 1
      IF Code <> 136 THEN Status = Code
      EXIT
    ENDIF
    IF S$ = "*" THEN EXIT
    INPUT #1, T$
    INPUT #1, In$
    IF UCASE$(S$) = UCASE$(CheckName$) THEN CLOSE #1 : RETURN 1
  LOOP
  CLOSE #1
  RETURN 0
ENDFUNC

' Loads Target$ into the editor fields.  Value is the one-based record.
FUNC FindConfigUser()
  LOCAL Code, P
  Found = 0 : Value = 0
  F$ = DataDrive$ : F$ =+ "USERS.DAT"
  CLOSE #1
  OPEN #1, 4, 0, F$
  IF ERR() <> 1 THEN RETURN
  DO
    INPUT #1, S$
    Code = ERR()
    IF Code <> 1 THEN EXIT
    IF S$ = "*" THEN EXIT
    INC Value
    INPUT #1, T$
    IF ERR() <> 1 THEN EXIT
    INPUT #1, In$
    IF ERR() <> 1 THEN EXIT
    IF UCASE$(S$) = UCASE$(Target$)
      Name$ = S$[1, 40]
      City$ = T$[1, 40]
      P = INSTR(In$, ",")
      IF P = 5
        Pass$ = In$[1, 4]
        UserLevel = VAL(In$[6])
        Found = 1
      ENDIF
      EXIT
    ENDIF
  LOOP
  CLOSE #1
ENDFUNC

FUNC CountConfigUsers()
  LOCAL Code
  Count = 0
  F$ = DataDrive$ : F$ =+ "USERS.DAT"
  CLOSE #1
  OPEN #1, 4, 0, F$
  IF ERR() <> 1 THEN RETURN
  DO
    INPUT #1, S$
    Code = ERR()
    IF Code <> 1 THEN EXIT
    IF S$ = "*" THEN EXIT
    INPUT #1, T$
    INPUT #1, In$
    INC Count
  LOOP
  CLOSE #1
ENDFUNC

FUNC ListConfigUsers()
  LOCAL Code, P, L
  CLS
  PRINT "LV USER / CITY"
  PRINT "-- -------------------------------------"
  F$ = DataDrive$ : F$ =+ "USERS.DAT"
  CLOSE #1
  OPEN #1, 4, 0, F$
  IF ERR() <> 1 THEN PRINT "NO USER DATABASE" : PauseForKey() : RETURN
  Count = 0
  DO
    INPUT #1, S$
    Code = ERR()
    IF Code <> 1 THEN EXIT
    IF S$ = "*" THEN EXIT
    INPUT #1, T$
    INPUT #1, In$
    P = INSTR(In$, ",")
    L = -1
    IF P = 5 THEN L = VAL(In$[6])
    IF L = 0
      PRINT "B  "; S$
    ELSE
      PRINT L; "  "; S$
    ENDIF
    PRINT "   "; T$
    INC Count
  LOOP
  CLOSE #1
  IF Count = 0 THEN PRINT "NO USERS"
  PauseForKey()
ENDFUNC

FUNC AskUserFields()
  DO
    PRINT "NAME (3-40 CHARACTERS) >";
    INPUT ; Name$
  LOOP UNTIL LEN(Name$) >= 3 AND LEN(Name$) <= 40
  DO
    PRINT "CITY/STATE (3-40 CHARACTERS) >";
    INPUT ; City$
  LOOP UNTIL LEN(City$) >= 3 AND LEN(City$) <= 40
  DO
    PRINT "PASSWORD (4 CHARACTERS) >";
    INPUT ; Pass$
    Pass$ = UCASE$(Pass$)
  LOOP UNTIL LEN(Pass$) = 4
  UserLevel = AskNumber(1, 0, 9)
ENDFUNC

FUNC AddConfigUser()
  CLS
  AskUserFields()
  IF ConfigUserExists(Name$)
    PRINT "USER ALREADY EXISTS" : PauseForKey() : RETURN
  ENDIF
  CountConfigUsers()
  IF Count = 0 OR UCASE$(Name$) = UCASE$(SysopName$) THEN UserLevel = 9
  F$ = DataDrive$ : F$ =+ "USERS.DAT"
  CLOSE #1
  OPEN #1, 12, 0, F$
  IF ERR() = 170
    CLOSE #1
    OPEN #1, 8, 0, F$
    CLOSE #1
    OPEN #1, 12, 0, F$
  ENDIF
  Status = ERR()
  IF Status = 1
    DO
      NOTE #1, CSect, CByte
      INPUT #1, S$
      Status = ERR()
      IF Status <> 1 OR S$ = "*" THEN EXIT
      INPUT #1, T$
      INPUT #1, In$
    LOOP
    POINT #1, CSect, CByte
    PRINT #1; Name$
    PRINT #1; City$
    PRINT #1; Pass$; ","; UserLevel
    PRINT #1; "*"
    Status = ERR()
  ENDIF
  CLOSE #1
  IF Status = 1 THEN PRINT "USER CREATED AT LEVEL "; UserLevel ELSE ShowError()
  PauseForKey()
ENDFUNC

' Target$ identifies the old record. NewName$/City$/Pass$/UserLevel are
' the replacement fields. DeleteFlag skips the matching record.  The new
' records are streamed through USERS.TMP, then copied over USERS.DAT in
' update mode so INIT's preallocated database space is retained.
FUNC RewriteConfigUser(DeleteFlag)
  LOCAL Code, P
  F$ = DataDrive$ : F$ =+ "USERS.DAT"
  BaseDesc$ = DataDrive$ : BaseDesc$ =+ "USERS.TMP"
  XIO 33, #2, 0, 0, BaseDesc$
  CLOSE #2
  OPEN #2, 8, 0, BaseDesc$
  Status = ERR()
  IF Status <> 1 THEN RETURN
  CLOSE #1
  OPEN #1, 4, 0, F$
  Status = ERR() : Found = 0
  IF Status <> 1 THEN CLOSE #2 : RETURN
  DO
    INPUT #1, S$
    Code = ERR()
    IF Code <> 1 THEN EXIT
    IF S$ = "*" THEN EXIT
    INPUT #1, T$
    IF ERR() <> 1 THEN Status = ERR() : EXIT
    Desc$ = T$
    INPUT #1, In$
    IF ERR() <> 1 THEN Status = ERR() : EXIT
    IF UCASE$(S$) = UCASE$(Target$)
      Found = 1
      IF NOT DeleteFlag
        PRINT #2; NewName$
        PRINT #2; City$
        T$ = Pass$ : T$ =+ "," : T$ =+ STR$(UserLevel)
        PRINT #2; T$
        Status = ERR()
      ENDIF
    ELSE
      PRINT #2; S$
      PRINT #2; Desc$
      PRINT #2; In$
      Status = ERR()
    ENDIF
    IF Status <> 1 THEN EXIT
  LOOP
  CLOSE #1
  IF Status = 136 THEN Status = 1
  IF Status = 1 AND Found
    PRINT #2; "*"
    Status = ERR()
  ENDIF
  CLOSE #2
  IF Status <> 1 OR NOT Found
    XIO 33, #1, 0, 0, BaseDesc$
    RETURN
  ENDIF

  CLOSE #1
  OPEN #1, 4, 0, BaseDesc$
  Status = ERR()
  IF Status <> 1 THEN RETURN
  CLOSE #2
  OPEN #2, 12, 0, F$
  Status = ERR()
  IF Status <> 1 THEN CLOSE #1 : RETURN
  DO
    INPUT #1, T$
    Code = ERR()
    IF Code <> 1 THEN Status = Code : EXIT
    PRINT #2; T$
    Status = ERR()
    IF Status <> 1 OR T$ = "*" THEN EXIT
  LOOP
  CLOSE #1
  CLOSE #2
  IF Status = 1 THEN XIO 33, #1, 0, 0, BaseDesc$
ENDFUNC

FUNC EditConfigUser()
  CLS
  PRINT "USER NAME >";
  INPUT ; Target$
  IF Target$ = "" THEN RETURN
  FindConfigUser()
  IF NOT Found THEN PRINT "USER NOT FOUND" : PauseForKey() : RETURN
  Count = Value
  OldName$ = Name$
  PRINT "NAME: "; Name$
  PRINT "NEW NAME, RETURN=KEEP >";
  INPUT ; In$
  NewName$ = Name$
  IF In$ <> "" THEN NewName$ = In$[1, 40]
  IF LEN(NewName$) < 3 THEN PRINT "BAD NAME" : PauseForKey() : RETURN
  IF UCASE$(NewName$) <> UCASE$(OldName$) AND ConfigUserExists(NewName$)
    PRINT "THAT USER ALREADY EXISTS" : PauseForKey() : RETURN
  ENDIF
  PRINT "CITY: "; City$
  PRINT "NEW CITY, RETURN=KEEP >";
  INPUT ; In$
  IF In$ <> "" THEN City$ = In$[1, 40]
  PRINT "PASSWORD: "; Pass$
  PRINT "NEW 4 CHAR PASSWORD, RETURN=KEEP >";
  INPUT ; In$
  IF In$ <> ""
    IF LEN(In$) <> 4 THEN PRINT "BAD PASSWORD" : PauseForKey() : RETURN
    Pass$ = UCASE$(In$)
  ENDIF
  UserLevel = AskNumber(UserLevel, 0, 9)
  IF Count = 1 OR UCASE$(OldName$) = UCASE$(SysopName$) OR UCASE$(NewName$) = UCASE$(SysopName$) THEN UserLevel = 9
  Target$ = OldName$
  RewriteConfigUser(0)
  IF Status = 1 THEN PRINT "USER UPDATED" ELSE ShowError()
  PauseForKey()
ENDFUNC

FUNC SetConfigUserAccess(NewLevel)
  CLS
  PRINT "USER NAME >";
  INPUT ; Target$
  IF Target$ = "" THEN RETURN
  FindConfigUser()
  IF NOT Found THEN PRINT "USER NOT FOUND" : PauseForKey() : RETURN
  IF NewLevel = 0 AND (Value = 1 OR UCASE$(Name$) = UCASE$(SysopName$))
    PRINT "THE SYSOP CANNOT BE BANNED" : PauseForKey() : RETURN
  ENDIF
  NewName$ = Name$
  UserLevel = NewLevel
  IF Value = 1 OR UCASE$(Name$) = UCASE$(SysopName$) THEN UserLevel = 9
  Target$ = Name$
  RewriteConfigUser(0)
  IF Status = 1
    IF UserLevel = 0 THEN PRINT "USER BANNED" ELSE PRINT "USER APPROVED AT LEVEL "; UserLevel
  ELSE
    ShowError()
  ENDIF
  PauseForKey()
ENDFUNC

FUNC RemoveConfigUser()
  CLS
  PRINT "USER NAME >";
  INPUT ; Target$
  IF Target$ = "" THEN RETURN
  FindConfigUser()
  IF NOT Found THEN PRINT "USER NOT FOUND" : PauseForKey() : RETURN
  IF Value = 1 OR UCASE$(Name$) = UCASE$(SysopName$)
    PRINT "THE SYSOP CANNOT BE REMOVED" : PauseForKey() : RETURN
  ENDIF
  PRINT "REMOVE "; Name$; " (Y/N) >";
  IF NOT AskYes() THEN RETURN
  Target$ = Name$
  RewriteConfigUser(1)
  IF Status = 1 THEN PRINT "USER REMOVED" ELSE ShowError()
  PauseForKey()
ENDFUNC
