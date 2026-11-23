' Sysop chat is shared by every module that accepts a line of input.

FUNC Chat()
  LOCAL C, D
  PRINT "IN CHAT MODE"
  PRINT #ModemCh; "CHAT MODE: PRESS CTRL<X> TO END"
  POKE 764, 255
  DO
    IF Lost THEN EXIT
    C = -1
    IF NOT LocalMode AND RemmsStatus()
      C = RemmsGet()
      IF C >= 0
        PRINT #ModemCh; CHR$(C);
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
        PRINT #ModemCh; CHR$(C);
      ENDIF
      IF NOT LocalMode OR C <> 126 THEN PUT C
    ENDIF
    IF C = 24 THEN EXIT
    UpdateClock()
  LOOP
ENDFUNC
