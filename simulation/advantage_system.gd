class_name AdvantageSystem
## GDD s45 — Advantages and Disadvantages.
## Pure query and effect layer. No dice rolls; callers supply context dicts.
##
## Context dict keys (all optional; unrecognised keys are silently ignored):
##   "is_contested"         bool   — this roll is part of a contested check
##   "is_school_skill"      bool   — skill is in the character's school list
##   "is_social"            bool   — Etiquette / Courtier / Sincerity / Temptation
##   "is_voice_perform"     bool   — Perform roll using voice (Singing, Oratory)
##   "is_memory"            bool   — remembering something exactly (PRECISE_MEMORY)
##   "is_stealth"           bool   — any Stealth roll
##   "is_ambush_detection"  bool   — Investigation(Notice)/Perception vs ambush
##   "is_spell_casting"     bool   — casting a spell
##   "spell_type"           String — "sense", "commune", "summon" for FRIENDLY_KAMI
##   "element"              Enums.Ring — element of spell / ring roll
##   "is_ring_roll"         bool   — pure Trait/Ring roll (no skill)
##   "is_resist_temptation" bool   — resisting a Temptation roll
##   "is_resist_intimidation" bool — resisting Intimidation
##   "is_resist_fear"       bool   — resisting a Fear effect
##   "is_vs_persuasion"     bool   — HEARTLESS: being target of Courtier/Sin/Temp
##   "honor_rank_adding"    bool   — roll adds Honor Rank (BALANCE fires here)
##   "attacker_gender_matches" bool — for DANGEROUS_BEAUTY / LECHERY
##   "opponent_clan"        String — clan of the other character (contested)
##   "opponent_family"      String — family of the other character
##   "opponent_is_shugenja" bool
##   "opponent_is_artisan"  bool
##   "opponent_is_imperial" bool
##   "opponent_is_naga"     bool
##   "opponent_id"          int    — character_id of opponent
##   "is_resist_manipulation" bool — CLEAR_THINKER: opponent confusing/manipulating
##   "is_calligraphy"       bool   — Calligraphy skill roll (IMPERIAL_SCRIBE FR)
##   "is_athletics"         bool   — Athletics roll (DAREDEVIL)
##   "is_void_spend"        bool   — spending Void on this roll (DAREDEVIL, TOUCH_OF_VOID)
##   "is_unarmed_damage"    bool   — HANDS_OF_STONE
##   "is_weapon_skill"      bool   — CRAB_HANDS unskilled gate
##   "is_low_skill"         bool   — CRAFTY unskilled gate (Low Skills)
##   "is_lore_skill"        bool   — SAGE unskilled gate
##   "is_perform_skill"     bool   — SENSATION unskilled gate
##   "is_artisan_skill"     bool   — SOUL_OF_ARTISTRY
##   "is_craft_skill"       bool   — SOUL_OF_ARTISTRY
##   "is_detecting_intentions" bool — SHADOWED_HEART: opponent reading your intent
##   "is_navigation"        bool   — Navigation emphasis roll (WANDERER)
##   "situation_tags"       Array  — tags matching phobia/compulsion triggers
##   "lost_love_clan"       String — clan/family being interacted with (LOST_LOVE)
##   "lost_love_province_id" int   — province_id being entered (LOST_LOVE)
##   "is_debate"            bool   — public debate in progress (CONTRARY)
##   "max_glory_rank"       float  — highest Glory Rank of debate participants
##   "debater_direction"    int    — +1 or -1 position direction (CONTRARY NPC)

# ---------------------------------------------------------------------------
# Query helpers
# ---------------------------------------------------------------------------

static func has_advantage(character: L5RCharacterData, type: Enums.Advantage) -> bool:
	for adv: AdvantageData in character.advantages:
		if adv.advantage_type == type:
			return true
	return false


static func get_advantage(character: L5RCharacterData, type: Enums.Advantage) -> AdvantageData:
	for adv: AdvantageData in character.advantages:
		if adv.advantage_type == type:
			return adv
	return null


static func has_disadvantage(character: L5RCharacterData, type: Enums.Disadvantage) -> bool:
	for dis: DisadvantageData in character.disadvantages:
		if dis.disadvantage_type == type:
			return true
	return false


static func get_disadvantage(character: L5RCharacterData, type: Enums.Disadvantage) -> DisadvantageData:
	for dis: DisadvantageData in character.disadvantages:
		if dis.disadvantage_type == type:
			return dis
	return null


# ---------------------------------------------------------------------------
# Skill-roll bonus aggregator
# Returns {rolled: int, kept: int, free_raises: int}.
# Callers add returned values to their bonus_rolled / bonus_kept / flat_bonus.
# ---------------------------------------------------------------------------

