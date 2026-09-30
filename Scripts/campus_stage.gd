extends Node3D
class_name CampusStage

signal encounter_changed(checkpoint: int, title: String)
signal stage_completed

const Campaign = preload("res://Scripts/campaign_data.gd")
const CampusEnvironmentBuilder = preload("res://Scripts/campus_environment.gd")
const TeacherScript = preload("res://Scripts/teacher_ally.gd")
const EnemyScript = preload("res://Scripts/school_enemy.gd")
const PropScript = preload("res://Scripts/interactable_prop.gd")
const CAMPUS_FONT = preload("res://Assets/Fonts/NotoSansThai.ttf")
static var _model_scenes: Dictionary = {}

const STAGE_TITLES = Campaign.STAGE_NAMES
const ROOM_TITLES = Campaign.ROOM_TITLES
const ENCOUNTERS = Campaign.ENCOUNTERS
const INTRO_LINES = Campaign.INTRO_LINES
const OBJECTIVE_TITLES = Campaign.OBJECTIVE_TITLES
const SUPPORT_COOLDOWN := 15.0
const WEB_SECOND_WAVE := ["demon_imp", "demon_brute", "demon_caster"]

var stage_index := 0
var checkpoint_index := 0
var player: Node3D
var active_enemies: Array[Node] = []
var pending_enemies: Array[String] = []
var props: Array[Node] = []
var gates: Array[Node3D] = []
var gate_colliders: Array[CollisionShape3D] = []
var exit_labels: Array[Label3D] = []
var room_clear: Array[bool] = [false, false, false]
var encounter_started := false
var completed := false
var final_core_created := false
var spawn_serial := 0
var next_spawn_delay := 0.0
var boss: Node
var checkpoint_props: Node3D
var built := false
var accent := Color("dfa664")
var materials: Dictionary = {}
var total_defeated := 0
var last_support_notice := false
var elapsed := 0.0
var gate_tweens: Array[Tween] = []
var _visual_regions: Array[Node3D] = []
var _batch_region := 0
var _static_batches: Dictionary = {}
var _unit_cube: BoxMesh
var static_instance_count := 0
var static_batch_count := 0
var render_quality := 1
var _room_lights: Array = [[], [], []]
var _room_key_lights: Array[OmniLight3D] = [null, null, null]

# Geometry supplies local-space markers; progression never relies on a fixed axis.
var room_centers: Array[Vector3] = [Vector3.ZERO, Vector3(0, 0, -24), Vector3(0, 0, -48)]
var spawn_markers: Array[Vector3] = [Vector3(0, 0.12, 6), Vector3(0, 0.12, -18), Vector3(0, 0.12, -42)]
var exit_markers: Array[Vector3] = [Vector3(0, 0, -10), Vector3(0, 0, -34), Vector3(0, 0, -58)]
var objective_markers: Array[Vector3] = [Vector3(3, 0, -5.5), Vector3(3, 0, -29.5), Vector3(3, 0, -53.5)]
var ally_markers: Array[Vector3] = [Vector3(-4, 0, 3.5), Vector3(-4, 0, -20.5), Vector3(-4, 0, -44.5)]
var teacher: Node3D
var teacher_rescued := false
var support_cooldown := 0.0
var support_time := 0.0
var support_center := Vector3.ZERO
var support_visual: MeshInstance3D
var objective_node: Node3D
var objective_label: Label3D
var combat_cleared := false
var objective_completed := false
var wave_index := 1
var defeated_ids: Dictionary = {}

func _ready() -> void:
	stage_index = clampi(stage_index, 0, 2)
	checkpoint_index = clampi(checkpoint_index, 0, 2)
	accent = [Color("edb66c"), Color("68d4cf"), Color("f16b91")][stage_index]
	_unit_cube = BoxMesh.new()
	_unit_cube.size = Vector3.ONE
	for index in range(4):
		var region := Node3D.new()
		region.name = "RoomVisuals%d" % index if index < 3 else "CampusExteriorVisuals"
		region.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		add_child(region)
		_visual_regions.append(region)
	_build_campus()
	_flush_static_batches()
	var stage_kinds: Array = []
	for room_kinds in ENCOUNTERS[stage_index]:
		for enemy_kind in room_kinds:
			if enemy_kind not in stage_kinds: stage_kinds.append(enemy_kind)
	if stage_index == 2: stage_kinds.append("server_core")
	EnemyScript.preload_models(stage_kinds)
	reset_physics_interpolation()
	built = true

