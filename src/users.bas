' ====================================================================
' User accounts (new in this version)
' ====================================================================
' USERS.DAT is a text file with three lines for each user: name, city
' and PASSWORD,LEVEL (letters are stored in uppercase). Level 0 disables
' an account. User record 1
' and the configured sysop are always level 9.
' The sysop can edit it on a PC with tools/atascii.py.

' True if S$ and Name$ are the same name, ignoring upper/lower case
FUNC SameName()
  Q2 = LEN(Name$)
  IF LEN(S$) <> Q2 THEN RETURN 0
  Q5 = ADR(S$)
  Q6 = ADR(Name$)
  FOR Q1 = 1 TO Q2
    Q3 = PEEK(Q5 + Q1)
    Q4 = PEEK(Q6 + Q1)
    IF Q3 >= 97 AND Q3 <= 122 THEN Q3 = Q3 - 32
    IF Q4 >= 97 AND Q4 <= 122 THEN Q4 = Q4 - 32
    IF Q3 <> Q4 THEN RETURN 0
  NEXT Q1
  RETURN 1
ENDFUNC

' Looks for Name$ in USERS.DAT.  When found, returns 1 and sets Name$
' (as registered), Addr$ and UserPass$
FUNC FindUser()
  LOCAL Found
  Dir = 0
  CloseModem()
  CLOSE #FileCh
  OPEN #FileCh, 4, 0, UserFile$
  IF ERR() = 1
    DO
      INPUT #FileCh, S$
      IF ERR() <> 1 THEN EXIT
      IF S$ = "*" THEN EXIT
      INC Dir
      Found = SameName()
      IF Found THEN From$ = S$[1, 40]
      INPUT #FileCh, T$
      INPUT #FileCh, S$
      IF Found
        IF LEN(S$) = 6 AND S$[5, 1] = ","
          UserLevel = VAL(S$[6])
          IF UserLevel >= 0 AND UserLevel <= 9
            Name$ = From$
            Addr$ = T$[1, 40]
            UserPass$ = S$[1, 4]
            IF Dir = 1 OR NameIsSysop() THEN UserLevel = 9
            EXIT
          ENDIF
        ENDIF
        Found = 0
      ENDIF
    LOOP
  ENDIF
  CLOSE #FileCh
  OpenModem()
  RETURN Found
ENDFUNC

' Reads a password of up to 4 characters into L$, showing "*".
' Letters are changed to uppercase
FUNC GetPassword()
  LOCAL C, N
  L$ = ""
  NoEcho = 1
  DO
    C = GetChr()
    IF Lost
      L$ = ""
      EXIT
    ENDIF
    N = LEN(L$)
    IF C = 155
      PRINT #ModemCh,
      EXIT
    ELIF C = ControlChar(1) OR C = ControlChar(2) OR (C = 127 AND NOT AMode)
      IF N > 0
        PRINT #ModemCh; CHR$(ControlChar(1)); " "; CHR$(ControlChar(1));
        L$ = L$[1, N - 1]
      ENDIF
    ELIF C > 32 AND C < 127 AND N < 4
      IF C >= 97 AND C <= 122 THEN C = C - 32
      L$ =+ CHR$(C)
      PUT #ModemCh, 42
    ELSE
      PUT #ModemCh, ControlChar(0)
    ENDIF
  LOOP
  NoEcho = 0
ENDFUNC

