extends CharacterBody3D
class_name SchoolEnemy

signal defeated(enemy: Node)

const ProjectileScript = preload("res://Scripts/projectile.gd")

var kind := "paper"
var display_name := "กระดาษ F"
var health := 30.0
var max_health := 30.0
var posture := 0.0
var max_posture := 100.0
var broken := false
var dead := false
var is_boss := false
var is_core := false
var shielded := false
var shield_triggered := false
var backend := false
var stage: Node
var player: Node3D
var arena_center := Vector3.ZERO
var arena_half_size := Vector2(8.1, 8.8)
var is_attacking := false
var ranged := false
var speed := 2.0
var mode := "approach"
var state_time := 0.0
var elapsed := 0.0
var stun_time := 0.0
var broken_time := 0.0
var attack_id := "melee"
var attack_step := 0
var attack_clock := 0.0
var attack_serial := 0
var attack_direction := Vector3.FORWARD
var attack_target := Vector3.ZERO
var knockback := Vector3.ZERO
var knockback_impact_pending := false
var adapting := false
var adapt_time := 0.0
var last_combo := ""
var repeated_combos := 0
var scroll_time := 0.0
var visual: Node3D
var model: Node3D
var animator: AnimationPlayer
var current_animation := ""
var hint: Label3D
var name_label: Label3D
var telegraph: MeshInstance3D
var telegraph_material: StandardMaterial3D
var floor_warning: Node3D
var base_color := Color("ee6652")
var phase_core: Node
var born_delay := 0.55

func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 0.4
	_configure()
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.36 if is_boss else 0.3
	capsule.height = 1.7 if is_boss else 1.1
	collider.shape = capsule
	collider.position.y = capsule.height * 0.5
	add_child(collider)
	_build_visual()
	mode = "approach"
	state_time = 0.8 + float(get_instance_id() % 7) * 0.1

func _configure() -> void:
	match kind:
		"paper":
			display_name = "กระดาษ F"; max_health = 30; speed = 2.7; base_color = Color("efe5ca")
		"book":
			display_name = "อ่านก่อนสอบ 1 คืน"; max_health = 82; speed = 1.4; base_color = Color("668bce")
		"pencil":
			display_name = "ดินสอสายพุ่ง"; max_health = 42; speed = 2.4; base_color = Color("fac66e")
		"pen":
			display_name = "ปากกาแดง • แก้!"; max_health = 40; speed = 1.4; ranged = true; base_color = Color("ec596a")
		"phone":
			display_name = "อีกคลิปเดียว…"; max_health = 52; speed = 1.2; ranged = true; base_color = Color("ec71da")
		"tablet":
			display_name = "ติวโค้ดก่อนส่งงาน"; max_health = 62; speed = 1.5; base_color = Color("5de1ca")
		"computer":
			display_name = "ห้องแล็บ • Hello World"; max_health = 85; speed = 0; ranged = true; base_color = Color("a5dcf7")
		"programming":
			display_name = "อาจารย์เซมิโคลอน"; max_health = 340; speed = 2.2; is_boss = true; base_color = Color("f8b957")
		"ai":
			display_name = "อาจารย์โอเวอร์ฟิต"; max_health = 410; speed = 2.4; is_boss = true; base_color = Color("6ddfdb")
		"web":
			display_name = "อาจารย์ฟูลสแตก • Web App"; max_health = 480; speed = 2.4; is_boss = true; base_color = Color("ee5f8d")
		"server_core":
			display_name = "SERVER CORE • ทำลายเพื่อปิดโล่"; max_health = 65; speed = 0; is_core = true; base_color = Color("53e6dc")
		"final_core":
			display_name = "ระบบ F กลาง • โจมตีเพื่อจบเกม"; max_health = 40; speed = 0; is_core = true; base_color = Color("ff525d")
	health = max_health
	max_posture = 135 if is_boss else (100 if kind == "book" else 70)

