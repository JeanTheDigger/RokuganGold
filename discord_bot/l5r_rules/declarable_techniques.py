"""Declarable / activatable school techniques for combat (GDD s29).

Unlike the passive auto-apply bonuses in technique_effects.py (which fire on
every qualifying attack), these techniques require active declaration by the
player or Fortune during combat.  Each entry records the cost, usage limit,
duration, and -- where the bot can evaluate the effect deterministically --
machine-readable effect keys consumed by the attack flow.

Techniques whose effects are too situational for auto-application carry
``"manual": True``.  These are still declared, tracked, and displayed so
the Fortune sees them; the Fortune applies the effects by hand.

Key conventions
---------------
cost ........... 0 = free, positive int = Void Points, "slot" = spell slot
limit .......... "none" | "turn" | "round" | "encounter" | "skirmish" | "day"
max_uses ....... how many times per *limit* period (usually 1)
duration ....... "instant" | "attack" | "turn" | "round" | "rounds:N" |
                 "skirmish" | "special"
action ......... "free" | "simple" | "complex" | "reaction"
                 (what the declaration itself costs in action economy)
requires ....... dict of conditions that must be true to declare
effects ........ dict of auto-apply modifiers (see _EFFECT_KEYS below)
desc ........... one-line human-readable summary shown on the button / embed
manual ......... True if the Fortune must adjudicate (no auto-effects)

Effect keys consumed by the attack / damage / defense flow:
  atk_rolled, atk_kept, atk_flat        -- attack roll bonuses
  dmg_rolled, dmg_kept, dmg_flat        -- damage roll bonuses
  dmg_explode                           -- kept damage dice explode (bool)
  atn_bonus                             -- Armor TN bonus (defender)
  reduction_bonus                       -- extra Reduction (defender)
  reduction_ignore                      -- ignore N target Reduction
  target_reduction_penalty              -- reduce target Reduction by N
  on_hit_condition                      -- inflict condition on hit (str)
  ignore_wound_penalties                -- ignore all wound penalties (bool)
  simple_action_attack                  -- attacks become Simple Actions (bool)
  ignore_target_stance_atn              -- ignore target stance ATN (bool)
"""

from __future__ import annotations

# ---------------------------------------------------------------------------
# The catalog -- keyed by lowercase technique name.
# ---------------------------------------------------------------------------

CATALOG: dict[str, dict] = {}


def _add(name: str, **kw: object) -> None:
    kw.setdefault("cost", 0)
    kw.setdefault("limit", "none")
    kw.setdefault("max_uses", 1)
    kw.setdefault("duration", "attack")
    kw.setdefault("action", "free")
    kw.setdefault("requires", {})
    kw.setdefault("effects", {})
    kw.setdefault("manual", False)
    kw["display"] = name
    CATALOG[name.lower()] = kw


# ===== CATEGORY 1: VP + FREE ACTION ========================================

_add("Destiny's Hand",
     cost=1, duration="round",
     desc="VP: +1k1 to one ally's roll this Round.",
     manual=True)

_add("Unyielding Spirit",
     cost=1, duration="attack",
     desc="VP: Ignore all penalties on next roll; if Attack, also +Xk0 (Earth Ring).",
     manual=True)

_add("The Way of Water",
     cost=1, duration="attack",
     requires={"stance": ["defense", "full_defense"]},
     desc="VP: On melee miss against you, counter-Throw / Grapple opponent.",
     manual=True)

_add("Wall of Pikes",
     cost=1, duration="round",
     requires={"stance": ["defense", "full_defense"], "weapon_skill": "spears"},
     desc="VP: Reactive spear attack when opponent attacks you or adjacent ally. Full Defense costs 2 VP.",
     manual=True)

_add("Swift Fist, Subtle Heart",
     cost=1, duration="special",
     requires={"weapon": "unarmed"},
     desc="VP: For SR Rounds, each Turn choose +1k1 unarmed attack OR +1k0 unarmed damage.",
     manual=True)

_add("Strike When You Cannot",
     cost=1, duration="instant",
     desc="VP: During iaijutsu Assessment, deny opponent VP on Focus (Contested Kenjutsu/Fire).",
     manual=True)

