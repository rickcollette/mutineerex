' ====================================================================
' RDCONF - EOS/SDX RAM-disk cache planner and multi-select editor
' ====================================================================

INCLUDE "settings.bas"

' 96 flat 8.3 candidates, each stored as a compact 48-byte string record.
DIM FileSpecs(4607) BYTE
DIM FileSectors(95) WORD
DIM Selected(95) BYTE
DIM IoBuf(254) BYTE
DIM Count, Status, K, J, G, Page, Choice, Capacity, Needed, Saved, Code
DIM ExistingCount, ExistingUsed, FreeSectors, Got, Remain, P, C
DIM WfcRam, RemmsRam, Handler850Ram, ApeRam, DriverRam, IsSdx
DIM In$, S$, T$, F$, Name$, Spec$, Ext$, Drive$

InitSettings()
Status = LoadSettings()
IsSdx = DetectSdx()
GRAPHICS 0
POKE 82, 1
CLOSE #1
OPEN #1, 4, 0, "D1:RAMCACHE.APPLY"
IF ERR() = 1
  CLOSE #1
  XIO 33, #1, 0, 0, "D1:RAMCACHE.APPLY"
  Status = WriteBootFiles()
  IF Status = 1
    PRINT "SETTINGS AND STARTUP SAVED"
  ELSE
    PRINT "STARTUP SAVE ERROR "; Status
  ENDIF
  PAUSE 90
  RUN "D1:config.com"
  END
ENDIF
CLOSE #1
PRINT "SCANNING RAM-CACHE CANDIDATES..."
DiscoverFiles()
LoadManifest()
ReadRamCapacity()

DO
  ShowPlanner()
  INPUT "CHOICE >"; In$
  In$ = UCASE$(In$)
  Choice = VAL(In$)
  IF Choice >= 1 AND Choice <= 6
    ToggleGroup(Choice - 1)
  ELIF In$ = "P"
    PickFiles()
  ELIF In$ = "R"
    PRINT "RESCANNING..."
    DiscoverFiles()
    LoadManifest()
    ReadRamCapacity()
  ELIF In$ = "S"
    SaveManifest()
  ELIF In$ = "X"
    EXIT
  ENDIF
LOOP
RUN "D1:config.com"
END

FUNC DetectSdx()
  LOCAL Result
  CLOSE #3
  OPEN #3, 4, 0, "D1:SDX.ENV"
  Result = ERR() = 1
  CLOSE #3
  RETURN Result
ENDFUNC

FUNC ParseCacheLine()
  LOCAL Q, Ch
  F$ = S$ : Drive$ = ""
  Q = INSTR(S$, "|")
  IF Q > 1 AND Q < LEN(S$)
    F$ = S$[1, Q - 1]
    Drive$ = S$[Q + 1, LEN(S$) - Q]
    RETURN 1
  ENDIF
  ' Version 1 compatibility: synthesize the formerly implicit target.
  Q = 0
  FOR Ch = 1 TO LEN(F$)
    IF PEEK(ADR(F$) + Ch) = 58 OR PEEK(ADR(F$) + Ch) = 47 OR PEEK(ADR(F$) + Ch) = 92 OR PEEK(ADR(F$) + Ch) = 62 THEN Q = Ch
  NEXT Ch
  IF Q = 0 OR Q >= LEN(F$) THEN RETURN 0
  IF IsSdx
    Drive$ = "DO:"
  ELSE
    Drive$ = "O:"
  ENDIF
  Drive$ =+ F$[Q + 1, LEN(F$) - Q]
  RETURN 1
ENDFUNC

FUNC CacheName$()
  LOCAL Q, Ch
  Q = 0
  FOR Ch = 1 TO LEN(Drive$)
    IF PEEK(ADR(Drive$) + Ch) = 58 OR PEEK(ADR(Drive$) + Ch) = 47 OR PEEK(ADR(Drive$) + Ch) = 92 OR PEEK(ADR(Drive$) + Ch) = 62 THEN Q = Ch
  NEXT Ch
  IF Q > 0 AND Q < LEN(Drive$) THEN RETURN Drive$[Q + 1, LEN(Drive$) - Q]
  RETURN ""
