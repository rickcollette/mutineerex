' ====================================================================
' Shared CONFIG helpers
' ====================================================================

FUNC AskYes()
  LOCAL C
  DO
    GET C
    IF C > 96 THEN C = C - 32
  LOOP UNTIL C = 89 OR C = 78
  PRINT CHR$(C)
  RETURN C = 89
ENDFUNC

FUNC AskNumber(Old, Low, High)
  LOCAL N
  DO
    PRINT "FROM "; Low; " TO "; High; " (RETURN="; Old; ") >";
    INPUT ; In$
    IF In$ = "" THEN RETURN Old
    N = VAL(In$)
    IF ERR() = 1 AND N >= Low AND N <= High THEN RETURN N
    PRINT "NOT VALID"
  LOOP
ENDFUNC

FUNC AskDrive()
  LOCAL Last
  DO
    PRINT "DRIVE, LIKE D1: OR D2: >";
    INPUT ; In$
    In$ = UCASE$(In$)
    IF In$ = "" THEN RETURN
    Last = PEEK(ADR(In$) + LEN(In$))
    IF In$[1, 1] = "D" AND LEN(In$) <= 30 AND (Last = 58 OR Last = 62 OR Last = 92) THEN RETURN
    PRINT "MUST START D AND END : OR > OR \"
  LOOP
ENDFUNC

FUNC PauseForKey()
  PRINT
  PRINT "PRESS RETURN";
  INPUT ; In$
ENDFUNC

FUNC FileExists()
  CLOSE #1
  OPEN #1, 4, 0, F$
  Status = ERR()
  CLOSE #1
  RETURN Status = 1
ENDFUNC

FUNC ShowError()
  PRINT
  PRINT "ERROR "; Status; " WITH"
  PRINT F$
  PauseForKey()
ENDFUNC