_add("Wrath of the Earth Dragon",
     cost=1, duration="round",
     desc="VP: Attacks this Round ignore all Reduction of nonhuman opponents.",
     effects={"reduction_ignore": 999},
     manual=True)

_add("Courage of the Thunder Dragon",
     cost=1, duration="attack",
     desc="VP: After hitting, ignore one opponent Technique/armor/spell that reduces damage.",
     manual=True)

_add("Hand of the Emperor",
     cost=1, duration="round",
     desc="VP: Prevent Rokugani from harming you until next Reactions (only while not fighting).",
     manual=True)

_add("Ferocious Determination",
     cost=1, duration="round",
     desc="VP: Contested Courtier/Awareness; on success, opponent penalized on attack and social.",
     manual=True)

_add("The Lion's Victory",
     cost=1, limit="encounter", duration="attack",
     desc="VP (1x/encounter): After rolling damage, all kept dice explode.",
     effects={"dmg_explode": True})

_add("Matsu's Technique",
     cost=1, duration="instant", action="reaction",
     desc="VP: When opponent declares melee attack and you have not acted, pre-emptive Simple Action attack.",
     manual=True)

_add("Pure and Dedicated",
     cost=1, limit="skirmish", duration="round",
     desc="VP (1x/skirmish): Honor Rank counts as double for all other School Techniques.",
     manual=True)

_add("Hand of Osano-Wo",
     cost=1, duration="attack",
     desc="VP: Keep additional damage dice = Strength; +0k2 vs Prone.",
     manual=True)

_add("Legacy of the Kshatriya",
     cost=1, limit="skirmish", max_uses=2, duration="attack",
     desc="VP (2x/skirmish): On hit, add unkept dice to damage = Lore: Theology rank.",
     manual=True)

_add("To Punish the Wicked",
     cost=1, duration="attack",
     desc="VP: Negate target Reduction = School Rank.",
     manual=True)

_add("The Blade Upon the Wind",
     cost=1, limit="skirmish", duration="instant",
     desc="VP (1x/skirmish): Set Initiative = any other participant's (then -5 per Reactions).",
     manual=True)

_add("Exhaustive Knowledge",
     cost=1, duration="special",
     desc="VP: Attacks with self-crafted weapon as Simple Actions for SR Rounds.",
     effects={"simple_action_attack": True},
     manual=True)

_add("The Speed of Certainty",
     cost=1, limit="round", duration="attack", action="free",
     desc="VP (1x/Round): One melee attack as Free Action (no other attacks this Round).",
     manual=True)

_add("The Same Breeze",
     cost=1, duration="special",
     desc="VP: Copy one bushi Technique of character within 20' for Air Ring Rounds.",
     manual=True)

_add("Name of the Elements",
     cost=1, duration="special",
     desc="VP: +2x chosen Ring Rank to Armor TN for SR minutes.",
     manual=True)

_add("None Must Fall",
     cost=1, duration="attack", action="reaction",
     desc="VP: When absorbing damage for charge, on success negate damage entirely.",
     manual=True)

_add("Tigers Do Not Fall",
     cost=1, duration="attack", action="reaction",
     desc="VP: Negate all Maneuver benefits opponent declared (including Increased Damage).",
     manual=True)

_add("The Butcher's Gaze",
     cost=1, duration="instant",
     desc="VP: Before iaijutsu Assessment, Intimidation to prevent opponent dice exploding.",
     manual=True)

_add("Ekuro's Weapons",
     cost=1, duration="special",
     desc="VP: Attack with elemental weapons as Simple Actions for Insight Rank Rounds.",
     effects={"simple_action_attack": True},
     manual=True)

_add("Unravel the Shadow",
     cost=1, duration="attack",
     desc="VP: Attack/spell has full effect on Nothing minion regardless of resistances.",
     manual=True)

_add("The Hidden Blade",
     cost=1, duration="attack",
     requires={"weapon_skill": "knives"},
     desc="VP: Attacking surprised opponent with knife, damage Raises become +1k1 per Raise.",
     manual=True)

