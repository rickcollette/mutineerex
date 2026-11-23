INCLUDE "module_common.bas"
ModuleImage = 3
INCLUDE "module_env.bas"

AttachModule(3)
IF NOT LoadSystemMeta() THEN END
MainBbsLoop()
SaveSystemMeta()
FileName$ = "D1:"
IF StartOption(2) THEN FileName$ = "O:"
FileName$ =+ "wfc.com"
RunModule(FileName$, 1, "WFC")

INCLUDE "clock.bas"
INCLUDE "remms.bas"
INCLUDE "module_support.bas"
INCLUDE "modem.bas"
INCLUDE "chat.bas"
INCLUDE "textio.bas"
INCLUDE "callers.bas"
INCLUDE "users.bas"
INCLUDE "main_loop.bas"
