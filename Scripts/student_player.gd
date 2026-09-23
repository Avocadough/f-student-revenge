# Camera-relative acceleration and model rotation adapted from Jeh3no (MIT),
# WalkState / PlayerCharacter. Combat and campus interaction are original additions.
extends CharacterBody3D

signal defeated
signal message(text: String)
signal combo_completed(combo_id: String)

const CameraRig = preload("res://Scripts/camera_rig.gd")
const FX = preload("res://Scripts/combat_fx.gd")
const ATTACKS := {
	"jab": {"startup": 0.13, "active": 0.13, "recovery": 0.19, "damage": 13.0, "posture": 14.0, "range": 2.05, "force": 0.6, "heavy": false},
	"cross": {"startup": 0.14, "active": 0.13, "recovery": 0.21, "damage": 16.0, "posture": 17.0, "range": 2.15, "force": 0.8, "heavy": false},
	"hook": {"startup": 0.19, "active": 0.15, "recovery": 0.26, "damage": 24.0, "posture": 24.0, "range": 2.2, "force": 2.5, "heavy": false},
	"kick": {"startup": 0.23, "active": 0.16, "recovery": 0.28, "damage": 26.0, "posture": 37.0, "range": 2.5, "force": 5.2, "heavy": true},
	"sweep": {"startup": 0.22, "active": 0.17, "recovery": 0.28, "damage": 20.0, "posture": 40.0, "range": 2.3, "force": 1.6, "heavy": true},
	"focus": {"startup": 0.24, "active": 0.17, "recovery": 0.32, "damage": 45.0, "posture": 60.0, "range": 2.8, "force": 7.0, "heavy": true},
	"counter": {"startup": 0.08, "active": 0.16, "recovery": 0.24, "damage": 26.0, "posture": 38.0, "range": 2.3, "force": 2.7, "heavy": true}
}

var health: float = 100.0
var max_health: float = 100.0
var posture: float = 0.0
var focus: float = 0.0
var active: bool = true
var dead: bool = false
var god_mode: bool = false
var stage_ref: Node
var camera_rig: Node3D
var visual: Node3D
var animation_player: AnimationPlayer
var animation_map: Dictionary = {}
var current_animation: String = ""
var move_speed: float = 5.0
var move_accel: float = 12.0
var model_rot_speed: float = 15.0
var facing: Vector3 = Vector3.FORWARD
var move_direction: Vector3 = Vector3.ZERO
var guarding: bool = false
var parry_timer: float = 0.0
var counter_timer: float = 0.0
var invulnerability: float = 0.0
var stagger_timer: float = 0.0
var dodge_timer: float = 0.0
var dodge_cooldown: float = 0.0
var dodge_direction: Vector3 = Vector3.ZERO
var last_hit_time: float = 0.0
var hit_pause: float = 0.0
var attack_id: String = ""
var attack_elapsed: float = 0.0
var hit_targets: Dictionary = {}
var chain: String = ""
var chain_targets: Dictionary = {}
var chain_timer: float = 0.0
var queued_action: String = ""
var queue_timer: float = 0.0
var combo_hits: int = 0
var combo_display_timer: float = 0.0
var last_combo_name: String = ""
var attack_connected: bool = false
var attack_count: int = 0
var parry_count: int = 0
var dodge_count: int = 0
var damage_taken: float = 0.0
var step_timer: float = 0.0
var animation_hold: float = 0.0
var locomotion_clip: String = "idle"
var audio_ref: Node

func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 0.3
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.33
	capsule.height = 1.72
	collision.shape = capsule
	collision.position.y = 0.86
	add_child(collision)
	visual = Node3D.new()
	visual.name = "Visual"
	add_child(visual)
	_load_model()
	camera_rig = CameraRig.new()
	add_child(camera_rig)
	audio_ref = get_tree().get_first_node_in_group("game_audio")
	FX.prepare(get_parent())