func start(new_player: Node3D) -> void:
	player = new_player
	if not built:
		return
	for index in range(checkpoint_index):
		room_clear[index] = true
		_open_gate(index, false)
	_start_encounter(checkpoint_index)

func get_spawn_position() -> Vector3:
	return to_global(spawn_markers[checkpoint_index])

func get_objective() -> String:
	if completed:
		return "ผนึกประตูมิติสำเร็จ • มหาวิทยาลัยปลอดภัย"
	if room_clear[checkpoint_index]:
		return "เดินผ่านประตูสีเขียวไปพื้นที่ถัดไป"
	if combat_cleared:
		return "E ใกล้จุดสีฟ้า • %s" % OBJECTIVE_TITLES[stage_index][checkpoint_index]
	if checkpoint_index == 2:
		if is_instance_valid(boss) and boss.shielded:
			return "ทำลายเสาคำสาปสีม่วง เพื่อเปิดโล่บอส"
		return "ร่วมกับอาจารย์กำจัด %s" % Campaign.BOSS_NAMES[stage_index]
	var wave := " • ระลอก %d/2" % wave_index if stage_index == 2 and checkpoint_index == 1 else ""
	return "กำจัดปีศาจ • เหลือ %d ตัว%s" % [get_remaining(), wave]

func get_boss() -> Node:
	if is_instance_valid(boss) and not boss.dead:
		return boss
	return null

func get_remaining() -> int:
	var count := pending_enemies.size()
	for enemy in active_enemies:
		if is_instance_valid(enemy) and not enemy.dead:
			count += 1
	return count

func request_attack(requester: Node, wants_ranged: bool) -> bool:
	var attacks := 0
	var ranged_attacks := 0
	for enemy in active_enemies:
		if not is_instance_valid(enemy) or enemy == requester or enemy.dead:
			continue
		if enemy.is_attacking:
			attacks += 1
			if enemy.ranged:
				ranged_attacks += 1
	return attacks < 2 and (not wants_ranged or ranged_attacks < 1)

func restart_encounter() -> void:
	encounter_started = false
	for enemy in active_enemies:
		if is_instance_valid(enemy): enemy.queue_free()
	active_enemies.clear()
	_clear_projectiles()
	pending_enemies.clear()
	boss = null
	completed = false
	room_clear[checkpoint_index] = false
	_close_gate(checkpoint_index)
	if is_instance_valid(player):
		player.global_position = get_spawn_position()
		player.reset_physics_interpolation()
	_start_encounter(checkpoint_index)

func _start_encounter(index: int) -> void:
	checkpoint_index = index
	encounter_started = true
	spawn_serial = 0
	next_spawn_delay = 0.1
	room_clear[index] = false
	combat_cleared = false
	objective_completed = false
	final_core_created = false
	wave_index = 1
	defeated_ids.clear()
	active_enemies.clear()
	pending_enemies.clear()
	for enemy_kind in ENCOUNTERS[stage_index][index]: pending_enemies.append(enemy_kind)
	_setup_props(index)
	_setup_mission(index)
	_update_visual_quality()
	encounter_changed.emit(index, ROOM_TITLES[stage_index][index])
	if index == 2:
		_toast("%s: “%s”" % [Campaign.TEACHER_NAMES[stage_index], INTRO_LINES[stage_index]], 4.0)
	elif stage_index == 0 and index == 0:
		_toast("ช่วยอาจารย์ที่ถูกล้อม! WASD เดิน • คลิกซ้ายต่อคอมโบ • Shift ปัดป้อง • Space หลบ", 5.0)
	elif stage_index == 2 and index == 1:
		_toast("อาจารย์กำลังเปิดเครื่องผนึก! ป้องกันปีศาจ 2 ระลอก • T กางกำแพง", 5.0)
	else:
		_toast("%s • T ขอแรงอาจารย์ • E ใช้อุปกรณ์เมื่อพื้นที่ปลอดภัย" % OBJECTIVE_TITLES[stage_index][index], 4.5)