static func get_skill_bonus(
	character: L5RCharacterData,
	skill_name: String,
	context: Dictionary,
) -> Dictionary:
	var rolled: int = 0
	var kept: int = 0
	var free_raises: int = 0

	for adv: AdvantageData in character.advantages:
		match adv.advantage_type:

			Enums.Advantage.BALANCE:
				# +1k0 resist Temptation/Intimidation when adding Honor Rank
				if (context.get("is_resist_temptation", false) or context.get("is_resist_intimidation", false)) \
						and context.get("honor_rank_adding", false):
					rolled += 1

			Enums.Advantage.CHOSEN_BY_THE_ORACLES:
				# +1k1 to all Ring Rolls using the chosen Ring
				if context.get("is_ring_roll", false):
					var chosen: int = adv.metadata.get("ring", Enums.Ring.NONE)
					if chosen != Enums.Ring.NONE and context.get("element", Enums.Ring.NONE) == chosen:
						kept += 1

			Enums.Advantage.CLEAR_THINKER:
				# +1k0 Contested Rolls when opponent is confusing/manipulating you
				if context.get("is_contested", false) and context.get("is_resist_manipulation", false):
					rolled += 1

			Enums.Advantage.CRAB_HANDS:
				# Unskilled Weapon Skill treated as Rank 1 — no die bonus, handled via unskilled_rank
				pass

			Enums.Advantage.CRAFTY:
				# Unskilled Low Skill treated as Rank 1 — handled via unskilled_rank
				pass

			Enums.Advantage.DANGEROUS_BEAUTY:
				# +1k0 to Temptation rolls against this character by matching-gender attacker.
				# Applied to the ATTACKER, not here. See get_target_temptation_bonus().
				pass

			Enums.Advantage.DAREDEVIL:
				# +3k1 instead of normal +1k1 when spending Void on Athletics.
				# Net advantage: +2k0 on top of normal (the +1k1 normal is already in the pool).
				if context.get("is_athletics", false) and context.get("is_void_spend", false):
					rolled += 2

			Enums.Advantage.FRIEND_OF_THE_ELEMENTS:
				# Free Raise whenever making a Trait Roll with either Trait of chosen Ring
				if context.get("is_ring_roll", false):
					var ring: int = adv.metadata.get("ring", Enums.Ring.NONE)
					if ring != Enums.Ring.NONE and context.get("element", Enums.Ring.NONE) == ring:
						free_raises += 1

			Enums.Advantage.FRIENDLY_KAMI:
				# +1k1 to Spell Casting for Sense/Commune/Summon of chosen element. Shugenja only.
				if context.get("is_spell_casting", false):
					var elem: int = adv.metadata.get("element", Enums.Ring.NONE)
					var stype: String = context.get("spell_type", "")
					if elem != Enums.Ring.NONE \
							and context.get("element", Enums.Ring.NONE) == elem \
							and stype in ["sense", "commune", "summon"]:
						kept += 1

			Enums.Advantage.HANDS_OF_STONE:
				# +0k1 to unarmed Damage Rolls
				if context.get("is_unarmed_damage", false):
					kept += 1

			Enums.Advantage.HEART_OF_VENGEANCE:
				# +1k1 Contested Rolls against chosen Clan/faction
				if context.get("is_contested", false):
					var target_clan: String = context.get("opponent_clan", "")
					var chosen_clan: String = adv.metadata.get("clan", "")
					if chosen_clan != "" and target_clan == chosen_clan:
						kept += 1

			Enums.Advantage.HEARTLESS:
				# +1k0 to rolls resisting Courtier/Sincerity/Temptation to persuade/seduce/change mind
				if context.get("is_vs_persuasion", false):
					rolled += 1

			Enums.Advantage.IMPERIAL_SCRIBE:
				# +1k0 Social vs shugenja and artisans; Free Raise on all Calligraphy
				if context.get("is_social", false) \
						and (context.get("opponent_is_shugenja", false) or context.get("opponent_is_artisan", false)):
					rolled += 1
				if context.get("is_calligraphy", false):
					free_raises += 1

			Enums.Advantage.IMPERIAL_SPOUSE:
				# +1k1 Social Skill Rolls with Imperial families
				if context.get("is_social", false) and context.get("opponent_is_imperial", false):
					kept += 1

			Enums.Advantage.IRREPROACHABLE:
				# +1k0 to rolls resisting Temptation
				if context.get("is_resist_temptation", false):
					rolled += 1

			Enums.Advantage.NAGA_ANCESTRY:
				# +1k0 Social Skill Rolls with Naga
				if context.get("is_social", false) and context.get("opponent_is_naga", false):
					rolled += 1

			Enums.Advantage.PARAGON:
				# Various bonuses by Bushido virtue. Only simulation-relevant tiers.
				var virtue: String = adv.metadata.get("virtue", "")
				match virtue:
					"Courage":
						# +1k1 to resist Intimidation or Fear
						if context.get("is_resist_intimidation", false) or context.get("is_resist_fear", false):
							kept += 1
					"Courtesy":
						# +2k0 on Etiquette to avoid embarrassment
						if skill_name == "Etiquette":
							rolled += 2
					"Honesty":
						# +1k1 on Sincerity (Honesty)
						if skill_name == "Sincerity" and context.get("is_honest", false):
							kept += 1
					"Honor":
						# Add twice Honor Rank to resist Temptation/Intimidation.
						# Honor Rank is already added by callers; this doubles it.
						# Implemented as a flat bonus per the character's honor_rank.
						if context.get("is_resist_temptation", false) or context.get("is_resist_intimidation", false):
							var hr: int = int(character.honor)
							rolled += hr  # effectively doubles the honor rank bonus
					"Sincerity":
						# +2k0 to all Contested Sincerity rolls
						if skill_name == "Sincerity" and context.get("is_contested", false):
							rolled += 2
					"Compassion":
						# +2k2 when spending Void to help lower-Status — handled by Void system
						pass
					"Duty":
						# Void Point negates all TN/Wound penalties on one roll — handled by Void system
						pass

			Enums.Advantage.PRECISE_MEMORY:
				# +1k1 Intelligence Trait Rolls when remembering
				if context.get("is_memory", false):
					kept += 1

			Enums.Advantage.PRODIGY:
				# +1k0 to all School Skill Rolls
				if context.get("is_school_skill", false):
					rolled += 1

			Enums.Advantage.REINCARNATED:
				# +1k0 to three chosen non-School Skills
				var skills: Array = adv.metadata.get("skills", [])
				if skill_name in skills:
					rolled += 1

			Enums.Advantage.SAGE:
				# Unskilled Lore Skill = Rank 1 — handled via unskilled_rank
				pass

			Enums.Advantage.SAGE_OF_SWORD_AND_FAN:
				# Use higher of Battle/Courtier rank on Contested rolls (up to Insight Rank/day).
				# Structural — executor must set context; we provide the query helper.
				pass

			Enums.Advantage.SENSATION:
				# Unskilled Perform = Rank 1 — handled via unskilled_rank
				pass

			Enums.Advantage.SEVEN_FORTUNES_BLESSING:
				var fortune: String = adv.metadata.get("fortune", "")
				match fortune:
					"Benten":
						# +0k1 Social for persuasion (not coercion)
						if context.get("is_social", false) and not context.get("is_coercion", false):
							kept += 1
					"Bishamon":
						# +1k0 Strength Trait Rolls
						if context.get("is_ring_roll", false) and context.get("element", Enums.Ring.NONE) == Enums.Ring.WATER:
							rolled += 1  # Strength is Water trait
					"Daikoku":
						# +1k1 Commerce Skill Rolls
						if skill_name == "Commerce":
							kept += 1
					"Ebisu":
						# +1k1 Social with non-samurai Rokugani
						if context.get("is_social", false) and context.get("opponent_is_commoner", false):
							kept += 1
					"Fukurokujin":
						# +1k1 to chosen Lore Skill
						var lore_skill: String = adv.metadata.get("skill", "")
						if skill_name == lore_skill:
							kept += 1
					"Jurojin":
						# +2k0 to resist disease or poison (handled by relevant systems)
						pass

			Enums.Advantage.SILENT:
				# +1k0 to all Stealth rolls
				if context.get("is_stealth", false) or skill_name == "Stealth":
					rolled += 1

			Enums.Advantage.SOUL_OF_ARTISTRY:
				# Unskilled Artisan/Craft = Rank 1 — handled via unskilled_rank
				pass

			Enums.Advantage.STOLEN_IDENTITY:
				# Two Free Raises on Acting rolls when using alternate identity
				if skill_name == "Acting" and context.get("using_alternate_identity", false):
					free_raises += 2

			Enums.Advantage.STUDENT_OF_SHOURIDO:
				# May add +5 instead of Honor Rank to resist Temptation/Intimidation/Fear.
				# Not a die bonus — changes how the bonus is computed. Handled in callers.
				pass

			Enums.Advantage.TOUCH_OF_THE_SPIRIT_REALMS:
				var realm: String = adv.metadata.get("realm", "")
				match realm:
					"Chikushudo":
						if skill_name == "Animal Handling":
							kept += 1
					"Jigoku":
						# Add Taint Rank to attack and Physical Trait rolls
						if context.get("is_combat", false) or (context.get("is_ring_roll", false) and context.get("is_physical_trait", false)):
							rolled += int(character.taint)
					"Meido":
						# +2k0 Contested Rolls vs social manipulation
						if context.get("is_contested", false) and context.get("is_resist_manipulation", false):
							rolled += 2
					"Sakkaku":
						# +1k1 Sincerity (Deceit)
						if skill_name == "Sincerity" and context.get("is_deceit", false):
							kept += 1
					"Tengoku":
						# +2k0 Earth Ring Rolls to resist Taint
						if context.get("element", Enums.Ring.NONE) == Enums.Ring.EARTH and context.get("is_resist_taint", false):
							rolled += 2
					"Yomi":
						# +1k0 to one chosen School Skill
						var yomi_skill: String = adv.metadata.get("skill", "")
						if skill_name == yomi_skill and context.get("is_school_skill", false):
							rolled += 1

			Enums.Advantage.VOICE:
				# +1k1 to any Perform Skill Roll using voice
				if context.get("is_voice_perform", false):
					kept += 1

			Enums.Advantage.WARY:
				# +1k1 to Investigation (Notice)/Perception rolls to detect ambush
				if context.get("is_ambush_detection", false):
					kept += 1

			Enums.Advantage.WATANU_TRAINED:
				# +1k1 to chosen Craft Skill for metallic goods
				var w_skill: String = adv.metadata.get("skill", "")
				if skill_name == w_skill:
					kept += 1

			Enums.Advantage.GREAT_POTENTIAL:
				# Raises limited by Skill Rank rather than Void Ring — not a die bonus.
				# Executor must enforce this when computing max raises.
				pass

	return {"rolled": rolled, "kept": kept, "free_raises": free_raises}


