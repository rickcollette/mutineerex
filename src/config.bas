' ====================================================================
' CONFIG - non-destructive administration console for Mutineer-eX
' ====================================================================
' INIT.COM creates a new board.  CONFIG.COM changes settings and manages
' message bases, downloadable files and users without reinitializing it.

INCLUDE "settings.bas"

DATA BaudCodes() BYTE = 8, 10, 12, 13, 14, 15
DATA BaudRates() WORD = 300, 1200, 2400, 4800, 9600, 19200

DIM Changed, Choice, Value, Status, Count, K, Found
DIM MSect, MByte, CSect, CByte, Msgs, HMsg, BaseId, BaseMin, UserLevel
DIM Blank(124) BYTE
DIM BasePresent(25) BYTE, BaseLevel(25) BYTE

InitSettings()
In$ = "" : F$ = "" : S$ = "" : T$ = ""
Name$ = "" : Desc$ = "" : City$ = "" : Pass$ = ""
Target$ = "" : NewName$ = "" : OldName$ = ""
BaseName$ = "" : BaseDesc$ = ""
Blank(124) = 155

GRAPHICS 0
POKE 82, 1
Status = LoadSettings()
IF Status = 170
  PRINT "NO "; CfgFile$; " - RUN INIT FIRST"
  PRINT "DEFAULTS ARE LOADED FOR THIS SESSION"
  PAUSE 120
ELIF Status <> 1
  PRINT "INVALID "; CfgFile$; " - RUN INIT"
  PRINT "ERROR "; Status; " READING CONFIGURATION"
  PRINT "DEFAULTS ARE LOADED FOR THIS SESSION"
  PAUSE 120
ENDIF

DO
  CLS
  PRINT "     Mutineer-eX 1.0.7 CONFIG"
  PRINT "     ------------------------"
  PRINT
  PRINT " 1 GENERAL CONFIG"
  PRINT " 2 MESSAGE BASES"
  PRINT " 3 FILE AREAS"
  PRINT " 4 USER EDITOR"
  PRINT " 5 RAMDISK FILES"
  PRINT
  PRINT " Q QUIT"
  PRINT
  INPUT "CHOICE >"; In$
  In$ = UCASE$(In$)
  IF In$ = "1"
    GeneralConfig()
  ELIF In$ = "2"
    MessageBaseManager()
  ELIF In$ = "3"
    FileAreaManager()
  ELIF In$ = "4"
    UserEditor()
  ELIF In$ = "5"
    IF Changed
      PRINT "SAVE GENERAL SETTINGS FIRST"
      PAUSE 90
    ELSE
      RUN "D1:rdconf.com"
    ENDIF
  ELIF In$ = "Q"
    IF NOT Changed THEN EXIT
    PRINT "QUIT WITH UNSAVED SETTINGS (Y/N) >";
    IF AskYes() THEN EXIT
  ENDIF
LOOP
POKE 82, 2
END

INCLUDE "config_common.bas"
INCLUDE "config_general.bas"
INCLUDE "config_messages.bas"
INCLUDE "config_files.bas"
INCLUDE "config_users.bas"