func apply_render_quality(quality: int) -> void:
	render_quality = clampi(quality, 0, 1)
	_update_visual_quality()

func register_room_light(light: OmniLight3D, room: int, primary: bool = false) -> void:
	_room_lights[room].append(light)
	if primary or _room_key_lights[room] == null:
		_room_key_lights[room] = light

func _update_visual_quality() -> void:
	if _visual_regions.size() < 3: return
	for room in range(3):
		var nearby := absi(room - checkpoint_index) <= 1
		_visual_regions[room].visible = nearby
		# Keep neighboring architecture readable without lighting it with every accent.
		for light: OmniLight3D in _room_lights[room]:
			light.visible = nearby and (light == _room_key_lights[room] or (render_quality > 0 and room == checkpoint_index))

func _physics_process(delta: float) -> void:
	if not encounter_started or completed or not is_instance_valid(player) or get_tree().paused:
		return
	elapsed += delta
	support_cooldown = maxf(0.0, support_cooldown - delta)
	support_time = maxf(0.0, support_time - delta)
	if is_instance_valid(support_visual):
		support_visual.visible = support_time > 0.0
		if support_time > 0.0: support_visual.rotate_y(delta * 0.35)
	next_spawn_delay -= delta
	if next_spawn_delay <= 0 and not pending_enemies.is_empty() and _alive_count() < 4:
		_spawn_enemy(pending_enemies.pop_front())
		next_spawn_delay = 0.65
	if room_clear[checkpoint_index]:
		var point := to_local(player.global_position)
		var exit := exit_markers[checkpoint_index]
		var forward := (exit - room_centers[checkpoint_index]).normalized()
		var offset := point - exit
		var across: float = offset.dot(forward)
		var lateral: float = (offset - forward * across).length()
		if across > 1.0 and lateral < 2.6:
			if checkpoint_index < 2: _start_encounter(checkpoint_index + 1)
			elif stage_index < 2: _complete_stage()
	for enemy in active_enemies:
		if is_instance_valid(enemy) and not enemy.dead and not enemy.broken and enemy.kind == "tablet" and enemy.mode not in ["telegraph", "attack"]:
			enemy.telegraph.visible = true
			enemy.telegraph.scale.x = 1.5
			enemy.telegraph.scale.z = 1.5
			enemy.telegraph_material.albedo_color = Color("bd69e5")

func _setup_mission(index: int) -> void:
	if is_instance_valid(teacher): teacher.queue_free()
	if is_instance_valid(objective_node): objective_node.queue_free()
	if is_instance_valid(support_visual): support_visual.queue_free()
	support_visual = null
	support_cooldown = 0.0
	support_time = 0.0
	teacher_rescued = stage_index > 0 or index > 0
	teacher = TeacherScript.new()
	teacher.teacher_index = stage_index
	teacher.rescued = teacher_rescued
	teacher.position = ally_markers[index]
	teacher.rotation.y = PI
	add_child(teacher)
	objective_node = Node3D.new()
	objective_node.name = "MissionDevice"
	objective_node.position = objective_markers[index]
	add_child(objective_node)
	var device_kind := "cabinet" if stage_index == 0 else "terminal"
	if checkpoint_index == 2 and stage_index > 0 or stage_index == 2 and checkpoint_index == 1: device_kind = "seal"
	_build_objective_device(device_kind)
	var ring := MeshInstance3D.new()
	var ring_shape := TorusMesh.new()
	ring_shape.inner_radius = 0.9
	ring_shape.outer_radius = 1.03
	ring_shape.rings = 32
	ring_shape.ring_segments = 6
	ring.mesh = ring_shape
	ring.scale.y = 0.13
	ring.position.y = 0.04
	ring.material_override = _material(Color("61def0"), 0.4, 0.9)
	objective_node.add_child(ring)
	objective_label = Label3D.new()
	objective_label.font = CAMPUS_FONT
	objective_label.font_size = 38
	objective_label.pixel_size = 0.003
	objective_label.position.y = 1.6
	objective_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	objective_label.modulate = Color("a0f0ef")
	objective_label.text = OBJECTIVE_TITLES[stage_index][index] + "\nกำจัดปีศาจก่อน"
	objective_node.add_child(objective_label)

