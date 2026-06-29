# FAZ 1 test kamerası — mouse ile bakış, wobble efektini gözlemlemek için.
extends Camera3D

@export var mouse_sensitivity: float = 0.002
@export var orbit_speed: float = 0.3
@export var use_mouse_look: bool = true
@export var auto_orbit: bool = false

var _yaw: float = 0.0
var _pitch: float = 0.0


func _ready() -> void:
	_yaw = rotation.y
	_pitch = rotation.x
	if use_mouse_look:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and use_mouse_look:
		_yaw -= event.relative.x * mouse_sensitivity
		_pitch -= event.relative.y * mouse_sensitivity
		_pitch = clampf(_pitch, deg_to_rad(-85.0), deg_to_rad(85.0))
		rotation = Vector3(_pitch, _yaw, 0.0)

	if event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(delta: float) -> void:
	if auto_orbit and not use_mouse_look:
		_yaw += orbit_speed * delta
		rotation = Vector3(_pitch, _yaw, 0.0)
