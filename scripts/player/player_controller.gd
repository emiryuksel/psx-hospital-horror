# First-person oyuncu kontrolcüsü — PSX tarzı ağır hareket, stamina, eğilme, head bob.
extends CharacterBody3D

signal stamina_changed(current: float, maximum: float)
signal health_changed(current: float, maximum: float)

@export_group("Health")
@export var max_health: float = 100.0

@export_group("Movement")
@export var walk_speed: float = 2.5
@export var run_speed: float = 4.8
@export var crouch_speed: float = 1.3
@export var acceleration: float = 7.5
@export var deceleration: float = 9.0
@export var gravity: float = 9.8

@export_group("Stamina")
@export var max_stamina: float = 50.0
@export var stamina_drain_rate: float = 22.0
@export var stamina_regen_rate: float = 14.0
@export var min_stamina_to_run: float = 4.0

@export_group("Crouch")
@export var stand_height: float = 1.7
@export var crouch_height: float = 1.0
@export var crouch_lerp_speed: float = 10.0

@export_group("Camera")
@export var mouse_sensitivity: float = 0.002
@export var head_bob_frequency: float = 2.2
@export var head_bob_amplitude: float = 0.035
@export var head_height: float = 1.55

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var _capsule: CapsuleShape3D = collision_shape.shape as CapsuleShape3D
@onready var _interaction: Node = $InteractionComponent
@onready var _flashlight: Node3D = $Head/Flashlight

var _smoothed_velocity: Vector3 = Vector3.ZERO
var _stamina: float = 100.0
var _health: float = 100.0
var _is_crouching: bool = false
var _yaw: float = 0.0
var _pitch: float = 0.0
var _bob_timer: float = 0.0
var _base_head_y: float = 0.0
var _capsule_stand_height: float = 1.4
var _is_dead: bool = false
var _input_locked: bool = false
var _wake_triggered: bool = false
var _step_distance: float = 0.0
var _shake_strength: float = 0.0


func _ready() -> void:
	add_to_group("player")
	_stamina = max_stamina
	_health = max_health
	_yaw = rotation.y
	_base_head_y = head.position.y
	if _capsule:
		_capsule_stand_height = _capsule.height
	if GameSession.intro_pending:
		_input_locked = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	_interaction.focus_changed.connect(_on_focus_changed)
	_flashlight.battery_changed.connect(func(c, m): HudManager.update_battery(c, m))
	InventoryManager.heal_requested.connect(_on_heal_requested)
	if not SaveManager.has_pending_load():
		call_deferred("_sync_hud")


func _sync_hud() -> void:
	HudManager.update_health(_health, max_health)
	HudManager.update_stamina(_stamina, max_stamina)
	HudManager.update_battery(_flashlight.battery, _flashlight.max_battery)


func set_input_locked(locked: bool) -> void:
	_input_locked = locked
	if locked:
		velocity = Vector3.ZERO
		_smoothed_velocity = Vector3.ZERO


func _input(event: InputEvent) -> void:
	if _input_locked or _is_dead or InventoryManager.is_open:
		return

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw -= event.relative.x * mouse_sensitivity
		_pitch -= event.relative.y * mouse_sensitivity
		_pitch = clampf(_pitch, deg_to_rad(-85.0), deg_to_rad(85.0))
		rotation.y = _yaw
		head.rotation.x = _pitch


func _unhandled_input(event: InputEvent) -> void:
	if _input_locked or _is_dead:
		return

	if event.is_action_pressed("inventory"):
		InventoryManager.toggle_inventory()
		get_viewport().set_input_as_handled()
		return

	if InventoryManager.is_open:
		return


func _physics_process(delta: float) -> void:
	if _input_locked or _is_dead or InventoryManager.is_open:
		velocity = Vector3.ZERO
		return

	_is_crouching = Input.is_action_pressed("crouch")

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if not _wake_triggered and input_dir.length() > 0.1:
		_wake_triggered = true
		InnerVoiceManager.trigger("wake_up")

	var direction := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()

	var wants_run := Input.is_action_pressed("sprint") and not _is_crouching and input_dir.length() > 0.1
	var is_running := wants_run and _stamina >= min_stamina_to_run

	if is_running:
		_stamina = maxf(0.0, _stamina - stamina_drain_rate * delta)
	else:
		_stamina = minf(max_stamina, _stamina + stamina_regen_rate * delta)

	stamina_changed.emit(_stamina, max_stamina)
	HudManager.update_stamina(_stamina, max_stamina)

	var target_speed := crouch_speed if _is_crouching else (run_speed if is_running else walk_speed)
	var target_velocity := direction * target_speed
	var blend_rate := acceleration if direction.length() > 0.1 else deceleration
	_smoothed_velocity = _smoothed_velocity.lerp(
		Vector3(target_velocity.x, 0.0, target_velocity.z),
		blend_rate * delta
	)

	velocity.x = _smoothed_velocity.x
	velocity.z = _smoothed_velocity.z

	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0

	move_and_slide()
	_update_crouch(delta)
	_update_head_bob(delta)


