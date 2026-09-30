extends Node3D
class_name TeacherAlly

const Campaign = preload("res://Scripts/campaign_data.gd")
const FONT = preload("res://Assets/Fonts/NotoSansThai.ttf")
const WorldLabel = preload("res://Scripts/world_label.gd")

var teacher_index := 0
var rescued := false
var animator: AnimationPlayer
var clips: Dictionary = {}
var caption: Label3D
var indicator: MeshInstance3D
var animation_time := 0.0

func _ready() -> void:
	# Allies are event-anchored, invulnerable, nonblocking and never enemy targets.
	add_to_group("teacher_allies")
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
	WorldLabel.apply(caption, 64, 0.004)
	caption.position.y = 2.45
	caption.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(caption)
	indicator = MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.65
	ring.outer_radius = 0.73
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
		caption.text = "%s\n%s" % [Campaign.TEACHER_NAMES[teacher_index].replace("อาจารย์", "อ."), "T • ช่วยสู้" if rescued else "ช่วยอาจารย์!"]
		caption.modulate = Color("a5eff0") if rescued else Color("ffe2ad")

func show_support() -> void:
	animation_time = 1.0
	_play("guard")
	var tween := create_tween()
	tween.tween_property(indicator, "scale", Vector3(1.55, 0.12, 1.55), 0.18)
	tween.tween_property(indicator, "scale", Vector3(1.0, 0.12, 1.0), 0.6)

func _process(delta: float) -> void:
	if animation_time > 0.0:
		animation_time -= delta
		if animation_time <= 0.0:
			_play("idle")

func _play(key: String) -> void:
	if animator and clips.has(key):
		if key == "idle":
			animator.get_animation(clips[key]).loop_mode = Animation.LOOP_LINEAR
		animator.play(clips[key], 0.18)

func _find_animator(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_animator(child)
		if found:
			return found
	return null
