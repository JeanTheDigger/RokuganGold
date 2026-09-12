"""Access helpers over the generated spell catalog (GDD s32-s37).

Data (l5r_rules/spells_catalog.py) is produced verbatim by
tools/extract_spells.py. This module indexes and queries it.
"""

from __future__ import annotations

from .spells_catalog import SPELLS_DATA

ALL = SPELLS_DATA
_BY_NAME = {s["name"].lower(): s for s in SPELLS_DATA}


def get(name: str) -> dict | None:
    return _BY_NAME.get(name.lower().strip())


def search(query: str) -> list[dict]:
    q = query.lower().strip()
    return [
        s for s in SPELLS_DATA
        if q in s["name"].lower() or q in s["element"].lower() or q in s["keyword"].lower()
    ]


def by_element(element: str) -> list[dict]:
    return [s for s in SPELLS_DATA if s["element"].lower() == element.lower()]


def elements() -> list[str]:
    return sorted({s["element"] for s in SPELLS_DATA})
