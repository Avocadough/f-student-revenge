extends RefCounted
## Campus architecture is batched per encounter region. All dimensions are metres.
## The central combat lanes remain clear; dressing occupies the room perimeter.

static var _geometry: Dictionary = {}
static var _contact_material: StandardMaterial3D
static var _portal_material: ShaderMaterial

static func build(stage) -> void:
	stage.room_centers = [Vector3.ZERO, Vector3(0, 0, -24), Vector3(0, 0, -48)] as Array[Vector3]
	stage.spawn_markers = [Vector3(0, 0, 6), Vector3(0, 0, -18), Vector3(0, 0, -42)] as Array[Vector3]
	stage.exit_markers = [Vector3(0, 0, -10), Vector3(0, 0, -34), Vector3(0, 0, -58)] as Array[Vector3]
	stage.objective_markers = [Vector3(3, 0, -5.5), Vector3(3, 0, -29.5), Vector3(3, 0, -53.5)] as Array[Vector3]
	stage.ally_markers = [Vector3(-4, 0, 3.5), Vector3(-4, 0, -20.5), Vector3(-4, 0, -44.5)] as Array[Vector3]
	_prepare_materials(stage)
	for room in range(3):
		stage._batch_region = room
		var z: float = stage.room_centers[room].z
		var outdoor: bool = (room == 0 and stage.stage_index != 1) or (stage.stage_index == 2 and room == 2)
		_foundation(stage, z, outdoor)
		match stage.stage_index:
			0:
				if room == 0: _grade_courtyard(stage, z)
				elif room == 1: _emergency_corridor(stage, z)
				else: _power_room(stage, z)
			1:
				if room == 0: _ai_lab(stage, z)
				elif room == 1: _server_hall(stage, z)
				else: _rift_chamber(stage, z)
			2:
				if room == 0: _evacuation_court(stage, z)
				elif room == 1: _auditorium(stage, z)
				else: _portal_plaza(stage, z)
		_exit_arch(stage, room, z)
		_connector(stage, room, z)
		if not outdoor:
			_light(stage, Vector3(0, 3.4, z + 2.5), Color("bec9c6"), 2.4, 14, true)
		stage._create_gate(room, z - 10.0)
	stage._batch_region = 0
	_box(stage, "DoorWall", Vector3(18.4, 4.5, 0.4), Vector3(0, 2.25, 10.2), "wall", true)
	stage._sign("เขตอพยพปิดแล้ว  •  เดินหน้าช่วยมหาวิทยาลัย", Vector3(0, 2.0, 9.95), 0.007, Color("c4d3cc"), Vector3(0, PI, 0))
	stage._batch_region = 3
	_campus_skyline(stage)

static func _prepare_materials(stage) -> void:
	var m: Dictionary = stage.materials
	m["floor"] = _surface("concrete_floor", Color("9da59d"), 0.45)
	m["wall"] = _surface("painted_plaster_wall", Color("c6c4b5"), 0.38)
	m["concrete"] = _surface("concrete_floor", Color("78857f"), 0.55)
	m["dark"] = _mat(Color("202b2e"), 0.88)
	m["trim"] = _mat(Color("506165"), 0.62, 0.3)
	m["wood"] = _mat(Color("554535"), 0.87)
	m["tile"] = _mat(Color("566d65"), 0.63)
	m["tileline"] = _mat(Color("353e3c"), 0.98)
	m["glass"] = _mat(Color("21343c"), 0.23, 0.45)
	m["paper"] = _mat(Color("d5cbbb"), 0.95)
	m["brass"] = _mat(Color("9b8457"), 0.48, 0.6)
	m["rust"] = _mat(Color("755047"), 0.96)
	m["red"] = _mat(Color("7d302f"), 0.72)
	m["leaf"] = _mat(Color("304b43"), 0.96)
	m["leaf_light"] = _mat(Color("52655a"), 0.91)
	m["light"] = _mat(Color("b8d3c0"), 0.42, 0.0, 1.7)
	m["warm_light"] = _mat(Color("dcc398"), 0.4, 0.0, 1.8)
	m["screen"] = _mat(Color("133c45"), 0.5, 0.0, 0.35)
	m["code"] = _mat(Color("79c3c4"), 0.5, 0.0, 1.1)
	m["warning"] = _mat(Color("c2984c"), 0.75, 0.0, 0.13)
	m["gate"] = _mat(Color("855094"), 0.5, 0.0, 0.55)
	m["corruption"] = _mat(Color("2c172e"), 0.81)
	m["vein"] = _mat(Color("ab4868"), 0.55, 0.0, 1.1)
	m["portal"] = _mat(Color("d17eaa"), 0.5, 0.0, 2.0)
	m["void"] = _mat(Color("120c1a"), 1.0)

static func _surface(stem: String, tint: Color, density: float) -> StandardMaterial3D:
	var material: StandardMaterial3D = _mat(tint, 0.91)
	# These repeating 1K maps need imported mip chains, especially on grazing floors.
	# Anisotropy keeps their broad detail readable without single-pixel speckling.
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var base: String = "res://Assets/Textures/%s_" % stem
	if ResourceLoader.exists(base + "diff.jpg"):
		material.albedo_texture = load(base + "diff.jpg") as Texture2D
		material.uv1_triplanar = true
		material.uv1_world_triplanar = true
		material.uv1_scale = Vector3.ONE * density
	if ResourceLoader.exists(base + "normal.jpg"):
		material.normal_enabled = true
		material.normal_texture = load(base + "normal.jpg") as Texture2D
		material.normal_scale = 0.28
	if ResourceLoader.exists(base + "rough.jpg"):
		material.roughness_texture = load(base + "rough.jpg") as Texture2D
	return material

