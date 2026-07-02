# Yaklaşma tetikleyici — oyuncu Area3D'ye girince tek seferlik callback tetikler.
# Level scripti trigger_id ile hangi olayın çalışacağını dinler.
extends Area3D

signal player_entered(trigger_id: String)

@export var trigger_id: String = ""

var _fired: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if _fired:
		return
	if not body.is_in_group("player"):
		return
	_fired = true
	player_entered.emit(trigger_id)


func reset() -> void:
	_fired = false
