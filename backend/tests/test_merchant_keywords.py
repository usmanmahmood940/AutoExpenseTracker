"""Merchant alias map: merchant -> keywords, and question -> search terms."""

from __future__ import annotations

from app.services.merchant_keywords import (
    keyword_suffix,
    keywords_for_merchant,
    terms_from_question,
    topics_for_merchant,
)


def test_electricity_merchants_carry_electricity_keywords() -> None:
    for merchant in ("LESCO", "lesco bill payment", "K-Electric", "IESCO"):
        keywords = keywords_for_merchant(merchant)
        assert "electricity" in keywords, merchant
        assert "gas" not in keywords, merchant


def test_gas_merchant_is_not_electricity() -> None:
    keywords = keywords_for_merchant("SNGPL")
    assert "gas" in keywords
    assert "electricity" not in keywords
    assert "electric" not in keywords


def test_unrelated_merchant_has_no_keywords() -> None:
    assert keywords_for_merchant("KFC") == []
    assert keyword_suffix("KFC") == ""


def test_alias_matches_whole_tokens_only() -> None:
    # `ke` is a K-Electric alias but must not fire inside other words.
    assert topics_for_merchant("Bakery Delight") == []
    assert topics_for_merchant("Epson Store") == []
    assert topics_for_merchant("KE") == ["electricity"]


def test_keyword_suffix_is_appendable_text() -> None:
    suffix = keyword_suffix("LESCO")
    assert "electricity" in suffix
    assert suffix == suffix.strip()


def test_question_about_electricity_reaches_electricity_merchants() -> None:
    terms = terms_from_question("how much i paid in electricity till now")
    assert "lesco" in terms
    assert "iesco" in terms
    assert "sngpl" not in terms


def test_question_about_gas_reaches_gas_merchants() -> None:
    terms = terms_from_question("what did I spend on gas")
    assert "sngpl" in terms
    assert "ssgc" in terms
    assert "lesco" not in terms


def test_question_naming_merchant_resolves_directly() -> None:
    terms = terms_from_question("total spent at sngpl")
    assert "sngpl" in terms
    assert "gas" in terms


def test_generic_alias_never_becomes_a_search_term() -> None:
    # `%ke%` as a LIKE pattern would match half the merchant table.
    assert "ke" not in terms_from_question("how much on electricity")


def test_question_without_topic_yields_no_terms() -> None:
    assert terms_from_question("what was my biggest transaction today") == []
    assert terms_from_question("") == []
