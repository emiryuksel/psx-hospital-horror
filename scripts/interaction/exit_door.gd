# Kırmızı EXIT kapısı — Part I'de açılmaz; asansöre yönlendirir.
extends Interactable


func _ready() -> void:
	super._ready()
	add_to_group("save_interactable")
	interacted.connect(_on_interacted)
	_apply_glow()
	_refresh_prompt()


func _apply_glow() -> void:
	if _mesh == null:
		return
	var mat := _mesh.material_override as StandardMaterial3D
	if mat == null:
		return

	if mat.albedo_texture == null:
		var path := PsxSurfaceTextures.EXIT_DOOR_PATH
		if ResourceLoader.exists(path):
			var tex := load(path) as Texture2D
			if tex:
				mat.albedo_texture = tex
				mat.albedo_color = Color.WHITE

	if mat.albedo_texture:
		mat.emission_enabled = true
		mat.emission_texture = mat.albedo_texture
		mat.emission = Color(1.0, 1.0, 1.0)
		mat.emission_energy_multiplier = 0.3
	else:
		mat.albedo_color = Color(0.55, 0.10, 0.09)
		mat.emission_enabled = true
		mat.emission_texture = null
		mat.emission = Color(0.70, 0.12, 0.10)
		mat.emission_energy_multiplier = 0.25


func _on_interacted(_actor: Node3D) -> void:
	AudioManager.play_3d("exit_sealed", global_position, -1.0)

	if QuestManager.part1_state == QuestManager.Part1State.SEEK_ELEVATOR:
		InventoryManager.note_requested.emit(
			"The exit is welded shut — emergency protocol.\nThe only way down is the elevator past reception, east wall.",
			"EXIT — BLOCKED"
		)
		InnerVoiceManager.trigger("memory_glitch")
		return

	if not QuestManager.power_on:
		InventoryManager.note_requested.emit(
			"The exit is magnetically sealed.\nEmergency power must be restored first.",
			"EXIT — SEALED"
		)
		if QuestManager.part1_state == QuestManager.Part1State.SEEK_FUSE:
			InnerVoiceManager.trigger("exit_locked")
		else:
			InnerVoiceManager.trigger("memory_glitch")
		return

	InventoryManager.note_requested.emit(
		"Still locked. Find the breaker panel and restore power before anything else opens.",
		"EXIT — SEALED"
	)


func _refresh_prompt() -> void:
	prompt_text = "Try EXIT door"


func get_save_id() -> String:
	return name


func get_save_data() -> Dictionary:
	return {"save_id": get_save_id(), "opened": false}


func apply_save_data(_data: Dictionary) -> void:
	_refresh_prompt()
