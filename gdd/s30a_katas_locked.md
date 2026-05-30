# s30a — Katas: Eligibility, Acquisition, and Effect Registry (LOCKED)

**Status: LOCKED — 2026-05-30**
**Source: GDD s30 (Reference) + implementation design**

Katas are fighting postures evolved through martial repetition. They differentiate
bushi characters beyond Techniques but with more martial specificity than Skills
or Advantages. This document formalises the mechanic rules sufficient for data
modelling and eligibility gating. Combat effects are registered as stubs here and
**remain blocked on s40 (individual combat)** — no effect is applied until s40 is
implemented.

---

## A1 — Core Rules (from GDD s30)

1. **Bushi only.** Only characters whose `school_type == SchoolType.BUSHI` may
   learn or use katas. School-less characters (born ronin) with no school data
   are NOT eligible — the GDD states "A bushi may purchase a Kata if their School
   is listed." A character with no school has no listed school. EXCEPTION: katas
   whose Schools field is "Any" or "Any bushi School" remain unavailable to
   school-less characters because the character lacks a bushi school designation.

2. **Ring requirement.** The character's relevant Ring must equal or exceed the
   kata's Mastery Level. Ring value = min(associated traits), per s4.5.2.

3. **XP cost.** Cost equals the Mastery Level in Experience Points.
   `kata_xp_cost = mastery_level` (in XP units, not progress units).

4. **Activation.** Executing a kata is a Simple Action (s40, blocked). The benefit
   lasts until the effect expires or the character drops it (Free Action, s40, blocked).

5. **One active at a time.** Only one kata may be active simultaneously. The `katas`
   array on `L5RCharacterData` stores *known* katas (the full list); the active kata
   is tracked separately by the combat system (s40, blocked).

6. **No duplicate learning.** A character may not learn the same kata twice.

---

## A2 — School Eligibility Interpretation

The GDD s30 Schools field uses four patterns:

| GDD Pattern | Code Interpretation |
|-------------|---------------------|
| `Any` | Any bushi (school_type == BUSHI) from any school |
| `Any bushi School` | Same as "Any" |
| `Any [Clan] Bushi` | school_type == BUSHI AND clan == [Clan] |
| Named school(s) | school_name must exactly match one listed name |

School name matching is case-sensitive against the exact string in KATA_DATA.
Multi-school katas (comma-separated) pass if the character's `school_name` is
in the list OR their `school_paths` array contains a matching entry.

**Clan matching for "Any [Clan] Bushi":**
- "Any Mantis Bushi" → clan == "Mantis"
- "Any Crane Bushi"  → clan == "Crane"
- "Any Crab Bushi"   → clan == "Crab"
- "Any Spider Bushi" → clan == "Spider"
- "Any Lion Bushi"   → clan == "Lion"
- "Any Scorpion Bushi" → clan == "Scorpion"
- "Any Dragon Bushi" → clan == "Dragon"
- "Any Unicorn Bushi" → clan == "Unicorn"
- "Any Phoenix Bushi" → clan == "Phoenix"

---

## A3 — Multi-Ring Katas (The Daisho Chain)

Four katas accept Air **or** Fire as their qualifying ring:

| Kata | Standard Requirement | Mirumoto/Kakita Reduction |
|------|---------------------|--------------------------|
| The Empire Rests on its Edge | Air 3 or Fire 3 | Air 2 or Fire 2 |
| The World Is Empty | Air 4 or Fire 4 | Air 3 or Fire 3 |
| Victory of the River | Air 5 or Fire 5 | Air 4 or Fire 4 |
| Standing on the Heavens | Air 6 or Fire 6 | Air 5 or Fire 5 |

"Standing on the Heavens" requires Ring 6. The maximum ring rank in normal play
is 5. It is theoretically unreachable except via extraordinary narrative means
(not yet modelled). Eligibility logic returns `false` for this kata unless a
character somehow possesses Ring 6+.

Mirumoto Bushi and Kakita Bushi schools reduce the requirement by 1 (minimum 2).
The `school_name` check for reduction uses exact match: "Mirumoto Bushi" and
"Kakita Bushi".

**Special restriction:** All four katas require Katana or daisho as the weapon
(see effect_desc). This gate is s40 combat state — not enforced in eligibility
(learning is permitted; activation is gated by weapon, blocked on s40).

---

## A4 — XP Deduction vs. Progress System

The progress bar system (s48/s52) tracks skill and ring advancement in units.
Kata learning uses **XP directly**, not progress units:

```
learn cost = kata.mastery_level  (in XP)
character.xp_accumulated -= kata.mastery_level
```

XP is always non-negative — eligibility check must verify `character.xp_accumulated
>= mastery_level` before deducting.

---

## A5 — Kata Data Table (43 Katas)

