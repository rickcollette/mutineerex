' Values that must survive exBASIC RUN while one module replaces another.
' Caller identity, access and terminal modes live in REMMS's resident session
' block; this small COMMON record only carries the software clock and the
' circular caller-log position.
COMMON Hour, Minute, Second, Day, Month, Year, LastTick, Fps, CallNo, CSect, CByte
