' Mutineer-eX BLACKJACK - REMMS-aware casino door.
' A 52-card shoe is dealt without replacement. Dealer stands on 17.
INCLUDE "module_common.bas"
ModuleImage = 7
INCLUDE "module_env.bas"

DIM Deck(51) BYTE, PlayerHand(10) BYTE, DealerHand(10) BYTE
DIM DeckLeft, PlayerCards, DealerCards, Bankroll, Bet, GameDone, PeakBankroll

AttachModule(7)
OpenModem()
POKE 82, 0
POKE 83, 39
Bankroll = 100
PeakBankroll = Bankroll
NewShoe()
ShowBlackjackWelcome()
SetBlackjackScoreFiles()
ShowDoorScores()

DO
  IF Lost OR GameDone OR Bankroll <= 0 THEN EXIT
  AskBet()
  IF Lost OR GameDone THEN EXIT
  PlayBlackjackHand()
  IF Bankroll > PeakBankroll THEN PeakBankroll = Bankroll
LOOP

SetBlackjackScoreFiles()
SaveDoorScore(PeakBankroll)
OpenModem()
IF Bankroll <= 0 THEN PRINT #ModemCh; "THE HOUSE HAS YOUR LAST CREDIT."
IF NOT Lost
  PRINT #ModemCh,
  PRINT #ModemCh; "LEAVING BLACKJACK WITH "; Bankroll; " CREDITS."
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

FUNC SetBlackjackScoreFiles()
  FileName$ = DataDrive$ : FileName$ =+ "BJHI10.TXT"
  BaseDesc$ = DataDrive$ : BaseDesc$ =+ "BJHI10.TMP"
  Spec$ = DataDrive$ : Spec$ =+ "BJHI10.BAK"
  Marker$ = "BJHI10.BAK"
  Prompt$ = "BJHI10.TXT"
  BaseName$ = "BLACKJACK TOP TEN"
ENDFUNC

FUNC ShowBlackjackWelcome()
  PRINT #ModemCh,
  PRINT #ModemCh; "+------------------------------------+"
  PRINT #ModemCh; "|    Mutineer-eX 1.0.8 BLACKJACK    |"
  PRINT #ModemCh; "+------------------------------------+"
  PRINT #ModemCh; "BLACKJACK PAYS 3 TO 2."
  PRINT #ModemCh; "DEALER STANDS ON 17."
  PRINT #ModemCh; "NO INSURANCE OR SPLITS. BANK: 100."
  PRINT #ModemCh; "H=HIT  S=STAND  D=DOUBLE"
ENDFUNC

FUNC NewShoe()
  LOCAL K
  FOR K = 0 TO 51
    Deck(K) = K
  NEXT K
  DeckLeft = 52
ENDFUNC

FUNC DrawCard()
  LOCAL Pick, Card
  IF DeckLeft = 0 THEN NewShoe()
  Pick = RAND(DeckLeft)
  Card = Deck(Pick)
  DEC DeckLeft
  Deck(Pick) = Deck(DeckLeft)
  RETURN Card
ENDFUNC

FUNC CardPoints(Card)
  LOCAL Rank
  Rank = Card MOD 13
  IF Rank = 0 THEN RETURN 11
  IF Rank >= 9 THEN RETURN 10
  RETURN Rank + 1
ENDFUNC

FUNC PlayerTotal()
  LOCAL K, Total, Aces
  FOR K = 0 TO PlayerCards - 1
    Total = Total + CardPoints(PlayerHand(K))
    IF PlayerHand(K) MOD 13 = 0 THEN INC Aces
  NEXT K
  WHILE Total > 21 AND Aces > 0
    Total = Total - 10
    DEC Aces
  WEND
  RETURN Total
ENDFUNC

FUNC DealerTotal()
  LOCAL K, Total, Aces
  FOR K = 0 TO DealerCards - 1
    Total = Total + CardPoints(DealerHand(K))
    IF DealerHand(K) MOD 13 = 0 THEN INC Aces
  NEXT K
  WHILE Total > 21 AND Aces > 0
    Total = Total - 10
    DEC Aces
  WEND
  RETURN Total
ENDFUNC

FUNC PrintCard(Card)
  LOCAL Rank, Suit
  Rank = Card MOD 13
  Suit = Card / 13
  PRINT #ModemCh; "[";
  IF Rank = 0
    PRINT #ModemCh; "A";
  ELIF Rank = 9
    PRINT #ModemCh; "10";
  ELIF Rank = 10
    PRINT #ModemCh; "J";
  ELIF Rank = 11
    PRINT #ModemCh; "Q";
  ELIF Rank = 12
    PRINT #ModemCh; "K";
  ELSE
    PRINT #ModemCh; Rank + 1;
  ENDIF
  IF Suit = 0
    PRINT #ModemCh; "S";
  ELIF Suit = 1
    PRINT #ModemCh; "H";
  ELIF Suit = 2
    PRINT #ModemCh; "D";
  ELSE
    PRINT #ModemCh; "C";
  ENDIF
  PRINT #ModemCh; "]";
ENDFUNC

