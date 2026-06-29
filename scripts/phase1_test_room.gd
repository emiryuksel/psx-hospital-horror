# FAZ 1 test odası — PSX material'lı primitive mesh'ler, collision ve fog ortamı kurar.
extends Node3D

const WALL_COLOR := Color(0.35, 0.32, 0.30)
const FLOOR_COLOR := Color(0.22, 0.20, 0.18)
const CUBE_COLOR := Color(0.55, 0.15, 0.12)
const ACCENT_COLOR := Color(0.18, 0.22, 0.28)
const CRATE_COLOR := Color(0.45, 0.28, 0.15)

const GENERATED_GROUP := "generated_room"


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


func _rebuild_geometry() -> void:
	_clear_generated()
	_build_room()
	_build_props()
	_build_interactables()
	_build_pickups()
	if not Engine.is_editor_hint():
		_build_enemies()
	PsxMaterialHelper.fix_culling_tree(self)


func _clear_generated() -> void:
	for child in get_children():
		if child.is_in_group(GENERATED_GROUP):
			child.queue_free()


func _apply_fog_settings() -> void:
	var world_env: WorldEnvironment = get_node_or_null("WorldEnvironment")
	if world_env and world_env.environment:
		world_env.environment.fog_enabled = PsxSettings.fog_enabled
		world_env.environment.fog_density = PsxSettings.fog_density
		world_env.environment.fog_light_color = PsxSettings.fog_color


func _build_room() -> void:
	var room_size := Vector3(8.0, 3.0, 8.0)
	var wall_thickness := 0.35

	_add_solid_box("Floor", Vector3(0, -wall_thickness * 0.5, 0), Vector3(room_size.x, wall_thickness, room_size.z), FLOOR_COLOR)
	_add_solid_box("Ceiling", Vector3(0, room_size.y, 0), Vector3(room_size.x, wall_thickness, room_size.z), FLOOR_COLOR * 0.8)

	_add_solid_box("WallNorth", Vector3(0, room_size.y * 0.5, -room_size.z * 0.5), Vector3(room_size.x, room_size.y, wall_thickness), WALL_COLOR)
	_add_solid_box("WallSouth", Vector3(0, room_size.y * 0.5, room_size.z * 0.5), Vector3(room_size.x, room_size.y, wall_thickness), WALL_COLOR)
	_add_solid_box("WallEast", Vector3(room_size.x * 0.5, room_size.y * 0.5, 0), Vector3(wall_thickness, room_size.y, room_size.z), WALL_COLOR * 0.95)
	_add_solid_box("WallWest", Vector3(-room_size.x * 0.5, room_size.y * 0.5, 0), Vector3(wall_thickness, room_size.y, room_size.z), WALL_COLOR * 0.9)


func _build_props() -> void:
	_add_solid_box("CenterCube", Vector3(0, 0.75, -2.0), Vector3(1.5, 1.5, 1.5), CUBE_COLOR)
	_add_solid_box("SidePillar", Vector3(2.5, 1.0, 1.5), Vector3(0.6, 2.0, 0.6), ACCENT_COLOR)
	_add_solid_box("Ramp", Vector3(-2.0, 0.25, 2.0), Vector3(2.0, 0.5, 1.5), WALL_COLOR * 1.1)


func _build_interactables() -> void:
	_add_interactable_crate("TestCrate", Vector3(-2.0, 0.5, -1.0), Vector3(1.0, 1.0, 1.0))


func _build_pickups() -> void:
	_add_pickup("PickupHerb", "green_herb", 1, Vector3(1.2, 0.2, 2.8), Vector3(0.3, 0.3, 0.3), Color(0.2, 0.75, 0.3))
	_add_pickup("PickupNote", "note_diary", 1, Vector3(-3.2, 0.9, -2.0), Vector3(0.25, 0.35, 0.05), Color(0.85, 0.8, 0.65))
	_add_pickup("PickupEmptyMag", "empty_mag", 1, Vector3(0.8, 0.15, 1.2), Vector3(0.2, 0.25, 0.1), Color(0.35, 0.35, 0.4))
	_add_pickup("PickupAmmo", "pistol_ammo", 3, Vector3(-0.6, 0.15, 1.2), Vector3(0.25, 0.2, 0.25), Color(0.8, 0.75, 0.2))
	_add_pickup("PickupKey", "rusty_key", 1, Vector3(3.0, 0.15, -2.5), Vector3(0.15, 0.35, 0.05), Color(0.75, 0.55, 0.2))


func _add_pickup(
	node_name: String,
	item_id: String,
	count: int,
	pos: Vector3,
	box_size: Vector3,
	color: Color
) -> void:
	var pickup := Node3D.new()
	pickup.name = node_name
	pickup.position = pos
	pickup.add_to_group(GENERATED_GROUP)
	pickup.set_script(load("res://scripts/inventory/pickup_item.gd"))
	pickup.set("item_id", item_id)
	pickup.set("pickup_count", count)
	pickup.set("pickup_color", color)

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
	pickup.add_child(body)
	add_child(pickup)


func _build_enemies() -> void:
	var enemy_scene: PackedScene = load("res://scenes/enemies/test_enemy.tscn")
	var enemy: EnemyAI = enemy_scene.instantiate() as EnemyAI
	enemy.position = Vector3(2.5, 0.0, -2.8)
	enemy.name = "TestEnemy"
	enemy.add_to_group(GENERATED_GROUP)
	add_child(enemy)


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


func _add_interactable_crate(node_name: String, pos: Vector3, box_size: Vector3) -> void:
	var crate: Node3D = Node3D.new()
	crate.name = node_name
	crate.position = pos
	crate.add_to_group(GENERATED_GROUP)
	crate.set_script(load("res://scripts/interaction/test_crate_interactable.gd"))

	var body := StaticBody3D.new()
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = box_size
	mesh_instance.mesh = box
	mesh_instance.material_override = PsxMaterialHelper.create_material(CRATE_COLOR, true)

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = box_size
	collision.shape = shape

	body.add_child(mesh_instance)
	body.add_child(collision)
	crate.add_child(body)
	add_child(crate)