ENDFUNC

FUNC GroupExt$(N)
  IF N = 0 THEN RETURN "COM"
  IF N = 1 THEN RETURN "ATA"
  IF N = 2 THEN RETURN "TXT"
  IF N = 3 THEN RETURN "V52"
  IF N = 4 THEN RETURN "RIP"
  RETURN "IG"
ENDFUNC

FUNC ExtensionGroup(E$)
  E$ = UCASE$(E$)
  FOR G = 0 TO 5
    IF E$ = GroupExt$(G) THEN RETURN G
  NEXT G
  RETURN -1
ENDFUNC

FUNC DirectoryExtra(N)
  ' Empty filesystems already own one main-directory data sector and map.
  IF IsSdx THEN RETURN ((N + 1) * 23 + 255) / 256 - 1
  RETURN ((N + 1) * 44 + 255) / 256 - 1
ENDFUNC

FUNC CountFileSectors(Path$)
  LOCAL Code, N, Total
  CLOSE #2
  OPEN #2, 4, 0, Path$
  Code = ERR()
  IF Code <> 1 THEN CLOSE #2 : RETURN 999
  Remain = 0
  DO
    BGET #2, ADR(IoBuf), 255
    Code = ERR()
    Got = 0
    IF Code = 1 THEN Got = DPEEK($348 + 32)
    IF Got > 0
      Remain = Remain + Got
      WHILE Remain > 255
        INC Total
        Remain = Remain - 256
      WEND
    ENDIF
    IF Code <> 1 OR Got = 0 THEN EXIT
  LOOP
  CLOSE #2
  IF Remain > 0 THEN INC Total
  RETURN Total
ENDFUNC

FUNC FindSpec(Path$)
  FOR K = 0 TO Count - 1
    IF UCASE$($(ADR(FileSpecs) + K * 48)) = UCASE$(Path$) THEN RETURN K
  NEXT K
  RETURN -1
ENDFUNC

FUNC AddDirectoryLine(Path$)
  LOCAL N
  IF IsSdx
    IF LEN(S$) < 41 OR S$[36, 1] <> ":" THEN RETURN
    Ext$ = UCASE$(S$[10, 3])
  ELSE
    Ext$ = UCASE$(S$[11, 3])
  ENDIF
  IF ExtensionGroup(Ext$) < 0 OR Count > 95 THEN RETURN
  Name$ = ""
  IF IsSdx THEN P = 1 ELSE P = 3
  FOR J = P TO P + 7
    C = PEEK(ADR(S$) + J)
    IF C <> 32 THEN Name$ =+ CHR$(C)
  NEXT J
  Name$ =+ "." : Name$ =+ Ext$
  Spec$ = Path$ : Spec$ =+ Name$
  IF LEN(Spec$) > 47 OR FindSpec(Spec$) >= 0 THEN RETURN
  IF IsSdx THEN N = CountFileSectors(Spec$) ELSE N = VAL(S$[15, 3])
  IF N >= 999 THEN N = CountFileSectors(Spec$)
  MOVE ADR(Spec$), ADR(FileSpecs) + Count * 48, LEN(Spec$) + 1
  FileSectors(Count) = N
  Selected(Count) = 0
  INC Count
ENDFUNC

FUNC ScanDrive(Path$)
  CLOSE #1
  F$ = Path$ : F$ =+ "*.???"
  OPEN #1, 6, 0, F$
  IF ERR() <> 1 THEN CLOSE #1 : RETURN
  DO
    INPUT #1, S$
    Status = ERR()
    IF Status <> 1 OR INSTR(S$, "FREE SECTORS") > 0 THEN EXIT
    IF LEN(S$) >= 17 THEN AddDirectoryLine(Path$)
  LOOP
  CLOSE #1
ENDFUNC

FUNC DiscoverFiles()
  Count = 0
  ScanDrive("D1:")
  IF UCASE$(TextDrive$) <> "D1:" THEN ScanDrive(TextDrive$)
  IF UCASE$(FileDrive$) <> "D1:" AND UCASE$(FileDrive$) <> UCASE$(TextDrive$) THEN ScanDrive(FileDrive$)
