extends CharacterBody3D
class_name TeacherAlly

const Campaign = preload("res://Scripts/campaign_data.gd")
const WorldLabel = preload("res://Scripts/world_label.gd")
const FX = preload("res://Scripts/combat_fx.gd")
const ATTACK_WINDUP := 0.20
const ATTACK_RECOVERY := 0.65
const ATTACK_COOLDOWN := 2.2
const ATTACK_RANGE := 1.85
const ACQUIRE_RADIUS := 5.5
const SCAN_INTERVAL := 0.2

var teacher_index := 0
var rescued := false
var animator: AnimationPlayer
var clips: Dictionary = {}
var caption: Label3D
var indicator: MeshInstance3D
var animation_time := 0.0
var stage: Node3D
var player: Node3D
var arena_center := Vector3.ZERO
var arena_half_size := Vector2(6.3, 7.6)
var target: Node3D
var current_clip := ""
var locomotion_clip := "idle"
var locomotion_rate := 1.0
var combat_state := "follow"
var attack_time := 0.0
var attack_cooldown := 0.0
var attack_applied := false
var scan_time := 0.0
var landed_hits := 0
var support_tween: Tween
var steering_side := 1.0

func _ready() -> void:
	# World collision keeps feet out of scenery; layer zero never obstructs actors.
	add_to_group("teacher_allies")
	collision_layer = 0
	collision_mask = 1
	floor_snap_length = 0.35
	process_mode = Node.PROCESS_MODE_PAUSABLE
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.28
	capsule.height = 1.7
	collider.shape = capsule
	collider.position.y = 0.85
	add_child(collider)
	steering_side = 1.0 if teacher_index % 2 == 0 else -1.0
	var path := "res://Assets/Models/teacher_%s.glb" % ["programming", "ai", "web"][teacher_index]
	if ResourceLoader.exists(path):
		var packed: PackedScene = load(path)
		var model := packed.instantiate() as Node3D
		add_child(model)
		animator = _find_animator(model)
		if animator:
			animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE
			for clip in animator.get_animation_list():
				var key := String(clip).get_slice("/", String(clip).get_slice_count("/") - 1).to_lower()
				clips[key] = clip
			_play("idle")
	caption = Label3D.new()
	WorldLabel.apply(caption, 64, 0.0022)
	caption.position.y = 2.2
	caption.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(caption)
	indicator = MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.48
	ring.outer_radius = 0.52
	ring.rings = 24
	ring.ring_segments = 6
	indicator.mesh = ring
	indicator.scale.y = 0.12
	indicator.position.y = 0.055
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("64dbe5")
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	indicator.material_override = material
	add_child(indicator)
	set_rescued(rescued)

func set_rescued(value: bool) -> void:
	rescued = value
	if is_instance_valid(caption):
		caption.text = Campaign.TEACHER_NAMES[teacher_index].replace("อาจารย์", "อ.") + ("" if rescued else "\nช่วยอาจารย์!")
		caption.modulate = Color("a5eff0") if rescued else Color("ffe2ad")

func show_support() -> void:
	_cancel_attack()
	animation_time = 1.0
	_play("guard", 0.0, true)
	if support_tween and support_tween.is_valid(): support_tween.kill()
	support_tween = create_tween()
	support_tween.tween_property(indicator, "scale", Vector3(1.55, 0.12, 1.55), 0.18)
	support_tween.tween_property(indicator, "scale", Vector3(1.0, 0.12, 1.0), 0.6)

func get_combat_status() -> String:
	if not rescued: return "รอช่วยเหลือ"
	if not _can_act(): return "รอไปต่อ"
	if animation_time > 0.0: return "ช่วยร่ายสกิล"
	if combat_state == "attack": return "กำลังช่วยโจมตี"
	if is_instance_valid(target): return "เข้าสกัดปีศาจ"
	return "ตามมาช่วย" if Vector2(velocity.x, velocity.z).length() > 0.2 else "พร้อมช่วยสู้"

func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED:
		_cancel_attack()
		velocity = Vector3.ZERO

func _can_act() -> bool:
	return rescued and is_instance_valid(stage) and is_instance_valid(player) and stage._player_can_act()

