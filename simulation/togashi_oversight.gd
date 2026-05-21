class_name TogashiOversight
## Dragon Clan governance exception per GDD s55.10.2.
##
## Implements the Togashi Oversight Check that runs alongside the
## Mirumoto Family Champion's delegated Strategic Evaluation. The Kami
## Togashi monitors four cosmic axes (Balance, Imperial Cohesion,
## Spiritual Health, Shadowlands Containment), accumulates dissatisfaction
## when the Mirumoto FC's strategic priorities don't address active
## concerns, and forces directives when an axis crosses threshold.
##
## Pure simulation class — no Node inheritance, no scene tree.
##
## State is held in a plain Dictionary owned by the caller, shaped:
##   {
##     "dissatisfaction": { Axis -> float },   # 0.0..100.0+
##     "active_forced_directives": Array[Dictionary],
##     "defiance_count": int,                  # 0..4 (Stage 1..4)
##     "stage": int,                            # 0=clear, 1..4 escalation
##     "last_directive_axis": int,              # Axis of the last forced directive (-1 if none)
##   }


# -- Axes --------------------------------------------------------------------

enum Axis {
	BALANCE_OF_POWER,
	IMPERIAL_COHESION,
	SPIRITUAL_HEALTH,
	SHADOWLANDS_CONTAINMENT,
}


# -- PROVISIONAL constants per GDD s55.10.2 ----------------------------------

const DISSATISFACTION_THRESHOLD: float = 50.0
const DISSATISFACTION_RESET_AFTER_COMPLY: float = 30.0
const DISSATISFACTION_LIFT_BELOW: float = 20.0   # Forced directive lifts here.
const DECAY_NO_CONCERN: float = 10.0
const DECAY_ALIGNED: float = 5.0
const INCREMENT_NOT_ALIGNED: float = 15.0

# Concern thresholds
const BALANCE_DOMINANCE_RATIO: float = 0.30      # +30% over second-strongest
const REBELLION_THRESHOLD: int = 5
const FAILING_WORSHIP_PROVINCES: int = 10
const REALM_OVERLAPS_EMPIRE_WIDE: int = 3
const PTL_OUTSIDE_SHADOWLANDS_THRESHOLD: float = 3.0
const CRAB_READINESS_THRESHOLD: float = 0.50

# Compliance evaluation
const REPEATED_LETTER_MEIYO_BONUS: int = 5

# Escalation stage constants
const STAGE_DIPLOMATIC_PENALTY: int = -5         # Stage 2+ diplomatic credibility


# -- State factory -----------------------------------------------------------

static func make_initial_state() -> Dictionary:
	return {
		"dissatisfaction": {
			Axis.BALANCE_OF_POWER: 0.0,
			Axis.IMPERIAL_COHESION: 0.0,
			Axis.SPIRITUAL_HEALTH: 0.0,
			Axis.SHADOWLANDS_CONTAINMENT: 0.0,
		},
		"active_forced_directives": [],
		"defiance_count": 0,
		"stage": 0,
		"last_directive_axis": -1,
		# High House assault state (s55.10.2.8).
		"togashi_vanished": false,
		"order_dissolved_by_assault": false,
		"order_reconstitution_seasons_remaining": 0,
		"dragon_autonomous_rule": false,
	}


static func initialize_from_world_state(
	state: Dictionary,
	world_state: Dictionary,
) -> void:
	## Seeds dissatisfaction from the starting world state rather than 0.
	## Call once at game start after make_initial_state().
	for axis: int in [
		Axis.BALANCE_OF_POWER,
		Axis.IMPERIAL_COHESION,
		Axis.SPIRITUAL_HEALTH,
		Axis.SHADOWLANDS_CONTAINMENT,
	]:
		var fires: bool = axis_concern_fires(axis, world_state)
		if fires:
			state["dissatisfaction"][axis] = DISSATISFACTION_THRESHOLD * 0.5


# -- Concern checks (s55.10.2.3) ---------------------------------------------
#
# world_state shape (caller responsibility):
#   "clan_strengths": Dictionary[String -> float]    # combined power index per clan
#   "active_inter_clan_wars": int
#   "emperor_vacant": bool
#   "provinces_in_rebellion": int
#   "failing_worship_provinces": int
#   "realm_overlaps_empire_wide": int
#   "realm_overlap_in_dragon_territory": bool
#   "max_non_shadowlands_ptl": float
#   "wall_breach_active": bool
#   "shadowlands_incursion_tier": int                # 0=none, 1=minor, 2+ concern
#   "crab_military_readiness": float                 # 0.0..1.0

