"""Deterministic combat modifiers from weapon Skill Mastery abilities (GDD s24).

Each weapon skill grants mastery abilities at Ranks 3, 5, and 7 (some skip a
rank). This module evaluates the subset that `/attack` can compute faithfully
from the character sheet, the weapon profile, and the encounter state: the
same deterministic-auto-apply pattern used by kata_effects.py and
technique_effects.py.

Every value here is read verbatim from the s24 LOCKED text; nothing is
auto-applied on a condition the engine cannot actually check.

Auto-applied (18):
  Kenjutsu R3: +1k0 damage (sword)
  Kenjutsu R7: damage explodes on 9 and 10 (sword)
  Jiujutsu R3: +1k0 damage (unarmed)
  Jiujutsu R7: +0k1 damage (unarmed)
  Heavy Weapons R3: ignore 2 Reduction
  Heavy Weapons R5: free raise toward Knockdown
  Heavy Weapons R7: damage explodes on 9 and 10
  Kyujutsu R7: bow Strength +1 (+1k0 damage)
  Spears R3: ignore 3 Reduction (first round only)
  Ninjutsu R3: +1k0 damage
  Ninjutsu R5: damage dice explode normally (overrides default no-explode)
  Ninjutsu R7: +0k1 damage
  Staves R5: free raise toward Knockdown
  Staves R7: small staves +1k0 damage
  Knives R5: free raise toward Disarm (sai/jitte)
  Chain Weapons R7: free raise toward Disarm or Knockdown
  War Fan R5: defender Armor TN +1
  War Fan R7: defender Armor TN +3

Reminder-only (not auto-applied):
  Polearms R3 (+5 Init first round: needs per-round tracker changes),
  Spears R5/R7 (range / ready: not combat math), Staves R3 (armor doubling
  not modeled), Knives R3/R7 and War Fan R3 (off-hand / extra attack: dual-
  wield not modeled), Chain Weapons R3/R5 (grapple not modeled), Kenjutsu R5
  and Kyujutsu R3/R5 (ready / string / range: not combat math).
"""

from __future__ import annotations

from .character import Character


def _skill(weapon_profile: dict) -> str:
    return str(weapon_profile.get("skill", "")).lower()


def _skill_rank(character: Character, weapon_profile: dict) -> int:
    skill_name = weapon_profile.get("skill", "")
    return character.skills.get(skill_name, 0)


def _is_small(weapon_profile: dict) -> bool:
    return str(weapon_profile.get("size", "")).lower() == "small"


def _wielding_war_fan(character: Character) -> bool:
    eq = character.equipped_weapon.lower().strip()
    off = character.off_hand_weapon.lower().strip()
    return eq == "war_fan" or off == "war_fan"


def attacker_damage(
    attacker: Character, weapon_profile: dict, weapon_name: str,
) -> tuple[int, int, int, list[str]]:
    """(extra_rolled, extra_kept, flat_bonus, notes) for the damage roll."""
    rolled = kept = flat = 0
    notes: list[str] = []
    skill = _skill(weapon_profile)
    rank = _skill_rank(attacker, weapon_profile)
    wname = weapon_name.lower().strip()

    if skill == "kenjutsu" and rank >= 3:
        rolled += 1; notes.append("Kenjutsu R3 +1k0 damage (sword)")
    if skill == "jiujutsu" and wname == "unarmed":
        if rank >= 3:
            rolled += 1; notes.append("Jiujutsu R3 +1k0 damage (unarmed)")
        if rank >= 7:
            kept += 1; notes.append("Jiujutsu R7 +0k1 damage (unarmed)")
    if skill == "ninjutsu":
        if rank >= 3:
            rolled += 1; notes.append("Ninjutsu R3 +1k0 damage")
        if rank >= 7:
            kept += 1; notes.append("Ninjutsu R7 +0k1 damage")
    if skill == "kyujutsu" and rank >= 7:
        rolled += 1; notes.append("Kyujutsu R7 +1k0 damage (bow Strength +1)")
    if skill == "staves" and rank >= 7 and _is_small(weapon_profile):
        rolled += 1; notes.append("Staves R7 +1k0 damage (small staff)")
    return rolled, kept, flat, notes


