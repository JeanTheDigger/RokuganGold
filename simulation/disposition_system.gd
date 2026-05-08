class_name DispositionSystem
## Disposition System per GDD s12.2.
## Core relationship layer: permanent, historical, and temporary modifiers.
## Scale: -100 to +100. Tier thresholds drive NPC behavior.


# -- Tier Constants -----------------------------------------------------------

enum Tier {
	BLOOD_ENEMY,
	ENEMY,
	RIVAL,
	STRANGER,
	ACQUAINTANCE,
	FRIEND,
	TRUSTED_ALLY,
	DEVOTED,
}

const TIER_THRESHOLDS: Array[Array] = [
	[-100, -61, Tier.BLOOD_ENEMY],
	[-60, -31, Tier.ENEMY],
	[-30, -11, Tier.RIVAL],
	[-10, 10, Tier.STRANGER],
	[11, 30, Tier.ACQUAINTANCE],
	[31, 60, Tier.FRIEND],
	[61, 90, Tier.TRUSTED_ALLY],
	[91, 100, Tier.DEVOTED],
]

const TIER_NAMES: Dictionary = {
	Tier.BLOOD_ENEMY: "Blood Enemy",
	Tier.ENEMY: "Enemy",
	Tier.RIVAL: "Rival",
	Tier.STRANGER: "Stranger",
	Tier.ACQUAINTANCE: "Acquaintance",
	Tier.FRIEND: "Friend",
	Tier.TRUSTED_ALLY: "Trusted Ally",
	Tier.DEVOTED: "Devoted",
}


# -- Roll Modifiers (target's disp toward you) --------------------------------

const TARGET_RAISE_MODIFIERS: Dictionary = {
	Tier.BLOOD_ENEMY: 2,
	Tier.ENEMY: 1,
	Tier.RIVAL: 0,
	Tier.STRANGER: 0,
	Tier.ACQUAINTANCE: 0,
	Tier.FRIEND: -1,
	Tier.TRUSTED_ALLY: -2,
	Tier.DEVOTED: -3,
}

# -- Authenticity modifier (your disp toward target, dice kept adjustment) -----

static func get_authenticity_modifier(your_disposition: int, action_is_hostile: bool) -> int:
	if action_is_hostile:
		if your_disposition >= 91:
			return -2
		elif your_disposition >= 31:
			return -1
	else:
		if your_disposition <= -91:
			return -2
		elif your_disposition <= -31:
			return -1
	return 0


# -- Tier Queries -------------------------------------------------------------

static func get_tier(disposition: int) -> Tier:
	if disposition <= -61:
		return Tier.BLOOD_ENEMY
	elif disposition <= -31:
		return Tier.ENEMY
	elif disposition <= -11:
		return Tier.RIVAL
	elif disposition <= 10:
		return Tier.STRANGER
	elif disposition <= 30:
		return Tier.ACQUAINTANCE
	elif disposition <= 60:
		return Tier.FRIEND
	elif disposition <= 90:
		return Tier.TRUSTED_ALLY
	return Tier.DEVOTED


static func get_tier_name(disposition: int) -> String:
	return TIER_NAMES.get(get_tier(disposition), "Unknown")


static func get_raise_modifier(target_disposition: int) -> int:
	return TARGET_RAISE_MODIFIERS.get(get_tier(target_disposition), 0)


# -- Virtue Compatibility (Category 1 — Permanent) ---------------------------

