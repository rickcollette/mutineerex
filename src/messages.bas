' ====================================================================
' Messages
' ====================================================================
' A message base uses three 7.3 files.  For base A, minimum level 1:
' MESSAGE.DA1 = data, MESSAGE.IA1 = index, MESSAGE.MA1 = metadata.
' The metadata contains name, description, NOTE position, count and high
' message number.  Base IDs are A through Z and the last extension digit
' is the minimum access level.

' Builds and sends the list of message bases visible at the user's level
FUNC ListMessageBases()
  LOCAL K
  Dir = ActiveBase
  CloseModem()
  DiscoverBases()
  BufLen = 0
  T$ = "MESSAGE BASES:"
  BufAdd(1)
  FOR K = 0 TO 25
    IF BasePresent(K) AND BaseLevel(K) <= UserLevel
      ReadBaseMeta(K)
      IF St = 1
        T$ = CHR$(65 + K)
        T$ =+ BaseName$
        BufAdd(1)
        T$ = "  "
        T$ =+ BaseDesc$
        BufAdd(1)
      ENDIF
    ENDIF
  NEXT K
  IF Dir >= 0 AND BasePresent(Dir) THEN ReadBaseMeta(Dir)
  OpenModem()
  SendBuf(1)
ENDFUNC

' J: lists accessible bases and changes the active one
FUNC ChangeMessageBase()
  ListMessageBases()
  PRINT #ModemCh; "Base A-Z, RETURN=keep >";
  GLine()
  IF L$ = "" THEN RETURN
  Q1 = PEEK(ADR(L$) + 1)
  IF Q1 >= 97 AND Q1 <= 122 THEN Q1 = Q1 - 32
  Q1 = Q1 - 65
  IF Q1 < 0 OR Q1 > 25 OR NOT BasePresent(Q1) OR BaseLevel(Q1) > UserLevel
    PRINT #ModemCh; "NO ACCESS TO THAT BASE"
    RETURN
  ENDIF
  CloseModem()
  ReadBaseMeta(Q1)
  OpenModem()
  IF St <> 1
    PRINT #ModemCh; "ERROR "; St; " OPENING BASE"
  ELSE
    PRINT #ModemCh; "BASE "; CHR$(65 + ActiveBase); ": "; BaseName$
  ENDIF
ENDFUNC

' MESSAGE.IIL is the active index, loaded in Buf: 40 bytes per message,
'   bytes 0-3   message number, 4 digits
'   bytes 4-36  subject, padded with spaces
'   bytes 37-38 sector of the message in MESSAGE.DIL (high, low)
'   byte  39    byte in the sector (from NOTE)
' MESSAGE.DIL holds, for each message, the lines: number, subject,
' date, time, from, to, number of lines, then the lines.
' MSect/MByte is the end of the used part of MESSAGE.DIL.
' The lines of a message being written or read are kept in MsgText,
' 121 bytes each: a length byte and up to 120 characters, the format of
' an exBASIC string, so line K is $(ADR(MsgText) + (K - 1) * 121).

' Message number of index record R (1 = first)
FUNC RecNum(R)
  Q1 = ADR(Buf) + (R - 1) * 40
  Q2 = 0
  FOR Q3 = 0 TO 3
    Q2 = Q2 * 10 + PEEK(Q1 + Q3) - 48
  NEXT Q3
  RETURN Q2
ENDFUNC

' Stores S$ as line K of MsgText
FUNC StoreLine(K)
  IF LEN(S$) > 120 THEN S$ = S$[1, 120]
  MOVE ADR(S$), ADR(MsgText) + (K - 1) * 121, LEN(S$) + 1
ENDFUNC

