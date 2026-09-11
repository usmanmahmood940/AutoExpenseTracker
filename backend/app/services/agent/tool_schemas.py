"""Gemini function-calling declarations for the spending agent."""

from __future__ import annotations

READ_TOOL_DECLARATIONS: list[dict] = [
    {
        "name": "query_transactions",
        "description": (
            "List the user's transactions with optional filters. "
            "Merged rows are included only when statuses includes merged."
        ),
        "parameters": {
            "type": "OBJECT",
            "properties": {
                "date_from": {"type": "STRING", "description": "YYYY-MM-DD"},
                "date_to": {"type": "STRING", "description": "YYYY-MM-DD"},
                "concepts": {
                    "type": "ARRAY",
                    "items": {"type": "STRING"},
                    "description": "Closed vocabulary tags e.g. electricity, fast_food",
                },
                "merchants": {
                    "type": "ARRAY",
                    "items": {"type": "STRING"},
                },
                "categories": {
                    "type": "ARRAY",
                    "items": {"type": "STRING"},
                },
                "types": {
                    "type": "ARRAY",
                    "items": {"type": "STRING"},
                    "description": (
                        "debit and/or credit. Match aggregate_spending types "
                        "when listing support for a 'how much' answer."
                    ),
                },
                "statuses": {
                    "type": "ARRAY",
                    "items": {"type": "STRING"},
                    "description": "active, settled, merged, needs_review",
                },
                "min_amount": {"type": "NUMBER"},
                "max_amount": {"type": "NUMBER"},
                "limit": {"type": "INTEGER"},
                "sort": {
                    "type": "STRING",
                    "description": "date_desc, date_asc, amount_desc, amount_asc",
                },
            },
        },
    },
    {
        "name": "aggregate_spending",
        "description": (
            "Exact SQL aggregates for totals. Defaults to debit (spending). "
            "Pass types: [\"credit\"] for money received / paid-to-me. "
            "Always use this for totals, comparisons, and 'how much' questions. "
            "Never invent numbers. Returns matching sample transactions for citations."
        ),
        "parameters": {
            "type": "OBJECT",
            "properties": {
                "date_from": {"type": "STRING"},
                "date_to": {"type": "STRING"},
                "group_by": {
                    "type": "STRING",
                    "description": "merchant, category, month, or day",
                },
                "concepts": {
                    "type": "ARRAY",
                    "items": {"type": "STRING"},
                },
                "merchants": {
                    "type": "ARRAY",
                    "items": {"type": "STRING"},
                },
                "categories": {
                    "type": "ARRAY",
                    "items": {"type": "STRING"},
                },
                "types": {
                    "type": "ARRAY",
                    "items": {"type": "STRING"},
                    "description": (
                        "debit (default) and/or credit. "
                        "Use credit for received / paid-to-me totals."
                    ),
                },
                "statuses": {
                    "type": "ARRAY",
                    "items": {"type": "STRING"},
                },
            },
            "required": ["date_from", "date_to"],
        },
    },
    {
        "name": "list_settlements",
        "description": "List settled primary transactions in a date window.",
        "parameters": {
            "type": "OBJECT",
            "properties": {
                "date_from": {"type": "STRING"},
                "date_to": {"type": "STRING"},
                "limit": {"type": "INTEGER"},
            },
            "required": ["date_from", "date_to"],
        },
    },
    {
        "name": "get_transaction",
        "description": "Fetch one transaction by id owned by the current user.",
        "parameters": {
            "type": "OBJECT",
            "properties": {
                "transaction_id": {"type": "STRING"},
            },
            "required": ["transaction_id"],
        },
    },
    {
        "name": "search_transaction_candidates",
        "description": (
            "Find candidate transactions when the user refers to one indirectly "
            "(e.g. cafe bill, Ali reimbursement). Return multiple when ambiguous."
        ),
        "parameters": {
            "type": "OBJECT",
            "properties": {
                "query": {"type": "STRING"},
                "date_from": {"type": "STRING"},
                "date_to": {"type": "STRING"},
                "type": {"type": "STRING"},
                "concepts": {
                    "type": "ARRAY",
                    "items": {"type": "STRING"},
                },
                "limit": {"type": "INTEGER"},
            },
            "required": ["query"],
        },
    },
]

WRITE_TOOL_DECLARATIONS: list[dict] = [
    {
        "name": "propose_create_transaction",
        "description": (
            "Propose creating a transaction. Does NOT write to the database. "
            "Use a short ref like t1 for later settle steps."
        ),
        "parameters": {
            "type": "OBJECT",
            "properties": {
                "ref": {"type": "STRING"},
                "amount": {"type": "NUMBER"},
                "type": {"type": "STRING"},
                "merchant": {"type": "STRING"},
                "category": {"type": "STRING"},
                "date": {"type": "STRING"},
                "currency": {"type": "STRING"},
                "note": {"type": "STRING"},
            },
            "required": ["ref", "amount", "type", "merchant", "date"],
        },
    },
    {
        "name": "propose_settle",
        "description": (
            "Propose settling source transactions into a primary. "
            "primary_ref/source_refs may be proposal refs (t1) or UUIDs."
        ),
        "parameters": {
            "type": "OBJECT",
            "properties": {
                "primary_ref": {"type": "STRING"},
                "source_refs": {
                    "type": "ARRAY",
                    "items": {"type": "STRING"},
                },
                "primary_transaction_id": {"type": "STRING"},
                "source_transaction_ids": {
                    "type": "ARRAY",
                    "items": {"type": "STRING"},
                },
                "primary_updated_at": {"type": "STRING"},
                "sources_updated_at": {
                    "type": "OBJECT",
                },
            },
        },
    },
    {
        "name": "propose_unsettle",
        "description": "Propose undoing a settlement group on a primary transaction.",
        "parameters": {
            "type": "OBJECT",
            "properties": {
                "primary_transaction_id": {"type": "STRING"},
                "group_id": {"type": "STRING"},
                "primary_updated_at": {"type": "STRING"},
            },
            "required": ["primary_transaction_id", "group_id"],
        },
    },
    {
        "name": "propose_unmerge",
        "description": "Propose unmerging a single merged transaction.",
        "parameters": {
            "type": "OBJECT",
            "properties": {
                "transaction_id": {"type": "STRING"},
                "updated_at": {"type": "STRING"},
            },
            "required": ["transaction_id"],
        },
    },
]

ALL_TOOL_DECLARATIONS = READ_TOOL_DECLARATIONS + WRITE_TOOL_DECLARATIONS
WRITE_TOOL_NAMES = frozenset(item["name"] for item in WRITE_TOOL_DECLARATIONS)
READ_TOOL_NAMES = frozenset(item["name"] for item in READ_TOOL_DECLARATIONS)