func _device_mesh(shape: Mesh, at: Vector3, color: Color, glow: float = 0.0) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	item.mesh = shape
	item.position = at
	item.material_override = _material(color, 0.65, glow)
	objective_node.add_child(item)
	return item

func _device_box(size: Vector3, at: Vector3, color: Color, glow: float = 0.0) -> void:
	var shape := BoxMesh.new()
	shape.size = size
	_device_mesh(shape, at, color, glow)

func _build_objective_device(device_kind: String) -> void:
	# Distinct visual affordances share E interaction and never obstruct a combat lane.
	match device_kind:
		"cabinet":
			_device_box(Vector3(0.9, 1.35, 0.55), Vector3(0, 0.675, 0), Color("4b656e"))
			_device_box(Vector3(0.72, 0.82, 0.04), Vector3(0, 0.76, 0.3), Color("233845"))
			for index in range(3):
				_device_box(Vector3(0.13, 0.23, 0.07), Vector3(-0.23 + index * 0.23, 0.73, 0.34), Color("83d7e1"), 0.4)
			_device_box(Vector3(0.62, 0.09, 0.05), Vector3(0, 1.22, 0.31), Color("e2c176"), 0.3)
		"terminal":
			_device_box(Vector3(0.68, 0.7, 0.65), Vector3(0, 0.35, 0), Color("35434c"))
			_device_box(Vector3(1.0, 0.64, 0.12), Vector3(0, 1.04, -0.16), Color("304b58"))
			_device_box(Vector3(0.85, 0.47, 0.025), Vector3(0, 1.05, -0.083), Color("78ccd9"), 0.6)
			_device_box(Vector3(0.76, 0.055, 0.35), Vector3(0, 0.74, 0.14), Color("688c97"))
		"seal":
			var stone := CylinderMesh.new()
			stone.top_radius = 0.72
			stone.bottom_radius = 0.86
			stone.height = 0.55
			stone.radial_segments = 8
			_device_mesh(stone, Vector3(0, 0.275, 0), Color("6e747b"))
			var seal := TorusMesh.new()
			seal.inner_radius = 0.35
			seal.outer_radius = 0.43
			seal.rings = 24
			seal.ring_segments = 6
			_device_mesh(seal, Vector3(0, 0.61, 0), Color("8ae4ea"), 1.2)
			for index in range(4):
				var angle := float(index) * PI / 2.0
				_device_box(Vector3(0.12, 0.3, 0.12), Vector3(sin(angle) * 0.61, 0.67, cos(angle) * 0.61), Color("bcdbc9"), 0.4)

func _player_can_act() -> bool:
	if get_tree().paused or completed or not is_instance_valid(player): return false
	if player.get("dead") == true or player.get("active") == false or player.get("health") == 0: return false
	var game := get_tree().get_first_node_in_group("game")
	if game and game.get("modal") is Control and game.modal.visible: return false
	return true

func request_teacher_support() -> bool:
	if not _player_can_act() or not teacher_rescued or support_cooldown > 0.0: return false
	support_cooldown = SUPPORT_COOLDOWN
	teacher.show_support()
	_play_audio("support")
	support_center = player.global_position
	if stage_index < 2:
		var radius := 6.0 if stage_index == 0 else 9.0
		for enemy in active_enemies:
			if is_instance_valid(enemy) and not enemy.dead and enemy.global_position.distance_to(support_center) <= radius:
				enemy.apply_teacher_support(stage_index)
		support_time = 1.0
		_show_support_ring(radius, Color("69ddec") if stage_index == 0 else Color("94dba8"))
	else:
		support_time = 6.0
		_show_support_ring(3.4, Color("76beff"))
	_toast("%s: %s!" % [Campaign.TEACHER_NAMES[stage_index], Campaign.SUPPORT_NAMES[stage_index]], 2.5)
	return true

