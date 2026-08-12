"""Offline connection-contract tests for Star Citizen Tracker.

These tests execute the app's real normalization and CRUD helper functions
against a small in-memory Supabase-compatible query chain. They do not contact
or modify a live database.
"""
from __future__ import annotations

import ast
import json
import re
from datetime import datetime, timezone
from pathlib import Path
from types import SimpleNamespace
from typing import Any

import pandas as pd

APP_PATH = Path(__file__).resolve().parents[1] / "app.py"
SOURCE = APP_PATH.read_text(encoding="utf-8")
TREE = ast.parse(SOURCE)
FUNCTIONS = {
    node.name: node
    for node in TREE.body
    if isinstance(node, ast.FunctionDef)
}

SELECTED_FUNCTIONS = [
    "safe_float",
    "empty_contract_frame",
    "normalize_contracts",
    "fetch_table",
    "insert_contract",
    "normalize_blueprint_materials",
    "insert_blueprint",
    "delete_record",
    "update_record",
    "empty_ore_transaction_frame",
    "normalize_ore_action",
    "_ore_alias_series",
    "normalize_ore_transactions",
    "insert_ore",
    "empty_commodity_transaction_frame",
    "normalize_commodity_action",
    "_commodity_alias_series",
    "normalize_commodity_transactions",
    "insert_commodity_transaction",
    "normalize_loot_locations",
    "insert_loot_location",
]

missing = [name for name in SELECTED_FUNCTIONS if name not in FUNCTIONS]
if missing:
    raise AssertionError(f"Missing functions: {missing}")

module = ast.Module(
    body=[FUNCTIONS[name] for name in SELECTED_FUNCTIONS],
    type_ignores=[],
)
ast.fix_missing_locations(module)


class Response:
    def __init__(self, data: list[dict[str, Any]] | None = None):
        self.data = data or []


class Query:
    def __init__(self, client: "FakeSupabase", table_name: str):
        self.client = client
        self.table_name = table_name
        self.operation = "select"
        self.payload: dict[str, Any] | None = None
        self.filters: list[tuple[str, Any]] = []
        self.order_by: tuple[str, bool] | None = None
        self.limit_count: int | None = None

    def select(self, _columns: str):
        self.operation = "select"
        return self

    def insert(self, payload: dict[str, Any]):
        self.operation = "insert"
        self.payload = dict(payload)
        return self

    def update(self, payload: dict[str, Any]):
        self.operation = "update"
        self.payload = dict(payload)
        return self

    def delete(self):
        self.operation = "delete"
        return self

    def eq(self, column: str, value: Any):
        self.filters.append((column, value))
        return self

    def order(self, column: str, desc: bool = False):
        self.order_by = (column, desc)
        return self

    def limit(self, count: int):
        self.limit_count = int(count)
        return self

    def _matches(self, row: dict[str, Any]) -> bool:
        return all(row.get(column) == value for column, value in self.filters)

    def execute(self):
        rows = self.client.tables.setdefault(self.table_name, [])

        if self.operation == "insert":
            assert self.payload is not None
            row = dict(self.payload)
            row.setdefault("id", self.client.next_id(self.table_name))
            row.setdefault("date_saved", datetime.now(timezone.utc).isoformat())
            rows.append(row)
            # Simulate PostgREST deployments that return no INSERT representation.
            return Response([])

        if self.operation == "update":
            assert self.payload is not None
            for row in rows:
                if self._matches(row):
                    row.update(self.payload)
            return Response([])

        if self.operation == "delete":
            self.client.tables[self.table_name] = [
                row for row in rows if not self._matches(row)
            ]
            return Response([])

        selected = [dict(row) for row in rows if self._matches(row)]
        if self.order_by:
            column, desc = self.order_by
            selected.sort(key=lambda row: row.get(column, 0), reverse=desc)
        if self.limit_count is not None:
            selected = selected[: self.limit_count]
        return Response(selected)


class FakeSupabase:
    def __init__(self):
        self.tables: dict[str, list[dict[str, Any]]] = {
            "contracts": [],
            "ore_transactions": [],
            "commodity_transactions": [],
            "blueprint_tracker": [],
            "loot_locations": [],
        }
        self._ids: dict[str, int] = {}

    def next_id(self, table_name: str) -> int:
        self._ids[table_name] = self._ids.get(table_name, 0) + 1
        return self._ids[table_name]

    def table(self, table_name: str) -> Query:
        return Query(self, table_name)


