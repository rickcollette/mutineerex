' Text screens and persistent caller counters shared by several modules.

FUNC ReadFile()
  LOCAL Code, N, Got
  CloseModem()
  CLOSE #FileCh
  BufLen = 0
  OPEN #FileCh, 4, 0, FileName$
  Code = ERR()
  IF Code = 1
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

FUNC SelectTextFile()
  RawText = 0
  IF AMode
    FileName$ =+ ".ATA"
  ELSE
    FileName$ =+ ".TXT"
    RawText = 1
  ENDIF
ENDFUNC

FUNC ReadTextFile()
  SelectTextFile()
  St = ReadFile()
  IF St <> 1 THEN RawText = 0
  RETURN St
ENDFUNC

FUNC ShowTextFile()
  IF ReadTextFile() <> 1 THEN RETURN
  SendBuf(1)
ENDFUNC

FUNC SaveSystemMeta()
  CloseModem()
  CLOSE #FileCh
  OPEN #FileCh, 8, 0, SystemFile$
  PRINT #FileCh; CSect
  PRINT #FileCh; CByte
  PRINT #FileCh; CallNo
  CLOSE #FileCh
ENDFUNC

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
