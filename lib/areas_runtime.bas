' Compact read-only AREAS.CFG resolver for the live BBS and RDCONF.
' It deliberately reuses the modules' Q1-Q6 work integers so adding area
' routing does not push the exBASIC variable table past its 512-byte limit.

DIM AreaPath$, AreaLine$
DIM AreaLevel, AreaError
DIM AreaMaskF

FUNC NormalizeAreaPath()
  AreaPath$ = UCASE$(AreaPath$)
  IF LEN(AreaPath$) < 3 OR LEN(AreaPath$) > 30 THEN RETURN 0
  IF AreaPath$[1, 1] <> "D" THEN RETURN 0
  Q1 = PEEK(ADR(AreaPath$) + 2)
  IF Q1 < 49 OR Q1 > 56 OR AreaPath$[3, 1] <> ":" THEN RETURN 0
  FOR Q1 = 4 TO LEN(AreaPath$)
    Q2 = PEEK(ADR(AreaPath$) + Q1)
    IF Q2 = 92 OR Q2 = 47 THEN POKE ADR(AreaPath$) + Q1, 62 : Q2 = 62
    IF Q2 = 42 OR Q2 = 63 OR Q2 = 44 OR Q2 < 32 THEN RETURN 0
  NEXT Q1
  IF LEN(AreaPath$) = 3 THEN RETURN 1
  IF AreaPath$[4, 1] = ">" THEN RETURN 0
  IF AreaPath$[LEN(AreaPath$), 1] <> ">" THEN AreaPath$ =+ ">"
  IF LEN(AreaPath$) > 30 THEN RETURN 0
  Q3 = 4
  FOR Q1 = 4 TO LEN(AreaPath$)
    IF PEEK(ADR(AreaPath$) + Q1) = 62
      IF Q1 = Q3 THEN RETURN 0
      Q4 = 0 : Q5 = 0 : Q6 = 0
      FOR Q2 = Q3 TO Q1 - 1
        IF PEEK(ADR(AreaPath$) + Q2) = 46
          IF Q4 OR Q5 = 0 THEN RETURN 0
          Q4 = 1
        ELSE
          IF NOT ((PEEK(ADR(AreaPath$) + Q2) >= 65 AND PEEK(ADR(AreaPath$) + Q2) <= 90) OR (PEEK(ADR(AreaPath$) + Q2) >= 48 AND PEEK(ADR(AreaPath$) + Q2) <= 57) OR PEEK(ADR(AreaPath$) + Q2) = 95 OR PEEK(ADR(AreaPath$) + Q2) = 45) THEN RETURN 0
          IF Q4 THEN INC Q6 ELSE INC Q5
        ENDIF
      NEXT Q2
      IF Q5 < 1 OR Q5 > 8 OR Q6 > 3 THEN RETURN 0
      IF Q4 AND Q6 = 0 THEN RETURN 0
      Q3 = Q1 + 1
    ENDIF
  NEXT Q1
  RETURN 1
ENDFUNC

FUNC ParseAreaRecord()
  AreaError = 0
  IF LEN(AreaLine$) < 6 OR AreaLine$[2, 1] <> "|" THEN RETURN 0
  IF AreaLine$[1, 1] = "F"
    IF AreaLine$[4, 1] <> "|" THEN RETURN 0
    AreaError = PEEK(ADR(AreaLine$) + 3) - 48
    IF AreaError < 0 OR AreaError > 5 THEN RETURN 0
    AreaPath$ = AreaLine$[5]
    IF NOT NormalizeAreaPath() THEN RETURN 0
    IF AreaLine$[5] <> AreaPath$ THEN RETURN 0
    RETURN 1
  ENDIF
  IF AreaLine$[1, 1] <> "M" OR LEN(AreaLine$) < 8 THEN RETURN 0
  AreaError = PEEK(ADR(AreaLine$) + 3) - 65
  IF AreaError < 0 OR AreaError > 25 OR AreaLine$[4, 1] <> "|" OR AreaLine$[6, 1] <> "|" THEN RETURN 0
  AreaLevel = PEEK(ADR(AreaLine$) + 5) - 48
  IF AreaLevel < 1 OR AreaLevel > 9 THEN RETURN 0
  AreaPath$ = AreaLine$[7]
  IF NOT NormalizeAreaPath() THEN RETURN 0
  IF AreaLine$[7] <> AreaPath$ THEN RETURN 0
  AreaError = AreaError + 6
  RETURN 1
ENDFUNC

