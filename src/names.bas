' Case-insensitive comparison used by message ownership checks.

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
