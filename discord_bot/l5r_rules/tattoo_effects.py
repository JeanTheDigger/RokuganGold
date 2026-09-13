"""Deterministic combat modifiers from a character's ACTIVE tattoo (GDD s57.25).

Only tattoos whose effect the bot can compute faithfully from the sheet are
auto-applied here: passive modifiers gated on the active tattoo, character
stats, and weapon profile — the same pattern as kata_effects.py / kiho_effects.py.

Auto-applied (9):
  Bamboo: Armor TN += (2 x School Rank) + 5 (defender, no armor)
  Bear: Stamina +SR or Strength +ceil(SR/2) (choice locked at activation)
  Blaze: unarmed damage +Fire Ring +School Rank flat (attacker)
  Crab: Reduction += Earth Ring (defender)
  Lion: +SR rolled dice on attack rolls with chosen Bugei skill (attacker)
  Mantis: Fear immunity (passive, always on — wired into /assess fear)
  Mountain: wound penalties reduced by (School Rank + 2) (attacker)
  Phoenix: reactive heal at Down/Out (reminder on damage resolution)
  Storm: Knockdown costs 1 Raise instead of standard (attacker free raise)

Reminder-only (not auto-applied):
  Balance (spell TN mod), Cloud (re-roll), Crane (social pool), Dragon
  (breath attack), Hawk (leap), Ki-Rin (re-roll per round), Ocean (rest/VP),
  Scorpion (auto-Daze on exploding unarmed: DM adjudicated), Volcano
  (defensive reaction), Wave (Knockdown contested roll bonus), and
  world-map-only tattoos (Centipede, Whisper, Wind, Wolf).
"""

from __future__ import annotations

import math

from . import stats
from .character import Character


def _active(c: Character) -> str:
    return (getattr(c, "active_tattoo", "") or "").lower().strip()


def _has_tattoo(c: Character, name: str) -> bool:
    return name in [t.lower().strip() for t in (getattr(c, "tattoos", None) or [])]


# ---------------------------------------------------------------------------
# Defender: Armor TN bonus
# ---------------------------------------------------------------------------

def defender_armor_tn_bonus(defender: Character) -> tuple[int, list[str]]:
    """(bonus, notes) added to the defender's Armor TN from active tattoo."""
    active = _active(defender)
    bonus = 0
    notes: list[str] = []
    if active == "bamboo":
        if not defender.armor_name:
            v = 2 * defender.school_rank + 5
            bonus += v
            notes.append(f"Bamboo Tattoo +{v} Armor TN (2×SR {defender.school_rank} + 5)")
        else:
            notes.append(f"Bamboo Tattoo: no effect (mutually exclusive with {defender.armor_name} armor)")
    return bonus, notes


# ---------------------------------------------------------------------------
# Defender: Reduction bonus
# ---------------------------------------------------------------------------

def defender_reduction_bonus(defender: Character) -> tuple[int, list[str]]:
    """(extra Reduction, notes) from the defender's active tattoo."""
    active = _active(defender)
    bonus = 0
    notes: list[str] = []
    if active == "crab":
        v = stats.ring_value(defender, "earth")
        bonus += v
        notes.append(f"Crab Tattoo +{v} Reduction (Earth Ring)")
    if active == "bear":
        choice = (getattr(defender, "bear_tattoo_choice", "") or "").lower()
        if choice == "stamina":
            sr = defender.school_rank
            boosted_stam = defender.stamina + sr
            effective_earth = min(boosted_stam, defender.willpower)
            base_earth = min(defender.stamina, defender.willpower)
            earth_delta = effective_earth - base_earth
            if earth_delta > 0:
                bonus += earth_delta
                notes.append(f"Bear Tattoo +{earth_delta} Reduction (Earth Ring {base_earth}→{effective_earth} via +{sr} Stamina)")
    return bonus, notes


# ---------------------------------------------------------------------------
# Attacker: Attack dice bonus
# ---------------------------------------------------------------------------

def attacker_attack_dice(
    attacker: Character, weapon_profile: dict,
) -> tuple[int, int, int, list[str]]:
    """(bonus_rolled, bonus_kept, flat_bonus, notes) added to the attack roll.
    Lion: +SR rolled dice when attacking with the chosen Bugei skill."""
    active = _active(attacker)
    rolled = kept = flat = 0
    notes: list[str] = []
    if active == "lion":
        chosen = (getattr(attacker, "lion_tattoo_skill", "") or "").lower().strip()
        wpn_skill = str(weapon_profile.get("skill", "")).lower()
        if chosen and chosen == wpn_skill:
            sr = attacker.school_rank
            rolled += sr
            notes.append(f"Lion Tattoo +{sr}k0 attack (+SR ranks in {chosen.title()})")
    return rolled, kept, flat, notes


# ---------------------------------------------------------------------------
# Attacker: Wound penalty reduction
# ---------------------------------------------------------------------------