# ---------------------------------------------------------------------------
# TN modifier from disadvantages/advantages that raise or lower the TN.
# Returns int: positive = harder (TN increases), negative = easier.
# ---------------------------------------------------------------------------

static func get_tn_modifier(
	character: L5RCharacterData,
	context: Dictionary,
) -> int:
	var mod: int = 0

	for dis: DisadvantageData in character.disadvantages:
		match dis.disadvantage_type:

			Enums.Disadvantage.ANACHRONISM:
				if context.get("is_artisan_skill", false) or context.get("is_craft_skill", false) \
						or context.get("is_social", false):
					mod += 5

			Enums.Disadvantage.DISBELIEVER:
				if context.get("opponent_is_shugenja", false) or context.get("opponent_is_monk", false):
					if context.get("is_social", false):
						mod += 5

			Enums.Disadvantage.DISTURBING_COUNTENANCE:
				if context.get("is_social", false):
					mod += 5

			Enums.Disadvantage.FAILURE_OF_BUSHIDO:
				var virtue: String = dis.metadata.get("virtue", "")
				match virtue:
					"Courtesy":
						# Must call one no-effect Raise on Social apology/avoid-offense rolls
						# Represented as +5 effective TN (equivalent to one wasted Raise)
						if context.get("is_social_apology", false) or context.get("is_avoid_offense", false):
							mod += 5
					"Sincerity":
						# Must call one no-effect Raise on Sincerity conviction rolls
						if skill_name_from_context(context) == "Sincerity" and context.get("is_conviction", false):
							mod += 5
					"Courage":
						# +5 TN vs higher Glory/Status or Shadowlands opponents
						if context.get("opponent_higher_glory", false) or context.get("opponent_is_shadowlands", false):
							mod += 5
					"Honor":
						# Cannot add Honor Rank to resist Intimidation/Temptation.
						# Handled at caller; not a TN change.
						pass

			Enums.Disadvantage.LAME:
				# +10 TN on Agility rolls involving lower limbs
				if context.get("is_leg_agility_roll", false):
					mod += 10

			Enums.Disadvantage.MISSING_LIMB:
				# +10 TN on tasks involving the missing limb
				if context.get("involves_missing_limb", false):
					mod += 10

			Enums.Disadvantage.PHOBIA:
				# +5 per rank of the Disadvantage when in a tagged situation
				var tags: Array = dis.metadata.get("situation_tags", [])
				var sit_tags: Array = context.get("situation_tags", [])
				for tag: String in tags:
					if tag in sit_tags:
						mod += 5 * dis.rank
						break

			Enums.Disadvantage.SHADOWED_HEART:
				# Applied to the ATTACKER trying to read you, not your own roll.
				# See get_target_detection_tn_bonus().
				pass

			Enums.Disadvantage.WANDERER:
				if context.get("is_navigation", false):
					mod += 15

			Enums.Disadvantage.MEMBER_OF_CHRYSANTHEMUM_COURT:
				# The +Status-loss mechanic is situational — handled by court system.
				pass

	for adv: AdvantageData in character.advantages:
		match adv.advantage_type:
			Enums.Advantage.BLAND:
				# May voluntarily increase TN to identify you by +10.
				# Applied on request in context["bland_active"] = true.
				if context.get("bland_active", false):
					mod += 10  # negative: harder to be identified (benefit to self)

	return mod