' Reads the first range of message numbers of Spec$ ("5", "1-9" or
' "9-1", ranges separated by any character) into From, Upto and Dir
' (1 = up, -1 = down, 0 = Spec$ was empty) and removes it from Spec$
' (line 9000 of the original)
FUNC ParseRange()
  From = 0
  Upto = 0
  Dir = 0
  Q2 = LEN(Spec$)
  IF Q2 = 0 THEN RETURN
  Q4 = ADR(Spec$)
  Q1 = 1
  WHILE Q1 <= Q2
    Q3 = PEEK(Q4 + Q1)
    IF Q3 < 48 OR Q3 > 57 THEN EXIT
    IF From < 3000 THEN From = From * 10 + Q3 - 48
    INC Q1
  WEND
  IF Q1 <= Q2 AND PEEK(Q4 + Q1) = 45
    INC Q1
    WHILE Q1 <= Q2
      Q3 = PEEK(Q4 + Q1)
      IF Q3 < 48 OR Q3 > 57 THEN EXIT
      IF Upto < 3000 THEN Upto = Upto * 10 + Q3 - 48
      INC Q1
    WEND
    Dir = 1
    IF Upto < From THEN Dir = -1
  ELSE
    Upto = From
    Dir = 1
  ENDIF
  IF Q1 < Q2
    Spec$ = Spec$[Q1 + 1]
  ELSE
    Spec$ = ""
  ENDIF
ENDFUNC

' Index record where the range starts: the first message >= From going
' up, the last message <= From going down
FUNC FindRec(NRec)
  LOCAL F
  IF Dir = 1
    F = 1
    WHILE F <= NRec AND RecNum(F) < From
      INC F
    WEND
  ELSE
    F = NRec
    WHILE F >= 1 AND RecNum(F) > From
      DEC F
    WEND
  ENDIF
  RETURN F
ENDFUNC

' Shows message R of the index; with Mode > 0 only its header.
' Returns the last key of the caller (24 = stopped)
FUNC ShowMessage(R, Mode)
  LOCAL P, C, K, Sect, Bt, Code
  P = ADR(Buf) + (R - 1) * 40
  Sect = PEEK(P + 37) * 256 + PEEK(P + 38)
  Bt = PEEK(P + 39)
  CloseModem()
  CLOSE #FileCh
  OPEN #FileCh, 4, 0, MDF$
  POINT #FileCh, Sect, Bt
  INPUT #FileCh, S$
  MsgNo$ = S$[1, 4]
  INPUT #FileCh, S$
  Subj$ = S$[1, 33]
  INPUT #FileCh, S$
  MDate$ = S$[1, 10]
  INPUT #FileCh, S$
  MTime$ = S$[1, 8]
  INPUT #FileCh, S$
  From$ = S$[1, 40]
  INPUT #FileCh, S$
  ToWho$ = S$[1, 40]
  INPUT #FileCh, MsgLines
  Code = ERR()
  IF MsgLines > 16 THEN MsgLines = 16
  IF Mode <= 0
    FOR K = 1 TO MsgLines
      INPUT #FileCh, S$
      StoreLine(K)
    NEXT K
  ENDIF
  CLOSE #FileCh
  OpenModem()
  IF Code <> 1
    PRINT #ModemCh; "SYSTEM ERROR --- TRY AGAIN."
    RETURN 24
  ENDIF
  T$ = "MSG# "
  T$ =+ MsgNo$
  T$ =+ " DATE:"
  T$ =+ MDate$
  T$ =+ " TIME:"
  T$ =+ MTime$
  C = SendLine(T$)
  IF C = 24 THEN RETURN C
  T$ = "FROM: "
  T$ =+ From$
  C = SendLine(T$)
  IF C = 24 THEN RETURN C
  T$ = "  TO: "
  T$ =+ ToWho$
  C = SendLine(T$)
  IF C = 24 THEN RETURN C
  T$ = "SUBJ: "
  T$ =+ Subj$
  C = SendLine(T$)
  IF C = 24 THEN RETURN C
  IF Mode > 0
    C = SendLine("=========")
    IF C = 24 THEN RETURN C
  ELSE
    FOR K = 1 TO MsgLines
      C = SendLine($(ADR(MsgText) + (K - 1) * 121))
      IF C = 24 THEN RETURN C
    NEXT K
  ENDIF
  PRINT #ModemCh,
  RETURN C
ENDFUNC

' Prints the message just shown on the log printer
FUNC PrintMessage(Mode)
  LOCAL K
  PRINT #LogCh; "MSG# "; MsgNo$; " DATE:"; MDate$; " TIME:"; MTime$
  PRINT #LogCh; "FROM: "; From$
  PRINT #LogCh; "  TO: "; ToWho$
  PRINT #LogCh; "SUBJ: "; Subj$
  IF Mode > 0 THEN PRINT #LogCh; "========="
  IF Mode <= 0 THEN FOR K = 1 TO MsgLines : PRINT #LogCh; $(ADR(MsgText) + (K - 1) * 121) : NEXT K
  LogCheck()
