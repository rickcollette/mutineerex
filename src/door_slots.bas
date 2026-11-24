' Mutineer-eX LUCKY SLOTS - REMMS-aware three-reel game door.
INCLUDE "module_common.bas"
ModuleImage = 7
INCLUDE "module_env.bas"

DIM Bankroll, Bet, GameDone, PeakBankroll, Reel1, Reel2, Reel3, Pay

AttachModule(7)
OpenModem()
POKE 82, 0
POKE 83, 39
Bankroll = 100
PeakBankroll = Bankroll
ShowSlotsWelcome()
SetSlotsScoreFiles()
ShowDoorScores()

DO
  IF Lost OR GameDone OR Bankroll <= 0 THEN EXIT
  AskSlotBet()
  IF Lost OR GameDone THEN EXIT
  SpinSlots()
  IF Bankroll > PeakBankroll THEN PeakBankroll = Bankroll
LOOP

SetSlotsScoreFiles()
SaveDoorScore(PeakBankroll)
OpenModem()
IF Bankroll <= 0 THEN PRINT #ModemCh; "THE MACHINE HAS YOUR LAST CREDIT."
IF NOT Lost
  PRINT #ModemCh,
  PRINT #ModemCh; "LEAVING LUCKY SLOTS WITH "; Bankroll; " CREDITS."
ENDIF

FileName$ = "D1:doors.com"
Q1 = ResolveCachePath()
RunModule(FileName$, 6, "DOORS")

INCLUDE "clock.bas"
INCLUDE "remms.bas"
INCLUDE "module_support.bas"
INCLUDE "modem.bas"
INCLUDE "chat.bas"
INCLUDE "door_scores.bas"

FUNC SetSlotsScoreFiles()
  FileName$ = DataDrive$ : FileName$ =+ "SLOTHI10.TXT"
  BaseDesc$ = DataDrive$ : BaseDesc$ =+ "SLOTHI10.TMP"
  Spec$ = DataDrive$ : Spec$ =+ "SLOTHI10.BAK"
  Marker$ = "SLOTHI10.BAK"
  Prompt$ = "SLOTHI10.TXT"
  BaseName$ = "LUCKY SLOTS TOP TEN"
ENDFUNC

FUNC ShowSlotsWelcome()
  PRINT #ModemCh,
  PRINT #ModemCh; "+------------------------------------+"
  PRINT #ModemCh; "|   Mutineer-eX 1.0.8 LUCKY SLOTS   |"
  PRINT #ModemCh; "+------------------------------------+"
  PRINT #ModemCh; "THREE 7S PAY 20X. THREE BARS PAY 12X."
  PRINT #ModemCh; "THREE BELLS PAY 8X. ANY TRIPLE 5X."
  PRINT #ModemCh; "2 CHERRIES PAY 3X; 1 CHERRY PAYS 1X."
  PRINT #ModemCh; "STARTING BANK: 100 CREDITS."
ENDFUNC

FUNC AskSlotBet()
  LOCAL MaxBet
  IF Bankroll > 10
    MaxBet = 10
  ELSE
    MaxBet = Bankroll
  ENDIF
  DO
    OpenModem()
    PRINT #ModemCh,
    PRINT #ModemCh; "BANKROLL: "; Bankroll; "   MAX BET: "; MaxBet
    PRINT #ModemCh; "BET 1-"; MaxBet; " OR Q TO QUIT >";
    Il = 3
    GLine()
    IF Lost THEN RETURN
    IF L$ <> ""
      Marker$ = UCASE$(L$[1, 1])
      IF Marker$ = "Q"
        GameDone = 1
        RETURN
      ENDIF
      Bet = VAL(L$)
      IF Bet >= 1 AND Bet <= MaxBet THEN RETURN
    ENDIF
    PRINT #ModemCh; "INVALID BET."
  LOOP
ENDFUNC

FUNC PrintSlotSymbol(Symbol)
  IF Symbol = 0
    PRINT #ModemCh; "CHERRY";
  ELIF Symbol = 1
    PRINT #ModemCh; "LEMON";
  ELIF Symbol = 2
    PRINT #ModemCh; "ORANGE";
  ELIF Symbol = 3
    PRINT #ModemCh; "BELL";
  ELIF Symbol = 4
    PRINT #ModemCh; "BAR";
  ELSE
    PRINT #ModemCh; "SEVEN";
  ENDIF
ENDFUNC

FUNC ShowReels()
  PRINT #ModemCh,
  PRINT #ModemCh; "+------------------------------------+"
  PRINT #ModemCh; "| [";
  PrintSlotSymbol(Reel1)
  PRINT #ModemCh; "] [";
  PrintSlotSymbol(Reel2)
  PRINT #ModemCh; "] [";
  PrintSlotSymbol(Reel3)
  PRINT #ModemCh; "]"
  PRINT #ModemCh; "+------------------------------------+"
ENDFUNC

FUNC SlotPayout()
  LOCAL Cherries
  IF Reel1 = 5 AND Reel2 = 5 AND Reel3 = 5 THEN RETURN Bet * 20
  IF Reel1 = 4 AND Reel2 = 4 AND Reel3 = 4 THEN RETURN Bet * 12
  IF Reel1 = 3 AND Reel2 = 3 AND Reel3 = 3 THEN RETURN Bet * 8
  IF Reel1 = Reel2 AND Reel2 = Reel3 THEN RETURN Bet * 5
  IF Reel1 = 0 THEN INC Cherries
  IF Reel2 = 0 THEN INC Cherries
  IF Reel3 = 0 THEN INC Cherries
  IF Cherries = 2 THEN RETURN Bet * 3
  IF Cherries = 1 THEN RETURN Bet
  RETURN 0
ENDFUNC

FUNC SpinSlots()
  Bankroll = Bankroll - Bet
  Reel1 = RAND(6)
  Reel2 = RAND(6)
  Reel3 = RAND(6)
  Pay = SlotPayout()
  Bankroll = Bankroll + Pay
  ShowReels()
  IF Pay > 0
    PRINT #ModemCh; "WIN! MACHINE PAYS "; Pay; " CREDITS."
  ELSE
    PRINT #ModemCh; "NO WIN THIS SPIN."
  ENDIF
  PRINT #ModemCh; "BANKROLL: "; Bankroll
ENDFUNC