static func balance_concern_fires(world_state: Dictionary) -> bool:
	var strengths: Dictionary = world_state.get("clan_strengths", {})
	if strengths.size() < 2:
		return false
	var sorted_values: Array = strengths.values().duplicate()
	sorted_values.sort()
	var top: float = float(sorted_values[sorted_values.size() - 1])
	var second: float = float(sorted_values[sorted_values.size() - 2])
	if second <= 0.0:
		return top > 0.0
	return ((top - second) / second) > BALANCE_DOMINANCE_RATIO


static func imperial_cohesion_concern_fires(world_state: Dictionary) -> bool:
	if int(world_state.get("active_inter_clan_wars", 0)) >= 2:
		return true
	if bool(world_state.get("emperor_vacant", false)):
		return true
	if int(world_state.get("provinces_in_rebellion", 0)) > REBELLION_THRESHOLD:
		return true
	return false


static func spiritual_health_concern_fires(world_state: Dictionary) -> bool:
	if int(world_state.get("failing_worship_provinces", 0)) >= FAILING_WORSHIP_PROVINCES:
		return true
	if bool(world_state.get("realm_overlap_in_dragon_territory", false)):
		return true
	if int(world_state.get("realm_overlaps_empire_wide", 0)) >= REALM_OVERLAPS_EMPIRE_WIDE:
		return true
	if float(world_state.get("max_non_shadowlands_ptl", 0.0)) > PTL_OUTSIDE_SHADOWLANDS_THRESHOLD:
		return true
	return false


static func shadowlands_concern_fires(world_state: Dictionary) -> bool:
	if bool(world_state.get("wall_breach_active", false)):
		return true
	if int(world_state.get("shadowlands_incursion_tier", 0)) >= 2:
		return true
	if float(world_state.get("crab_military_readiness", 1.0)) < CRAB_READINESS_THRESHOLD:
		return true
	return false


static func axis_concern_fires(axis: Axis, world_state: Dictionary) -> bool:
	match axis:
		Axis.BALANCE_OF_POWER:
			return balance_concern_fires(world_state)
		Axis.IMPERIAL_COHESION:
			return imperial_cohesion_concern_fires(world_state)
		Axis.SPIRITUAL_HEALTH:
			return spiritual_health_concern_fires(world_state)
		Axis.SHADOWLANDS_CONTAINMENT:
			return shadowlands_concern_fires(world_state)
	return false


# -- Alignment check ---------------------------------------------------------
#
# strategic_directives is the array produced by the Mirumoto FC's
# StrategicReview.run_seasonal_review. Each directive is a dict with a
# "directive" enum value and various target fields. Alignment is a
# heuristic match per s55.10.2.4 Step 2.

static func is_directive_aligned(axis: Axis, directives: Array) -> bool:
	for d: Dictionary in directives:
		if not (d is Dictionary):
			continue
		if d.get("forced_by_champion", false):
			# Don't credit Togashi's own forced directive as alignment —
			# alignment must come from the FC's own conclusions.
			continue
		var dtype: int = int(d.get("directive", -1))
		match axis:
			Axis.BALANCE_OF_POWER:
				# Treat war-readiness or seek-peace targeting as engagement
				# with the dominant clan. War-readiness is a defensive posture
				# against a rising threat; seek-peace can de-escalate one too.
				if dtype == StrategicReview.Directive.WAR_READINESS:
					return true
				if dtype == StrategicReview.Directive.SEEK_PEACE:
					return true
			Axis.IMPERIAL_COHESION:
				# Seek-peace, calling court (signaling stability), or
				# war-readiness when responding to rebellion all engage.
				if dtype == StrategicReview.Directive.SEEK_PEACE:
					return true
				if dtype == StrategicReview.Directive.CALL_COURT:
					return true
				if dtype == StrategicReview.Directive.WAR_READINESS:
					return true
			Axis.SPIRITUAL_HEALTH:
				# No purification/worship-targeted directive in the existing
				# StrategicReview enum. The FC has no native way to address
				# spiritual concerns through standard directives — alignment
				# only via custom "spiritual_response" directives explicitly
				# tagged.
				if d.get("addresses_spiritual", false):
					return true
			Axis.SHADOWLANDS_CONTAINMENT:
				# Same gap — explicit tag on the directive.
				if d.get("addresses_shadowlands", false):
					return true
	return false


