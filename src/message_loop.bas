' MESSAGE - message-base command loop.  X returns to MAINBBS.

FUNC MessageLoop()
  FileName$ = TextDrive$ : FileName$ =+ "MESGM"
  ShowTextFile()
  DO
    IF Lost OR Bye THEN RETURN
    OpenModem()
    PRINT #ModemCh; "MESSAGE >";
    IF NOT LocalMode THEN PRINT : PRINT "MESSAGE >";
    Il = 120
    GLine()
    IF L$ <> ""
      Q1 = PEEK(ADR(L$) + 1)
      IF Q1 >= 97 THEN Q1 = Q1 - 32
      IF Q1 = 88 THEN RETURN
      IF Q1 = 63
        FileName$ = TextDrive$ : FileName$ =+ "MESGM" : ShowTextFile()
      ELIF Q1 = 74
        ChangeMessageBase()
      ELIF Q1 = 81 OR Q1 = 82 OR Q1 = 83
        IF ActiveBase = -2
          PRINT #ModemCh; "NO ACCESSIBLE MESSAGE BASE"
        ELIF Q1 = 81
          ScanMessages(-1)
        ELIF Q1 = 82
          ScanMessages(0)
        ELSE
          ScanMessages(1)
        ENDIF
      ELIF Q1 = 69
        IF ActiveBase = -2
          PRINT #ModemCh; "NO ACCESSIBLE MESSAGE BASE"
        ELSE
          EnterMessage()
        ENDIF
      ELIF Q1 = 75
        IF ActiveBase = -2
          PRINT #ModemCh; "NO ACCESSIBLE MESSAGE BASE"
        ELSE
          KillMessage()
        ENDIF
      ELIF Q1 = 77
        IF ActiveBase = -2
          PRINT #ModemCh; "NO ACCESSIBLE MESSAGE BASE"
        ELSE
          ModifyMessage()
        ENDIF
      ELSE
        PRINT #ModemCh; "MESSAGE COMMAND?  TYPE ? FOR MENU"; CHR$(ControlChar(0))
      ENDIF
    ENDIF
  LOOP
ENDFUNC
