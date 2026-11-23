' Resolve one configured source path through the explicit RAM-cache manifest.
' FileName$ enters as the disk path.  It changes to O:<basename> only when
' that exact source is selected.  A selected file that failed to copy therefore
' fails visibly on O: instead of silently falling back to disk.
FUNC ResolveCachePath()
  LOCAL Code, P, K, C, ManifestVersion
  IF NOT StartOption(2) THEN RETURN 0
  CLOSE #FileCh
  OPEN #FileCh, 4, 0, "D1:RAMCACHE.CFG"
  Code = ERR()
  IF Code <> 1 THEN CLOSE #FileCh : RETURN 0
  INPUT #FileCh, S$
  Code = ERR()
  IF S$ = "MUTINREX RAMCACHE 2" THEN ManifestVersion = 2
  IF S$ = "MUTINREX RAMCACHE 1" THEN ManifestVersion = 1
  IF Code <> 1 OR ManifestVersion = 0 THEN CLOSE #FileCh : RETURN 0
  DO
    INPUT #FileCh, S$
    Code = ERR()
    IF Code <> 1 THEN EXIT
    T$ = S$
    P = INSTR(S$, "|")
    IF ManifestVersion = 2 AND P > 1 AND P < LEN(S$)
      T$ = S$[1, P - 1]
    ENDIF
    IF UCASE$(T$) = UCASE$(FileName$)
      CLOSE #FileCh
      IF ManifestVersion = 2 AND P > 1 AND P < LEN(S$)
        FileName$ = S$[P + 1, LEN(S$) - P]
        RETURN 1
      ENDIF
      ' Version 1 compatibility: infer the old implicit destination.
      P = 0
      FOR K = 1 TO LEN(FileName$)
        C = PEEK(ADR(FileName$) + K)
        IF C = 58 OR C = 47 OR C = 92 OR C = 62 THEN P = K
      NEXT K
      IF P > 0 AND P < LEN(FileName$)
        S$ = FileName$[P + 1, LEN(FileName$) - P]
        ' SDX exposes its lettered RAM drive through the D: CIO handler.
        ' EOS instead needs REMMS's native O: CIO bridge.
        OPEN #FileCh, 4, 0, "D1:SDX.ENV"
        Code = ERR()
        CLOSE #FileCh
        IF Code = 1
          FileName$ = "DO:"
        ELSE
          FileName$ = "O:"
        ENDIF
        FileName$ =+ S$
        RETURN 1
      ENDIF
      RETURN 0
    ENDIF
  LOOP
  CLOSE #FileCh
  RETURN 0
ENDFUNC
