' LOGIN - terminal negotiation, login/registration and caller log entry.

FUNC LoginCaller()
  LOCAL C, User
  DO
    OpenModem()
    PRINT #ModemCh; "HIT <RETURN> ";
    C = GetChr()
    IF Lost THEN RETURN 0
    IF C = 155
      PRINT #ModemCh,
      EXIT
    ENDIF
    IF C = 13 OR C = 141
      AMode = 0
      RemmsSetControls()
      OpenModem()
      PRINT #ModemCh; CHR$(10)
      PRINT #ModemCh; "Do you require Line Feeds";
      IF YesNo() THEN LMode = 64
      OpenModem()
      EXIT
    ENDIF
  LOOP
  FileName$ = TextDrive$ : FileName$ =+ "WELC"
  IF ReadTextFile() = 1 THEN SendBuf(0)
  User = UserLogin()
  IF User = 0 THEN RETURN 0
  LoadDefaultBase()
  LogCaller()
  FileName$ = TextDrive$ : FileName$ =+ "BULL"
  C = 0
  IF ReadTextFile() = 1 THEN C = SendBuf(1)
  IF C = 24
    XMode = NOT XMode
  ELIF User = 2
    FileName$ = TextDrive$ : FileName$ =+ "NEWU"
    ShowTextFile()
  ENDIF
  RETURN 1
ENDFUNC