# -- Per-season tick ---------------------------------------------------------

static func tick_oversight(
	state: Dictionary,
	world_state: Dictionary,
	strategic_directives: Array,
) -> Dictionary:
	## Updates dissatisfaction across all four axes, returns information
	## about any threshold crossing this season.
	##
	## Result shape:
	##   {
	##     "axes_triggered": Array[Axis],        # all axes >= threshold
	##     "primary_axis": int,                   # highest-dissatisfaction triggered axis (-1 if none)
	##     "primary_dissatisfaction": float,
	##   }
	var dissatisfaction: Dictionary = state["dissatisfaction"]
	for axis: int in [
		Axis.BALANCE_OF_POWER,
		Axis.IMPERIAL_COHESION,
		Axis.SPIRITUAL_HEALTH,
		Axis.SHADOWLANDS_CONTAINMENT,
	]:
		var current: float = float(dissatisfaction.get(axis, 0.0))
		if not axis_concern_fires(axis, world_state):
			current = maxf(0.0, current - DECAY_NO_CONCERN)
		elif is_directive_aligned(axis, strategic_directives):
			current = maxf(0.0, current - DECAY_ALIGNED)
		else:
			current = current + INCREMENT_NOT_ALIGNED
		dissatisfaction[axis] = current

	# Identify triggered axes and the primary one.
	var triggered: Array = []
	var primary_axis: int = -1
	var primary_value: float = 0.0
	for axis: int in dissatisfaction:
		var v: float = float(dissatisfaction[axis])
		if v >= DISSATISFACTION_THRESHOLD:
			triggered.append(axis)
			if v > primary_value:
				primary_value = v
				primary_axis = axis

	return {
		"axes_triggered": triggered,
		"primary_axis": primary_axis,
		"primary_dissatisfaction": primary_value,
	}


# -- Forced directive generation (s55.10.2.5) -------------------------------

static func generate_forced_directive(axis: Axis) -> Dictionary:
	## Produces a directive dict tagged forced_by_champion=true. Shape mirrors
	## StrategicReview directive output so it can be merged into the FC's
	## clan_strategic_priorities array.
	var directive_type: int = StrategicReview.Directive.NO_CHANGE
	var description: String = ""
	match axis:
		Axis.BALANCE_OF_POWER:
			directive_type = StrategicReview.Directive.WAR_READINESS
			description = "Counter the dominant clan — rebalance the Empire."
		Axis.IMPERIAL_COHESION:
			directive_type = StrategicReview.Directive.SEEK_PEACE
			description = "Heal the fractures — end the wars dividing the Empire."
		Axis.SPIRITUAL_HEALTH:
			directive_type = StrategicReview.Directive.NO_CHANGE
			description = "Address the spiritual failure in Dragon territory."
		Axis.SHADOWLANDS_CONTAINMENT:
			directive_type = StrategicReview.Directive.WAR_READINESS
			description = "Support Crab defense of the Wall."

	return {
		"directive": directive_type,
		"forced_by_champion": true,
		"axis": axis,
		"description": description,
		"addresses_spiritual": axis == Axis.SPIRITUAL_HEALTH,
		"addresses_shadowlands": axis == Axis.SHADOWLANDS_CONTAINMENT,
	}


# -- Compliance evaluation (s55.10.2.5) --------------------------------------

