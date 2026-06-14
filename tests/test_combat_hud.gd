extends GutTest
## GUT tests for CombatHUD (scripts/ui/combat_hud.gd).
## Covers: event formatting for all combat event types including
## Bug A (player_noticed) and Bug B (escalated_to_alert) fixes.


# =============================================================================
# -- Helpers ------------------------------------------------------------------
# =============================================================================

func _hud() -> CombatHUD:
	var h := CombatHUD.new()
	return h


# =============================================================================
# -- 1. player_noticed event (Bug A fix) --------------------------------------
# =============================================================================

func test_player_noticed_returns_non_empty_string() -> void:
	var h := _hud()
	var line: String = h._format_event({"type": "player_noticed", "unit_type": "bandit"})
	assert_false(line.is_empty(), "player_noticed must produce a non-empty HUD line")


func test_player_noticed_does_not_return_heard_something() -> void:
	# Previously "noise_detected" was used for FoV visual detection.
	# The new "player_noticed" event must produce a visually distinct message.
	var h := _hud()
	var line: String = h._format_event({"type": "player_noticed", "unit_type": "bandit"})
	assert_false(line.contains("heard"), "player_noticed must not say 'heard' — enemy SAW the player")


# =============================================================================
# -- 2. escalated_to_alert event (Bug B fix) ----------------------------------
# =============================================================================

func test_escalated_to_alert_returns_non_empty_string() -> void:
	var h := _hud()
	var line: String = h._format_event({"type": "escalated_to_alert", "unit_type": "guard"})
	assert_false(line.is_empty(), "escalated_to_alert must produce a non-empty HUD line")


func test_escalated_to_alert_contains_unit_type() -> void:
	var h := _hud()
	var line: String = h._format_event({"type": "escalated_to_alert", "unit_type": "guard"})
	assert_true(line.contains("guard"), "escalated_to_alert line must name the unit type")


# =============================================================================
# -- 3. Existing event types still work --------------------------------------
# =============================================================================

func test_noise_detected_still_works() -> void:
	var h := _hud()
	var line: String = h._format_event({"type": "noise_detected"})
	assert_false(line.is_empty(), "noise_detected must still produce a HUD line")
	assert_true(line.contains("heard"), "noise_detected should mention hearing")


func test_alarm_raised_still_works() -> void:
	var h := _hud()
	var line: String = h._format_event({"type": "alarm_raised"})
	assert_false(line.is_empty(), "alarm_raised must produce a HUD line")


func test_unknown_event_type_returns_empty() -> void:
	var h := _hud()
	var line: String = h._format_event({"type": "completely_unknown_type"})
	assert_true(line.is_empty(), "unknown event type must return empty string")


# =============================================================================
# -- 4. End Combat events (GDD s40.x) -----------------------------------------
# =============================================================================

func test_end_combat_blocked_reports_count() -> void:
	var h := _hud()
	var line: String = h._format_event({"type": "end_combat_blocked", "count": 2})
	assert_false(line.is_empty(), "end_combat_blocked must produce a HUD line")
	assert_true(line.contains("2"), "blocked line names the active hostile count")


func test_end_combat_awaiting_reports_count() -> void:
	var h := _hud()
	var line: String = h._format_event({"type": "end_combat_awaiting", "count": 3})
	assert_false(line.is_empty(), "end_combat_awaiting must produce a HUD line")
	assert_true(line.contains("3"), "awaiting line names the pending PC count")


func test_end_combat_resolved_returns_non_empty() -> void:
	var h := _hud()
	var line: String = h._format_event({"type": "end_combat_resolved"})
	assert_false(line.is_empty(), "end_combat_resolved must produce a HUD line")
