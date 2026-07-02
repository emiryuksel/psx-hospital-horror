# Pump Room soğutucu valfi — çevrilince coolant akar, generator hazır olur.
# fuse_panel.gd deseninin klonu: Part II akışında valve_open bayrağını set eder.
extends Interactable

var _opened: bool = false


func _ready() -> void:
	super._ready()
	add_to_group("save_interactable")
	interacted.connect(_on_interacted)
	_sync_from_quest()
	_refresh_prompt()


func _on_interacted(_actor: Node3D) -> void:
	if _opened:
		InventoryManager.note_requested.emit(
			"Coolant line is open. The generator can turn over now.",
			"Coolant Valve"
		)
		return

	_opened = true
	AudioManager.play_3d("fuse_install", global_position, -1.0)
	AudioManager.play_3d("exit_open", global_position, -6.0, 0.7, 0.85)
	_apply_opened_visual()
	QuestManager.on_valve_opened()
	InnerVoiceManager.trigger("valve_opened")
	_refresh_prompt()


func _sync_from_quest() -> void:
	if QuestManager.valve_open:
		_opened = true
		_apply_opened_visual()
		_refresh_prompt()


func _apply_opened_visual() -> void:
	if _mesh and _mesh.material_override != null:
		PsxMaterialHelper.set_albedo(_mesh.material_override, Color(0.35, 0.55, 0.42))


func _refresh_prompt() -> void:
	prompt_text = "Valve open" if _opened else "Turn coolant valve"


func get_save_id() -> String:
	return name


func get_save_data() -> Dictionary:
	return {"save_id": get_save_id(), "opened": _opened}


func apply_save_data(data: Dictionary) -> void:
	_opened = bool(data.get("opened", false))
	if _opened:
		_apply_opened_visual()
	_refresh_prompt()