func _show_support_ring(radius: float, color: Color) -> void:
	if is_instance_valid(support_visual): support_visual.queue_free()
	support_visual = MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = radius - 0.09
	ring.outer_radius = radius
	ring.rings = 48
	ring.ring_segments = 6
	support_visual.mesh = ring
	support_visual.scale.y = 0.18
	support_visual.material_override = _material(color, 0.4, 1.2)
	add_child(support_visual)
	support_visual.global_position = support_center + Vector3.UP * 0.08

func get_support_status() -> String:
	if not teacher_rescued: return "T • ช่วยอาจารย์ก่อน"
	if support_cooldown > 0.0: return "T • %s (%d วิ)" % [Campaign.SUPPORT_NAMES[stage_index], ceili(support_cooldown)]
	return "T • %s พร้อม" % Campaign.SUPPORT_NAMES[stage_index]

func support_block_projectile(at: Vector3) -> bool:
	if stage_index != 2 or support_time <= 0.0 or not _player_can_act(): return false
	return Vector2(at.x, at.z).distance_to(Vector2(support_center.x, support_center.z)) <= 3.4 and absf(at.y - support_center.y) < 3.0

func interact_objective(user: Node3D) -> bool:
	if user != player or not _player_can_act() or not combat_cleared or objective_completed: return false
	if not is_instance_valid(objective_node) or user.global_position.distance_to(objective_node.global_position) > 2.5: return false
	var sight := PhysicsRayQueryParameters3D.create(user.global_position + Vector3.UP, objective_node.global_position + Vector3.UP, 1)
	if not get_world_3d().direct_space_state.intersect_ray(sight).is_empty(): return false
	objective_completed = true
	room_clear[checkpoint_index] = true
	objective_label.text = "สำเร็จ • " + OBJECTIVE_TITLES[stage_index][checkpoint_index]
	_clear_projectiles()
	if stage_index == 2 and checkpoint_index == 2:
		_play_audio("seal")
		var portal = get_meta("final_portal_visual", null)
		if is_instance_valid(portal) and portal is Node3D: portal.hide()
		_show_support_ring(2.5, Color("b2f2e3"))
		support_visual.global_position = objective_node.global_position + Vector3.UP * 0.1
		support_time = 2.0
		_complete_stage()
	else:
		_open_gate(checkpoint_index)
		_toast("ภารกิจสำเร็จ! ผ่านประตูสีเขียวไปพื้นที่ถัดไป", 3.5)
	return true

func _complete_stage() -> void:
	if completed: return
	completed = true
	_clear_projectiles()
	stage_completed.emit()

func _alive_count() -> int:
	var result := 0
	for enemy in active_enemies:
		if is_instance_valid(enemy) and not enemy.dead:
			result += 1
	return result

func _spawn_enemy(enemy_kind: String, at: Vector3 = Vector3.INF) -> Node:
	var enemy := EnemyScript.new()
	enemy.kind = enemy_kind
	enemy.stage = self
	enemy.player = player
	enemy.arena_center = to_global(room_centers[checkpoint_index])
	var positions := [Vector3(-3.8, 0.08, -2.5), Vector3(3.8, 0.08, -3.7), Vector3(0, 0.08, -5.0), Vector3(-2.0, 0.08, 0), Vector3(3.6, 0.08, -5.4), Vector3(-4.2, 0.08, -4.5)]
	var spawn_at: Vector3 = positions[spawn_serial % positions.size()] + room_centers[checkpoint_index]
	if enemy_kind in ["programming", "ai", "web"]:
		spawn_at = room_centers[checkpoint_index] + Vector3(0, 0.08, -3.4)
	if enemy_kind == "computer":
		spawn_at.x = 4.0
		spawn_at.z = room_centers[checkpoint_index].z - 5.8
	if at != Vector3.INF:
		spawn_at = at
	enemy.position = spawn_at
	enemy.defeated.connect(_on_enemy_defeated)
	add_child(enemy)
	enemy.reset_physics_interpolation()
	active_enemies.append(enemy)
	spawn_serial += 1
	if enemy.is_boss:
		boss = enemy
	return enemy