FUNC ValidateAreaRegistry(Which)
  AreaMaskF = 0
  CLOSE #6
  IF Which = 1
    OPEN #6, 4, 0, "D1:AREAS.CFG"
  ELSE
    OPEN #6, 4, 0, "D1:AREAS.BAK"
  ENDIF
  Q1 = ERR()
  IF Q1 = 170 THEN CLOSE #6 : RETURN 0
  IF Q1 <> 1 THEN CLOSE #6 : AreaError = Q1 : RETURN -1
  INPUT #6, AreaLine$
  Q1 = ERR()
  IF Q1 <> 1 OR AreaLine$ <> "MUTINREX AREAS 1" THEN CLOSE #6 : AreaError = 18 : RETURN -1
  DO
    INPUT #6, AreaLine$
    Q1 = ERR()
    IF Q1 <> 1 THEN EXIT
    IF NOT ParseAreaRecord() THEN CLOSE #6 : AreaError = 18 : RETURN -1
    Q2 = 1
    IF AreaError < 6
      FOR Q3 = 1 TO AreaError : Q2 = Q2 * 2 : NEXT Q3
      IF AreaMaskF & Q2 THEN CLOSE #6 : AreaError = 18 : RETURN -1
      AreaMaskF = AreaMaskF + Q2
    ENDIF
  LOOP
  CLOSE #6
  IF Q1 <> 136 OR AreaMaskF <> 63 THEN AreaError = 18 : RETURN -1
  RETURN 1
ENDFUNC

FUNC FindAreaRegistry()
  Q4 = ValidateAreaRegistry(1)
  IF Q4 = 1 THEN RETURN 1
  Q5 = ValidateAreaRegistry(2)
  IF Q5 = 1 THEN RETURN 2
  IF Q4 = 0 AND Q5 = 0 THEN RETURN 0
  IF AreaError = 0 THEN AreaError = 18
  RETURN -1
ENDFUNC

FUNC OpenAreaRegistry(Which)
  CLOSE #6
  IF Which = 1 THEN OPEN #6, 4, 0, "D1:AREAS.CFG" ELSE OPEN #6, 4, 0, "D1:AREAS.BAK"
  INPUT #6, AreaLine$
ENDFUNC

FUNC ResolveFileArea(N)
  Q4 = FindAreaRegistry()
  IF Q4 < 0 THEN RETURN -1
  IF Q4 = 0
    AreaPath$ = FileDrive$
    IF NormalizeAreaPath() THEN RETURN 1
    AreaError = 18 : RETURN -1
  ENDIF
  OpenAreaRegistry(Q4)
  DO
    INPUT #6, AreaLine$
    IF ERR() <> 1 THEN EXIT
    IF AreaLine$[1, 1] = "F" AND PEEK(ADR(AreaLine$) + 3) - 48 = N
      ParseAreaRecord() : CLOSE #6 : RETURN 1
    ENDIF
  LOOP
  CLOSE #6 : AreaError = 18 : RETURN -1
ENDFUNC

FUNC ResolveMessageArea(N)
  Q4 = FindAreaRegistry()
  IF Q4 < 0 THEN RETURN -1
  IF Q4 = 0
    AreaPath$ = MsgDrive$
    IF NOT NormalizeAreaPath() THEN AreaError = 18 : RETURN -1
    FOR Q5 = 1 TO 9
      AreaLine$ = AreaPath$ : AreaLine$ =+ "MESSAGE.M" : AreaLine$ =+ CHR$(65 + N) : AreaLine$ =+ STR$(Q5)
      CLOSE #6 : OPEN #6, 4, 0, AreaLine$
      IF ERR() = 1 THEN CLOSE #6 : AreaLevel = Q5 : RETURN 1
      CLOSE #6
    NEXT Q5
    RETURN 0
  ENDIF
  OpenAreaRegistry(Q4)
  DO
    INPUT #6, AreaLine$
    IF ERR() <> 1 THEN EXIT
    IF AreaLine$[1, 1] = "M" AND PEEK(ADR(AreaLine$) + 3) - 65 = N
      ParseAreaRecord() : CLOSE #6 : RETURN 1
    ENDIF
  LOOP
  CLOSE #6 : RETURN 0
ENDFUNC

FUNC FileStorageArea(Name$)
  Q1 = INSTR(Name$, ".")
  IF Q1 < 2 OR Q1 + 3 <> LEN(Name$) THEN RETURN -1
  IF PEEK(ADR(Name$) + Q1 + 2) = 84 THEN RETURN 0
  Q2 = PEEK(ADR(Name$) + Q1 + 1)
  IF Q2 = 71 THEN RETURN 1
  IF Q2 = 65 THEN RETURN 2
  IF Q2 = 84 THEN RETURN 3
  IF Q2 = 82 THEN RETURN 4
  IF Q2 = 85 THEN RETURN 5
  RETURN -1
ENDFUNC

FUNC AreaBasename()
  Q2 = 3
  FOR Q1 = 4 TO LEN(AreaLine$)
    Q3 = PEEK(ADR(AreaLine$) + Q1)
    IF Q3 = 58 OR Q3 = 62 OR Q3 = 92 OR Q3 = 47 THEN Q2 = Q1
  NEXT Q1
  IF Q2 < LEN(AreaLine$) THEN AreaLine$ = AreaLine$[Q2 + 1] ELSE AreaLine$ = ""
ENDFUNC