def attacker_explode_9(
    attacker: Character, weapon_profile: dict,
) -> tuple[bool, str]:
    """(True, note) if the attacker's skill mastery makes damage dice explode
    on 9 and 10 instead of just 10. Kenjutsu R7, Heavy Weapons R7."""
    skill = _skill(weapon_profile)
    rank = _skill_rank(attacker, weapon_profile)
    if skill == "kenjutsu" and rank >= 7:
        return True, "Kenjutsu R7: damage explodes on 9+"
    if skill == "heavy weapons" and rank >= 7:
        return True, "Heavy Weapons R7: damage explodes on 9+"
    return False, ""


def attacker_ninjutsu_can_explode(
    attacker: Character, weapon_profile: dict,
) -> tuple[bool, str]:
    """(True, note) if Ninjutsu R5 overrides the default no-explode on
    Ninjutsu weapons. Ninjutsu damage dice do not normally explode (s24);
    at R5 they explode normally."""
    if _skill(weapon_profile) == "ninjutsu" and _skill_rank(attacker, weapon_profile) >= 5:
        return True, "Ninjutsu R5: damage dice explode normally"
    return False, ""


def attacker_reduction_ignored(
    attacker: Character, weapon_profile: dict, encounter_round: int | None = None,
) -> tuple[int, list[str]]:
    """Amount of the target's Reduction ignored by the attacker's skill mastery.
    `encounter_round` is the current round number from the initiative tracker
    (1-based); Spears R3 only fires in round 1."""
    skill = _skill(weapon_profile)
    rank = _skill_rank(attacker, weapon_profile)
    ignore = 0
    notes: list[str] = []
    if skill == "heavy weapons" and rank >= 3:
        ignore += 2; notes.append("Heavy Weapons R3 ignores 2 Reduction")
    if skill == "spears" and rank >= 3 and encounter_round == 1:
        ignore += 3; notes.append("Spears R3 ignores 3 Reduction (first round)")
    return ignore, notes


def defender_armor_tn_bonus(defender: Character) -> tuple[int, list[str]]:
    """(Armor TN bonus, notes) from the DEFENDER's War Fan mastery."""
    if not _wielding_war_fan(defender):
        return 0, []
    rank = defender.skills.get("War Fan", 0)
    bonus = 0
    notes: list[str] = []
    if rank >= 5:
        bonus += 1; notes.append("War Fan R5 +1 Armor TN")
    if rank >= 7:
        bonus += 3; notes.append("War Fan R7 +3 Armor TN")
    return bonus, notes


def maneuver_free_raises(
    attacker: Character, weapon_profile: dict, weapon_name: str, maneuver: str,
) -> tuple[int, list[str]]:
    """(free_raises, notes) that reduce the maneuver's raise cost."""
    skill = _skill(weapon_profile)
    rank = _skill_rank(attacker, weapon_profile)
    wname = weapon_name.lower().strip()
    free = 0
    notes: list[str] = []
    if maneuver == "knockdown":
        if skill == "heavy weapons" and rank >= 5:
            free += 1; notes.append("Heavy Weapons R5: free raise for Knockdown")
        if skill == "staves" and rank >= 5:
            free += 1; notes.append("Staves R5: free raise for Knockdown")
        if skill == "chain weapons" and rank >= 7:
            free += 1; notes.append("Chain Weapons R7: free raise for Knockdown")
    if maneuver == "disarm":
        if skill == "knives" and rank >= 5 and wname in ("sai", "jitte"):
            free += 1; notes.append("Knives R5: free raise for Disarm (sai/jitte)")
        if skill == "chain weapons" and rank >= 7:
            free += 1; notes.append("Chain Weapons R7: free raise for Disarm")
    return free, notes


def initiative_reminder(character: Character, weapon_profile: dict) -> str | None:
    """A DM reminder for initiative-phase masteries the bot doesn't auto-apply.
    Polearms R3: +5 Initiative in the first round of a skirmish."""
    if _skill(weapon_profile) == "polearms" and _skill_rank(character, weapon_profile) >= 3:
        return "Polearms R3: +5 Initiative in first round (not auto-applied: adjust manually)"
    return None
