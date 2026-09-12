"""Access helpers over the generated kiho catalog. Data is produced verbatim by
tools/extract_kata_kiho.py."""

from __future__ import annotations

from .kiho_catalog import KIHO_DATA

ALL = KIHO_DATA
_BY = {r["name"].lower(): r for r in KIHO_DATA}


def get(name: str) -> dict | None:
    return _BY.get(name.lower().strip())


def search(query: str) -> list[dict]:
    q = query.lower().strip()
    return [r for r in KIHO_DATA if q in r["name"].lower() or q in r["element"].lower() or q in str(r.get("type", "")).lower()]


def by_element(element: str) -> list[dict]:
    return [r for r in KIHO_DATA if r["element"].lower() == element.lower()]


def elements() -> list[str]:
    return sorted({r["element"] for r in KIHO_DATA})