# Convenience helper used internally
static func skill_name_from_context(ctx: Dictionary) -> String:
	return ctx.get("skill_name", "")


# ---------------------------------------------------------------------------
# TN bonus on rolls made TO detect this character's intentions / identity.
# Returns int: how much the attacker's TN is increased.
# Used by callers who are rolling social-read skills against this character.
# ---------------------------------------------------------------------------

static func get_target_detection_tn_bonus(target: L5RCharacterData) -> int:
	var bonus: int = 0
	if has_advantage(target, Enums.Advantage.SHADOWED_HEART):
		bonus += 5
	return bonus


# ---------------------------------------------------------------------------
# Bonus to ATTACKER's Temptation roll because of this TARGET's advantages.
# Handles DANGEROUS_BEAUTY.
# ---------------------------------------------------------------------------

static func get_target_temptation_bonus(target: L5RCharacterData, attacker_gender_matches: bool) -> int:
	if attacker_gender_matches and has_advantage(target, Enums.Advantage.DANGEROUS_BEAUTY):
		return 1  # +1k0 rolled
	return 0


# ---------------------------------------------------------------------------
# Bonus/penalty to attacker's LECHERY / GREEDY / GULLIBLE / FRAIL_MIND rolls.
# Returns {rolled: int, kept: int} bonus for the ATTACKER when targeting this char.
# ---------------------------------------------------------------------------

static func get_attacker_bonus_from_target(
	target: L5RCharacterData,
	skill_name: String,
	context: Dictionary,
) -> Dictionary:
	var rolled: int = 0
	var kept: int = 0

	for dis: DisadvantageData in target.disadvantages:
		match dis.disadvantage_type:

			Enums.Disadvantage.GULLIBLE:
				# Sincerity (Deceit) opponents gain +1k1
				if skill_name == "Sincerity" and context.get("is_deceit", false):
					kept += 1

			Enums.Disadvantage.GREEDY:
				# Temptation (Bribery) opponents gain +1k1
				if skill_name == "Temptation" and context.get("is_bribery", false):
					kept += 1

			Enums.Disadvantage.LECHERY:
				# Temptation (Seduction) opponents +1k0 if gender matches
				if skill_name == "Temptation" and context.get("is_seduction", false) \
						and context.get("attacker_gender_matches", false):
					rolled += 1

			Enums.Disadvantage.FRAIL_MIND:
				# Opponents gain +2k0 in Willpower Contested Rolls
				if context.get("is_contested", false) and context.get("is_willpower_contest", false):
					rolled += 2

	return {"rolled": rolled, "kept": kept}