func _load_model() -> void:
	var path := "res://Assets/Models/student.glb"
	if ResourceLoader.exists(path):
		var model: Node3D = load(path).instantiate()
		visual.add_child(model)
		animation_player = _find_animation_player(model)
		if animation_player:
			# Imported clips only animate bones. Bone poses do not inherit Node3D
			# physics interpolation, so sample them every rendered frame.
			animation_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE
			_build_animation_map()
			_play_animation("idle")
	else:
		# Explicit temporary integration placeholder, excluded from release acceptance.
		var mesh := MeshInstance3D.new()
		var capsule := CapsuleMesh.new()
		capsule.height = 1.7
		capsule.radius = 0.32
		mesh.mesh = capsule
		mesh.position.y = 0.85
		visual.add_child(mesh)

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var result := _find_animation_player(child)
		if result:
			return result
	return null

func _build_animation_map() -> void:
	var candidates := {
		"idle": ["idle_normal", "idle", "idle a"], "walk": ["walk_normal", "walk", "walking"],
		"run": ["jog_fwd", "jog", "run", "sprint"], "jab": ["punch_jab", "jab", "punch"],
		"cross": ["punch_cross", "cross"], "hook": ["melee_hook", "hook"],
		"kick": ["front_kick", "kick", "push"], "sweep": ["sweep", "kick", "push"],
		"guard": ["guard", "block", "idle"], "parry": ["parry", "guard"],
		"dodge": ["dodge", "roll"], "hit": ["hit_chest", "hit", "knockback"],
		"death": ["death", "knockback"], "throw": ["overhand_throw", "throw", "push"]
	}
	for key: String in candidates:
		for candidate: String in candidates[key]:
			for animation: StringName in animation_player.get_animation_list():
				var normalized := String(animation).to_lower().replace(" ", "_").replace("-", "_")
				if normalized.contains(candidate.replace(" ", "_")) and not normalized.contains("_rm") and not normalized.contains("_rec"):
					animation_map[key] = String(animation)
					break
			if animation_map.has(key):
				break

func _play_animation(key: String, duration: float = 0.0, force: bool = false) -> void:
	if not animation_player or not animation_map.has(key):
		return
	var clip: String = animation_map[key]
	if current_animation == clip and not force:
		return
	current_animation = clip
	var anim := animation_player.get_animation(clip)
	anim.loop_mode = Animation.LOOP_LINEAR if key in ["idle", "walk", "run", "guard"] else Animation.LOOP_NONE
	var speed := anim.length / duration if duration > 0.0 else 1.0
	var blend := 0.16 if key in ["idle", "walk", "run", "guard"] else 0.07
	animation_player.speed_scale = 1.0
	animation_player.play(clip, blend, speed)

func _update_locomotion() -> void:
	if animation_hold > 0.0: return
	var speed := Vector2(velocity.x, velocity.z).length()
	var key := "guard" if guarding else locomotion_clip
	if not guarding:
		# Velocity and hysteresis prevent idle/run flicker while accelerating or brushing walls.
		if speed < 0.12:
			key = "idle"
		elif speed > 3.2:
			key = "run"
		elif speed < 2.7 or locomotion_clip == "idle":
			key = "walk"
		locomotion_clip = key
	_play_animation(key)
	if animation_player:
		animation_player.speed_scale = clampf(speed / (4.5 if key == "run" else 2.0), 0.65, 1.2) if key in ["run", "walk"] else 1.0

func _unhandled_input(event: InputEvent) -> void:
	if not active or dead or get_tree().paused:
		return
	if event is InputEventKey and event.echo:
		return
	if event.is_action_pressed("light_attack"):
		request_attack("L")
	elif event.is_action_pressed("heavy_attack"):
		request_attack("H")
	elif event.is_action_pressed("dodge"):
		request_dodge()
	elif event.is_action_pressed("guard"):
		if attack_id.is_empty() and dodge_timer <= 0.0 and stagger_timer <= 0.0:
			guarding = true
			parry_timer = 0.22
	elif event.is_action_released("guard"):
		guarding = false
	elif event.is_action_pressed("focus_attack"):
		request_focus()
	elif event.is_action_pressed("interact"):
		request_interact()
	elif event.is_action_pressed("recenter"):
		camera_rig.recenter(atan2(-facing.x, -facing.z))

