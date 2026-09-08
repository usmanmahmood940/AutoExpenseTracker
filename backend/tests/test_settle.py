"""Settle / unsettle / unmerge transaction lifecycle."""

from __future__ import annotations

from fastapi.testclient import TestClient

from app.db.models.enums import TransactionStatus
from app.db.models.transaction import Transaction
from app.services.rag_documents import build_transaction_doc, should_index_transaction
from tests.test_transactions import _post_tx


def test_settle_cafe_reimbursement_flow(api_client: TestClient) -> None:
    cafe = _post_tx(
        api_client, merchant="Cafe", amount=4000, tx_date="2026-09-01", tx_type="debit"
    )
    a = _post_tx(
        api_client,
        merchant="Friend A",
        amount=1000,
        tx_date="2026-09-02",
        tx_type="credit",
        category="Transfer",
    )
    b = _post_tx(
        api_client,
        merchant="Friend B",
        amount=1000,
        tx_date="2026-09-02",
        tx_type="credit",
        category="Transfer",
    )
    c = _post_tx(
        api_client,
        merchant="Friend C",
        amount=1000,
        tx_date="2026-09-02",
        tx_type="credit",
        category="Transfer",
    )

    settled = api_client.post(
        "/transactions/settle",
        json={
            "primaryId": cafe["id"],
            "sourceIds": [a["id"], b["id"], c["id"]],
        },
    )
    assert settled.status_code == 200, settled.text
    body = settled.json()
    assert body["status"] == "settled"
    assert body["amount"] == 1000
    assert body["original_amount"] == 4000
    assert len(body["settlement_groups"]) == 1
    group_id = body["settlement_groups"][0]["groupId"]

    listed = api_client.get("/transactions").json()["items"]
    by_id = {item["id"]: item for item in listed}
    assert by_id[cafe["id"]]["status"] == "settled"
    assert by_id[a["id"]]["status"] == "merged"
    assert by_id[a["id"]]["merged_into_id"] == cafe["id"]

    # Merged rows still appear in the list...
    assert len(listed) == 4
    # ...but money aggregates exclude them.
    aggregates = api_client.get(
        "/transactions",
        params={
            "include_aggregates": "true",
            "date_from": "2026-09-01",
            "date_to": "2026-09-30",
            "type": "debit",
        },
    ).json()
    assert aggregates["total_amount"] == 1000

    blocked = api_client.delete(f"/transactions/{cafe['id']}")
    assert blocked.status_code == 400

    unmerged = api_client.post(f"/transactions/{c['id']}/unmerge")
    assert unmerged.status_code == 200, unmerged.text
    assert unmerged.json()["status"] == "active"

    primary = api_client.get(f"/transactions/{cafe['id']}").json()
    assert primary["status"] == "settled"
    assert primary["amount"] == 2000
    assert len(primary["settlement_groups"]) == 1

    unsettled = api_client.post(
        f"/transactions/{cafe['id']}/unsettle",
        json={"groupId": primary["settlement_groups"][0]["groupId"]},
    )
    assert unsettled.status_code == 200, unsettled.text
    assert unsettled.json()["status"] == "active"
    assert unsettled.json()["amount"] == 4000
    assert unsettled.json()["settlement_groups"] is None
    assert group_id  # used above via primary path


def test_settle_rejects_non_positive_net(api_client: TestClient) -> None:
    cafe = _post_tx(api_client, merchant="Cafe", amount=1000, tx_date="2026-09-01")
    friend = _post_tx(
        api_client,
        merchant="Friend",
        amount=1000,
        tx_date="2026-09-02",
        tx_type="credit",
    )
    response = api_client.post(
        "/transactions/settle",
        json={"primaryId": cafe["id"], "sourceIds": [friend["id"]]},
    )
    assert response.status_code == 400


def test_should_index_settled_not_merged() -> None:
    settled = Transaction(
        amount=1000,
        currency="PKR",
        type="debit",
        merchant="Cafe",
        merchant_normalized="cafe",
        category="Food & Dining",
        payment_method="unknown",
        bank="",
        account_id="",
        account_id_masked="",
        transaction_time="",
        transaction_date=__import__("datetime").date(2026, 9, 1),
        day="Tuesday",
        external_id_type="unknown",
        dedup_key="x",
        sms_source={},
        status=TransactionStatus.settled,
        original_amount=4000,
    )
    merged = Transaction(
        amount=1000,
        currency="PKR",
        type="credit",
        merchant="Friend",
        merchant_normalized="friend",
        category="Transfer",
        payment_method="unknown",
        bank="",
        account_id="",
        account_id_masked="",
        transaction_time="",
        transaction_date=__import__("datetime").date(2026, 9, 2),
        day="Wednesday",
        external_id_type="unknown",
        dedup_key="y",
        sms_source={},
        status=TransactionStatus.merged,
    )
    assert should_index_transaction(settled) is True
    assert should_index_transaction(merged) is False
    doc = build_transaction_doc(settled)
    assert "settled net 1000.00 original 4000.00" in doc