static func _mat(color: Color, roughness: float, metallic: float = 0.0, emission: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	if emission > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = emission
	return material

static func _box(stage, label: String, size: Vector3, at: Vector3, material: String, collision: bool = false) -> void:
	stage._box(label, size, at, stage.materials[material], collision)

static func _foundation(stage, z: float, outdoor: bool) -> void:
	var wall_height: float = 8.0 if stage.stage_index == 2 else 5.4
	_box(stage, "RoomFloor", Vector3(18.5, 0.35, 20.5), Vector3(0, -0.19, z), "floor", true)
	for side in [-1, 1]:
		_box(stage, "WallBase", Vector3(0.4, 1.15 if outdoor else wall_height, 20.4), Vector3(side * 9.15, 0.575 if outdoor else wall_height * 0.5, z), "wall", true)
		_box(stage, "WallTrim", Vector3(0.44, 0.17, 20.4), Vector3(side * 9.15, 1.1 if outdoor else 0.14, z), "dark")
		if not outdoor:
			_box(stage, "WallBase", Vector3(0.04, 1.05, 20), Vector3(side * 8.93, 0.66, z), "tile")
			_box(stage, "WallTrim", Vector3(0.09, 0.09, 20), Vector3(side * 8.86, 1.2, z), "trim")
			for bay in [-7.0, -2.3, 2.3, 7.0]:
				_box(stage, "Pillar", Vector3(0.5, 5.4, 0.45), Vector3(side * 8.73, 2.7, z + bay), "concrete", true)
			_box(stage, "RoofBeam", Vector3(1.2, 0.35, 20.4), Vector3(side * 8.65, 5.15, z), "concrete", true)
			_box(stage, "CeilingPanel", Vector3(5.3, 0.2, 20.2), Vector3(side * 6.45, wall_height, z), "dark", true)
	if not outdoor:
		# Full roof keeps interior lighting distinct from the open campus courtyards.
		_box(stage, "RoofSlab", Vector3(8.2, 0.22, 20.2), Vector3(0, wall_height + 0.25, z), "concrete", true)
	for x in [-6.0, -3.0, 0.0, 3.0, 6.0]:
		_box(stage, "TileJoint", Vector3(0.015, 0.009, 19.9), Vector3(x, -0.008, z), "tileline")
	for offset in [-8.0, -4.0, 0.0, 4.0, 8.0]:
		_box(stage, "TileJoint", Vector3(18.0, 0.009, 0.015), Vector3(0, -0.007, z + offset), "tileline")
	# Perimeter contact shading is baked into a tiny original alpha texture.
	_contact(stage, Vector3(-8.2, 0.002, z), Vector2(2.0, 19.5), 0.0)
	_contact(stage, Vector3(8.2, 0.002, z), Vector2(2.0, 19.5), 0.0)

static func _exit_arch(stage, room: int, z: float) -> void:
	var final_portal: bool = stage.stage_index == 2 and room == 2
	if stage.stage_index == 2 and room == 1:
		_box(stage, "DoorWall", Vector3(18.4, 2.85, 0.4), Vector3(0, 6.8, z - 10.0), "wall", true)
	for side in [-1, 1]:
		_box(stage, "DoorWall", Vector3(6.35, 5.4, 0.4), Vector3(side * 5.8, 2.7, z - 10.0), "wall", true)
		_box(stage, "Pillar", Vector3(0.36, 4.3, 0.75), Vector3(side * 2.8, 2.15, z - 9.85), "dark", true)
	if not final_portal:
		_box(stage, "DoorLintel", Vector3(5.5, 1.15, 0.62), Vector3(0, 4.85, z - 10.0), "concrete", true)
		_box(stage, "ExitLight", Vector3(2.4, 0.07, 0.08), Vector3(0, 4.15, z - 9.62), "light")
	var destinations: Array = [
		["อาคารเรียน  /  TEACHING BLOCK", "ห้องไฟฟ้า  /  POWER CONTROL", "ศูนย์วิจัย  /  RESEARCH WING"],
		["ศูนย์ข้อมูล  /  DATA CENTRE", "ห้องทดลอง  /  CONTAINMENT", "หอประชุม  /  ASSEMBLY HALL"],
		["หอประชุม  /  AUDITORIUM", "ลานกลาง  /  CENTRAL PLAZA", "ประตูมิติ  /  THE BREACH"]
	]
	if not final_portal:
		stage._sign(destinations[stage.stage_index][room], Vector3(0, 3.7, z - 9.6), 0.008, Color("d9e2d6"))
	stage._sign("%02d" % (room + 1), Vector3(-3.4, 1.9, z - 9.7), 0.027, Color("a8b9b0"))

static func _connector(stage, room: int, z: float) -> void:
	_box(stage, "ConnectorFloor", Vector3(6.0, 0.35, 4.2), Vector3(0, -0.19, z - 12), "floor", true)
	for side in [-1, 1]:
		_box(stage, "ConnectorWallL", Vector3(0.32, 4.6, 4.0), Vector3(side * 3.03, 2.3, z - 12), "wall", true)
		_box(stage, "WallTrim", Vector3(0.08, 0.1, 4), Vector3(side * 2.83, 1.05, z - 12), "tile")
	_box(stage, "CeilingStrip", Vector3(1.7, 0.06, 0.23), Vector3(0, 4.3, z - 12), "light")
	_box(stage, "RoofSlab", Vector3(6.2, 0.22, 4.1), Vector3(0, 4.7, z - 12), "concrete", true)
	if room < 2:
		stage._sign("ทางไปต่อ  ↑", Vector3(0, 0.005, z - 12), 0.008, Color("c1baa0"), Vector3(-PI / 2.0, 0, 0))

static func _grade_courtyard(stage, z: float) -> void:
	for side in [-1, 1]:
		_colonnade(stage, side, z, false)
		for offset in [-6.0, 5.7]:
			_planter(stage, Vector3(side * 7.5, 0, z + offset), true)
			_bench(stage, Vector3(side * 7.15, 0, z + offset + 2), side * PI / 2.0)
		_box(stage, "WalkwayBorder", Vector3(0.12, 0.014, 18), Vector3(side * 5.8, 0, z), "brass")
	_notice_board(stage, Vector3(-7.45, 0, z - 1.0), PI / 2.0, "ประกาศผลการศึกษา", "ภาคการศึกษาปลาย\nรหัส 6633…       F\nขาดเรียนเกินกำหนด")
	_box(stage, "CampusMonument", Vector3(2.0, 0.55, 2.0), Vector3(7.35, 0.275, z - 1.0), "concrete", true)
	_box(stage, "CampusMonument", Vector3(0.48, 2.6, 0.48), Vector3(7.35, 1.8, z - 1), "brass")
	_rot_box(stage, Vector3(1.45, 1.45, 0.22), Vector3(7.35, 3.05, z - 1.0), Vector3(0, 0, PI / 4), "brass")
	stage._sign("มหาวิทยาลัย  •  CAMPUS", Vector3(0, 5.95, z - 9.72), 0.015, Color("cfceb3"))
	_scattered_papers(stage, Vector3(-6.6, 0, z + 0.8), 7)
	_light(stage, Vector3(-6, 4.3, z - 2), Color("d8c19a"), 1.2, 11)

static func _emergency_corridor(stage, z: float) -> void:
	for side in [-1, 1]:
		for offset in [-5.5, 1.0, 6.3]:
			_door(stage, Vector3(side * 8.9, 0, z + offset), side, "CLASSROOM  %d" % (201 + int(offset + 6)))
		for offset in [-6, 0, 6]:
			_box(stage, "RoofBeam", Vector3(17.7, 0.25, 0.35), Vector3(0, 5.0, z + offset), "concrete")
			_box(stage, "CeilingStrip", Vector3(0.18, 0.06, 2.1), Vector3(side * 4.7, 4.84, z + offset), "light" if offset != 0 else "warm_light")
		_pipe(stage, Vector3(side * 8.45, 4.2, z - 9.4), Vector3(side * 8.45, 4.2, z + 9.4), 0.07, "rust")
		_bench(stage, Vector3(side * 7.7, 0, z - 2.4), side * PI / 2)
		_rubble(stage, Vector3(side * 7.5, 0, z + 7.0), 6)
	_box(stage, "FireCabinet", Vector3(0.2, 1.1, 0.72), Vector3(-8.76, 1.5, z - 1.6), "red")
	stage._sign("FIRE\nHOSE", Vector3(-8.61, 1.5, z - 1.6), 0.005, Color("d9d7bf"), Vector3(0, PI / 2, 0))
	_notice_board(stage, Vector3(7.7, 0, z + 4.5), -PI / 2, "ประกาศฉุกเฉิน", "โปรดอพยพตามลูกศร\nรวมพลที่หอประชุม")
	stage._sign("เส้นทางอพยพ  ↑", Vector3(0, 0.005, z - 5), 0.013, Color("bdb394"), Vector3(-PI / 2, 0, 0))
	_light(stage, Vector3(-4.0, 4.5, z + 3), Color("b7ccc0"), 1.6, 13)
	_light(stage, Vector3(5.5, 3.3, z - 5), Color("cb8860"), 0.9, 8)

static func _power_room(stage, z: float) -> void:
	for side in [-1, 1]:
		for offset in [-6.2, -2.1, 2.1, 6.2]:
			_electrical_cabinet(stage, Vector3(side * 7.65, 0, z + offset), side)
		for height in [3.8, 4.15, 4.5]:
			_pipe(stage, Vector3(side * 8.4, height, z - 9.4), Vector3(side * 8.4, height, z + 9.4), 0.075, "rust" if height == 3.8 else "trim")
		_hazard_line(stage, Vector3(side * 6.25, 0.003, z), 15, 0.0)
	for offset in [-5, 5]:
		_box(stage, "RoofBeam", Vector3(17.8, 0.65, 0.4), Vector3(0, 4.8, z + offset), "dark")
		_box(stage, "CeilingStrip", Vector3(3.0, 0.08, 0.3), Vector3(0, 4.42, z + offset), "warm_light")
	stage._sign("DANGER  •  HIGH VOLTAGE", Vector3(-5.2, 3.55, z - 9.73), 0.007, Color("c9a862"))
	stage._sign("MAIN SWITCHBOARD\nคืนพลังงานให้อาคารเรียน", Vector3(5.8, 3.25, z - 9.73), 0.007, Color("d3d7c3"))
	_corruption(stage, Vector3(7.0, 0, z - 6.5), 1.9)
	_light(stage, Vector3(0, 4.2, z + 1), Color("c7b798"), 1.7, 15)

static func _ai_lab(stage, z: float) -> void:
	for side in [-1, 1]:
		for offset in [-5.8, 0.0, 5.8]:
			_box(stage, "LabBench", Vector3(2.2, 0.15, 3.0), Vector3(side * 7.45, 0.93, z + offset), "paper", true)
			_box(stage, "LabBase", Vector3(1.9, 0.83, 2.6), Vector3(side * 7.45, 0.42, z + offset), "tile", true)
			stage._place_model("laptop", Vector3(side * 7.4, 1.02, z + offset), Vector3.ONE * 0.8, side * PI / 2)
			_box(stage, "WindowGlass", Vector3(0.04, 1.8, 3.5), Vector3(side * 8.9, 2.7, z + offset), "glass")
			_box(stage, "WindowMullion", Vector3(0.09, 1.85, 0.06), Vector3(side * 8.83, 2.7, z + offset), "trim")
			_contact(stage, Vector3(side * 7.4, 0.003, z + offset), Vector2(3.3, 3.9), 0)
		_pipe(stage, Vector3(side * 4.7, 4.6, z - 9), Vector3(side * 4.7, 4.6, z + 9), 0.12, "dark")
	_box(stage, "LabDisplay", Vector3(4.2, 1.5, 0.1), Vector3(-5.8, 2.5, z - 9.72), "screen")
	stage._sign("AI RESEARCH LAB\nระบบกักกัน: OFFLINE", Vector3(-5.8, 2.5, z - 9.63), 0.01, Color("a6ced0"))
	stage._sign("RESEARCH  /  04", Vector3(5.9, 3.1, z - 9.7), 0.011, Color("afbeb8"))
	_scattered_papers(stage, Vector3(6.5, 0, z + 3), 5)
	_light(stage, Vector3(0, 4.6, z), Color("a8c4c6"), 1.7, 15)

static func _server_hall(stage, z: float) -> void:
	for side in [-1, 1]:
		for offset in [-6.8, -2.3, 2.3, 6.8]:
			_server_rack(stage, Vector3(side * 7.3, 0, z + offset), side)
			_box(stage, "FloorVent", Vector3(1.0, 0.012, 2.2), Vector3(side * 5.9, 0, z + offset), "dark")
			for slot in range(9):
				_box(stage, "VentSlat", Vector3(0.88, 0.02, 0.045), Vector3(side * 5.9, 0.014, z + offset - 0.9 + slot * 0.22), "trim")
		_box(stage, "CableTray", Vector3(0.7, 0.17, 19), Vector3(side * 6.5, 4.6, z), "dark")
		for cable in range(3):
			_pipe(stage, Vector3(side * 6.5 + cable * 0.12, 4.75, z - 9), Vector3(side * 6.5 + cable * 0.12, 4.75, z + 9), 0.035, "rust")
		_box(stage, "CeilingStrip", Vector3(0.12, 0.06, 17.5), Vector3(side * 3.8, 4.9, z), "code")
	stage._sign("DATA CENTRE  /  RESTRICTED", Vector3(0, 5.9, z - 9.7), 0.012, Color("a3bdc1"))
	stage._sign("ข้อมูลสำรอง\nBACKUP ARRAY", Vector3(-5.6, 3.3, z - 9.72), 0.01, Color("9fbec0"))
	_light(stage, Vector3(0, 4.5, z), Color("97b7c8"), 1.5, 14)

static func _rift_chamber(stage, z: float) -> void:
	for side in [-1, 1]:
		for offset in [-6.2, 5.8]:
			_box(stage, "Pillar", Vector3(1.1, 5.4, 1.1), Vector3(side * 7.25, 2.7, z + offset), "concrete", true)
			_box(stage, "LabScreen", Vector3(1.5, 1.0, 0.22), Vector3(side * 7.25, 1.55, z + offset + 0.65), "screen")
			_contact(stage, Vector3(side * 7.25, 0.002, z + offset), Vector2(2.8, 2.8), 0)
		_rubble(stage, Vector3(side * 7.2, 0, z), 9)
		_corruption(stage, Vector3(side * 7.75, 0, z - 5.0), 2.3)
		_box(stage, "RoofBeam", Vector3(0.4, 0.5, 20), Vector3(side * 5.8, 4.9, z), "dark")
	_ring(stage, Vector3(0, 0.015, z), Vector3(5.4, 0.035, 5.4), Vector3.ZERO, "trim")
	_ring(stage, Vector3(0, 0.025, z), Vector3(4.9, 0.015, 4.9), Vector3.ZERO, "vein")
	_portal(stage, Vector3(6.8, 2.7, z - 2), 1.4, -PI / 2)
	stage._sign("CONTAINMENT BREACH", Vector3(0, 5.8, z - 9.65), 0.013, Color("c791a4"))
	stage._sign("อย่าให้มันผ่านออกไป", Vector3(-5.5, 2.5, z - 9.7), 0.010, Color("c4b8b1"))
	_light(stage, Vector3(-3, 4.0, z + 2), Color("a5c7c1"), 1.7, 15)
	_light(stage, Vector3(6.5, 2.4, z - 2), Color("c2669c"), 1.6, 9)

static func _evacuation_court(stage, z: float) -> void:
	for side in [-1, 1]:
		_colonnade(stage, side, z, true)
		_planter(stage, Vector3(side * 7.3, 0, z + 6.0), true)
		_bench(stage, Vector3(side * 7.3, 0, z - 5.5), PI / 2)
		_box(stage, "Barrier", Vector3(1.15, 1.0, 4.0), Vector3(side * 7.3, 0.5, z), "concrete", true)
		_hazard_line(stage, Vector3(side * 6.5, 0.01, z), 4, 0)
		_corruption(stage, Vector3(side * 7.9, 0, z - 7), 2.2)
	_notice_board(stage, Vector3(-7.4, 0, z + 2.8), PI / 2, "จุดรวมพล", "อาจารย์และนักศึกษา\nช่วยกันรักษามหาวิทยาลัย")
	stage._sign("หอประชุมกลาง", Vector3(0, 6.35, z - 9.7), 0.022, Color("c4c1aa"))
	for x in [-4.8, 4.8]:
		_box(stage, "CampusBanner", Vector3(1.1, 3.7, 0.09), Vector3(x, 4.6, z - 9.68), "red")
		stage._sign("CAMPUS\nTOGETHER", Vector3(x, 4.65, z - 9.58), 0.007, Color("d1c6b0"))
	_light(stage, Vector3(0, 5.5, z - 7), Color("c8b28a"), 1.5, 14)

static func _auditorium(stage, z: float) -> void:
	for side in [-1, 1]:
		for row in range(5):
			var row_z: float = z + 6.7 - row * 3.0
			_box(stage, "AudienceTier", Vector3(3.2, 0.18, 2.5), Vector3(side * 7.05, 0.08, row_z), "wood")
			for seat in range(3):
				_seat(stage, Vector3(side * (6.1 + seat * 0.88), 0.15, row_z))
			_box(stage, "Pillar", Vector3(0.58, 6.8, 0.7), Vector3(side * 8.7, 3.4, row_z), "concrete", true)
		_box(stage, "Curtain", Vector3(0.13, 4.2, 17.5), Vector3(side * 8.78, 3.2, z), "red")
		for fold in range(18):
			_box(stage, "CurtainFold", Vector3(0.18, 4.2, 0.09), Vector3(side * 8.62, 3.2, z - 8.5 + fold), "rust")
		_box(stage, "AisleStrip", Vector3(0.07, 0.012, 18.0), Vector3(side * 5.25, 0.006, z), "warm_light")
		_box(stage, "AuditoriumStage", Vector3(3.8, 0.6, 2.6), Vector3(side * 6.85, 0.3, z - 8.1), "wood", true)
	_box(stage, "ProjectionScreen", Vector3(6.2, 2.8, 0.12), Vector3(0, 6.35, z - 9.7), "paper")
	stage._sign("TOGETHER\nไม่มีใครรอดได้เพียงลำพัง", Vector3(0, 6.35, z - 9.58), 0.015, Color("344a47"))
	for offset in [-6.0, 2.0, 8.0]:
		_box(stage, "RoofBeam", Vector3(18, 0.4, 0.42), Vector3(0, 7.1, z + offset), "dark")
	_light(stage, Vector3(0, 6.2, z - 6), Color("d2c097"), 2.1, 16)
	_light(stage, Vector3(0, 4.8, z + 6), Color("a3b8c0"), 1.0, 11)

static func _portal_plaza(stage, z: float) -> void:
	for side in [-1, 1]:
		for offset in [-6.0, 0.0, 6.0]:
			_box(stage, "Pillar", Vector3(0.95, 6.8, 0.95), Vector3(side * 7.45, 3.4, z + offset), "concrete", true)
			_contact(stage, Vector3(side * 7.4, 0.01, z + offset), Vector2(2.8, 2.8), 0)
			_corruption(stage, Vector3(side * 7.4, 0, z + offset), 1.7)
		_box(stage, "RoofBeam", Vector3(0.7, 0.65, 20), Vector3(side * 7.4, 6.7, z), "dark")
		_rubble(stage, Vector3(side * 7, 0, z + 3), 7)
	# Ritual inlays have no collision; the climax arena remains level.
	_ring(stage, Vector3(0, 0.01, z - 1), Vector3(5.8, 0.025, 5.8), Vector3.ZERO, "brass")
	_ring(stage, Vector3(0, 0.017, z - 1), Vector3(5.2, 0.02, 5.2), Vector3.ZERO, "vein")
	_ring(stage, Vector3(0, 0.022, z - 1), Vector3(2.0, 0.02, 2.0), Vector3.ZERO, "trim")
	for spoke in range(12):
		var angle: float = TAU * spoke / 12.0
		_rot_box(stage, Vector3(0.1, 0.018, 0.7), Vector3(sin(angle) * 4.4, 0.019, z - 1 + cos(angle) * 4.4), Vector3(0, angle, 0), "brass")
	_portal(stage, Vector3(0, 4.0, z - 9.15), 3.1, 0, true)
	stage._sign("ปิดประตูมิติ  •  ช่วยมหาวิทยาลัย", Vector3(0, 7.8, z - 10.1), 0.014, Color("d2b3c0"))
	_light(stage, Vector3(0, 5.5, z - 7), Color("bd729c"), 2.4, 14)
	_light(stage, Vector3(0, 4.8, z + 5), Color("a4bdc9"), 1.8, 15)

static func _colonnade(stage, side: int, z: float, damaged: bool) -> void:
	for offset in [-7.5, -2.5, 2.5, 7.5]:
		_box(stage, "Pillar", Vector3(0.62, 5.8, 0.62), Vector3(side * 8.7, 2.9, z + offset), "concrete", true)
		_box(stage, "WindowGlass", Vector3(0.2, 2.8, 3.5), Vector3(side * 10.3, 3.2, z + offset), "glass")
		_box(stage, "CampusExterior", Vector3(0.4, 8.6, 0.28), Vector3(side * 10.2, 4.3, z + offset - 2), "wall")
		if damaged and offset < 0: _rubble(stage, Vector3(side * 8.0, 0, z + offset), 4)
	_box(stage, "RoofBeam", Vector3(2.2, 0.4, 20), Vector3(side * 9.5, 5.6, z), "concrete")
	_box(stage, "CampusExterior", Vector3(0.7, 2.4, 20), Vector3(side * 10.6, 7.5, z), "wall")
	_box(stage, "CampusCornice", Vector3(1.0, 0.18, 20.4), Vector3(side * 10.3, 8.65, z), "concrete")

static func _notice_board(stage, at: Vector3, angle: float, title: String, body: String) -> void:
	var facing := Basis(Vector3.UP, angle)
	for x in [-1.25, 1.25]:
		_rot_box(stage, Vector3(0.09, 2.8, 0.09), at + facing * Vector3(x, 1.4, 0), Vector3(0, angle, 0), "trim")
	_rot_box(stage, Vector3(3.0, 1.8, 0.16), at + Vector3.UP * 1.9, Vector3(0, angle, 0), "dark")
	_rot_box(stage, Vector3(2.7, 1.3, 0.03), at + facing * Vector3(0, 1.68, 0.1), Vector3(0, angle, 0), "paper")
	_rot_box(stage, Vector3(3.2, 0.12, 0.8), at + Vector3.UP * 2.88, Vector3(0, angle, 0), "trim")
	stage._sign(title, at + facing * Vector3(0, 2.48, 0.12), 0.007, Color("d9dcca"), Vector3(0, angle, 0))
	stage._sign(body, at + facing * Vector3(0, 1.73, 0.14), 0.006, Color("39443f"), Vector3(0, angle, 0))
	_contact(stage, at + Vector3(0, 0.008, 0), Vector2(3.8, 1.8), angle)

static func _bench(stage, at: Vector3, angle: float) -> void:
	var basis := Basis(Vector3.UP, angle)
	for z in [-0.21, 0.0, 0.21]:
		_rot_box(stage, Vector3(2.35, 0.09, 0.16), at + basis * Vector3(0, 0.52, z), Vector3(0, angle, 0), "wood")
	for x in [-0.84, 0.84]:
		_rot_box(stage, Vector3(0.12, 0.49, 0.5), at + basis * Vector3(x, 0.245, 0), Vector3(0, angle, 0), "trim")
	_rot_box(stage, Vector3(2.35, 0.4, 0.1), at + basis * Vector3(0, 0.93, 0.25), Vector3(0, angle, 0), "wood")
	_contact(stage, at + Vector3(0, 0.006, 0), Vector2(3.0, 1.3), angle)

static func _planter(stage, at: Vector3, tree: bool) -> void:
	_box(stage, "Planter", Vector3(1.9, 0.56, 1.9), at + Vector3.UP * 0.28, "concrete", true)
	_box(stage, "Soil", Vector3(1.65, 0.025, 1.65), at + Vector3.UP * 0.58, "dark")
	if tree:
		_pipe(stage, at + Vector3(0, 0.57, 0), at + Vector3(0.13, 3.6, 0), 0.13, "wood")
		for index in range(4):
			var offset := Vector3(sin(index * 2.4) * 0.65, 3.2 + index * 0.34, cos(index * 2.4) * 0.6)
			_sphere(stage, at + offset, Vector3(1.3, 0.8, 1.2), "leaf" if index % 2 == 0 else "leaf_light")
	_contact(stage, at + Vector3(0, 0.008, 0), Vector2(3.0, 3.0), 0)

static func _door(stage, at: Vector3, side: int, label: String) -> void:
	_box(stage, "ClassroomDoor", Vector3(0.12, 2.65, 1.45), at + Vector3(0, 1.325, 0), "wood")
	_box(stage, "DoorWindow", Vector3(0.05, 0.67, 0.65), at + Vector3(-side * 0.10, 1.85, 0), "glass")
	_box(stage, "DoorHandle", Vector3(0.13, 0.06, 0.25), at + Vector3(-side * 0.10, 1.05, -0.52), "brass")
	stage._sign(label, at + Vector3(-side * 0.13, 3.0, 0), 0.006, Color("abb7af"), Vector3(0, -side * PI / 2, 0))

static func _electrical_cabinet(stage, at: Vector3, side: int) -> void:
	_box(stage, "ServerRack", Vector3(1.45, 2.65, 2.3), at + Vector3.UP * 1.325, "trim", true)
	_box(stage, "CabinetDoor", Vector3(0.04, 2.3, 2.07), at + Vector3(-side * 0.75, 1.37, 0), "tile")
	for row in range(6):
		_box(stage, "CabinetVent", Vector3(0.05, 0.035, 0.72), at + Vector3(-side * 0.78, 0.54 + row * 0.105, 0), "dark")
	_box(stage, "VoltageSign", Vector3(0.05, 0.4, 0.38), at + Vector3(-side * 0.78, 1.8, 0), "warning")
	stage._sign("⚡", at + Vector3(-side * 0.82, 1.8, 0), 0.009, Color("252b26"), Vector3(0, -side * PI / 2, 0))
	_box(stage, "StatusLamp", Vector3(0.06, 0.08, 0.08), at + Vector3(-side * 0.79, 2.38, -0.6), "vein")
	_contact(stage, at + Vector3(0, 0.004, 0), Vector2(2.4, 3.0), 0)

static func _server_rack(stage, at: Vector3, side: int) -> void:
	_box(stage, "ServerRack", Vector3(1.9, 3.3, 2.7), at + Vector3.UP * 1.65, "dark", true)
	for slot in range(9):
		var h: float = 0.35 + slot * 0.32
		_box(stage, "ServerUnit", Vector3(0.08, 0.24, 2.48), at + Vector3(-side * 0.99, h, 0), "trim")
		_box(stage, "ServerLED", Vector3(0.1, 0.04, 0.12), at + Vector3(-side * 1.03, h, -0.91), "code" if slot % 4 != 0 else "warning")
		_box(stage, "ServerVent", Vector3(0.1, 0.07, 1.5), at + Vector3(-side * 1.03, h, 0.21), "dark")
	_contact(stage, at + Vector3(0, 0.004, 0), Vector2(3.2, 3.6), 0)

static func _seat(stage, at: Vector3) -> void:
	_box(stage, "AudienceSeat", Vector3(0.67, 0.17, 0.64), at + Vector3(0, 0.46, 0), "red")
	_box(stage, "AudienceBack", Vector3(0.67, 0.68, 0.13), at + Vector3(0, 0.82, 0.30), "red")
	_box(stage, "AudienceLeg", Vector3(0.08, 0.44, 0.38), at + Vector3(0, 0.22, 0), "dark")

static func _rubble(stage, at: Vector3, count: int) -> void:
	for index in range(count):
		var phase: float = index * 2.39996
		var offset := Vector3(sin(phase) * 0.75, 0.08 + fmod(index * 0.13, 0.28), cos(phase) * 1.3)
		var size := Vector3(0.35 + fmod(index * 0.39, 0.5), 0.18 + fmod(index * 0.17, 0.3), 0.45 + fmod(index * 0.23, 0.6))
		_rot_box(stage, size, at + offset, Vector3(index * 0.23, phase, index * 0.14), "concrete" if index % 3 != 0 else "rust")
	_contact(stage, at + Vector3(0, 0.008, 0), Vector2(2.9, 3.8), 0)

static func _scattered_papers(stage, at: Vector3, count: int) -> void:
	for index in range(count):
		var offset := Vector3(sin(index * 2.8) * 1.1, 0.012 + index * 0.001, cos(index * 1.7) * 1.8)
		_rot_box(stage, Vector3(0.24, 0.005, 0.35), at + offset, Vector3(0, index * 0.91, 0), "paper")

static func _hazard_line(stage, at: Vector3, count: int, angle: float) -> void:
	for index in range(count):
		_rot_box(stage, Vector3(0.55, 0.012, 0.26), at + Vector3(0, 0, index * 0.8 - count * 0.4), Vector3(0, angle + 0.45, 0), "warning")

static func _corruption(stage, at: Vector3, radius: float) -> void:
	_contact(stage, at + Vector3(0, 0.02, 0), Vector2(radius * 2.4, radius * 2.4), 0)
	for index in range(6):
		var angle: float = index * 2.39996
		var root := at + Vector3(sin(angle) * radius * 0.7, 0.07, cos(angle) * radius * 0.7)
		var tip := at + Vector3(sin(angle + 0.4) * radius * 0.28, 1.1 + fmod(index * 0.63, 1.9), cos(angle + 0.4) * radius * 0.28)
		_pipe(stage, root, tip, 0.12 + index * 0.018, "corruption")
		_pipe(stage, root + Vector3(0.03, 0.04, 0), tip + Vector3(0.03, 0.02, 0), 0.025, "vein")

static func _portal(stage, at: Vector3, radius: float, yaw: float, sealable: bool = false) -> void:
	var owner: Node3D = null
	if sealable:
		owner = Node3D.new()
		owner.name = "SealablePortal"
		stage._visual_regions[stage._batch_region].add_child(owner)
		stage.set_meta("final_portal_visual", owner)
	var rotation := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, PI / 2)
	_portal_mesh(stage, owner, _ring_mesh(), Transform3D(rotation.scaled_local(Vector3(radius, radius * 0.7, radius * 1.15)), at), stage.materials["corruption"])
	_portal_mesh(stage, owner, _ring_mesh(), Transform3D(rotation.scaled_local(Vector3(radius * 0.92, radius * 0.28, radius * 1.07)), at), stage.materials["portal"])
	# One opaque clipped quad gives the breach depth without layered alpha overdraw.
	if not _geometry.has("portal_aperture"):
		var plane := QuadMesh.new()
		plane.size = Vector2(2, 2)
		_geometry["portal_aperture"] = plane
	_portal_mesh(stage, owner, _geometry["portal_aperture"], Transform3D(Basis(Vector3.UP, yaw).scaled_local(Vector3(radius * 0.89, radius * 1.05, 1)), at), _portal_surface())
	for index in range(9):
		var angle: float = TAU * index / 9.0
		var offset := Vector3(sin(angle) * radius * 0.98, cos(angle) * radius * 1.16, 0)
		offset = Basis(Vector3.UP, yaw) * offset
		_portal_mesh(stage, owner, stage._unit_cube, Transform3D(Basis.from_euler(Vector3(0, yaw, -angle)).scaled_local(Vector3(0.12, 0.4, 0.15)), at + offset), stage.materials["vein"])

