extends SceneTree

var checks: Array[Dictionary] = []
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks.append({"case": label, "passed": ok})
	if not ok: failures.append(label)

func _run() -> void:
	var audio = load("res://Scripts/game_audio.gd").new()
	root.add_child(audio)
	await process_frame
	for cue in ["warning", "support", "seal"]:
		check(audio._streams.has(cue) and not audio._streams[cue].is_empty(), "Loads original " + cue + " cue")
	check(audio._ambience.stream is AudioStreamOggVorbis and audio._ambience.stream.loop, "Ambience loads as a looping OGG")
	audio.set_combat(true)
	await process_frame
	check(audio._ambience.playing and not audio._ambience.stream_paused, "Combat starts ambience")
	var before: float = audio._ambience.volume_db
	audio.duck(2.0)
	audio._process(0.4)
	check(audio._ambience.volume_db < before - 5.0, "Warnings/dialogue duck ambience by at least five decibels")
	paused = true
	audio._process(0.1)
	check(audio._ambience.stream_paused, "Pause suspends ambience")
	paused = false
	audio._process(0.1)
	check(not audio._ambience.stream_paused, "Resume restores ambience")
	for n in range(100): audio.play_effect("support")
	check(audio._players.size() == 8, "Repeated support cues keep the bounded eight-voice pool")
	audio.play_effect("seal")
	var seal_voice: AudioStreamPlayer
	for voice: AudioStreamPlayer in audio._players:
		if voice.get_meta("effect", "") == "seal": seal_voice = voice
	audio.set_combat(false)
	check(not audio._ambience.playing, "Menu boundary stops the ambient stream")
	paused = true
	audio._process(0.1)
	var end_cue_ok := seal_voice != null and seal_voice.playing and seal_voice.can_process()
	for voice: AudioStreamPlayer in audio._players:
		if voice != seal_voice: end_cue_ok = end_cue_ok and not voice.playing
	audio.effects_volume = 0.0
	end_cue_ok = end_cue_ok and seal_voice != null and seal_voice.volume_db < -85.0
	audio.effects_volume = 0.8
	audio.play_effect("seal")
	end_cue_ok = end_cue_ok and not audio._last_played.has("seal")
	if seal_voice:
		await create_timer(seal_voice.stream.get_length() / seal_voice.pitch_scale + 0.2).timeout
		end_cue_ok = end_cue_ok and not seal_voice.playing
	check(end_cue_ok, "Seal finishes once across ending pause, obeys mute, stops naturally, and other combat sounds stop")
	paused = false
	audio.queue_free()
	await process_frame
	await create_timer(0.4).timeout
	var result := {"checks": checks, "failures": failures, "passed": failures.is_empty(), "scope": "Automated sound loading, ducking and lifecycle checks; no subjective listening assessment."}
	var output := FileAccess.open("res://evidence/audio_v03.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(result, "\t"))
	print("AUDIO_V03 ", JSON.stringify({"checks": checks.size(), "failures": failures}))
	quit(0 if failures.is_empty() else 1)
