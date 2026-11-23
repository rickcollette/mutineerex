' ====================================================================
' Disk files
' ====================================================================

' Reads the file FileName$ into Buf (RFILE of the original).
' The modem is closed during the disk access and opened again.
' Returns 1, or the error code after telling the caller
FUNC ReadFile()
  LOCAL Code, N, Got
  CloseModem()
  CLOSE #FileCh
  BufLen = 0
  OPEN #FileCh, 4, 0, FileName$
  Code = ERR()
  IF Code = 1
    ' EOS only transfers up to 255 bytes reliably in one request (the
    ' original RFILE used 255-byte XIO reads), so fill Buf in blocks.
    DO
      N = BufSize - BufLen
      IF N = 0 THEN EXIT
      IF N > 255 THEN N = 255
      BGET #FileCh, ADR(Buf) + BufLen, N
      Code = ERR()
      Got = DPEEK($348 + 16 * FileCh)
      BufLen = BufLen + Got
      IF Code <> 1 OR Got = 0 THEN EXIT
    LOOP
    IF Code = 136 THEN Code = 1
  ENDIF
  CLOSE #FileCh
  IF Code <> 1
    PRINT #LogCh; "Error- "; Code; " FILE "; FileName$
    LogCheck()
    OpenModem()
    PRINT #ModemCh,
    PRINT #ModemCh; "SYSTEM ERROR --- TRY AGAIN."
    RETURN Code
  ENDIF
  OpenModem()
  RETURN 1
ENDFUNC

' Adds .ATA for an ATASCII terminal or .TXT for an ASCII terminal.
FUNC SelectTextFile()
  RawText = 0
  IF AMode
    FileName$ =+ ".ATA"
  ELSE
    FileName$ =+ ".TXT"
    RawText = 1
  ENDIF
ENDFUNC

' Selects and reads the terminal-specific version of FileName$.
FUNC ReadTextFile()
  SelectTextFile()
  St = ReadFile()
  IF St <> 1 THEN RawText = 0
  RETURN St
ENDFUNC

' Sends the terminal-specific text screen FileName$ to the caller.
FUNC ShowTextFile()
  IF ReadTextFile() <> 1 THEN RETURN
  SendBuf(1)
ENDFUNC

' Writes the caller-log state to SYSTEM.MET
FUNC SaveSystemMeta()
  CloseModem()
  CLOSE #FileCh
  OPEN #FileCh, 8, 0, SystemFile$
  PRINT #FileCh; CSect
  PRINT #FileCh; CByte
  PRINT #FileCh; CallNo
  CLOSE #FileCh
ENDFUNC

' Adds T$ to Buf, followed by an EOL when Eol is 1
FUNC BufAdd(Eol)
  Q1 = LEN(T$)
  IF BufLen + Q1 + 1 > BufSize THEN RETURN
  MOVE ADR(T$) + 1, ADR(Buf) + BufLen, Q1
  BufLen = BufLen + Q1
  IF Eol
    Buf(BufLen) = 155
    INC BufLen
  ENDIF
ENDFUNC

' Sets T$ to the name of the selected file-list category.  Text files
' are a useful first view even though text is stored in the type byte;
' the other five views use the category byte of NAME.CTL.
FUNC FileCategoryName()
  IF FileCategory = 0
    T$ = "TEXT FILES"
  ELIF FileCategory = 1
    T$ = "GAMES"
  ELIF FileCategory = 2
    T$ = "APPLICATIONS"
  ELIF FileCategory = 3
    T$ = "TOOLS"
  ELIF FileCategory = 4
    T$ = "ARCHIVERS"
  ELSE
    T$ = "UNKNOWN"
  ENDIF
ENDFUNC

' Looks up FileName$ in FILES.DAT.  Records are NAME.CTL|description.
' Missing catalog files and uncataloged downloads get a useful default.
FUNC FindFileDescription()
  BaseDesc$ = "No description available."
  CLOSE #5
  L$ = FileDrive$
  L$ =+ "FILES.DAT"
  OPEN #5, 4, 0, L$
  Q2 = ERR()
  IF Q2 = 1
    DO
      INPUT #5, L$
      Q2 = ERR()
      IF Q2 <> 1 THEN EXIT
      Q1 = INSTR(L$, "|")
      IF Q1 > 1 AND L$[1, Q1 - 1] = FileName$
        BaseDesc$ = L$[Q1 + 1, 70]
        EXIT
      ENDIF
    LOOP
  ENDIF
  CLOSE #5
ENDFUNC

' Adds a 40-column table row to Buf.  The columns are 11, 8 and 19
' characters wide; description continuations leave the first two blank.
FUNC AddFileRow()
  T$ = FileName$
  WHILE LEN(T$) < 11
    T$ =+ " "
  WEND
  T$ =+ "|"
  IF Q6 = 71
    T$ =+ "GAME"
  ELIF Q6 = 65
    T$ =+ "APP"
  ELIF Q6 = 84
    T$ =+ "TOOL"
  ELIF Q6 = 82
    T$ =+ "ARCHIVER"
  ELSE
    T$ =+ "UNKNOWN"
  ENDIF
  WHILE LEN(T$) < 20
    T$ =+ " "
  WEND
  T$ =+ "|"
  Q2 = 1
  DO
    Q3 = LEN(BaseDesc$) - Q2 + 1
    IF Q3 > 19
      Q4 = 0
      FOR Q5 = 1 TO 19
        IF PEEK(ADR(BaseDesc$) + Q2 + Q5 - 1) = 32 THEN Q4 = Q5
      NEXT Q5
      IF Q4 = 0 THEN Q4 = 19
      Q3 = Q4
    ENDIF
    T$ =+ BaseDesc$[Q2, Q3]
    BufAdd(1)
    Q2 = Q2 + Q3
    WHILE Q2 <= LEN(BaseDesc$) AND PEEK(ADR(BaseDesc$) + Q2) = 32
      INC Q2
    WEND
    IF Q2 > LEN(BaseDesc$) THEN EXIT
    T$ = "           |        |"
  LOOP
  T$ = "-----------+--------+-------------------"
  BufAdd(1)