static func _portal_mesh(stage, owner: Node3D, mesh: Mesh, transform: Transform3D, material: Material) -> void:
	if owner == null:
		stage._batch_instance(mesh, transform, material, false)
		return
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = material
	visual.transform = transform
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	owner.add_child(visual)

static func _portal_surface() -> ShaderMaterial:
	if _portal_material == null:
		var shader := Shader.new()
		shader.code = """shader_type spatial;
render_mode unshaded, cull_disabled;
void fragment() {
 vec2 p = UV * 2.0 - 1.0;
 float r = length(p);
 if (r > 1.0) { discard; }
 float a = atan(p.y, p.x);
 float swirl = sin(a * 5.0 - r * 17.0 + TIME * 0.7);
 float cloud = sin(p.x * 9.0 + TIME * 0.21) * sin(p.y * 7.0 - TIME * 0.17);
 float veil = pow(max(0.0, swirl * 0.5 + cloud * 0.25), 3.0);
 float edge = pow(r, 7.0);
 vec3 color = mix(vec3(0.022, 0.016, 0.043), vec3(0.17, 0.047, 0.16), veil * 0.65 + r * 0.18);
 color += vec3(0.31, 0.105, 0.24) * edge;
 ALBEDO = color;
}
"""
		_portal_material = ShaderMaterial.new()
		_portal_material.shader = shader
	return _portal_material

