' Per-module attachment to REMMS and normal BBS devices.

FUNC AttachModule(App)
  IF NOT RemmsDiscover()
    PRINT "REMMS 1.10 / SESSION 9 NOT RESIDENT"
    PRINT "LOAD REMMS.COM BEFORE WFC"
    END
  ENDIF
  SerialReady = RemmsHasR()
  IF SerialReady
    IF USR(@REMMS_CALL0, RemmsApi) <> 0
      PRINT "REMMS COULD NOT INSTALL R: WRAPPERS"
      END
    ENDIF
  ENDIF
  CurrentApp = App
  RemmsLoadSession()
  CurrentApp = App
  IF Fps = 0
    Fps = 60
    IF (PEEK($D014) & 14) = 0 THEN Fps = 50
  ENDIF
  IF LastTick = 0 THEN LastTick = TIME
  CLOSE #ModemCh
  CLOSE #KbdCh
  OPEN #ModemCh, 12, 0, "E:"
  OPEN #KbdCh, 4, 0, "K:"
  LogOk = 0
  IF UsePrinter
    CLOSE #LogCh
    OPEN #LogCh, 8, 0, "P:"
    IF ERR() = 1 THEN LogOk = 1
  ENDIF
  RemmsApplyRoute()
ENDFUNC

FUNC LoadSystemMeta()
  CLOSE #FileCh
  OPEN #FileCh, 4, 0, SystemFile$
  INPUT #FileCh, CSect, CByte, CallNo
  St = ERR()
  CLOSE #FileCh
  IF St <> 1 AND St <> 136
    PRINT "CAN'T READ "; SystemFile$; ", ERROR "; St
    PRINT "RUN CONFIG AND INITIALIZE FIRST"
    RETURN 0
  ENDIF
  RETURN 1
ENDFUNC

FUNC SetPrompt()
  IF XMode
    Prompt$ = "OK >"
  ELSE
    Prompt$ = "A,B,C,D,F,G,H,L,M,T,W,X,Y,Z,? >"
  ENDIF
ENDFUNC
