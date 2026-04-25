extends RefCounted
class_name PirateFleetStub

var id: int = -1
var sr: int = 0
var strength: int = 0
var composition_id: String = ""


static func create_default() -> Dictionary:
	return {
		"id": -1,
		"sr": 0,
		"strength": 0,
		"composition_id": "",
	}
