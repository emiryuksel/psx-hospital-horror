# Generator Room jeneratör paneli — valf açıksa çalıştırılır, bodrum gücü gelir.
# fuse_panel.gd deseninin klonu: on_generator_started() ile asansör tekrar aktif olur.
extends Interactable

var _started: bool = false


func _ready() -> void:
	super._ready()
	add_to_group("save_interactable")
	interacted.connect(_on_interacted)
	_sync_from_quest()
	_refresh_prompt()


func _on_interacted(_actor: Node3D) -> void:
	if _started:
		InventoryManager.note_requested.emit(
			"Sub-generator running. The elevator has power again.",
			"Generator"
		)
		return

	if not QuestManager.valve_open:
		AudioManager.play_3d("door_locked", global_position, -2.0, 0.9, 1.0)
		InventoryManager.note_requested.emit(
			"The starter cranks and dies.\nCOOLANT LOW — open the valve in the PUMP ROOM first.",
			"Generator"
		)
		return

	_started = true
	AudioManager.play_3d("fuse_install", global_position, -1.0)
	_apply_started_visual()
	QuestManager.on_generator_started()
	InnerVoiceManager.trigger("generator_online")
	_refresh_prompt()


func _sync_from_quest() -> void:
	if QuestManager.basement_power_on:
		_started = true
		_apply_started_visual()
		_refresh_prompt()


func _apply_started_visual() -> void:
	if _mesh and _mesh.material_override != null:
		PsxMaterialHelper.set_albedo(_mesh.material_override, Color(0.5, 0.55, 0.4))


func _refresh_prompt() -> void:
	prompt_text = "Generator running" if _started else "Start generator"


func get_save_id() -> String:
	return name


func get_save_data() -> Dictionary:
	return {"save_id": get_save_id(), "started": _started}


func apply_save_data(data: Dictionary) -> void:
	_started = bool(data.get("started", false))
	if _started:
		_apply_started_visual()
	_refresh_prompt()