All 43 katas from GDD s30. Effect descriptions are logged but not applied (s40 blocked).

### AIR Katas

| Kata | Ring | ML | Schools | Effect Summary |
|------|------|----|---------|----------------|
| Striking as Air | Air | 3 | Any bushi | In Defense Stance: +Air Ring to Armor TN |
| Breath of Wind Style | Air | 3 | Kakita Bushi, Bayushi Bushi | Initiative +2 each Reactions Stage |
| Dance of the Winds | Air | 3 | Daidoji Bushi, Shiba Bushi | Polearm/spear: +3 Initiative |
| Strength of the Mantis | Air | 3 | Any Mantis Bushi | Ranged attack penalty in melee −3 |
| Strength of the Crane | Air | 3 | Any Crane Bushi | Sword/spear: +(Honor Rank−3, min 1) to Armor TN |
| Iron Forest Style | Air | 4 | Daidoji Iron Warrior, Heichi Bushi, Shiba Bushi | Spear/polearm: use Air Ring instead of Agility for attack rolls |
| Veiled Menace Style | Air | 4 | Bayushi Bushi, Hiruma Bushi, Tsuruchi Archer, Yoritomo Bushi | Once per Turn: +Stealth rank to Armor TN vs one attack |
| North Wind Style | Air | 4 | Any bushi School | +Air Ring to attack roll total when using Increased Damage Maneuver |
| South Wind Style | Air | 4 | Any bushi School | +Air Ring to attack roll total when using Called Shot or Knockdown Maneuver |
| Hidden Blade Style | Air | 4 | Bayushi Bushi, Yoritomo Bushi | Disarm attacks deal normal damage (not 2k1); damage may not be raised |

### EARTH Katas

| Kata | Ring | ML | Schools | Effect Summary |
|------|------|----|---------|----------------|
| Striking as Earth | Earth | 3 | Any bushi | In Full Defense Stance: +Earth Ring Reduction |
| The Power of the Mountain | Earth | 3 | Hida Bushi, Hiruma Bushi, Matsu Berserker, Ichiro Bushi | Reduce Armor TN by up to Earth Ring; +same to all damage totals |
| The Strength of the Mountain | Earth | 3 | Hida Bushi, Hiruma Scout, Shiba Bushi, Daidoji Iron Warrior | Reduce Initiative by up to Earth Ring; +same to Armor TN |
| Strike as the Avalanche | Earth | 3 | Hida Bushi, Hiruma Bushi, Ichiro Bushi, Moto Bushi, Moto Vindicator | Heavy Weapons: Strength treated one Rank higher for damage |
| Strength of the Spider | Earth | 3 | Any Spider Bushi | Once per Round: if 15+ Wounds dealt, opponent −3 to all rolls next Turn |
| Strength of the Crab | Earth | 3 | Any Crab Bushi | In Attack Stance wearing Armor: +2 Reduction |
| Iron in the Mountains Style | Earth | 3 | Daidoji Iron Warrior, Hida Bushi | Use Earth Ring in place of Air Ring for Defense Stance |
| Indomitable Warrior Style | Earth | 4 | Daigotsu Bushi, Hida Bushi, Ichiro Bushi, Moto Bushi | Reduce TN penalties from Wound Ranks by Earth Ring |
| Lee of the Stone | Earth | 4 | Hida Bushi, Hida Pragmatist, Shiba Bushi, Daidoji Iron Warrior | In Defense/Full Defense Stance: +Earth Ring to Armor TN |
| Weathered and Unbroken | Earth | 5 | Hida Bushi, Hiruma Bushi, Hiruma Scout, Ichiro Bushi | Water treated 2 Ranks lower for movement; Heavy Weapons gain 1 Free Raise for Knockdown only |

### FIRE Katas

| Kata | Ring | ML | Schools | Effect Summary |
|------|------|----|---------|----------------|
| Striking as Fire | Fire | 3 | Any bushi | In Full Attack Stance: +Fire Ring to one attack roll per Round |
| Strength of the Scorpion | Fire | 3 | Any Scorpion Bushi | Once per Turn after Feint: damage +3 Wounds |
| Strength of the Dragon | Fire | 3 | Any Dragon Bushi | Katana main + wakizashi off-hand: +3 Armor TN |
| Reckless Abandon Style | Fire | 4 | Daigotsu Bushi, Matsu Berserker, Usagi Bushi | In Full Attack Stance: +Fire Ring to Armor TN |
| Disappearing World Style | Fire | 4 | Akodo Bushi, Kakita Bushi | Choose one opponent; once per Turn: use Agility instead of Strength for damage |
| Spinning Blades Style | Fire | 5 | Mirumoto Bushi, Yoritomo Bushi | Extra Attack Maneuver costs 3 Raises (not 5); off-hand normal damage; no Raise damage boost |

