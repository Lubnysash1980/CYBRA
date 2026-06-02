#!/data/data/com.termux/files/usr/bin/bash
set -e

OWNER_AMOUNT="29400000000000000"

PRICE="${1:-0}"

python3 - <<PY
from decimal import Decimal, getcontext
getcontext().prec = 50

owner = Decimal("$OWNER_AMOUNT")
price = Decimal("$PRICE")

value = owner * price

print("KIBRA OWNER TOKENS:", owner)
print("PRICE PER KIBRA USD:", price)
print("THEORETICAL OWNER VALUE USD:", value)
print()
print("NOTE: This is theoretical only. Real value requires liquidity, buyers and market price.")
PY
