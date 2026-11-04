"""Access helpers over the generated advantages/disadvantages catalog (GDD s45).

Data (l5r_rules/advantages_catalog.py) is produced verbatim by
tools/extract_advantages.py. This module indexes and queries it.
"""

from __future__ import annotations

import re

from .advantages_catalog import ADVANTAGES_DATA

ALL = ADVANTAGES_DATA

# (Disadvantages keep their top tier: it is the XP they give back.)
# A tiered cost such as "2/4/6 pts" (Magic Resistance) is stored with its top tier as `points`.
# Buying the entry gets Rank 1, so charge the first tier; later ranks are bought one at a time.
for _r in ADVANTAGES_DATA:
    _m = re.match(r"^\s*(\d+)\s*/\s*\d+", _r.get("cost_text") or "")
    if _m and _r.get("points") is not None and _r["kind"] == "advantage":
        _r["points"] = int(_m.group(1))


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
