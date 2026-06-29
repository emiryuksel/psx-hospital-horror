# Asansör paneli — güç durumuna göre mesaj değişir.
extends Interactable


func _ready() -> void:
	super._ready()
	prompt_text = "Check elevator"
	interacted.connect(_on_interacted)


func _on_interacted(_actor: Node3D) -> void:
	if QuestManager.power_on:
		InventoryManager.note_requested.emit(
			"Elevator motors responding… but access is still restricted.\nBasement generator required for full service.\n\n(Part II — coming soon)",
			"Elevator Panel"
		)
	else:
		InventoryManager.note_requested.emit(
			"DEAD — NO POWER\n\nCheck the breaker panel on the west wall.",
			"Elevator Panel"
		)