func _physics_process(delta: float) -> void:
	if not _can_act():
		_cancel_attack()
		velocity = Vector3.ZERO
		_play("idle")
		return
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	animation_time = maxf(0.0, animation_time - delta)
	if not is_on_floor(): velocity.y -= 20.0 * delta
	else: velocity.y = -0.1
	if animation_time > 0.0:
		_move_toward_point(global_position, delta, 0.0)
		return
	if stage.combat_cleared or stage.room_clear[stage.checkpoint_index]:
		_cancel_attack()
	elif combat_state == "attack":
		_tick_attack(delta)
		_move_toward_point(global_position, delta, 0.0)
		return
	else:
		if not is_instance_valid(target) or not _valid_target(target): target = null
		scan_time -= delta
		if scan_time <= 0.0:
			scan_time = SCAN_INTERVAL
			if is_instance_valid(target) and not _has_line_of_sight(target): target = null
			if not is_instance_valid(target): target = _choose_target()
	if is_instance_valid(target):
		var direction := target.global_position - global_position
		direction.y = 0.0
		_face(direction, delta)
		if direction.length() <= ATTACK_RANGE and attack_cooldown <= 0.0 and _within_facing(direction, 0.65) and _has_line_of_sight(target):
			combat_state = "attack"
			attack_time = 0.0
			attack_applied = false
			attack_cooldown = ATTACK_COOLDOWN
			_play("jab", ATTACK_WINDUP + ATTACK_RECOVERY, true)
			_move_toward_point(global_position, delta, 0.0)
			return
		var goal := target.global_position - direction.normalized() * 1.45
		_move_toward_point(_bound_to_room(goal), delta, 4.0)
	else:
		var facing: Vector3 = player.facing
		var side := Vector3(-facing.z, 0.0, facing.x)
		var follow_point := player.global_position - facing * 1.75 + side * steering_side * 1.35
		_move_toward_point(_bound_to_room(follow_point), delta, 5.2)
	_update_locomotion(delta)

func _valid_target(enemy: Node3D) -> bool:
	if not is_instance_valid(enemy) or enemy.is_queued_for_deletion(): return false
	if enemy not in stage.active_enemies or enemy.dead or enemy.broken or enemy.is_core or enemy.shielded: return false
	if not enemy.has_method("take_ally_hit"): return false
	var local_point := enemy.global_position - arena_center
	var closest_point := _bound_to_room(enemy.global_position)
	var reach_offset := enemy.global_position - closest_point
	# Account for arrival tolerance: do not wait forever for an unreachable corner.
	if Vector2(reach_offset.x, reach_offset.z).length() > ATTACK_RANGE - 0.3: return false
	return absf(local_point.x) <= 8.2 and absf(local_point.z) <= 8.9 and enemy.global_position.distance_to(player.global_position) <= ACQUIRE_RADIUS

func _choose_target() -> Node3D:
	var nearest: Node3D
	var best := INF
	for enemy in stage.active_enemies:
		if not is_instance_valid(enemy) or not _valid_target(enemy) or not _has_line_of_sight(enemy): continue
		var distance := global_position.distance_squared_to(enemy.global_position)
		if distance < best:
			nearest = enemy
			best = distance
	return nearest

func _has_line_of_sight(enemy: Node3D) -> bool:
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP, enemy.global_position + Vector3.UP, 1)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func _tick_attack(delta: float) -> void:
	if not is_instance_valid(target) or not _valid_target(target):
		_cancel_attack()
		_play("idle")
		return
	attack_time += delta
	_face(target.global_position - global_position, delta)
	if not attack_applied and attack_time >= ATTACK_WINDUP:
		attack_applied = true
		var offset := target.global_position - global_position
		if Vector2(offset.x, offset.z).length() <= ATTACK_RANGE and absf(offset.y) < 1.8 and _within_facing(offset, 0.4) and _has_line_of_sight(target):
			var result: String = target.take_ally_hit(8.0, 10.0, global_position, 0.0)
			if result == "hit":
				landed_hits += 1
				FX.burst(player.get_parent(), target.global_position + Vector3.UP, Color("81d8de"), false)
	if attack_time >= ATTACK_WINDUP + ATTACK_RECOVERY:
		combat_state = "follow"
		_play("idle")

