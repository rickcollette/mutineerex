' DOORS - catalog-driven external program launcher. X returns to MAINBBS.
' DOORS.DAT records are KEY|LEVEL|NAME|PATH, one record per ATASCII line.

FUNC ParseDoor()
  Q1 = INSTR(S$, "|")
  IF Q1 <> 2 THEN RETURN 0
  Marker$ = UCASE$(S$[1, 1])
  T$ = S$[Q1 + 1, 255]
  Q1 = INSTR(T$, "|")
  IF Q1 < 2 THEN RETURN 0
  FileCategory = VAL(T$[1, Q1 - 1])
  IF FileCategory < 1 OR FileCategory > 9 THEN RETURN 0
  T$ = T$[Q1 + 1, 255]
  Q1 = INSTR(T$, "|")
  IF Q1 < 2 THEN RETURN 0
  BaseName$ = T$[1, Q1 - 1]
  Spec$ = T$[Q1 + 1, 255]
  IF BaseName$ = "" OR Spec$ = "" THEN RETURN 0
  RETURN 1
ENDFUNC

FUNC OpenDoorCatalog()
  FileName$ = DataDrive$ : FileName$ =+ "DOORS.DAT"
  CLOSE #FileCh
  OPEN #FileCh, 4, 0, FileName$
  RETURN ERR()
ENDFUNC

FUNC ShowDoors()
  LOCAL Code, Count
  PRINT #ModemCh,
  PRINT #ModemCh; ".oO-[ Mutineer-eX 1.0.6 DOORS ]-Oo."
  PRINT #ModemCh; ".o  KEY  DOOR                    o."
  PRINT #ModemCh; ".oO----------------------------Oo."
  Code = OpenDoorCatalog()
  IF Code <> 1
    PRINT #ModemCh; "NO DOORS ARE CONFIGURED."
    CLOSE #FileCh
    RETURN
  ENDIF
  DO
    INPUT #FileCh, S$
    Code = ERR()
    IF Code <> 1 THEN EXIT
    IF ParseDoor() AND FileCategory <= UserLevel
      PRINT #ModemCh; " ["; Marker$; "] "; BaseName$[1, 29]
      INC Count
    ENDIF
  LOOP
  CLOSE #FileCh
  IF Count = 0 THEN PRINT #ModemCh; "NO DOORS AVAILABLE AT YOUR LEVEL."
  PRINT #ModemCh; " [X] MAIN BBS              [?] LIST"
ENDFUNC

FUNC FindDoor(Key$)
  LOCAL Code
  Code = OpenDoorCatalog()
  IF Code <> 1 THEN CLOSE #FileCh : RETURN 0
  DO
    INPUT #FileCh, S$
    Code = ERR()
    IF Code <> 1 THEN EXIT
    IF ParseDoor() AND Marker$ = Key$
      CLOSE #FileCh
      IF FileCategory > UserLevel THEN RETURN -1
      RETURN 1
    ENDIF
  LOOP
  CLOSE #FileCh
  RETURN 0
ENDFUNC

FUNC ResolveDoorPath()
  FileName$ = Spec$
  IF INSTR(FileName$, ":") = 0 THEN FileName$ = "D1:" : FileName$ =+ Spec$
  Q1 = ResolveCachePath()
  RETURN 1
ENDFUNC

FUNC LaunchDoor()
  LOCAL Code
  ResolveDoorPath()
  CLOSE #FileCh
  OPEN #FileCh, 4, 0, FileName$
  Code = ERR()
  CLOSE #FileCh
  IF Code <> 1
    PRINT #ModemCh; "DOOR FILE NOT FOUND: "; FileName$
    RETURN
  ENDIF
  RunModule(FileName$, 7, BaseName$)
ENDFUNC

FUNC DoorLoop()
  LOCAL Found
  ShowDoors()
  DO
    IF Lost OR Bye THEN RETURN
    OpenModem()
    PRINT #ModemCh; "DOOR >";
    IF NOT LocalMode THEN PRINT : PRINT "DOOR >";
    Il = 8
    GLine()
    IF L$ <> ""
      Marker$ = UCASE$(L$[1, 1])
      IF Marker$ = "X" THEN RETURN
      IF Marker$ = "?"
        ShowDoors()
      ELSE
        Found = FindDoor(Marker$)
        IF Found = 1
          LaunchDoor()
        ELIF Found = -1
          PRINT #ModemCh; "ACCESS DENIED."
        ELSE
          PRINT #ModemCh; "NO SUCH DOOR. TYPE ? FOR LIST."
        ENDIF
      ENDIF
    ENDIF
  LOOP
ENDFUNC
