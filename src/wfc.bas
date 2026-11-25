INCLUDE "module_common.bas"
ModuleImage = 1
INCLUDE "module_env.bas"
INCLUDE "areas_runtime.bas"
Q1 = USR(@BIND_AREA_STRINGS)

AttachModule(1)
InitializeClock()
IF NOT LoadSystemMeta() THEN END
DO
  CurrentApp = 1
  NextApp = 1
  RemmsSaveSession()
  Q1 = WaitForCall()
  IF Q1 = 0 THEN END
  PRINT CHR$(125)
  POKE 82, 2
  CurrentApp = 2
  NextApp = 2
  RemmsSaveSession()
  IF LoginCaller()
    RemmsSaveSession()
    FileName$ = "D1:mainbbs.com"
    Q1 = ResolveCachePath()
    RunModule(FileName$, 3, "MAINBBS")
  ENDIF
  SaveSystemMeta()
LOOP

INCLUDE "clock.bas"
INCLUDE "clock_start.bas"
INCLUDE "remms.bas"
INCLUDE "module_support.bas"
INCLUDE "modem.bas"
INCLUDE "chat.bas"
INCLUDE "textio.bas"
INCLUDE "message_base.bas"
INCLUDE "callers.bas"
INCLUDE "users.bas"
INCLUDE "login_flow.bas"
INCLUDE "wfc_flow.bas"
