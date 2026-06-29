# Asansör paneli — güç geldikten sonra Part II'ye geçiş noktası.
extends Interactable


func _ready() -> void:
	super._ready()
	prompt_text = "Check elevator"
	interacted.connect(_on_interacted)


func _on_interacted(_actor: Node3D) -> void:
	if QuestManager.part1_state == QuestManager.Part1State.SEEK_ELEVATOR:
		AudioManager.play_3d("exit_open", global_position, -1.0)
		InventoryManager.note_requested.emit(
			"The car shudders, then descends.\nBasement level unlocked.\n\n— End of Part I —\n(Part II — coming soon)",
			"Elevator"
		)
		HudManager.update_objective("Part I complete — descend via elevator")
		InnerVoiceManager.trigger("safe_zone")
		return

	if QuestManager.power_on:
		InventoryManager.note_requested.emit(
			"Elevator motors online. Basement access should be available now.",
			"Elevator Panel"
		)
	else:
		InventoryManager.note_requested.emit(
			"DEAD — NO POWER\n\nCheck the breaker panel on the west wall.",
			"Elevator Panel"
		)
