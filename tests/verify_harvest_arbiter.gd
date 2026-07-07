extends SceneTree
## Runtime driver for routing the harvest-destruction gate through the canonical
## arbiter (StarvationWarfare.evaluate_ai_harvest_decision). Before this fix the
## NPC engine's _is_harvest_blocked_by_virtue had an inline copy that diverged from
## the GDD (s4.3.17 Phase 4) twice: (1) it never enforced the Autumn-harvest-tick
## requirement (line 1041), so RAID_HARVEST could be selected in any season; and
## (2) it treated Rei as CONDITIONAL (allowed on a prior formal demand) when the
## GDD makes Rei a NEVER virtue (line 1061). This verifies the gate now agrees with
## the arbiter, that the season derives correctly from ctx.ic_day, and the two
## title-case/season helpers.
## Run: godot --headless -s tests/verify_harvest_arbiter.gd

const _NPC := preload("res://simulation/npc_decision_engine.gd")

var _pass: int = 0
var _fail: int = 0


func _ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("  FAIL: %s" % label)


func _ctx(
	bushido: Enums.BushidoVirtue,
	shourido: Enums.ShouridoVirtue,
	ic_day: int,
	conds: Dictionary = {},
) -> NPCDataStructures.ContextSnapshot:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.bushido_virtue = bushido
	ctx.shourido_virtue = shourido
	ctx.ic_day = ic_day
	ctx.clan = "Lion"
	# hated_enemy -> a disposition <= -60.
	if conds.get("hated_enemy", false):
		ctx.disposition_values = {99: -70}
	# lord_commands -> a pending RAID_HARVEST/DESTROY_HARVEST event.
	if conds.get("lord_commands", false):
		ctx.pending_events = [{"need_type": "DESTROY_HARVEST"}]
	# publicly_declared / prior_formal_demand -> action_log entries.
	var log: Array = []
	if conds.get("publicly_declared", false):
		log.append({"action_id": "PUBLIC_DECLARATION"})
	if conds.get("prior_formal_demand", false):
		log.append({"action_id": "DEMAND_TRIBUTE"})
	ctx.action_log = log
	# no_other_path -> an active war with own score < 25.
	if conds.get("no_other_path", false):
		ctx.active_wars = [{"clan_a": "Lion", "clan_b": "Crane", "war_score_a": 10, "war_score_b": 90}]
	return ctx


## true == the arbiter BLOCKS harvest destruction for this ctx.
func _blocked(ctx: NPCDataStructures.ContextSnapshot) -> bool:
	return _NPC._is_harvest_blocked_by_virtue(ctx)


const AUTUMN := 200  # doy 200 in [180,240)
const SUMMER := 100  # doy 100, not autumn


func _init() -> void:
	print("--- Harvest Destruction Arbiter Routing (s4.3.17 Phase 4) ---")
	_test_never_virtues()
	_test_conditional_virtues()
	_test_shourido_and_season_gate()
	_test_helpers()
	print("--- %d passed, %d failed ---" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)


func _test_never_virtues() -> void:
	print("[1] NEVER virtues (Jin/Gi/Rei) blocked in Autumn regardless of conditions")
	# Rei is THE key fix: the old code allowed Rei on a prior formal demand.
	_ok(_blocked(_ctx(Enums.BushidoVirtue.REI, Enums.ShouridoVirtue.NONE, AUTUMN,
		{"prior_formal_demand": true, "hated_enemy": true, "lord_commands": true})),
		"Rei blocked in Autumn even with prior demand + hated enemy + lord command")
	_ok(_blocked(_ctx(Enums.BushidoVirtue.JIN, Enums.ShouridoVirtue.NONE, AUTUMN, {"hated_enemy": true})),
		"Jin blocked in Autumn")
	_ok(_blocked(_ctx(Enums.BushidoVirtue.GI, Enums.ShouridoVirtue.NONE, AUTUMN, {"lord_commands": true})),
		"Gi blocked in Autumn")


