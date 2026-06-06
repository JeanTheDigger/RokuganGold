extends GutTest
## Validates the Kolat scoring-table entries (GDD s54.7c). Loads the NPC-engine
## JSON tables and asserts the 6 NeedTypes, 29 ActionID skill mappings, and the
## Gi recruitment gate are present and well-formed.

const TABLE_DIR := "res://systems/npc_engine/data/tables/"

const KOLAT_NEEDTYPES := [
	"SEND_KOLAT_DIRECTIVE", "MAINTAIN_KOLAT_NETWORK", "MANAGE_KOLAT_FUNDS",
	"CONDITION_SLEEPER", "MAINTAIN_SLEEPER", "LOCATE_CHARACTER",
]

const KOLAT_ACTIONIDS := [
	"TRANSMIT_VIA_TEAR", "OBSERVE_VIA_EYE", "SUBMIT_KOLAT_REPORT", "RUN_COURIER_ROUTE",
	"DISTRIBUTE_INTELLIGENCE", "ESTABLISH_DEAD_DROP", "UNDERREPORT_KOKU", "LAUNDER_KOKU",
	"TRANSFER_KOLAT_FUNDS", "ANONYMOUS_TIP", "CONDUCT_CONDITIONING", "MAINTAIN_SLEEPER_CONTACT",
	"ACTIVATE_SLEEPER", "SECURE_ONI_EYE", "APPROACH_FOR_RECRUITMENT", "ROUTE_VIA_DEAD_DROP",
	"CHECK_DEAD_DROP", "ROTATE_DEAD_DROP", "ARRANGE_PROXY_DUEL", "CHECK_CONFIRMATION_DROP",
	"ROUTE_ANONYMOUS_INTELLIGENCE", "SPONSOR_INSURGENCY", "BRIBE_GARRISON_COMMANDER",
	"CONTRIBUTE_TO_RESERVE", "CONDUCT_PERIMETER_PATROL", "ARCHIVE_TOPIC", "RESURRECT_TOPIC",
	"USE_CLOUDS_EYES", "DELIVER_SEALED_LETTER",
]


func _load(table: String) -> Dictionary:
	var f := FileAccess.open(TABLE_DIR + table, FileAccess.READ)
	assert_not_null(f, "table opens: " + table)
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	assert_true(parsed is Dictionary, "table is valid JSON object: " + table)
	return parsed


func test_objective_alignment_has_kolat_needtypes() -> void:
	var oa := _load("objective_alignment.json")
	for nt: String in KOLAT_NEEDTYPES:
		assert_true(oa.has(nt), "objective_alignment has NeedType " + nt)
	# Spot-check exact s54.7c scores.
	assert_eq(int(oa["SEND_KOLAT_DIRECTIVE"]["TRANSMIT_VIA_TEAR"]), 100)
	assert_eq(int(oa["MANAGE_KOLAT_FUNDS"]["UNDERREPORT_KOKU"]), 100)
	assert_eq(int(oa["CONDITION_SLEEPER"]["CONDUCT_CONDITIONING"]), 100)
	assert_eq(int(oa["MAINTAIN_SLEEPER"]["MAINTAIN_SLEEPER_CONTACT"]), 100)


func test_action_skill_map_has_all_kolat_actions() -> void:
	var sm := _load("action_skill_map.json")
	for a: String in KOLAT_ACTIONIDS:
		assert_true(sm.has(a), "action_skill_map has " + a)
		assert_true(sm[a].has("primary") and sm[a].has("secondary"),
			"%s has primary/secondary keys" % a)
	# Spot-check exact s54.7c skill mappings.
	assert_eq(sm["TRANSMIT_VIA_TEAR"]["primary"], "Calligraphy (Cipher)")
	assert_eq(sm["CONDUCT_CONDITIONING"]["primary"], "Temptation")
	assert_eq(sm["LAUNDER_KOKU"]["primary"], "Commerce (Appraisal)")
	assert_eq(sm["APPROACH_FOR_RECRUITMENT"]["primary"], "Sincerity (Temptation)")
	assert_eq(sm["SPONSOR_INSURGENCY"]["primary"], "Commerce (Merchant)")


func test_gi_blocks_recruitment_and_covert_kolat() -> void:
	var pf := _load("personality_filter.json")
	var gi_blocked: Array = pf["bushido"]["GI"]["always_blocked"]
	assert_true("APPROACH_FOR_RECRUITMENT" in gi_blocked, "Gi blocks recruitment (s54.7c)")
	assert_true("CONDUCT_CONDITIONING" in gi_blocked, "Gi blocks conditioning")
	assert_true("ACTIVATE_SLEEPER" in gi_blocked)
