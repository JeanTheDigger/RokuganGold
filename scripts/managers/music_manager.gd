extends Node

# 🎵 Global music player (original purpose)
var music_player: AudioStreamPlayer

# 🌆 Ambiance system
var ambiance_loop_player: AudioStreamPlayer
var ambiance_sfx_player: AudioStreamPlayer
var random_timer: Timer

var current_category: String = ""
var current_one_shot_pool: Array[AudioStream] = []
var current_delay_range: Array = []

# 🎼 Unified category → { loop, random[], optional random_delay_range }
var ambiance_profiles: Dictionary = {}

func _ready():
	# 🎵 Main music
	music_player = AudioStreamPlayer.new()
	music_player.bus = "Music"
	music_player.volume_db = 0
	add_child(music_player)

	# 🌆 Ambiance loop
	ambiance_loop_player = AudioStreamPlayer.new()
	ambiance_loop_player.bus = "Ambiance"
	ambiance_loop_player.volume_db = -15
	ambiance_loop_player.autoplay = false
	add_child(ambiance_loop_player)

	# 🌌 One-shot SFX
	ambiance_sfx_player = AudioStreamPlayer.new()
	ambiance_sfx_player.bus = "Ambiance"
	ambiance_sfx_player.volume_db = -15
	add_child(ambiance_sfx_player)

	# ⏱️ Timer for randomized SFX
	random_timer = Timer.new()
	random_timer.one_shot = true
	random_timer.timeout.connect(_on_random_ambiance_timer_timeout)
	add_child(random_timer)


func update_ambiance_for_category(category: String) -> void:
	print("🎼 Switching ambiance to:", category)
	if category == current_category:
		return  # No change needed
	current_category = category

	var profile = ambiance_profiles.get(category, null)
	if profile == null:
		print("⚠️ No ambiance profile found for:", category)
		clear_ambiance()
		return

	play_loop_stream(profile.get("loop", null))

	# ✅ Safe manual cast to Array[AudioStream]
	current_one_shot_pool = []
	for sfx in profile.get("random", []):
		if sfx is AudioStream:
			current_one_shot_pool.append(sfx)

	current_delay_range = profile.get("random_delay_range", [12.0, 25.0])
	_schedule_next_sfx()


func play_loop_stream(stream: AudioStream) -> void:
	if stream == null:
		print("⚠️ Loop stream is null")
		ambiance_loop_player.stop()
		return

	if ambiance_loop_player.stream == stream and ambiance_loop_player.playing:
		print("✅ Loop already playing:", stream)
		return

	print("🎧 Starting new ambiance loop:", stream)
	ambiance_loop_player.stop()
	ambiance_loop_player.stream = stream
	ambiance_loop_player.play()


func _schedule_next_sfx():
	if current_one_shot_pool.is_empty():
		return
	var min_delay = current_delay_range[0]
	var max_delay = current_delay_range[1]
	var delay = randf_range(min_delay, max_delay)
	random_timer.start(delay)

func _on_random_ambiance_timer_timeout() -> void:
	if current_one_shot_pool.is_empty():
		print("⚠️ No one-shots available to play")
		return

	var index = randi() % current_one_shot_pool.size()
	var sound: AudioStream = current_one_shot_pool[index]

	ambiance_sfx_player.stream = sound
	ambiance_sfx_player.play()

	_schedule_next_sfx()


func clear_ambiance() -> void:
	ambiance_loop_player.stop()
	ambiance_sfx_player.stop()
	random_timer.stop()
	current_one_shot_pool = []
	current_category = ""
	current_delay_range = []

# 🎵 Original music fading system
func play_music(stream: AudioStream, start_pos := 0.0, fade_duration := 1.5):
	if music_player.stream == stream and music_player.playing:
		return
	music_player.stream = stream
	music_player.play(start_pos)
	music_player.volume_db = -80
	var tween := create_tween()
	tween.tween_property(music_player, "volume_db", 0, fade_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func fade_out(fade_duration := 2.5, final_volume_db := -30.0):
	if not music_player.playing:
		return
	var tween := create_tween()
	tween.tween_property(music_player, "volume_db", final_volume_db, fade_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	music_player.stop()
	music_player.volume_db = 0


func set_ambiance_category(category: String) -> void:
	update_ambiance_for_category(category)

func update_ambiance_volume(db_value: float) -> void:
	if ambiance_loop_player:
		ambiance_loop_player.volume_db = db_value
	if ambiance_sfx_player:
		ambiance_sfx_player.volume_db = db_value