' Registers Name$ as a new user.  Returns 1 when done
FUNC Register()
  Il = 40
  DO
    PRINT #ModemCh; "From City,State >";
    GLine()
    IF Lost THEN RETURN 0
    IF LEN(L$) >= 3 THEN EXIT
  LOOP
  Addr$ = L$
  PRINT #ModemCh; "You are "; Name$
  PRINT #ModemCh; "Calling from "; Addr$
  PRINT #ModemCh; "CORRECT";
  IF NOT YesNo() THEN RETURN 0
  DO
    PRINT #ModemCh; "Choose a 4 character password >";
    GetPassword()
    IF Lost THEN RETURN 0
    IF LEN(L$) = 4
      UserPass$ = L$
      PRINT #ModemCh; "Type it again >";
      GetPassword()
      IF L$ = UserPass$ THEN EXIT
      PRINT #ModemCh; "The passwords are different."
    ELSE
      PRINT #ModemCh; "The password must have 4 characters."
    ENDIF
    IF Lost THEN RETURN 0
  LOOP
  CloseModem()
  CLOSE #FileCh
  ' Find the end marker in the fixed user base. Older grow-as-needed
  ' USERS.DAT files without a marker are accepted and gain one here.
  OPEN #FileCh, 12, 0, UserFile$
  IF ERR() = 170
    CLOSE #FileCh
    OPEN #FileCh, 8, 0, UserFile$
    CLOSE #FileCh
    OPEN #FileCh, 12, 0, UserFile$
  ENDIF
  Dir = 0
  DO
    NOTE #FileCh, NoteSect, NoteByte
    INPUT #FileCh, S$
    St = ERR()
    IF St <> 1 OR S$ = "*" THEN EXIT
    INPUT #FileCh, T$
    INPUT #FileCh, S$
    IF ERR() <> 1 THEN EXIT
    INC Dir
  LOOP
  BFlag = 0
  IF Dir = 0 THEN BFlag = 1
  POINT #FileCh, NoteSect, NoteByte
  PRINT #FileCh; Name$
  PRINT #FileCh; Addr$
  UserLevel = 1
  IF BFlag OR NameIsSysop() THEN UserLevel = 9
  T$ = UserPass$
  T$ =+ ","
  T$ =+ STR$(UserLevel)
  PRINT #FileCh; T$
  PRINT #FileCh; "*"
  St = ERR()
  CLOSE #FileCh
  IF St <> 1
    OpenModem()
    PRINT #ModemCh; "SYSTEM ERROR - YOU ARE NOT REGISTERED."
    RETURN 0
  ENDIF
  PRINT #LogCh; "NEW USER "; Name$; " FROM "; Addr$
  LogCheck()
  OpenModem()
  IF UserLevel = 1
    PRINT #ModemCh; "Registered at access level 1."
    PRINT #ModemCh; "The sysop must approve higher access."
  ELSE
    PRINT #ModemCh; "You are registered. Remember your password!"
  ENDIF
  RETURN 1
ENDFUNC

' True when Name$ is the sysop account (SysopName$ of the settings)
FUNC NameIsSysop()
  S$ = SysopName$
  RETURN SameName()
ENDFUNC

' Asks the name and the password, or registers a new user.
' Sets UserLevel from 1 through 9.
' Returns 0 = failed, 1 = known user, 2 = new user
FUNC UserLogin()
  LOCAL Tries
  UserLevel = 1
  DO
    Il = 40
    DO
      PRINT #ModemCh,
      PRINT #ModemCh; "Enter your Name >";
      GLine()
      IF Lost THEN RETURN 0
      IF LEN(L$) >= 3 THEN EXIT
    LOOP
    Name$ = L$
    IF FindUser()
      IF UserLevel = 0
        PRINT #ModemCh; "THIS ACCOUNT IS DISABLED."
        PRINT #ModemCh; "CONTACT THE SYSOP."
        RETURN 0
      ENDIF
      FOR Tries = 1 TO 3
        PRINT #ModemCh; "Password >";
        GetPassword()
        IF Lost THEN RETURN 0
        IF L$ = UserPass$
          PRINT #ModemCh; "Welcome back, "; Name$; " from "; Addr$
          PRINT #ModemCh; "Access level "; UserLevel
          RETURN 1
        ENDIF
        PRINT #ModemCh; "WRONG PASSWORD"; CHR$(ControlChar(0))
      NEXT Tries
      CloseModem()
      GetTime()
      PRINT #LogCh; "BAD PASSWORD FOR "; Name$; " AT "; NowTime$
      LogCheck()
      OpenModem()
      PRINT #ModemCh; "Sorry, please call again."
      RETURN 0
    ENDIF
    PRINT #ModemCh; Name$; " is not a user of this BBS."
    ' The sysop account can only be made at the BBS keyboard
    IF NameIsSysop() AND NOT LocalMode
      PRINT #ModemCh; "That name is reserved."
    ELSE
      PRINT #ModemCh; "Register as a new user";
      IF YesNo()
        IF Register()
          RETURN 2
        ENDIF
      ENDIF
    ENDIF
    IF Lost THEN RETURN 0
  LOOP