ENDFUNC

FUNC LoadManifest()
  FOR K = 0 TO Count - 1
    Selected(K) = 0
  NEXT K
  CLOSE #1
  OPEN #1, 4, 0, "D1:RAMCACHE.CFG"
  IF ERR() <> 1 THEN CLOSE #1 : RETURN
  INPUT #1, S$
  Status = ERR()
  IF Status <> 1 THEN CLOSE #1 : RETURN
  IF S$ <> "MUTINREX RAMCACHE 1" AND S$ <> "MUTINREX RAMCACHE 2" THEN CLOSE #1 : RETURN
  DO
    INPUT #1, S$
    Status = ERR()
    IF Status <> 1 THEN EXIT
    Status = ParseCacheLine()
    K = FindSpec(F$)
    IF K >= 0 THEN Selected(K) = 1
  LOOP
  CLOSE #1
ENDFUNC

FUNC ParseDirectoryName()
  Name$ = ""
  IF IsSdx THEN P = 1 ELSE P = 3
  FOR J = P TO P + 7
    C = PEEK(ADR(S$) + J)
    IF C <> 32 THEN Name$ =+ CHR$(C)
  NEXT J
  IF IsSdx THEN T$ = S$[10, 3] ELSE T$ = S$[11, 3]
  IF T$ <> "   "
    Name$ =+ "."
    FOR J = 1 TO 3
      C = PEEK(ADR(T$) + J)
      IF C <> 32 THEN Name$ =+ CHR$(C)
    NEXT J
  ENDIF
ENDFUNC

FUNC ReadRamCapacity()
  Capacity = 0
  ExistingCount = 0
  ExistingUsed = 0
  FreeSectors = 0
  CLOSE #1
  OPEN #1, 6, 0, "DO:*.*"
  IF ERR() <> 1 THEN CLOSE #1 : RETURN
  DO
    INPUT #1, S$
    Status = ERR()
    IF Status <> 1 THEN EXIT
    IF INSTR(S$, "FREE SECTORS") > 0
      FreeSectors = VAL(S$)
      EXIT
    ENDIF
    IF IsSdx AND LEN(S$) >= 41 AND S$[36, 1] = ":"
      ParseDirectoryName()
      Spec$ = "DO:" : Spec$ =+ Name$
      K = CountFileSectors(Spec$)
      ExistingUsed = ExistingUsed + K + 1
      INC ExistingCount
    ELIF NOT IsSdx AND LEN(S$) >= 17 AND PEEK(ADR(S$) + 2) <> 58
      ParseDirectoryName()
      Spec$ = "DO:" : Spec$ =+ Name$
      K = VAL(S$[15, 3])
      IF K >= 999 THEN K = CountFileSectors(Spec$)
      ExistingUsed = ExistingUsed + K + 1
      INC ExistingCount
    ENDIF
  LOOP
  CLOSE #1
  IF Status = 1 OR Status = 136
    Capacity = FreeSectors + ExistingUsed + DirectoryExtra(ExistingCount)
  ENDIF
ENDFUNC

FUNC NeededSectors()
  LOCAL N, Files
  FOR K = 0 TO Count - 1
    IF Selected(K)
      N = N + FileSectors(K) + 1
      INC Files
    ENDIF
  NEXT K
  RETURN N + DirectoryExtra(Files)
ENDFUNC

FUNC GroupState$(N)
  LOCAL All, On
  Ext$ = GroupExt$(N)
  FOR K = 0 TO Count - 1
    Spec$ = $(ADR(FileSpecs) + K * 48)
    P = INSTR(Spec$, ".")
    IF P > 0 AND UCASE$(Spec$[P + 1, 3]) = Ext$
      INC All
      IF Selected(K) THEN INC On
    ENDIF
  NEXT K
  IF All = 0 THEN RETURN "NONE"
  IF On = 0 THEN RETURN "OFF"
  IF On = All THEN RETURN "ALL"
  RETURN "SOME"
ENDFUNC

