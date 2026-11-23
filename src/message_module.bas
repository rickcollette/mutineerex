INCLUDE "module_common.bas"
ModuleImage = 4
INCLUDE "module_env.bas"

AttachModule(4)
IF NOT LoadSystemMeta() THEN END
IF ActiveBase >= 0
  CloseModem()
  ReadBaseMeta(ActiveBase)
  OpenModem()
ELSE
  LoadDefaultBase()
ENDIF
MessageLoop()
IF Lost
  SaveSystemMeta()
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
INCLUDE "textio.bas"
INCLUDE "names.bas"
INCLUDE "message_base.bas"
INCLUDE "messages.bas"
INCLUDE "message_loop.bas"
