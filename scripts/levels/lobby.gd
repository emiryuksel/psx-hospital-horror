# St. Véronique — Main Lobby blockout (placeholder primitives).
extends Node3D

const GENERATED_GROUP := "generated_lobby"

# Clinical placeholder palette
const FLOOR_COLOR := Color(0.28, 0.30, 0.29)
const WALL_COLOR := Color(0.62, 0.60, 0.56)
const CEILING_COLOR := Color(0.48, 0.47, 0.45)
const TRIM_COLOR := Color(0.38, 0.36, 0.34)
const RECEPTION_COLOR := Color(0.32, 0.24, 0.18)
const CHAIR_COLOR := Color(0.42, 0.18, 0.15)
const DEBRIS_COLOR := Color(0.30, 0.28, 0.26)
const MIST_COLOR := Color(0.78, 0.80, 0.84, 0.88)
const ELEVATOR_COLOR := Color(0.25, 0.27, 0.30)

# Interior footprint (meters) — human-scale, player capsule ~1.8m
const LOBBY_SIZE := Vector3(14.0, 3.2, 12.0)
const WALL_THICK := 0.35
const CORRIDOR_WIDTH := 3.2
const CORRIDOR_LENGTH := 7.0


func _ready() -> void:
	if not Engine.is_editor_hint():
		_apply_fog_settings()
		PsxSettings.settings_changed.connect(_apply_fog_settings)
	_rebuild_geometry()
	if not Engine.is_editor_hint():
		call_deferred("_try_apply_save")


func _try_apply_save() -> void:
	if not SaveManager.has_pending_load():
		return
	await get_tree().process_frame
	SaveManager.apply_to_current_scene()


func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return

	var key: Key = event.keycode
	if key == KEY_NONE:
		key = event.physical_keycode

	if key == KEY_F5 or key == KEY_F6:
		_mark_input_handled()
		SaveManager.save_game()
	elif key == KEY_F9:
		_mark_input_handled()
		SaveManager.load_game()


func _mark_input_handled() -> void:
	var vp := get_viewport()
	if vp:
		vp.set_input_as_handled()


func _apply_fog_settings() -> void:
	var world_env: WorldEnvironment = get_node_or_null("WorldEnvironment")
	if world_env and world_env.environment:
		world_env.environment.fog_enabled = PsxSettings.fog_enabled
		world_env.environment.fog_density = PsxSettings.fog_density
		world_env.environment.fog_light_color = PsxSettings.fog_color


func _rebuild_geometry() -> void:
	_clear_generated()
	_build_shell()
	_build_reception()
	_build_props()
	_build_mist_windows()
	_build_patient_wing_stub()
	_build_interactables()
	PsxMaterialHelper.fix_culling_tree(self)


func _clear_generated() -> void:
	for child in get_children():
		if child.is_in_group(GENERATED_GROUP):
			child.queue_free()


func _build_shell() -> void:
	var half := LOBBY_SIZE * 0.5
	var h := LOBBY_SIZE.y
	var wt := WALL_THICK

	_add_solid_box("Floor", Vector3(0, -wt * 0.5, 0), Vector3(LOBBY_SIZE.x, wt, LOBBY_SIZE.z), FLOOR_COLOR)
	_add_solid_box("Ceiling", Vector3(0, h, 0), Vector3(LOBBY_SIZE.x, wt, LOBBY_SIZE.z), CEILING_COLOR)

	# South wall (entrance) — segments around 4m door gap
	var door_w := 4.0
	var side_w := (LOBBY_SIZE.x - door_w) * 0.5
	_add_solid_box("WallSouthLeft", Vector3(-half.x + side_w * 0.5, h * 0.5, half.z), Vector3(side_w, h, wt), WALL_COLOR)
	_add_solid_box("WallSouthRight", Vector3(half.x - side_w * 0.5, h * 0.5, half.z), Vector3(side_w, h, wt), WALL_COLOR)
	_add_solid_box("WallSouthHeader", Vector3(0, h - 0.4, half.z), Vector3(door_w, 0.8, wt), WALL_COLOR)

	# North wall — patient wing opening
	var north_gap := CORRIDOR_WIDTH
	var north_side := (LOBBY_SIZE.x - north_gap) * 0.5
	_add_solid_box("WallNorthLeft", Vector3(-half.x + north_side * 0.5, h * 0.5, -half.z), Vector3(north_side, h, wt), WALL_COLOR)
	_add_solid_box("WallNorthRight", Vector3(half.x - north_side * 0.5, h * 0.5, -half.z), Vector3(north_side, h, wt), WALL_COLOR)
	_add_solid_box("WallNorthHeader", Vector3(0, h - 0.35, -half.z), Vector3(north_gap, 0.7, wt), WALL_COLOR)

	# East / west full walls
	_add_solid_box("WallEast", Vector3(half.x, h * 0.5, 0), Vector3(wt, h, LOBBY_SIZE.z), WALL_COLOR * 0.95)
	_add_solid_box("WallWest", Vector3(-half.x, h * 0.5, 0), Vector3(wt, h, LOBBY_SIZE.z), WALL_COLOR * 0.92)

	# Basement stair alcove + debris block (west side, mid)
	_add_solid_box("StairDebris", Vector3(-half.x + 1.2, 0.55, 0.5), Vector3(1.8, 1.1, 2.4), DEBRIS_COLOR)

	# Elevator shaft blockout (east)
	_add_solid_box("ElevatorFrame", Vector3(half.x - 1.0, h * 0.5, -2.0), Vector3(1.6, h, 2.2), ELEVATOR_COLOR)