_add("Dancing With the Fortunes",
     cost=1, duration="instant",
     desc="VP: Roll Void (TN 20/30) to get VP benefit without spending it.",
     manual=True)

_add("Otaku's Blessing",
     cost=1, duration="turn",
     desc="VP: Add Honor Rank to all damage rolls and Bugei Skill Rolls this Turn.",
     manual=True)

_add("Pale Face of Death",
     cost=1, duration="skirmish",
     desc="VP: One opponent within 30' suffers TN penalties = Lore: Theology for rest of encounter.",
     manual=True)

_add("Sun's Light Reveals",
     cost=1, duration="instant",
     desc="VP: Investigation (Notice)/Perception TN 25 to see through all disguises/illusions.",
     manual=True)

_add("Never This Sacred Ground Shall Fall",
     cost=1, duration="instant",
     desc="VP: When defending sacred location, grant Earth damage spell the Jade keyword.",
     manual=True)


# ===== CATEGORY 2: VP COST (various timing) ================================

_add("The Mountain Does Not Fall",
     cost=1, limit="none", duration="turn",
     desc="VP: Act as Healthy for one Turn, ignore Dazed/Fatigued/Stunned.",
     effects={"ignore_wound_penalties": True})

_add("Fight to the End",
     cost=1, duration="attack",
     desc="VP: One attack ignoring all Wound penalties/Status/Disadvantages, +3k1 damage.",
     effects={"ignore_wound_penalties": True, "dmg_rolled": 3, "dmg_kept": 1})

_add("Vigilant and Strong",
     cost=1, duration="rounds:2",
     desc="VP: Negate darkness/blinding penalties for 2 Rounds.",
     manual=True)

_add("Claws of the Falcon",
     cost=1, duration="round",
     desc="VP: Vs Spirit Realm creatures, reduce Reduction by 10 for one Round.",
     effects={"reduction_ignore": 10},
     manual=True)

_add("Overrun",
     cost=1, duration="attack",
     requires={"mounted": True},
     desc="VP: Add mount's Strength (unkept dice) to attack roll when mounted.",
     manual=True)

_add("The Soul's Grace",
     cost=1, duration="special",
     desc="VP: Reduce all opponents' damage rolls within 20' by 0k1 for SR Rounds.",
     manual=True)

_add("Vigilance of Mind",
     cost=1, duration="attack", action="reaction",
     desc="VP during Reactions: +2k1 attack and damage vs opponent who attacked you/charge.",
     effects={"atk_rolled": 2, "atk_kept": 1, "dmg_rolled": 2, "dmg_kept": 1})

_add("Cunning of Daidoji",
     cost=1, duration="attack",
     desc="VP: Next attack Maneuvers -1 Raise, +1k1 damage; vs unaware, unlimited Raises.",
     effects={"dmg_rolled": 1, "dmg_kept": 1})

_add("The Willow in the Storm",
     cost=1, duration="round", action="reaction",
     desc="VP during Reactions: Attackers subtract their Air Ring from each die next Round.",
     manual=True)

_add("Strike of Harmony",
     cost=1, duration="attack",
     requires={"weapon_skill": "kenjutsu"},
     desc="VP: On damage rolls with sword (stacks with katana ability).",
     manual=True)

_add("Strike the Base",
     cost=1, duration="attack",
     requires={"weapon": "unarmed"},
     desc="VP: On unarmed damage rolls including Grapple.",
     manual=True)

_add("The Body is Illusion",
     cost=1, duration="skirmish", action="simple",
     desc="VP + Simple Action: Ignore Wound Penalties (incl. Down) for rest of skirmish.",
     effects={"ignore_wound_penalties": True})

_add("The Silence of Two Strikes",
     cost=0, limit="none", duration="skirmish",
     requires={"weapon": ["katana", "wakizashi"]},
     desc="While wielding katana/wakizashi, may spend VP twice per Turn.",
     manual=True)

_add("The Clouds Part",
     cost=1, duration="turn",
     desc="VP at start of Turn: Add Honor Rank to all attack and damage roll totals.",
     manual=True)

_add("Heaven Never Falls",
     cost=1, duration="instant", action="reaction",
     desc="VP: Leap in front of blow targeting charge within 20'; absorb damage; if still standing, extra Simple Action.",
     manual=True)

