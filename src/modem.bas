' ====================================================================
' Caller input and output through REMMS
' ====================================================================
' In local mode the "modem" channel is the screen editor E: and the
' sysop types on the keyboard (K: on channel KbdCh).
' The R: handler in concurrent mode leaves, after STATUS, the number of
' characters waiting in DVSTAT+1 (747) and the number of characters still
' to send in DVSTAT+3 (749).  Error 139 means the carrier was lost.

' True when the REMMS-routed E: channel is open
FUNC ModemOpen()
  RETURN PEEK($340 + 16 * ModemCh) <> 255
ENDFUNC

' Waits until the R: output buffer is empty (line 8 of the original)
FUNC WaitSent()
  ' REMMS serializes each PUT through its private IOCB.
ENDFUNC

' Closes the modem channel, needed before any disk or printer access
' (CLM of the original)
FUNC CloseModem()
  IF SerialReady
    IF NOT LocalMode
      IF PEEK(RemmsSession + 87) = 1 AND PEEK(RemmsPublic + 24) = 2
        Q1 = RemmsSuspend()
        IF Q1 THEN Lost = 1
      ENDIF
    ENDIF
  ENDIF
ENDFUNC

' Starts the R: concurrent mode with RBuf as the input buffer.
' Returns the CIO status
FUNC StartConcurrent()
  RETURN 1
ENDFUNC

' Opens the modem channel with the current translation (AMode) and
' line feed (LMode) settings (OPM of the original)
FUNC OpenModem()
  POKE 77, 0
  IF SerialReady
    IF NOT LocalMode
      IF PEEK(RemmsPublic + 24) = 4
        Q1 = RemmsResume()
        IF Q1 THEN Lost = 1
      ENDIF
    ENDIF
  ENDIF
  IF NOT ModemOpen()
    CLOSE #ModemCh
    OPEN #ModemCh, 12, 0, "E:"
  ENDIF
  RemmsApplyRoute()
ENDFUNC

' Waits for a character from the caller or from the sysop keyboard and
' shows it on the screen.  Returns 24 (CTRL-X) when the line is lost
FUNC GetChr()
  LOCAL C, Start, Idle
  IF Lost THEN RETURN 24
  Start = TIME
  DO
    IF LocalMode
      IF PEEK(764) <> 255
        GET #KbdCh, C
        RETURN C
      ENDIF
    ELSE
      IF RemmsStatus()
        ' Terminal detection needs raw CR.  Once ASCII mode is selected,
        ' use REMMS text input so CR/LF and editing keys are canonical ATASCII.
        IF AMode
          C = RemmsGet()
        ELSE
          C = RemmsTextGet()
        ENDIF
        IF Lost OR C < 0 THEN RETURN 24
        IF NOT NoEcho THEN PUT C
        RETURN C
      ENDIF
      IF PEEK(764) <> 255
        GET #KbdCh, C
        IF NOT NoEcho THEN PUT C
        RETURN C
      ENDIF
      ' Every 10 seconds without input reopen the channel, as the
      ' original did; hang up after IdleMinutes
      IF TIME - Start > 10 * Fps
        Q1 = RemmsStatus()
        IF Lost THEN RETURN 24
        Start = TIME
        INC Idle
        IF Idle >= IdleMinutes * 6
          PRINT "IDLE TIMEOUT"
          Lost = 1
          RETURN 24
        ENDIF
      ENDIF
    ENDIF
    UpdateClock()
  LOOP
ENDFUNC

' Reads a raw byte from the modem without showing it, or -1 after Limit
' frames
FUNC GetRaw(Limit)
  LOCAL Start, C
  Start = TIME
  DO
    IF RemmsStatus()
      C = RemmsGet()
      RETURN C
    ENDIF
    IF Lost THEN RETURN -1
    IF TIME - Start > Limit THEN RETURN -1
    UpdateClock()
  LOOP
ENDFUNC

' Reads and drops the characters waiting from the modem, showing them
' on the screen when Echo is 1
FUNC DrainInput(Echo)
  LOCAL C
  IF LocalMode THEN RETURN
  DO
    IF NOT RemmsStatus() THEN EXIT
    C = RemmsGet()
    IF C < 0 THEN EXIT
    IF Echo THEN PUT C
  LOOP
ENDFUNC

' Called between pieces of output.  CTRL-S pauses until the next key.
' K: returns ATASCII control keys (147/152), while an ASCII terminal
' returns 19/24, so normalize both forms to 24 = CTRL-X.
FUNC CheckPause()
  LOCAL C
  WaitSent()
  IF Lost THEN RETURN 24
  IF PEEK(764) = 255
    IF LocalMode THEN RETURN 0
    IF NOT RemmsStatus() THEN RETURN 0
  ENDIF
  C = GetChr()
  IF C = 19 OR C = 147 THEN C = GetChr()
  IF C = 152 THEN C = 24
  RETURN C
