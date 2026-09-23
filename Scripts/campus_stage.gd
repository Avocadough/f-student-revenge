extends Node3D
class_name CampusStage

signal encounter_changed(checkpoint: int, title: String)
signal stage_completed

const EnemyScript = preload("res://Scripts/school_enemy.gd")
const PropScript = preload("res://Scripts/interactable_prop.gd")

const STAGE_TITLES := ["เช็คชื่อครั้งสุดท้าย", "ห้องแล็บที่รู้ทันทุกอย่าง", "Final Deployment"]
const ROOM_TITLES := [
	["01 • CHECK IN / ลานเช็คชื่อ", "02 • LAST ASSIGNMENT / ทางเดินส่งงาน", "03 • SEMICOLON / ห้องเขียนโปรแกรม"],
	["01 • DATA HALL / ทางเดินห้องแล็บ", "02 • TRAINING ROOM / ห้องคอมพิวเตอร์", "03 • OVERFIT / ห้องทดลอง AI"],
	["01 • REQUEST GATE / จุดตรวจหน้าห้อง", "02 • DEMO DAY / ห้องรอนำเสนอ", "03 • FINAL DEPLOY / ห้องสอบ Web App"]
]
const ENCOUNTERS := [
	[["paper", "paper", "pencil"], ["paper", "pencil", "pen", "book", "paper"], ["programming"]],
	[["pencil", "pencil", "book", "phone"], ["pen", "book", "phone", "tablet", "computer", "phone"], ["ai"]],
	[["phone", "phone", "tablet", "computer", "book"], ["pen", "book", "phone", "tablet", "computer", "book"], ["web"]]
]
const INTRO_LINES := [
	"ในห้องไม่เห็นหน้า แต่ในใบเกรดเห็น F ชัดมาก",
	"Accuracy บนข้อมูลฝึก 100% …แล้วข้อมูลใหม่ล่ะ?",
	"เปิดเว็บได้ ไม่ได้แปลว่างานเสร็จ"
]

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

func _ready() -> void:
	stage_index = clampi(stage_index, 0, 2)
	checkpoint_index = clampi(checkpoint_index, 0, 2)
	accent = [Color("edb66c"), Color("68d4cf"), Color("f16b91")][stage_index]
	_build_campus()
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
	return global_position + Vector3(0, 0.12, 6.0 - checkpoint_index * 24.0)

func get_objective() -> String:
	if completed:
		return "ระบบ F ถูกทำลายแล้ว"
	if final_core_created:
		return "ชนะอาจารย์แล้ว! โจมตีแกนระบบ F กลางเพื่อจบเกม"
	if room_clear[checkpoint_index]:
		return "ผ่านประตูสีเขียวไปด่านถัดไป" if checkpoint_index == 2 else "เคลียร์แล้ว • เดินผ่านประตูสีเขียวไปห้องถัดไป"
	if checkpoint_index == 2:
		if is_instance_valid(boss) and boss.shielded:
			return "ทำลาย SERVER CORE ที่ส่องแสงเพื่อปิดโล่บอส"
		return "เอาชนะ %s" % ["อาจารย์เซมิโคลอน", "อาจารย์โอเวอร์ฟิต", "อาจารย์ Web App"][stage_index]
	return "กำจัดอุปกรณ์การเรียน • เหลือ %d ตัว" % get_remaining()

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
		if is_instance_valid(enemy):
			enemy.queue_free()
	active_enemies.clear()
	_clear_projectiles()
	pending_enemies.clear()
	boss = null
	final_core_created = false
	completed = false
	room_clear[checkpoint_index] = false
	_close_gate(checkpoint_index)
	if is_instance_valid(player):
		player.global_position = get_spawn_position()
	_start_encounter(checkpoint_index)