FUNC ToggleGroup(N)
  LOCAL TurnOn
  T$ = GroupState$(N)
  TurnOn = T$ <> "ALL"
  Ext$ = GroupExt$(N)
  FOR K = 0 TO Count - 1
    Spec$ = $(ADR(FileSpecs) + K * 48)
    P = INSTR(Spec$, ".")
    IF P > 0 AND UCASE$(Spec$[P + 1, 3]) = Ext$ THEN Selected(K) = TurnOn
  NEXT K
ENDFUNC

FUNC ShowPlanner()
  CLS
  Needed = NeededSectors()
  PRINT "       RAMDISK FILE PLANNER"
  PRINT "       --------------------"
  IF Capacity > 0
    PRINT "O: CAPACITY "; Capacity; " SECTORS ("; (Capacity + 3) / 4; " KB)"
    PRINT "SELECTED    "; Needed; " SECTORS ("; (Needed + 3) / 4; " KB)"
    IF Needed <= Capacity
      PRINT "RESULT      FITS, "; Capacity - Needed; " SECTORS FREE"
    ELSE
      PRINT "RESULT      OVER BY "; Needed - Capacity; " SECTORS"
    ENDIF
  ELSE
    PRINT "O: NOT INSTALLED - CAPACITY UNKNOWN"
    PRINT "ENABLE RAM CACHE, COLD BOOT, RERUN"
  ENDIF
  PRINT
  FOR G = 0 TO 5
    PRINT G + 1; " ["; GroupState$(G); "] ALL ."; GroupExt$(G); " FILES"
  NEXT G
  PRINT
  PRINT "P PICK FILES  R RESCAN  S SAVE  X BACK"
ENDFUNC

FUNC CandidateFits(N)
  LOCAL Was, Total
  Was = Selected(N)
  Selected(N) = 1
  Total = NeededSectors()
  Selected(N) = Was
  RETURN Capacity = 0 OR Total <= Capacity
ENDFUNC

FUNC PickFiles()
  Page = 0
  DO
    CLS
    PRINT "RAMDISK FILES "; Page * 9 + 1; "-"; Page * 9 + 9; " OF "; Count
    PRINT "# LOAD SOURCE                SIZE"
    FOR J = 0 TO 8
      K = Page * 9 + J
      IF K < Count
        Spec$ = $(ADR(FileSpecs) + K * 48)
        PRINT J + 1; " ";
        IF Selected(K)
          PRINT "[R] ";
        ELIF CandidateFits(K)
          PRINT "[D] ";
        ELSE
          PRINT "[!] ";
        ENDIF
        PRINT Spec$[1, 23]; " "; FileSectors(K); "S"
      ENDIF
    NEXT J
    PRINT
    PRINT "1-9 TOGGLE  N NEXT  P PREV  X BACK"
    PRINT "[!] WILL NOT FIT WITH SELECTION"
    INPUT "CHOICE >"; In$
    In$ = UCASE$(In$)
    Choice = VAL(In$)
    IF Choice >= 1 AND Choice <= 9
      K = Page * 9 + Choice - 1
      IF K < Count THEN Selected(K) = NOT Selected(K)
    ELIF In$ = "N" AND (Page + 1) * 9 < Count
      INC Page
    ELIF In$ = "P" AND Page > 0
      DEC Page
    ELIF In$ = "X"
      RETURN
    ENDIF
  LOOP
ENDFUNC

FUNC WriteSystem()
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

