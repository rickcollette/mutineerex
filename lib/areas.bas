' ====================================================================
' Per-area storage registry
' ====================================================================
' D1:AREAS.CFG is deliberately fixed so the BBS can find its storage
' map before any configurable drive is available.  A missing registry
' means legacy mode; a malformed registry is an error unless AREAS.BAK
' is valid.

DIM AreaPath$, AreaLine$
DIM AreaLevel, AreaError, AreaKind
DIM AreaSeen(25) BYTE

FUNC NormalizeAreaPath()
  LOCAL I, C, Start, Dot, Stem, Ext
  AreaPath$ = UCASE$(AreaPath$)
  IF LEN(AreaPath$) < 3 OR LEN(AreaPath$) > 30 THEN RETURN 0
  IF AreaPath$[1, 1] <> "D" THEN RETURN 0
  C = PEEK(ADR(AreaPath$) + 2)
  IF C < 49 OR C > 56 OR AreaPath$[3, 1] <> ":" THEN RETURN 0
  FOR I = 4 TO LEN(AreaPath$)
    C = PEEK(ADR(AreaPath$) + I)
    IF C = 92 OR C = 47 THEN POKE ADR(AreaPath$) + I, 62 : C = 62
    IF C = 42 OR C = 63 OR C = 44 OR C < 32 THEN RETURN 0
  NEXT I
  IF LEN(AreaPath$) = 3 THEN RETURN 1
  IF AreaPath$[4, 1] = ">" THEN RETURN 0
  IF AreaPath$[LEN(AreaPath$), 1] <> ">" THEN AreaPath$ =+ ">"
  IF LEN(AreaPath$) > 30 THEN RETURN 0
  Start = 4
  FOR I = 4 TO LEN(AreaPath$)
    IF PEEK(ADR(AreaPath$) + I) = 62
      IF I = Start THEN RETURN 0
      Dot = 0 : Stem = 0 : Ext = 0
      FOR C = Start TO I - 1
        IF PEEK(ADR(AreaPath$) + C) = 46
          IF Dot OR Stem = 0 THEN RETURN 0
          Dot = 1
        ELSE
          IF NOT ((PEEK(ADR(AreaPath$) + C) >= 65 AND PEEK(ADR(AreaPath$) + C) <= 90) OR (PEEK(ADR(AreaPath$) + C) >= 48 AND PEEK(ADR(AreaPath$) + C) <= 57) OR PEEK(ADR(AreaPath$) + C) = 95 OR PEEK(ADR(AreaPath$) + C) = 45) THEN RETURN 0
          IF Dot THEN INC Ext ELSE INC Stem
        ENDIF
      NEXT C
      IF Stem < 1 OR Stem > 8 OR Ext > 3 THEN RETURN 0
      IF Dot AND Ext = 0 THEN RETURN 0
      Start = I + 1
    ENDIF
  NEXT I
  RETURN 1
ENDFUNC

FUNC ParseAreaRecord()
  LOCAL P
  AreaKind = 0
  IF LEN(AreaLine$) < 6 OR AreaLine$[2, 1] <> "|" THEN RETURN 0
  IF AreaLine$[1, 1] = "F"
    IF AreaLine$[4, 1] <> "|" THEN RETURN 0
    AreaKind = PEEK(ADR(AreaLine$) + 3) - 48
    IF AreaKind < 0 OR AreaKind > 5 THEN RETURN 0
    AreaPath$ = AreaLine$[5]
    IF NOT NormalizeAreaPath() THEN RETURN 0
    IF AreaLine$[5] <> AreaPath$ THEN RETURN 0
    RETURN 1
  ENDIF
  IF AreaLine$[1, 1] <> "M" OR LEN(AreaLine$) < 8 THEN RETURN 0
  AreaKind = PEEK(ADR(AreaLine$) + 3) - 65
  IF AreaKind < 0 OR AreaKind > 25 OR AreaLine$[4, 1] <> "|" OR AreaLine$[6, 1] <> "|" THEN RETURN 0
  AreaLevel = PEEK(ADR(AreaLine$) + 5) - 48
  IF AreaLevel < 1 OR AreaLevel > 9 THEN RETURN 0
  AreaPath$ = AreaLine$[7]
  IF NOT NormalizeAreaPath() THEN RETURN 0
  IF AreaLine$[7] <> AreaPath$ THEN RETURN 0
  AreaKind = AreaKind + 6
  RETURN 1
