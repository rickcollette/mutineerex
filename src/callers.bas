' ====================================================================
' Callers log (CALLERS.DAT)
' ====================================================================
' CALLERS.DAT is made by INIT with empty sectors and used as a circular
' file: each caller is the lines "+", name, city, date, time, and "*"
' marks the end (CSect/CByte).  When a record doesn't fit at the end of
' the file it is written at the start.
' The records read back are kept in From$ (name), ToWho$ (city), MDate$
' and MTime$.

' Writes the record of the caller and the end marker; returns the error
FUNC WriteCaller()
  LOCAL Code
  PRINT #FileCh; "+"
  PRINT #FileCh; Name$
  PRINT #FileCh; Addr$
  PRINT #FileCh; NowDate$
  PRINT #FileCh; NowTime$
  Code = ERR()
  NOTE #FileCh, CSect, CByte
  PRINT #FileCh; "*"
  IF ERR() <> 1 THEN Code = ERR()
  RETURN Code
ENDFUNC

' Adds the caller to CALLERS.DAT and to the log
FUNC LogCaller()
  INC CallNo
  PRINT #ModemCh; "You are caller "; CallNo
  PRINT #ModemCh; "Saving name to disk."
  CloseModem()
  CLOSE #FileCh
  OPEN #FileCh, 12, 0, CDF$
  NOTE #FileCh, NoteSect, NoteByte
  POINT #FileCh, CSect, CByte
  GetTime()
  IF WriteCaller() <> 1
    POINT #FileCh, NoteSect, NoteByte
    WriteCaller()
  ENDIF
  CLOSE #FileCh
  SaveSystemMeta()
  PRINT #LogCh; "LOGGED ON "; Name$; " FROM "; Addr$; " ON "; NowDate$; " AT "; NowTime$; ".  CALLER # "; CallNo; " SECTOR # "; CSect - NoteSect
  LogCheck()
ENDFUNC

' Reads the next caller record while the modem is closed, going back to
' the start of the file at its end.  Returns 0 at the end marker.
FUNC NextCaller()
  LOCAL Tries
  DO
    INPUT #FileCh, S$
    Marker$ = S$[1, 1]
    St = ERR()
    IF St = 1 AND Marker$ = "*" THEN RETURN 0
    IF St = 1 OR St = 137
      INPUT #FileCh, S$ : From$ = S$[1, 40]
      INPUT #FileCh, S$ : ToWho$ = S$[1, 40]
      INPUT #FileCh, S$ : MDate$ = S$[1, 10]
      INPUT #FileCh, S$ : MTime$ = S$[1, 8]
      St = ERR()
      IF St = 1 OR St = 137 THEN RETURN 1
    ENDIF
    INC Tries
    IF Tries > 2 THEN RETURN 0
    POINT #FileCh, NoteSect, NoteByte
  LOOP
ENDFUNC

' C: lists the callers from a date
FUNC ListCallers()
  LOCAL Tries, C, Ok
  GetTime()
  PRINT #ModemCh; CallNo; " Callers"
  CloseModem()
  CLOSE #FileCh
  OPEN #FileCh, 4, 0, CDF$
  NOTE #FileCh, NoteSect, NoteByte
  POINT #FileCh, CSect, CByte
  INPUT #FileCh, S$
  Marker$ = S$[1, 1]
  ' The oldest caller is the first "+" after the end marker
  DO
    INPUT #FileCh, S$
    Marker$ = S$[1, 1]
    St = ERR()
    IF St = 1 AND Marker$ = "+" THEN EXIT
    IF St <> 1 AND St <> 137
      INC Tries
      IF Tries > 1
        CLOSE #FileCh
        OpenModem()
        PRINT #ModemCh; "No callers"
        RETURN
      ENDIF
      POINT #FileCh, NoteSect, NoteByte
    ENDIF
  LOOP
  INPUT #FileCh, S$ : From$ = S$[1, 40]
  INPUT #FileCh, S$ : ToWho$ = S$[1, 40]
  INPUT #FileCh, S$ : MDate$ = S$[1, 10]
  INPUT #FileCh, S$ : MTime$ = S$[1, 8]
  OpenModem()
  DO
    PRINT #ModemCh; "First Date:"; MDate$; "-Last Date:"; NowDate$
    PRINT #ModemCh; "ENTER Starting Date <MM/DD/YYYY>";
    GLine()
    IF L$ = ""
      CLOSE #FileCh
      RETURN
    ENDIF
    IF LEN(L$) <> 10
      PRINT #ModemCh; "Date not in correct format."
    ELIF PEEK(ADR(L$) + 3) = 47 AND PEEK(ADR(L$) + 6) = 47
      IF L$[7, 2] = "20" THEN EXIT
    ENDIF
  LOOP
  PRINT #ModemCh; "SEARCHING CALLERS..."
  CloseModem()
  Ok = 1
  WHILE Ok AND L$ <> MDate$
    Ok = NextCaller()
  WEND
  IF Ok
    Dir = 1
    DO
      BufLen = 0
      ' A complete formatted record needs no more than 126 bytes.
      WHILE Ok AND BufLen + 126 <= BufSize
        T$ = "CALLER: " : T$ =+ From$ : BufAdd(1)
        T$ = "FROM: " : T$ =+ ToWho$ : BufAdd(1)
        T$ = "AT: " : T$ =+ MTime$ : T$ =+ "  ON: " : T$ =+ MDate$ : BufAdd(1)
        T$ = "" : BufAdd(1)
        Ok = NextCaller()
      WEND
      OpenModem()
      IF Dir AND NOT XMode THEN PRINT #ModemCh; CtrlMsg$
      Dir = 0
      C = SendRaw()
      IF C = 24
        CLOSE #FileCh
        RETURN
      ENDIF
      IF NOT Ok THEN EXIT
      CloseModem()
    LOOP
  ENDIF
  CLOSE #FileCh
  OpenModem()
  PRINT #ModemCh; "*** END OF FILE ***"
ENDFUNC
