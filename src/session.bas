' ====================================================================
' Start up, waiting for calls, logon and the command menu
' ====================================================================

' Asks the date and time, reads SYSTEM.MET and opens the keyboard and
' log printer.
FUNC Init()
  PRINT CHR$(125); "B.B.S."
  IF CfgStatus = 170 THEN PRINT "NO "; CfgFile$; " - RUN INIT"
  IF CfgStatus <> 1 AND CfgStatus <> 170 THEN PRINT "INVALID "; CfgFile$; " - RUN INIT"
  SetPrompt()
  ' Use the configured source. Manual is reliable after an offline restart;
  ' APETime is accepted only when its redirected status contains a timestamp.
  St = 0
  IF AutoStart AND StartOption(1) = 2 THEN St = ClockFromAPE()
  IF AutoStart AND (StartOption(1) = 1 OR StartOption(1) = 3) THEN St = ClockFromEOS()
  IF St = 0 THEN AskClock()
  ' 50 frames per second on PAL machines, 60 on NTSC
  Fps = 60
  IF (PEEK($D014) & 14) = 0 THEN Fps = 50
  LastTick = TIME
  CLOSE #FileCh
  OPEN #FileCh, 4, 0, SystemFile$
  INPUT #FileCh, CSect, CByte, CallNo
  St = ERR()
  CLOSE #FileCh
  IF St <> 1
    PRINT "CAN'T READ "; SystemFile$; ", ERROR "; St
    PRINT "RUN CONFIG AND INITIALIZE FIRST"
    END
  ENDIF
  OPEN #KbdCh, 4, 0, "K:"
  IF UsePrinter
    OPEN #LogCh, 8, 0, "P:"
    LogOk = 1
    PRINT #LogCh; "BUFF = "; BufSize
    LogCheck()
  ENDIF
ENDFUNC

' Asks the date and time when no trustworthy automatic source is available
FUNC AskClock()
  DO
    PRINT "Enter date mm/dd/yyyy ";
    INPUT S$
    Month = VAL(S$[1, 2])
    Day = VAL(S$[4, 2])
    Year = VAL(S$[9, 2])
    IF LEN(S$) = 10 AND S$[7, 2] = "20" AND Month >= 1 AND Month <= 12 AND Day >= 1 AND Day <= 31 THEN EXIT
  LOOP
  DO
    PRINT "Enter time hh:mm:ss ";
    INPUT S$
    Hour = VAL(S$[1, 2])
    Minute = VAL(S$[4, 2])
    Second = VAL(S$[7, 2])
    IF LEN(S$) = 8 AND Hour < 24 AND Minute < 60 AND Second < 60 THEN EXIT
  LOOP
ENDFUNC

' APETime's success line contains a date; its failure message contains no
' numbers. Consume that status first so an unreachable SIO host cannot make
' us accept the old JIFFY value written by DATE and TIME.
FUNC ClockFromAPE()
  FileName$ = "D1:APETIME.TXT"
  IF ReadNumbers() <> 3 THEN RETURN 0
  RETURN ClockFromEOS()
ENDFUNC

' Reads the date and time that eosauto.bat wrote with DATE /T and
' TIME /T to D1:BBSDATE.TXT and D1:BBSTIME.TXT.  Returns 1 when both
' are good, 0 to ask them
FUNC ClockFromEOS()
  FileName$ = "D1:BBSDATE.TXT"
  IF ReadNumbers() <> 3 THEN RETURN 0
  IF Q1 > 31
    ' year first, as in 2026-11-17
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

' Reads the first line of FileName$ into S$, deletes the file and
' returns how many numbers GetNumbers found in it
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

' Puts the first three numbers written in S$ in Q1, Q2 and Q3 and
' returns how many there were
FUNC GetNumbers()
  Q1 = 0
  Q2 = 0
  Q3 = 0
  Q4 = 0
  Q5 = 1
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

' The prompt of the normal (not expert) mode
FUNC SetPrompt()
  Prompt$ = "A,B,C,F,G,H,L,M,T,W,X,Y,Z, or ? >"
ENDFUNC

