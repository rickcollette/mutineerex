' WFC - wait for a REMMS call, local logon or quit command.

FUNC InitializeClock()
  IF Year <> 0 THEN RETURN
  PRINT CHR$(125); "Mutineer-eX 1.0.17 WFC"
  IF CfgStatus = 170 THEN PRINT "NO "; CfgFile$; " - RUN INIT"
  IF CfgStatus <> 1 AND CfgStatus <> 170 THEN PRINT "INVALID "; CfgFile$; " - RUN INIT"
  St = 0
  IF AutoStart AND StartOption(1) = 2 THEN St = ClockFromAPE()
  IF AutoStart AND (StartOption(1) = 1 OR StartOption(1) = 3) THEN St = ClockFromEOS()
  IF St = 0 THEN AskClock()
ENDFUNC

' Draws the local 40-column ATASCII wait-for-call dashboard.  WFC always
' uses the native screen even when callers are configured for ASCII.
FUNC WfcDrawScreen()
  LOCAL Code, C
  POKE 82, 0
  POKE 83, 39
  POKE 752, 1
  FileName$ = TextDrive$ : FileName$ =+ "WFC.ATA"
  St = ResolveCachePath()
  CLOSE #FileCh
  OPEN #FileCh, 4, 0, FileName$
  Code = ERR()
  IF Code <> 1
    CLOSE #FileCh
    PRINT CHR$(125); "Mutineer-eX 1.0.17 / REMMS WFC"
    PRINT "MISSING "; FileName$; " ERROR "; Code
    RETURN
  ENDIF
  DO
    GET #FileCh, C
    Code = ERR()
    IF Code = 1 THEN PUT #ModemCh, C
  LOOP UNTIL Code <> 1
  CLOSE #FileCh
ENDFUNC

' Writes T$ into an arbitrary field without disturbing its ATASCII box.
FUNC WfcValue(Column, Row, Width)
  LOCAL K
  IF LEN(T$) > Width THEN T$ = T$[1, Width]
  POSITION Column, Row
  FOR K = 1 TO Width
    PUT 32
  NEXT K
  POSITION Column, Row
  PRINT T$;
ENDFUNC

FUNC WfcClockName$(Source)
  IF Source = 1 THEN RETURN "EOS / JIFFY"
  IF Source = 2 THEN RETURN "APETIME"
  IF Source = 3 THEN RETURN "R-TIME 8"
  RETURN "MANUAL"
ENDFUNC

FUNC WfcSystemInfo()
  GetTime()
  T$ = NowDate$ : WfcValue(7, 5, 10)
  T$ = NowTime$ : WfcValue(26, 5, 8)
  T$ = STR$(CallNo) : WfcValue(8, 6, 9)
  T$ = WfcClockName$(StartOption(1)) : WfcValue(27, 6, 11)
  IF CarrierWatch
    T$ = "ON"
  ELSE
    T$ = "OFF"
  ENDIF
  WfcValue(9, 11, 3)
  T$ = STR$(IdleMinutes) : T$ =+ " MIN" : WfcValue(20, 11, 6)
  T$ = STR$(PEEK(RemmsSession + 159)) : WfcValue(34, 11, 3)
ENDFUNC

FUNC WfcModemInfo(Ready)
  IF Ready
    T$ = "READY / WAITING FOR RING" : WfcValue(9, 10, 29)
  ELSE
    T$ = "OFFLINE / LOCAL LOGON ONLY" : WfcValue(9, 10, 29)
  ENDIF
ENDFUNC

FUNC WaitForCall()
  LOCAL Command, Ready
  Lost = 0
  LocalMode = 0
  Name$ = ""
  Addr$ = ""
  UserLevel = 0
  UserNumber = 0
  ActiveBase = -2
  AMode = 32
  LMode = 0
  XMode = 0
  RemmsSetControls()
  IF SerialReady THEN Q1 = RemmsClose()
  POKE RemmsSession + 96, NOT SerialReady
  POKE RemmsSession + 159, 1
  WfcDrawScreen()
  WfcSystemInfo()
  T$ = "INITIALIZING / PLEASE WAIT" : WfcValue(9, 10, 29)
  Ready = 0
  IF SerialReady THEN Ready = RemmsOpen() = 0
  IF Ready
    RemmsCommand("ATZ")
    PAUSE 30
    ' REMMS detects textual result codes.  Do not inherit quiet or numeric
    ' result mode from a modem profile loaded by ATZ.
    RemmsCommand("ATQ0 V1")
    RemmsCommand(ModemInit$)
  ENDIF
  WfcModemInfo(Ready)
  DO
    GetTime()
    T$ = NowDate$ : WfcValue(7, 5, 10)
    T$ = NowTime$ : WfcValue(26, 5, 8)
    Command = RemmsConsole()
    IF Command = 3
      T$ = "SHUTTING DOWN..." : WfcValue(9, 10, 29)
      PAUSE 20
      IF SerialReady THEN Q1 = RemmsClose()
      POKE 82, 2
      POKE 752, 0
      RETURN 0
    ENDIF
    IF Command = 2
      T$ = "LOCAL LOGON / STARTING..." : WfcValue(9, 10, 29)
      PAUSE 30
      LocalMode = 1
      IF SerialReady
        Q1 = RemmsClose()
        Q1 = RemmsMode(0)
        Q1 = RemmsRoute(0)
      ENDIF
      POKE 82, 2
      POKE 752, 0
      RETURN 2
    ENDIF
    IF Ready
      Q1 = RemmsStatus()
      IF PEEK(RemmsSession + 87) = 1
        T$ = "CONNECTED / STARTING LOGIN" : WfcValue(9, 10, 29)
        PAUSE 45
        LocalMode = 0
        Lost = 0
        Q1 = RemmsMode(1)
        Q1 = RemmsRoute(2)
        POKE 82, 2
        POKE 752, 0
        RETURN 1
      ELIF PEEK(RemmsSession + 160) > 0
        T$ = "RING ": T$ =+ STR$(PEEK(RemmsSession + 160))
        T$ =+ " / ANSWERING..."
        WfcValue(9, 10, 29)
      ENDIF
    ENDIF
    PAUSE 5
  LOOP
ENDFUNC