ENDFUNC

' Q, R and S: scans the messages.  Mode -1 = quick scan (subjects),
' 0 = retrieve (whole messages), 1 = summary (headers)
FUNC ScanMessages(Mode)
  LOCAL NRec, F, T, C
  IF Mode < 0
    PRINT #ModemCh; "Quick Scan";
  ELIF Mode = 0
    PRINT #ModemCh; "Retrieve";
  ELSE
    PRINT #ModemCh; "Summary of";
  ENDIF
  PRINT #ModemCh; " Messages - "; BaseName$
  FileName$ = MIF$
  IF ReadFile() <> 1 THEN RETURN
  PRINT #ModemCh; Msgs; " Messages"
  IF NOT XMode THEN PRINT #ModemCh; CtrlMsg$
  NRec = BufLen / 40
  IF NRec = 0
    PRINT #ModemCh; "No Messages"
    RETURN
  ENDIF
  Msgs = NRec
  PRINT #ModemCh; "First Msg# "; RecNum(1); "  Last Msg# "; RecNum(NRec)
  Spec$ = ""
  IF LEN(L$) > 2 THEN Spec$ = L$[3]
  DO
    IF Lost THEN RETURN
    IF Spec$ = ""
      PRINT #ModemCh; "RETURN=Exit, Msg# From-To >";
      GLine()
      PRINT #ModemCh,
      IF L$ = "" THEN RETURN
      Spec$ = L$
    ENDIF
    ParseRange()
    IF Dir = 0
      PRINT #ModemCh,
    ELSE
      F = FindRec(NRec)
      WHILE F >= 1 AND F <= NRec
        T = RecNum(F)
        IF Dir = 1 AND (T < From OR T > Upto) THEN EXIT
        IF Dir = -1 AND (T < Upto OR T > From) THEN EXIT
        IF Mode < 0
          PRINT #ModemCh; T; ". ";
          BPUT #ModemCh, ADR(Buf) + F * 40 - 36, 33
          PRINT #ModemCh,
          C = CheckPause()
        ELSE
          C = ShowMessage(F, Mode)
        ENDIF
        IF C = 24
          Spec$ = ""
          EXIT
        ENDIF
        F = F + Dir
      WEND
    ENDIF
  LOOP
ENDFUNC

' E: enters a new message (Create).  The author is the logged in user
FUNC EnterMessage()
  From$ = Name$
  PRINT #ModemCh; "Enter Message---"
  PRINT #ModemCh; "SUBJECT: ";
  GLine()
  IF L$ = "" THEN RETURN
  Subj$ = L$[1, 33]
  PRINT #ModemCh; "TO: <RETURN>=All ";
  GLine()
  IF Lost THEN RETURN
  IF L$ = ""
    L$ = "ALL"
    PRINT #ModemCh; "TO: "; L$
    PRINT #ModemCh,
  ENDIF
  ToWho$ = L$[1, 40]
  MsgLines = 0
  PRINT #ModemCh; "Enter Message, Two <RETURN>s when done."
  AddLines()
  IF EditorMenu() THEN SaveMessage(0)
ENDFUNC

' The menu of the message editor.  Returns 1 to save the message
FUNC EditorMenu()
  LOCAL C
  DO
    IF Lost THEN RETURN 0
    PRINT #ModemCh; "(A)dd,(E)dit,(L)ist,(Q)uit,(S)ave ?";
    C = GetChr()
    PRINT #ModemCh; CHR$(C)
    IF C > 96 THEN C = C - 32
    IF C = 65
      AddLines()
    ELIF C = 69
      EditLines()
    ELIF C = 76
      ListLines()
    ELIF C = 81
      PRINT #ModemCh; "MESSAGE ABORTED"
      RETURN 0
    ELIF C = 83 AND MsgLines > 0
      RETURN 1
    ENDIF
  LOOP
ENDFUNC

' Adds lines to the message, until an empty line or 16 lines
FUNC AddLines()
  Il = 120
  DO
    INC MsgLines
    IF MsgLines > 16 THEN EXIT
    IF MsgLines > 13 THEN PRINT #ModemCh; "Only "; 17 - MsgLines; " Lines left"
    PRINT #ModemCh; MsgLines; " ";
    GLine()
    IF L$ = "" THEN EXIT
    S$ = L$
    StoreLine(MsgLines)
  LOOP
  DEC MsgLines