func _start_encounter(index: int) -> void:
	checkpoint_index = index
	encounter_started = true
	spawn_serial = 0
	next_spawn_delay = 0.1
	room_clear[index] = false
	active_enemies.clear()
	pending_enemies.clear()
	for enemy_kind in ENCOUNTERS[stage_index][index]:
		pending_enemies.append(enemy_kind)
	_setup_props(index)
	encounter_changed.emit(index, ROOM_TITLES[stage_index][index])
	if index == 2:
		_toast("%s: “%s”" % [["อาจารย์เซมิโคลอน", "อาจารย์โอเวอร์ฟิต", "อาจารย์ Web App"][stage_index], INTRO_LINES[stage_index]], 4.0)
	elif stage_index == 0 and index == 0:
		_toast("WASD เดิน • คลิกซ้าย 3 ครั้งต่อคอมโบ • Shift ปัดป้อง • Space หลบ", 5.0)
	elif stage_index == 0 and index == 1:
		_toast("หนังสือตั้งรับ: ใช้ L–L–H หรือ L–H–L • E หยิบของขว้าง", 4.0)
	elif stage_index == 1 and index == 1:
		_toast("iPad ช่วยเพื่อนตั้งรับ • กำจัดก่อน แล้วเปลี่ยนคอมโบให้หลากหลาย", 4.0)

func _physics_process(delta: float) -> void:
	if not encounter_started or completed or not is_instance_valid(player):
		return
	elapsed += delta
	next_spawn_delay -= delta
	if next_spawn_delay <= 0 and not pending_enemies.is_empty() and _alive_count() < 4:
		_spawn_enemy(pending_enemies.pop_front())
		next_spawn_delay = 0.65
	if room_clear[checkpoint_index]:
		if checkpoint_index < 2:
			var threshold := -float(checkpoint_index + 1) * 24.0 + 8.0
			if player.global_position.z - global_position.z < threshold:
				_start_encounter(checkpoint_index + 1)
		elif stage_index < 2 and player.global_position.z - global_position.z < -60.0:
			completed = true
			stage_completed.emit()
	# The support visual is a clear turquoise floor ring, only while a tablet is alive.
	for enemy in active_enemies:
		if is_instance_valid(enemy) and not enemy.dead and enemy.kind == "tablet" and enemy.mode not in ["telegraph", "attack"]:
			enemy.telegraph.visible = true
			enemy.telegraph.scale.x = 1.5
			enemy.telegraph.scale.z = 1.5
			enemy.telegraph_material.albedo_color = Color("57d7c3")

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
	enemy.arena_center = global_position + Vector3(0, 0, -checkpoint_index * 24.0)
	var positions := [Vector3(-3.8, 0.08, -2.5), Vector3(3.8, 0.08, -3.7), Vector3(0, 0.08, -5.0), Vector3(-2.0, 0.08, 0), Vector3(3.6, 0.08, -5.4), Vector3(-4.2, 0.08, -4.5)]
	var spawn_at: Vector3 = positions[spawn_serial % positions.size()] + Vector3(0, 0, -checkpoint_index * 24.0)
	if enemy_kind in ["programming", "ai", "web"]:
		spawn_at = Vector3(0, 0.08, -checkpoint_index * 24.0 - 3.4)
	if enemy_kind == "computer":
		spawn_at.x = 4.0
		spawn_at.z = -checkpoint_index * 24.0 - 5.8
	if at != Vector3.INF:
		spawn_at = at
	enemy.position = spawn_at
	enemy.defeated.connect(_on_enemy_defeated)
	add_child(enemy)
	active_enemies.append(enemy)
	spawn_serial += 1
	if enemy.is_boss:
		boss = enemy
	return enemy

func _on_enemy_defeated(enemy: Node) -> void:
	total_defeated += 1
	if enemy.kind == "server_core":
		if is_instance_valid(boss) and not boss.dead:
			boss.disable_shield()
		return
	if enemy.kind == "final_core":
		completed = true
		_clear_projectiles()
		stage_completed.emit()
		return
	if enemy.kind == "web":
		_clear_projectiles()
		for other in active_enemies:
			if is_instance_valid(other) and other != enemy and not other.dead:
				other.dead = true
				other.queue_free()
		pending_enemies.clear()
		final_core_created = true
		var core := _spawn_enemy("final_core", Vector3(0, 0.08, -54.5))
		core.rotation.y = PI
		_toast("อาจารย์ Web App แพ้แล้ว! ทำลายแกน F กลาง แล้วจบการล้างแค้น", 5.0)
		return
	if get_remaining() == 0:
		room_clear[checkpoint_index] = true
		_open_gate(checkpoint_index)
		_clear_projectiles()
		if checkpoint_index == 2:
			_toast("Generalization Failed • ประตูขึ้นชั้นถัดไปเปิดแล้ว" if stage_index == 1 else "ส่งงานผ่าน! เดินผ่านประตูไปชั้นถัดไป", 4.0)
		else:
			_toast("เคลียร์แล้ว! เดินผ่านประตูสีเขียว • จุดเริ่มใหม่อยู่ห้องถัดไป", 3.0)

