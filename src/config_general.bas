' ====================================================================
' General BBS settings
' ====================================================================

FUNC GeneralConfig()
  DO
    ShowGeneralMenu()
    INPUT "SETTING, S=SAVE, X=BACK >"; In$
    In$ = UCASE$(In$)
    Choice = VAL(In$)
    IF In$ = "S"
      Status = SaveSettings()
      IF Status = 1 THEN Status = WriteSystem()
      IF Status = 1 THEN Status = WriteStartup()
      IF Status = 1
        Changed = 0
        PRINT "SETTINGS SAVED"
      ELSE
        PRINT "SAVE ERROR "; Status
      ENDIF
      PAUSE 90
    ELIF In$ = "D"
      PRINT "RESTORE DEFAULT SETTINGS (Y/N) >";
      IF AskYes()
        DefaultSettings()
        Changed = 1
      ENDIF
    ELIF In$ = "X"
      RETURN
    ELIF Choice >= 1 AND Choice <= 17
      EditSetting(Choice)
    ENDIF
  LOOP
ENDFUNC

FUNC ShowGeneralMenu()
  CLS
  PRINT "       GENERAL CONFIG"
  PRINT "       --------------"
  PRINT " 1 SYSOP   "; SysopName$
  PRINT " 2 PRINTER "; OnOff$(UsePrinter)
  PRINT " 3 CARRIER "; OnOff$(CarrierWatch)
  PRINT " 4 IDLE    "; IdleMinutes; " MIN"
  PRINT " 5 BAUD    "; BaudName(BaudCode)
  PRINT " 6 MODEM   "; ModemInit$
  PRINT " 7 DL CHUNK "; ChunkSize
  PRINT " 8 XMODEM   "; NumSect; " BLOCKS"
  PRINT " 9 DATA     "; DataDrive$
  PRINT "10 MESSAGES "; MsgDrive$
  PRINT "11 TEXT     "; TextDrive$
  PRINT "12 FILES    "; FileDrive$
  PRINT "13 R DRIVER "; RName$(RDriver)
  PRINT "14 AUTOSTART "; OnOff$(AutoStart)
  PRINT "15 START X   "; OnOff$(StartOption(0))
  PRINT "16 CLOCK     "; ClockName$(StartOption(1))
  PRINT "17 RAM CACHE "; OnOff$(StartOption(2))
  PRINT
  PRINT " S SAVE  D DEFAULTS  X BACK"
ENDFUNC

FUNC OnOff$(Flag)
  IF Flag THEN RETURN "ON"
  RETURN "OFF"
ENDFUNC

FUNC RName$(Driver)
  IF Driver = 1 THEN RETURN "RS232"
  IF Driver = 2 THEN RETURN "RVRFULL"
  IF Driver = 3 THEN RETURN "RVRTWOW"
  IF Driver = 4 THEN RETURN "NHAND"
  RETURN "NONE"
ENDFUNC

FUNC ClockName$(Source)
  IF Source = 1 THEN RETURN "EOS/JIFFY"
  IF Source = 2 THEN RETURN "APETIME"
  IF Source = 3 THEN RETURN "R-TIME 8"
  RETURN "MANUAL"
ENDFUNC

FUNC BaudName(Code)
  LOCAL I
  FOR I = 0 TO 5
    IF BaudCodes(I) = Code THEN RETURN BaudRates(I)
  NEXT I
  RETURN 0
ENDFUNC

FUNC WriteStartup()
  LOCAL Code, P
  CLOSE #1
  IF RDriver = 0 AND AutoStart = 0
    XIO 33, #1, 0, 0, "D1:eosauto.bat"
    RETURN 1
  ENDIF
  OPEN #1, 8, 0, "D1:eosauto.bat"
  PRINT #1; "; Written by Mutineer-eX CONFIG"
  PRINT #1; "SET PATH=CAR:;D1:"
  IF AutoStart AND StartOption(2)
    PRINT #1; "ECHO COPYING MUTINREX TO RAMDISK O:"
    PRINT #1; "cp D1:wfc.com O:wfc.com"
    PRINT #1; "cp D1:mainbbs.com O:mainbbs.com"
    PRINT #1; "cp D1:message.com O:message.com"
    PRINT #1; "cp D1:files.com O:files.com"
    PRINT #1; "cp D1:doors.com O:doors.com"
    PRINT #1; "cp D1:bjack.com O:bjack.com"
    PRINT #1; "cp D1:slots.com O:slots.com"
    S$ = "WFC|WELC|BULL|FUNC|HELP|MESGM|FILEM|NEWU"
    DO
      P = INSTR(S$, "|")
      IF P
        T$ = S$[1, P - 1]
      ELSE
        T$ = S$
      ENDIF
      PRINT #1; "cp "; TextDrive$; T$; ".TXT O:"; T$; ".TXT"
      PRINT #1; "cp "; TextDrive$; T$; ".ATA O:"; T$; ".ATA"
      IF NOT P THEN EXIT
      S$ = S$[P + 1, LEN(S$) - P]
    LOOP
    PRINT #1; "SET PATH=CAR:;O:;D1:"
  ENDIF
  ' Current REMMS backends are EOS DEVICE drivers. The older Atari 850
  ' bootstrap must run after boot; it hangs if loaded while EOSSYS is active.
  IF RDriver = 1 THEN PRINT #1; "D1:rs232.com"
  PRINT #1; "D1:remms.com"
  IF AutoStart
    IF StartOption(1) = 2 THEN PRINT #1; "D1:apetime.com >>D1:APETIME.TXT"
    PRINT #1; "SET DAYTIME=1"
    IF StartOption(1) > 0
      PRINT #1; "DATE /T >>D1:BBSDATE.TXT"
      PRINT #1; "TIME /T >>D1:BBSTIME.TXT"
    ENDIF
    IF StartOption(0)
      IF StartOption(2)
        PRINT #1; "X O:wfc.com"
      ELSE
        PRINT #1; "X D1:wfc.com"
      ENDIF
    ELSE
      IF StartOption(2)
        PRINT #1; "O:wfc.com"
      ELSE
        PRINT #1; "D1:wfc.com"
      ENDIF
    ENDIF
  ENDIF
  Code = ERR()
  CLOSE #1
  IF Code = 1 THEN Code = ERR()
  RETURN Code