ENDFUNC

' Changes lines of the message
FUNC EditLines()
  LOCAL Z
  IF MsgLines = 0 THEN RETURN
  DO
    IF Lost THEN RETURN
    PRINT #ModemCh; "EDIT WHICH LINE 1-"; MsgLines; " ?";
    GLine()
    IF L$ = "" THEN RETURN
    Z = VAL(L$)
    IF Z >= 1 AND Z <= MsgLines
      PRINT #ModemCh; "OLD LINE "; Z; " READS:"
      PRINT #ModemCh,
      PRINT #ModemCh; Z; " "; $(ADR(MsgText) + (Z - 1) * 121)
      PRINT #ModemCh; "CHANGE TO:  <RETURN>=NO CHANGE"
      PRINT #ModemCh; Z; " ";
      GLine()
      IF L$ <> ""
        S$ = L$
        StoreLine(Z)
      ENDIF
    ENDIF
  LOOP
ENDFUNC

' Lists the lines of the message
FUNC ListLines()
  LOCAL K
  FOR K = 1 TO MsgLines
    PRINT #ModemCh; K; " "; $(ADR(MsgText) + (K - 1) * 121)
  NEXT K
ENDFUNC

' Writes the message at the end of MESSAGE.DIL.  Rec = 0 adds it to the
' index as a new message (Create); else index record Rec is changed to
' point to the new copy, keeping its number (Update).  The old copy stays
' in MESSAGE.DIL until a compactor rewrites the base
FUNC SaveMessage(Rec)
  LOCAL K, Sect, Bt, Code, P, NRec
  IF Rec = 0
    INC HMsg
    MsgNo$ = STR$(10000 + HMsg)[2]
  ENDIF
  PRINT #ModemCh; "SAVING MESSAGE...."
  CloseModem()
  CLOSE #FileCh
  OPEN #FileCh, 12, 0, MDF$
  NOTE #FileCh, NoteSect, NoteByte
  POINT #FileCh, MSect, MByte
  GetTime()
  Sect = MSect
  Bt = MByte
  PRINT #FileCh; MsgNo$
  PRINT #FileCh; Subj$
  PRINT #FileCh; NowDate$
  PRINT #FileCh; NowTime$
  PRINT #FileCh; From$
  PRINT #FileCh; ToWho$
  PRINT #FileCh; MsgLines
  Code = ERR()
  FOR K = 1 TO MsgLines
    PRINT #FileCh; $(ADR(MsgText) + (K - 1) * 121)
    St = ERR()
    IF St <> 1 THEN Code = St
  NEXT K
  NOTE #FileCh, MSect, MByte
  CLOSE #FileCh
  IF Code <> 1
    MSect = Sect
    MByte = Bt
    IF Rec = 0 THEN DEC HMsg
    OpenModem()
    PRINT #ModemCh; "MESSAGE FILE FULL, NOT SAVED"
    RETURN
  ENDIF
  IF Rec = 0
    PRINT #LogCh; "MSG #:"; MsgNo$; ".  SUBJ:"; Subj$; ".  FROM:"; From$; ".  TO:"; ToWho$
  ELSE
    PRINT #LogCh; "CHANGED MSG #:"; MsgNo$; " BY "; Name$
  ENDIF
  FOR K = 1 TO MsgLines
    PRINT #LogCh; $(ADR(MsgText) + (K - 1) * 121)
  NEXT K
  LogCheck()
  ' Update the index
  FileName$ = MIF$
  IF ReadFile() <> 1 THEN RETURN
  CloseModem()
  NRec = BufLen / 40
  IF Rec = 0
    IF (NRec + 1) * 40 > BufSize
      OpenModem()
      PRINT #ModemCh; "MESSAGE INDEX FULL"
      RETURN
    ENDIF
    INC NRec
    Rec = NRec
  ENDIF
  P = ADR(Buf) + (Rec - 1) * 40
  MOVE ADR(MsgNo$) + 1, P, 4
  MSET P + 4, 33, 32
  MOVE ADR(Subj$) + 1, P + 4, LEN(Subj$)
  ' High byte of the 16-bit sector, also above 32767 (negative here)
  K = (Sect & $7FFF) / 256
  IF Sect < 0 THEN K = K + 128
  POKE P + 37, K
  POKE P + 38, Sect & 255
  POKE P + 39, Bt
  BufLen = NRec * 40
  OPEN #FileCh, 8, 0, MIF$
  BPUT #FileCh, ADR(Buf), BufLen
  CLOSE #FileCh
  Msgs = NRec
  SaveBaseMeta()
  PRINT #LogCh; MSect - NoteSect
  LogCheck()
  OpenModem()
  PRINT #ModemCh; "SAVED AS MSG#"; MsgNo$