static func _campus_skyline(stage) -> void:
	for side in [-1, 1]:
		for block in range(5):
			var at := Vector3(side * (16.0 + block % 2 * 3.0), 0, 4.0 - block * 16.0)
			var height: float = 10.0 + (block % 3) * 2.5
			_box(stage, "CampusExterior", Vector3(7.0, height, 11.5), at + Vector3.UP * height * 0.5, "concrete")
			for floor in range(3):
				for bay in range(4):
					_box(stage, "ExteriorWindow", Vector3(0.035, 1.4, 1.6), at + Vector3(-side * 3.53, 3.0 + floor * 2.7, -4.2 + bay * 2.8), "screen" if (bay + floor + block) % 4 == 0 else "glass")
			_box(stage, "RoofBeam", Vector3(7.5, 0.3, 12), at + Vector3.UP * height, "dark")

static func _rot_box(stage, size: Vector3, at: Vector3, angles: Vector3, material: String) -> void:
	stage._batch_instance(stage._unit_cube, Transform3D(Basis.from_euler(angles).scaled_local(size), at), stage.materials[material], false)

static func _pipe(stage, from: Vector3, to: Vector3, radius: float, material: String) -> void:
	var delta: Vector3 = to - from
	if delta.length() < 0.001: return
	var mesh: CylinderMesh = _disc_mesh()
	var basis := Basis(Quaternion(Vector3.UP, delta.normalized()))
	stage._batch_instance(mesh, Transform3D(basis.scaled_local(Vector3(radius, delta.length(), radius)), (from + to) * 0.5), stage.materials[material], true)