FUNC WriteStartup()
  WfcRam = 0 : RemmsRam = 0 : Handler850Ram = 0 : ApeRam = 0
  CLOSE #1
  IF RDriver = 0 AND AutoStart = 0
    XIO 33, #1, 0, 0, "D1:eosauto.bat"
    RETURN 1
  ENDIF
  OPEN #1, 8, 0, "D1:eosauto.bat"
  PRINT #1; "SET PATH=CAR:;D1:"
  IF AutoStart AND StartOption(2)
    PRINT #1; "FORMAT /QQ O:"
    CLOSE #2
    OPEN #2, 4, 0, "D1:RAMCACHE.CFG"
    Code = ERR()
    IF Code = 1
      INPUT #2, S$
      Code = ERR()
      Status = 0
      IF S$ = "MUTINREX RAMCACHE 1" THEN Status = 1
      IF S$ = "MUTINREX RAMCACHE 2" THEN Status = 1
      IF Code = 1 AND Status
        DO
          INPUT #2, S$
          Code = ERR()
          IF Code <> 1 THEN EXIT
          IF ParseCacheLine()
            T$ = CacheName$()
            PRINT #1; "ECHO COPYING "; F$; " -> RAMDISK:"; T$
            PRINT #1; "cp "; F$; " O:"; T$
            IF UCASE$(F$) = "D1:WFC.COM" THEN WfcRam = 1
            IF UCASE$(F$) = "D1:REMMS.COM" THEN RemmsRam = 1
            IF UCASE$(F$) = "D1:RS232.COM" THEN Handler850Ram = 1
            IF UCASE$(F$) = "D1:APETIME.COM" THEN ApeRam = 1
          ENDIF
        LOOP
      ENDIF
    ENDIF
    CLOSE #2
    PRINT #1; "SET PATH=CAR:;O:;D1:"
  ENDIF
  IF RDriver = 1
    IF Handler850Ram
      PRINT #1; "O:rs232.com"
    ELSE
      PRINT #1; "D1:rs232.com"
    ENDIF
  ENDIF
  IF RemmsRam
    PRINT #1; "O:remms.com"
  ELSE
    PRINT #1; "D1:remms.com"
  ENDIF
  IF AutoStart
    IF StartOption(1) = 2
      IF ApeRam
        PRINT #1; "DO:apetime.com >>D1:APETIME.TXT"
      ELSE
        PRINT #1; "D1:apetime.com >>D1:APETIME.TXT"
      ENDIF
    ENDIF
    PRINT #1; "SET DAYTIME=1"
    IF StartOption(1) > 0
      PRINT #1; "DATE /T >>D1:BBSDATE.TXT"
      PRINT #1; "TIME /T >>D1:BBSTIME.TXT"
    ENDIF
    IF StartOption(0)
      IF WfcRam
        PRINT #1; "X DO:wfc.com"
      ELSE
        PRINT #1; "X D1:wfc.com"
      ENDIF
    ELSE
      IF WfcRam
        PRINT #1; "DO:wfc.com"
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