func _on_enemy_defeated(enemy: Node) -> void:
	if completed or defeated_ids.has(enemy.get_instance_id()): return
	defeated_ids[enemy.get_instance_id()] = true
	total_defeated += 1
	if enemy.kind == "server_core":
		if is_instance_valid(boss) and not boss.dead: boss.disable_shield()
		return
	if enemy.kind == "web":
		_clear_projectiles()
		for other in active_enemies:
			if is_instance_valid(other) and other != enemy and not other.dead:
				other.dead = true
				other.queue_free()
		pending_enemies.clear()
		final_core_created = true # Compatibility name now means the seal objective is available.
	if get_remaining() > 0: return
	if stage_index == 2 and checkpoint_index == 1 and wave_index == 1:
		wave_index = 2
		for enemy_kind in WEB_SECOND_WAVE: pending_enemies.append(enemy_kind)
		next_spawn_delay = 1.1
		_toast("ระลอกที่ 2/2 • ป้องกันอาจารย์ระหว่างเปิดเครื่องผนึก!", 4.0)
		return
	combat_cleared = true
	_clear_projectiles()
	if not teacher_rescued:
		teacher_rescued = true
		teacher.set_rescued(true)
		_toast("อาจารย์: ขอบใจ! เรื่องเกรดไว้ก่อน ช่วยมหาลัยให้รอด! • T ขอแรงอาจารย์", 5.0)
	else:
		_toast("พื้นที่ปลอดภัยแล้ว! ไปจุดสีฟ้าแล้วกด E • " + OBJECTIVE_TITLES[stage_index][checkpoint_index], 4.5)
	objective_label.text = "E • " + OBJECTIVE_TITLES[stage_index][checkpoint_index]

func spawn_web_core(_owner: Node) -> Node:
	return _spawn_enemy("server_core", room_centers[checkpoint_index] + Vector3(-4.5, 0.08, -3.5))

func _clear_projectiles() -> void:
	for projectile in get_tree().get_nodes_in_group("school_projectiles"):
		if is_ancestor_of(projectile):
			projectile.queue_free()

func consume_prop(user: Node3D, direction: Vector3) -> bool:
	var nearest: Node3D
	var nearest_distance := 3.25
	for prop in props:
		if not is_instance_valid(prop) or not prop.available:
			continue
		var d: float = prop.global_position.distance_to(user.global_position)
		if d < nearest_distance:
			nearest = prop
			nearest_distance = d
	if nearest == null:
		return false
	var target: Node3D
	var best := -100.0
	for enemy in active_enemies:
		if not is_instance_valid(enemy) or enemy.dead:
			continue
		var offset: Vector3 = enemy.global_position - user.global_position
		offset.y = 0
		var dist := offset.length()
		if dist > 12.0 or dist < 0.05:
			continue
		var alignment := direction.normalized().dot(offset.normalized())
		if alignment < 0.1:
			continue
		var score := alignment * 5.0 - dist * 0.16
		if score > best:
			best = score
			target = enemy
	nearest.throw_at(target, direction)
	return true

func _setup_props(index: int) -> void:
	if is_instance_valid(checkpoint_props):
		checkpoint_props.queue_free()
	props.clear()
	checkpoint_props = Node3D.new()
	add_child(checkpoint_props)
	for offset in [Vector3(-5.2, 0, 3.0), Vector3(5.2, 0, -0.5), Vector3(-5.0, 0, -5.7)]:
		var prop := PropScript.new()
		prop.prop_kind = "chair"
		prop.player = player
		prop.stage = self
		prop.position = offset + room_centers[index]
		prop.rotation.y = float(props.size()) * 1.2
		checkpoint_props.add_child(prop)
		prop.reset_physics_interpolation()
		props.append(prop)

