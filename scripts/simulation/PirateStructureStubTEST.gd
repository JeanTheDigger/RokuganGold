extends RefCounted
class_name PirateStructureStub

var id: int = -1
var type: String = ""
var sr: int = 0


static func create_default() -> Dictionary:
	return {
		"id": -1,
		"type": "",
		"sr": 0,
	}