# ---------------------------------------------------------------------------
# Wound TN modifier (added on top of the normal wound penalty when wounded).
# Returns int: positive = less painful, negative = more painful.
# ---------------------------------------------------------------------------

static func get_wound_tn_modifier(character: L5RCharacterData) -> int:
	var mod: int = 0
	if has_advantage(character, Enums.Advantage.STRENGTH_OF_THE_EARTH):
		mod += 3
	if has_disadvantage(character, Enums.Disadvantage.LOW_PAIN_THRESHOLD):
		mod -= 5
	return mod


# ---------------------------------------------------------------------------
# Magic resistance: returns additional TN that must be overcome by spells
# targeting this character. Only elemental spells (not maho or gaijin).
# ---------------------------------------------------------------------------

static func get_magic_resistance_tn(character: L5RCharacterData) -> int:
	var adv: AdvantageData = get_advantage(character, Enums.Advantage.MAGIC_RESISTANCE)
	if adv != null:
		return adv.rank * 3
	return 0


# ---------------------------------------------------------------------------
# Unskilled rank bonus: returns 1 if character should be treated as Rank 1
# when rolling this skill unskilled, 0 otherwise.
# ---------------------------------------------------------------------------

static func get_unskilled_rank_bonus(character: L5RCharacterData, skill_name: String, context: Dictionary) -> int:
	for adv: AdvantageData in character.advantages:
		match adv.advantage_type:
			Enums.Advantage.CRAB_HANDS:
				if context.get("is_weapon_skill", false):
					return 1
			Enums.Advantage.CRAFTY:
				if context.get("is_low_skill", false):
					return 1
			Enums.Advantage.SAGE:
				if context.get("is_lore_skill", false) or skill_name.begins_with("Lore"):
					return 1
			Enums.Advantage.SENSATION:
				if context.get("is_perform_skill", false) or skill_name.begins_with("Perform"):
					return 1
			Enums.Advantage.SOUL_OF_ARTISTRY:
				if context.get("is_artisan_skill", false) or context.get("is_craft_skill", false) \
						or skill_name.begins_with("Artisan") or skill_name.begins_with("Craft"):
					return 1
	return 0


# ---------------------------------------------------------------------------
# Trait modifier: returns adjustment to a specific trait value.
# Positive = higher effective trait, negative = lower.
# ---------------------------------------------------------------------------

static func get_trait_modifier(character: L5RCharacterData, trait_type: Enums.Trait, context: Dictionary) -> int:
	var mod: int = 0

	for dis: DisadvantageData in character.disadvantages:
		match dis.disadvantage_type:

			Enums.Disadvantage.WEAKNESS:
				var weak_trait: int = dis.metadata.get("trait", Enums.Trait.NONE)
				if weak_trait == trait_type:
					mod -= 1

			Enums.Disadvantage.BAD_HEALTH:
				# Earth Ring Traits considered 1 lower for Wound Ranks and disease resistance.
				# Only applies to Stamina/Willpower in the wound/disease context.
				if (trait_type == Enums.Trait.STAMINA or trait_type == Enums.Trait.WILLPOWER) \
						and context.get("is_wound_check", false):
					mod -= 1

			Enums.Disadvantage.LAME:
				# Water Ring = 1 for Move Actions
				if (trait_type == Enums.Trait.STRENGTH or trait_type == Enums.Trait.PERCEPTION) \
						and context.get("is_move_action", false):
					# Clamp to 1 is applied by the caller; we return the required delta.
					mod -= maxf(0.0, character.get_trait_value(trait_type) - 1.0)
					mod = int(mod)

			Enums.Disadvantage.SMALL:
				# Water Ring considered 1 lower for Move Action distance
				if (trait_type == Enums.Trait.STRENGTH or trait_type == Enums.Trait.PERCEPTION) \
						and context.get("is_move_action", false):
					mod -= 1

			Enums.Disadvantage.BLIND:
				# Water Ring 2 lower for Move Actions
				if (trait_type == Enums.Trait.STRENGTH or trait_type == Enums.Trait.PERCEPTION) \
						and context.get("is_move_action", false):
					mod -= 2

	return mod


# ---------------------------------------------------------------------------
# SMALL disadvantage: melee damage penalty (-1k0)
# ---------------------------------------------------------------------------

static func get_melee_damage_penalty(character: L5RCharacterData) -> int:
	if has_disadvantage(character, Enums.Disadvantage.SMALL):
		return -1  # -1k0 rolled dice on damage
	return 0


# ---------------------------------------------------------------------------
# QUICK_HEALER: Stamina considered 2 ranks higher for wound recovery.
# Returns the bonus Stamina ranks for healing purposes.
# ---------------------------------------------------------------------------

static func get_healing_stamina_bonus(character: L5RCharacterData) -> int:
	if has_advantage(character, Enums.Advantage.QUICK_HEALER):
		return 2
	return 0


# ---------------------------------------------------------------------------
# PERMANENT_WOUND: first wound rank always full.
# Returns true if the first wound box is always considered occupied.
# ---------------------------------------------------------------------------

static func has_permanent_wound(character: L5RCharacterData) -> bool:
	return has_disadvantage(character, Enums.Disadvantage.PERMANENT_WOUND)


