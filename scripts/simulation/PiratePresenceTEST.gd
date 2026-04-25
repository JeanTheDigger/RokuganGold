extends RefCounted
class_name PiratePresence

const StrategicTestConfig = preload("res://scripts/simulation/StrategicTestConfig.gd")

var system_id: int = -1
var state: int = StrategicTestConfig.PIRATE_STATE_NONE
var threat_sr: int = 0
var base_level: int = 0
var tags: Dictionary = {
	"has_hidden_base": false,
	"leader_id": null,
	"loot_table_id": "pirate_basic",
}
var active_fleets: Array = []
var structures: Array = []


static func create_default(system_id_value: int) -> Dictionary:
	return {
		"system_id": system_id_value,
		"state": StrategicTestConfig.PIRATE_STATE_NONE,
		"threat_sr": 0,
		"base_level": 0,
		"tags": {
			"has_hidden_base": false,
			"leader_id": null,
			"loot_table_id": "pirate_basic",
		},
		"active_fleets": [],
		"structures": [],
	}
