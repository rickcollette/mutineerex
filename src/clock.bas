' ====================================================================
' Clock and calendar, kept from the OS frame counter
' ====================================================================
' TIME differences are correct for up to 9 minutes, so UpdateClock is
' called from every waiting loop.

' Adds the frames counted since the last call to the clock
FUNC UpdateClock()
  Q1 = TIME
  Q2 = Q1 - LastTick
  LastTick = Q1
  IF Q2 <= 0 THEN RETURN
  Q3 = Q2 / Fps
  Jiffy = Jiffy + Q2 MOD Fps
  IF Jiffy >= Fps
    Jiffy = Jiffy - Fps
    INC Q3
  ENDIF
  IF Q3 = 0 THEN RETURN
  Second = Second + Q3
  Minute = Minute + Second / 60
  Second = Second MOD 60
  Hour = Hour + Minute / 60
  Minute = Minute MOD 60
  WHILE Hour >= 24
    Hour = Hour - 24
    NextDay()
  WEND
ENDFUNC

' Moves the calendar to the next day
FUNC NextDay()
  INC Day
  Q4 = MonthDays(Month)
  IF Month = 2 AND Year MOD 4 = 0 THEN Q4 = 29
  IF Day > Q4
    Day = 1
    INC Month
    IF Month > 12
      Month = 1
      Year = (Year + 1) MOD 100
    ENDIF
  ENDIF
ENDFUNC

' Updates the clock and sets NowDate$ (MM/DD/20YY) and NowTime$ (HH:MM:SS)
FUNC GetTime()
  UpdateClock()
  NowDate$ = STR$(100 + Month)[2]
  NowDate$ =+ "/"
  NowDate$ =+ STR$(100 + Day)[2]
  NowDate$ =+ "/"
  NowDate$ =+ "20"
  NowDate$ =+ STR$(100 + Year)[2]
  NowTime$ = STR$(100 + Hour)[2]
  NowTime$ =+ ":"
  NowTime$ =+ STR$(100 + Minute)[2]
  NowTime$ =+ ":"
  NowTime$ =+ STR$(100 + Second)[2]
ENDFUNC