FUNC ShowTable(HideDealer)
  LOCAL K
  PRINT #ModemCh,
  PRINT #ModemCh; "+------------------------------------+"
  PRINT #ModemCh; " BANK "; Bankroll; "   BET "; Bet; "   SHOE "; DeckLeft
  PRINT #ModemCh; "+------------------------------------+"
  PRINT #ModemCh; " DEALER ";
  FOR K = 0 TO DealerCards - 1
    IF HideDealer AND K = 0
      PRINT #ModemCh; "[??]";
    ELSE
      PrintCard(DealerHand(K))
    ENDIF
    PRINT #ModemCh; " ";
  NEXT K
  IF NOT HideDealer THEN PRINT #ModemCh; " = "; DealerTotal();
  PRINT #ModemCh,
  PRINT #ModemCh; " PLAYER ";
  FOR K = 0 TO PlayerCards - 1
    PrintCard(PlayerHand(K))
    PRINT #ModemCh; " ";
  NEXT K
  PRINT #ModemCh; " = "; PlayerTotal()
  PRINT #ModemCh; "+------------------------------------+"
ENDFUNC

FUNC ReadGameKey()
  Il = 2
  GLine()
  IF L$ = "" THEN RETURN 0
  Marker$ = UCASE$(L$[1, 1])
  RETURN PEEK(ADR(Marker$) + 1)
ENDFUNC

FUNC AskBet()
  LOCAL MaxBet
  IF Bankroll > 100
    MaxBet = 100
  ELSE
    MaxBet = Bankroll
  ENDIF
  DO
    OpenModem()
    PRINT #ModemCh,
    PRINT #ModemCh; "BANKROLL: "; Bankroll; "   MAX BET: "; MaxBet
    PRINT #ModemCh; "BET 1-"; MaxBet; " OR Q TO QUIT >";
    Il = 5
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

FUNC WaitNextHand()
  LOCAL Key
  PRINT #ModemCh; "PRESS RETURN FOR THE NEXT HAND."
  DO
    Key = GetChr()
  LOOP UNTIL Key = 155 OR Lost
ENDFUNC

FUNC SettleHand(PlayerScore, DealerScore)
  IF PlayerScore > 21
    Bankroll = Bankroll - Bet
    PRINT #ModemCh; "BUST. YOU LOSE "; Bet; "."
  ELIF DealerScore > 21
    Bankroll = Bankroll + Bet
    PRINT #ModemCh; "DEALER BUSTS. YOU WIN "; Bet; "."
  ELIF PlayerScore > DealerScore
    Bankroll = Bankroll + Bet
    PRINT #ModemCh; "YOU WIN "; Bet; "."
  ELIF PlayerScore < DealerScore
    Bankroll = Bankroll - Bet
    PRINT #ModemCh; "DEALER WINS. YOU LOSE "; Bet; "."
  ELSE
    PRINT #ModemCh; "PUSH. YOUR BET IS RETURNED."
  ENDIF
ENDFUNC

FUNC PlayBlackjackHand()
  LOCAL Key, PlayerScore, DealerScore, Doubled
  IF DeckLeft < 15 THEN NewShoe()
  PlayerCards = 2
  DealerCards = 2
  PlayerHand(0) = DrawCard()
  DealerHand(0) = DrawCard()
  PlayerHand(1) = DrawCard()
  DealerHand(1) = DrawCard()
  PlayerScore = PlayerTotal()
  DealerScore = DealerTotal()

  IF PlayerScore = 21 OR DealerScore = 21
    ShowTable(0)
    IF PlayerScore = 21 AND DealerScore = 21
      PRINT #ModemCh; "DOUBLE BLACKJACK. PUSH."
    ELIF PlayerScore = 21
      Q1 = (Bet * 3) / 2
      Bankroll = Bankroll + Q1
      PRINT #ModemCh; "BLACKJACK! YOU WIN "; Q1; "."
    ELSE
      Bankroll = Bankroll - Bet
      PRINT #ModemCh; "DEALER BLACKJACK. YOU LOSE "; Bet; "."
    ENDIF
    WaitNextHand()
    RETURN
  ENDIF

  DO
    ShowTable(1)
    PRINT #ModemCh; "[H]IT  [S]TAND";
    IF PlayerCards = 2 AND Bet * 2 <= Bankroll THEN PRINT #ModemCh; "  [D]OUBLE";
    PRINT #ModemCh; " >";
    Key = ReadGameKey()
    IF Lost THEN RETURN
    IF Key = 72
      PlayerHand(PlayerCards) = DrawCard()
      INC PlayerCards
      PlayerScore = PlayerTotal()
      IF PlayerScore >= 21 THEN EXIT
    ELIF Key = 83
      EXIT
    ELIF Key = 68 AND PlayerCards = 2 AND Bet * 2 <= Bankroll
      Bet = Bet * 2
      Doubled = 1
      PlayerHand(PlayerCards) = DrawCard()
      INC PlayerCards
      PlayerScore = PlayerTotal()
      EXIT
    ELSE
      PRINT #ModemCh; "TYPE H, S";
      IF PlayerCards = 2 AND Bet * 2 <= Bankroll THEN PRINT #ModemCh; " OR D";
      PRINT #ModemCh; "."
    ENDIF
  LOOP

  PlayerScore = PlayerTotal()
  IF PlayerScore <= 21
    DealerScore = DealerTotal()
    WHILE DealerScore < 17
      DealerHand(DealerCards) = DrawCard()
      INC DealerCards
      DealerScore = DealerTotal()
    WEND
  ENDIF
  ShowTable(0)
  SettleHand(PlayerScore, DealerScore)
  WaitNextHand()
ENDFUNC