func _build_campus() -> void:
	materials["floor"] = _material([Color("928d7d"), Color("445d62"), Color("655465")][stage_index], 0.88)
	materials["wall"] = _material([Color("bbb09a"), Color("799a9c"), Color("988691")][stage_index], 0.9)
	materials["dark"] = _material(Color("233039"), 0.7)
	materials["trim"] = _material(Color("41434a"), 0.55)
	materials["wood"] = _material(Color("956544"), 0.8)
	materials["glass"] = _material([Color("61726d"), Color("18363f"), Color("34354d")][stage_index], 0.38)
	materials["accent"] = _material(accent, 0.55)
	materials["light"] = _material([Color("f1d8a8"), Color("9cd8d0"), Color("e3afcc")][stage_index], 0.5, 0.75)
	materials["screen"] = _material(Color("142934"), 0.5, 0.18)
	materials["tileline"] = _material([Color("7c786e"), Color("354c53"), Color("514252")][stage_index], 1.0)
	materials["gate"] = _material(Color("ad4857"), 0.65, 0.2)
	materials["paper"] = _material(Color("d5c6a8"), 0.9)
	materials["code"] = _material(accent.lightened(0.18), 0.6, 0.65)
	materials["inset"] = _material([Color("a79c84"), Color("34494f"), Color("493c50")][stage_index], 0.93)
	CampusEnvironmentBuilder.build(self)

