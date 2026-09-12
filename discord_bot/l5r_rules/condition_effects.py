"""Deterministic combat modifiers from conditions (GDD s40).

Conditions are transient per-encounter state on a Combatant.  Only effects
computable from the condition set + weapon profile are auto-applied here;
everything else (Entangled break-free, Dazed/Stunned recovery rolls, Fatigued
incremental penalties, movement restrictions) stays DM-adjudicated.

Auto-applied (15 effects across 7 conditions):
  Blinded:   -3k3 ranged attack, -1k1 melee attack, Armor TN = Reflexes+5
  Dazed:     -3k0 attack rolls
  Fatigued:  +5 TN to attacker's rolls (applied as flat penalty on attack)
  Grappled:  Armor TN = 5 + armor bonus
  Mounted:   +1k0 attack rolls vs unmounted
  Prone:     -10 Armor TN vs melee, -2k0 attack (Medium/Small), can't attack (Large)
  Stunned:   Armor TN = 5 + armor bonus, can't act (reminder only)

Entangled: reminder-only (break-free TN set by DM).
"""

from __future__ import annotations


def attacker_attack_dice(
    attacker_conditions: set[str],
    weapon_profile: dict,
) -> tuple[int, int, int, list[str]]:
    """(extra_rolled, extra_kept, flat_bonus, notes) for the attack roll."""
    rolled = kept = flat = 0
    notes: list[str] = []
    is_melee = weapon_profile.get("melee", True)
    size = str(weapon_profile.get("size", "")).lower()

    if "blinded" in attacker_conditions:
        if is_melee:
            rolled -= 1; kept -= 1
            notes.append("Blinded -1k1 (melee attack)")
        else:
            rolled -= 3; kept -= 3
            notes.append("Blinded -3k3 (ranged attack)")

    if "dazed" in attacker_conditions:
        rolled -= 3
        notes.append("Dazed -3k0 (all actions)")

    if "fatigued" in attacker_conditions:
        flat -= 5
        notes.append("Fatigued +5 TN (applied as -5 flat)")

    if "mounted" in attacker_conditions:
        rolled += 1
        notes.append("Mounted +1k0 attack (vs unmounted/lower)")

    if "prone" in attacker_conditions:
        if size == "large":
            notes.append("Prone: CANNOT attack with Large weapon")
        elif size in ("medium", "small", ""):
            rolled -= 2
            notes.append(f"Prone -2k0 attack ({size.title() or 'Medium'} weapon)")

    return rolled, kept, flat, notes


def defender_armor_tn_override(
    defender_conditions: set[str],
    defender_reflexes: int,
    defender_armor_bonus: int,
    is_melee_attack: bool,
) -> tuple[int | None, list[str]]:
    """(override_tn | None, notes).

    Some conditions replace the normal Armor TN formula entirely.
    Returns None when no override applies (use normal calculation).
    When multiple overrides apply, the lowest wins (worst for defender)."""
    overrides: list[tuple[int, str]] = []

    if "stunned" in defender_conditions:
        v = 5 + defender_armor_bonus
        overrides.append((v, f"Stunned: Armor TN = {v} (5 + armor {defender_armor_bonus})"))

    if "grappled" in defender_conditions:
        v = 5 + defender_armor_bonus
        overrides.append((v, f"Grappled: Armor TN = {v} (5 + armor {defender_armor_bonus})"))

    if "blinded" in defender_conditions:
        v = defender_reflexes + 5 + defender_armor_bonus
        overrides.append((v, f"Blinded: Armor TN = {v} (Reflexes {defender_reflexes} + 5 + armor {defender_armor_bonus})"))

    if not overrides:
        return None, []

    overrides.sort(key=lambda x: x[0])
    return overrides[0][0], [overrides[0][1]]


def defender_armor_tn_mod(
    defender_conditions: set[str],
    is_melee_attack: bool,
) -> tuple[int, list[str]]:
    """(modifier, notes) added to the defender's normal Armor TN.

    Separate from overrides: these stack with the normal formula."""
    mod = 0
    notes: list[str] = []

    if "prone" in defender_conditions and is_melee_attack:
        mod -= 10
        notes.append("Prone -10 Armor TN (vs melee)")

    return mod, notes


def stunned_cannot_act(conditions: set[str]) -> bool:
    return "stunned" in conditions


def entangled_cannot_act(conditions: set[str]) -> bool:
    return "entangled" in conditions


def condition_reminders(conditions: set[str]) -> list[str]:
    """DM reminder lines for conditions with non-auto-applied effects."""
    lines: list[str] = []
    if "stunned" in conditions:
        lines.append("**Stunned:** cannot take actions; recovers Earth TN 20 at Reactions Stage")
    if "dazed" in conditions:
        lines.append("**Dazed:** Defense/Full Defense stances only; recovers Earth TN 20 at Reactions Stage")
    if "entangled" in conditions:
        lines.append("**Entangled:** can only attempt to break free (Strength, TN set by DM)")
    if "fatigued" in conditions:
        lines.append("**Fatigued:** cannot use Full Attack Stance; +5 TN stacks per extra day")
    if "prone" in conditions:
        lines.append("**Prone:** cannot use Move Actions; standing up is a Simple Action")
    if "blinded" in conditions:
        lines.append("**Blinded:** Water -2 for movement; Simple Move needs Athletics/Agility TN 20 or fall Prone")
    if "mounted" in conditions:
        lines.append("**Mounted:** cannot use Full Attack Stance")
    return lines