ENDFUNC

' Rewrites FILES.DAT after a moderator uploads or deletes FileName$.
' Q6 is true for deletion; otherwise BaseDesc$ is stored.
FUNC UpdateFileCatalog()
  S$ = FileName$[LEN(FileDrive$) + 1]
  CloseModem()
  CLOSE #FileCh
  L$ = FileDrive$
  L$ =+ "FILES.DAT"
  OPEN #FileCh, 4, 0, L$
  Q2 = ERR()
  BufLen = 0
  IF Q2 = 1
    DO
      INPUT #FileCh, T$
      Q2 = ERR()
      IF Q2 <> 1 THEN EXIT
      Q1 = INSTR(T$, "|")
      IF Q1 < 2 OR T$[1, Q1 - 1] <> S$ THEN BufAdd(1)
    LOOP
  ENDIF
  CLOSE #FileCh
  IF NOT Q6
    T$ = S$
    T$ =+ "|"
    T$ =+ BaseDesc$
    BufAdd(1)
  ENDIF
  OPEN #FileCh, 8, 0, L$
  Q2 = ERR()
  IF Q2 = 1 AND BufLen > 0 THEN BPUT #FileCh, ADR(Buf), BufLen
  IF ERR() <> 1 THEN Q2 = ERR()
  CLOSE #FileCh
  OpenModem()
  IF Q2 <> 1 THEN PRINT #ModemCh; "CATALOG UPDATE ERROR "; Q2
ENDFUNC

' F: lists accessible controlled files in the selected category.
FUNC ListFiles()
  CloseModem()
  CLOSE #FileCh
  S$ = FileDrive$
  S$ =+ "*.???"
  OPEN #FileCh, 6, 0, S$
  BufLen = 0
  T$ = "CATEGORY: "
  FileCategoryName()
  S$ = T$
  T$ = "CATEGORY: "
  T$ =+ S$
  BufAdd(1)
  T$ = "FILENAME   |CATEGORY|DESCRIPTION"
  BufAdd(1)
  T$ = "-----------+--------+-------------------"
  BufAdd(1)
  BFlag = 0
  DO
    INPUT #FileCh, S$
    IF ERR() <> 1 OR INSTR(S$, "FREE SECTORS") > 0 THEN EXIT
    IF LEN(S$) >= 13
      Q1 = PEEK(ADR(S$) + 11)
      Q2 = PEEK(ADR(S$) + 12)
      Q3 = PEEK(ADR(S$) + 13) - 48
      IF (Q1 = 71 OR Q1 = 65 OR Q1 = 84 OR Q1 = 82 OR Q1 = 85) AND (Q2 = 67 OR Q2 = 69 OR Q2 = 88 OR Q2 = 66 OR Q2 = 84 OR Q2 = 85) AND Q3 >= 1 AND Q3 <= UserLevel AND ((FileCategory = 0 AND Q2 = 84) OR (FileCategory = 1 AND Q1 = 71) OR (FileCategory = 2 AND Q1 = 65) OR (FileCategory = 3 AND Q1 = 84) OR (FileCategory = 4 AND Q1 = 82) OR (FileCategory = 5 AND Q1 = 85))
        Q6 = Q1
        FileName$ = ""
        FOR Q4 = 3 TO 10
          IF PEEK(ADR(S$) + Q4) <> 32 THEN FileName$ =+ CHR$(PEEK(ADR(S$) + Q4))
        NEXT Q4
        FileName$ =+ "."
        FileName$ =+ S$[11, 3]
        FindFileDescription()
        AddFileRow()
        INC BFlag
      ENDIF
    ENDIF
  LOOP
  CLOSE #FileCh
  IF BFlag = 0
    T$ = "NO FILES IN THIS CATEGORY"
    BufAdd(1)
  ENDIF
  OpenModem()
  SendBuf(1)
ENDFUNC

' J: selects a file category, then displays it.
FUNC ChangeFileCategory()
  PRINT #ModemCh; "1 TEXT FILES   2 GAMES"
  PRINT #ModemCh; "3 APPLICATIONS 4 TOOLS"
  PRINT #ModemCh; "5 ARCHIVERS    6 UNKNOWN"
  PRINT #ModemCh; "CATEGORY 1-6, RETURN=KEEP >";
  GLine()
  IF L$ <> ""
    Q1 = VAL(L$)
    IF Q1 < 1 OR Q1 > 6
      PRINT #ModemCh; "CHOOSE A CATEGORY FROM 1 TO 6"; CHR$(ControlChar(0))
      RETURN
    ENDIF
    FileCategory = Q1 - 1
  ENDIF
  ListFiles()
ENDFUNC