# ---------------------------------------------------------------------------
# IDEALISTIC: Honor losses increased by 1 point.
# ---------------------------------------------------------------------------

static func get_honor_loss_increase(character: L5RCharacterData) -> float:
	if has_disadvantage(character, Enums.Disadvantage.IDEALISTIC):
		return 1.0
	return 0.0


# ---------------------------------------------------------------------------
# MOMOKU: cannot spend Void Points on non-Technique things.
# Returns true if the Void spend should be blocked.
# ---------------------------------------------------------------------------

static func is_void_spend_blocked(character: L5RCharacterData, context: Dictionary) -> bool:
	if not has_disadvantage(character, Enums.Disadvantage.MOMOKU):
		return false
	# Allowed if spending on a School Technique that requires Void
	return not context.get("is_technique_void_spend", false)


# ---------------------------------------------------------------------------
# TOUCH_OF_THE_VOID: +2k1 instead of +1k1 when spending Void on a roll.
# Returns the extra kept dice (on top of the normal +1k1 = 1 kept).
# The roll also requires Willpower TN 30 or Dazed — checked separately.
# ---------------------------------------------------------------------------

static func get_void_spend_bonus(character: L5RCharacterData) -> Dictionary:
	if has_advantage(character, Enums.Advantage.TOUCH_OF_THE_SPIRIT_REALMS):
		var adv: AdvantageData = get_advantage(character, Enums.Advantage.TOUCH_OF_THE_SPIRIT_REALMS)
		if adv != null and adv.metadata.get("realm", "") == "Yume-do":
			pass  # Yume-do is rest recovery, not a roll bonus
	if has_advantage(character, Enums.Advantage.TOUCH_OF_THE_VOID):
		return {"extra_kept": 1}  # +2k1 total vs normal +1k1
	return {"extra_kept": 0}


static func needs_void_dazed_check(character: L5RCharacterData) -> bool:
	return has_advantage(character, Enums.Advantage.TOUCH_OF_THE_VOID)


# ---------------------------------------------------------------------------
# SACROSANCT: characters with Honor 5+ may not attack this character unless
# attacked first.  Returns true if NPC should skip violence against this char.
# ---------------------------------------------------------------------------

static func is_sacrosanct(character: L5RCharacterData) -> bool:
	if not has_advantage(character, Enums.Advantage.SACROSANCT):
		return false
	return character.honor >= 6.0


# ---------------------------------------------------------------------------
# Behavioral triggers
# ---------------------------------------------------------------------------

## COMPULSION: returns {triggered: bool, tn: int}.
## Caller rolls Willpower vs TN; on failure action is consumed.
static func check_compulsion_trigger(character: L5RCharacterData, location_tags: Array) -> Dictionary:
	var dis: DisadvantageData = get_disadvantage(character, Enums.Disadvantage.COMPULSION)
	if dis == null:
		return {"triggered": false, "tn": 0}
	var subject_tags: Array = dis.metadata.get("location_tags", [])
	for tag: String in subject_tags:
		if tag in location_tags:
			var tn: int = 15 + (dis.rank - 1) * 5
			return {"triggered": true, "tn": tn}
	return {"triggered": false, "tn": 0}


## CONTRARY: returns {triggered: bool, tn: int}.
## Caller rolls Willpower vs TN; on failure NPC declares position publicly.
static func check_contrary_trigger(character: L5RCharacterData, max_glory_rank: float) -> Dictionary:
	if not has_disadvantage(character, Enums.Disadvantage.CONTRARY):
		return {"triggered": false, "tn": 0}
	var tn: int = int(5.0 * max_glory_rank)
	return {"triggered": true, "tn": tn}


## LOST_LOVE: returns {triggered: bool, tiers_used: int}.
## Returns triggered=true if the interaction context matches the lost love's
## clan/family or the death-province. On trigger, all TNs +5 until Void spent.
## Cannot trigger more than twice per IC day; at least 1 hour between instances.
static func check_lost_love_trigger(
	character: L5RCharacterData,
	context: Dictionary,
	ic_day: int,
) -> Dictionary:
	var dis: DisadvantageData = get_disadvantage(character, Enums.Disadvantage.LOST_LOVE)
	if dis == null:
		return {"triggered": false}

	var triggers_today: int = dis.metadata.get("triggers_today", 0)
	var last_trigger_day: int = dis.metadata.get("last_trigger_ic_day", -1)
	if last_trigger_day != ic_day:
		triggers_today = 0

	if triggers_today >= 2:
		return {"triggered": false}

	var love_clan: String = dis.metadata.get("clan", "")
	var love_family: String = dis.metadata.get("family", "")
	var death_province: int = dis.metadata.get("province_id", -1)

	var ctx_clan: String = context.get("lost_love_clan", "")
	var ctx_family: String = context.get("lost_love_family", "")
	var ctx_province: int = context.get("lost_love_province_id", -1)

	var triggered: bool = false
	if love_clan != "" and ctx_clan == love_clan:
		triggered = true
	if love_family != "" and ctx_family == love_family:
		triggered = true
	if death_province >= 0 and ctx_province == death_province:
		triggered = true

	return {"triggered": triggered, "tn_penalty": 5 if triggered else 0}


