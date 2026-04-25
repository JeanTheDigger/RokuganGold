extends Node

const CHAT_DIVIDER: String = "[color=gray]────────────────────[/color]\n"

func _ready() -> void:
	pass

func get_eligible_targets(_teacher_name: String) -> Array[String]:
	return []

func get_teachable_disciplines(_teacher_name: String, _student_name: String) -> Array[String]:
	return []

func get_teaching_options(_teacher_name: String, _student_name: String, _subject: String) -> Dictionary:
	return {
		"options": [],
		"auto_select": false,
		"auto_value": "",
		"auto_label": ""
	}

func accept_teach_invite(_teacher_name: String, _student_name: String, _discipline: String) -> Dictionary:
	return {
		"ok": false,
		"code": "mentoring_disabled",
		"message": CHAT_DIVIDER + "Mentoring is currently unavailable."
	}

func accept_training_invite(_teacher_name: String, _student_name: String, _subject: String, _topic_value: String, _topic_label: String) -> Dictionary:
	return {
		"ok": false,
		"code": "mentoring_disabled",
		"message": CHAT_DIVIDER + "Mentoring is currently unavailable."
	}
