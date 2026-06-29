# Kırmızı EXIT kapısı — karanlıkta parlar, güç gelince açılır (Part I → Part II geçişi).
extends Interactable

var _opened: bool = false


func _ready() -> void:
	super._ready()
	add_to_group("save_interactable")
	interacted.connect(_on_interacted)
	_apply_glow()
	_refresh_prompt()


func _apply_glow() -> void:
	# EXIT levhası ve kırmızı yüzey karanlıkta kendiliğinden parlasın.
	if _mesh == null:
		return
	var mat := _mesh.material_override as StandardMaterial3D
	if mat == null:
		return

	# Texture import yarışı nedeniyle yüklenmemişse garantiye al (yoksa düz beyaza patlıyordu).
	if mat.albedo_texture == null:
		var path := PsxSurfaceTextures.EXIT_DOOR_PATH
		if ResourceLoader.exists(path):
			var tex := load(path) as Texture2D
			if tex:
				mat.albedo_texture = tex
				mat.albedo_color = Color.WHITE

	if mat.albedo_texture:
		# Emission'ı texture ile çarp — kapı kendi renkleriyle (kırmızı + yeşil EXIT) parlar.
		mat.emission_enabled = true
		mat.emission_texture = mat.albedo_texture
		mat.emission = Color(1.0, 1.0, 1.0)
		mat.emission_energy_multiplier = 0.3
	else:
		# Texture hiç yoksa: beyaza patlamak yerine düz kırmızı kapı + sönük kırmızı parıltı.
		mat.albedo_color = Color(0.55, 0.10, 0.09)
		mat.emission_enabled = true
		mat.emission_texture = null
		mat.emission = Color(0.70, 0.12, 0.10)
		mat.emission_energy_multiplier = 0.25


func _on_interacted(_actor: Node3D) -> void:
	if _opened:
		InventoryManager.note_requested.emit(
			"Beyond here, the corridors go dark again.\n\n(Part II — coming soon)",
			"EXIT"
		)
		return

	if not QuestManager.power_on:
		AudioManager.play_3d("exit_sealed", global_position, -1.0)
		InventoryManager.note_requested.emit(
			"The exit is magnetically sealed.\nEmergency power must be restored first.",
			"EXIT — SEALED"
		)
		# Silahi aldiktan sonra kilitli oldugunu fark etme — sigorta hedefini vurgula
		if QuestManager.part1_state == QuestManager.Part1State.SEEK_FUSE:
			InnerVoiceManager.trigger("exit_locked")
		else:
			InnerVoiceManager.trigger("memory_glitch")
		return

	_opened = true
	AudioManager.play_3d("exit_open", global_position, 0.0)
	_refresh_prompt()
	InnerVoiceManager.trigger("safe_zone")
	InventoryManager.note_requested.emit(
		"The magnetic lock clicks open. Cold air spills from the stairwell beyond.\n\n— End of Part I —\n(Part II — coming soon)",
		"EXIT"
	)
	HudManager.update_objective("Part I complete — EXIT unlocked")


func _refresh_prompt() -> void:
	if _opened:
		prompt_text = "Go through EXIT"
	elif QuestManager.power_on:
		prompt_text = "Open EXIT"
	else:
		prompt_text = "Try EXIT door"


func get_save_id() -> String:
	return name


func get_save_data() -> Dictionary:
	return {"save_id": get_save_id(), "opened": _opened}


func apply_save_data(data: Dictionary) -> void:
	_opened = bool(data.get("opened", false))
	_refresh_prompt()