_add("Storm of Heaven's Wrath",
     cost=1, duration="attack",
     requires={"mounted": True, "stance": ["attack"]},
     desc="VP: Add half Honor Rank (kept dice) to attack roll while mounted in Attack Stance.",
     manual=True)

_add("Uphold the Peace",
     cost=1, duration="instant", action="complex",
     desc="VP + Complex Action: Contested Intimidation to force cessation of hostilities.",
     manual=True)

_add("Malleable as the Sea",
     cost=1, duration="instant",
     desc="VP: Choose any Heroic Opportunity in Mass Battle Turn.",
     manual=True)

_add("The Soul of the Army",
     cost=1, duration="attack",
     desc="VP: +5k2 Battle Skill Roll or +2k2 Bugei Skill Roll.",
     manual=True)

_add("Drunk Pounds a Door",
     cost=1, duration="attack",
     desc="VP on melee attack: +4k1 attack and damage (+4k2 if Prone).",
     effects={"atk_rolled": 4, "atk_kept": 1, "dmg_rolled": 4, "dmg_kept": 1})

_add("The Anger of the Boar",
     cost=1, duration="skirmish", action="reaction",
     desc="VP during Reactions: Reduce Wound TN penalty by one rank for rest of skirmish.",
     manual=True)

_add("Forge Your Own Fate",
     cost=1, duration="instant", action="reaction",
     desc="VP when taking Wounds: Opponent drops two highest damage dice (min 1k1).",
     manual=True)

_add("Stand Against Oppression",
     cost=1, duration="attack",
     desc="VP: +unkept dice to attack = Glory difference (max SR) vs higher-Glory opponent.",
     manual=True)

_add("The Poisoned Frog",
     cost=1, limit="skirmish", duration="attack",
     desc="VP (1x/opponent/skirmish): Damage Raises become +1k1 instead of +1k0 (max Void Rank Raises).",
     manual=True)

_add("Purity",
     cost=1, duration="attack",
     requires={"weapon": ["unarmed", "knife"]},
     desc="VP with unarmed/knife: Contested Void; on success, opponent -Xk0 Skill Rolls for 3 Reactions.",
     manual=True)

_add("Strength of the Empire",
     cost=1, duration="attack",
     desc="VP enhancement gains bonus = number of allied legionnaires/magistrates within 25'.",
     manual=True)

_add("The Riddle of Fire",
     cost=1, duration="instant", action="reaction",
     desc="VP when struck by melee: Contested Fire to reduce opponent's damage dice by Fire Ring.",
     manual=True)

_add("The Trials of Jade",
     cost=1, duration="attack",
     desc="VP: Spell counts as jade/crystal for defeating Reduction/Invulnerability.",
     manual=True)

_add("Shiba's Sacrifice",
     cost=0, duration="instant",
     desc="VP spent to reduce absorbed damage reduces by 20 instead of 10.",
     manual=True)

_add("Valor of the Wolf",
     cost=1, duration="special",
     desc="VP: Activate Rank 1 Technique without Willpower Roll, lasts Fire Ring Rounds.",
     manual=True)

_add("For My Brothers",
     cost=1, duration="instant", action="reaction",
     desc="VP: Negate damage on ally = Void Ring x 5.",
     manual=True)

_add("Smoke and Mirrors",
     cost=1, limit="round", max_uses=2, duration="attack",
     requires={"weapon": "machi_kanshisha"},
     desc="VP: Melee attack with iron pipe as Simple Action (up to 2 VP/Round).",
     effects={"simple_action_attack": True})

_add("Death's Dark Shadow",
     cost=1, duration="attack",
     desc="VP: Add Stealth margin of success to next attack roll.",
     manual=True)

_add("The Journey's Beginning",
     cost=1, duration="attack",
     requires={"mounted": True},
     desc="VP while mounted: Single attack as Simple Action.",
     effects={"simple_action_attack": True})

_add("Flight of Innocence",
     cost=1, duration="attack",
     requires={"weapon_skill": "kyujutsu"},
     desc="VP with bow: +1k1 to damage.",
     effects={"dmg_rolled": 1, "dmg_kept": 1})