ENDFUNC

' Which=1 validates AREAS.CFG, Which=2 validates AREAS.BAK, and Which=3
' validates the completed replacement file.
' Returns 1 valid, 0 absent, -1 malformed/unreadable.
FUNC ValidateAreaRegistry(Which)
  LOCAL Code, Mask, I
  FOR I = 0 TO 25
    AreaSeen(I) = 0
  NEXT I
  CLOSE #6
  IF Which = 1
    OPEN #6, 4, 0, "D1:AREAS.CFG"
  ELIF Which = 2
    OPEN #6, 4, 0, "D1:AREAS.BAK"
  ELSE
    OPEN #6, 4, 0, "D1:AREAS.NEW"
  ENDIF
  Code = ERR()
  IF Code = 170 THEN CLOSE #6 : RETURN 0
  IF Code <> 1 THEN CLOSE #6 : AreaError = Code : RETURN -1
  INPUT #6, AreaLine$
  Code = ERR()
  IF Code <> 1 OR AreaLine$ <> "MUTINREX AREAS 1" THEN CLOSE #6 : AreaError = 18 : RETURN -1
  Mask = 0
  DO
    INPUT #6, AreaLine$
    Code = ERR()
    IF Code <> 1 THEN EXIT
    IF NOT ParseAreaRecord() THEN CLOSE #6 : AreaError = 18 : RETURN -1
    IF AreaKind < 6
      I = 1
      FOR Code = 1 TO AreaKind
        I = I * 2
      NEXT Code
      IF Mask & I THEN CLOSE #6 : AreaError = 18 : RETURN -1
      Mask = Mask + I
    ELSE
      I = AreaKind - 6
      IF AreaSeen(I) THEN CLOSE #6 : AreaError = 18 : RETURN -1
      AreaSeen(I) = 1
    ENDIF
  LOOP
  CLOSE #6
  IF Code <> 136 OR Mask <> 63 THEN AreaError = 18 : RETURN -1
  RETURN 1
ENDFUNC

' Returns 0 for legacy mode, 1 for live registry, 2 for backup, -1 error.
FUNC FindAreaRegistry()
  LOCAL Live, Backup
  Live = ValidateAreaRegistry(1)
  IF Live = 1 THEN RETURN 1
  Backup = ValidateAreaRegistry(2)
  IF Backup = 1 THEN RETURN 2
  IF Live = 0 AND Backup = 0 THEN RETURN 0
  IF AreaError = 0 THEN AreaError = 18
  RETURN -1
ENDFUNC

FUNC OpenAreaRegistry(Which)
  CLOSE #6
  IF Which = 1
    OPEN #6, 4, 0, "D1:AREAS.CFG"
  ELSE
    OPEN #6, 4, 0, "D1:AREAS.BAK"
  ENDIF
  INPUT #6, AreaLine$
ENDFUNC

' Returns 1 with AreaPath$, or -1 for a configuration error.
FUNC ResolveFileArea(N)
  LOCAL R
  IF N < 0 OR N > 5 THEN AreaError = 18 : RETURN -1
  R = FindAreaRegistry()
  IF R < 0 THEN RETURN -1
  IF R = 0
    AreaPath$ = FileDrive$
    IF NormalizeAreaPath() THEN RETURN 1
    AreaError = 18 : RETURN -1
  ENDIF
  OpenAreaRegistry(R)
  DO
    INPUT #6, AreaLine$
    IF ERR() <> 1 THEN EXIT
    IF AreaLine$[1, 1] = "F" AND PEEK(ADR(AreaLine$) + 3) - 48 = N
      ParseAreaRecord()
      CLOSE #6
      RETURN 1
    ENDIF
  LOOP
  CLOSE #6
  AreaError = 18
  RETURN -1