fake = FakeSupabase()
st = SimpleNamespace(session_state={"user_id": "user-1"})
namespace = {
    "Any": Any,
    "json": json,
    "re": re,
    "pd": pd,
    "APP_TIMEZONE": "America/Chicago",
    "LOOT_VISIBILITY_OPTIONS": ["Shared", "Private"],
    "USER_OWNED_TABLES": frozenset(fake.tables),
    "st": st,
    "get_supabase": lambda: fake,
}
exec(compile(module, str(APP_PATH), "exec"), namespace)

insert_contract = namespace["insert_contract"]
fetch_table = namespace["fetch_table"]
update_record = namespace["update_record"]
delete_record = namespace["delete_record"]
insert_ore = namespace["insert_ore"]
insert_commodity = namespace["insert_commodity_transaction"]
insert_blueprint = namespace["insert_blueprint"]
insert_loot = namespace["insert_loot_location"]

# Contract + bounty salvage path.
contract = insert_contract(
    {
        "user_id": "user-1",
        "contract_name": "ERT Bounty Test",
        "contract_type": "Bounty Hunting",
        "offer_group": "Verified",
        "system_name": "Stanton",
        "total_payout": 100_000,
        "salvage_value": 250_000,
        "expenses": 50_000,
        "crew_members": 2,
        "notes": "Offline verification",
    }
)
assert contract["gross_income"] == 350_000
assert contract["net_payout"] == 300_000
assert contract["individual_share"] == 150_000

# Explicit user filtering.
fake.tables["contracts"].append(
    {
        "id": 99,
        "user_id": "different-user",
        "date_saved": datetime.now(timezone.utc).isoformat(),
        "contract_name": "Other user's row",
        "contract_type": "Bounty Hunting",
        "total_payout": 1,
        "salvage_value": 0,
        "expenses": 0,
        "crew_members": 1,
        "net_payout": 1,
        "individual_share": 1,
    }
)
assert len(fetch_table("contracts")) == 1

# Verified update and delete.
update_record(
    "contracts",
    int(contract["id"]),
    {
        "salvage_value": 300_000,
        "net_payout": 350_000,
        "individual_share": 175_000,
    },
)
assert fake.tables["contracts"][0]["salvage_value"] == 300_000
delete_record("contracts", int(contract["id"]))
assert not any(row.get("id") == contract["id"] for row in fake.tables["contracts"])

# Ore connection.
ore = insert_ore(
    {
        "user_id": "user-1",
        "action": "Sold",
        "ore_name": "Agricium",
        "quantity_scu": 10,
        "unit_price": 14_400,
        "total_value": 144_000,
        "location": "Area18",
        "notes": "",
    }
)
assert ore["total_value"] == 144_000

# Commodity connection.
commodity = insert_commodity(
    {
        "user_id": "user-1",
        "commodity_name": "Gold",
        "action": "Sold",
        "quantity_scu": 5,
        "unit_price": 10_000,
        "fees": 0,
        "origin": "Origin",
        "destination": "Destination",
        "shipment_reference": "TEST",
        "notes": "",
    }
)
assert commodity["total_value"] == 50_000

# Blueprint connection.
blueprint = insert_blueprint(
    {
        "user_id": "user-1",
        "blueprint_name": "Test Blueprint",
        "blueprint_category": "Armor",
        "blueprint_status": "Owned",
        "source_location": "Mission",
        "copies_owned": 1,
        "target_builds": 1,
        "materials": {"Agricium": 2.0},
        "notes": "",
    }
)
assert blueprint["blueprint_name"] == "Test Blueprint"

# Loot connection.
loot = insert_loot(
    {
        "user_id": "user-1",
        "submitted_by": "Citizen",
        "item_name": "Test Item",
        "category": "Armor",
        "acquisition_type": "Salvaged",
        "system_name": "Stanton",
        "location_name": "Test Site",
        "sub_location": "",
        "container_type": "",
        "rarity": "Rare",
        "mission_or_event": "Bounty Hunting",
        "patch_version": "Test",
        "verification_status": "Verified",
        "last_verified": None,
        "visibility": "Private",
        "notes": "",
    }
)
assert loot["item_name"] == "Test Item"

print("PASS: contract salvage insert/read/update/delete")
print("PASS: explicit user-scoped reads")
print("PASS: ore insert/read verification")
print("PASS: commodity insert/read verification")
print("PASS: blueprint insert/read verification")
print("PASS: loot insert/read verification")