_add("The Unbroken",
     cost=1, duration="instant",
     desc="VP after killing Shadowlands creature: Lose 1 Taint Point permanently.",
     manual=True)

_add("Black Lion Talon",
     cost=1, duration="attack",
     desc="VP on attack roll: Also add Honor Rank to total (enhances normal VP usage).",
     manual=True)

_add("The Final Silence",
     cost=1, duration="attack",
     desc="VP after damage: Increase any two dice to 10s (multiple VPs allowed).",
     manual=True)

_add("Fury of Heaven",
     cost=1, duration="attack",
     desc="VP on attack: +5x Lore: Theology to attack total.",
     manual=True)

_add("Utaku's Thunder",
     cost=1, limit="skirmish", duration="attack",
     desc="VP (1x/skirmish): +Honor Rank unkept dice to attack roll.",
     manual=True)

_add("The World is a Canvas",
     cost=1, limit="day", duration="instant",
     desc="VP (Insight Rank times/day): Cast Summon Fog or False Realm as Simple Action.",
     manual=True)

_add("The Eye Sees All",
     cost=1, duration="instant",
     desc="VP: +2k2 to avoid being surprised.",
     manual=True)

_add("Voice of the Emperor",
     cost=1, duration="round",
     desc="VP: Attackers automatically lose Honor = 2x SR.",
     manual=True)

_add("Scrutiny's Sweet Sting",
     cost=1, duration="instant",
     desc="VP in Contested Roll: Force opponent to use Mental Trait of your choice.",
     manual=True)


# ===== CATEGORY 3: ONCE PER ROUND (no VP) ==================================

_add("Hummingbird Wings",
     cost=0, limit="round", duration="attack", action="reaction",
     desc="1x/Round: Double SR bonus to Armor TN vs one attack.",
     manual=True)

_add("The Crab are the Wall",
     cost=0, limit="round", duration="instant",
     desc="1x/Round: Negate one Condition (except Mounted/Grappled).",
     manual=True)

_add("Empowered By Her Name",
     cost=0, limit="round", duration="attack",
     desc="1x/Round FA: Extra melee attack vs opponent with lower Honor.",
     manual=True)

_add("The Spirit of Ikoma",
     cost=0, limit="round", duration="round",
     desc="1x/Round FA: Lose 3 Honor for +2k1 attack/damage/social until end of Round.",
     effects={"atk_rolled": 2, "atk_kept": 1, "dmg_rolled": 2, "dmg_kept": 1})

_add("Charge of the Pride",
     cost=0, limit="round", duration="round",
     requires={"stance": ["full_attack"]},
     desc="1x/Round: +5' movement in Full Attack; Complex Move = Water x 25'.",
     manual=True)

_add("Fortune Favors Mortal Man",
     cost=1, limit="round", duration="instant",
     desc="VP 1x/Round: Reroll any roll with +2k1, keep either result.",
     manual=True)

_add("The Emperor's Hand",
     cost=0, limit="round", duration="instant",
     desc="1x/Round FA: Grant bonus VP to subordinate/ally in line of sight.",
     manual=True)

_add("Spirit of the Blade Unleashed",
     cost=0, limit="round", duration="attack", action="reaction",
     desc="1x/Round FA (SR times/skirmish): Reactive melee attack in Defense/Full Defense.",
     requires={"stance": ["defense", "full_defense"]},
     manual=True)


# ===== CATEGORY 4: ONCE PER ENCOUNTER / SKIRMISH ===========================

_add("Devastating Blow",
     cost=0, limit="encounter", duration="attack",
     requires={"weapon_skill": "heavy weapons"},
     desc="1x/encounter, Heavy Weapon: Lower enemy Reduction by 4, Daze on hit.",
     effects={"target_reduction_penalty": 4, "on_hit_condition": "dazed"})

_add("Berserker's Rage",
     cost=0, limit="skirmish", duration="special",
     desc="1x/skirmish: Enter rage (Earth x2 Rounds). +2k1 attack/damage, ignore Wounds; no Center/Defense/FD. If killed, stay alive until rage ends.",
     effects={"atk_rolled": 2, "atk_kept": 1, "dmg_rolled": 2, "dmg_kept": 1, "ignore_wound_penalties": True})

