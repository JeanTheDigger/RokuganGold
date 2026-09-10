#!/usr/bin/env python3
"""One-time (re-runnable) transcriber: parse every creature `_make(...)` call in
the Godot bestiary .gd files and emit `l5r_rules/creature_catalog.py` verbatim.

This copies the LOCKED bestiary numbers into the Python bot — it invents nothing.
The eight standard bestiaries share one `_make` signature; `lost_bestiary.gd`
uses a different field order (attack/damage flat bonuses, no tier/thresholds/fear)
and is handled separately.

Usage (from discord_bot/):  python3 tools/extract_bestiary.py [path-to-simulation]
"""

from __future__ import annotations

import ast
import os
import sys

# Standard signature positional indices (id, name, tier, air, earth, fire, water,
# traits, init_r, init_k, atk_name, atk_r, atk_k, dmg_r, dmg_k, atn, reduction,
# thresholds, dead, fear, tags, [swift], [realm]).
STD = dict(
    template_id=0, name=1, air=3, earth=4, fire=5, water=6, traits=7,
    initiative_rolled=8, initiative_kept=9, attack_name=10, attack_rolled=11,
    attack_kept=12, damage_rolled=13, damage_kept=14, armor_tn=15, reduction=16,
    wound_thresholds=17, wounds_dead=18, fear=19, tags=20,
)
# lost_bestiary.gd signature (no tier, has atk_flat/dmg_flat, no thresholds/fear).
LOST = dict(
    template_id=0, name=1, air=2, earth=3, fire=4, water=5, traits=6,
    initiative_rolled=7, initiative_kept=8, attack_name=9, attack_rolled=10,
    attack_kept=11, attack_flat=12, damage_rolled=13, damage_kept=14, damage_flat=15,
    armor_tn=16, reduction=17, wounds_dead=18, tags=19,
)


def _strip_comments(text: str) -> str:
    out = []
    for line in text.splitlines():
        in_str = False
        cut = len(line)
        for i, ch in enumerate(line):
            if ch == '"':
                in_str = not in_str
            elif ch == "#" and not in_str:
                cut = i
                break
        out.append(line[:cut])
    return "\n".join(out)


def _find_make_calls(text: str) -> list[str]:
    """Return the argument substring of each `_make(...)` call (balanced)."""
    calls = []
    i = 0
    token = "_make("
    while True:
        j = text.find(token, i)
        if j == -1:
            break
        start = j + len(token)
        depth = 1
        k = start
        in_str = False
        while k < len(text) and depth > 0:
            ch = text[k]
            if ch == '"':
                in_str = not in_str
            elif not in_str:
                if ch in "([{":
                    depth += 1
                elif ch in ")]}":
                    depth -= 1
            k += 1
        calls.append(text[start:k - 1])
        i = k
    return calls


def _split_args(s: str) -> list[str]:
    args, depth, in_str, cur = [], 0, False, []
    for ch in s:
        if ch == '"':
            in_str = not in_str
            cur.append(ch)
        elif in_str:
            cur.append(ch)
        elif ch in "([{":
            depth += 1
            cur.append(ch)
        elif ch in ")]}":
            depth -= 1
            cur.append(ch)
        elif ch == "," and depth == 0:
            args.append("".join(cur).strip())
            cur = []
        else:
            cur.append(ch)
    if "".join(cur).strip():
        args.append("".join(cur).strip())
    return args


def _val(token: str):
    """Parse a literal arg: string, int, dict, or list. Non-literals -> None."""
    token = token.strip()
    try:
        return ast.literal_eval(token)  # handles "str", 123, {..}, [..]
    except Exception:
        return None


def _parse(args: list[str], spec: dict) -> dict | None:
    rec = {}
    for field_name, idx in spec.items():
        if idx >= len(args):
            return None
        v = _val(args[idx])
        if v is None and field_name != "attack_name":  # attack_name may be ""
            # empty attack name "" parses fine; a None here means a non-literal arg
            if not (field_name in ("template_id", "name", "attack_name") and args[idx].strip() == '""'):
                return None
        rec[field_name] = v if v is not None else ""
    rec.setdefault("attack_flat", 0)
    rec.setdefault("damage_flat", 0)
    rec.setdefault("wound_thresholds", [])
    rec.setdefault("fear", 0)
    rec.setdefault("traits", {})
    rec.setdefault("tags", [])
    return rec


def main() -> None:
    sim = sys.argv[1] if len(sys.argv) > 1 else os.path.join("..", "simulation")
    files = sorted(f for f in os.listdir(sim) if "bestiary" in f and f.endswith(".gd"))
    catalog: dict[str, dict] = {}
    skipped: list[str] = []
    for fname in files:
        spec = LOST if fname == "lost_bestiary.gd" else STD
        text = _strip_comments(open(os.path.join(sim, fname), encoding="utf-8").read())
        for arg_str in _find_make_calls(text):
            args = _split_args(arg_str)
            rec = _parse(args, spec)
            if rec is None or not rec.get("template_id"):
                skipped.append(f"{fname}: {args[:2]}")
                continue
            catalog.setdefault(rec["template_id"], rec)

    ordered = sorted(catalog.values(), key=lambda r: (r["template_id"]))
    out_path = os.path.join("l5r_rules", "creature_catalog.py")
    with open(out_path, "w", encoding="utf-8") as fh:
        fh.write('"""AUTO-GENERATED by tools/extract_bestiary.py — do not edit by hand.\n\n')
        fh.write("Creature stat blocks transcribed VERBATIM from the Godot bestiary .gd\n")
        fh.write("files. Re-run the extractor to refresh. Every value traces to the GDD.\n")
        fh.write(f'\n{len(ordered)} creatures.\n"""\n\n')
        fh.write("CATALOG_DATA = [\n")
        for r in ordered:
            fh.write("    " + repr(r) + ",\n")
        fh.write("]\n")

    print(f"Wrote {len(ordered)} creatures to {out_path}")
    if skipped:
        print(f"Skipped {len(skipped)} non-literal/edge entries:")
        for s in skipped:
            print("  -", s)


if __name__ == "__main__":
    main()