const VIRTUE_COMPATIBILITY: Dictionary = {
	"Jin_Jin": 10, "Jin_Yu": 5, "Jin_Rei": 8, "Jin_Chugi": 5,
	"Jin_Gi": 10, "Jin_Meiyo": 5, "Jin_Makoto": 10,
	"Yu_Yu": 5, "Yu_Rei": -8, "Yu_Chugi": 10, "Yu_Gi": 5,
	"Yu_Meiyo": 12, "Yu_Makoto": 5,
	"Rei_Rei": 8, "Rei_Chugi": 8, "Rei_Gi": 8, "Rei_Meiyo": 8,
	"Rei_Makoto": 10,
	"Chugi_Chugi": 12, "Chugi_Gi": 8, "Chugi_Meiyo": 10, "Chugi_Makoto": 8,
	"Gi_Gi": 12, "Gi_Meiyo": 10, "Gi_Makoto": 15,
	"Meiyo_Meiyo": -5, "Meiyo_Makoto": 10,
	"Makoto_Makoto": 10,

	"Seigyo_Seigyo": -10, "Seigyo_Ketsui": 8, "Seigyo_Dosatsu": 15,
	"Seigyo_Chishiki": 10, "Seigyo_Kanpeki": 8, "Seigyo_Kyoryoku": -5,
	"Seigyo_Ishi": -8,
	"Ketsui_Ketsui": 10, "Ketsui_Dosatsu": -5, "Ketsui_Chishiki": -5,
	"Ketsui_Kanpeki": 5, "Ketsui_Kyoryoku": 15, "Ketsui_Ishi": 12,
	"Dosatsu_Dosatsu": -8, "Dosatsu_Chishiki": 12, "Dosatsu_Kanpeki": 5,
	"Dosatsu_Kyoryoku": -8, "Dosatsu_Ishi": -5,
	"Chishiki_Chishiki": -5, "Chishiki_Kanpeki": 10, "Chishiki_Kyoryoku": -5,
	"Chishiki_Ishi": 5,
	"Kanpeki_Kanpeki": -12, "Kanpeki_Kyoryoku": -8, "Kanpeki_Ishi": 5,
	"Kyoryoku_Kyoryoku": 5, "Kyoryoku_Ishi": 10,
	"Ishi_Ishi": -10,

	"Jin_Seigyo": -15, "Jin_Ketsui": 5, "Jin_Dosatsu": 5,
	"Jin_Chishiki": 8, "Jin_Kanpeki": 0, "Jin_Kyoryoku": -5, "Jin_Ishi": -8,
	"Yu_Seigyo": -10, "Yu_Ketsui": 15, "Yu_Dosatsu": -5,
	"Yu_Chishiki": -5, "Yu_Kanpeki": -8, "Yu_Kyoryoku": 20, "Yu_Ishi": 8,
	"Rei_Seigyo": -12, "Rei_Ketsui": 0, "Rei_Dosatsu": 8,
	"Rei_Chishiki": 5, "Rei_Kanpeki": 15, "Rei_Kyoryoku": -10, "Rei_Ishi": -5,
	"Chugi_Seigyo": -8, "Chugi_Ketsui": 12, "Chugi_Dosatsu": 0,
	"Chugi_Chishiki": 5, "Chugi_Kanpeki": 5, "Chugi_Kyoryoku": 10, "Chugi_Ishi": 15,
	"Gi_Seigyo": -20, "Gi_Ketsui": 5, "Gi_Dosatsu": -10,
	"Gi_Chishiki": 8, "Gi_Kanpeki": 10, "Gi_Kyoryoku": 5, "Gi_Ishi": 8,
	"Meiyo_Seigyo": -15, "Meiyo_Ketsui": 8, "Meiyo_Dosatsu": -8,
	"Meiyo_Chishiki": 5, "Meiyo_Kanpeki": 12, "Meiyo_Kyoryoku": 10, "Meiyo_Ishi": 5,
	"Makoto_Seigyo": -20, "Makoto_Ketsui": 8, "Makoto_Dosatsu": -12,
	"Makoto_Chishiki": 5, "Makoto_Kanpeki": 8, "Makoto_Kyoryoku": 5, "Makoto_Ishi": 10,
}

static func get_virtue_pair_modifier(virtue_a: String, virtue_b: String) -> int:
	var key1: String = virtue_a + "_" + virtue_b
	if VIRTUE_COMPATIBILITY.has(key1):
		return VIRTUE_COMPATIBILITY[key1]
	var key2: String = virtue_b + "_" + virtue_a
	if VIRTUE_COMPATIBILITY.has(key2):
		return VIRTUE_COMPATIBILITY[key2]
	return 0