_add("Balance of Nothingness",
     cost=0, limit="skirmish", duration="attack",
     requires={"weapon_skill": "kenjutsu"},
     desc="1x/skirmish: Spend unlimited VP on damage with sword.",
     manual=True)

_add("Judgment of Celestial Dragon",
     cost=4, limit="skirmish", duration="instant",
     desc="VP x4 (1x/skirmish, 3 VP vs nonhuman): Auto reduce opponent to Down/Out/Dead.",
     manual=True)

_add("Triumph Before Battle",
     cost=0, limit="skirmish", duration="round",
     desc="1x/skirmish: Designate opponent; ignore their Stance ATN bonuses next Round.",
     effects={"ignore_target_stance_atn": True})

_add("The Heart of the Sword",
     cost=0, limit="skirmish", duration="instant",
     desc="1x/skirmish FA: Activate a Kata as Free Action.",
     manual=True)

_add("Every Scar Has a Name",
     cost=0, limit="skirmish", duration="attack",
     requires={"weapon": ["unarmed", "improvised"]},
     desc="1x/skirmish: 2 Raises to inflict Fear (Insight Rank) with unarmed/improvised.",
     manual=True)

_add("Flight of No-Mind",
     cost=1, limit="skirmish", duration="attack", action="complex",
     requires={"weapon_skill": "kyujutsu"},
     desc="VP+Complex (1x/skirmish): Arrow ignores armor/Wound penalties/visibility.",
     effects={"ignore_wound_penalties": True, "reduction_ignore": 999})

_add("The Virtue of the Gods",
     cost=1, limit="skirmish", duration="attack",
     desc="VP (1x/skirmish): +unkept dice to damage = Lore: Theology (IK).",
     manual=True)

_add("Twice-Cutting Spirit",
     cost=1, limit="skirmish", duration="attack",
     desc="VP (1x/skirmish): Spend VP on damage roll regardless of weapon.",
     manual=True)

_add("Pincers Hold, Tail Strikes",
     cost=1, limit="encounter", duration="attack", action="complex",
     desc="VP+Complex (1x/encounter): Melee attack Stuns target.",
     effects={"on_hit_condition": "stunned"})

_add("Relentless Resolve",
     cost=0, limit="skirmish", duration="round",
     desc="1x/skirmish: +unkept dice (Intimidation rank) on all attacks for one Round.",
     manual=True)

_add("The Eyes of My Enemy",
     cost=1, limit="skirmish", duration="special", action="simple",
     desc="VP+Simple (1x/skirmish): Disable chosen-clan samurai's School Techniques for 2 Turns.",
     manual=True)

_add("The Charge of Madness",
     cost=0, limit="skirmish", duration="instant", action="reaction",
     desc="1x/skirmish FA: On reducing target to Out, extra attack vs different target.",
     manual=True)

_add("Bloodied but Unbowed",
     cost=0, limit="skirmish", duration="rounds:2",
     desc="1x/skirmish FA: Damage bonus = Wound TN penalties suffered, lasts 2 Rounds.",
     manual=True)

_add("Epic of My Name",
     cost=0, limit="skirmish", duration="attack",
     requires={"stance": ["full_attack"]},
     desc="1x/skirmish in Full Attack: +4k2 damage with chosen weapon.",
     effects={"dmg_rolled": 4, "dmg_kept": 2})


# ===== CATEGORY 5: FREE ACTION ONLY (no VP) ================================

_add("To Ride the Darkness",
     cost=0, duration="instant",
     desc="FA: Lore: Shadowlands roll to recall creature strength/weakness.",
     manual=True)

_add("The Crab's Shell",
     cost=0, duration="round", action="reaction",
     desc="After melee hit, Guard as FA; add attack excess to charge's ATN.",
     manual=True)

_add("To Tread on the Sword",
     cost=2, duration="instant", action="reaction",
     desc="2VP+FA: Redirect attack from Guard target to self + FA to move toward charge.",
     manual=True)

_add("Spirit of the Falcon",
     cost=0, duration="instant",
     desc="FA: Command falcon to attack enemy.",
     manual=True)