func _test_conditional_virtues() -> void:
	print("[2] CONDITIONAL virtues gated on their specific condition (Autumn)")
	# Meiyo requires hated_enemy.
	_ok(not _blocked(_ctx(Enums.BushidoVirtue.MEIYO, Enums.ShouridoVirtue.NONE, AUTUMN, {"hated_enemy": true})),
		"Meiyo + hated enemy -> allowed")
	_ok(_blocked(_ctx(Enums.BushidoVirtue.MEIYO, Enums.ShouridoVirtue.NONE, AUTUMN, {})),
		"Meiyo without hated enemy -> blocked")
	# Chugi requires lord_commands.
	_ok(not _blocked(_ctx(Enums.BushidoVirtue.CHUGI, Enums.ShouridoVirtue.NONE, AUTUMN, {"lord_commands": true})),
		"Chugi + lord command -> allowed")
	_ok(_blocked(_ctx(Enums.BushidoVirtue.CHUGI, Enums.ShouridoVirtue.NONE, AUTUMN, {})),
		"Chugi without lord command -> blocked")
	# Makoto requires publicly_declared.
	_ok(not _blocked(_ctx(Enums.BushidoVirtue.MAKOTO, Enums.ShouridoVirtue.NONE, AUTUMN, {"publicly_declared": true})),
		"Makoto + public declaration -> allowed")
	# Yu requires no_other_path.
	_ok(not _blocked(_ctx(Enums.BushidoVirtue.YU, Enums.ShouridoVirtue.NONE, AUTUMN, {"no_other_path": true})),
		"Yu + no other path -> allowed")


func _test_shourido_and_season_gate() -> void:
	print("[3] Shourido always-condition-met + the Autumn season gate")
	# Ketsui (shourido) needs no condition -> allowed in Autumn.
	_ok(not _blocked(_ctx(Enums.BushidoVirtue.NONE, Enums.ShouridoVirtue.KETSUI, AUTUMN, {})),
		"Ketsui shourido -> allowed in Autumn (no condition needed)")
	# The SEASON FIX: the SAME Ketsui lord is BLOCKED out of Autumn.
	_ok(_blocked(_ctx(Enums.BushidoVirtue.NONE, Enums.ShouridoVirtue.KETSUI, SUMMER, {})),
		"Ketsui shourido -> BLOCKED in Summer (season gate)")
	# And an allowed-in-Autumn Meiyo is likewise blocked out of season.
	_ok(_blocked(_ctx(Enums.BushidoVirtue.MEIYO, Enums.ShouridoVirtue.NONE, SUMMER, {"hated_enemy": true})),
		"Meiyo + hated enemy -> BLOCKED in Summer (season gate)")
	# No virtue at all -> the gate never fires (not blocked; personality can't forbid).
	_ok(not _blocked(_ctx(Enums.BushidoVirtue.NONE, Enums.ShouridoVirtue.NONE, AUTUMN, {})),
		"no virtue -> not blocked by the virtue gate")


func _test_helpers() -> void:
	print("[4] season + virtue-case helpers")
	_ok(_NPC._is_autumn_ic_day(200), "ic_day 200 -> autumn")
	_ok(_NPC._is_autumn_ic_day(180), "ic_day 180 (window start) -> autumn")
	_ok(not _NPC._is_autumn_ic_day(240), "ic_day 240 (window end, exclusive) -> not autumn")
	_ok(not _NPC._is_autumn_ic_day(10), "ic_day 10 -> not autumn")
	_ok(_NPC._is_autumn_ic_day(560), "ic_day 560 (year 2 autumn) -> autumn")  # 560 % 360 = 200
	_ok(not _NPC._is_autumn_ic_day(-10), "ic_day -10 -> not autumn (wraps to 350)")
	# Title-case conversion of the UPPERCASE enum key.
	var rei := _ctx(Enums.BushidoVirtue.REI, Enums.ShouridoVirtue.NONE, AUTUMN, {})
	_ok(_NPC._harvest_virtue_title_case(rei) == "Rei", "REI -> Rei")
	var ketsui := _ctx(Enums.BushidoVirtue.NONE, Enums.ShouridoVirtue.KETSUI, AUTUMN, {})
	_ok(_NPC._harvest_virtue_title_case(ketsui) == "Ketsui", "KETSUI -> Ketsui")