static func compute_permanent_modifier(
	bushido_a: Enums.BushidoVirtue,
	shourido_a: Enums.ShouridoVirtue,
	bushido_b: Enums.BushidoVirtue,
	shourido_b: Enums.ShouridoVirtue,
) -> int:
	var total: int = 0
	var virtues_a: Array[String] = []
	var virtues_b: Array[String] = []

	if bushido_a != Enums.BushidoVirtue.NONE:
		virtues_a.append(Enums.bushido_virtue_name(bushido_a))
	if shourido_a != Enums.ShouridoVirtue.NONE:
		virtues_a.append(Enums.shourido_virtue_name(shourido_a))
	if bushido_b != Enums.BushidoVirtue.NONE:
		virtues_b.append(Enums.bushido_virtue_name(bushido_b))
	if shourido_b != Enums.ShouridoVirtue.NONE:
		virtues_b.append(Enums.shourido_virtue_name(shourido_b))

	for va in virtues_a:
		for vb in virtues_b:
			total += get_virtue_pair_modifier(va, vb)
	return total


# -- Historical Modifiers (Category 2) ---------------------------------------

const HISTORICAL_EVENTS: Dictionary = {
	"saved_life": {"start": 20, "floor": 10, "decay": true},
	"life_saved_by": {"start": 20, "floor": 10, "decay": true},
	"same_battle_same_side": {"start": 10, "floor": 5, "decay": true},
	"same_battle_opposite": {"start": -10, "floor": -3, "decay": true},
	"killed_family_member": {"start": -50, "floor": -50, "decay": false},
	"same_dojo": {"start": 8, "floor": 4, "decay": true},
	"same_sensei": {"start": 10, "floor": 5, "decay": true},
	"same_delegation": {"start": 6, "floor": 3, "decay": true},
	"witnessed_performance": {"start": 3, "floor": 1, "decay": true},
	"shared_victory": {"start": 12, "floor": 6, "decay": true},
	"shared_defeat": {"start": 8, "floor": 4, "decay": true},
	"families_married": {"start": 8, "floor": 4, "decay": false},
	"publicly_praised": {"start": 8, "floor": 4, "decay": true},
	"praised_by_you": {"start": 6, "floor": 3, "decay": true},
	"publicly_humiliated": {"start": -15, "floor": -8, "decay": true},
	"humiliated_by_you": {"start": -12, "floor": -6, "decay": true},
	"politically_betrayed": {"start": -25, "floor": -15, "decay": true},
	"reneged_commitment": {"start": -15, "floor": -10, "decay": true},
	"revealed_secret": {"start": -20, "floor": -15, "decay": true},
	"fabricated_secret": {"start": -25, "floor": -25, "decay": false},
	"favor_honored": {"start": 10, "floor": 5, "decay": true},
	"won_duel_survived": {"start": -8, "floor": -3, "decay": true},
	"lost_duel_survived": {"start": 5, "floor": 2, "decay": true},
	"yielded_to_you": {"start": 3, "floor": 1, "decay": true},
	"you_yielded": {"start": -5, "floor": -2, "decay": true},
	"destroyed_province": {"start": -20, "floor": -15, "decay": true},
	"harmed_hostage": {"start": -30, "floor": -30, "decay": false},
	"took_hostage": {"start": -5, "floor": -3, "decay": true},
	"taken_hostage": {"start": -5, "floor": -3, "decay": true},
	"hostage_escape": {"start": -15, "floor": -15, "decay": false},
	"destroyed_harvest": {"start": -20, "floor": -20, "decay": false},
	"witnessed_harvest_destruction": {"start": -10, "floor": -5, "decay": true},
}

const FAMILY_BONDS: Dictionary = {
	"sibling": 20,
	"parent_child": 20,
	"grandparent_grandchild": 12,
	"first_cousin": 6,
	"cross_clan_marriage": 4,
}

