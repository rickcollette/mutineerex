' ====================================================================
' File transfers: D (download), U (upload), text or XMODEM checksum
' ====================================================================
' The original pads the last XMODEM block with 128-N bytes of value N
' (N = bytes used in the block, 128 zeros when the file fills it) and
' the receiver removes that padding.  The same is done here.

' Controlled files use NAME.CTL: category, type and minimum level.
' Names have at most seven characters.  Q6=2 (delete) skips protocol.
' Sets BFlag for a good accessible name and Dir for XMODEM.
FUNC AskFileName()
  BFlag = 0
  Dir = 0
  FileName$ = ""
  PRINT #ModemCh; "RETURN=Exit, File NAME.CTL >";
  GLine()
  IF L$ = "" THEN RETURN
  Q3 = LEN(L$)
  FOR Q1 = 1 TO Q3
    Q2 = PEEK(ADR(L$) + Q1)
    IF Q2 >= 97 AND Q2 <= 122
      Q2 = Q2 - 32
      POKE ADR(L$) + Q1, Q2
    ENDIF
  NEXT Q1
  Q4 = INSTR(L$, ".")
  IF Q4 < 2 OR Q4 > 8 OR Q4 <> Q3 - 3
    PRINT #ModemCh; "USE 1-7 CHARACTERS PLUS .CTL"
    RETURN
  ENDIF
  FOR Q1 = 1 TO Q4 - 1
    Q2 = PEEK(ADR(L$) + Q1)
    IF NOT ((Q2 >= 65 AND Q2 <= 90) OR (Q2 >= 48 AND Q2 <= 57))
      PRINT #ModemCh; "LETTERS AND DIGITS ONLY"
      RETURN
    ENDIF
  NEXT Q1
  Q2 = PEEK(ADR(L$) + Q4 + 1)
  IF NOT (Q2 = 71 OR Q2 = 65 OR Q2 = 84 OR Q2 = 82 OR Q2 = 85)
    PRINT #ModemCh; "CATEGORY: G,A,T,R,U"
    RETURN
  ENDIF
  Q2 = PEEK(ADR(L$) + Q4 + 2)
  IF NOT (Q2 = 67 OR Q2 = 69 OR Q2 = 88 OR Q2 = 66 OR Q2 = 84 OR Q2 = 85)
    PRINT #ModemCh; "TYPE: C,E,X,B,T,U"
    RETURN
  ENDIF
  Q5 = PEEK(ADR(L$) + Q4 + 3) - 48
  IF Q5 < 1 OR Q5 > UserLevel
    PRINT #ModemCh; "NO ACCESS TO THAT FILE LEVEL"
    RETURN
  ENDIF
  Q2 = FileStorageArea(L$)
  IF Q2 < 0 OR ResolveFileArea(Q2) <> 1
    PRINT #ModemCh; "FILE AREA CONFIGURATION ERROR"
    RETURN
  ENDIF
  FileName$ = AreaPath$
  FileName$ =+ L$
  BFlag = 1
  IF Q6 = 2 THEN RETURN
  PRINT #ModemCh; "Are you using the Christensen XMODEM"
  PRINT #ModemCh; "File transfer protocol";
  Dir = YesNo()
ENDFUNC

' Adds up to ChunkSize bytes of the open file to Buf.
' BFlag gets the error code at the end of the file, else 0
FUNC ReadChunk()
  Q1 = ChunkSize
  IF BufLen + Q1 > BufSize THEN Q1 = BufSize - BufLen
  BFlag = 0
  St = 1
  DO
    IF Q1 = 0 THEN EXIT
    Q2 = Q1
    IF Q2 > 255 THEN Q2 = 255
    BGET #FileCh, ADR(Buf) + BufLen, Q2
    St = ERR()
    Q3 = DPEEK($348 + 16 * FileCh)
    BufLen = BufLen + Q3
    Q1 = Q1 - Q3
    IF St <> 1 OR Q3 = 0 THEN EXIT
  LOOP
  IF St <> 1 THEN BFlag = St
ENDFUNC

' Pads Buf to a multiple of 128 bytes for the last XMODEM block
FUNC PadBlock()
  Q1 = BufLen MOD 128
  MSET ADR(Buf) + BufLen, 128 - Q1, Q1
  BufLen = BufLen + 128 - Q1
ENDFUNC

' D: sends a file to the caller
FUNC Download()
  LOCAL C
  Q6 = 0
  AskFileName()
  IF NOT BFlag THEN RETURN
  CloseModem()
  CLOSE #FileCh
  OPEN #FileCh, 4, 0, FileName$
  St = ERR()
  IF St <> 1
    CLOSE #FileCh
    OpenModem()
    PRINT #ModemCh,
    PRINT #ModemCh; "Can't find that file"
    RETURN
  ENDIF
  GetTime()
  IF Dir AND NOT LocalMode
    XmodemSend()
    RETURN
  ENDIF
  PRINT #LogCh; "DL "; FileName$; " "; NowTime$
  LogCheck()
  BufLen = 0
  ReadChunk()
  OpenModem()
  PRINT #ModemCh; "FILE: "; FileName$
  IF NOT XMode THEN PRINT #ModemCh; CtrlMsg$
  PRINT #ModemCh,
  DO
    C = SendRaw()
    IF BFlag OR C = 24 OR C = 152 OR Lost THEN EXIT
    CloseModem()
    BufLen = 0
    ReadChunk()
    OpenModem()
  LOOP
  CLOSE #FileCh
  PRINT #ModemCh,
  PRINT #ModemCh; "*** END OF FILE ***"
