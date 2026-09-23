extends Node
## Small non-positional SFX pool. Combat audio stops at pause/menu boundaries.
## External samples and source archive hashes are recorded in Assets/Audio.

const POOL_SIZE := 8
const SAMPLE_PATHS := {
	"swing": ["res://Assets/Audio/swing.wav"],
	"hit": ["res://Assets/Audio/hit_1.ogg", "res://Assets/Audio/hit_2.ogg"],
	"heavy": ["res://Assets/Audio/heavy_1.ogg", "res://Assets/Audio/heavy_2.ogg"],
	"block": ["res://Assets/Audio/block_1.ogg", "res://Assets/Audio/block_2.ogg"],
	"parry": ["res://Assets/Audio/parry.ogg"],
	"hurt": ["res://Assets/Audio/hurt.ogg"],
	"step": ["res://Assets/Audio/step_1.ogg", "res://Assets/Audio/step_2.ogg"],
	"ui": ["res://Assets/Audio/ui.ogg"],
}
const LEVEL_DB := {"swing": -13.0, "hit": -7.0, "heavy": -5.0, "block": -11.0, "parry": -11.0, "hurt": -7.0, "step": -18.0, "ui": -14.0}
const PRIORITY := {"swing": 1, "hit": 2, "heavy": 2, "block": 2, "parry": 3, "hurt": 3, "step": 0, "ui": 4}
const COOLDOWN_MS := {"swing": 50, "hit": 28, "heavy": 40, "block": 45, "parry": 70, "hurt": 70, "step": 95, "ui": 45}

@export_range(0.0, 1.0, 0.01) var effects_volume: float = 0.8:
	set(value):
		effects_volume = clampf(value, 0.0, 1.0)
		_update_volumes()

var _players: Array[AudioStreamPlayer] = []
var _streams: Dictionary = {}
var _last_played: Dictionary = {}
var _combat_enabled := false
var _was_paused := false


func _ready() -> void:
	add_to_group("game_audio")
	process_mode = Node.PROCESS_MODE_ALWAYS
	for id: String in SAMPLE_PATHS:
		var samples: Array[AudioStream] = []
		for path: String in SAMPLE_PATHS[id]:
			if ResourceLoader.exists(path):
				var sample := load(path) as AudioStream
				if sample:
					samples.append(sample)
		_streams[id] = samples
	for index in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.name = "SFX%d" % index
		player.max_polyphony = 1
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		player.set_meta("effect", "")
		player.set_meta("priority", -1)
		player.set_meta("started", 0)
		add_child(player)
		_players.append(player)


func _process(_delta: float) -> void:
	var paused := get_tree().paused
	if paused and not _was_paused:
		_stop_combat_sounds()
	_was_paused = paused


func play_effect(id: String) -> void:
	if not _streams.has(id) or effects_volume <= 0.0:
		return
	if id != "ui" and (not _combat_enabled or get_tree().paused):
		return
	var samples: Array = _streams[id]
	if samples.is_empty():
		return
	var now := Time.get_ticks_msec()
	if now - int(_last_played.get(id, -10000)) < int(COOLDOWN_MS[id]):
		return
	var player: AudioStreamPlayer = _free_player(int(PRIORITY[id]))
	if not player:
		return
	player.stop()
	player.process_mode = Node.PROCESS_MODE_ALWAYS if id == "ui" else Node.PROCESS_MODE_PAUSABLE
	player.stream = samples[randi() % samples.size()] as AudioStream
	player.set_meta("effect", id)
	player.set_meta("priority", int(PRIORITY[id]))
	player.set_meta("started", now)
	player.volume_db = float(LEVEL_DB[id]) + linear_to_db(maxf(effects_volume, 0.0001))
	player.pitch_scale = 1.5 if id == "parry" else randf_range(0.94, 1.06)
	player.play()
	_last_played[id] = now


func set_combat(enabled: bool) -> void:
	_combat_enabled = enabled
	if not enabled:
		_stop_combat_sounds()
		_last_played.clear()


func _free_player(priority: int) -> AudioStreamPlayer:
	for player in _players:
		if not player.playing:
			return player
	# Preserve more important feedback. Footsteps cannot interrupt an impact/UI cue.
	var candidate: AudioStreamPlayer = null
	for player in _players:
		var active_priority := int(player.get_meta("priority", -1))
		if active_priority > priority:
			continue
		if candidate == null:
			candidate = player
		elif active_priority < int(candidate.get_meta("priority", -1)):
			candidate = player
		elif active_priority == int(candidate.get_meta("priority", -1)) and int(player.get_meta("started", 0)) < int(candidate.get_meta("started", 0)):
			candidate = player
	return candidate


func _stop_combat_sounds() -> void:
	for player in _players:
		if str(player.get_meta("effect", "")) != "ui":
			player.stop()


func _update_volumes() -> void:
	for player in _players:
		var id := str(player.get_meta("effect", ""))
		if LEVEL_DB.has(id):
			player.volume_db = float(LEVEL_DB[id]) + linear_to_db(maxf(effects_volume, 0.0001))