def attacker_wound_penalty_mod(attacker: Character) -> tuple[int, list[str]]:
    """(flat_bonus, notes) to counteract wound penalties.
    Mountain: wound penalties reduced by (School Rank + 2)."""
    active = _active(attacker)
    if active == "mountain":
        v = attacker.school_rank + 2
        return v, [f"Mountain Tattoo: wound penalties reduced by {v} (SR {attacker.school_rank} + 2)"]
    return 0, []


# ---------------------------------------------------------------------------
# Attacker: Damage bonus
# ---------------------------------------------------------------------------

def attacker_damage(
    attacker: Character, weapon_name: str,
) -> tuple[int, int, int, list[str]]:
    """(extra_rolled, extra_kept, flat_bonus, notes) for the damage roll.
    Blaze: unarmed fire damage = Fire Ring + School Rank (flat).
    Bear (Strength): +ceil(SR/2) rolled melee damage dice."""
    active = _active(attacker)
    rolled = kept = flat = 0
    notes: list[str] = []
    if active == "blaze" and weapon_name.lower().strip() == "unarmed":
        fire = stats.ring_value(attacker, "fire")
        v = fire + attacker.school_rank
        flat += v
        notes.append(f"Blaze Tattoo +{v} fire damage (Fire {fire} + SR {attacker.school_rank})")
    if active == "bear":
        choice = (getattr(attacker, "bear_tattoo_choice", "") or "").lower()
        if choice == "strength":
            v = math.ceil(attacker.school_rank / 2)
            rolled += v
            notes.append(f"Bear Tattoo +{v}k0 melee damage (+{v} Strength)")
    return rolled, kept, flat, notes


# ---------------------------------------------------------------------------
# Attacker: Maneuver free raises
# ---------------------------------------------------------------------------

def maneuver_free_raises(
    attacker: Character, maneuver: str,
) -> tuple[int, list[str]]:
    """(free_raises, notes) that reduce a maneuver's raise cost.
    Storm: Knockdown costs 1 Raise instead of the standard cost."""
    active = _active(attacker)
    if active == "storm" and maneuver == "knockdown":
        return 1, ["Storm Tattoo: Knockdown costs 1 Raise (instead of 2)"]
    return 0, []


# ---------------------------------------------------------------------------
# Fear immunity (Mantis — passive, always on, does not need activation)
# ---------------------------------------------------------------------------

def is_fear_immune(character: Character) -> bool:
    """Mantis Tattoo: permanent passive Fear immunity (s57.25)."""
    return _has_tattoo(character, "mantis")


# ---------------------------------------------------------------------------
# Phoenix reactive heal reminder
# ---------------------------------------------------------------------------

def phoenix_heal_reminder(character: Character) -> str | None:
    """If the character has a Phoenix tattoo, remind that it may trigger
    when reduced to Down or below."""
    if _has_tattoo(character, "phoenix"):
        heal = character.school_rank * 10
        return f"Phoenix Tattoo: if 1+ VP remains, may lose all VP and heal {heal} wounds (cooldown 1 IC week)"
    return None


# ---------------------------------------------------------------------------
# Active tattoo combat reminder (non-auto-applied effects)
# ---------------------------------------------------------------------------

_COMBAT_REMINDERS: dict[str, str] = {
    "balance": "Spells targeting you: TN ±(2×SR + 5)",
    "cloud": "Attackers must re-roll hits; cannot attack while active",
    "ki-rin": "Re-roll one roll per round (keeping higher)",
    "scorpion": "Unarmed attacks auto-Daze on any exploding damage die",
    "volcano": "Wood weapons: Reduction 5 + destroyed; Metal: Contested Fire or disarm",
    "wave": "+IR k0 on Contested Strength for Knockdown (attack and defense)",
}


def active_tattoo_reminder(character: Character) -> str | None:
    """DM-facing reminder of the active tattoo's non-auto-applied combat effect."""
    active = _active(character)
    if not active:
        return None
    if active == "bear":
        choice = (getattr(character, "bear_tattoo_choice", "") or "").lower()
        if choice == "stamina":
            sr = character.school_rank
            boosted = min(character.stamina + sr, character.willpower)
            base = min(character.stamina, character.willpower)
            delta = boosted - base
            thresh = delta * 2
            if thresh > 0:
                return f"⚑ Bear Tattoo (Stamina +{sr}): wound threshold +{thresh} per level (Earth {base}→{boosted})"
        return None
    if active == "lion":
        chosen = (getattr(character, "lion_tattoo_skill", "") or "")
        if chosen:
            return None
        return "⚑ Lion Tattoo: no Bugei skill chosen — use `/sheet tattoo activate Lion skill:` to set one"
    text = _COMBAT_REMINDERS.get(active)
    if text:
        sr = character.school_rank
        text = text.replace("SR", str(sr)).replace("IR", str(stats.insight_rank(character)))
        return f"⚑ {active.title()} Tattoo: {text}"
    return None
