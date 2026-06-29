# El feneri — pil ömrü ile sınırlı SpotLight3D.
extends Node3D

signal battery_changed(current: float, maximum: float)
signal toggled(is_on: bool)

@export var max_battery: float = 100.0
@export var drain_rate: float = 1.2
@export var idle_regen_rate: float = 1.5

@onready var _light: SpotLight3D = $SpotLight3D

var battery: float = 100.0
var is_on: bool = false


@export var start_on: bool = false
var _has_flashlight: bool = false


func _ready() -> void:
	battery = max_battery
	# Flashlight baslatmada devre disi — pickup alininca etkinlesir
	set_enabled(false)
	_light.visible = false
	InventoryManager.item_added.connect(_on_item_added)
	call_deferred("_check_flashlight_from_inventory")


func _check_flashlight_from_inventory() -> void:
	if InventoryManager.has_item("flashlight"):
		_has_flashlight = true
		set_enabled(true)


func _on_item_added(item: Item, _slot_index: int, _count: int) -> void:
	if item != null and item.id == "flashlight":
		_has_flashlight = true
		set_enabled(true)


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("flashlight"):
		toggle()

	if is_on:
		battery = maxf(0.0, battery - drain_rate * delta)
		if battery <= 0.0:
			set_enabled(false)
	else:
		battery = minf(max_battery, battery + idle_regen_rate * delta)

	battery_changed.emit(battery, max_battery)


func toggle() -> void:
	if not _has_flashlight:
		return
	if is_on:
		set_enabled(false)
	elif battery > 0.0:
		set_enabled(true)


func set_enabled(enabled: bool) -> void:
	var was_on := is_on
	is_on = enabled and battery > 0.0
	_light.visible = is_on
	if is_on != was_on and Engine.is_editor_hint() == false and is_inside_tree():
		AudioManager.play("flashlight_click", -4.0, 0.97, 1.03)
	toggled.emit(is_on)


func get_save_data() -> Dictionary:
	return {
		"battery": battery,
		"is_on": is_on,
		"has_flashlight": _has_flashlight,
	}


func apply_save_data(data: Dictionary) -> void:
	if data.is_empty():
		return

	battery = float(data.get("battery", battery))
	_has_flashlight = bool(data.get("has_flashlight", false))
	if _has_flashlight:
		set_enabled(bool(data.get("is_on", false)))
	else:
		set_enabled(false)
	HudManager.update_battery(battery, max_battery)
	battery_changed.emit(battery, max_battery)