const DECAY_RATE: float = 0.1


static func create_historical_modifier(event_type: String, created_ic_day: int) -> Dictionary:
	var template: Dictionary = HISTORICAL_EVENTS.get(event_type, {})
	if template.is_empty():
		return {}
	return {
		"event_type": event_type,
		"current_value": template["start"],
		"floor": template["floor"],
		"decays": template["decay"],
		"created_ic_day": created_ic_day,
	}


static func decay_historical_modifier(modifier: Dictionary, days_elapsed: int) -> void:
	if not modifier.get("decays", true):
		return
	var start_val: int = modifier["current_value"]
	var floor_val: int = modifier["floor"]
	if start_val > floor_val:
		var decay_amount: int = days_elapsed / 10
		modifier["current_value"] = max(floor_val, start_val - decay_amount)
	elif start_val < floor_val:
		var decay_amount: int = days_elapsed / 10
		modifier["current_value"] = min(floor_val, start_val + decay_amount)


# -- Temporary Modifiers (Category 3) ----------------------------------------

const TEMPORARY_EVENTS: Dictionary = {
	"at_war": {"value": -15, "duration": -1},
	"same_court": {"value": 3, "duration": 30},
	"letter_received": {"value": 1, "duration": 10},
	"fine_letter": {"value": 3, "duration": 15},
	"gift_normal": {"value": 3, "duration": 30},
	"gift_fine": {"value": 5, "duration": 45},
	"gift_exceptional": {"value": 8, "duration": 60},
	"gift_masterwork": {"value": 12, "duration": 90},
	"favor_performed": {"value": 5, "duration": 45},
	"private_insult": {"value": -5, "duration": 30},
	"discovered_lie": {"value": -10, "duration": 90},
	"gift_obligation": {"value": -2, "duration": -1},
	"hosting_guest": {"value": 2, "duration": -1},
	"fought_alongside": {"value": 5, "duration": 45},
}


static func create_temporary_modifier(event_type: String, created_ic_day: int) -> Dictionary:
	var template: Dictionary = TEMPORARY_EVENTS.get(event_type, {})
	if template.is_empty():
		return {}
	var mod: Dictionary = {
		"event_type": event_type,
		"value": template["value"],
		"created_ic_day": created_ic_day,
		"duration": template["duration"],
	}
	return mod


static func is_temporary_expired(modifier: Dictionary, current_ic_day: int) -> bool:
	var duration: int = modifier.get("duration", -1)
	if duration < 0:
		return false
	return (current_ic_day - modifier.get("created_ic_day", 0)) >= duration


# -- Death of Mutual Friend (Category 2 — dynamic) ---------------------------

static func create_death_mutual_friend_modifier(
	disp_a_toward_deceased: int,
	disp_b_toward_deceased: int,
	created_ic_day: int,
) -> Dictionary:
	var avg_disp: int = (disp_a_toward_deceased + disp_b_toward_deceased) / 2
	var start_val: int = mini(avg_disp / 10, 10)
	var floor_val: int = start_val / 2
	return {
		"event_type": "death_mutual_friend",
		"current_value": start_val,
		"floor": floor_val,
		"decays": true,
		"created_ic_day": created_ic_day,
	}


# -- Cohabitation -------------------------------------------------------------

const COHABITATION_RATE: float = 0.1


static func compute_cohabitation_bonus(days_cohabiting: int) -> float:
	return float(days_cohabiting) * COHABITATION_RATE


# -- Disposition Change Values (Court Actions) --------------------------------

const ACTION_DISPOSITION: Dictionary = {
	"CHARM": {"success": 8, "per_raise": 3, "critical_failure": -5},
	"NEGOTIATE": {"success": 9, "per_raise": 3, "critical_failure": -6},
	"IMPRESS": {"success": 9, "per_raise": 3, "critical_failure": -6},
	"PERSUADE": {"success": 11, "per_raise": 3, "critical_failure": -7},
	"LISTEN_REFLECT": {"success": 11, "per_raise": 3, "critical_failure": -7},
	"INTIMIDATE": {"success": 0, "per_raise": 3, "critical_failure": -8},
	"PERFORM_FOR": {"success": 10, "per_raise": 3, "critical_failure": -4},
}