static func evaluate_compliance(
	mirumoto_fc: L5RCharacterData,
	forced_directive: Dictionary,
	togashi_id: int,
	repeated_letter: bool = false,
	conflict_modifier: int = 0,
) -> Dictionary:
	## Computes comply vs defy scores per s55.10.2.5 Step 3.
	## Returns { comply: bool, comply_score: int, defy_score: int }.
	if mirumoto_fc == null:
		return {"comply": false, "comply_score": 0, "defy_score": 0}

	var comply: int = 0
	# Chugi (Duty) and Rei (Courtesy) on the comply side.
	if mirumoto_fc.bushido_virtue == Enums.BushidoVirtue.CHUGI:
		comply += 10
	if mirumoto_fc.bushido_virtue == Enums.BushidoVirtue.REI:
		comply += 5
	# Disposition toward Togashi adds directly (clamped to ±20).
	if togashi_id >= 0:
		var disp: int = int(mirumoto_fc.disposition_values.get(togashi_id, 0))
		comply += clampi(disp, -20, 20)
	if repeated_letter:
		comply += REPEATED_LETTER_MEIYO_BONUS
		# Plus an extra Meiyo nudge if the FC carries the Honor virtue.
		if mirumoto_fc.bushido_virtue == Enums.BushidoVirtue.MEIYO:
			comply += 5

	var defy: int = 0
	# Ishi (Will) and Ketsui (Determination) on the defy side.
	if mirumoto_fc.shourido_virtue == Enums.ShouridoVirtue.ISHI:
		defy += 10
	if mirumoto_fc.shourido_virtue == Enums.ShouridoVirtue.KETSUI:
		defy += 8
	# Conflict modifier (caller supplies based on objective overlap, 0..20).
	defy += clampi(conflict_modifier, 0, 20)

	return {
		"comply": comply >= defy,
		"comply_score": comply,
		"defy_score": defy,
	}


# -- Defiance / compliance state transitions (s55.10.2.6) -------------------

static func handle_compliance_response(state: Dictionary, axis: Axis) -> void:
	## Called when the Mirumoto FC complies with a forced directive.
	## - Resets dissatisfaction on the triggering axis to 30 (problem still
	##   exists; just being addressed).
	## - Adds the forced directive to active_forced_directives (caller does
	##   the actual injection into clan_strategic_priorities).
	## - Reduces escalation stage by 1 toward 0 (trust rebuilds gradually).
	state["dissatisfaction"][axis] = DISSATISFACTION_RESET_AFTER_COMPLY
	state["last_directive_axis"] = axis
	state["stage"] = maxi(state.get("stage", 0) - 1, 0)
	# defiance_count is cumulative and never decremented (s55.10.2.6)


static func handle_defiance(state: Dictionary, axis: Axis) -> void:
	## Mirumoto FC defied a forced directive.
	## - defiance_count increments (cumulative across all axes per §6).
	## - stage is set to defiance_count, capped at 4.
	## - Dissatisfaction on the axis keeps climbing (caller's tick will
	##   continue to raise it).
	var dc: int = int(state.get("defiance_count", 0)) + 1
	state["defiance_count"] = dc
	state["stage"] = mini(dc, 4)
	state["last_directive_axis"] = axis


# -- Authority lockout (s55.10.2.6 Stage 2+) --------------------------------

static func is_authority_locked(state: Dictionary) -> bool:
	return int(state.get("stage", 0)) >= 2


static func is_order_withdrawn(state: Dictionary) -> bool:
	## Stage 3: Wandering Togashi recalled, tattoo ceremonies suspended,
	## bushi-shugenja synergy lost.
	return int(state.get("stage", 0)) >= 3


static func is_removal_triggered(state: Dictionary) -> bool:
	## Stage 4: Togashi formally removes the Mirumoto FC. The standard
	## succession system handles the rest (deferred — see s22.5).
	return int(state.get("stage", 0)) >= 4


# -- Diplomatic credibility modifier (Stage 2+) -----------------------------

static func get_diplomatic_credibility_modifier(state: Dictionary) -> int:
	if is_authority_locked(state):
		return STAGE_DIPLOMATIC_PENALTY
	return 0


# -- Forced directive lifecycle ---------------------------------------------

static func should_lift_forced_directive(
	state: Dictionary,
	axis: Axis,
) -> bool:
	## Forced directive persists until dissatisfaction drops below 20.
	var current: float = float(state["dissatisfaction"].get(axis, 0.0))
	return current < DISSATISFACTION_LIFT_BELOW


static func remove_forced_directive(state: Dictionary, axis: Axis) -> void:
	var actives: Array = state.get("active_forced_directives", [])
	var kept: Array = []
	for d: Dictionary in actives:
		if int(d.get("axis", -1)) != axis:
			kept.append(d)
	state["active_forced_directives"] = kept


static func _has_active_directive_on_axis(state: Dictionary, axis: Axis) -> bool:
	for d: Dictionary in state.get("active_forced_directives", []):
		if int(d.get("axis", -1)) == axis:
			return true
	return false