func spawn_web_core(_owner: Node) -> Node:
	return _spawn_enemy("server_core", Vector3(-4.5, 0.08, -51.5))

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
		var score := direction.normalized().dot(offset.normalized()) * 5.0 - dist * 0.16
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
		prop.position = offset + Vector3(0, 0, -index * 24.0)
		prop.rotation.y = float(props.size()) * 1.2
		checkpoint_props.add_child(prop)
		props.append(prop)

func _build_campus() -> void:
	materials["floor"] = _material(Color("98968d") if stage_index == 0 else Color("6e7b84") if stage_index == 1 else Color("7e7479"), 0.8)
	materials["wall"] = _material(Color("b7b2a5") if stage_index == 0 else Color("a0b2b7") if stage_index == 1 else Color("b1a9ae"), 0.9)
	materials["dark"] = _material(Color("233039"), 0.7)
	materials["trim"] = _material(Color("41434a"), 0.55)
	materials["wood"] = _material(Color("9d7550"), 0.8)
	materials["glass"] = _material(Color("314e63"), 0.3)
	materials["accent"] = _material(accent, 0.55)
	materials["light"] = _material(Color("f3e4c7"), 0.5, 1.5)
	materials["screen"] = _material(Color("183244"), 0.5, 0.3)
	materials["tileline"] = _material(Color("9c9b99"), 1.0)
	materials["gate"] = _material(Color("ad4857"), 0.65, 0.2)
	for room in range(3):
		_build_room(room)
	# The entrance closes the playable boundary, so backing out never drops into the void.
	_box("CampusEntranceBarrier", Vector3(5.2, 3.2, 0.24), Vector3(0, 1.6, 10.0), materials["glass"], true)
	_sign("ทางออกปิด • ต้องผ่านอาจารย์ก่อน", Vector3(0, 2.2, 9.82), 0.004, Color("f0d7aa"), Vector3(0, PI, 0))
	for room in range(3):
		var z := -float(room) * 24.0 - 12.0
		_box("ConnectorFloor", Vector3(6.2, 0.3, 4.3), Vector3(0, -0.16, z), materials["floor"], true)
		_box("ConnectorWallL", Vector3(0.25, 3.4, 4.0), Vector3(-3.15, 1.7, z), materials["wall"], true)
		_box("ConnectorWallR", Vector3(0.25, 3.4, 4.0), Vector3(3.15, 1.7, z), materials["wall"], true)
		_box("ConnectorLight", Vector3(2.8, 0.045, 0.16), Vector3(0, 3.0, z), materials["light"])
		_sign("↑ NEXT FLOOR" if room == 2 else "↑ NEXT ROOM", Vector3(0, 0.025, z), 0.0035, accent, Vector3(-PI / 2.0, 0, 0))
	_box("ExitFloor", Vector3(6.2, 0.3, 5), Vector3(0, -0.16, -63.5), materials["floor"], true)
	# Long exterior masses give every window a visible campus backdrop.
	for side in [-1, 1]:
		for block in range(6):
			_box("CampusExterior", Vector3(5, 9, 7), Vector3(side * 18.0, 2.5, 6 - block * 13.0), materials["dark"])
			for pane in range(3):
				_box("ExteriorWindow", Vector3(0.05, 1.0, 1.3), Vector3(side * 15.45, 3.5, 4.5 - block * 13.0 + pane * 1.8), materials["screen"])