' Hangs up, prepares the modem and waits for a call or a console key.
' Returns 0 = quit (OPTION), 1 = call answered, 2 = local (SELECT),
' 3 = no connection
FUNC WaitRing()
  LOCAL Con, Ready
  IF LocalMode
    CLOSE #ModemCh
  ELSE
    CloseModem()
  ENDIF
  LocalMode = 0
  Lost = 0
  ' Drop DTR to hang up
  XIO 38, #ModemCh, 0, 0, "R:"
  XIO 34, #ModemCh, 128, 0, "R:"
  PAUSE 30
  GRAPHICS 0
  GetTime()
  PRINT #LogCh; "===== "; NowDate$; " ===== "; NowTime$; " ====="
  LogCheck()
  XIO 34, #ModemCh, 192, 0, "R:"
  XIO 36, #ModemCh, BaudCode, 0, "R:"
  CLOSE #ModemCh
  OPEN #ModemCh, 15, 0, "R:"
  Ready = ERR() = 1
  IF Ready THEN Ready = StartConcurrent() = 1
  ControlChar(0) = 253
  ControlChar(2) = 156
  ControlChar(1) = 126
  SetPrompt()
  AMode = 32
  LMode = 0
  XMode = 0
  POKE 752, 1
  IF Ready
    DrainInput(1)
    PRINT #ModemCh; "ATZ"
    PAUSE 30
    PRINT CHR$(253);
    DrainInput(1)
    PAUSE 30
    PRINT #ModemCh; ModemInit$
    PAUSE 30
    DrainInput(1)
  ELSE
    PRINT "R: NOT READY, ONLY LOCAL LOGON WORKS"
  ENDIF
  PRINT CallNo; " CALLS SINCE INITIALIZATION"
  POSITION 2, 10
  PRINT "SELECT = LOCAL LOGON   OPTION = QUIT"
  DO
    GetTime()
    POSITION 2, 8
    PRINT "TIME: "; NowTime$; "   DATE: "; NowDate$
    Con = PEEK(53279)
    IF Con = 3
      PRINT #ModemCh; "AT H1 M0"
      RETURN 0
    ENDIF
    IF Con = 5
      PRINT #ModemCh; "AT H1 M0"
      CloseModem()
      LocalMode = 1
      OPEN #ModemCh, 13, 0, "E:"
      RETURN 2
    ENDIF
    IF Ready
      STATUS #ModemCh, St
      IF PEEK(747)
        PRINT CHR$(253);
        DrainInput(1)
        PRINT CHR$(253);
        RETURN Answer()
      ENDIF
    ENDIF
    PAUSE 5
  LOOP
ENDFUNC

' Answers the phone; returns 1 when connected, 3 when not
FUNC Answer()
  LOCAL Start, C
  PRINT "ANSWERING CALL"
  PRINT #ModemCh; "ATA"
  Start = TIME
  DO
    STATUS #ModemCh, St
    IF PEEK(747) THEN EXIT
    UpdateClock()
    IF TIME - Start > 60 * Fps THEN RETURN 3
  LOOP
  ' Show the modem messages until the line is quiet for a second
  Start = TIME
  WHILE TIME - Start < Fps
    STATUS #ModemCh, St
    IF PEEK(747)
      GET #ModemCh, C
      PUT C
      Start = TIME
    ENDIF
  WEND
  RETURN 1
ENDFUNC

' Finds the terminal type, shows the welcome text and logs the user on.
' Returns 1 when the user can use the BBS
FUNC Logon()
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
      ControlChar(0) = 7
      ControlChar(1) = 8
      ControlChar(2) = 24
      AMode = 0
      OpenModem()
      PRINT #ModemCh; CHR$(10)
      PRINT #ModemCh; "Do you require Line Feeds";
      IF YesNo()
        LMode = 64
        OpenModem()
      ENDIF
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
    ToggleExpert()
  ELIF User = 2
    FileName$ = TextDrive$ : FileName$ =+ "NEWU"
    ShowTextFile()
  ENDIF
  RETURN 1
ENDFUNC

