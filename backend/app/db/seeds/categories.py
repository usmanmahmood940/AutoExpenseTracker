"""The 20 default categories from `shared/types/schema.ts` `DEFAULT_CATEGORIES`.

Home tiles resolve colours through CategoryColorBinder, which keys off both
the slug (`food_dining`) and the display name (`Food & Dining`). Seeding here
in Phase C — not when the Flutter categories screen is cut over — is what
keeps those colours working after Home moves off Firestore.
"""

from __future__ import annotations

from typing import TypedDict

from app.db.models.enums import CategoryType


class DefaultCategory(TypedDict):
    slug: str
    name: str
    type: CategoryType
    icon: str
    color: str
    sort_order: int


FALLBACK_CATEGORY_NAME = "Uncategorized"

DEFAULT_CATEGORIES: tuple[DefaultCategory, ...] = (
    {
        "slug": "food_dining",
        "name": "Food & Dining",
        "type": CategoryType.expense,
        "icon": "restaurant",
        "color": "#F57C00",
        "sort_order": 1,
    },
    {
        "slug": "groceries",
        "name": "Groceries",
        "type": CategoryType.expense,
        "icon": "cart",
        "color": "#43A047",
        "sort_order": 2,
    },
    {
        "slug": "fuel",
        "name": "Fuel",
        "type": CategoryType.expense,
        "icon": "local_gas_station",
        "color": "#BF360C",
        "sort_order": 3,
    },
    {
        "slug": "transport",
        "name": "Transport",
        "type": CategoryType.expense,
        "icon": "directions_car",
        "color": "#1E88E5",
        "sort_order": 4,
    },
    {
        "slug": "shopping",
        "name": "Shopping",
        "type": CategoryType.expense,
        "icon": "shopping_bag",
        "color": "#D81B60",
        "sort_order": 5,
    },
    {
        "slug": "entertainment",
        "name": "Entertainment",
        "type": CategoryType.expense,
        "icon": "movie",
        "color": "#8E24AA",
        "sort_order": 6,
    },
    {
        "slug": "bills_utilities",
        "name": "Bills & Utilities",
        "type": CategoryType.expense,
        "icon": "bolt",
        "color": "#FB8C00",
        "sort_order": 7,
    },
    {
        "slug": "healthcare",
        "name": "Healthcare",
        "type": CategoryType.expense,
        "icon": "medical_services",
        "color": "#E53935",
        "sort_order": 8,
    },
    {
        "slug": "education",
        "name": "Education",
        "type": CategoryType.expense,
        "icon": "school",
        "color": "#3949AB",
        "sort_order": 9,
    },
    {
        "slug": "travel",
        "name": "Travel",
        "type": CategoryType.expense,
        "icon": "flight",
        "color": "#00838F",
        "sort_order": 10,
    },
    {
        "slug": "personal_care",
        "name": "Personal Care",
        "type": CategoryType.expense,
        "icon": "spa",
        "color": "#EC407A",
        "sort_order": 11,
    },
    {
        "slug": "subscriptions",
        "name": "Subscriptions",
        "type": CategoryType.expense,
        "icon": "replay",
        "color": "#5E35B1",
        "sort_order": 12,
    },
    {
        "slug": "rent_housing",
        "name": "Rent & Housing",
        "type": CategoryType.expense,
        "icon": "home",
        "color": "#6D4C41",
        "sort_order": 13,
    },
    {
        "slug": "cash_withdrawal",
        "name": "Cash Withdrawal",
        "type": CategoryType.expense,
        "icon": "atm",
        "color": "#F9A825",
        "sort_order": 14,
    },
    {
        "slug": "transfer",
        "name": "Transfer",
        "type": CategoryType.expense,
        "icon": "swap_horiz",
        "color": "#039BE5",
        "sort_order": 15,
    },
    {
        "slug": "fees_charges",
        "name": "Fees & Charges",
        "type": CategoryType.expense,
        "icon": "receipt",
        "color": "#C62828",
        "sort_order": 16,
    },
    {
        "slug": "donations_zakat",
        "name": "Donations & Zakat",
        "type": CategoryType.expense,
        "icon": "volunteer_activism",
        "color": "#00695C",
        "sort_order": 17,
    },
    {
        "slug": "income",
        "name": "Income",
        "type": CategoryType.income,
        "icon": "payments",
        "color": "#2E7D32",
        "sort_order": 18,
    },
    {
        "slug": "refund",
        "name": "Refund",
        "type": CategoryType.income,
        "icon": "undo",
        "color": "#26A69A",
        "sort_order": 19,
    },
    {
        "slug": "uncategorized",
        "name": FALLBACK_CATEGORY_NAME,
        "type": CategoryType.other,
        "icon": "help_outline",
        "color": "#757575",
        "sort_order": 20,
    },
)
