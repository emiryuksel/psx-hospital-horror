# Kapı/dolap etkileşimi — imported mesh'lere bağlanır (pivot altında mesh).
extends Interactable

@export var open_angle_deg: float = 90.0
@export var anim_speed: float = 2.5
@export var starts_open: bool = false

var _is_open: bool = false
var _is_animating: bool = false
var _closed_rotation: float = 0.0
var _pivot: Node3D = null


func _ready() -> void:
	super._ready()
	add_to_group("save_interactable")
	_pivot = self as Node3D
	_closed_rotation = _pivot.rotation.y
	_is_open = starts_open
	if _is_open:
		_pivot.rotation.y = _closed_rotation + deg_to_rad(open_angle_deg)
	prompt_text = "Close door" if _is_open else "Open door"
	interacted.connect(_on_interacted)


func _on_interacted(_actor: Node3D) -> void:
	if _is_animating:
		return
	_is_open = not _is_open
	prompt_text = "Close door" if _is_open else "Open door"
	_animate_door()


func _animate_door() -> void:
	_is_animating = true
	var target := _closed_rotation + (deg_to_rad(open_angle_deg) if _is_open else 0.0)
	var tween := create_tween()
	tween.tween_property(_pivot, "rotation:y", target, 1.0 / anim_speed)
	tween.finished.connect(func() -> void: _is_animating = false)


func get_save_id() -> String:
	return name


func get_save_data() -> Dictionary:
	return {"save_id": get_save_id(), "is_open": _is_open}


func apply_save_data(data: Dictionary) -> void:
	_is_open = bool(data.get("is_open", starts_open))
	_pivot.rotation.y = _closed_rotation + (deg_to_rad(open_angle_deg) if _is_open else 0.0)
	prompt_text = "Close door" if _is_open else "Open door"