ENDFUNC

' True if S$ and Spec$ are the same name, ignoring case
FUNC SameTarget()
  Dir = 0
  Q2 = LEN(Spec$)
  IF LEN(S$) <> Q2 THEN RETURN
  Q5 = ADR(S$)
  Q6 = ADR(Spec$)
  FOR Q1 = 1 TO Q2
    Q3 = PEEK(Q5 + Q1)
    Q4 = PEEK(Q6 + Q1)
    IF Q3 >= 97 AND Q3 <= 122 THEN Q3 = Q3 - 32
    IF Q4 >= 97 AND Q4 <= 122 THEN Q4 = Q4 - 32
    IF Q3 <> Q4 THEN RETURN
  NEXT Q1
  Dir = 1
ENDFUNC

' Z: level 9 changes a user's access level; level 0 disables the account.
' Names, cities and passwords
' are copied unchanged while USERS.DAT is rewritten.
FUNC ManageUsers()
  IF UserLevel < 9
    PRINT #ModemCh; "LEVEL 9 REQUIRED"
    RETURN
  ENDIF
  PRINT #ModemCh; "User name >";
  Il = 40
  GLine()
  IF L$ = "" THEN RETURN
  Spec$ = L$
  PRINT #ModemCh; "New level 0-9 (0=disabled) >";
  GLine()
  From = VAL(L$)
  IF From < 0 OR From > 9
    PRINT #ModemCh; "NOT VALID"
    RETURN
  ENDIF
  S$ = SysopName$
  SameTarget()
  IF Dir AND From <> 9
    PRINT #ModemCh; "CONFIGURED SYSOP IS ALWAYS LEVEL 9"
    RETURN
  ENDIF
  CloseModem()
  CLOSE #FileCh
  OPEN #FileCh, 4, 0, UserFile$
  St = ERR()
  BufLen = 0
  BFlag = 0
  Upto = 0
  IF St = 1
    DO
      INPUT #FileCh, S$
      IF ERR() <> 1 THEN EXIT
      IF S$ = "*" THEN EXIT
      INC Upto
      SameTarget()
      IF Dir AND Upto = 1 AND From <> 9
        BFlag = 2
        EXIT
      ENDIF
      T$ = S$
      IF BufLen + LEN(T$) + 1 > BufSize
        St = 162
        EXIT
      ENDIF
      BufAdd(1)
      INPUT #FileCh, S$
      IF ERR() <> 1
        St = ERR()
        EXIT
      ENDIF
      T$ = S$
      IF BufLen + LEN(T$) + 1 > BufSize
        St = 162
        EXIT
      ENDIF
      BufAdd(1)
      INPUT #FileCh, S$
      IF ERR() <> 1
        St = ERR()
        EXIT
      ENDIF
      IF Dir
        BFlag = 1
        S$ = S$[1, 4]
        S$ =+ ","
        S$ =+ STR$(From)
      ENDIF
      T$ = S$
      IF BufLen + LEN(T$) + 1 > BufSize
        St = 162
        EXIT
      ENDIF
      BufAdd(1)
    LOOP
  ENDIF
  CLOSE #FileCh
  IF St = 1 AND BFlag = 1
    T$ = "*"
    BufAdd(1)
    OPEN #FileCh, 12, 0, UserFile$
    IF BufLen > 0 THEN BPUT #FileCh, ADR(Buf), BufLen
    St = ERR()
    CLOSE #FileCh
  ENDIF
  IF BFlag = 1 AND St = 1
    PRINT #LogCh; "USER LEVEL "; Spec$; " = "; From; " BY "; Name$
    LogCheck()
  ENDIF
  OpenModem()
  IF BFlag = 2
    PRINT #ModemCh; "USER 1 IS ALWAYS LEVEL 9"
  ELIF NOT BFlag
    PRINT #ModemCh; "USER NOT FOUND"
  ELIF St <> 1
    PRINT #ModemCh; "ERROR "; St; " UPDATING USERS"
  ELSE
    PRINT #ModemCh; Spec$; " IS NOW LEVEL "; From
  ENDIF
ENDFUNC
