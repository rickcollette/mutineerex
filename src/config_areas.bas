' ====================================================================
' CONFIG support for D1:AREAS.CFG
' ====================================================================

FUNC AreaTitle$(N)
  IF N = 0 THEN RETURN "TEXT"
  IF N = 1 THEN RETURN "GAMES"
  IF N = 2 THEN RETURN "APPLICATIONS"
  IF N = 3 THEN RETURN "TOOLS"
  IF N = 4 THEN RETURN "ARCHIVERS"
  RETURN "UNKNOWN"
ENDFUNC

FUNC AskStoragePath()
  PRINT "PATH (D1:-D8:, RETURN=KEEP)"
  PRINT "CURRENT: "; AreaPath$
  PRINT ">";
  INPUT ; In$
  IF In$ = "" THEN RETURN 1
  AreaPath$ = In$
  IF NOT NormalizeAreaPath()
    PRINT "INVALID PATH; USE 8.3 FOLDERS, 30 CHARACTERS MAX"
    RETURN 0
  ENDIF
  IF NOT EnsureAreaFolder()
    Status = AreaError
    PRINT "CANNOT CREATE OR OPEN "; AreaPath$
    RETURN 0
  ENDIF
  RETURN 1
ENDFUNC

FUNC EmitFileArea(N, Override)
  IF Override AND BaseId = N
    AreaPath$ = Target$
  ELSE
    Status = ResolveFileArea(N)
    IF Status <> 1 THEN RETURN 0
  ENDIF
  AreaLine$ = "F|" : AreaLine$ =+ STR$(N) : AreaLine$ =+ "|" : AreaLine$ =+ AreaPath$
  PRINT #7; AreaLine$
  Status = ERR()
  RETURN Status = 1
ENDFUNC

FUNC EmitMessageArea(N, Mode)
  LOCAL R
  R = ResolveMessageArea(N)
  IF R < 0 THEN Status = AreaError : RETURN 0
  IF Mode > 0 AND N = BaseId
    AreaPath$ = Target$
    AreaLevel = BaseMin
    R = 1
  ELIF Mode < 0 AND N = BaseId
    R = 0
  ENDIF
  IF R = 1
    AreaLine$ = "M|" : AreaLine$ =+ CHR$(65 + N) : AreaLine$ =+ "|"
    AreaLine$ =+ STR$(AreaLevel) : AreaLine$ =+ "|" : AreaLine$ =+ AreaPath$
    PRINT #7; AreaLine$
    Status = ERR()
    IF Status <> 1 THEN RETURN 0
  ENDIF
  RETURN 1
ENDFUNC

' Mode 0 changes one file area, Mode 1 adds/changes one message base,
' and Mode -1 removes one message base. Target$ is the canonical path.
FUNC SaveAreaRegistry(Mode)
  LOCAL I, Source, Code
  IF Mode >= 0
    AreaPath$ = Target$
    IF NOT NormalizeAreaPath() THEN Status = 18 : RETURN 0
    Target$ = AreaPath$
    IF NOT EnsureAreaFolder() THEN Status = AreaError : RETURN 0
  ENDIF
  Source = FindAreaRegistry()
  IF Source < 0 THEN Status = AreaError : RETURN 0
  XIO 33, #7, 0, 0, "D1:AREAS.NEW"
  CLOSE #7
  OPEN #7, 8, 0, "D1:AREAS.NEW"
  Status = ERR()
  IF Status <> 1 THEN CLOSE #7 : RETURN 0
  PRINT #7; "MUTINREX AREAS 1"
  FOR I = 0 TO 5
    IF NOT EmitFileArea(I, Mode = 0) THEN CLOSE #7 : RETURN 0
  NEXT I
  FOR I = 0 TO 25
    IF NOT EmitMessageArea(I, Mode) THEN CLOSE #7 : RETURN 0
  NEXT I
  CLOSE #7
  IF ValidateAreaRegistry(3) <> 1 THEN Status = AreaError : RETURN 0

  ' Preserve the last known-good registry.  If recovery already selected
  ' AREAS.BAK, discard only the malformed live file.
  ' MoveFile copies when DOS cannot rename (SpartaDOS X 4.49e).
  IF Source = 1
    XIO 33, #7, 0, 0, "D1:AREAS.BAK"
    F$ = "D1:AREAS.CFG" : S$ = "D1:AREAS.BAK"
    MoveFile()
    IF Status <> 1 AND Status <> 170 THEN RETURN 0
  ELSE
    XIO 33, #7, 0, 0, "D1:AREAS.CFG"
  ENDIF
  F$ = "D1:AREAS.NEW" : S$ = "D1:AREAS.CFG"
  IF MoveFile() THEN RETURN 1
  IF Source = 1
    Code = Status
    F$ = "D1:AREAS.BAK"
    MoveFile()
    Status = Code
  ENDIF
  RETURN 0
ENDFUNC
