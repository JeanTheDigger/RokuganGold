"""Access helpers over the generated advantages/disadvantages catalog (GDD s45).

Data (l5r_rules/advantages_catalog.py) is produced verbatim by
tools/extract_advantages.py. This module indexes and queries it.
"""

from __future__ import annotations

from .advantages_catalog import ADVANTAGES_DATA

ALL = ADVANTAGES_DATA


def get(name: str, kind: str | None = None) -> dict | None:
    n = name.lower().strip()
    for r in ADVANTAGES_DATA:
        if r["name"].lower() == n and (kind is None or r["kind"] == kind):
            return r
    return None


def search(query: str, kind: str | None = None) -> list[dict]:
    q = query.lower().strip()
    return [
        r for r in ADVANTAGES_DATA
        if (kind is None or r["kind"] == kind)
        and (q in r["name"].lower() or q in (r.get("category") or "").lower())
    ]


def by_kind(kind: str) -> list[dict]:
    return [r for r in ADVANTAGES_DATA if r["kind"] == kind]