func _build_visual() -> void:
	visual = Node3D.new()
	add_child(visual)
	var asset_kind := "teacher_" + kind if is_boss else kind
	if is_core:
		asset_kind = "computer"
	var path := "res://Assets/Models/%s.glb" % asset_kind
	if ResourceLoader.exists(path):
		var packed := load(path) as PackedScene
		if packed != null:
			model = packed.instantiate() as Node3D
	if model == null:
		var mesh := MeshInstance3D.new()
		var shape := CapsuleMesh.new()
		shape.radius = 0.32
		shape.height = 1.7 if is_boss else 0.95
		mesh.mesh = shape
		mesh.position.y = shape.height / 2.0
		var mat := StandardMaterial3D.new()
		mat.albedo_color = base_color
		mesh.material_override = mat
		model = mesh
	visual.add_child(model)
	animator = _find_animator(model)
	if kind in ["phone", "tablet", "computer"] and animator and animator.has_animation("ScreenLoop"):
		animator.get_animation("ScreenLoop").loop_mode = Animation.LOOP_LINEAR
		animator.play("ScreenLoop")
	else:
		_play("Idle")
	name_label = _label(display_name, 26, Color("e5e9ef"))
	name_label.position.y = 2.2 if is_boss else 1.65
	add_child(name_label)
	hint = _label("", 30, Color("ffd568"))
	hint.position.y = 2.55 if is_boss else 2.0
	add_child(hint)
	telegraph = MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.66
	ring.outer_radius = 0.72
	ring.rings = 24
	ring.ring_segments = 8
	telegraph.mesh = ring
	telegraph.scale.y = 0.12
	telegraph.position.y = 0.045
	telegraph_material = StandardMaterial3D.new()
	telegraph_material.albedo_color = Color(1.0, 0.58, 0.13, 0.85)
	telegraph_material.emission_enabled = true
	telegraph_material.emission = Color(1.0, 0.4, 0.05)
	telegraph_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	telegraph.material_override = telegraph_material
	telegraph.visible = false
	add_child(telegraph)
	if kind in ["phone", "tablet", "computer"]:
		var screen_note := _label("SHORTS ↻\nอีกคลิปเดียว" if kind == "phone" else "CODE TUTOR\nLet's fix this step by step", 24, base_color)
		screen_note.position.y = 0.8
		screen_note.position.z = -0.15
		screen_note.pixel_size = 0.0026
		visual.add_child(screen_note)
	if is_core:
		model.scale *= 1.5
		hint.text = "[ F ]" if kind == "final_core" else "BREAK SHIELD"
		hint.modulate = base_color
		telegraph.visible = true
		telegraph_material.albedo_color = base_color

func _label(text_value: String, size: int, color: Color) -> Label3D:
	var label := Label3D.new()
	label.text = text_value
	label.font_size = size
	label.pixel_size = 0.0038
	label.modulate = color
	label.outline_size = 8
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = false
	var font_path := "res://Assets/Fonts/NotoSansThai.ttf"
	if ResourceLoader.exists(font_path):
		label.font = load(font_path) as Font
	return label