func request_attack(input: String) -> void:
	if dead or not active or stagger_timer > 0.0 or dodge_timer > 0.0:
		return
	if not attack_id.is_empty():
		queued_action = input
		queue_timer = 0.18
		return
	guarding = false
	if counter_timer > 0.0 and input == "L":
		counter_timer = 0.0
		chain = ""
		_start_attack("counter")
		return
	if chain_timer <= 0.0:
		chain = ""
	if chain.is_empty():
		chain_targets.clear()
	chain += input
	var chosen := "jab"
	match chain:
		"L": chosen = "jab"
		"LL": chosen = "cross"
		"LLL": chosen = "hook"
		"LLH": chosen = "kick"
		"LH": chosen = "sweep"
		"LHL": chosen = "cross"
		_: chosen = "kick" if input == "H" else "jab"
	if chain not in ["L", "LL", "LLL", "LLH", "LH", "LHL"]:
		chain = input
		chain_targets.clear()
	_start_attack(chosen)

func _start_attack(id: String) -> void:
	attack_id = id
	attack_elapsed = 0.0
	hit_targets.clear()
	attack_connected = false
	animation_hold = 0.0
	attack_count += 1
	var target := nearest_enemy(3.0, true)
	if target:
		var direction: Vector3 = target.global_position - global_position
		direction.y = 0
		facing = direction.normalized()
	elif move_direction.length() > 0.1:
		facing = move_direction.normalized()
	var data: Dictionary = ATTACKS[id]
	var duration: float = data.startup + data.active + data.recovery
	_play_animation("kick" if id == "focus" else "cross" if id == "counter" else id, duration, true)
	_sound("swing")

func request_dodge() -> void:
	if dead or not active or dodge_cooldown > 0.0 or stagger_timer > 0.0:
		return
	if not attack_id.is_empty() and attack_elapsed < ATTACKS[attack_id].startup + ATTACKS[attack_id].active:
		return
	attack_id = ""
	chain = ""
	queued_action = ""
	queue_timer = 0.0
	animation_hold = 0.0
	guarding = false
	dodge_direction = move_direction.normalized() if move_direction.length() > 0.1 else facing
	dodge_timer = 0.36
	dodge_cooldown = 0.65
	invulnerability = 0.18
	dodge_count += 1
	_play_animation("dodge", 0.36, true)
	_sound("swing")

func request_focus() -> void:
	if focus < 50.0 or dead or not active or not attack_id.is_empty() or stagger_timer > 0.0 or dodge_timer > 0.0:
		return
	focus -= 50.0
	chain = ""
	guarding = false
	_start_attack("focus")
	message.emit("ส่งงานนาทีสุดท้าย!")
	invulnerability = 0.5

func request_interact() -> void:
	if dead or not active or stagger_timer > 0.0 or not attack_id.is_empty() or dodge_timer > 0.0:
		return
	var target := nearest_enemy(2.4, false, true)
	if target:
		var boss: bool = target.is_boss
		target.finish()
		if not boss:
			heal(8.0)
		_play_animation("kick", 0.65, true)
		animation_hold = 0.55
		stagger_timer = 0.35
		invulnerability = 0.85
		camera_rig.shake = 0.32
		message.emit("ปิดงาน!" if not boss else "เปิดช่องอาจารย์!")
		_sound("heavy")
	elif stage_ref and stage_ref.consume_prop(self, facing):
		_play_animation("throw", 0.55, true)
		animation_hold = 0.45
		stagger_timer = 0.35
		_sound("swing")