ENDFUNC

' Sends the open file with XMODEM (checksum, 128 byte blocks)
FUNC XmodemSend()
  LOCAL Block, Dir, T, I, C, Sum, A, AM, LM
  PRINT #LogCh; "XDL "; FileName$; " "; NowTime$
  LogCheck()
  BufLen = 0
  ReadChunk()
  IF BFlag THEN PadBlock()
  OpenModem()
  PRINT #ModemCh; "FILE: "; FileName$; " Ready to Send"
  PRINT #ModemCh; "^X to cancel"
  Block = 1
  C = GetChr()
  IF C <> 21
    CLOSE #FileCh
    RETURN
  ENDIF
  AM = AMode
  LM = LMode
  AMode = 32
  LMode = 0
  OpenModem()
  Q1 = RemmsRoute(1)             ' binary stream to remote only
  DO
    Dir = 0
    DO
      A = ADR(Buf) + Dir * 128
      Sum = 0
      FOR I = 0 TO 127
        Sum = Sum + PEEK(A + I)
      NEXT I
      FOR T = 1 TO 10
        PUT #ModemCh, 1
        PUT #ModemCh, Block
        PUT #ModemCh, 255 - Block
        BPUT #ModemCh, A, 128
        PUT #ModemCh, Sum
        C = GetChr()
        IF C <> 21 THEN EXIT
      NEXT T
      INC Dir
      INC Block
      IF C <> 6 THEN EXIT
      IF (Dir + 1) * 128 > BufLen THEN EXIT
    LOOP
    IF C <> 6 THEN EXIT
    IF BFlag
      PUT #ModemCh, 4
      EXIT
    ENDIF
    ' Keep the bytes not sent yet and read more of the file
    T = BufLen - Dir * 128
    IF T > 0 THEN MOVE ADR(Buf) + Dir * 128, ADR(Buf), T
    BufLen = T
    CloseModem()
    ReadChunk()
    IF BFlag THEN PadBlock()
    OpenModem()
    Q1 = RemmsRoute(1)
  LOOP
  IF C <> 6
    PRINT #ModemCh,
    PRINT #ModemCh; "* ABORTED *"
  ENDIF
  CLOSE #FileCh
  AMode = AM
  LMode = LM
  Q1 = RemmsRoute(2)
ENDFUNC

' Reads the rest of an XMODEM block (block number, its complement,
' 128 bytes, checksum) into Blk.  Returns 1 if it is good
FUNC ReadBlock()
  LOCAL I, C, Start, Sum, K
  Start = TIME
  WHILE I < 131
    IF RemmsStatus()
      C = RemmsGet()
      IF C < 0 THEN RETURN 0
      Blk(I) = C
      INC I
      Start = TIME
    ELIF TIME - Start > 2 * Fps
      RETURN 0
    ENDIF
  WEND
  IF Blk(0) + Blk(1) <> 255 THEN RETURN 0
  FOR K = 2 TO 129
    Sum = Sum + Blk(K)
  NEXT K
  IF (Sum & 255) = Blk(130) THEN RETURN 1
  RETURN 0
ENDFUNC