func _find_animator(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_animator(child)
		if found != null:
			return found
	return null

func _play(clip: String) -> void:
	if animator == null or current_animation == clip:
		return
	var matching := ""
	for available_clip in animator.get_animation_list():
		if available_clip.to_lower() == clip.to_lower() or available_clip.to_lower().ends_with("/" + clip.to_lower()):
			matching = available_clip
			break
	if matching.is_empty():
		return
	current_animation = clip
	animator.play(matching, 0.12)

func _physics_process(delta: float) -> void:
	if dead:
		return
	elapsed += delta
	born_delay = maxf(0, born_delay - delta)
	if not is_instance_valid(player):
		return
	if player.health <= 0:
		if is_attacking:
			_end_attack(1.0)
		velocity = Vector3.ZERO
		_play("Idle")
		return
	if is_core:
		visual.position.y = sin(elapsed * 2.5) * 0.035
		return
	if adapting:
		adapt_time -= delta
		if adapt_time <= 0:
			adapting = false
			_update_hint()
	velocity.y -= 22.0 * delta
	if is_on_floor():
		velocity.y = -0.1
	knockback = knockback.move_toward(Vector3.ZERO, delta * 12)
	velocity.x = knockback.x
	velocity.z = knockback.z
	if broken:
		broken_time -= delta
		if broken_time <= 0:
			broken = false
			posture = max_posture * 0.35
			mode = "recover"
			state_time = 0.8
			_update_hint()
		move_and_slide()
		_resolve_knockback_impact()
		return
	if stun_time > 0:
		stun_time -= delta
		move_and_slide()
		_resolve_knockback_impact()
		return
	var toward := player.global_position - global_position
	toward.y = 0
	var distance := toward.length()
	var direction := toward.normalized() if distance > 0.05 else Vector3.FORWARD
	if mode != "attack":
		rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), delta * 8)
	if not is_boss:
		visual.position.y = (0.07 + sin(elapsed * 5.0) * 0.055) if kind in ["paper", "pencil", "pen"] else sin(elapsed * 4) * 0.025
		visual.rotation.z = sin(elapsed * 4.0) * 0.035
	match mode:
		"recover":
			state_time -= delta
			_play("Idle")
			if state_time <= 0:
				mode = "approach"
				_update_hint()
		"telegraph":
			state_time -= delta
			telegraph.visible = true
			telegraph.scale.x = 1.0 + sin(elapsed * 20) * 0.05
			telegraph.scale.z = telegraph.scale.x
			if state_time <= 0:
				mode = "attack"
				attack_clock = 0
				attack_step = 0
				attack_direction = direction if attack_id not in ["charge", "ai_zone", "web_error"] else attack_direction
				_play("Kick" if attack_id in ["spin", "charge", "web_error"] else "Jab")
		"attack":
			_process_attack(delta)
		"approach":
			posture = maxf(0, posture - delta * 5)
			state_time -= delta
			var desired := 5.0 if ranged else 1.65
			if kind == "tablet":
				desired = 3.3
			var movement := Vector3.ZERO
			if distance > desired + 0.2:
				movement = direction * speed
			elif ranged and distance < 3.5 and kind != "computer":
				movement = -direction * speed * 0.55
			movement += _separation() * 1.4
			velocity.x += movement.x
			velocity.z += movement.z
			_play("Walk" if movement.length() > 0.2 else "Idle")
			if born_delay <= 0 and state_time <= 0 and distance < (9.0 if ranged or is_boss else 4.7 if kind == "pencil" else 2.3 if kind != "tablet" else 4.0):
				if stage == null or stage.request_attack(self, ranged):
					_begin_attack(direction)
	global_position.x = clampf(global_position.x, arena_center.x - arena_half_size.x, arena_center.x + arena_half_size.x)
	global_position.z = clampf(global_position.z, arena_center.z - arena_half_size.y, arena_center.z + arena_half_size.y)
	move_and_slide()
	_resolve_knockback_impact()

func _resolve_knockback_impact() -> void:
	if not knockback_impact_pending:
		return
	for index in range(get_slide_collision_count()):
		var contact := get_slide_collision(index)
		if absf(contact.get_normal().y) < 0.5:
			knockback_impact_pending = false
			posture += 25.0
			knockback = Vector3.ZERO
			_check_broken()
			if not broken:
				hint.text = "ชนฉาก! • +เสียสมดุล"
			return
	if knockback.length_squared() < 0.15:
		knockback_impact_pending = false

func _separation() -> Vector3:
	var push := Vector3.ZERO
	for other in get_tree().get_nodes_in_group("enemies"):
		if other == self or not is_instance_valid(other) or other.dead:
			continue
		var offset: Vector3 = global_position - other.global_position
		offset.y = 0
		var d := offset.length()
		if d > 0.01 and d < 1.1:
			push += offset.normalized() * (1.1 - d)
	return push