func _build_room(index: int) -> void:
	var z := -float(index) * 24.0
	_box("RoomFloor", Vector3(18, 0.3, 20), Vector3(0, -0.16, z), materials["floor"], true)
	# Simple tile joints are geometry, keeping this readable without large texture downloads.
	for tile_x in range(-8, 9, 2):
		_box("TileJoint", Vector3(0.022, 0.012, 19.7), Vector3(tile_x, 0.001, z), materials["tileline"])
	for tile_z in range(-8, 10, 2):
		_box("TileJoint", Vector3(17.8, 0.012, 0.022), Vector3(0, 0.001, z + tile_z), materials["tileline"])
	for side in [-1, 1]:
		_box("WallBase", Vector3(0.24, 0.95, 20), Vector3(side * 9.0, 0.475, z), materials["wall"], true)
		_box("WallTop", Vector3(0.24, 0.7, 20), Vector3(side * 9.0, 3.45, z), materials["wall"], true)
		_box("WindowGlass", Vector3(0.12, 2.15, 20), Vector3(side * 9.0, 2.02, z), materials["glass"], true)
		for column_z in range(-9, 11, 4):
			_box("Pillar", Vector3(0.45, 3.8, 0.45), Vector3(side * 8.9, 1.9, z + column_z), materials["wall"], true)
		_box("WallTrim", Vector3(0.06, 0.08, 20), Vector3(side * 8.84, 0.98, z), materials["accent"])
		_place_model("cabinet", Vector3(side * 7.65, 0, z + 8.1), Vector3.ONE * 1.15, PI / 2.0 * side)
		_place_model("plant", Vector3(side * 7.7, 0, z - 8.3), Vector3.ONE * 1.1, 0)
		for desk_z in [-5.5, 0.0, 5.5]:
			_place_model("desk", Vector3(side * 7.2, 0, z + desk_z), Vector3.ONE * 1.1, PI / 2.0 * side)
			if stage_index > 0:
				_box("IdleMonitor", Vector3(0.06, 0.7, 1.0), Vector3(side * 7.4, 1.22, z + desk_z), materials["screen"])
			else:
				_box("ExerciseBooks", Vector3(0.3, 0.07, 0.5), Vector3(side * 7.2, 0.82, z + desk_z), materials["accent"])
	for front in [-1, 1]:
		var wall_z: float = z + front * 10.0
		for side in [-1, 1]:
			_box("DoorWall", Vector3(6.4, 3.8, 0.28), Vector3(side * 5.8, 1.9, wall_z), materials["wall"], true)
		_box("DoorLintel", Vector3(5.2, 0.65, 0.35), Vector3(0, 3.5, wall_z), materials["dark"], true)
		_box("DoorTrim", Vector3(5.3, 0.07, 0.39), Vector3(0, 3.12, wall_z), materials["accent"])
	for beam_z in [-6, 2, 8]:
		_box("RoofBeam", Vector3(18, 0.25, 0.28), Vector3(0, 3.8, z + beam_z), materials["wall"])
		_box("CeilingStrip", Vector3(4.4, 0.035, 0.19), Vector3(0, 3.65, z + beam_z), materials["light"])
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0, 4.6, z)
	lamp.light_color = Color("ffdcb6") if stage_index == 0 else Color("c5e4ff") if stage_index == 1 else Color("f3c8dc")
	lamp.light_energy = 0.35
	lamp.omni_range = 17.0
	lamp.shadow_enabled = false
	add_child(lamp)
	_sign(ROOM_TITLES[stage_index][index], Vector3(0, 3.53, z - 9.76), 0.0048, Color("f8e7cc"))
	_sign("CP410844  /  GROUP 03", Vector3(5.6, 2.6, z - 9.74), 0.003, Color("3a4653"))
	var board_text := "ATTENDANCE\nPresent: 0   Grade: F\nเช็คชื่อแล้วไม่เคยอยู่" if stage_index == 0 else "TRAINING STATUS\nAccuracy 100%\nGeneralization ???" if stage_index == 1 else "DEPLOYMENT\nGET /grades  →  500\nWorks on my machine."
	_box("NoticeBoard", Vector3(3.6, 1.8, 0.12), Vector3(-5.4, 2.0, z - 9.7), materials["dark"])
	_sign(board_text, Vector3(-5.4, 2.0, z - 9.61), 0.004, Color("e8e7dc"))
	_box("WallClock", Vector3(0.5, 0.5, 0.08), Vector3(5.9, 3.25, z - 9.7), materials["accent"])
	_sign("23:59", Vector3(5.9, 3.25, z - 9.63), 0.003, Color("1a2630"))
	if index == 2:
		_box("PresentationScreen", Vector3(5.8, 2.0, 0.16), Vector3(0, 2.1, z - 8.8), materials["screen"])
		var screen := ["SYNTAX ERROR\nmissing student;", "OVERFIT LAB\nTrain ≠ Test", "FINAL PROJECT\nWEB APPLICATION"]
		_sign(screen[stage_index], Vector3(0, 2.1, z - 8.69), 0.006, accent)
		# Plinth sits beyond combat center; its visual anchors the professor's arena.
		_box("PresentationPlinth", Vector3(5.8, 0.12, 1.4), Vector3(0, 0.06, z - 8.6), materials["dark"])
	_create_gate(index, z - 10)

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
	for bar in range(-2, 3):
		var mesh := MeshInstance3D.new()
		var bar_shape := BoxMesh.new()
		bar_shape.size = Vector3(0.12, 2.65, 0.1)
		mesh.mesh = bar_shape
		mesh.material_override = materials["gate"]
		mesh.position = Vector3(bar * 0.96, 1.35, 0)
		gate.add_child(mesh)
	var sign_label := _sign("LOCKED • กำจัดศัตรูก่อน", Vector3(0, 2.82, z + 0.17), 0.004, Color("ffb5b5"))
	exit_labels.append(sign_label)
	gates.append(gate)

