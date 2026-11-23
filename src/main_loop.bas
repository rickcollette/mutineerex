' MAINBBS - the top-level BBS command loop.

FUNC MainBbsLoop()
  LOCAL C
  Bye = 0
  SetPrompt()
  DO
    IF Lost OR Bye THEN EXIT
    OpenModem()
    PRINT #ModemCh,
    PRINT #ModemCh; Prompt$;
    IF NOT LocalMode
      PRINT
      PRINT Prompt$;
    ENDIF
    Il = 120
    GLine()
    IF L$ <> ""
      C = PEEK(ADR(L$) + 1)
      IF C >= 97 THEN C = C - 32
      IF C <> 59 THEN DoMainCommand(C)
    ENDIF
  LOOP
ENDFUNC

FUNC DoMainCommand(C)
  IF C = 66
    FileName$ = TextDrive$ : FileName$ =+ "BULL" : ShowTextFile()
  ELIF C = 63
    FileName$ = TextDrive$ : FileName$ =+ "FUNC" : ShowTextFile()
  ELIF C = 72
    FileName$ = TextDrive$ : FileName$ =+ "HELP" : ShowTextFile()
  ELIF C = 87
    FileName$ = TextDrive$ : FileName$ =+ "WELC" : ShowTextFile()
  ELIF C = 88
    ToggleExpert()
  ELIF C = 84
    GetTime()
    PRINT #ModemCh; "TIME: "; NowTime$; "   DATE: "; NowDate$
  ELIF C = 77
    FileName$ = "D1:"
    IF StartOption(2) THEN FileName$ = "O:"
    FileName$ =+ "message.com"
    RunModule(FileName$, 4, "MESSAGE")
  ELIF C = 70
    FileName$ = "D1:"
    IF StartOption(2) THEN FileName$ = "O:"
    FileName$ =+ "files.com"
    RunModule(FileName$, 5, "FILES")
  ELIF C = 68
    FileName$ = "D1:"
    IF StartOption(2) THEN FileName$ = "O:"
    FileName$ =+ "doors.com"
    RunModule(FileName$, 6, "DOORS")
  ELIF C = 89
    Yell()
  ELIF C = 71
    Goodbye()
  ELIF C = 76
    ToggleLF()
  ELIF C = 65
    SwitchMode()
  ELIF C = 67
    ListCallers()
  ELIF C = 90
    ManageUsers()
  ELSE
    PRINT #ModemCh; "I DON'T KNOW WHAT "; L$; " MEANS."; CHR$(ControlChar(0))
  ENDIF
ENDFUNC

FUNC ToggleExpert()
  XMode = NOT XMode
  SetPrompt()
  IF XMode
    PRINT #ModemCh; "EXPERT USER MODE"
  ELSE
    PRINT #ModemCh; "NORMAL USER MODE"
  ENDIF
ENDFUNC

FUNC ToggleLF()
  LMode = 64 - LMode
  OpenModem()
  PRINT #ModemCh; "LINE-FEED ";
  IF LMode
    PRINT #ModemCh; "ON"
  ELSE
    PRINT #ModemCh; "OFF"
  ENDIF
ENDFUNC

FUNC SwitchMode()
  LOCAL C
  AMode = 32
  RemmsSetControls()
  OpenModem()
  PRINT #ModemCh; "HIT <RETURN>";
  C = GetChr()
  IF C <> 155 THEN AMode = 0
  RemmsSetControls()
  OpenModem()
  IF AMode
    T$ = "ATASCII Mode"
    SetInverse(1)
    PRINT #ModemCh; T$
  ELSE
    PRINT #ModemCh; "ASCII Mode"
  ENDIF
ENDFUNC

FUNC Goodbye()
  PRINT #ModemCh; "Any Comments";
  IF YesNo()
    PRINT #ModemCh; "Enter comments"
    DO
      PRINT #ModemCh; ">";
      GLine()
      IF L$ = "" THEN EXIT
      PRINT #LogCh; L$
      LogCheck()
    LOOP
  ENDIF
  GetTime()
  PRINT #LogCh; "LOGGED-OFF AT "; NowTime$
  LogCheck()
  PRINT #ModemCh; "Thanks for calling "; Name$
  PRINT #ModemCh; "Please call again..."
  Bye = 1
ENDFUNC

FUNC Yell()
  LOCAL F, Start
  PRINT #ModemCh; "CHAT MODE, I'll call "; SysopName$; "......."
  PRINT Name$; " FROM "; Addr$
  PRINT
  PRINT "PRESS SELECT TO BEGIN, CTRL<X> TO END"
  FOR F = 1 TO 5
    PRINT CHR$(253)
    PAUSE 6
    IF PEEK(53279) = 5 THEN Chat() : RETURN
  NEXT F
  Start = TIME
  WHILE TIME - Start < 5 * Fps
    IF PEEK(53279) = 5 THEN Chat() : RETURN
  WEND
  PRINT #ModemCh; "Sorry, "; SysopName$; " isn't here."
ENDFUNC