static func add_forced_directive(state: Dictionary, directive: Dictionary) -> void:
	var actives: Array = state.get("active_forced_directives", [])
	# Replace any existing directive on the same axis (only one per axis at a time).
	var kept: Array = []
	for d: Dictionary in actives:
		if int(d.get("axis", -1)) != int(directive.get("axis", -1)):
			kept.append(d)
	kept.append(directive)
	state["active_forced_directives"] = kept


# -- High House of Light assault (s55.10.2.8) --------------------------------
#
# Called when the Mirumoto FC's army successfully takes the High House of Light
# during a Dragon Schism. Togashi cannot be killed; he vanishes instead.
#
# Returns a result dict. Caller is responsible for:
#   - Applying honor_change to the FC.
#   - Applying empire_disposition_change to all clan collective dispositions.
#   - Adding the returned topic to active_topics.
#
# togashi_character is mutated directly: physical_location is cleared.

static func assault_high_house(
	state: Dictionary,
	togashi_character: L5RCharacterData,
	next_topic_id: int,
	ic_day: int,
	assaulting_fc_id: int = -1,
) -> Dictionary:
	## Fires when the FC's army captures the High House of Light.
	state["togashi_vanished"] = true
	state["order_dissolved_by_assault"] = true
	state["last_assaulter_fc_id"] = assaulting_fc_id

	if togashi_character != null:
		togashi_character.physical_location = ""

	var topic := TopicData.new()
	topic.topic_id = next_topic_id
	topic.slug = "togashi_vanished_y%d" % ic_day
	topic.tier = TopicData.Tier.TIER_1
	topic.momentum = 100.0
	topic.category = TopicData.Category.SUPERNATURAL
	topic.ic_day_created = ic_day

	return {
		"honor_change": -2.0,
		"empire_disposition_change": -20,
		"topic": topic,
		"togashi_vanished": true,
	}


static func is_togashi_off_map(state: Dictionary) -> bool:
	return bool(state.get("togashi_vanished", false))


static func is_order_dissolved_by_assault(state: Dictionary) -> bool:
	return bool(state.get("order_dissolved_by_assault", false))


# -- Togashi reappearance (s55.10.2.8) ----------------------------------------
#
# Fires when a new Mirumoto FC takes position after the previous one dies or
# is removed. Locates the nearest Dragon temple/monastery controlled by a
# Legitimacy-aligned lord; falls back to the nearest temple outside Dragon
# territory if none exists.
#
# settlements: Array[SettlementData] — the full settlement list.
# provinces: Dictionary[int -> ProvinceData].
# faction_assignments: Dictionary[int -> IntraClanCivilWar.Faction] for the
#   resolved schism, used to identify Legitimacy-aligned lords. Pass {} if
#   the schism was not assaulted (fallback path).
#
# Returns { "reappeared": bool, "settlement_id": int }.

static func reappear_togashi(
	state: Dictionary,
	togashi_character: L5RCharacterData,
	settlements: Array,
	provinces: Dictionary,
	faction_assignments: Dictionary,
) -> Dictionary:
	if togashi_character == null:
		return {"reappeared": false, "settlement_id": -1}

	var target_id: int = _find_reappearance_settlement(
		settlements, provinces, faction_assignments
	)
	if target_id < 0:
		return {"reappeared": false, "settlement_id": -1}

	togashi_character.physical_location = str(target_id)
	state["togashi_vanished"] = false
	state["dragon_autonomous_rule"] = false
	# Order reconstitutes over 4 seasons (s55.10.2.8) only if not assaulted;
	# assault dissolves the Order permanently for the autonomous FC's lifetime —
	# but a new FC clears autonomous rule, so reconstitution restarts then.
	# Pyrrhic: dissolved_by_assault stays true to track the history.
	state["order_reconstitution_seasons_remaining"] = 4

	return {"reappeared": true, "settlement_id": target_id}


