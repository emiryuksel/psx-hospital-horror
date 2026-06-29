# Can sistemi — hasar alma ve ölüm sinyalleri.
class_name HealthComponent
extends Node

signal health_changed(current: float, maximum: float)
signal died
signal damaged(amount: float, source: Node)

@export var max_health: float = 100.0

var health: float = 100.0
var _is_dead: bool = false


func _ready() -> void:
	health = max_health


func take_damage(amount: float, source: Node = null) -> void:
	if _is_dead or amount <= 0.0:
		return

	health = maxf(0.0, health - amount)
	health_changed.emit(health, max_health)
	damaged.emit(amount, source)

	if health <= 0.0:
		_is_dead = true
		died.emit()


func is_dead() -> bool:
	return _is_dead


func set_health(value: float) -> void:
	health = clampf(value, 0.0, max_health)
	_is_dead = health <= 0.0
	health_changed.emit(health, max_health)