func _physics_process(delta: float) -> void:
	if not active:
		return
	if dead:
		velocity.x = move_toward(velocity.x, 0.0, delta * 12.0)
		velocity.z = move_toward(velocity.z, 0.0, delta * 12.0)
		if not is_on_floor(): velocity.y -= 20.0 * delta
		move_and_slide()
		return
	parry_timer = maxf(0, parry_timer - delta)
	animation_hold = maxf(0, animation_hold - delta)
	counter_timer = maxf(0, counter_timer - delta)
	invulnerability = maxf(0, invulnerability - delta)
	dodge_cooldown = maxf(0, dodge_cooldown - delta)
	stagger_timer = maxf(0, stagger_timer - delta)
	chain_timer = maxf(0, chain_timer - delta)
	queue_timer = maxf(0, queue_timer - delta)
	combo_display_timer = maxf(0, combo_display_timer - delta)
	if combo_display_timer <= 0: combo_hits = 0
	last_hit_time += delta
	if last_hit_time > 2.0: posture = maxf(0.0, posture - 22.0 * delta)
	# Retained camera-relative movement mapping from Jeh3no WalkState.
	var move_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back").rotated(-camera_rig.global_rotation.y)
	move_direction = Vector3(move_dir.x, 0, move_dir.y)
	if not is_on_floor(): velocity.y -= 20.0 * delta
	if global_position.y < -8.0:
		if god_mode:
			# Immortality must not leave the player falling forever outside the map.
			global_position = stage_ref.get_spawn_position() if is_instance_valid(stage_ref) else Vector3(0, 0.12, 0)
			velocity = Vector3.ZERO
			reset_physics_interpolation()
			camera_rig.snap_to_target()
			return
		receive_hit(1000.0, 0.0, global_position, true)
		return
	if hit_pause > 0.0:
		hit_pause -= delta
		if animation_player: animation_player.speed_scale = 0.0
		return
	if animation_player and animation_player.speed_scale == 0.0:
		animation_player.speed_scale = 1.0
	if dodge_timer > 0.0:
		dodge_timer -= delta
		velocity.x = dodge_direction.x * 8.2
		velocity.z = dodge_direction.z * 8.2
	elif stagger_timer > 0.0:
		velocity.x = move_toward(velocity.x, 0.0, delta * 18.0)
		velocity.z = move_toward(velocity.z, 0.0, delta * 18.0)
	elif not attack_id.is_empty():
		visual.rotation.y = rotate_toward(visual.rotation.y, atan2(-facing.x, -facing.z), 26.0 * delta)
		_tick_attack(delta)
		velocity.x = move_toward(velocity.x, 0.0, delta * 15.0)
		velocity.z = move_toward(velocity.z, 0.0, delta * 15.0)
	else:
		guarding = Input.is_action_pressed("guard")
		var speed := 2.1 if guarding else move_speed
		velocity.x = lerpf(velocity.x, move_dir.x * speed, minf(1.0, move_accel * delta))
		velocity.z = lerpf(velocity.z, move_dir.y * speed, minf(1.0, move_accel * delta))
		if move_direction.length() > 0.1:
			facing = move_direction.normalized()
			visual.rotation.y = rotate_toward(visual.rotation.y, atan2(-facing.x, -facing.z), model_rot_speed * delta)
		_update_locomotion()
		step_timer -= delta
		if move_dir.length() > 0.1 and is_on_floor() and step_timer <= 0.0:
			_sound("step")
			step_timer = 0.33
	move_and_slide()

func _tick_attack(delta: float) -> void:
	attack_elapsed += delta
	var data: Dictionary = ATTACKS[attack_id]
	if attack_elapsed < data.startup:
		velocity.x = facing.x * 1.7
		velocity.z = facing.z * 1.7
	if attack_elapsed >= data.startup and attack_elapsed <= data.startup + data.active:
		_strike_targets(data)
	if attack_elapsed >= data.startup + data.active + data.recovery:
		var finished_chain := chain
		var finished_attack := attack_id
		attack_id = ""
		chain_timer = 0.6
		if finished_chain in ["LLL", "LLH", "LHL"] or finished_attack == "counter":
			if attack_connected:
				var combo_id := "COUNTER" if finished_attack == "counter" else finished_chain
				var completed_on_target := false
				for enemy in get_tree().get_nodes_in_group("enemies"):
					if not is_instance_valid(enemy): continue
					var count: int = chain_targets.get(enemy.get_instance_id(), 0)
					var landed := hit_targets.has(enemy.get_instance_id()) if finished_attack == "counter" else count >= finished_chain.length()
					if landed:
						completed_on_target = true
						if not enemy.dead and enemy.is_boss: enemy.notify_combo(combo_id)
				if completed_on_target:
					combo_completed.emit(combo_id)
					last_combo_name = {"LLL": "เช็คชื่อครบสาม", "LLH": "ส่งออกนอกห้อง", "LHL": "แก้งานรอบสุดท้าย", "COUNTER": "ขอเถียงด้วยหลักฐาน"}.get(combo_id, combo_id)
					message.emit(last_combo_name)
			chain = ""
		if queue_timer > 0.0 and not queued_action.is_empty():
			var next := queued_action
			queued_action = ""
			queue_timer = 0.0
			request_attack(next)

