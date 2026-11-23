' FILES - controlled-file command loop.  X returns to MAINBBS.

FUNC FileLoop()
  FileCategory = 0
  FileName$ = TextDrive$ : FileName$ =+ "FILEM"
  ShowTextFile()
  T$ = ""
  FileCategoryName()
  PRINT #ModemCh; "CATEGORY: "; T$
  DO
    IF Lost OR Bye THEN RETURN
    OpenModem()
    PRINT #ModemCh; "FILE >";
    IF NOT LocalMode THEN PRINT : PRINT "FILE >";
    Il = 120
    GLine()
    IF L$ <> ""
      Q1 = PEEK(ADR(L$) + 1)
      IF Q1 >= 97 THEN Q1 = Q1 - 32
      IF Q1 = 88 THEN RETURN
      IF Q1 = 63
        FileName$ = TextDrive$ : FileName$ =+ "FILEM" : ShowTextFile()
      ELIF Q1 = 68
        Download()
      ELIF Q1 = 70 OR Q1 = 73
        ListFiles()
      ELIF Q1 = 74
        ChangeFileCategory()
      ELIF Q1 = 85
        Upload()
      ELIF Q1 = 86
        DeleteFile()
      ELSE
        PRINT #ModemCh; "FILE COMMAND?  TYPE ? FOR MENU"; CHR$(ControlChar(0))
      ENDIF
    ENDIF
  LOOP
ENDFUNC