static func _find_reappearance_settlement(
	settlements: Array,
	provinces: Dictionary,
	faction_assignments: Dictionary,
) -> int:
	# First pass: Dragon temple or monastery in a Legitimacy-aligned lord's province.
	for s: SettlementData in settlements:
		if not (
			s.settlement_type == Enums.SettlementType.TEMPLE
			or s.settlement_type == Enums.SettlementType.SHINDEN
			or s.settlement_type == Enums.SettlementType.MONASTERY
		):
			continue
		var prov: ProvinceData = provinces.get(s.province_id, null)
		if prov == null:
			continue
		if prov.clan != "Dragon":
			continue
		# Accept if at least one Legitimacy-aligned character governs the province,
		# or if no faction data (clear schism, any Dragon temple works).
		if faction_assignments.is_empty():
			return s.settlement_id
		for char_id: int in faction_assignments:
			var f: int = int(faction_assignments[char_id])
			if f == IntraClanCivilWar.Faction.LEGITIMACY:
				return s.settlement_id

	# Fallback: nearest temple or monastery outside Dragon territory.
	for s: SettlementData in settlements:
		if not (
			s.settlement_type == Enums.SettlementType.TEMPLE
			or s.settlement_type == Enums.SettlementType.SHINDEN
			or s.settlement_type == Enums.SettlementType.MONASTERY
		):
			continue
		var prov: ProvinceData = provinces.get(s.province_id, null)
		if prov == null:
			continue
		if prov.clan == "Dragon":
			continue
		return s.settlement_id

	return -1


# -- Order reconstitution tick (s55.10.2.8) -----------------------------------
# Call once per season. Returns true when reconstitution is complete.

static func tick_order_reconstitution(state: Dictionary) -> bool:
	var remaining: int = int(state.get("order_reconstitution_seasons_remaining", 0))
	if remaining <= 0:
		return remaining == 0 and not bool(state.get("togashi_vanished", false))
	remaining -= 1
	state["order_reconstitution_seasons_remaining"] = remaining
	return remaining == 0


# -- Pyrrhic victory: Order status after FC rebel win ------------------------

static func is_order_dissolved_permanently(state: Dictionary) -> bool:
	## True when the FC holds dragon_autonomous_rule AND the Order was
	## dissolved by assault. The Order stays dissolved for the FC's lifetime.
	return (
		bool(state.get("dragon_autonomous_rule", false))
		and bool(state.get("order_dissolved_by_assault", false))
	)


# -- High-level driver ------------------------------------------------------
#
# DayOrchestrator (or a Dragon-specific hook on season transitions) calls this
# after the Mirumoto FC's StrategicReview produces directives for the
# season. Returns a result dict the caller uses to mutate state and
# (optionally) inject the forced directive into the FC's clan_strategic_priorities.

static func process_seasonal_oversight(
	state: Dictionary,
	world_state: Dictionary,
	strategic_directives: Array,
	mirumoto_fc: L5RCharacterData,
	togashi_id: int,
	conflict_modifier: int = 0,
) -> Dictionary:
	# Oversight is suspended while Togashi is off-map (s55.10.2.8) or while the
	# FC holds autonomous rule (s55.10.2.8 rebel victory).
	if is_togashi_off_map(state) or bool(state.get("dragon_autonomous_rule", false)):
		return {
			"tick": {},
			"intervention_fired": false,
			"compliance": {},
			"forced_directive": {},
			"skipped": true,
		}

	var tick: Dictionary = tick_oversight(state, world_state, strategic_directives)

	# Lift any forced directives whose axis dissatisfaction dropped below the
	# release threshold (s55.10.2.5 step 6).
	for axis: int in [
		Axis.BALANCE_OF_POWER,
		Axis.IMPERIAL_COHESION,
		Axis.SPIRITUAL_HEALTH,
		Axis.SHADOWLANDS_CONTAINMENT,
	]:
		if should_lift_forced_directive(state, axis):
			remove_forced_directive(state, axis)

	var primary: int = int(tick.get("primary_axis", -1))
	if primary < 0:
		return {
			"tick": tick,
			"intervention_fired": false,
			"compliance": {},
			"forced_directive": {},
		}

	var directive: Dictionary = generate_forced_directive(primary as Axis)
	var is_repeated: bool = _has_active_directive_on_axis(state, primary as Axis)
	var compliance: Dictionary = evaluate_compliance(
		mirumoto_fc, directive, togashi_id, is_repeated, conflict_modifier
	)
	if compliance.get("comply", false):
		handle_compliance_response(state, primary as Axis)
		add_forced_directive(state, directive)
	else:
		handle_defiance(state, primary as Axis)

	return {
		"tick": tick,
		"intervention_fired": true,
		"compliance": compliance,
		"forced_directive": directive,
	}
