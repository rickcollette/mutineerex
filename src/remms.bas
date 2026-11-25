' REMMS 1.10 discovery, API calls and session-contract-9 handoff.

FUNC RemmsDiscover()
  ' The sole locator is inside REMMS's MEMLO-protected allocation.
  IF DPEEK($3EB0) <> $4C52 OR DPEEK($3EB2) <> $434F THEN RETURN 0
  IF DPEEK($3EB4) <> $0101 OR DPEEK($3EB6) <> $090A THEN RETURN 0
  RemmsApi = DPEEK($3EB8)
  RemmsPublic = DPEEK($3EBA)
  RemmsSession = DPEEK($3EBC)
  IF RemmsApi = 0 OR RemmsPublic = 0 OR RemmsSession = 0 THEN RETURN 0
  IF PEEK(RemmsPublic) <> 82 OR PEEK(RemmsPublic + 1) <> 69 THEN RETURN 0
  IF PEEK(RemmsPublic + 5) <> 1 OR PEEK(RemmsPublic + 6) <> 10 THEN RETURN 0
  IF PEEK(RemmsSession) <> 77 OR PEEK(RemmsSession + 1) <> 9 THEN RETURN 0
  RETURN 1
ENDFUNC

' REMMS can publish its resident API without an EOS R: backend.  Do not call
' its physical serial entry points until EOS has actually installed R: in
' HATABS; those entries necessarily target the saved R: handler.
FUNC RemmsHasR()
  LOCAL K
  FOR K = 0 TO 33 STEP 3
    IF PEEK($031A + K) = 82 THEN RETURN 1
  NEXT K
  RETURN 0
ENDFUNC

FUNC RemmsMode(Mode)
  RETURN USR(@REMMS_CALL1, RemmsApi + 3, Mode)
ENDFUNC

FUNC RemmsRoute(Route)
  RETURN USR(@REMMS_CALL1, RemmsApi + 6, Route)
ENDFUNC

FUNC RemmsOpen()
  ' WFC always requests a fresh wait-call physical configuration.
  RETURN USR(@REMMS_CALL1, RemmsApi + 9, 1)
ENDFUNC

FUNC RemmsClose()
  RETURN USR(@REMMS_CALL1, RemmsApi + 12, 0)
ENDFUNC

' Release the physical R: stream without hanging up a connected caller.
' Disk and printer CIO can then own POKEY/SIO safely.
FUNC RemmsSuspend()
  RETURN USR(@REMMS_CALL1, RemmsApi + 12, 1)
ENDFUNC

' Rebuild the connected stream after disk/printer ownership ends.
FUNC RemmsResume()
  RETURN USR(@REMMS_CALL1, RemmsApi + 9, 0)
ENDFUNC

FUNC RemmsStatus()
  Q1 = USR(@REMMS_CALL0, RemmsApi + 15)
  IF CurrentApp <> 1 AND PEEK(RemmsSession + 87) = 0 AND NOT LocalMode THEN Lost = 1
  RETURN Q1
ENDFUNC

FUNC RemmsGet()
  Q1 = USR(@REMMS_CALL0, RemmsApi + 18)
  ' REMMS 1.10 returns $0100-$0104 for no data, carrier, I/O and timeout.
  IF Q1 > 255
    IF Q1 <> 256 AND CurrentApp <> 1 AND NOT LocalMode THEN Lost = 1
    RETURN -1
  ENDIF
  RETURN Q1
ENDFUNC

' Canonical terminal input: ASCII controls and CR/LF become ATASCII values.
' Raw GET remains available for terminal detection and binary protocols.
FUNC RemmsTextGet()
  Q1 = USR(@REMMS_CALL0, RemmsApi + 27)
  IF Q1 > 255
    IF Q1 <> 256 AND CurrentApp <> 1 AND NOT LocalMode THEN Lost = 1
    RETURN -1
  ENDIF
  RETURN Q1
ENDFUNC

FUNC RemmsPut(C)
  RETURN USR(@REMMS_CALL1, RemmsApi + 21, C & 255)
ENDFUNC

FUNC RemmsConsole()
  RETURN USR(@REMMS_CALL0, RemmsApi + 24)
ENDFUNC

FUNC RemmsCommand(Command$)
  LOCAL K
  FOR K = 1 TO LEN(Command$)
    Q1 = RemmsPut(PEEK(ADR(Command$) + K))
  NEXT K
  Q1 = RemmsPut(13)
ENDFUNC

FUNC RemmsSetControls()
  ' Application code always uses canonical ATASCII controls.  REMMS converts
  ' them at the E: boundary for an ASCII caller.
  ControlChar(0) = 253
  ControlChar(1) = 126
  ControlChar(2) = 156
ENDFUNC

