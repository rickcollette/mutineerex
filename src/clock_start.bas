' WFC-only clock acquisition after a cold or offline restart.

FUNC AskClock()
  ' Clock entry is always a local-console operation.  AttachModule restores
  ' the saved caller route before this function runs; with a configured R:
  ' handler that route makes E: reads wait on REMMS instead of the keyboard.
  ' WaitForCall selects host mode again when it opens the modem.
  IF SerialReady THEN Q1 = RemmsMode(0)
  DO
    PRINT "Enter date mm/dd/yyyy ";
    ' A DOS/RAM-disk launch may leave IOCB #0 closed or redirected.
    ' AttachModule always opens ModemCh on E:, so use that explicit editor
    ' channel instead of relying on the inherited console.
    INPUT #ModemCh, S$
    Month = VAL(S$[1, 2])
    Day = VAL(S$[4, 2])
    Year = VAL(S$[9, 2])
    IF LEN(S$) = 10 AND S$[7, 2] = "20" AND Month >= 1 AND Month <= 12 AND Day >= 1 AND Day <= 31 THEN EXIT
  LOOP
  DO
    PRINT "Enter time hh:mm:ss ";
    INPUT #ModemCh, S$
    Hour = VAL(S$[1, 2])
    Minute = VAL(S$[4, 2])
    Second = VAL(S$[7, 2])
    IF LEN(S$) = 8 AND Hour < 24 AND Minute < 60 AND Second < 60 THEN EXIT
  LOOP
ENDFUNC

FUNC ClockFromAPE()
  FileName$ = "D1:APETIME.TXT"
  IF ReadNumbers() <> 3 THEN RETURN 0
  RETURN ClockFromEOS()
ENDFUNC

FUNC ClockFromEOS()
  FileName$ = "D1:BBSDATE.TXT"
  IF ReadNumbers() <> 3 THEN RETURN 0
  IF Q1 > 31
    Year = Q1 MOD 100
    Month = Q2
    Day = Q3
  ELSE
    Month = Q1
    Day = Q2
    Year = Q3 MOD 100
  ENDIF
  IF Month < 1 OR Month > 12 OR Day < 1 OR Day > 31 THEN RETURN 0
  FileName$ = "D1:BBSTIME.TXT"
  IF ReadNumbers() < 2 THEN RETURN 0
  Hour = Q1
  Minute = Q2
  Second = Q3
  IF INSTR(S$, "P") > 0 AND Hour < 12 THEN Hour = Hour + 12
  IF INSTR(S$, "A") > 0 AND Hour = 12 THEN Hour = 0
  IF Hour > 23 OR Minute > 59 OR Second > 59 THEN RETURN 0
  PRINT "DATE AND TIME FROM EOS"
  RETURN 1
ENDFUNC

FUNC ReadNumbers()
  CLOSE #FileCh
  OPEN #FileCh, 4, 0, FileName$
  INPUT #FileCh, S$
  St = ERR()
  CLOSE #FileCh
  XIO 33, #FileCh, 0, 0, FileName$
  IF St <> 1 AND St <> 136 THEN RETURN 0
  RETURN GetNumbers()
ENDFUNC

FUNC GetNumbers()
  Q1 = 0 : Q2 = 0 : Q3 = 0 : Q4 = 0 : Q5 = 1
  WHILE Q5 <= LEN(S$) AND Q4 < 3
    Q6 = PEEK(ADR(S$) + Q5)
    IF Q6 >= 48 AND Q6 <= 57
      INC Q4
      Q6 = 0
      WHILE Q5 <= LEN(S$)
        IF PEEK(ADR(S$) + Q5) < 48 OR PEEK(ADR(S$) + Q5) > 57 THEN EXIT
        IF Q6 < 3000 THEN Q6 = Q6 * 10 + PEEK(ADR(S$) + Q5) - 48
        INC Q5
      WEND
      IF Q4 = 1 THEN Q1 = Q6
      IF Q4 = 2 THEN Q2 = Q6
      IF Q4 = 3 THEN Q3 = Q6
    ELSE
      INC Q5
    ENDIF
  WEND
  RETURN Q4
ENDFUNC
