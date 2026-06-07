class_name KolatOpportunityScanner
## Self-initiated Kolat objectives (s54.7d/e). Beyond the standing Sect mandate
## (which keeps an established network humming), a Master opportunistically pursues:
##   - SECURE_DEAD_DROP_NETWORK — a Lotus Master with a compromised dead drop
##     rotates it before any other Lotus work (s54.7c ROTATE_DEAD_DROP).
##   - CONDITION_SLEEPER        — a Dream Master below its sleeper target conditions
##     a co-located, non-Kolat, non-sleeper candidate (s54.7e).
##   - RECRUIT_KOLAT_AGENT      — an agent-network Sect below its capacity cap
##     recruits a co-located Friend-tier non-Kolat candidate (s54.7d).
## Trigger conditions and target-selection criteria trace to s54.7 (LOCKED); this
## layer only routes them into the Kolat objective slot. No invented mechanics.

const SOURCE: String = "kolat_self_select"
const RECRUIT_DISPOSITION_MIN: int = 31    # Friend tier (s12.2 / s54.7d)
const JADE_AGENT_CAP: int = 3              # s54.7h


## The best opportunistic Kolat objective for the Master, or {} if none applies.
static func scan(master: L5RCharacterData, chars_by_id: Dictionary) -> Dictionary:
	if master == null or CharacterStats.is_dead(master):
		return {}
	var sect: Enums.KolatSect = master.kolat_sect

	# Lotus secures a compromised drop before growing the network.
	if sect == Enums.KolatSect.LOTUS and _has_compromised_drop(master):
		return _objective("SECURE_DEAD_DROP_NETWORK", -1)

	# Dream conditions toward its sleeper target rather than recruiting agents.
	if sect == Enums.KolatSect.DREAM:
		if _sleeper_count(master) < _sleeper_target(master):
			var s: int = _pick_conditioning_candidate(master, chars_by_id)
			if s >= 0:
				return _objective("CONDITION_SLEEPER", s)
		return {}

	# Agent-network Sects recruit toward their capacity cap.
	if KolatNetwork.network_field_for_sect(sect) != "" and not _at_recruit_capacity(master, sect):
		var r: int = _pick_recruit_candidate(master, chars_by_id)
		if r >= 0:
			return _objective("RECRUIT_KOLAT_AGENT", r)
	return {}


## True when a self-selected Kolat slot's trigger no longer holds, so the slot
## should be cleared (basic completion/recall for self-initiated objectives).
## Tiger directives (a different source) are never cleared here.
static func should_clear(master: L5RCharacterData, slot: Dictionary, chars_by_id: Dictionary) -> bool:
	if master == null or CharacterStats.is_dead(master):
		return true
	if String(slot.get("source", "")) != SOURCE:
		return false
	match String(slot.get("need_type", "")):
		"SECURE_DEAD_DROP_NETWORK":
			return not _has_compromised_drop(master)
		"CONDITION_SLEEPER":
			if _sleeper_count(master) >= _sleeper_target(master):
				return true
			var tid: int = int(slot.get("target_npc_id", -1))
			var t: L5RCharacterData = chars_by_id.get(tid, null)
			return t == null or CharacterStats.is_dead(t) or _is_sleeper_of(master, tid)
		"RECRUIT_KOLAT_AGENT":
			if _at_recruit_capacity(master, master.kolat_sect):
				return true
			var rid: int = int(slot.get("target_npc_id", -1))
			var rt: L5RCharacterData = chars_by_id.get(rid, null)
			return rt == null or CharacterStats.is_dead(rt) or rt.kolat_sect != Enums.KolatSect.NONE
	return false


static func _objective(need_type: String, target_npc_id: int) -> Dictionary:
	return {
		"need_type": need_type,
		"priority": 2,
		"target_npc_id": target_npc_id,
		"source": SOURCE,
		"auto_assigned": true,
	}


# -- capacity / network state -------------------------------------------------

static func _at_recruit_capacity(master: L5RCharacterData, sect: Enums.KolatSect) -> bool:
	if sect == Enums.KolatSect.JADE:
		return KolatNetwork.get_network(master, sect).size() >= JADE_AGENT_CAP
	return KolatNetwork.at_capacity(master, sect)


static func _sleeper_count(master: L5RCharacterData) -> int:
	var reg: Variant = master.special_data.get("dream_sleeper_registry", {})
	return (reg as Dictionary).size() if reg is Dictionary else 0


static func _sleeper_target(master: L5RCharacterData) -> int:
	return int(master.special_data.get("world_start_sleepers", 0))


static func _is_sleeper_of(master: L5RCharacterData, npc_id: int) -> bool:
	var reg: Variant = master.special_data.get("dream_sleeper_registry", {})
	if not reg is Dictionary:
		return false
	for sid: Variant in (reg as Dictionary):
		var e: Variant = (reg as Dictionary)[sid]
		if e is Dictionary and int((e as Dictionary).get("npc_id", -1)) == npc_id:
			return true
	return false


static func _has_compromised_drop(master: L5RCharacterData) -> bool:
	var rec: Dictionary = KolatNetwork.get_network(master, Enums.KolatSect.LOTUS)
	for cn: Variant in rec:
		var e: Variant = rec[cn]
		if not e is Dictionary:
			continue
		if bool((e as Dictionary).get("dead_drop_compromised", false)):
			return true
		if bool((e as Dictionary).get("confirmation_drop_compromised", false)):
			return true
	return false


# -- candidate selection (LOCKED criteria) ------------------------------------

## Highest-disposition co-located non-Kolat character at Friend tier (s54.7d).
## Matches the APPROACH_FOR_RECRUITMENT executor gate (target → recruiter ≥ 31).
static func _pick_recruit_candidate(master: L5RCharacterData, chars_by_id: Dictionary) -> int:
	var best: int = -1
	var best_disp: int = RECRUIT_DISPOSITION_MIN - 1
	for cid: Variant in chars_by_id:
		var c: L5RCharacterData = chars_by_id[cid]
		if c == null or CharacterStats.is_dead(c) or c.is_pc:
			continue
		if c.character_id == master.character_id or c.kolat_sect != Enums.KolatSect.NONE:
			continue
		if c.physical_location != master.physical_location:
			continue
		var disp: int = int(c.disposition_values.get(master.character_id, 0))
		if disp >= RECRUIT_DISPOSITION_MIN and disp > best_disp:
			best_disp = disp
			best = c.character_id
	return best


## Co-located non-Kolat, non-sleeper candidate with the fewest required sessions
## (lowest Willpower; sessions_required = Willpower × 3, s54.7c).
static func _pick_conditioning_candidate(master: L5RCharacterData, chars_by_id: Dictionary) -> int:
	var best: int = -1
	var best_wp: int = 1 << 30
	for cid: Variant in chars_by_id:
		var c: L5RCharacterData = chars_by_id[cid]
		if c == null or CharacterStats.is_dead(c) or c.is_pc:
			continue
		if c.character_id == master.character_id or c.kolat_sect != Enums.KolatSect.NONE:
			continue
		if c.physical_location != master.physical_location:
			continue
		if _is_sleeper_of(master, c.character_id):
			continue
		if c.willpower < best_wp:
			best_wp = c.willpower
			best = c.character_id
	return best