static func _disc_mesh() -> CylinderMesh:
	if not _geometry.has("cylinder"):
		var mesh := CylinderMesh.new()
		mesh.top_radius = 1.0
		mesh.bottom_radius = 1.0
		mesh.height = 1.0
		mesh.radial_segments = 12
		_geometry["cylinder"] = mesh
	return _geometry["cylinder"] as CylinderMesh

static func _sphere(stage, at: Vector3, size: Vector3, material: String) -> void:
	if not _geometry.has("sphere"):
		var mesh := SphereMesh.new()
		mesh.radius = 1.0
		mesh.height = 2.0
		mesh.radial_segments = 10
		mesh.rings = 5
		_geometry["sphere"] = mesh
	stage._batch_instance(_geometry["sphere"], Transform3D(Basis.IDENTITY.scaled_local(size), at), stage.materials[material], true)

static func _ring(stage, at: Vector3, size: Vector3, angles: Vector3, material: String) -> void:
	var rotation := Basis(Vector3.UP, angles.y) * Basis(Vector3.RIGHT, angles.x) * Basis(Vector3.FORWARD, angles.z)
	stage._batch_instance(_ring_mesh(), Transform3D(rotation.scaled_local(size), at), stage.materials[material], false)

static func _ring_mesh() -> TorusMesh:
	if not _geometry.has("ring"):
		var mesh := TorusMesh.new()
		mesh.inner_radius = 0.97
		mesh.outer_radius = 1.0
		mesh.rings = 40
		mesh.ring_segments = 6
		_geometry["ring"] = mesh
	return _geometry["ring"] as TorusMesh

