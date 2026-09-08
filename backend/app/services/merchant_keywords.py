"""Merchant alias keywords so RAG text and questions share vocabulary.

Embeddings do not know that LESCO bills electricity and SNGPL bills gas, and
the seeded taxonomy has a single `bills_utilities` category for both. Indexed
documents therefore get the plain-language keywords appended, and questions get
mapped back to the merchant tokens they imply.
"""

from __future__ import annotations

import re

_TOKEN = re.compile(r"[a-z0-9]+")

# topic -> (merchant aliases, plain-language keywords)
_TOPICS: dict[str, tuple[tuple[str, ...], tuple[str, ...]]] = {
    "electricity": (
        (
            "lesco",
            "k electric",
            "kelectric",
            "ke",
            "iesco",
            "mepco",
            "gepco",
            "fesco",
            "hesco",
            "pesco",
            "qesco",
            "sepco",
            "wapda",
        ),
        ("electricity", "electric", "power", "light bill", "utility"),
    ),
    "gas": (
        ("sngpl", "ssgc", "sui gas", "sui northern", "sui southern"),
        ("gas", "sui gas", "utility"),
    ),
    "water": (
        ("wasa", "water board"),
        ("water", "utility"),
    ),
    "telecom": (
        (
            "ptcl",
            "jazz",
            "warid",
            "zong",
            "ufone",
            "telenor",
            "nayatel",
            "stormfiber",
            "storm fiber",
            "transworld",
            "worldcall",
        ),
        ("mobile", "phone", "internet", "broadband", "telecom", "utility"),
    ),
    "fuel": (
        (
            "pso",
            "shell",
            "total parco",
            "totalparco",
            "attock",
            "hascol",
            "byco",
            "caltex",
        ),
        ("fuel", "petrol", "diesel", "gas station", "pump"),
    ),
}

# Fine on a LESCO document as extra embedding text; disastrous as `%LIKE%`
# against merchant names (`CURSOR AI POWER`, `Bills & Utilities`, ...).
_UNSAFE_AS_TERM = frozenset(
    {
        "ke",
        "power",
        "electric",
        "utility",
        "phone",
        "mobile",
        "pump",
        "gas",
        "water",
    }
)


def _tokens(text: str) -> list[str]:
    return _TOKEN.findall((text or "").lower())


def _has_phrase(haystack: list[str], phrase: str) -> bool:
    """True when the phrase appears as a contiguous run of tokens.

    Token runs rather than substrings so `ke` does not fire on `bakery` and
    `pso` does not fire on `epson`.
    """
    needle = _tokens(phrase)
    if not needle or not haystack:
        return False
    span = len(needle)
    for start in range(len(haystack) - span + 1):
        if haystack[start : start + span] == needle:
            return True
    return False


def topics_for_merchant(merchant: str) -> list[str]:
    """Topics a merchant name belongs to, e.g. `LESCO` -> `["electricity"]`."""
    tokens = _tokens(merchant)
    if not tokens:
        return []
    return [
        topic
        for topic, (aliases, _) in _TOPICS.items()
        if any(_has_phrase(tokens, alias) for alias in aliases)
    ]


def keywords_for_merchant(merchant: str) -> list[str]:
    """Plain-language keywords to append to a merchant's indexed document."""
    out: list[str] = []
    for topic in topics_for_merchant(merchant):
        for keyword in (topic, *_TOPICS[topic][1]):
            if keyword not in out:
                out.append(keyword)
    return out


def keyword_suffix(merchant: str) -> str:
    """Doc-text fragment for a merchant; empty when it matches no topic."""
    return " ".join(keywords_for_merchant(merchant))


def topics_from_question(question: str) -> list[str]:
    """Topics a question is asking about. Detection may use generic words."""
    tokens = _tokens(question)
    if not tokens:
        return []
    found: list[str] = []
    for topic, (aliases, keywords) in _TOPICS.items():
        probes = (topic, *keywords, *aliases)
        if any(_has_phrase(tokens, probe) for probe in probes):
            found.append(topic)
    return found


def merchant_belongs_to_topics(merchant: str, topics: list[str]) -> bool:
    """True when the merchant is a known member of at least one topic."""
    if not topics:
        return True
    owned = set(topics_for_merchant(merchant))
    return bool(owned.intersection(topics))


def terms_from_question(question: str) -> list[str]:
    """Search terms implied by a question.

    A question mentioning a topic ("electricity") yields that topic's merchant
    aliases so SQL reaches LESCO rows, plus the topic name so lexical search
    can hit enriched `content_text`. Generic cue words (`power`, `utility`)
    detect the topic but are never used as `%LIKE%` patterns.
    """
    tokens = _tokens(question)
    if not tokens:
        return []
    terms: list[str] = []

    def add(value: str) -> None:
        if value and value not in terms and value not in _UNSAFE_AS_TERM:
            terms.append(value)

    for topic in topics_from_question(question):
        aliases, keywords = _TOPICS[topic]
        add(topic)
        for alias in aliases:
            add(alias)
        for keyword in keywords:
            add(keyword)
    return terms
