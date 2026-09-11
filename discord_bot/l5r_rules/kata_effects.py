"""Deterministic combat modifiers from a character's ACTIVE kata (GDD s30).

Only the kata whose effect the bot's single-shot `/attack` can compute
faithfully are auto-applied here:
  - stance-conditional Armor TN bonuses (defender side), and
  - unconditional / weapon-conditional attack- and damage-roll modifiers
    (attacker side)
that depend solely on the sheet, the chosen stance, the maneuver, and the
weapon profile — all of which `/attack` already knows.

Everything else in s30 is deliberately NOT auto-applied and stays DM-adjudicated:
  - rate-limited effects ("once per Turn/Round") — the stateless `/attack` has
    no round/turn tracking, so applying them every swing would change the rule;
  - player-choice tradeoffs ("reduce Armor TN by *up to* Earth Ring …");
  - Initiative, movement, mount, ally, guard and other off-`/attack` effects.
The caller surfaces those as a reminder (see `active_kata_reminder`).

Per CLAUDE 'do not invent mechanics': every value below is read verbatim from
the s30 LOCKED text — no thresholds or defaults are invented. Only a PC sheet
carries an `active_kata`; NPCs/creatures simply have none unless a DM sets one.
"""

from __future__ import annotations

from . import stats
from . import combat
from . import kata as kata_mod
from .character import Character

# Lowercased names of the kata whose effect is auto-applied in combat.
AUTO_KATA: frozenset[str] = frozenset({
    "striking as air",         # Defense Stance -> Armor TN += Air Ring
    "reckless abandon style",  # Full Attack Stance -> Armor TN += Fire Ring
    "striking as void",        # Center Stance -> Armor TN += Void Ring
    "lee of the stone",        # Defense (/Full Defense) -> Armor TN += Earth Ring
    "iron in the mountains style",  # Defense Stance uses Earth instead of Air Ring
    "north wind style",        # Increased Damage Maneuver -> attack total += Air Ring
    "south wind style",        # Called Shot/Knockdown Maneuver -> attack total += Air Ring
    "iron forest style",       # spear/polearm -> attack roll uses Air Ring, not Agility
    "waves upon the breakers",  # weapon w/ 3+ Skill Ranks -> damage +1k0
    "strike as the avalanche",  # Heavy Weapons skill -> Strength +1 rank for damage (+1k0)
    "son of storms",           # Small melee weapon -> opponent Reduction -1
    "strength of the crab",    # Attack Stance + wearing Armor -> +2 Reduction
    "strength of the crane",   # wielding sword/spear -> Armor TN += max(1, Honor Rank - 3)
    "strength of the dragon",  # katana main + wakizashi off -> Armor TN += 3
})

# Weapon-skill classes used by the conditional kata (match WEAPON_CATALOG['skill']).
_SPEAR_POLEARM_SKILLS = frozenset({"spears", "polearms"})
_HEAVY_WEAPON_SKILL = "heavy weapons"
_SWORD_SKILL = "kenjutsu"   # every Kenjutsu-skill weapon in the catalog is a sword
_SPEAR_SKILL = "spears"


def _weapon_skill(weapon_name: str) -> str:
    return str(combat.get_weapon_profile(weapon_name).get("skill", "")).lower()


def is_auto(name: str) -> bool:
    """True if `name` is a kata whose combat effect this module auto-applies."""
    return (name or "").lower().strip() in AUTO_KATA


def _active(character: Character) -> str:
    return (getattr(character, "active_kata", "") or "").lower().strip()