' One call, from the logon to the good-bye or the lost carrier
FUNC Session()
  LOCAL C
  Bye = 0
  IF Logon()
    DO
      IF Lost OR Bye THEN EXIT
      OpenModem()
      PRINT #ModemCh,
      PRINT #ModemCh; Prompt$;
      Il = 120
      IF NOT LocalMode
        PRINT
        PRINT Prompt$;
      ENDIF
      GLine()
      IF L$ <> ""
        C = PEEK(ADR(L$) + 1)
        IF C >= 97
          C = C - 32
          POKE ADR(L$) + 1, C
        ENDIF
        IF C <> 59 THEN DoCommand(C)
      ENDIF
    LOOP
  ENDIF
  IF Lost
    CloseModem()
    GetTime()
    PRINT #LogCh; "LINE LOST AT "; NowTime$
    LogCheck()
  ENDIF
ENDFUNC

' Runs the command with the letter C
FUNC DoCommand(C)
  IF C = 66
    FileName$ = TextDrive$ : FileName$ =+ "BULL"
    ShowTextFile()
  ELIF C = 63
    FileName$ = TextDrive$ : FileName$ =+ "FUNC"
    ShowTextFile()
  ELIF C = 72
    FileName$ = TextDrive$ : FileName$ =+ "HELP"
    ShowTextFile()
  ELIF C = 87
    FileName$ = TextDrive$ : FileName$ =+ "WELC"
    ShowTextFile()
  ELIF C = 88
    ToggleExpert()
  ELIF C = 84
    GetTime()
    PRINT #ModemCh; "TIME: "; NowTime$; "   DATE: "; NowDate$
  ELIF C = 77
    MessageMenu()
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
  ELIF C = 70
    FileMenu()
  ELIF C = 90
    ManageUsers()
  ELSE
    PRINT #ModemCh; "I DON'T KNOW WHAT "; L$; " MEANS."; CHR$(ControlChar(0))
  ENDIF
ENDFUNC

' M from the main menu: message-base commands. X returns to main.
FUNC MessageMenu()
  FileName$ = TextDrive$ : FileName$ =+ "MESGM"
  ShowTextFile()
  DO
    IF Lost OR Bye THEN RETURN
    OpenModem()
    PRINT #ModemCh; "MESSAGE >";
    IF NOT LocalMode
      PRINT
      PRINT "MESSAGE >";
    ENDIF
    Il = 120
    GLine()
    IF L$ <> ""
      Q1 = PEEK(ADR(L$) + 1)
      IF Q1 >= 97 THEN Q1 = Q1 - 32
      IF Q1 = 88 THEN RETURN
      IF Q1 = 63
        FileName$ = TextDrive$ : FileName$ =+ "MESGM"
        ShowTextFile()
      ELIF Q1 = 74
        ChangeMessageBase()
      ELIF Q1 = 81
        IF ActiveBase = -2
          PRINT #ModemCh; "NO ACCESSIBLE MESSAGE BASE"
        ELSE
          ScanMessages(-1)
        ENDIF
      ELIF Q1 = 82
        IF ActiveBase = -2
          PRINT #ModemCh; "NO ACCESSIBLE MESSAGE BASE"
        ELSE
          ScanMessages(0)
        ENDIF
      ELIF Q1 = 83
        IF ActiveBase = -2
          PRINT #ModemCh; "NO ACCESSIBLE MESSAGE BASE"
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

' F from the main menu: controlled-file commands. X returns to main.
FUNC FileMenu()
  FileCategory = 0
  FileName$ = TextDrive$ : FileName$ =+ "FILEM"
  ShowTextFile()
  T$ = ""
  FileCategoryName()
  PRINT #ModemCh; "CATEGORY: "; T$
  DO
    IF Lost OR Bye THEN RETURN
    OpenModem()
    PRINT #ModemCh; "FILE >";
    IF NOT LocalMode
      PRINT
      PRINT "FILE >";
    ENDIF
    Il = 120
    GLine()
    IF L$ <> ""
      Q1 = PEEK(ADR(L$) + 1)
      IF Q1 >= 97 THEN Q1 = Q1 - 32
      IF Q1 = 88 THEN RETURN
      IF Q1 = 63
        FileName$ = TextDrive$ : FileName$ =+ "FILEM"
        ShowTextFile()
      ELIF Q1 = 68
        Download()
      ELIF Q1 = 70
        ListFiles()
      ELIF Q1 = 73
        ListFiles()
      ELIF Q1 = 74
        ChangeFileCategory()
      ELIF Q1 = 85
        Upload()
      ELIF Q1 = 86
        DeleteFile()
      ELSE
        PRINT #ModemCh; "FILE COMMAND?  TYPE ? FOR MENU"; CHR$(ControlChar(0))
      ENDIF
    ENDIF
  LOOP