func _begin_attack(direction: Vector3) -> void:
	is_attacking = true
	mode = "telegraph"
	attack_direction = direction
	attack_target = player.global_position
	attack_serial += 1
	state_time = 0.65
	attack_id = "melee"
	match kind:
		"pencil": attack_id = "charge"; state_time = 0.85
		"pen": attack_id = "shot"; state_time = 0.85
		"phone": attack_id = "phone_burst"; state_time = 0.85
		"computer": attack_id = "triple_shot"; state_time = 1.0
		"tablet": attack_id = "support"; state_time = 0.7
		"book": attack_id = "slam"; state_time = 0.85
		"programming":
			attack_id = ["combo", "charge", "spin"][(attack_serial - 1) % 3]
			state_time = 1.0 if attack_id == "spin" else 0.7
		"ai":
			attack_id = ["charge", "ai_zone", "combo"][(attack_serial - 1) % 3]
			state_time = 1.1 if attack_id == "ai_zone" else 0.8
		"web":
			if shielded:
				attack_id = "shot"; state_time = 1.5
			elif backend:
				attack_id = ["triple_shot", "web_error", "charge"][(attack_serial - 1) % 3]
				state_time = 1.1 if attack_id == "web_error" else 0.85
			else:
				attack_id = ["combo", "layout", "charge"][(attack_serial - 1) % 3]
				state_time = 1.0 if attack_id == "layout" else 0.75
	telegraph.visible = true
	var danger := attack_id in ["spin", "ai_zone", "web_error", "layout"]
	telegraph_material.albedo_color = Color("ff5067") if danger else Color("ffcc66")
	telegraph_material.emission = Color("ff234f") if danger else Color("ffc34d")
	hint.text = "!  หลบ / DODGE" if danger else "!  ปัดป้อง / PARRY"
	hint.modulate = Color("ff657a") if danger else Color("ffe18f")
	_play("Guard")
	if attack_id in ["ai_zone", "web_error", "layout"]:
		_spawn_warning(attack_target, 2.35 if attack_id != "layout" else 2.0)
	if attack_id in ["shot", "phone_burst", "triple_shot"]:
		var camera := get_viewport().get_camera_3d()
		if camera != null:
			var point := global_position + Vector3.UP
			var outside := camera.is_position_behind(point) or not get_viewport().get_visible_rect().has_point(camera.unproject_position(point))
			if outside:
				_toast("! กระสุนจากนอกจอ • เตรียมหลบหรือปัดป้อง", 1.5)

func _process_attack(delta: float) -> void:
	attack_clock += delta
	match attack_id:
		"combo":
			var timing := [0.06, 0.42, 1.02]
			if attack_step < 3 and attack_clock >= timing[attack_step]:
				current_animation = ""
				_play(["Jab", "Cross", "Hook"][attack_step])
				_melee_hit(10.0, 18.0, 2.35, false)
				attack_step += 1
			if attack_clock > 1.2: _end_attack(1.3)
		"charge":
			if attack_clock < 0.5:
				velocity.x = attack_direction.x * (8.0 if is_boss else 7.0)
				velocity.z = attack_direction.z * (8.0 if is_boss else 7.0)
				if attack_step == 0 and global_position.distance_to(player.global_position) < 1.8:
					_melee_hit(13.0 if is_boss else 9.0, 24.0, 2.2, false)
					attack_step = 1
			if attack_clock >= 0.6: _end_attack(1.45)
		"shot", "phone_burst", "triple_shot":
			var count := 1 if attack_id == "shot" else 3
			if attack_step < count and attack_clock >= float(attack_step) * 0.28:
				_fire_projectile()
				attack_step += 1
			if attack_clock > (0.3 if count == 1 else 0.9):
				_end_attack(2.6 if kind == "phone" else 1.4)
				if kind == "phone": hint.text = "มัวดูคลิป… ตีได้!"
		"ai_zone", "web_error", "layout":
			if attack_step == 0:
				attack_step = 1
				var radius := 2.35 if attack_id != "layout" else 2.0
				if _flat_distance(player.global_position, attack_target) < radius:
					player.receive_hit(15.0, 28.0, global_position, true)
				_clear_warning()
			if attack_clock > 0.35: _end_attack(1.45)
		"spin":
			visual.rotate_y(delta * 11)
			if attack_step == 0 and attack_clock > 0.18:
				attack_step = 1
				_melee_hit(17.0, 32.0, 3.2, true, true)
			if attack_clock > 0.65:
				visual.rotation.y = 0
				_end_attack(1.65)
		"support":
			if attack_step == 0:
				attack_step = 1
				_melee_hit(6.0, 12.0, 1.9, false)
			if attack_clock > 0.4: _end_attack(1.8)
		_:
			if attack_step == 0 and attack_clock > 0.07:
				attack_step = 1
				_melee_hit(11.0 if kind == "book" else 7.0, 24.0 if kind == "book" else 13.0, 2.15, false)
			if attack_clock > 0.35: _end_attack(1.0)