## PHOBIA: returns {active: bool, tn_penalty: int}.
static func check_phobia_trigger(character: L5RCharacterData, situation_tags: Array) -> Dictionary:
	var dis: DisadvantageData = get_disadvantage(character, Enums.Disadvantage.PHOBIA)
	if dis == null:
		return {"active": false, "tn_penalty": 0}
	var phobia_tags: Array = dis.metadata.get("situation_tags", [])
	for tag: String in phobia_tags:
		if tag in situation_tags:
			return {"active": true, "tn_penalty": 5 * dis.rank}
	return {"active": false, "tn_penalty": 0}


## RUMORMONGER: returns {triggered: bool, tn: int}.
## Caller rolls Willpower vs TN; on failure NPC spreads the rumor.
static func check_rumormonger_trigger(character: L5RCharacterData, max_glory_rank: float) -> Dictionary:
	if not has_disadvantage(character, Enums.Disadvantage.RUMORMONGER):
		return {"triggered": false, "tn": 0}
	var tn: int = int(5.0 * max_glory_rank)
	return {"triggered": true, "tn": tn}


## TRUE_LOVE: returns {void_cost_required: bool}.
## If the pending action would negatively affect the lover, Void must be spent.
## If no Void Points remain, action cannot be taken this tick.
static func check_true_love_constraint(
	character: L5RCharacterData,
	action_harms_lover: bool,
) -> Dictionary:
	if not has_disadvantage(character, Enums.Disadvantage.TRUE_LOVE):
		return {"void_cost_required": false}
	if action_harms_lover:
		return {"void_cost_required": true}
	return {"void_cost_required": false}


## DARK_PARAGON: would activating it (retroactively) change the outcome?
## Returns {should_activate: bool}.
## The engine calls this after computing roll result; NPC spends if beneficial.
static func check_dark_paragon_activation(
	character: L5RCharacterData,
	roll_total: int,
	tn: int,
	precept: String,
) -> Dictionary:
	var adv: AdvantageData = get_advantage(character, Enums.Advantage.DARK_PARAGON)
	if adv == null:
		return {"should_activate": false}
	var char_precept: String = adv.metadata.get("precept", "")
	if char_precept != precept:
		return {"should_activate": false}
	# Activate if +5 bonus would turn a miss into a hit
	var would_succeed: bool = (roll_total + 5) >= tn and roll_total < tn
	# Or if Will/Determination would prevent death
	var is_survival_precept: bool = (precept == "Will" or precept == "Determination")
	return {"should_activate": would_succeed or is_survival_precept}


## BRASH: returns {triggered: bool, tn: int}.
## Caller rolls Willpower + Honor Rank vs TN; on failure NPC attacks immediately.
static func check_brash_trigger(character: L5RCharacterData, was_threatened_or_insulted: bool) -> Dictionary:
	if not has_disadvantage(character, Enums.Disadvantage.BRASH):
		return {"triggered": false, "tn": 0}
	if was_threatened_or_insulted:
		return {"triggered": true, "tn": 25}
	return {"triggered": false, "tn": 0}


## CANT_LIE: returns {triggered: bool, tn: int}.
## If someone tells a lie the character knows is false, Willpower TN 20 to stay quiet.
static func check_cant_lie_trigger(character: L5RCharacterData, lie_detected: bool) -> Dictionary:
	if not has_disadvantage(character, Enums.Disadvantage.CANT_LIE):
		return {"triggered": false, "tn": 0}
	if lie_detected:
		return {"triggered": true, "tn": 20}
	return {"triggered": false, "tn": 0}


## SOFT_HEARTED: returns {triggered: bool, tn: int}.
## Must roll Willpower TN 20 before killing a human; if failing while killing, +10 TN all day.
static func check_soft_hearted_trigger(character: L5RCharacterData, would_kill_human: bool) -> Dictionary:
	if not has_disadvantage(character, Enums.Disadvantage.SOFT_HEARTED):
		return {"triggered": false, "tn": 0}
	if would_kill_human:
		return {"triggered": true, "tn": 20}
	return {"triggered": false, "tn": 0}


## EPILEPSY: returns {triggered: bool, tn: int}.
## High stress or flashing lights trigger a Willpower TN 15 roll.
static func check_epilepsy_trigger(character: L5RCharacterData, high_stress: bool) -> Dictionary:
	if not has_disadvantage(character, Enums.Disadvantage.EPILEPSY):
		return {"triggered": false, "tn": 0}
	if high_stress:
		return {"triggered": true, "tn": 15}
	return {"triggered": false, "tn": 0}


## ELEMENTAL_IMBALANCE: returns {triggered: bool, tn: int, element: int}.
## Fires when casting a spell of the character's imbalanced element.
static func check_elemental_imbalance_trigger(
	character: L5RCharacterData,
	cast_element: int,
) -> Dictionary:
	var dis: DisadvantageData = get_disadvantage(character, Enums.Disadvantage.ELEMENTAL_IMBALANCE)
	if dis == null:
		return {"triggered": false, "tn": 0}
	var imb_elem: int = dis.metadata.get("element", Enums.Ring.NONE)
	if imb_elem != Enums.Ring.NONE and cast_element == imb_elem:
		var tn: int = 15 + (dis.rank - 1) * 5
		return {"triggered": true, "tn": tn, "element": cast_element}
	return {"triggered": false, "tn": 0}