ENDFUNC

' Returns 1 with AreaPath$/AreaLevel, 0 if the base does not exist,
' or -1 for a configuration error.
FUNC ResolveMessageArea(N)
  LOCAL R, L
  IF N < 0 OR N > 25 THEN AreaError = 18 : RETURN -1
  R = FindAreaRegistry()
  IF R < 0 THEN RETURN -1
  IF R = 0
    AreaPath$ = MsgDrive$
    IF NOT NormalizeAreaPath() THEN AreaError = 18 : RETURN -1
    FOR L = 1 TO 9
      AreaLine$ = AreaPath$ : AreaLine$ =+ "MESSAGE.M" : AreaLine$ =+ CHR$(65 + N) : AreaLine$ =+ STR$(L)
      CLOSE #6
      OPEN #6, 4, 0, AreaLine$
      IF ERR() = 1 THEN CLOSE #6 : AreaLevel = L : RETURN 1
      CLOSE #6
    NEXT L
    RETURN 0
  ENDIF
  OpenAreaRegistry(R)
  DO
    INPUT #6, AreaLine$
    IF ERR() <> 1 THEN EXIT
    IF AreaLine$[1, 1] = "M" AND PEEK(ADR(AreaLine$) + 3) - 65 = N
      ParseAreaRecord()
      CLOSE #6
      AreaKind = AreaKind - 6
      RETURN 1
    ENDIF
  LOOP
  CLOSE #6
  RETURN 0
ENDFUNC

' Text owns its own area.  Every other controlled file is routed by its
' category byte.  Returns -1 for a malformed controlled filename.
FUNC FileStorageArea(Name$)
  LOCAL P, C
  P = INSTR(Name$, ".")
  IF P < 2 OR P + 3 <> LEN(Name$) THEN RETURN -1
  IF PEEK(ADR(Name$) + P + 2) = 84 THEN RETURN 0
  C = PEEK(ADR(Name$) + P + 1)
  IF C = 71 THEN RETURN 1
  IF C = 65 THEN RETURN 2
  IF C = 84 THEN RETURN 3
  IF C = 82 THEN RETURN 4
  IF C = 85 THEN RETURN 5
  RETURN -1
ENDFUNC

' Changes AreaLine$ from a full path to its final 8.3 name.
FUNC AreaBasename()
  LOCAL I, P, C
  P = 3
  FOR I = 4 TO LEN(AreaLine$)
    C = PEEK(ADR(AreaLine$) + I)
    IF C = 58 OR C = 62 OR C = 92 OR C = 47 THEN P = I
  NEXT I
  IF P < LEN(AreaLine$) THEN AreaLine$ = AreaLine$[P + 1] ELSE AreaLine$ = ""
ENDFUNC

' Creates every missing directory component with the SDX-compatible
' XIO 42 command implemented by both exOS and SpartaDOS X.
FUNC EnsureAreaFolder()
  LOCAL I, Code
  IF NOT NormalizeAreaPath() THEN AreaError = 18 : RETURN 0
  IF LEN(AreaPath$) > 3
    FOR I = 4 TO LEN(AreaPath$)
      IF PEEK(ADR(AreaPath$) + I) = 62
        AreaLine$ = AreaPath$[1, I - 1]
        XIO 42, #6, 0, 0, AreaLine$
      ENDIF
    NEXT I
  ENDIF
  AreaLine$ = AreaPath$ : AreaLine$ =+ "*.*"
  CLOSE #6
  OPEN #6, 6, 0, AreaLine$
  Code = ERR()
  CLOSE #6
  IF Code <> 1 THEN AreaError = Code : RETURN 0
  RETURN 1
ENDFUNC