func _cancel_attack() -> void:
	target = null
	combat_state = "follow"
	attack_time = 0.0
	attack_applied = false
	scan_time = 0.0

func _bound_to_room(point: Vector3) -> Vector3:
	return Vector3(clampf(point.x, arena_center.x - arena_half_size.x, arena_center.x + arena_half_size.x), global_position.y, clampf(point.z, arena_center.z - arena_half_size.y, arena_center.z + arena_half_size.y))

func _move_toward_point(point: Vector3, delta: float, speed: float) -> void:
	var offset := point - global_position
	offset.y = 0.0
	var desired := offset.normalized() * minf(speed, offset.length() * 3.0) if offset.length() > 0.28 else Vector3.ZERO
	# Keep a gap without collision layers that would trap the student in a doorway.
	if speed > 0.0:
		var away := global_position - player.global_position
		away.y = 0.0
		if away.length() > 0.01 and away.length() < 1.15: desired += away.normalized() * (1.15 - away.length()) * 3.0
		if desired.length() > 0.1 and test_move(global_transform, desired.normalized() * 0.55):
			var right := desired.rotated(Vector3.UP, steering_side * PI / 3.0)
			var left := desired.rotated(Vector3.UP, -steering_side * PI / 3.0)
			if not test_move(global_transform, right.normalized() * 0.55): desired = right
			elif not test_move(global_transform, left.normalized() * 0.55): desired = left
			else: desired = Vector3.ZERO
	velocity.x = move_toward(velocity.x, desired.x, delta * 14.0)
	velocity.z = move_toward(velocity.z, desired.z, delta * 14.0)
	move_and_slide()
	if not is_instance_valid(target): _face(get_real_velocity(), delta)

func _face(direction: Vector3, delta: float) -> void:
	direction.y = 0.0
	if direction.length() > 0.1: rotation.y = rotate_toward(rotation.y, atan2(-direction.x, -direction.z), delta * 8.0)

func _within_facing(direction: Vector3, minimum_dot: float) -> bool:
	direction.y = 0.0
	return direction.length() <= 0.01 or (-global_transform.basis.z).dot(direction.normalized()) >= minimum_dot

func _update_locomotion(delta: float) -> void:
	var speed := Vector2(get_real_velocity().x, get_real_velocity().z).length()
	if speed < 0.12: locomotion_clip = "idle"
	elif speed > 3.2: locomotion_clip = "run"
	elif speed < 2.7 or locomotion_clip == "idle": locomotion_clip = "walk"
	_play(locomotion_clip)
	if animator:
		var wanted_rate := clampf(speed / (4.5 if locomotion_clip == "run" else 2.0), 0.65, 1.2) if locomotion_clip in ["walk", "run"] else 1.0
		locomotion_rate = lerpf(locomotion_rate, wanted_rate, 1.0 - exp(-12.0 * delta))
		animator.speed_scale = locomotion_rate

func _play(key: String, duration: float = 0.0, force: bool = false) -> void:
	if animator == null or not clips.has(key) or (current_clip == key and not force): return
	var phase := -1.0
	if key in ["walk", "run"] and current_clip in ["walk", "run"]:
		phase = fposmod(animator.current_animation_position / maxf(0.001, animator.current_animation_length), 1.0)
	var recovering := key in ["idle", "walk", "run", "guard"] and current_clip not in ["idle", "walk", "run", "guard"]
	current_clip = key
	var animation := animator.get_animation(clips[key])
	animation.loop_mode = Animation.LOOP_LINEAR if key in ["idle", "walk", "run", "guard"] else Animation.LOOP_NONE
	animator.speed_scale = 1.0
	animator.play(clips[key], 0.22 if recovering else 0.18 if key in ["idle", "walk", "run", "guard"] else 0.08, animation.length / duration if duration > 0.0 else 1.0)
	if phase >= 0.0: animator.seek(phase * animation.length)

func _find_animator(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_animator(child)
		if found:
			return found
	return null
