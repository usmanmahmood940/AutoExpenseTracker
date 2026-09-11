"""Closed semantic vocabulary for merchant concept enrichment.

Gemini and the query resolver must pick from this list only so concept tags
are joinable against merchant_concepts.concepts.
"""

from __future__ import annotations

# Canonical concept tags. Keep snake_case; aliases map natural language → tag.
CONCEPT_VOCABULARY: tuple[str, ...] = (
    "electricity",
    "gas",
    "water",
    "internet",
    "mobile",
    "telecom",
    "utilities",
    "bills",
    "fuel",
    "fast_food",
    "restaurant",
    "coffee",
    "groceries",
    "pharmacy",
    "healthcare",
    "ride_hailing",
    "transportation",
    "subscriptions",
    "entertainment",
    "shopping",
    "rent",
    "insurance",
    "education",
    "travel",
    "atm",
    "transfer",
    "reimbursement",
    "salary",
    "investment",
    "donations",
    "pets",
    "personal_care",
    "home",
    "other",
)

CONCEPT_SET: frozenset[str] = frozenset(CONCEPT_VOCABULARY)

# Natural-language / plural / synonym → canonical concept.
CONCEPT_ALIASES: dict[str, str] = {
    "electric": "electricity",
    "power": "electricity",
    "light bill": "electricity",
    "sui gas": "gas",
    "petrol": "fuel",
    "diesel": "fuel",
    "gas station": "fuel",
    "pump": "fuel",
    "fast food": "fast_food",
    "fastfood": "fast_food",
    "burger": "fast_food",
    "pizza": "fast_food",
    "dining": "restaurant",
    "cafe": "coffee",
    "café": "coffee",
    "coffee shop": "coffee",
    "grocery": "groceries",
    "supermarket": "groceries",
    "medicine": "pharmacy",
    "medical": "healthcare",
    "doctor": "healthcare",
    "hospital": "healthcare",
    "uber": "ride_hailing",
    "careem": "ride_hailing",
    "bykea": "ride_hailing",
    "taxi": "ride_hailing",
    "transport": "transportation",
    "commute": "transportation",
    "streaming": "subscriptions",
    "netflix": "subscriptions",
    "spotify": "subscriptions",
    "phone": "mobile",
    "broadband": "internet",
    "wifi": "internet",
    "utility": "utilities",
    "bill": "bills",
    "food": "restaurant",
    "reimburse": "reimbursement",
    "refund": "reimbursement",
}

# Seed bootstrap: known merchant_normalized → concepts (zero LLM cost).
KNOWN_MERCHANT_CONCEPTS: dict[str, tuple[str, ...]] = {
    "lesco": ("electricity", "utilities", "bills"),
    "k electric": ("electricity", "utilities", "bills"),
    "kelectric": ("electricity", "utilities", "bills"),
    "ke": ("electricity", "utilities", "bills"),
    "iesco": ("electricity", "utilities", "bills"),
    "mepco": ("electricity", "utilities", "bills"),
    "gepco": ("electricity", "utilities", "bills"),
    "fesco": ("electricity", "utilities", "bills"),
    "hesco": ("electricity", "utilities", "bills"),
    "pesco": ("electricity", "utilities", "bills"),
    "qesco": ("electricity", "utilities", "bills"),
    "sepco": ("electricity", "utilities", "bills"),
    "wapda": ("electricity", "utilities", "bills"),
    "sngpl": ("gas", "utilities", "bills"),
    "ssgc": ("gas", "utilities", "bills"),
    "sui gas": ("gas", "utilities", "bills"),
    "sui northern": ("gas", "utilities", "bills"),
    "sui southern": ("gas", "utilities", "bills"),
    "wasa": ("water", "utilities", "bills"),
    "ptcl": ("internet", "telecom", "utilities", "bills"),
    "jazz": ("mobile", "telecom", "utilities", "bills"),
    "zong": ("mobile", "telecom", "utilities", "bills"),
    "ufone": ("mobile", "telecom", "utilities", "bills"),
    "telenor": ("mobile", "telecom", "utilities", "bills"),
    "nayatel": ("internet", "telecom", "utilities", "bills"),
    "stormfiber": ("internet", "telecom", "utilities", "bills"),
    "storm fiber": ("internet", "telecom", "utilities", "bills"),
    "pso": ("fuel",),
    "shell": ("fuel",),
    "total parco": ("fuel",),
    "totalparco": ("fuel",),
    "attock": ("fuel",),
    "hascol": ("fuel",),
    "byco": ("fuel",),
    "caltex": ("fuel",),
    "kfc": ("fast_food", "restaurant"),
    "mcdonalds": ("fast_food", "restaurant"),
    "mcdonald's": ("fast_food", "restaurant"),
    "burger king": ("fast_food", "restaurant"),
    "pizza hut": ("fast_food", "restaurant"),
    "domino": ("fast_food", "restaurant"),
    "dominos": ("fast_food", "restaurant"),
    "subway": ("fast_food", "restaurant"),
    "uber": ("ride_hailing", "transportation"),
    "careem": ("ride_hailing", "transportation"),
    "bykea": ("ride_hailing", "transportation"),
    "indrive": ("ride_hailing", "transportation"),
    "atm": ("atm",),
}


def canonicalize_concept(raw: str) -> str | None:
    """Map a free-form tag onto the closed vocabulary, or None."""
    text = (raw or "").strip().lower().replace("-", "_")
    text = " ".join(text.split())
    if not text:
        return None
    if text in CONCEPT_SET:
        return text
    underscored = text.replace(" ", "_")
    if underscored in CONCEPT_SET:
        return underscored
    if text in CONCEPT_ALIASES:
        return CONCEPT_ALIASES[text]
    if underscored in CONCEPT_ALIASES:
        return CONCEPT_ALIASES[underscored]
    return None


def canonicalize_concepts(raw: list[str] | tuple[str, ...]) -> list[str]:
    out: list[str] = []
    for item in raw:
        concept = canonicalize_concept(item)
        if concept and concept not in out and concept in CONCEPT_SET:
            out.append(concept)
    return out