### WATER Katas

| Kata | Ring | ML | Schools | Effect Summary |
|------|------|----|---------|----------------|
| Striking as Water | Water | 4 | Any bushi | In Attack Stance: move 5 extra feet as Free Action |
| Strength of the Lion | Water | 3 | Any Lion Bushi | Once per Round Reactions Stage: +3 Initiative to one ally in skirmish |
| Son of Storms | Water | 3 | Akodo Bushi, Shosuro Infiltrator, Yoritomo Bushi | Small melee weapon attacks: opponent Reduction −1 |
| Strength of the Unicorn | Water | 3 | Any Unicorn Bushi | Mounted: steed +3 Armor TN and +3 Reduction |
| Waves upon the Breakers | Water | 3 | Akodo Bushi, Kakita Bushi, Shinjo Bushi | Weapon with 3+ Skill Ranks: damage +1k0 |
| Leaves in the Stream | Water | 3 | Bayushi Bushi, Hiruma Bushi, Mirumoto Bushi, Shiba Bushi | Reduce Armor TN by up to 5×Water Ring (min 5); +same to max movement distance |
| Power of the Tsunami | Water | 4 | Daigotsu Bushi, Hida Bushi, Moto Bushi | Once per Round when attacking: ignore Reduction equal to Water Ring |
| Strength in Arms Style | Water | 4 | Hida Bushi, Ichiro Bushi, Moto Bushi | Once per Turn with Heavy Weapon: use Strength instead of Agility for attack |
| Art of Ninjutsu | Water | 5 | Daigotsu Bushi, Bayushi Bushi, Daidoji Scout, Shosuro Actor, Shosuro Infiltrator, Goju Ninja | Once per Round: Move distance as if Water Ring = Stealth rank |

### VOID & MULTI-RING Katas

| Kata | Ring | ML | Schools | Effect Summary |
|------|------|----|---------|----------------|
| Striking as Void | Void | 3 | Any bushi | In Center Stance: +Void Ring to Armor TN |
| Balance the Elements Style | Void | 3 | Mirumoto Bushi, Shiba Bushi | Use Void Ring instead of Reflexes for Initiative Rolls |
| Strength of Purity Style | Void | 3 | Akodo Bushi, Kakita Bushi, Matsu Berserker, Utaku Battle Maiden | Once per Turn when rolling damage: roll Honor Rank, keep weapon DR dice |
| Strength of the Phoenix | Void | 3 | Any Phoenix Bushi | Once per Turn on Guard Action: guarded ally +3 Armor TN |
| The Empire Rests on its Edge | Air 3 or Fire 3 | 3 | Any (Katana/daisho only) | Choose non-combat High Skill; while active: +Rank in that Skill to Kenjutsu/Iaijutsu rolls |
| The World Is Empty | Air 4 or Fire 4 | 4 | Any (Katana/daisho only) | +Xk0 to Kenjutsu/Iaijutsu (X = current Void Points); lasts Void Points rounds; lose 1 VP on end |
| Victory of the River | Air 5 or Fire 5 | 5 | Any (Katana/daisho only) | On successful strike: target Armor TN −10 for 3 rounds; own Armor TN −10 while active |
| Standing on the Heavens | Air 6 or Fire 6 | 6 | Any (Katana/daisho only) | Once per Round when struck: spend 1 VP (Free Action) to force opponent to reroll attack |

---

## A6 — Effect Registry Structure

Each kata maps to an `effect_id` string. The effect registry in `kata_system.gd`
stores the description but does not apply any mechanical change. Wiring belongs
to s40 (individual combat).

Effect stub format:
```gdscript
{
    "effect_id": String,   # unique snake_case identifier
    "blocked_on": "s40",   # dependency
    "effect_desc": String, # human-readable GDD text
}
```

---

## A7 — NPC Kata Selection

NPCs select the highest Mastery Level kata they are eligible for when:
- They have sufficient XP accumulated (`xp_accumulated >= mastery_level`)
- No kata of equal or higher mastery is already known
- Their school_type == BUSHI

Selection preference: highest mastery level, then alphabetical tie-break
for determinism. Katas for which the character lacks the required ring are
excluded regardless of school eligibility.

---

## A8 — What Is NOT Implemented (s40 Blocked)

All mechanical effects of katas — Armor TN changes, attack roll bonuses,
damage bonuses, Initiative changes, stance interactions, maneuver modifiers,
movement bonuses, void point interactions — are **blocked on s40 (individual
combat)**. The `get_effect_stub()` function returns the description string
only. No stat on `L5RCharacterData` is modified by learning or "activating"
a kata.

The `active_kata` field tracking which kata is currently active is also s40-
blocked. `L5RCharacterData.katas` stores only the set of known katas.