FUNC WriteSdxStartup()
  WfcRam = 0 : RemmsRam = 0 : Handler850Ram = 0 : ApeRam = 0 : DriverRam = 0
  CLOSE #1
  IF RDriver = 0 AND AutoStart = 0
    XIO 33, #1, 0, 0, "D1:AUTOEXEC.BAT"
    RETURN 1
  ENDIF
  XIO 33, #1, 0, 0, "D1:AUTOEXEC.BAT"
  CLOSE #1
  OPEN #1, 8, 0, "D1:AUTOEXEC.BAT"
  Code = ERR()
  IF Code <> 1 THEN CLOSE #1 : RETURN Code
  PRINT #1; "ECHO MUTINEER-EX STARTS IN 5 SECONDS"
  PRINT #1; "ECHO PRESS BREAK FOR THE SDX PROMPT"
  PRINT #1; "PAUSE 5"
  IF AutoStart AND StartOption(2)
    ' SDX /QQ prepares O: without the formatter menu or clear-disk prompt.
    PRINT #1; "FORMAT /QQ O: MUTINREX"
    CLOSE #2
    OPEN #2, 4, 0, "D1:RAMCACHE.CFG"
    Code = ERR()
    IF Code = 1
      INPUT #2, S$
      Code = ERR()
      Status = 0
      IF S$ = "MUTINREX RAMCACHE 1" THEN Status = 1
      IF S$ = "MUTINREX RAMCACHE 2" THEN Status = 1
      IF Code = 1 AND Status
        DO
          INPUT #2, S$
          Code = ERR()
          IF Code <> 1 THEN EXIT
          IF ParseCacheLine()
            T$ = CacheName$()
            PRINT #1; "ECHO COPYING "; F$; " -> RAMDISK:"; T$
            PRINT #1; "COPY "; F$; " O:"; T$
            IF UCASE$(F$) = "D1:WFC.COM" THEN WfcRam = 1
            IF UCASE$(F$) = "D1:REMMS.COM" THEN RemmsRam = 1
            IF UCASE$(F$) = "D1:RHND850.COM" THEN Handler850Ram = 1
            IF UCASE$(F$) = "D1:APETIME.COM" THEN ApeRam = 1
            IF RDriver = 1 AND UCASE$(F$) = "D1:RHND850.COM" THEN DriverRam = 1
            IF RDriver = 2 AND UCASE$(F$) = "D1:RVRFULL.COM" THEN DriverRam = 1
            IF RDriver = 3 AND UCASE$(F$) = "D1:RVRTWOW.COM" THEN DriverRam = 1
            IF RDriver = 4 AND UCASE$(F$) = "D1:NHAND.COM" THEN DriverRam = 1
          ENDIF
        LOOP
      ENDIF
    ENDIF
    CLOSE #2
  ENDIF
  T$ = ""
  IF RDriver = 1 THEN T$ = "RHND850.COM"
  IF RDriver = 2 THEN T$ = "RVRFULL.COM"
  IF RDriver = 3 THEN T$ = "RVRTWOW.COM"
  IF RDriver = 4 THEN T$ = "NHAND.COM"
  IF LEN(T$) > 0
    IF DriverRam
      PRINT #1; "O:"; T$
    ELSE
      PRINT #1; "D1:"; T$
    ENDIF
  ENDIF
  IF RemmsRam
    PRINT #1; "O:REMMS.COM"
  ELSE
    PRINT #1; "D1:REMMS.COM"
  ENDIF
  IF AutoStart
    IF StartOption(1) = 2
      IF ApeRam
        PRINT #1; "O:APETIME.COM >>D1:APETIME.TXT"
      ELSE
        PRINT #1; "D1:APETIME.COM >>D1:APETIME.TXT"
      ENDIF
    ENDIF
    PRINT #1; "SET DAYTIME=1"
    IF StartOption(1) > 0
      PRINT #1; "DATE /T >>D1:BBSDATE.TXT"
      PRINT #1; "TIME /T >>D1:BBSTIME.TXT"
    ENDIF
    IF StartOption(0) THEN PRINT #1; "X ";
    IF WfcRam
      PRINT #1; "O:WFC.COM"
    ELSE
      PRINT #1; "D1:WFC.COM"
    ENDIF
  ENDIF
  Code = ERR()
  CLOSE #1
  IF Code = 1 THEN Code = ERR()
  RETURN Code
ENDFUNC

FUNC WriteBootFiles()
  IF IsSdx THEN RETURN WriteSdxStartup()
  Status = WriteSystem()
  IF Status = 1 THEN Status = WriteStartup()
  RETURN Status
ENDFUNC

FUNC SaveManifest()
  Needed = NeededSectors()
  IF Capacity > 0 AND Needed > Capacity
    PRINT "SELECTION DOES NOT FIT O:"
    PRINT "REMOVE "; Needed - Capacity; " SECTORS FIRST"
    PAUSE 120
    RETURN
  ENDIF
  CLOSE #1
  OPEN #1, 8, 0, "D1:RAMCACHE.CFG"
  Status = ERR()
  IF Status = 1
    PRINT #1; "MUTINREX RAMCACHE 2"
    FOR K = 0 TO Count - 1
      IF Selected(K)
        F$ = $(ADR(FileSpecs) + K * 48)
        Drive$ = ""
        S$ = F$
        Status = ParseCacheLine()
        IF Status THEN PRINT #1; F$; "|"; Drive$
      ENDIF
    NEXT K
    Status = ERR()
  ENDIF
  CLOSE #1
  IF Status = 1
    Status = WriteBootFiles()
    IF Status = 1
      Saved = 1
      PRINT "RAMCACHE.CFG AND STARTUP SAVED"
      IF Capacity = 0 THEN PRINT "WARNING: FIT COULD NOT BE VERIFIED"
    ELSE
      PRINT "STARTUP SAVE ERROR "; Status
    ENDIF
  ELSE
    PRINT "SAVE ERROR "; Status
  ENDIF
  PAUSE 120
ENDFUNC