FUNC RemmsLoadSession()
  LOCAL K, N
  N = PEEK(RemmsSession + 2)
  IF N > 40 THEN N = 40
  Name$ = ""
  FOR K = 0 TO N - 1
    Name$ =+ CHR$(PEEK(RemmsSession + 3 + K))
  NEXT K
  N = PEEK(RemmsSession + 43)
  IF N > 40 THEN N = 40
  Addr$ = ""
  FOR K = 0 TO N - 1
    Addr$ =+ CHR$(PEEK(RemmsSession + 44 + K))
  NEXT K
  AMode = PEEK(RemmsSession + 84)
  LMode = PEEK(RemmsSession + 85)
  XMode = PEEK(RemmsSession + 86)
  ' +88 belongs to REMMS console snoop in contract 9; +96 is the published
  ' BASIC scratch byte and carries Mutineer-eX local/remote mode between modules.
  LocalMode = PEEK(RemmsSession + 96)
  UserLevel = PEEK(RemmsSession + 123)
  UserNumber = PEEK(RemmsSession + 125) + 256 * PEEK(RemmsSession + 124)
  Q1 = PEEK(RemmsSession + 97)
  IF Q1 = 255
    ActiveBase = -2
  ELSE
    ActiveBase = Q1
  ENDIF
  CurrentApp = PEEK(RemmsSession + 102)
  NextApp = PEEK(RemmsSession + 161)
  RemmsSetControls()
ENDFUNC

FUNC RemmsSaveSession()
  LOCAL K, N
  N = LEN(Name$)
  IF N > 40 THEN N = 40
  POKE RemmsSession + 2, N
  FOR K = 0 TO 39
    Q1 = 0
    IF K < N THEN Q1 = PEEK(ADR(Name$) + K + 1)
    POKE RemmsSession + 3 + K, Q1
  NEXT K
  N = LEN(Addr$)
  IF N > 40 THEN N = 40
  POKE RemmsSession + 43, N
  FOR K = 0 TO 39
    Q1 = 0
    IF K < N THEN Q1 = PEEK(ADR(Addr$) + K + 1)
    POKE RemmsSession + 44 + K, Q1
  NEXT K
  POKE RemmsSession + 84, AMode
  POKE RemmsSession + 85, LMode
  POKE RemmsSession + 86, XMode
  POKE RemmsSession + 96, LocalMode
  POKE RemmsSession + 123, UserLevel
  POKE RemmsSession + 124, UserNumber / 256
  POKE RemmsSession + 125, UserNumber & 255
  IF ActiveBase < 0
    POKE RemmsSession + 97, 255
  ELSE
    POKE RemmsSession + 97, ActiveBase
  ENDIF
  POKE RemmsSession + 102, CurrentApp
  POKE RemmsSession + 161, NextApp
ENDFUNC

FUNC RemmsApplyRoute()
  RemmsSaveSession()
  IF NOT SerialReady THEN RETURN
  IF LocalMode
    Q1 = RemmsMode(0)
    Q1 = RemmsRoute(0)
  ELSE
    Q1 = RemmsMode(1)
    Q1 = RemmsRoute(2)
  ENDIF
ENDFUNC

FUNC RunModule(Path$, App, Module$)
  LOCAL K, CachePrefix
  LOCAL Source$
  NextApp = App
  RemmsSaveSession()
  POKE RemmsSession + 161, App
  PRINT #ModemCh,
  PRINT #ModemCh; "Preparing "; Module$; "... ";
  FOR K = 1 TO 12
    IF K MOD 4 = 1 THEN PUT #ModemCh, 124
    IF K MOD 4 = 2 THEN PUT #ModemCh, 47
    IF K MOD 4 = 3 THEN PUT #ModemCh, 45
    IF K MOD 4 = 0 THEN PUT #ModemCh, 92
    PAUSE 2
    PUT #ModemCh, ControlChar(1)
  NEXT K
  PUT #ModemCh, 124
  PRINT #ModemCh,
  Source$ = Path$
  CachePrefix = 0
  IF LEN(Path$) > 2
    IF UCASE$(Path$[1, 2]) = "O:" THEN CachePrefix = 2
    IF UCASE$(Path$[1, 3]) = "DO:" THEN CachePrefix = 3
  ENDIF
  IF CachePrefix > 0
    Source$ = "RAMDISK:"
    IF LEN(Path$) > CachePrefix THEN Source$ =+ Path$[CachePrefix + 1, LEN(Path$) - CachePrefix]
  ENDIF
  PRINT #ModemCh; "Loading "; Module$; " from "; Source$; "..."
  ' Leave the real load message visible while RUN blocks in filesystem I/O.
  PAUSE 5
  CLOSE #ModemCh
  CLOSE #KbdCh
  RUN Path$
  PRINT "CAN'T RUN "; Path$; ", ERROR "; ERR()
  END
ENDFUNC