_add("Heart of the Dragon",
     cost=0, duration="attack",
     requires={"weapon": ["katana", "wakizashi"]},
     desc="FA: Third off-hand attack when attacking twice with katana/wakizashi.",
     manual=True)

_add("Inner Fortitude",
     cost="slot", duration="special",
     desc="Spell slot + FA: Reduction 2 and +10 ATN for Earth Ring Rounds.",
     effects={"atn_bonus": 10, "reduction_bonus": 2},
     manual=True)

_add("Strength of the Soul",
     cost="slot", limit="round", duration="attack",
     desc="Spell slot + FA: +1k0 on any Bugei roll (max SR/Round).",
     manual=True)

_add("No Boundaries",
     cost=0, limit="day", duration="skirmish",
     desc="FA: Target SR opponents, +1k0 attack/Contested vs them (SR times/day).",
     effects={"atk_rolled": 1})

_add("Strike Through the Eagle",
     cost=0, duration="instant",
     desc="FA: Ready nage-yari any number of times/Round.",
     manual=True)

_add("Strike With the Soul",
     cost=0, duration="attack",
     requires={"weapon_skill": "spears"},
     desc="FA: One spear ranged attack as Free Action.",
     manual=True)

_add("I Stand with My Brothers",
     cost=0, limit="skirmish", duration="skirmish",
     desc="FA at skirmish start: Battle roll for bonus dice pool.",
     manual=True)

_add("Scion of Strength",
     cost="slot", duration="attack",
     desc="Spell slot + FA: +1k0 to Strength roll/melee damage.",
     effects={"dmg_rolled": 1})

_add("Drunk Loses His Sandal",
     cost=0, duration="instant", action="reaction",
     desc="FA: After enemy attack, become Prone; after Feint, trade 5 damage for +5 ATN.",
     manual=True)

_add("Howl of the Cliff's Edge",
     cost=0, duration="instant",
     desc="FA: Release Entangled opponent.",
     manual=True)

_add("The Charge of the Boar",
     cost=0, duration="instant",
     requires={"stance": ["full_attack"]},
     desc="FA: Ready medium weapon/spear in Full Attack Stance.",
     manual=True)

_add("Beyond the Mountains",
     cost=0, duration="attack",
     requires={"stance": ["full_defense"]},
     desc="FA: One attack with spear/samurai weapon in Full Defense (+2k0).",
     effects={"atk_rolled": 2},
     manual=True)

_add("The Way of the Phoenix",
     cost=0, duration="round",
     desc="FA: Guard action (target gets +5 ATN instead of +10).",
     manual=True)

_add("Unity of Purpose",
     cost=0, duration="round",
     desc="FA after Initiative: Lower Initiative to match ally; +1k0 per ally attacking same foe.",
     manual=True)

_add("Rise to Meet the Challenge",
     cost=0, duration="instant",
     desc="FA: Athletics/Agility TN 20 to stand from Prone.",
     manual=True)

_add("Seeking Weakness",
     cost=0, limit="round", duration="attack",
     desc="FA each Round: One extra attack with Small weapon; ignore opponent's armor.",
     effects={"reduction_ignore": 999},
     manual=True)

_add("I Am A Weapon",
     cost=0, limit="skirmish", duration="special",
     desc="FA (SR times/skirmish): Swap melee weapon skill; melee attacks as Simple Actions.",
     effects={"simple_action_attack": True},
     manual=True)

_add("Dance of the Blade",
     cost=0, limit="round", duration="attack",
     requires={"stance": ["full_defense"]},
     desc="FA in Full Defense: Contested Agility to make successful attack miss (SR times/Round).",
     manual=True)


# ===== CATEGORY 6: DECLARE/TOGGLE (no VP) ==================================

_add("The Wind Blows Many Ways",
     cost=0, limit="skirmish", duration="skirmish",
     desc="At combat start: Declare SR Bugei Skills, +1k0 to all rolls with them.",
     manual=True)

_add("The Tiger's Fangs",
     cost=0, limit="skirmish", duration="round",
     desc="Round 1 only: Maneuvers cost 1 less Raise.",
     manual=True)

