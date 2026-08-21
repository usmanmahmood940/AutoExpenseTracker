"""Default category seed + custom create."""

from __future__ import annotations

from fastapi.testclient import TestClient


def test_defaults_are_seeded(api_client: TestClient) -> None:
    response = api_client.get("/categories")
    assert response.status_code == 200
    items = response.json()["items"]
    slugs = [row["slug"] for row in items]
    assert slugs[:3] == ["food_dining", "groceries", "fuel"]
    assert "uncategorized" in slugs
    defaults = [row for row in items if row["is_default"]]
    assert len(defaults) == 20
    food = next(row for row in items if row["slug"] == "food_dining")
    assert food["name"] == "Food & Dining"
    assert food["color"] == "#F57C00"


def test_create_custom_category(api_client: TestClient) -> None:
    created = api_client.post(
        "/categories",
        json={
            "name": "Side Hustle",
            "type": "income",
            "icon": "work",
            "color": "#123456",
        },
    )
    assert created.status_code == 201, created.text
    body = created.json()
    assert body["is_default"] is False
    assert body["slug"] == "side_hustle"
    assert body["sort_order"] == 1000

    clash = api_client.post("/categories", json={"name": "Side Hustle"})
    assert clash.status_code == 409

    listed = api_client.get("/categories").json()["items"]
    assert any(row["slug"] == "side_hustle" for row in listed)
