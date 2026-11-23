INCLUDE "module_common.bas"
ModuleImage = 6
INCLUDE "module_env.bas"

AttachModule(6)
IF NOT LoadSystemMeta() THEN END
DoorLoop()
IF Lost
  FileName$ = "D1:wfc.com"
  Q1 = ResolveCachePath()
  RunModule(FileName$, 1, "WFC")
ENDIF
FileName$ = "D1:mainbbs.com"
Q1 = ResolveCachePath()
RunModule(FileName$, 3, "MAINBBS")

INCLUDE "clock.bas"
INCLUDE "remms.bas"
INCLUDE "module_support.bas"
INCLUDE "modem.bas"
INCLUDE "chat.bas"
INCLUDE "door_loop.bas"
