extends SceneTree

# This is a headless regression of browser-policy fallback helpers, not proof that
# a browser granted pointer lock. Actual web denial/recovery requires browser QA.
const GameScene = preload("res://Scenes/main.tscn")
var checks: Array[Dictionary] = []
var failures: Array[String] = []
var skipped: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	checks.append({"pass": condition, "description": description})
	if not condition:
		failures.append(description)
		push_error(description)

func run() -> void:
	var game: Node = GameScene.instantiate()
	game.set_meta("qa_no_save", true)
	root.add_child(game)
	await process_frame
	game.start_level(0, 0)
	check(not game._capture_was_active and game._capture_stable_time == 0.0, "Starting a level clears pointer-capture history")
	for index in range(120): game._update_mouse_capture(0.1, false)
	check(not game.paused and not paused, "Continuously denied pointer capture never auto-pauses gameplay")
	check(game._capture_fallback_notified and "เมาส์กลาง" in game.toast.text, "Capture denial explains the middle-mouse camera fallback")
	var original_notice: String = game.toast.text
	game.notify("Later gameplay notice", 2.0)
	for index in range(20): game._update_mouse_capture(0.1, false)
	check(game.toast.text == "Later gameplay notice", "Fallback notification is not repeated over later gameplay notices")
	check(not original_notice.is_empty(), "Fallback notification is visible text")

	game.start_level(0, 0)
	game._update_mouse_capture(0.10, true)
	game._update_mouse_capture(0.70, false)
	check(not game.paused and not game._capture_was_active, "Brief capture below stability threshold does not arm loss-based pause")
	game._update_mouse_capture(0.10, true)
	game._update_mouse_capture(0.11, true)
	check(game._capture_was_active, "Stable capture arms normal loss-of-capture protection")
	game._update_mouse_capture(0.20, false)
	check(not game.paused, "Transient loss within grace period keeps gameplay running")
	game._update_mouse_capture(0.20, false)
	check(game.paused and paused and game.modal.visible, "Loss after stable capture and grace period opens pause menu")
	game._resume()
	check(not paused and not game.paused and not game._capture_was_active and game._capture_stable_time == 0.0, "Resume clears previous capture history and resumes the simulation")
	for index in range(20): game._update_mouse_capture(0.10, false)
	check(not game.paused, "Denied capture after resume does not create an endless pause loop")

	var camera: Node3D = game.player.camera_rig
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(40, 15)
	motion.button_mask = 0
	var before := camera.rotation
	camera._input(motion)
	check(camera.rotation == before, "Uncaptured mouse movement without middle button does not rotate camera")
	motion.button_mask = MOUSE_BUTTON_MASK_MIDDLE
	camera._input(motion)
	check(camera.rotation != before, "Middle-button dragging rotates camera without pointer capture")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	motion.button_mask = 0
	before = camera.rotation
	camera._input(motion)
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		check(camera.rotation != before, "Captured mouse motion retains ordinary camera rotation")
	else:
		skipped.append({"case": "Captured mouse motion camera branch", "reason": "Headless display backend cannot grant MOUSE_MODE_CAPTURED; verify in browser"})
	paused = true
	motion.button_mask = MOUSE_BUTTON_MASK_MIDDLE
	before = camera.rotation
	camera._input(motion)
	check(camera.rotation == before, "Paused camera ignores middle-drag motion")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	camera._input(motion)
	check(camera.rotation == before, "Paused camera also ignores uncaptured middle-button motion")
	paused = false
	var result := {"scope": "Headless helper regression for browser capture denial and camera fallback; actual browser pointer lock remains a separate verification", "engine": Engine.get_version_info().string, "passed": failures.is_empty(), "checks": checks, "failures": failures, "skipped": skipped}
	var output := FileAccess.open("res://evidence/browser_fallback_checks.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(result, "\t"))
	stop_audio(game)
	OS.delay_msec(120)
	game.queue_free()
	await process_frame
	await process_frame
	print("BROWSER_FALLBACK_RESULT ", JSON.stringify({"checks": checks.size(), "failures": failures, "passed": failures.is_empty()}))
	quit(0 if failures.is_empty() else 1)

func stop_audio(node: Node) -> void:
	if node is AudioStreamPlayer or node is AudioStreamPlayer3D or node is AudioStreamPlayer2D: node.stop()
	for child in node.get_children(): stop_audio(child)