func _update_crouch(delta: float) -> void:
	var target_capsule_height := _capsule_stand_height * (crouch_height / stand_height) if _is_crouching else _capsule_stand_height
	var target_head_y := _base_head_y * (crouch_height / stand_height) if _is_crouching else _base_head_y

	if _capsule:
		_capsule.height = lerpf(_capsule.height, target_capsule_height, crouch_lerp_speed * delta)
		collision_shape.position.y = _capsule.height * 0.5

	head.position.y = lerpf(head.position.y, target_head_y, crouch_lerp_speed * delta)


func _update_head_bob(delta: float) -> void:
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	var bob_y := 0.0
	if is_on_floor() and horizontal_speed > 0.2 and not _is_crouching:
		_bob_timer += delta * head_bob_frequency * (horizontal_speed / walk_speed)
		bob_y = sin(_bob_timer * TAU) * head_bob_amplitude
	else:
		_bob_timer = 0.0
		bob_y = lerpf(camera.position.y, 0.0, 10.0 * delta)

	var shake_x := 0.0
	var shake_y := 0.0
	if _shake_strength > 0.002:
		shake_x = randf_range(-1.0, 1.0) * _shake_strength
		shake_y = randf_range(-1.0, 1.0) * _shake_strength * 0.65
		_shake_strength = lerpf(_shake_strength, 0.0, 14.0 * delta)
	else:
		_shake_strength = 0.0
		shake_x = lerpf(camera.position.x, 0.0, 12.0 * delta)

	camera.position.x = shake_x
	camera.position.y = bob_y + shake_y

	_update_footsteps(delta, horizontal_speed)


func _update_footsteps(delta: float, horizontal_speed: float) -> void:
	if not is_on_floor() or horizontal_speed < 0.4:
		_step_distance = 0.0
		return

	_step_distance += horizontal_speed * delta
	var stride := 2.0
	if _is_crouching:
		stride = 2.4
	if _step_distance >= stride:
		_step_distance = 0.0
		var running := horizontal_speed > walk_speed + 0.5
		if _is_crouching:
			AudioManager.footstep(false)
		else:
			AudioManager.footstep(running)


func get_camera() -> Camera3D:
	return camera


func play_camera_shake(strength: float = 0.12, _duration: float = 0.35) -> void:
	_shake_strength = maxf(_shake_strength, strength)


func take_damage(amount: float, _source: Node = null) -> void:
	if _is_dead:
		return

	var was_above_critical := _health > max_health * 0.25
	_health = maxf(0.0, _health - amount)
	health_changed.emit(_health, max_health)
	HudManager.update_health(_health, max_health)
	AudioManager.play("player_hurt", -2.0, 0.95, 1.05)
	# Ekran kirmizi flash — hasar siddetine gore yogunluk
	HudManager.play_damage_feedback(clampf(amount / 34.0, 0.5, 1.5))

	if was_above_critical and _health <= max_health * 0.25 and _health > 0.0:
		InnerVoiceManager.trigger("health_critical")

	_update_heartbeat()

	if _health <= 0.0:
		_die()


func _update_heartbeat() -> void:
	if _health <= max_health * 0.25 and _health > 0.0:
		AudioManager.start_heartbeat()
	else:
		AudioManager.stop_heartbeat()


func _die() -> void:
	_is_dead = true
	velocity = Vector3.ZERO
	AudioManager.stop_heartbeat()
	AudioManager.play("player_hurt", 0.0, 0.7, 0.8)
	HudManager.show_game_over()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func is_dead() -> bool:
	return _is_dead


func get_save_data() -> Dictionary:
	return {
		"position": [global_position.x, global_position.y, global_position.z],
		"rotation_y": rotation.y,
		"pitch": _pitch,
		"health": _health,
		"stamina": _stamina,
		"is_dead": _is_dead,
	}


func apply_save_data(data: Dictionary) -> void:
	if data.is_empty():
		return

	var pos: Array = data.get("position", [])
	if pos.size() >= 3:
		global_position = Vector3(float(pos[0]), float(pos[1]), float(pos[2]))

	_yaw = float(data.get("rotation_y", rotation.y))
	_pitch = float(data.get("pitch", _pitch))
	rotation.y = _yaw
	head.rotation.x = _pitch

	_health = float(data.get("health", _health))
	_stamina = float(data.get("stamina", _stamina))
	_is_dead = bool(data.get("is_dead", false))

	if _is_dead:
		HudManager.show_game_over()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		HudManager.hide_game_over()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	HudManager.update_health(_health, max_health)
	HudManager.update_stamina(_stamina, max_stamina)
	health_changed.emit(_health, max_health)
	stamina_changed.emit(_stamina, max_stamina)


func _on_focus_changed(target: Interactable) -> void:
	if target:
		HudManager.show_prompt(target.get_prompt())
	else:
		HudManager.hide_prompt()


func _on_heal_requested(amount: float) -> void:
	_health = minf(max_health, _health + amount)
	health_changed.emit(_health, max_health)
	HudManager.update_health(_health, max_health)
	_update_heartbeat()