func _build_reception() -> void:
	# L-shaped desk facing entrance
	_add_solid_box("ReceptionMain", Vector3(0, 0.55, -1.5), Vector3(3.6, 1.1, 0.8), RECEPTION_COLOR)
	_add_solid_box("ReceptionSide", Vector3(1.4, 0.55, -0.6), Vector3(0.8, 1.1, 2.0), RECEPTION_COLOR * 0.9)


func _build_props() -> void:
	_add_solid_box("ChairOverturned", Vector3(-2.2, 0.25, 0.8), Vector3(0.55, 0.5, 0.55), CHAIR_COLOR)
	_add_solid_box("ChairA", Vector3(2.5, 0.35, 1.2), Vector3(0.5, 0.7, 0.5), CHAIR_COLOR * 0.85)
	_add_solid_box("Bench", Vector3(-3.5, 0.25, -3.0), Vector3(2.0, 0.5, 0.6), TRIM_COLOR)


func _build_mist_windows() -> void:
	var half_z := LOBBY_SIZE.z * 0.5
	var placements := [
		Vector3(-1.2, 1.4, half_z - 0.05),
		Vector3(1.2, 1.4, half_z - 0.05),
		Vector3(0.0, 2.1, half_z - 0.05),
	]
	for i in placements.size():
		_add_mist_plane("MistWindow%d" % i, placements[i], Vector2(1.6, 1.8))


func _build_patient_wing_stub() -> void:
	# Short corridor north of lobby — blockout only
	var start_z := -LOBBY_SIZE.z * 0.5 - WALL_THICK
	var mid_z := start_z - CORRIDOR_LENGTH * 0.5
	_add_solid_box("CorridorFloor", Vector3(0, -WALL_THICK * 0.5, mid_z), Vector3(CORRIDOR_WIDTH, WALL_THICK, CORRIDOR_LENGTH), FLOOR_COLOR * 0.9)
	_add_solid_box("CorridorCeil", Vector3(0, LOBBY_SIZE.y, mid_z), Vector3(CORRIDOR_WIDTH, WALL_THICK, CORRIDOR_LENGTH), CEILING_COLOR)
	_add_solid_box("CorridorWallL", Vector3(-CORRIDOR_WIDTH * 0.5, LOBBY_SIZE.y * 0.5, mid_z), Vector3(WALL_THICK, LOBBY_SIZE.y, CORRIDOR_LENGTH), WALL_COLOR)
	_add_solid_box("CorridorWallR", Vector3(CORRIDOR_WIDTH * 0.5, LOBBY_SIZE.y * 0.5, mid_z), Vector3(WALL_THICK, LOBBY_SIZE.y, CORRIDOR_LENGTH), WALL_COLOR)
	_add_solid_box("CorridorEnd", Vector3(0, LOBBY_SIZE.y * 0.5, start_z - CORRIDOR_LENGTH), Vector3(CORRIDOR_WIDTH, LOBBY_SIZE.y, WALL_THICK), WALL_COLOR)