func _melee_hit(damage_value: float, structure_value: float, reach: float, unblockable: bool, all_directions: bool = false) -> void:
	var offset := player.global_position - global_position
	offset.y = 0
	if offset.length() > reach:
		return
	if not all_directions and offset.length() > 0.1 and attack_direction.dot(offset.normalized()) < 0.25:
		return
	var result: String = player.receive_hit(damage_value, structure_value, global_position, unblockable)
	if result == "parried":
		on_parried()

func on_parried() -> void:
	if dead:
		return
	posture += 42.0 if is_boss else 38.0
	adapting = false
	repeated_combos = 0
	_interrupt(0.75)
	_check_broken()
	_update_hint()

func _fire_projectile() -> void:
	var bullet := ProjectileScript.new()
	bullet.target = player
	bullet.attacker = self
	bullet.source_position = global_position
	bullet.speed = 8.5 if is_boss else 7.0
	bullet.damage = 8.0 if is_boss else 6.0
	bullet.structure = 14.0
	bullet.tint = base_color
	var spawn := global_position + Vector3.UP * (1.2 if is_boss else 0.85)
	bullet.direction = (player.global_position + Vector3.UP * 0.9 - spawn).normalized()
	stage.add_child(bullet)
	bullet.global_position = spawn
	if bullet.direction.length_squared() > 0.01:
		bullet.look_at(spawn + bullet.direction, Vector3.UP)

func _end_attack(recovery: float) -> void:
	is_attacking = false
	mode = "recover"
	state_time = recovery
	telegraph.visible = false
	_update_hint()
	_clear_warning()

func _interrupt(duration: float) -> void:
	is_attacking = false
	mode = "recover"
	state_time = duration + 0.35
	stun_time = duration
	telegraph.visible = false
	visual.rotation.y = 0
	current_animation = ""
	_play("Hit")
	_clear_warning()

func take_hit(damage: float, structure: float, from: Vector3, force: float = 0.0, heavy: bool = false) -> String:
	if dead:
		return "dead"
	if shielded:
		hint.text = "ทำลาย SERVER CORE ก่อน"
		return "shielded"
	var offset := from - global_position
	offset.y = 0
	var facing := -global_transform.basis.z
	var frontal := offset.length() < 0.1 or facing.dot(offset.normalized()) > 0.15
	if not broken and frontal and not heavy and ((kind == "book" and mode == "approach") or adapting):
		posture += structure * 0.4
		hint.text = "ตั้งรับ • ใช้ท่าหนัก"
		_check_broken()
		return "blocked"
	if adapting and heavy:
		adapting = false
		repeated_combos = 0
	var support := _has_support()
	health = maxf(0, health - damage)
	posture += structure * (0.55 if support else 1.0)
	if force > 0 and offset.length() > 0.01:
		knockback = -offset.normalized() * force
		knockback_impact_pending = true
	if health <= 0:
		_die()
		return "hit"
	if is_core:
		var tween := create_tween()
		tween.tween_property(visual, "scale", Vector3.ONE * 0.9, 0.05)
		tween.tween_property(visual, "scale", Vector3.ONE, 0.1)
		return "hit"
	# Professors keep their attack/recovery clock through ordinary hits. Only a real
	# parry, posture break, finisher or phase transition interrupts their sequence.
	# Damage and posture above still land normally, including heavy attacks.
	if not is_boss:
		_interrupt(0.27 if not heavy else 0.5)
	_check_broken()
	_check_web_phase()
	return "hit"

func _has_support() -> bool:
	if kind == "tablet" or is_boss or is_core:
		return false
	for other in get_tree().get_nodes_in_group("enemies"):
		if other != self and is_instance_valid(other) and not other.dead and other.kind == "tablet" and global_position.distance_to(other.global_position) < 4.8:
			return true
	return false

