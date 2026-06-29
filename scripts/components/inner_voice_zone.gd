# Alan tabanlı inner voice trigger — güvenli oda, lore bölgesi vb.
extends Area3D

@export var trigger_id: String = "safe_zone"
@export var require_player_group: bool = true


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if require_player_group and not body.is_in_group("player"):
		return
	InnerVoiceManager.trigger(trigger_id)
