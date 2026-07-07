extends SceneTree
## Runtime driver for the dormant land-commander battle-bonus arbiter (s11.7 / s45).
## ArmyCombatSystem.resolve_commander_bonus (Battle rank + Tactician +5 + Strategist +1k0,
## ring-typed with clan-priority tie-break) had ZERO production callers -- the sole land-army
## battle-company builder (_build_battle_states) instead computed the bonus via the NAVAL-shaped
## inline copy _compute_captain_bonus, which SILENTLY DROPS the Tactician/Strategist advantages
## (s45) and uses a FIRE-biased tie-break with no clan priority. So a Tactician/Strategist land
## commander gave their army NO bonus in any field battle or storm assault. Now _build_battle_states
## routes through resolve_commander_bonus.
## Run: godot --headless -s tests/verify_land_commander_bonus.gd

const _ACS := preload("res://simulation/army_combat_system.gd")
const _DO := preload("res://simulation/day_orchestrator.gd")

var _pass: int = 0
var _fail: int = 0


func _ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("  FAIL: %s" % label)


# A commander: Battle rank + a dominant ring (via its paired traits) + optional advantages.
func _cmdr(clan: String, battle: int, advantages: Array = [], fire: int = 2) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = 1
	c.clan = clan
	c.skills = {"Battle": battle}
	# Fire ring = min(Agility, Intelligence); make Fire dominant so bonus_type == attack.
	c.agility = fire
	c.intelligence = fire
	# Keep the other rings low so Fire wins outright (no tie).
	c.reflexes = 1
	c.awareness = 1
	c.stamina = 1
	c.willpower = 1
	c.strength = 1
	c.perception = 1
	c.void_ring = 1
	for a: Enums.Advantage in advantages:
		var ad := AdvantageData.new()
		ad.advantage_type = a
		c.advantages.append(ad)
	return c


func _init() -> void:
	print("--- land-commander battle bonus: canonical arbiter (s11.7 / s45) ---")
	_test_plain_commander_matches()
	_test_tactician_restored()
	_test_strategist_restored()
	_test_build_battle_states_routes()
	_test_no_battle_skill()
	print("--- %d passed, %d failed ---" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)


func _test_plain_commander_matches() -> void:
	print("[1] a plain commander (no advantages) -> bonus_value == Battle rank, type attack")
	var b := _ACS.resolve_commander_bonus(_cmdr("Lion", 3), "Lion")
	_ok(b.get("bonus_type", "") == "attack", "Fire-dominant -> attack bonus (got %s)" % b.get("bonus_type", ""))
	_ok(int(b.get("bonus_value", -1)) == 3, "bonus_value == Battle rank 3 (got %d)" % int(b.get("bonus_value", -1)))


func _test_tactician_restored() -> void:
	print("[2] a TACTICIAN commander -> +5 over Battle rank (the dropped advantage, s45)")
	var b := _ACS.resolve_commander_bonus(_cmdr("Lion", 3, [Enums.Advantage.TACTICIAN]), "Lion")
	_ok(int(b.get("bonus_value", -1)) == 8, "Battle 3 + Tactician 5 = 8 (got %d)" % int(b.get("bonus_value", -1)))


func _test_strategist_restored() -> void:
	print("[3] a STRATEGIST commander -> +1 over Battle rank (the dropped advantage, s45)")
	var b := _ACS.resolve_commander_bonus(_cmdr("Lion", 3, [Enums.Advantage.STRATEGIST]), "Lion")
	_ok(int(b.get("bonus_value", -1)) == 4, "Battle 3 + Strategist 1 = 4 (got %d)" % int(b.get("bonus_value", -1)))


func _test_build_battle_states_routes() -> void:
	print("[4] _build_battle_states now applies the Tactician bonus to the built company")
	var cmdr := _cmdr("Lion", 3, [Enums.Advantage.TACTICIAN])
	var chars: Dictionary = {cmdr.character_id: cmdr}
	# A minimal company dict with this commander (the fields _company_dict_to_data + the builder read).
	var cd: Dictionary = {
		"company_id": 100, "commander_id": cmdr.character_id,
		"unit_type": Enums.CompanyUnitType.BUSHI_RETAINER,
		"clan_name": "Lion",
		"health": 153, "morale": 16, "attack": 3, "defense": 5, "morale_defense": 7,
	}
	var states: Array = _DO._build_battle_states([cd], "attacker", chars)
	_ok(states.size() == 1, "one battle company built")
	var bonus: Dictionary = states[0].get("commander_bonus", {})
	_ok(int(bonus.get("bonus_value", -1)) == 8, "built company carries Battle 3 + Tactician 5 = 8 (got %d)" % int(bonus.get("bonus_value", -1)))
	# And the effective attack reflects the bonus (base_attack from UNIT_STATS + attack bonus 8).
	var base_atk: int = int(states[0].get("base_attack", 0))
	var eff: int = _ACS._get_effective_attack(states[0])
	_ok(eff == base_atk + 8, "effective attack = base %d + commander 8 = %d (got %d)" % [base_atk, base_atk + 8, eff])


func _test_no_battle_skill() -> void:
	print("[5] a commander with Battle 0 -> no bonus (bonus_type empty)")
	var b := _ACS.resolve_commander_bonus(_cmdr("Lion", 0, [Enums.Advantage.TACTICIAN]), "Lion")
	_ok(b.get("bonus_type", "") == "", "Battle 0 -> no bonus type (got %s)" % b.get("bonus_type", ""))
