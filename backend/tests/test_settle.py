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


def test_settle_rejects_negative_net(api_client: TestClient) -> None:
    cafe = _post_tx(api_client, merchant="Cafe", amount=1000, tx_date="2026-09-01")
    friend = _post_tx(
        api_client,
        merchant="Friend",
        amount=1500,
        tx_date="2026-09-02",
        tx_type="credit",
    )
    response = api_client.post(
        "/transactions/settle",
        json={"primaryId": cafe["id"], "sourceIds": [friend["id"]]},
    )
    assert response.status_code == 400
    assert response.json()["code"] == "settle_amount_invalid"


def test_settle_to_zero_debit_primary(api_client: TestClient) -> None:
    zoom = _post_tx(
        api_client,
        merchant="ZOOM LAHORE",
        amount=600,
        tx_date="2026-09-01",
        tx_type="debit",
    )
    touseef = _post_tx(
        api_client,
        merchant="M.Touseef",
        amount=600,
        tx_date="2026-09-02",
        tx_type="credit",
        category="Transfer",
    )
    response = api_client.post(
        "/transactions/settle",
        json={"primaryId": zoom["id"], "sourceIds": [touseef["id"]]},
    )
    assert response.status_code == 200, response.text
    body = response.json()
    assert body["amount"] == 0
    assert body["original_amount"] == 600
    assert body["status"] == "settled"


def test_settle_to_zero_credit_primary(api_client: TestClient) -> None:
    touseef = _post_tx(
        api_client,
        merchant="M.Touseef",
        amount=600,
        tx_date="2026-09-02",
        tx_type="credit",
        category="Transfer",
    )
    zoom = _post_tx(
        api_client,
        merchant="ZOOM LAHORE",
        amount=600,
        tx_date="2026-09-01",
        tx_type="debit",
    )
    response = api_client.post(
        "/transactions/settle",
        json={"primaryId": touseef["id"], "sourceIds": [zoom["id"]]},
    )
    assert response.status_code == 200, response.text
    body = response.json()
    assert body["amount"] == 0
    assert body["original_amount"] == 600
    assert body["status"] == "settled"


def test_settle_same_type_credits_increase_primary(api_client: TestClient) -> None:
    payroll = _post_tx(
        api_client,
        merchant="Payroll",
        amount=1000,
        tx_date="2026-09-01",
        tx_type="credit",
        category="Transfer",
    )
    bonus = _post_tx(
        api_client,
        merchant="Bonus",
        amount=200,
        tx_date="2026-09-02",
        tx_type="credit",
        category="Transfer",
    )
    response = api_client.post(
        "/transactions/settle",
        json={"primaryId": payroll["id"], "sourceIds": [bonus["id"]]},
    )
    assert response.status_code == 200, response.text
    body = response.json()
    assert body["amount"] == 1200
    assert body["original_amount"] == 1000
    assert body["status"] == "settled"
    assert body["settlement_groups"][0]["amountApplied"] == -200


def test_unmerge_after_credit_primary_settle(api_client: TestClient) -> None:
    touseef = _post_tx(
        api_client,
        merchant="M.Touseef",
        amount=1000,
        tx_date="2026-09-02",
        tx_type="credit",
        category="Transfer",
    )
    zoom = _post_tx(
        api_client,
        merchant="ZOOM LAHORE",
        amount=400,
        tx_date="2026-09-01",
        tx_type="debit",
    )
    settled = api_client.post(
        "/transactions/settle",
        json={"primaryId": touseef["id"], "sourceIds": [zoom["id"]]},
    )
    assert settled.status_code == 200, settled.text
    assert settled.json()["amount"] == 600

    unmerged = api_client.post(f"/transactions/{zoom['id']}/unmerge")
    assert unmerged.status_code == 200, unmerged.text
    assert unmerged.json()["status"] == "active"

    primary = api_client.get(f"/transactions/{touseef['id']}").json()
    assert primary["status"] == "active"
    assert primary["amount"] == 1000
    assert primary["settlement_groups"] is None
    assert primary["original_amount"] is None


def test_settlement_edit_locks_amount_and_type_only(api_client: TestClient) -> None:
    cafe = _post_tx(
        api_client, merchant="Cafe", amount=4000, tx_date="2026-09-01", tx_type="debit"
    )
    friend = _post_tx(
        api_client,
        merchant="Friend",
        amount=1000,
        tx_date="2026-09-02",
        tx_type="credit",
        category="Transfer",
    )
    settled = api_client.post(
        "/transactions/settle",
        json={"primaryId": cafe["id"], "sourceIds": [friend["id"]]},
    )
    assert settled.status_code == 200, settled.text
    assert settled.json()["amount"] == 3000

    edited = api_client.patch(
        f"/transactions/{friend['id']}",
        json={"merchant": "Ali", "category": "Food"},
    )
    assert edited.status_code == 200, edited.text
    body = edited.json()
    assert body["status"] == "merged"
    assert body["merchant"] == "Ali"
    assert body["category"] == "Food"
    assert body["amount"] == 1000
    assert body["type"] == "credit"

    locked_amount = api_client.patch(
        f"/transactions/{friend['id']}", json={"amount": 50}
    )
    assert locked_amount.status_code == 400
    assert locked_amount.json()["code"] == "settlement_amount_locked"

    locked_type = api_client.patch(
        f"/transactions/{friend['id']}", json={"type": "debit"}
    )
    assert locked_type.status_code == 400
    assert locked_type.json()["code"] == "settlement_type_locked"

    same_type = api_client.patch(
        f"/transactions/{friend['id']}", json={"type": "credit", "bank": "HBL"}
    )
    assert same_type.status_code == 200, same_type.text
    assert same_type.json()["bank"] == "HBL"
    assert same_type.json()["type"] == "credit"

    primary = api_client.patch(
        f"/transactions/{cafe['id']}", json={"merchant": "Cafe Updated"}
    )
    assert primary.status_code == 200, primary.text
    assert primary.json()["status"] == "settled"
    assert primary.json()["merchant"] == "Cafe Updated"
    assert primary.json()["amount"] == 3000
    assert primary.json()["type"] == "debit"

    primary_amount = api_client.patch(
        f"/transactions/{cafe['id']}", json={"amount": 10}
    )
    assert primary_amount.status_code == 400
    assert primary_amount.json()["code"] == "settlement_amount_locked"

    primary_type = api_client.patch(
        f"/transactions/{cafe['id']}", json={"type": "credit"}
    )
    assert primary_type.status_code == 400
    assert primary_type.json()["code"] == "settlement_type_locked"

    unmerged = api_client.post(f"/transactions/{friend['id']}/unmerge")
    assert unmerged.status_code == 200, unmerged.text
    restored = api_client.get(f"/transactions/{cafe['id']}").json()
    assert restored["status"] == "active"
    assert restored["amount"] == 4000


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
