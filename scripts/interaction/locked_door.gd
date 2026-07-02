# Kilitli kapı placeholder — FAZ 3 anahtar item bağlantısı için.
extends Interactable

@export var required_key_id: String = "maintenance_key"
@export var locked_message: String = "Locked — Maintenance Key required"

var _is_unlocked: bool = false


func _ready() -> void:
	super._ready()
	add_to_group("save_interactable")
	prompt_text = "Try door"
	interacted.connect(_on_interacted)


func _on_interacted(_actor: Node3D) -> void:
	if _is_unlocked:
		return

	if InventoryManager.has_item(required_key_id):
		_is_unlocked = true
		AudioManager.play_3d("exit_open", global_position, -4.0)
		HudManager.show_message("Door unlocked")
		_open_door()
	else:
		AudioManager.play_3d("door_locked", global_position, -2.0, 0.95, 1.05)
		InventoryManager.note_requested.emit(locked_message, "Locked Door")


# Kapıyı fiziksel olarak geçilebilir yap: collision kapat + mesh gizle.
func _open_door() -> void:
	prompt_text = "Open doorway"
	for body in _find_static_bodies(self):
		for c in body.get_children():
			if c is CollisionShape3D:
				(c as CollisionShape3D).disabled = true
	if _mesh:
		_mesh.visible = false


func _find_static_bodies(node: Node) -> Array[StaticBody3D]:
	var result: Array[StaticBody3D] = []
	if node is StaticBody3D:
		result.append(node as StaticBody3D)
	for child in node.get_children():
		result.append_array(_find_static_bodies(child))
	return result


func get_save_id() -> String:
	return name


func get_save_data() -> Dictionary:
	return {"save_id": get_save_id(), "unlocked": _is_unlocked}


func apply_save_data(data: Dictionary) -> void:
	_is_unlocked = bool(data.get("unlocked", false))
	if _is_unlocked:
		_open_door()