ENDFUNC

' Reads a line from the caller into L$, at most Il characters, with
' echo, backspace and delete line (GLINE of the original).
' SELECT on the console when it starts breaks into chat mode
FUNC GLine()
  LOCAL C, N, K
  L$ = ""
  IF PEEK(53279) = 5
    Chat()
    RETURN
  ENDIF
  DO
    C = GetChr()
    IF Lost
      L$ = ""
      RETURN
    ENDIF
    N = LEN(L$)
    IF C = 155
      PRINT #ModemCh,
      RETURN
    ELIF C = ControlChar(1) OR (C = 127 AND NOT AMode)
      IF N > 0
        PRINT #ModemCh; CHR$(ControlChar(1)); " "; CHR$(ControlChar(1));
        L$ = L$[1, N - 1]
      ENDIF
    ELIF C = ControlChar(2)
      FOR K = 1 TO N
        PRINT #ModemCh; CHR$(ControlChar(1)); " "; CHR$(ControlChar(1));
      NEXT K
      L$ = ""
    ELSE
      PUT #ModemCh, C
      L$ =+ CHR$(C)
      IF N + 1 >= Il
        PRINT #ModemCh,
        RETURN
      ENDIF
      IF N + 1 >= Il - 3 THEN PUT #ModemCh, ControlChar(0)
    ENDIF
  LOOP
ENDFUNC

' Asks a yes or no question; returns 1 for Y
FUNC YesNo()
  LOCAL C
  DO
    PRINT #ModemCh; " <Y/N>";
    C = GetChr()
    IF Lost THEN RETURN 0
    IF C > 96 THEN C = C - 32
    IF C = 89
      PRINT #ModemCh; "Y"
      RETURN 1
    ENDIF
    IF C = 78
      PRINT #ModemCh; "N"
      RETURN 0
    ENDIF
    OpenModem()
  LOOP
ENDFUNC

' Sends Buf to the caller in pieces of 8 characters, so that the caller
' can pause or stop.  Returns the last key (24 or 152 = stopped)
FUNC SendRaw()
  LOCAL F, N, C
  IF BufLen = 0 THEN RETURN 0
  IF NOT LocalMode THEN BPUT #0, ADR(Buf), BufLen
  WHILE F < BufLen
    N = BufLen - F
    IF N > 8 THEN N = 8
    BPUT #ModemCh, ADR(Buf) + F, N
    F = F + N
    IF F < BufLen
      C = CheckPause()
      IF C = 24 OR C = 152
        PRINT #ModemCh,
        PRINT #ModemCh; "Interrupted"
        RETURN C
      ENDIF
    ENDIF
  WEND
  RETURN C
ENDFUNC

' Sends Buf as a text, with the CTRL-S/CTRL-X help first when Help is 1
' (lines 160 and 170 of the original)
FUNC SendBuf(Help)
  LOCAL C
  IF Help AND NOT XMode THEN PRINT #ModemCh; CtrlMsg$
  PRINT #ModemCh,
  IF RawText
    ' NAME.TXT is already ASCII: bypass the R: ATASCII translation.
    RawText = 0
    AMode = 32
    OpenModem()
    C = SendRaw()
    AMode = 0
    OpenModem()
  ELSE
    C = SendRaw()
  ENDIF
  IF C <> 24 AND C <> 152 THEN PRINT #ModemCh,
  RETURN C
ENDFUNC

' Sends one line to the caller in pieces of 8 characters.
' Returns the last key (24 = stopped)
FUNC SendLine(Text$)
  LOCAL F, C, N
  N = LEN(Text$)
  F = 1
  WHILE F <= N
    PRINT #ModemCh; Text$[F, 8];
    F = F + 8
    C = CheckPause()
    IF C = 24
      PRINT #ModemCh,
      RETURN C
    ENDIF
  WEND
  PRINT #ModemCh,
  RETURN C
ENDFUNC

' Changes the characters of T$ from position First to inverse video
FUNC SetInverse(First)
  Q2 = ADR(T$)
  FOR Q1 = First TO LEN(T$)
    POKE Q2 + Q1, PEEK(Q2 + Q1) ! 128
  NEXT Q1
ENDFUNC

' Checks the result of a PRINT to the log printer; turns the log off
' after an error, so a missing printer does not slow the BBS
FUNC LogCheck()
  Q1 = ERR()
  IF LogOk AND Q1 <> 1
    LogOk = 0
    CLOSE #LogCh
    PRINT "PRINTER LOG OFF, ERROR "; Q1
  ENDIF
ENDFUNC