func _check_broken() -> void:
	if posture >= max_posture and not is_core:
		posture = max_posture
		broken = true
		broken_time = 3.6
		_interrupt(0.0)
		hint.text = "E  •  ปิดฉาก / FINISH"
		hint.modulate = Color("86f2c2")
		telegraph.visible = true
		telegraph_material.albedo_color = Color("75efb5")

func can_finish() -> bool:
	return broken and not dead and not shielded and not is_core

func finish() -> void:
	if not can_finish():
		return
	if not is_boss:
		_die()
	else:
		broken = false
		posture = 0
		health = maxf(0, health - 60)
		_interrupt(1.05)
		if health <= 0:
			_die()
		else:
			_check_web_phase()
			_update_hint()

func notify_combo(combo_id: String) -> void:
	if kind != "ai" or dead:
		return
	if combo_id == last_combo:
		repeated_combos += 1
	else:
		last_combo = combo_id
		repeated_combos = 1
	if repeated_combos >= 3:
		adapting = true
		adapt_time = 6.0
		_update_hint()
		_toast("อ่านแพตเทิร์นออกแล้ว! เปลี่ยนคอมโบหนัก หรือปัดป้องแล้วสวน", 3.0)
	else:
		adapting = false

func _check_web_phase() -> void:
	if kind != "web" or dead or shield_triggered or health > max_health * 0.6:
		return
	shield_triggered = true
	shielded = true
	backend = true
	broken = false
	posture = 0
	_interrupt(1.5)
	hint.text = "WORKS ON MY MACHINE • SHIELD"
	if is_instance_valid(stage):
		phase_core = stage.spawn_web_core(self)
	_toast("Works on my machine! ทำลาย SERVER CORE ที่ส่องแสงเพื่อปิดโล่", 4.0)

func disable_shield() -> void:
	shielded = false
	if not dead:
		_interrupt(1.2)
		_update_hint()
		_toast("โล่ปิดแล้ว! BACKEND ONLINE • ระวัง 500 ERROR", 3.0)

func _die() -> void:
	if dead:
		return
	dead = true
	is_attacking = false
	broken = false
	shielded = false
	velocity = Vector3.ZERO
	collision_layer = 0
	collision_mask = 0
	_clear_warning()
	telegraph.visible = false
	hint.visible = false
	name_label.visible = false
	_play("Death")
	defeated.emit(self)
	var tween := create_tween()
	if not is_boss:
		tween.tween_property(visual, "rotation:z", 1.5, 0.3)
		tween.parallel().tween_property(visual, "position:y", 0.15, 0.3)
	else:
		tween.tween_interval(0.9)
	tween.tween_property(visual, "scale", Vector3.ONE * 0.01, 0.3)
	tween.tween_callback(queue_free)

func _update_hint() -> void:
	if broken:
		hint.text = "E  •  ปิดฉาก / FINISH"
	elif shielded:
		hint.text = "SHIELD • ทำลาย SERVER CORE"
	elif adapting:
		hint.text = "OVERFIT • เปลี่ยนคอมโบ!"
	elif kind == "tablet":
		hint.text = "SUPPORT • ช่วยเพื่อนตั้งรับ"
	elif is_boss:
		hint.text = "BACKEND" if backend else ""
	else:
		hint.text = ""
	hint.modulate = Color("ffdb8c")

func _spawn_warning(point: Vector3, radius: float) -> void:
	_clear_warning()
	floor_warning = MeshInstance3D.new()
	var disk := CylinderMesh.new()
	disk.top_radius = radius
	disk.bottom_radius = radius
	disk.height = 0.025
	disk.radial_segments = 40
	floor_warning.mesh = disk
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1, 0.08, 0.23, 0.34)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	floor_warning.material_override = mat
	stage.add_child(floor_warning)
	floor_warning.global_position = Vector3(point.x, 0.05, point.z)

func _clear_warning() -> void:
	if is_instance_valid(floor_warning):
		floor_warning.queue_free()
	floor_warning = null

func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))

func _toast(message: String, duration: float = 2.0) -> void:
	var game := get_tree().get_first_node_in_group("game")
	if game != null and game.has_method("notify"):
		game.notify(message, duration)

func _exit_tree() -> void:
	_clear_warning()