' Receives FileName$ with XMODEM
FUNC XmodemReceive()
  LOCAL AM, LM, Ack, NSec, T, I, N, Soh, X
  AM = AMode
  LM = LMode
  AMode = 32
  LMode = 64
  Ack = 21
  NSec = 0
  BufLen = 0
  CloseModem()
  CLOSE #FileCh
  OPEN #FileCh, 8, 0, FileName$
  St = ERR()
  OpenModem()
  Q1 = RemmsRoute(1)             ' binary stream to remote only
  IF St <> 1
    PRINT #ModemCh; "* ABORTED *"
    CLOSE #FileCh
    AMode = AM
    LMode = LM
    Q1 = RemmsRoute(2)
    RETURN 0
  ENDIF
  PRINT #ModemCh; "FILE: "; FileName$; " Ready to Receive,"
  PRINT #ModemCh; "^X to Cancel"
  DO
    FOR T = 1 TO 10
      PUT Ack
      DrainInput(0)
      PUT #ModemCh, Ack
      Ack = 6
      Soh = GetRaw(10 * Fps)
      IF Soh = -1
        Ack = 21
      ELIF Soh <> 1
        EXIT
      ELIF ReadBlock()
        MOVE ADR(Blk) + 2, ADR(Buf) + BufLen, 128
        BufLen = BufLen + 128
        INC NSec
        EXIT
      ELSE
        PAUSE 30
        OpenModem()
        Q1 = RemmsRoute(1)
        Ack = 21
      ENDIF
      IF Lost THEN EXIT
    NEXT T
    IF Soh <> 1 OR Ack <> 6 OR Lost THEN EXIT
    IF NSec >= NumSect
      CloseModem()
      BPUT #FileCh, ADR(Buf), BufLen
      BufLen = 0
      NSec = 0
      OpenModem()
      Q1 = RemmsRoute(1)
    ENDIF
  LOOP
  IF Soh = 4 AND Ack = 6
    PUT #ModemCh, Ack
    OpenModem()
    PRINT #ModemCh,
    PRINT #ModemCh; "* SAVING FILE *"
    CloseModem()
    IF BufLen > 0
      ' Remove the padding of the last block
      X = Buf(BufLen - 1)
      N = 0
      IF X < 128
        N = 128 - X
        FOR I = BufLen - N TO BufLen - 1
          IF Buf(I) <> X THEN N = 0
        NEXT I
      ENDIF
      BufLen = BufLen - N
      IF BufLen > 0 THEN BPUT #FileCh, ADR(Buf), BufLen
    ENDIF
  ELSE
    PRINT #ModemCh,
    PRINT #ModemCh; "* ABORTED *"
    CloseModem()
  ENDIF
  CLOSE #FileCh
  AMode = AM
  LMode = LM
  Q1 = RemmsRoute(2)
  IF Soh = 4 AND Ack = 6 THEN RETURN 1
  RETURN 0
ENDFUNC

' Records the description shown by the categorized file list.
FUNC DescribeUpload()
  PRINT #ModemCh; "DESCRIPTION (70 CHARACTERS) >";
  Il = 70
  GLine()
  IF L$ = ""
    BaseDesc$ = "No description available."
  ELSE
    BaseDesc$ = L$[1, 70]
  ENDIF
  Q6 = 0
  UpdateFileCatalog()
ENDFUNC

' U: receives a file from the caller
FUNC Upload()
  IF UserLevel < 8
    PRINT #ModemCh; "LEVEL 8 FILE MODERATOR REQUIRED"
    RETURN
  ENDIF
  Q6 = 1
  AskFileName()
  IF NOT BFlag THEN RETURN
  ' Show free space for the selected file's actual destination area.
  CloseModem()
  CLOSE #FileCh
  S$ = AreaPath$ : S$ =+ "*.XXX"
  OPEN #FileCh, 6, 0, S$
  S$ = ""
  DO
    INPUT #FileCh, S$
    IF ERR() <> 1 OR INSTR(S$, "FREE") > 0 THEN EXIT
  LOOP
  CLOSE #FileCh
  OpenModem()
  PRINT #ModemCh; S$
  PRINT #ModemCh,
  IF LocalMode THEN Dir = 0
  CloseModem()
  GetTime()
  IF Dir
    PRINT #LogCh; "XUP "; FileName$; " "; NowTime$
  ELSE
    PRINT #LogCh; "UP "; FileName$; " "; NowTime$
  ENDIF
  LogCheck()
  CLOSE #FileCh
  OPEN #FileCh, 4, 0, FileName$
  St = ERR()
  CLOSE #FileCh
  IF St = 1
    OpenModem()
    PRINT #ModemCh,
    PRINT #ModemCh; CHR$(ControlChar(0)); "FILE ALREADY EXISTS!!!"
    RETURN
  ENDIF
  IF Dir
    IF XmodemReceive() THEN DescribeUpload()
    RETURN
  ENDIF
  OPEN #FileCh, 8, 0, FileName$
  OpenModem()
  PRINT #ModemCh; "Upload --- Enter file <CR>=Exit "
  Il = 120
  DO
    PRINT #ModemCh; ">";
    GLine()
    CloseModem()
    IF L$ = "" THEN EXIT
    PRINT #FileCh; L$
    OpenModem()
  LOOP
  CLOSE #FileCh
  DescribeUpload()
ENDFUNC

' V: level 8/9 file moderators delete a controlled file
FUNC DeleteFile()
  IF UserLevel < 8
    PRINT #ModemCh; "LEVEL 8 FILE MODERATOR REQUIRED"
    RETURN
  ENDIF
  Q6 = 2
  AskFileName()
  IF NOT BFlag THEN RETURN
  PRINT #ModemCh; "Delete "; FileName$;
  IF NOT YesNo() THEN RETURN
  CloseModem()
  XIO 33, #FileCh, 0, 0, FileName$
  St = ERR()
  IF St = 1
    GetTime()
    PRINT #LogCh; "DEL "; FileName$; " BY "; Name$; " "; NowTime$
    LogCheck()
    Q6 = 1
    UpdateFileCatalog()
  ENDIF
  OpenModem()
  IF St = 1
    PRINT #ModemCh; "FILE DELETED"
  ELSE
    PRINT #ModemCh; "DELETE ERROR "; St
  ENDIF
ENDFUNC