func _strike_targets(data: Dictionary) -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or enemy.dead or hit_targets.has(enemy.get_instance_id()):
			continue
		var direction: Vector3 = enemy.global_position - global_position
		var distance: float = Vector2(direction.x, direction.z).length()
		if distance > float(data.range) or absf(direction.y) > 2.0:
			continue
		direction.y = 0
		var arc := -0.2 if attack_id == "sweep" else 0.30
		if distance > 0.15 and facing.dot(direction.normalized()) < arc:
			continue
		var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP, enemy.global_position + Vector3.UP, 1)
		if not get_world_3d().direct_space_state.intersect_ray(query).is_empty():
			continue
		hit_targets[enemy.get_instance_id()] = true
		var result: String = enemy.take_hit(data.damage, data.posture, global_position, data.force, data.heavy)
		var success := result == "hit"
		attack_connected = attack_connected or success
		if success:
			chain_targets[enemy.get_instance_id()] = int(chain_targets.get(enemy.get_instance_id(), 0)) + 1
			combo_hits += 1
			combo_display_timer = 3.0
			focus = minf(100.0, focus + 4.0)
			camera_rig.shake = 0.22 if data.heavy else 0.10
			hit_pause = 0.045 if data.heavy else 0.025
			FX.burst(get_parent(), enemy.global_position + Vector3.UP, Color("ffb05a") if data.heavy else Color("fcf3d8"), data.heavy)
			_sound("heavy" if data.heavy else "hit")
		else:
			_sound("block")

func nearest_enemy(radius: float, require_front: bool = false, finish_only: bool = false) -> Node3D:
	var result: Node3D = null
	var best := radius
	var preference: Vector3 = move_direction.normalized() if move_direction.length() > 0.1 else facing
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or enemy.dead:
			continue
		if finish_only and not enemy.can_finish():
			continue
		var direction: Vector3 = enemy.global_position - global_position
		direction.y = 0
		var distance := direction.length()
		if distance >= best:
			continue
		if require_front and distance > 0.2 and preference.dot(direction.normalized()) < 0.0:
			continue
		if finish_only:
			var sight := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP, enemy.global_position + Vector3.UP, 1)
			if not get_world_3d().direct_space_state.intersect_ray(sight).is_empty():
				continue
		best = distance
		result = enemy
	return result

func receive_hit(damage: float, structure: float, from: Vector3, unblockable: bool = false) -> String:
	if dead or not active or invulnerability > 0.0:
		return "dodged"
	if god_mode:
		return "invulnerable"
	var direction := from - global_position
	direction.y = 0
	var frontal := direction.length() < 0.1 or facing.dot(direction.normalized()) >= -0.1
	last_hit_time = 0.0
	if guarding and frontal and not unblockable and stagger_timer <= 0.0:
		if parry_timer > 0.0:
			parry_timer = 0.0
			counter_timer = 0.65
			focus = minf(100.0, focus + 20.0)
			posture = maxf(0.0, posture - 12.0)
			parry_count += 1
			_play_animation("parry", 0.2, true)
			animation_hold = 0.18
			FX.burst(get_parent(), global_position + Vector3.UP + facing * 0.6, Color("7be8e0"), true)
			message.emit("ปัดป้อง!  คลิกซ้ายเพื่อสวน")
			_sound("parry")
			return "parried"
		posture = minf(100.0, posture + structure)
		_sound("block")
		if posture < 100.0:
			return "blocked"
		posture = 55.0
		stagger_timer = 0.9
		message.emit("เสียหลัก! อย่ารับทุกหมัดด้วยการ์ด")
	else:
		stagger_timer = 0.28
	health = maxf(0.0, health - damage)
	damage_taken += damage
	invulnerability = maxf(stagger_timer + 0.25, 0.5)
	attack_id = ""
	chain = ""
	queued_action = ""
	guarding = false
	combo_hits = 0
	velocity.x = -direction.normalized().x * 2.6
	velocity.z = -direction.normalized().z * 2.6
	camera_rig.shake = 0.35
	_play_animation("hit", 0.3, true)
	animation_hold = 0.25
	_sound("hurt")
	if health <= 0.0:
		dead = true
		_play_animation("death", 1.2, true)
		defeated.emit()
	return "hit"

func heal(amount: float) -> void:
	health = minf(max_health, health + amount)

func _sound(id: String) -> void:
	if is_instance_valid(audio_ref): audio_ref.play_effect(id)
