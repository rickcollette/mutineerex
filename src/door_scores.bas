' Shared persistent top-ten support for game doors.
' The caller sets FileName$ to the final file, BaseDesc$ to a temporary
' filename, Spec$ to the full backup path, Marker$ to its bare filename,
' Prompt$ to the bare final filename, and BaseName$ to the title.

FUNC ScorePlayerName$()
  IF Name$ = "" THEN RETURN "LOCAL PLAYER"
  IF LEN(Name$) > 20 THEN RETURN Name$[1, 20]
  RETURN Name$
ENDFUNC

FUNC ShowDoorScores()
  LOCAL Rank, P, OldScore, Code
  OpenModem()
  PRINT #ModemCh,
  PRINT #ModemCh; "+------------------------------------+"
  PRINT #ModemCh; " "; BaseName$
  PRINT #ModemCh; "+------------------------------------+"
  CLOSE #FileCh
  OPEN #FileCh, 4, 0, FileName$
  Code = ERR()
  Rank = 0
  IF Code = 1
    DO
      INPUT #FileCh, T$
      Code = ERR()
      IF Code <> 1 THEN EXIT
      P = INSTR(T$, "|")
      IF P > 1
        OldScore = VAL(T$[1, P - 1])
        INC Rank
        PRINT #ModemCh; Rank; ". "; OldScore; "  "; T$[P + 1]
        IF Rank = 10 THEN EXIT
      ENDIF
    LOOP
  ENDIF
  CLOSE #FileCh
  IF Rank = 0 THEN PRINT #ModemCh; "NO SCORES YET. YOU COULD BE FIRST!"
  PRINT #ModemCh; "+------------------------------------+"
ENDFUNC

FUNC WriteDoorScore(Score)
  T$ = STR$(Score) : T$ =+ "|" : T$ =+ ScorePlayerName$()
  PRINT #5; T$
  RETURN ERR()
ENDFUNC

FUNC SaveDoorScore(Score)
  LOCAL Count, Inserted, P, OldScore, Code, OldMoved
  ' Build the replacement completely before touching the live leaderboard.
  XIO 33, #5, 0, 0, BaseDesc$
  CLOSE #5
  OPEN #5, 8, 0, BaseDesc$
  IF ERR() <> 1 THEN RETURN

  CLOSE #FileCh
  OPEN #FileCh, 4, 0, FileName$
  Code = ERR()
  IF Code = 1
    DO
      INPUT #FileCh, S$
      Code = ERR()
      IF Code <> 1 THEN EXIT
      P = INSTR(S$, "|")
      IF P > 1
        OldScore = VAL(S$[1, P - 1])
        IF NOT Inserted AND Score > OldScore AND Count < 10
          Code = WriteDoorScore(Score)
          IF Code <> 1 THEN EXIT
          INC Count
          Inserted = 1
        ENDIF
        IF Count < 10
          PRINT #5; S$
          Code = ERR()
          IF Code <> 1 THEN EXIT
          INC Count
        ENDIF
      ENDIF
    LOOP
  ELIF Code = 170
    Code = 1
  ENDIF
  CLOSE #FileCh
  IF Code <> 1 AND Code <> 136 THEN CLOSE #5 : RETURN
  IF NOT Inserted AND Count < 10
    Code = WriteDoorScore(Score)
    IF Code = 1 THEN Inserted = 1
  ENDIF
  CLOSE #5
  IF Code <> 1 THEN RETURN

  ' EOS XIO 32 renames OLD,NEW. Keep a backup until the new file is live.
  T$ = Spec$
  XIO 33, #FileCh, 0, 0, T$
  S$ = FileName$ : S$ =+ "," : S$ =+ Marker$
  XIO 32, #FileCh, 0, 0, S$
  Code = ERR()
  IF Code = 1 THEN OldMoved = 1
  IF Code <> 1 AND Code <> 170 THEN RETURN

  S$ = BaseDesc$ : S$ =+ "," : S$ =+ Prompt$
  XIO 32, #FileCh, 0, 0, S$
  Code = ERR()
  IF Code <> 1 AND OldMoved
    S$ = T$ : S$ =+ "," : S$ =+ Prompt$
    XIO 32, #FileCh, 0, 0, S$
    RETURN
  ENDIF
  IF Code = 1 THEN XIO 33, #FileCh, 0, 0, T$
ENDFUNC
