' Resolve one configured source path through the explicit RAM-cache manifest.
' FileName$ enters as the disk path.  It changes to O:<basename> only when
' that exact source is selected.  A selected file that failed to copy therefore
' fails visibly on O: instead of silently falling back to disk.
FUNC ResolveCachePath()
  LOCAL Code, P, K, C
  IF NOT StartOption(2) THEN RETURN 0
  CLOSE #FileCh
  OPEN #FileCh, 4, 0, "D1:RAMCACHE.CFG"
  Code = ERR()
  IF Code <> 1 THEN CLOSE #FileCh : RETURN 0
  INPUT #FileCh, S$
  Code = ERR()
  IF Code <> 1 OR S$ <> "MUTINREX RAMCACHE 1" THEN CLOSE #FileCh : RETURN 0
  DO
    INPUT #FileCh, S$
    Code = ERR()
    IF Code <> 1 THEN EXIT
    IF UCASE$(S$) = UCASE$(FileName$)
      CLOSE #FileCh
      P = 0
      FOR K = 1 TO LEN(FileName$)
        C = PEEK(ADR(FileName$) + K)
        IF C = 58 OR C = 47 OR C = 92 OR C = 62 THEN P = K
      NEXT K
      IF P > 0 AND P < LEN(FileName$)
        S$ = FileName$[P + 1, LEN(FileName$) - P]
        FileName$ = "O:" : FileName$ =+ S$
        RETURN 1
      ENDIF
      RETURN 0
    ENDIF
  LOOP
  CLOSE #FileCh
  RETURN 0
ENDFUNC