func _open_gate(index: int, animated: bool = true) -> void:
	gate_colliders[index].set_deferred("disabled", true)
	exit_labels[index].text = "↑ NEXT FLOOR • ขึ้นชั้นถัดไป" if index == 2 else "↑ OPEN • ไปห้องถัดไป"
	exit_labels[index].modulate = Color("97efbd")
	if animated:
		var tween := create_tween()
		tween.tween_property(gates[index], "position:y", 3.7, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	else:
		gates[index].position.y = 3.7

func _close_gate(index: int) -> void:
	gates[index].position.y = 0
	gate_colliders[index].set_deferred("disabled", false)
	exit_labels[index].text = "LOCKED • กำจัดศัตรูก่อน"
	exit_labels[index].modulate = Color("ffb5b5")

func _box(node_name: String, size: Vector3, at: Vector3, material: Material, collision: bool = false) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = node_name
	var shape := BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	mesh.material_override = material
	mesh.position = at
	add_child(mesh)
	if collision:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		var collider := CollisionShape3D.new()
		var volume := BoxShape3D.new()
		volume.size = size
		collider.shape = volume
		body.add_child(collider)
		mesh.add_child(body)
	return mesh

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
	label.pixel_size = pixel_size
	label.font_size = 32
	label.modulate = color
	label.outline_size = 2
	label.shaded = false
	var font_path := "res://Assets/Fonts/NotoSansThai.ttf"
	if ResourceLoader.exists(font_path):
		label.font = load(font_path) as Font
	add_child(label)
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
		var resource := load(path) as PackedScene
		if resource != null:
			var item := resource.instantiate() as Node3D
			item.position = at
			item.scale = size
			item.rotation.y = angle
			add_child(item)
			return
	_box("DeskTop", Vector3(1.5, 0.08, 0.8), at + Vector3.UP * 0.77, materials["wood"])
	for x in [-0.6, 0.6]:
		for z in [-0.3, 0.3]:
			_box("DeskLeg", Vector3(0.055, 0.75, 0.055), at + Vector3(x, 0.37, z), materials["trim"])

func _toast(message: String, duration: float = 2.0) -> void:
	var game := get_tree().get_first_node_in_group("game")
	if game != null and game.has_method("notify"):
		game.notify(message, duration)