def defender_armor_tn_bonus(defender: Character, defender_stance: str) -> tuple[int, str]:
    """Armor TN added by the DEFENDER's active kata for their current stance.

    Returns (bonus, note). Note is a short human-readable tag, "" when nothing
    applies. Stance keys match the bot: attack / full_attack / defense / center.
    (The bot has no separate Full Defense stance, so Lee of the Stone's
    Full-Defense branch is unreachable here — Defense is honoured.)
    """
    k = _active(defender)
    if not k:
        return 0, ""
    if k == "striking as air" and defender_stance == "defense":
        v = stats.ring_value(defender, "air")
        return v, f"Striking as Air +{v} Armor TN (Defense)"
    if k == "reckless abandon style" and defender_stance == "full_attack":
        v = stats.ring_value(defender, "fire")
        return v, f"Reckless Abandon +{v} Armor TN (Full Attack)"
    if k == "striking as void" and defender_stance == "center":
        v = stats.ring_value(defender, "void")
        return v, f"Striking as Void +{v} Armor TN (Center)"
    if k == "lee of the stone" and defender_stance == "defense":
        v = stats.ring_value(defender, "earth")
        return v, f"Lee of the Stone +{v} Armor TN (Defense)"
    if k == "iron in the mountains style" and defender_stance == "defense":
        # Defense Stance normally adds the Air Ring (combat.armor_tn); this kata
        # uses Earth in its place, so the net change is (Earth - Air).
        air = stats.ring_value(defender, "air")
        earth = stats.ring_value(defender, "earth")
        delta = earth - air
        return delta, f"Iron in the Mountains: Defense uses Earth {earth} (was Air {air}), {delta:+d} Armor TN"
    if k == "strength of the crane":
        # Fighting with a sword or spear -> + max(1, Honor Rank - 3) Armor TN.
        # Only a real wielded weapon counts (an empty hand must not fall back to
        # the DEFAULT_WEAPON's Kenjutsu skill).
        eq = (defender.equipped_weapon or "").strip()
        if eq and _weapon_skill(eq) in (_SWORD_SKILL, _SPEAR_SKILL):
            v = max(1, stats.honor_rank(defender) - 3)
            return v, f"Strength of the Crane +{v} Armor TN (sword/spear, Honor Rank − 3)"
    if k == "strength of the dragon":
        # Katana in the main hand and wakizashi in the off hand -> +3 Armor TN.
        if defender.equipped_weapon.lower().strip() == "katana" and \
                defender.off_hand_weapon.lower().strip() == "wakizashi":
            return 3, "Strength of the Dragon +3 Armor TN (katana + wakizashi)"
    return 0, ""


def defender_reduction_bonus(defender: Character, defender_stance: str) -> tuple[int, str]:
    """Extra armor Reduction from the DEFENDER's active kata at damage time.

    Strength of the Crab: while wearing Armor and in Attack Stance, armor
    provides an additional +2 Reduction (s30).
    """
    if _active(defender) == "strength of the crab" and defender_stance == "attack":
        if getattr(defender, "armor_name", ""):
            return 2, "Strength of the Crab +2 Reduction (Attack Stance, armored)"
    return 0, ""


def attacker_trait_override(attacker: Character, weapon_profile: dict) -> tuple[int | None, str]:
    """Trait value replacing the attack roll's normal Trait, from an active kata.

    Iron Forest Style: while using a spear or polearm, use Air Ring instead of
    Agility for attack rolls (s30). Returns (None, "") when no override applies.
    """
    if _active(attacker) == "iron forest style":
        skill = str(weapon_profile.get("skill", "")).lower()
        if skill in _SPEAR_POLEARM_SKILLS:
            v = stats.ring_value(attacker, "air")
            return v, f"Iron Forest: Air Ring {v} replaces Agility on the attack roll"
    return None, ""


def attacker_roll_flat_bonus(attacker: Character, maneuver: str, increased_damage: int) -> tuple[int, str]:
    """Flat bonus added to the ATTACKER's attack-roll total by their active kata.

    North Wind (Increased Damage maneuver) and South Wind (Knockdown; Called
    Shot isn't modelled) each add Air Ring to the attack total (s30).
    """
    k = _active(attacker)
    if not k:
        return 0, ""
    if k == "north wind style" and increased_damage > 0:
        v = stats.ring_value(attacker, "air")
        return v, f"North Wind +{v} to attack (Increased Damage)"
    if k == "south wind style" and maneuver == "knockdown":
        v = stats.ring_value(attacker, "air")
        return v, f"South Wind +{v} to attack (Knockdown)"
    return 0, ""


def attacker_damage_rolled_bonus(attacker: Character, weapon_profile: dict) -> tuple[int, str]:
    """Extra ROLLED damage dice from the attacker's active kata.

    Waves upon the Breakers: while wielding a weapon in which you have at least
    three Skill Ranks, damage is increased by +1k0 (s30) -> +1 rolled die.
    """
    k = _active(attacker)
    if k == "waves upon the breakers":
        skill = weapon_profile.get("skill", "Kenjutsu")
        if attacker.skills.get(skill, 0) >= 3:
            return 1, "Waves upon the Breakers +1k0 damage"
    if k == "strike as the avalanche":
        # Strength considered one Rank higher for damage with Heavy Weapons -> +1
        # rolled die (Strength adds to the rolled pool on a melee weapon).
        if str(weapon_profile.get("skill", "")).lower() == _HEAVY_WEAPON_SKILL:
            return 1, "Strike as the Avalanche +1k0 damage (Strength +1 rank, Heavy Weapons)"
    return 0, ""