ENDFUNC

FUNC WriteSystem()
  LOCAL Code
  CLOSE #1
  OPEN #1, 8, 0, "D1:eossys.sys"
  PRINT #1; "SET PATH=CAR:;D1:"
  IF StartOption(1) = 3
    PRINT #1; "DEVICE RTIME8"
  ELSE
    PRINT #1; "DEVICE JIFFY"
  ENDIF
  IF StartOption(2) THEN PRINT #1; "DEVICE RAMDISK"
  IF RDriver = 2 THEN PRINT #1; "DEVICE D1:RVRFULL"
  IF RDriver = 3 THEN PRINT #1; "DEVICE D1:RVRTWOW"
  IF RDriver = 4 THEN PRINT #1; "DEVICE D1:NHAND"
  Code = ERR()
  CLOSE #1
  IF Code = 1 THEN Code = ERR()
  RETURN Code
ENDFUNC

FUNC EditSetting(N)
  LOCAL I
  PRINT
  IF N = 1
    PRINT "SYSOP USER NAME >";
    INPUT ; In$
    IF LEN(In$) >= 3 AND LEN(In$) <= 40 THEN SysopName$ = In$ : Changed = 1
  ELIF N = 2
    UsePrinter = NOT UsePrinter : Changed = 1
  ELIF N = 3
    CarrierWatch = NOT CarrierWatch : Changed = 1
  ELIF N = 4
    IdleMinutes = AskNumber(IdleMinutes, 1, 60) : Changed = 1
  ELIF N = 5
    FOR I = 0 TO 5
      PRINT I + 1; " = "; BaudRates(I)
    NEXT I
    I = AskNumber(0, 1, 6)
    IF I > 0 THEN BaudCode = BaudCodes(I - 1) : Changed = 1
  ELIF N = 6
    PRINT "MODEM INIT >";
    INPUT ; In$
    IF In$ <> "" THEN ModemInit$ = UCASE$(In$)[1, 80] : Changed = 1
  ELIF N = 7
    ChunkSize = AskNumber(ChunkSize, 128, 4096) : Changed = 1
  ELIF N = 8
    NumSect = AskNumber(NumSect, 1, 32) : Changed = 1
  ELIF N >= 9 AND N <= 12
    AskDrive()
    IF In$ <> ""
      IF N = 9 THEN DataDrive$ = In$
      IF N = 10 THEN MsgDrive$ = In$
      IF N = 11 THEN TextDrive$ = In$
      IF N = 12 THEN FileDrive$ = In$
      Changed = 1
    ENDIF
  ELIF N = 13
    FOR I = 0 TO 4
      PRINT I; " = "; RName$(I)
    NEXT I
    RDriver = AskNumber(RDriver, 0, 4) : Changed = 1
  ELIF N = 14
    AutoStart = NOT AutoStart : Changed = 1
  ELIF N = 15
    StartOption(0) = NOT StartOption(0) : Changed = 1
  ELIF N = 16
    PRINT "0 = MANUAL AT EACH START"
    PRINT "1 = CURRENT EOS/JIFFY CLOCK"
    PRINT "2 = APETIME FROM SIO HOST"
    PRINT "3 = R-TIME 8 CLOCK"
    StartOption(1) = AskNumber(StartOption(1), 0, 3) : Changed = 1
  ELIF N = 17
    StartOption(2) = NOT StartOption(2) : Changed = 1
    IF StartOption(2)
      PRINT "NEEDS COMPATIBLE XE RAM"
      PRINT "1088K RECOMMENDED; COLD RESTART"
      PAUSE 120
    ENDIF
  ENDIF
ENDFUNC