_add("Way of the Wardmaster",
     cost=0, duration="attack", action="simple",
     desc="Activate stored Ward spell on target with Simple Action.",
     manual=True)


# ===== CATEGORY 7: SIMPLE / COMPLEX ACTION COST ============================

_add("Blessing of the Emperor",
     cost=0, limit="encounter", duration="instant", action="complex",
     desc="Complex Action (SR times/session): Force cessation of hostilities.",
     manual=True)

_add("Tsuruchi's Eye",
     cost=0, duration="attack", action="complex",
     requires={"weapon_skill": "kyujutsu"},
     desc="Complex Action ranged attack: +4k1 attack and damage.",
     effects={"atk_rolled": 4, "atk_kept": 1, "dmg_rolled": 4, "dmg_kept": 1})

_add("The Ward of Vishnu",
     cost=0, duration="attack", action="simple",
     desc="Simple Action with shield: Contested Defense, opponent needs 3 extra Raises to hit.",
     manual=True)

_add("Vision",
     cost=1, duration="skirmish", action="simple",
     desc="VP+Simple Action: Assess opponent, gain +Xk0 attack (X = lowest Trait) for skirmish.",
     manual=True)

_add("Master of the Dojo",
     cost=1, duration="turn", action="complex",
     desc="VP+Complex: Ally uses one of your Techniques until next Turn.",
     manual=True)

_add("The Ward of the Sea",
     cost="slot", duration="rounds:3", action="complex",
     desc="Complex Action + spell slot: Ship gets Reduction 10 and arrow obstruction for 3 Rounds.",
     manual=True)

_add("Steel Within Silk",
     cost=0, duration="attack", action="complex",
     desc="Complex Action: Make SR shuriken attacks.",
     manual=True)

_add("Wind Never Stops",
     cost=1, duration="attack", action="simple",
     requires={"mounted": True},
     desc="VP+Simple: Mounted charge (movement+attack as one Simple Action), +2k1 damage.",
     effects={"dmg_rolled": 2, "dmg_kept": 1})

_add("Reckless Abandon",
     cost=1, duration="attack", action="simple",
     requires={"stance": ["full_attack"]},
     desc="VP+Simple in Full Attack: Gain Reduction = SR.",
     manual=True)

_add("Strength of Suitengu",
     cost=1, duration="attack", action="complex",
     desc="VP+Complex: Lightning bolt, Air Ring kept damage dice.",
     manual=True)

_add("The Way of Fire",
     cost=0, duration="attack",
     requires={"weapon": "unarmed"},
     desc="Unarmed attack: Suffer Wounds = Fire x2, but base DR becomes 0k[Fire Ring].",
     manual=True)

_add("Stone Turns Steel Aside",
     cost=0, duration="attack",
     requires={"weapon": "unarmed"},
     desc="Contested Jiujutsu to turn enemy's weapon against them.",
     manual=True)

_add("Veil of the Spirits",
     cost=1, duration="special",
     desc="VP while stationary with cover: Add SR kept dice to Stealth. Lasts until movement/noise.",
     manual=True)


# ---------------------------------------------------------------------------
# Lookup helpers
# ---------------------------------------------------------------------------


def known_declarable(technique_names: list[str]) -> list[dict]:
    """Return the CATALOG entries for every technique in the list that has a
    declarable entry.  *technique_names* comes from ``character.techniques``
    (or an NPC's technique list).  Matching uses the same lowering /
    colon-stripping that ``technique_effects._known`` uses."""
    results: list[dict] = []
    seen: set[str] = set()
    for raw in technique_names:
        low = raw.lower().strip().replace("‘", "'").replace("’", "'").rstrip(":").strip()
        candidates = [low]
        colon = low.find(": ")
        if colon > 0:
            candidates.append(low[colon + 2:].strip())
        for key in candidates:
            if key in CATALOG and key not in seen:
                seen.add(key)
                results.append(CATALOG[key])
    return results


def get(name: str) -> dict | None:
    """Look up a technique by display name (case-insensitive)."""
    return CATALOG.get(name.lower().strip().replace("‘", "'").replace("’", "'"))