def attacker_reduction_ignored(attacker: Character, weapon_profile: dict) -> tuple[int, str]:
    """Amount of the target's Reduction ignored by the attacker's active kata.

    Son of Storms: when attacking with a Small melee weapon, any Reduction an
    opponent possesses is decreased by 1 (s30).
    """
    if _active(attacker) == "son of storms":
        if weapon_profile.get("melee") and str(weapon_profile.get("size", "")).lower() == "small":
            return 1, "Son of Storms −1 target Reduction"
    return 0, ""


# --- Rate-limited kata (once per Turn/Round) --------------------------------
# These are deterministic except for their usage limit, which only a live round
# tracker can enforce. The bot applies them ONLY while an encounter is tracking
# the attacker; otherwise they stay DM-adjudicated reminders. Each key here is
# the encounter usage-set key; the scope says which set gates it.
RATE_LIMITED_SCOPE: dict[str, str] = {
    "striking as fire": "round",        # Full Attack -> +Fire to one attack/Round
    "strength in arms style": "turn",   # Heavy Weapon -> Strength for attack, once/Turn
    "strength of the scorpion": "turn",  # after a Feint -> +3 damage, once/Turn
    "power of the tsunami": "round",     # ignore Reduction = Water Ring, once/Round
}


def is_rate_limited(name: str) -> bool:
    return (name or "").lower().strip() in RATE_LIMITED_SCOPE


def rate_limited_scope(name: str) -> str:
    return RATE_LIMITED_SCOPE.get((name or "").lower().strip(), "")


def striking_as_fire_bonus(attacker: Character, attacker_stance: str) -> tuple[int, str]:
    """Striking as Fire: in Full Attack Stance, add Fire Ring to the total of one
    attack roll per Round (s30). Rate limit enforced by the caller."""
    if _active(attacker) == "striking as fire" and attacker_stance == "full_attack":
        v = stats.ring_value(attacker, "fire")
        return v, f"Striking as Fire +{v} to attack (Full Attack, 1/Round)"
    return 0, ""


def strength_in_arms_override(attacker: Character, weapon_profile: dict) -> tuple[int | None, str]:
    """Strength in Arms Style: once per Turn while wielding a Heavy Weapon, use
    Strength instead of Agility for an attack roll (s30)."""
    if _active(attacker) == "strength in arms style":
        if str(weapon_profile.get("skill", "")).lower() == _HEAVY_WEAPON_SKILL:
            return attacker.strength, "Strength in Arms: Strength replaces Agility on the attack roll (1/Turn)"
    return None, ""


def scorpion_feint_damage(attacker: Character, maneuver: str) -> tuple[int, str]:
    """Strength of the Scorpion: once per Turn, after a successful Feint Maneuver,
    damage total is increased by +3 Wounds (s30)."""
    if _active(attacker) == "strength of the scorpion" and maneuver == "feint":
        return 3, "Strength of the Scorpion +3 damage (after Feint, 1/Turn)"
    return 0, ""


def tsunami_ignore_reduction(attacker: Character) -> tuple[int, str]:
    """Power of the Tsunami: once per Round when attacking, ignore Reduction
    equal to Water Ring (s30)."""
    if _active(attacker) == "power of the tsunami":
        v = stats.ring_value(attacker, "water")
        return v, f"Power of the Tsunami ignores {v} Reduction (1/Round)"
    return 0, ""


def active_kata_reminder(character: Character) -> str:
    """Effect text of an active kata the bot does NOT auto-apply, for the DM.

    Returns "" when there is no active kata, or when the active kata is one this
    module handles automatically (an auto kata whose condition simply isn't met
    this attack correctly does nothing, so it needs no reminder).
    """
    name = (getattr(character, "active_kata", "") or "").strip()
    if not name or is_auto(name):
        return ""
    rec = kata_mod.get(name)
    return rec["effect"] if rec else ""
