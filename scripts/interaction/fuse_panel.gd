# Lobby breaker panel — generator fuse takılır, güç geri gelir.
extends Interactable

const FUSE_ITEM_ID := "generator_fuse"

var _installed: bool = false


func _ready() -> void:
	super._ready()
	add_to_group("save_interactable")
	interacted.connect(_on_interacted)
	QuestManager.power_restored.connect(_on_power_restored)
	_sync_from_quest()
	_refresh_prompt()


func _on_interacted(_actor: Node3D) -> void:
	if _installed:
		InventoryManager.note_requested.emit(
			"Main breaker online. Emergency circuits are live again.",
			"Breaker Panel"
		)
		return

	if not InventoryManager.has_item(FUSE_ITEM_ID):
		InventoryManager.note_requested.emit(
			"Fuse socket empty. The label reads: UTILITY CLOSET — PATIENT WING.",
			"Breaker Panel"
		)
		return

	if not InventoryManager.remove_item_by_id(FUSE_ITEM_ID, 1):
		return

	_installed = true
	AudioManager.play_3d("fuse_install", global_position, -1.0)
	_apply_installed_visual()
	QuestManager.on_fuse_installed()
	_refresh_prompt()


func _on_power_restored() -> void:
	_sync_from_quest()


func _sync_from_quest() -> void:
	if QuestManager.power_on:
		_installed = true
		_apply_installed_visual()
		_refresh_prompt()


func _apply_installed_visual() -> void:
	if _mesh and _mesh.material_override != null:
		PsxMaterialHelper.set_albedo(_mesh.material_override, Color(0.45, 0.55, 0.38))


func _refresh_prompt() -> void:
	prompt_text = "Breaker online" if _installed else "Install fuse"


func get_save_id() -> String:
	return name


func get_save_data() -> Dictionary:
	return {"save_id": get_save_id(), "installed": _installed}


func apply_save_data(data: Dictionary) -> void:
	_installed = bool(data.get("installed", false))
	if _installed:
		_apply_installed_visual()
	_refresh_prompt()