ENDFUNC

' True if the logged in user may change the message just read (From$):
' its author or a level 8/9 moderator
FUNC CanChange()
  IF UserLevel >= 8 THEN RETURN 1
  S$ = From$
  RETURN SameName()
ENDFUNC

' Asks for a message number for K (Mode 0) or M (Mode 1) and loads the
' index.  Returns its index record, or 0
FUNC SelectMessage(Mode)
  LOCAL NRec, F
  FileName$ = MIF$
  IF ReadFile() <> 1 THEN RETURN 0
  NRec = BufLen / 40
  IF NRec = 0
    PRINT #ModemCh; "No Messages"
    RETURN 0
  ENDIF
  PRINT #ModemCh; "First Msg# "; RecNum(1); "  Last Msg# "; RecNum(NRec)
  Spec$ = ""
  IF LEN(L$) > 2 THEN Spec$ = L$[3]
  DO
    IF Lost THEN RETURN 0
    IF Spec$ = ""
      IF Mode = 0
        PRINT #ModemCh; "<RETURN>=EXIT, Kill <Msg#>";
      ELSE
        PRINT #ModemCh; "<RETURN>=EXIT, Modify <Msg#>";
      ENDIF
      GLine()
      IF L$ = "" THEN RETURN 0
      Spec$ = L$
    ENDIF
    ParseRange()
    Spec$ = ""
    IF Dir <> 0
      F = FindRec(NRec)
      IF F >= 1 AND F <= NRec THEN EXIT
    ENDIF
  LOOP
  IF RecNum(F) <> From
    PRINT #ModemCh; "MESSAGE NOT FOUND"
    RETURN 0
  ENDIF
  RETURN F
ENDFUNC

' K: deletes a message (Delete); its author or a level 8/9 moderator can
FUNC KillMessage()
  LOCAL NRec, F, P
  PRINT #ModemCh; "Kill Message"
  F = SelectMessage(0)
  IF F = 0 THEN RETURN
  IF ShowMessage(F, 1) = 24 THEN RETURN
  IF NOT CanChange()
    PRINT #ModemCh; "AUTHOR OR MODERATOR REQUIRED"; CHR$(ControlChar(0))
    RETURN
  ENDIF
  PRINT #ModemCh; "Delete this message";
  IF NOT YesNo() THEN RETURN
  NRec = BufLen / 40
  P = ADR(Buf) + (F - 1) * 40
  IF F < NRec THEN MOVE P + 40, P, (NRec - F) * 40
  BufLen = (NRec - 1) * 40
  CloseModem()
  CLOSE #FileCh
  OPEN #FileCh, 8, 0, MIF$
  IF BufLen > 0 THEN BPUT #FileCh, ADR(Buf), BufLen
  CLOSE #FileCh
  Msgs = NRec - 1
  SaveBaseMeta()
  PRINT #LogCh; "KILLED MSG "; MsgNo$; " BY "; Name$
  LogCheck()
  OpenModem()
  PRINT #ModemCh; "MESSAGE DELETED"
ENDFUNC

' M: changes a message (Update); its author or a level 8/9 moderator can
FUNC ModifyMessage()
  LOCAL F
  PRINT #ModemCh; "Modify Message"
  F = SelectMessage(1)
  IF F = 0 THEN RETURN
  IF ShowMessage(F, 0) = 24 THEN RETURN
  IF NOT CanChange()
    PRINT #ModemCh; "AUTHOR OR MODERATOR REQUIRED"; CHR$(ControlChar(0))
    RETURN
  ENDIF
  PRINT #ModemCh; "SUBJECT: "; Subj$
  PRINT #ModemCh; "New subject <RETURN>=NO CHANGE ";
  GLine()
  IF L$ <> "" THEN Subj$ = L$[1, 33]
  IF Lost THEN RETURN
  IF EditorMenu() THEN SaveMessage(F)
ENDFUNC