static func _contact(stage, at: Vector3, size: Vector2, angle: float) -> void:
	if _contact_material == null:
		var image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
		for y in range(64):
			for x in range(64):
				var uv := Vector2((x + 0.5) / 32.0 - 1.0, (y + 0.5) / 32.0 - 1.0)
				var alpha: float = pow(maxf(0.0, 1.0 - uv.length()), 1.8) * 0.55
				image.set_pixel(x, y, Color(0.035, 0.045, 0.044, alpha))
		_contact_material = StandardMaterial3D.new()
		_contact_material.albedo_texture = ImageTexture.create_from_image(image)
		_contact_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_contact_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_contact_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_contact_material.no_depth_test = false
		_contact_material.render_priority = 1
	if not _geometry.has("shadow_plane"):
		var mesh := QuadMesh.new()
		mesh.size = Vector2.ONE
		_geometry["shadow_plane"] = mesh
	var basis := Basis(Vector3.UP, angle) * Basis(Vector3.RIGHT, -PI / 2.0)
	stage._batch_instance(_geometry["shadow_plane"], Transform3D(basis.scaled_local(Vector3(size.x, size.y, 1)), at), _contact_material, false)

static func _light(stage, at: Vector3, color: Color, energy: float, distance: float, primary: bool = false) -> void:
	var light := OmniLight3D.new()
	light.position = at
	light.light_color = color
	light.light_energy = energy
	light.omni_range = distance
	light.omni_attenuation = 1.4
	light.shadow_enabled = false
	stage._visual_regions[stage._batch_region].add_child(light)
	stage.register_room_light(light, stage._batch_region, primary)