const BROADCAST_DISPOSITION: Dictionary = {
	"per_witness_success": 2,
	"per_raise_per_witness": 1,
	"per_witness_critical_failure": -2,
}

const GIFT_DISPOSITION: Dictionary = {
	"normal": 3,
	"fine": 5,
	"exceptional": 8,
	"masterwork": 12,
	"legendary": 12,
}


# -- Effective Disposition (with permanent modifiers) ------------------------

# Returns actor's disposition toward target_id with the permanent
# biological-family bond layered on top (s22.6). The stored
# disposition_values entry represents accumulated event-driven disposition;
# family bonds are added at read time so they never decay and can never go
# stale relative to the family graph.
#
# Pass chars_by_id={} (the default) to skip family-bond computation entirely
# — the function then degrades to a plain disposition_values lookup.
static func get_effective_disposition(
	actor: L5RCharacterData,
	target_id: int,
	chars_by_id: Dictionary = {},
) -> int:
	if actor == null or target_id < 0:
		return 0
	var stored: int = actor.disposition_values.get(target_id, 0)
	if chars_by_id.is_empty():
		return clampi(stored, -100, 100)
	var target: L5RCharacterData = chars_by_id.get(target_id)
	if target == null:
		return clampi(stored, -100, 100)
	var family_bond: int = BiologicalFamily.compute_pairwise_modifier(
		actor, target, chars_by_id
	)
	return clampi(stored + family_bond, -100, 100)


# -- Supply Sharing -----------------------------------------------------------

static func get_supply_share_ratio(disposition: int) -> float:
	if disposition >= 61:
		return 1.0
	elif disposition >= 31:
		var ratio: float = float(disposition - 31) / 29.0
		return 0.5 + (ratio * 0.5)
	return 0.0


static func will_share_supplies(disposition: int) -> bool:
	return disposition >= 31


# -- Composite Disposition Calculation ----------------------------------------

static func compute_total_disposition(
	permanent: int,
	historical_modifiers: Array,
	temporary_modifiers: Array,
	cohabitation_bonus: float = 0.0,
) -> int:
	var total: float = float(permanent) + cohabitation_bonus
	for mod in historical_modifiers:
		if mod is Dictionary:
			total += mod.get("current_value", 0)
	for mod in temporary_modifiers:
		if mod is Dictionary:
			total += mod.get("value", 0)
	return clampi(int(total), -100, 100)


# -- Family/Clan Ripple -------------------------------------------------------

const FAMILY_RIPPLE: int = 2
const CLAN_RIPPLE: int = 1
const FAMILY_RIPPLE_CAP: int = 30
const CLAN_RIPPLE_CAP: int = 15


# -- Information Sharing Thresholds -------------------------------------------

enum InfoSharingTier {
	SHARES_NOTHING,
	SHARES_NEUTRAL,
	SHARES_RELEVANT,
	SHARES_SENSITIVE,
}

static func get_info_sharing_tier(disposition: int) -> InfoSharingTier:
	if disposition >= 61:
		return InfoSharingTier.SHARES_SENSITIVE
	elif disposition >= 31:
		return InfoSharingTier.SHARES_RELEVANT
	elif disposition >= -10:
		return InfoSharingTier.SHARES_NEUTRAL
	return InfoSharingTier.SHARES_NOTHING


static func will_share_topic(disposition: int, topic_is_sensitive: bool) -> bool:
	var tier: InfoSharingTier = get_info_sharing_tier(disposition)
	if topic_is_sensitive:
		return tier == InfoSharingTier.SHARES_SENSITIVE
	return tier >= InfoSharingTier.SHARES_NEUTRAL


static func may_deliberately_mislead(disposition: int) -> bool:
	return disposition <= -11