## OVERCONFIDENT: returns {triggered: bool, tn: int}.
## Must succeed at Perception TN 20 to recognize an unwinnable situation and withdraw.
static func check_overconfident_trigger(
	character: L5RCharacterData,
	is_outnumbered: bool,
) -> Dictionary:
	if not has_disadvantage(character, Enums.Disadvantage.OVERCONFIDENT):
		return {"triggered": false, "tn": 0}
	if is_outnumbered:
		return {"triggered": true, "tn": 20}
	return {"triggered": false, "tn": 0}


# ---------------------------------------------------------------------------
# WRATH_OF_THE_KAMI: returns the Free Raise bonus granted to a spellcaster
# targeting this character with the marked element.
# ---------------------------------------------------------------------------

static func get_wrath_of_kami_bonus(target: L5RCharacterData, spell_element: int) -> int:
	var dis: DisadvantageData = get_disadvantage(target, Enums.Disadvantage.WRATH_OF_THE_KAMI)
	if dis == null:
		return 0
	var marked_elem: int = dis.metadata.get("element", Enums.Ring.NONE)
	if marked_elem != Enums.Ring.NONE and spell_element == marked_elem:
		return 1  # +1 Free Raise on Spell Casting Roll
	return 0


# ---------------------------------------------------------------------------
# SPY NETWORK helpers
# ---------------------------------------------------------------------------

## Returns the NPC's chosen focus dict or {} if no focus set.
static func get_spy_network_focus(character: L5RCharacterData) -> Dictionary:
	var adv: AdvantageData = get_advantage(character, Enums.Advantage.SPY_NETWORK)
	if adv == null:
		return {}
	return {
		"focus_type": adv.metadata.get("focus_type", ""),
		"focus_id": adv.metadata.get("focus_id", -1),
	}


## Sets the NPC's spy network focus. focus_type: "character", "place", "army".
static func set_spy_network_focus(
	character: L5RCharacterData,
	focus_type: String,
	focus_id: int,
	ooc_day: int,
) -> void:
	var adv: AdvantageData = get_advantage(character, Enums.Advantage.SPY_NETWORK)
	if adv == null:
		return
	adv.metadata["focus_type"] = focus_type
	adv.metadata["focus_id"] = focus_id
	adv.metadata["last_update_ooc_day"] = ooc_day


# ---------------------------------------------------------------------------
# WELL_CONNECTED helpers
# ---------------------------------------------------------------------------

## Returns list of settlement_ids where this character is well-connected.
static func get_well_connected_courts(character: L5RCharacterData) -> Array:
	var result: Array = []
	for adv: AdvantageData in character.advantages:
		if adv.advantage_type == Enums.Advantage.WELL_CONNECTED:
			var sid: int = adv.metadata.get("settlement_id", -1)
			if sid >= 0:
				result.append(sid)
	return result


# ---------------------------------------------------------------------------
# World generation — derive advantages/disadvantages from existing world state.
# Only derives entries that can be determined from confirmed data.
# ---------------------------------------------------------------------------

static func assign_derived_advantages(
	character: L5RCharacterData,
	active_hostages: Array,
	chars_by_id: Dictionary,
) -> void:
	# ISHIKEN_DO — assigned to Isawa Ishiken school characters
	if character.school == "Isawa Ishiken":
		if not has_advantage(character, Enums.Advantage.ISHIKEN_DO):
			var adv: AdvantageData = AdvantageData.new()
			adv.advantage_type = Enums.Advantage.ISHIKEN_DO
			character.advantages.append(adv)

	# FAME — assigned if glory >= 2.0 at world start
	if character.glory >= 2.0 and not has_advantage(character, Enums.Advantage.FAME):
		var adv: AdvantageData = AdvantageData.new()
		adv.advantage_type = Enums.Advantage.FAME
		character.advantages.append(adv)

	# SHADOWLANDS_TAINT — assigned if character has taint > 0
	if character.taint > 0.0 and not has_disadvantage(character, Enums.Disadvantage.SHADOWLANDS_TAINT):
		var dis: DisadvantageData = DisadvantageData.new()
		dis.disadvantage_type = Enums.Disadvantage.SHADOWLANDS_TAINT
		character.disadvantages.append(dis)

	# HOSTAGE — assigned if character appears in active_hostages as hostage_id
	for h: Dictionary in active_hostages:
		if h.get("hostage_id", -1) == character.character_id:
			if not has_disadvantage(character, Enums.Disadvantage.HOSTAGE):
				var dis: DisadvantageData = DisadvantageData.new()
				dis.disadvantage_type = Enums.Disadvantage.HOSTAGE
				character.disadvantages.append(dis)
			break

	# DISHONORED — assigned if character has role_position = "" and honor < 1.0
	if character.honor < 1.0 and character.role_position == "" and character.lord_id >= 0:
		if not has_disadvantage(character, Enums.Disadvantage.DISHONORED):
			var dis: DisadvantageData = DisadvantageData.new()
			dis.disadvantage_type = Enums.Disadvantage.DISHONORED
			character.disadvantages.append(dis)

	# SOCIAL_DISADVANTAGE — assigned if status < 0.5 (start with Status 0 per GDD)
	if character.status < 0.5 and not has_disadvantage(character, Enums.Disadvantage.SOCIAL_DISADVANTAGE):
		var dis: DisadvantageData = DisadvantageData.new()
		dis.disadvantage_type = Enums.Disadvantage.SOCIAL_DISADVANTAGE
		character.disadvantages.append(dis)
