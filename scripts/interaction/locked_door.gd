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
		prompt_text = "Door opens (placeholder)"
		return

	if InventoryManager.has_item(required_key_id):
		_is_unlocked = true
		prompt_text = "Door unlocked (placeholder)"
		AudioManager.play_3d("exit_open", global_position, -4.0)
		if _mesh and _mesh.material_override != null:
			PsxMaterialHelper.set_albedo(_mesh.material_override, Color(0.35, 0.42, 0.38))
	else:
		AudioManager.play_3d("door_locked", global_position, -2.0, 0.95, 1.05)
		InventoryManager.note_requested.emit(locked_message, "Locked Door")


func get_save_id() -> String:
	return name


func get_save_data() -> Dictionary:
	return {"save_id": get_save_id(), "unlocked": _is_unlocked}


func apply_save_data(data: Dictionary) -> void:
	_is_unlocked = bool(data.get("unlocked", false))
	if _is_unlocked and _mesh and _mesh.material_override != null:
		PsxMaterialHelper.set_albedo(_mesh.material_override, Color(0.35, 0.42, 0.38))
		prompt_text = "Door unlocked (placeholder)"
