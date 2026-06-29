# Asset showcase — imported .glb/.fbx test odası (FAZ 2.5).
extends Node3D

const GENERATED_GROUP := "generated_showcase"
const FLOOR_COLOR := Color(0.28, 0.30, 0.29)
const WALL_COLOR := Color(0.58, 0.56, 0.52)
const DOOR_COLOR := Color(0.36, 0.30, 0.26)


func _ready() -> void:
	if not Engine.is_editor_hint():
		_apply_fog_settings()
		PsxSettings.settings_changed.connect(_apply_fog_settings)
	_build_room()
	_build_example_door()
	if not Engine.is_editor_hint():
		call_deferred("_try_apply_save")
	PsxMaterialHelper.fix_culling_tree(self)


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


func _build_room() -> void:
	var size := Vector3(10.0, 3.0, 10.0)
	var wt := 0.35
	_add_box("Floor", Vector3(0, -wt * 0.5, 0), Vector3(size.x, wt, size.z), FLOOR_COLOR)
	_add_box("Ceiling", Vector3(0, size.y, 0), Vector3(size.x, wt, size.z), WALL_COLOR * 0.85)
	_add_box("WallN", Vector3(0, size.y * 0.5, -size.z * 0.5), Vector3(size.x, size.y, wt), WALL_COLOR)
	_add_box("WallS", Vector3(0, size.y * 0.5, size.z * 0.5), Vector3(size.x, size.y, wt), WALL_COLOR)
	_add_box("WallE", Vector3(size.x * 0.5, size.y * 0.5, 0), Vector3(wt, size.y, size.z), WALL_COLOR)
	_add_box("WallW", Vector3(-size.x * 0.5, size.y * 0.5, 0), Vector3(wt, size.y, size.z), WALL_COLOR)


func _build_example_door() -> void:
	var pivot := Node3D.new()
	pivot.name = "ExampleDoor"
	pivot.position = Vector3(0, 0, -4.0)
	pivot.set_script(load("res://scripts/interaction/door_interactable.gd"))
	pivot.add_to_group(GENERATED_GROUP)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "DoorMesh"
	mesh_instance.position = Vector3(0.6, 1.1, 0)
	var box := BoxMesh.new()
	box.size = Vector3(0.2, 2.2, 1.2)
	mesh_instance.mesh = box
	mesh_instance.material_override = PsxMaterialHelper.create_material(DOOR_COLOR)

	var body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = box.size
	collision.shape = shape
	collision.position = mesh_instance.position
	body.add_child(mesh_instance)
	body.add_child(collision)
	pivot.add_child(body)
	add_child(pivot)


func _add_box(node_name: String, pos: Vector3, box_size: Vector3, color: Color) -> void:
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
