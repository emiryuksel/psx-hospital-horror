# Test etkileşim objesi — E ile mesaj gösterir ve rengi değiştirir.
extends Interactable

@export var activated_color: Color = Color(0.2, 0.7, 0.3)

var _activated: bool = false


func _ready() -> void:
	super._ready()
	add_to_group("save_interactable")
	prompt_text = "Inspect crate"
	interacted.connect(_on_interacted)


func _on_interacted(_actor: Node3D) -> void:
	_activated = not _activated
	prompt_text = "Crate opened" if _activated else "Inspect crate"
	if _mesh and _mesh.material_override != null:
		_base_color = activated_color if _activated else Color(0.45, 0.28, 0.15)
		PsxMaterialHelper.set_albedo(_mesh.material_override, _base_color)


func get_save_id() -> String:
	return name


func get_save_data() -> Dictionary:
	return {
		"save_id": get_save_id(),
		"activated": _activated,
	}


func apply_save_data(data: Dictionary) -> void:
	_activated = bool(data.get("activated", false))
	prompt_text = "Crate opened" if _activated else "Inspect crate"
	if _mesh and _mesh.material_override != null:
		_base_color = activated_color if _activated else Color(0.45, 0.28, 0.15)
		PsxMaterialHelper.set_albedo(_mesh.material_override, _base_color)