func _create_gate(index: int, z: float) -> void:
	var gate := Node3D.new()
	gate.name = "ExitGate%d" % index
	gate.position = Vector3(0, 0, z)
	add_child(gate)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	gate.add_child(body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(5.2, 3.2, 0.35)
	shape.shape = box
	shape.position.y = 1.6
	body.add_child(shape)
	gate_colliders.append(shape)
	var mesh := MultiMeshInstance3D.new()
	var bars := MultiMesh.new()
	bars.transform_format = MultiMesh.TRANSFORM_3D
	bars.mesh = _unit_cube
	bars.instance_count = 5
	for bar in range(5):
		bars.set_instance_transform(bar, Transform3D(Basis.IDENTITY.scaled(Vector3(0.12, 2.65, 0.1)), Vector3((bar - 2) * 0.96, 1.35, 0)))
	mesh.multimesh = bars
	mesh.material_override = materials["gate"]
	gate.add_child(mesh)
	var sign_label := _sign("LOCKED • ทำภารกิจให้สำเร็จ", Vector3(0, 2.82, z + 0.17), 0.004, Color("ffb5b5"))
	exit_labels.append(sign_label)
	gates.append(gate)
	gate_tweens.append(null)

func _open_gate(index: int, animated: bool = true) -> void:
	if gate_tweens[index] != null and gate_tweens[index].is_valid():
		gate_tweens[index].kill()
	gate_colliders[index].set_deferred("disabled", true)
	exit_labels[index].text = "> NEXT FLOOR • ขึ้นชั้นถัดไป" if index == 2 else "> OPEN • ไปห้องถัดไป"
	exit_labels[index].modulate = Color("97efbd")
	if animated:
		var tween := create_tween()
		tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
		gate_tweens[index] = tween
		tween.tween_property(gates[index], "position:y", 3.7, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	else:
		gates[index].position.y = 3.7
		gates[index].reset_physics_interpolation()

func _close_gate(index: int) -> void:
	if gate_tweens[index] != null and gate_tweens[index].is_valid():
		gate_tweens[index].kill()
	gates[index].position.y = 0
	gates[index].reset_physics_interpolation()
	gate_colliders[index].set_deferred("disabled", false)
	exit_labels[index].text = "LOCKED • ทำภารกิจให้สำเร็จ"
	exit_labels[index].modulate = Color("ffb5b5")

func _box(node_name: String, size: Vector3, at: Vector3, material: Material, collision: bool = false) -> void:
	var shadow := node_name in ["WallBase", "WallTop", "DoorWall", "DoorLintel", "Pillar", "RoofBeam", "ServerRack", "CampusExterior", "RoofSlab", "CeilingPanel", "ArchWall", "CampusMonument", "PortalDais", "Rubble", "AuditoriumStage"]
	_batch_instance(_unit_cube, Transform3D(Basis.IDENTITY.scaled(size), at), material, shadow)
	if collision:
		var body := StaticBody3D.new()
		body.name = node_name + "Collision"
		body.position = at
		body.collision_layer = 1
		body.collision_mask = 0
		var collider := CollisionShape3D.new()
		var volume := BoxShape3D.new()
		volume.size = size
		collider.shape = volume
		body.add_child(collider)
		add_child(body)

func _batch_instance(mesh: Mesh, transform: Transform3D, material: Material = null, shadow: bool = true) -> void:
	var key := "%d:%d:%d:%s" % [_batch_region, mesh.get_instance_id(), material.get_instance_id() if material != null else 0, shadow]
	if not _static_batches.has(key):
		_static_batches[key] = {"mesh": mesh, "material": material, "transforms": [], "region": _batch_region, "shadow": shadow}
	_static_batches[key].transforms.append(transform)
	static_instance_count += 1

func _flush_static_batches() -> void:
	for entry: Dictionary in _static_batches.values():
		var batch := MultiMesh.new()
		batch.transform_format = MultiMesh.TRANSFORM_3D
		batch.mesh = entry.mesh
		batch.instance_count = entry.transforms.size()
		for index in range(batch.instance_count):
			batch.set_instance_transform(index, entry.transforms[index])
		var visual := MultiMeshInstance3D.new()
		visual.multimesh = batch
		visual.material_override = entry.material
		visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if entry.shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_visual_regions[entry.region].add_child(visual)
		static_batch_count += 1
	_static_batches.clear()

func _collect_static_meshes(node: Node, inherited: Transform3D) -> void:
	var transform := inherited
	if node is Node3D:
		transform = inherited * node.transform
	if node is MeshInstance3D and node.mesh != null:
		_batch_instance(node.mesh, transform, node.material_override, false)
	for child in node.get_children():
		_collect_static_meshes(child, transform)

func _material(color: Color, roughness: float, glow: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	if glow > 0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = glow
	return material

func _sign(text_value: String, at: Vector3, pixel_size: float, color: Color, angles: Vector3 = Vector3.ZERO) -> Label3D:
	var label := Label3D.new()
	label.text = text_value
	label.position = at
	label.rotation = angles
	label.pixel_size = pixel_size * 0.5
	label.font_size = 64
	label.modulate = color
	label.outline_size = 4
	label.shaded = false
	label.double_sided = false
	label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	label.font = CAMPUS_FONT
	_visual_regions[_batch_region].add_child(label)
	return label

func _place_model(asset_name: String, at: Vector3, size: Vector3, angle: float) -> void:
	if asset_name == "desk":
		var body := StaticBody3D.new()
		body.position = at
		body.rotation.y = angle
		body.collision_layer = 1
		body.collision_mask = 0
		var collider := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(1.5, 0.85, 0.8) * size
		collider.shape = shape
		collider.position.y = shape.size.y * 0.5
		body.add_child(collider)
		add_child(body)
	var path := "res://Assets/Models/%s.glb" % asset_name
	if ResourceLoader.exists(path):
		if not _model_scenes.has(path):
			_model_scenes[path] = load(path) as PackedScene
		var resource: PackedScene = _model_scenes[path]
		if resource != null:
			var item := resource.instantiate() as Node3D
			item.position = at
			item.scale = size
			item.rotation.y = angle
			_collect_static_meshes(item, Transform3D.IDENTITY)
			item.free()
			return
	_box("DeskTop", Vector3(1.5, 0.08, 0.8), at + Vector3.UP * 0.77, materials["wood"])
	for x in [-0.6, 0.6]:
		for z in [-0.3, 0.3]:
			_box("DeskLeg", Vector3(0.055, 0.75, 0.055), at + Vector3(x, 0.37, z), materials["trim"])

func _toast(message: String, duration: float = 2.0) -> void:
	var game := get_tree().get_first_node_in_group("game")
	if game != null and game.has_method("notify"):
		game.notify(message, duration)

func _play_audio(effect: String) -> void:
	var audio := get_tree().get_first_node_in_group("game_audio")
	if audio and audio.has_method("play_effect"): audio.play_effect(effect)
