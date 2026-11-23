INCLUDE "module_common.bas"
ModuleImage = 5
INCLUDE "module_env.bas"

AttachModule(5)
IF NOT LoadSystemMeta() THEN END
FileLoop()
IF Lost
  SaveSystemMeta()
  FileName$ = "D1:"
  IF StartOption(2) THEN FileName$ = "O:"
  FileName$ =+ "wfc.com"
  RunModule(FileName$, 1, "WFC")
ENDIF
FileName$ = "D1:"
IF StartOption(2) THEN FileName$ = "O:"
FileName$ =+ "mainbbs.com"
RunModule(FileName$, 3, "MAINBBS")

INCLUDE "clock.bas"
INCLUDE "remms.bas"
INCLUDE "module_support.bas"
INCLUDE "modem.bas"
INCLUDE "chat.bas"
INCLUDE "files.bas"
INCLUDE "transfer.bas"
INCLUDE "file_loop.bas"
