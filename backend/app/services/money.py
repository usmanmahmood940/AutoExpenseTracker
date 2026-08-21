"""Money helpers. Storage is Numeric; JSON still wants a number for Flutter."""

from __future__ import annotations

from decimal import ROUND_HALF_UP, Decimal

CENTS = Decimal("0.01")
ZERO = Decimal("0.00")


def as_money(value: Decimal | int | float | str) -> Decimal:
    return Decimal(str(value)).quantize(CENTS, rounding=ROUND_HALF_UP)


def money_float(value: Decimal | int | float | str) -> float:
    return float(as_money(value))