ENDFUNC

' X: switches the expert mode (short prompts)
FUNC ToggleExpert()
  XMode = NOT XMode
  IF XMode
    PRINT #ModemCh; "EXPERT USER MODE"
    Prompt$ = "OK >"
  ELSE
    PRINT #ModemCh; "NORMAL USER MODE"
    SetPrompt()
  ENDIF
ENDFUNC

' L: switches the line feeds after each line
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

' A: switches between ASCII and ATASCII; an ATASCII terminal answers
' the question with an ATASCII RETURN (155)
FUNC SwitchMode()
  LOCAL C
  AMode = 32
  OpenModem()
  PRINT #ModemCh; "HIT <RETURN>";
  C = GetChr()
  IF C <> 155 THEN AMode = 0
  OpenModem()
  IF AMode
    ControlChar(0) = 253
    ControlChar(2) = 156
    ControlChar(1) = 126
    T$ = "ATASCII Mode"
    SetInverse(1)
    PRINT #ModemCh; T$
  ELSE
    ControlChar(0) = 7
    ControlChar(2) = 24
    ControlChar(1) = 8
    PRINT #ModemCh; "ASCII Mode"
  ENDIF
ENDFUNC

' G: comments for the sysop, then good-bye
FUNC Goodbye()
  PRINT #ModemCh; "Any Comments";
  IF YesNo()
    PRINT #ModemCh; "Enter comments"
    DO
      PRINT #ModemCh; ">";
      GLine()
      IF L$ = "" THEN EXIT
      CloseModem()
      PRINT #LogCh; L$
      LogCheck()
      OpenModem()
    LOOP
  ENDIF
  CloseModem()
  GetTime()
  PRINT #LogCh; "LOGGED-OFF AT "; NowTime$
  LogCheck()
  OpenModem()
  PRINT #ModemCh; "Thanks for calling "; Name$
  PRINT #ModemCh; "Please call again..."
  Bye = 1
ENDFUNC

' Y: calls the sysop, who answers with SELECT
FUNC Yell()
  LOCAL F, Start
  PRINT #ModemCh; "CHAT MODE, I'll call "; SysopName$; "......."
  PRINT Name$; " FROM "; Addr$
  PRINT
  PRINT "PRESS SELECT TO BEGIN, CTRL<X> TO END"
  FOR F = 1 TO 5
    PRINT CHR$(253)
    PAUSE 6
    IF PEEK(53279) = 5
      Chat()
      RETURN
    ENDIF
  NEXT F
  Start = TIME
  WHILE TIME - Start < 5 * Fps
    IF PEEK(53279) = 5
      Chat()
      RETURN
    ENDIF
  WEND
  PRINT #ModemCh; "Sorry, "; SysopName$; " isn't here."
ENDFUNC

' Chat between the sysop and the caller, until either types CTRL-X
FUNC Chat()
  LOCAL C, D
  CloseModem()
  PRINT "IN CHAT MODE"
  OpenModem()
  PRINT #ModemCh; "CHAT MODE: PRESS CTRL<X> TO END"
  POKE 764, 255
  DO
    IF Lost THEN EXIT
    C = -1
    IF NOT LocalMode
      STATUS #ModemCh, St
      IF St = 139 THEN Lost = 1
      IF PEEK(747)
        GET #ModemCh, C
        PUT #ModemCh, C
        D = C
        IF C = 8 THEN D = 126
        PUT D
      ENDIF
    ENDIF
    IF C < 0 AND PEEK(764) <> 255
      GET #KbdCh, C
      IF C = 126
        PRINT #ModemCh; CHR$(ControlChar(1)); " "; CHR$(ControlChar(1));
      ELIF NOT LocalMode
        PUT #ModemCh, C
      ENDIF
      ' In local mode ModemCh is already E:, so the write above is also
      ' the screen echo.  During a real call the sysop needs a separate
      ' local echo in addition to the character sent to the caller.
      IF NOT LocalMode OR C <> 126 THEN PUT C
    ENDIF
    IF C = 24 THEN EXIT
    UpdateClock()
  LOOP
  CloseModem()
ENDFUNC
