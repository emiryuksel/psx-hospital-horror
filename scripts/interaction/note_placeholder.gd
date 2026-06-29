# Placeholder not etkileşimi — FAZ 3/7'de narrative-fragments.md ile değiştirilecek.
extends Interactable

@export var note_title: String = "Found Note"
@export var note_body: String = "Note found (placeholder)."
@export var inner_voice_trigger: String = ""


func _ready() -> void:
	label_height = 0.45   # yatak basligi ustunde gorunecek kadar yuksek
	super._ready()
	prompt_text = "Read note"
	interacted.connect(_on_interacted)


func get_label_text() -> String:
	return "READ NOTE"


func _on_interacted(_actor: Node3D) -> void:
	InventoryManager.note_requested.emit(note_body, note_title)
	if not inner_voice_trigger.is_empty():
		InnerVoiceManager.trigger(inner_voice_trigger)