func _build_interactables() -> void:
	_add_note_interactable(
		"ReceptionNote",
		Vector3(0, 1.05, -1.5),
		Vector3(0.5, 0.05, 0.35),
		Color(0.85, 0.82, 0.72),
		"Reception Log (placeholder)",
		"DAY 1 — Visitors stopped coming after the fog.\nWe were told to stay inside.\n\n(Full text will link to narrative-fragments.md in FAZ 3.)",
		"lore_major"
	)
	_add_inner_voice_zone(
		"ReceptionSafeZone",
		Vector3(0, 1.2, -2.2),
		Vector3(4.0, 2.4, 3.0),
		"safe_zone"
	)
	_add_locked_door(
		"BasementDoor",
		Vector3(-LOBBY_SIZE.x * 0.5 + 0.6, 1.1, 0.5),
		Vector3(0.25, 2.2, 1.4),
		Color(0.40, 0.38, 0.35)
	)
	_add_simple_interactable(
		"ElevatorPanel",
		Vector3(LOBBY_SIZE.x * 0.5 - 0.55, 1.2, -2.0),
		Vector3(0.15, 0.4, 0.3),
		Color(0.55, 0.50, 0.20),
		"Check elevator",
		"Elevator Panel",
		"Elevator offline (placeholder).\nNo power — basement generator required."
	)


func _add_solid_box(node_name: String, pos: Vector3, box_size: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = pos
	body.add_to_group(GENERATED_GROUP)

	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = box_size
	mesh_instance.mesh = box
	mesh_instance.material_override = PsxMaterialHelper.create_material(color)

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = box_size
	collision.shape = shape

	body.add_child(mesh_instance)
	body.add_child(collision)
	add_child(body)


func _add_mist_plane(node_name: String, pos: Vector3, plane_size: Vector2) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = pos
	body.add_to_group(GENERATED_GROUP)

	var mesh_instance := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = plane_size
	plane.orientation = PlaneMesh.FACE_Z
	mesh_instance.mesh = plane
	mesh_instance.material_override = _create_mist_material()

	body.add_child(mesh_instance)
	add_child(body)


func _create_mist_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = MIST_COLOR
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	return mat


func _add_note_interactable(
	node_name: String,
	pos: Vector3,
	box_size: Vector3,
	color: Color,
	title: String,
	body_text: String,
	inner_voice: String = ""
) -> void:
	var node := Node3D.new()
	node.name = node_name
	node.position = pos
	node.add_to_group(GENERATED_GROUP)
	node.set_script(load("res://scripts/interaction/note_placeholder.gd"))
	node.set("note_title", title)
	node.set("note_body", body_text)
	if not inner_voice.is_empty():
		node.set("inner_voice_trigger", inner_voice)

	var body := StaticBody3D.new()
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = box_size
	mesh_instance.mesh = box
	mesh_instance.material_override = PsxMaterialHelper.create_material(color, true)

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = box_size
	collision.shape = shape

	body.add_child(mesh_instance)
	body.add_child(collision)
	node.add_child(body)
	add_child(node)


func _add_inner_voice_zone(
	node_name: String,
	pos: Vector3,
	box_size: Vector3,
	trigger_id: String
) -> void:
	var area := Area3D.new()
	area.name = node_name
	area.position = pos
	area.add_to_group(GENERATED_GROUP)
	area.set_script(load("res://scripts/components/inner_voice_zone.gd"))
	area.set("trigger_id", trigger_id)

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = box_size
	collision.shape = shape
	area.add_child(collision)
	add_child(area)


func _add_locked_door(node_name: String, pos: Vector3, box_size: Vector3, color: Color) -> void:
	var node := Node3D.new()
	node.name = node_name
	node.position = pos
	node.add_to_group(GENERATED_GROUP)
	node.set_script(load("res://scripts/interaction/locked_door.gd"))

	var body := StaticBody3D.new()
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = box_size
	mesh_instance.mesh = box
	mesh_instance.material_override = PsxMaterialHelper.create_material(color, true)

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = box_size
	collision.shape = shape

	body.add_child(mesh_instance)
	body.add_child(collision)
	node.add_child(body)
	add_child(node)


func _add_simple_interactable(
	node_name: String,
	pos: Vector3,
	box_size: Vector3,
	color: Color,
	prompt: String,
	note_title: String,
	note_body: String
) -> void:
	var node := Node3D.new()
	node.name = node_name
	node.position = pos
	node.add_to_group(GENERATED_GROUP)
	node.set_script(load("res://scripts/interaction/note_placeholder.gd"))
	node.set("note_title", note_title)
	node.set("note_body", note_body)
	node.set("prompt_text", prompt)

	var body := StaticBody3D.new()
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = box_size
	mesh_instance.mesh = box
	mesh_instance.material_override = PsxMaterialHelper.create_material(color, true)

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = box_size
	collision.shape = shape

	body.add_child(mesh_instance)
	body.add_child(collision)
	node.add_child(body)
	add_child(node)
