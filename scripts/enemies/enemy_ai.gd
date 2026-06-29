# Düşman AI — Idle / Patrol / Alert / Chase / Attack state machine.
class_name EnemyAI
extends CharacterBody3D

enum State { IDLE, PATROL, ALERT, CHASE, ATTACK }

@export_group("Movement")
@export var patrol_speed: float = 1.4
@export var chase_speed: float = 3.2
@export var alert_speed: float = 2.0
@export var rotation_speed: float = 5.0
@export var gravity: float = 9.8
@export var waypoint_arrive_distance: float = 0.45

@export_group("Detection")
@export var detection_range: float = 7.0
@export var fov_degrees: float = 110.0
@export var lose_sight_time: float = 3.5
@export var eye_height: float = 1.45

@export_group("Combat")
@export var attack_range: float = 1.65
@export var attack_damage: float = 34.0
@export var attack_windup: float = 0.55
@export var attack_cooldown: float = 1.4
@export var use_contact_damage: bool = true
@export var contact_range: float = 1.1
@export var contact_damage_cooldown: float = 0.7

@export_group("Behavior")
@export var idle_duration: float = 2.0
@export var start_state: State = State.PATROL

@onready var _health: HealthComponent = $HealthComponent
@onready var _mesh: MeshInstance3D = $MeshPivot/MeshInstance3D
@onready var _mesh_pivot: Node3D = $MeshPivot
@onready var _patrol_root: Node3D = $PatrolPoints

const ZOMBIE_TEXTURE := "res://assets/textures/enemies/zombie.png"

var _state: State = State.IDLE
var _player: CharacterBody3D = null
var _base_color: Color = Color(1.0, 1.0, 1.0)

var _patrol_points: Array[Vector3] = []
var _patrol_index: int = 0
var _last_known_position: Vector3 = Vector3.ZERO

var _state_timer: float = 0.0
var _lose_sight_timer: float = 0.0
var _attack_timer: float = 0.0
var _can_attack: bool = true
var _fov_cos: float = 0.0
var _is_winding_up: bool = false
var _growl_timer: float = 0.0
var _contact_damage_timer: float = 0.0


func _ready() -> void:
	add_to_group("save_enemy")
	_fov_cos = cos(deg_to_rad(fov_degrees * 0.5))
	_mesh.material_override = _build_sprite_material()
	_health.died.connect(_on_died)
	_health.damaged.connect(_on_damaged)
	_cache_patrol_points()
	_state = start_state
	_state_timer = idle_duration
	call_deferred("_find_player")


func _find_player() -> void:
	_player = get_tree().get_first_node_in_group("player") as CharacterBody3D


# Zombi sprite — kameraya dönük billboard quad, alpha kesimli, flashlight ile aydınlanır.
func _build_sprite_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	mat.billboard_keep_scale = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat.roughness = 1.0
	mat.metallic = 0.0
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	mat.albedo_color = _base_color

	var tex: Texture2D = null
	if ResourceLoader.exists(ZOMBIE_TEXTURE):
		tex = load(ZOMBIE_TEXTURE) as Texture2D
	if tex != null:
		mat.albedo_texture = tex
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		mat.alpha_scissor_threshold = 0.5
	else:
		mat.albedo_color = Color(0.45, 0.52, 0.45)
	return mat


func _cache_patrol_points() -> void:
	_patrol_points.clear()
	if _patrol_root == null:
		return
	for child in _patrol_root.get_children():
		if child is Node3D:
			_patrol_points.append(child.global_position)
	if _patrol_points.is_empty():
		_patrol_points.append(global_position)


func set_patrol_points_local(points: Array[Vector3]) -> void:
	if _patrol_root == null:
		return
	for child in _patrol_root.get_children():
		child.queue_free()
	for i in points.size():
		var marker := Marker3D.new()
		marker.name = "Point%d" % i
		marker.position = points[i]
		_patrol_root.add_child(marker)
	_cache_patrol_points()


func _physics_process(delta: float) -> void:
	if _health.is_dead():
		return

	if _player == null or not is_instance_valid(_player):
		_find_player()

	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0

	match _state:
		State.IDLE:
			_process_idle(delta)
		State.PATROL:
			_process_patrol(delta)
		State.ALERT:
			_process_alert(delta)
		State.CHASE:
			_process_chase(delta)
		State.ATTACK:
			_process_attack(delta)

	_update_growl(delta)
	if use_contact_damage:
		_contact_damage_timer = maxf(0.0, _contact_damage_timer - delta)
		_try_contact_damage()
	move_and_slide()


func _update_growl(delta: float) -> void:
	_growl_timer -= delta
	if _growl_timer > 0.0:
		return
	if _state == State.CHASE or _state == State.ATTACK:
		_growl_timer = randf_range(1.6, 3.2)
		AudioManager.play_3d("enemy_growl", global_position, -3.0, 0.9, 1.1)
	elif _state == State.ALERT:
		_growl_timer = randf_range(3.0, 5.0)
		AudioManager.play_3d("enemy_growl", global_position, -8.0, 0.8, 0.95)
	else:
		_growl_timer = randf_range(4.0, 7.0)


func _process_idle(delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	_state_timer -= delta

	if _can_see_player():
		_begin_chase()
		return

	if _state_timer <= 0.0 and not _patrol_points.is_empty():
		_set_state(State.PATROL)


func _process_patrol(delta: float) -> void:
	if _can_see_player():
		_begin_chase()
		return

	if _patrol_points.is_empty():
		_set_state(State.IDLE)
		return

	var target := _patrol_points[_patrol_index]
	_move_toward(target, patrol_speed, delta)

	if global_position.distance_to(target) <= waypoint_arrive_distance:
		_patrol_index = (_patrol_index + 1) % _patrol_points.size()
		_set_state(State.IDLE)


func _process_alert(delta: float) -> void:
	if _can_see_player():
		_begin_chase()
		return

	_move_toward(_last_known_position, alert_speed, delta)

	if global_position.distance_to(_last_known_position) <= waypoint_arrive_distance:
		_set_state(State.PATROL)


func _process_chase(delta: float) -> void:
	if _player == null or _is_player_dead():
		_set_state(State.PATROL)
		return

	if _can_see_player():
		_last_known_position = _get_player_target_position()
		_lose_sight_timer = lose_sight_time
	elif _lose_sight_timer > 0.0:
		_lose_sight_timer -= delta
	else:
		_set_state(State.ALERT)
		return

	var dist := global_position.distance_to(_get_player_target_position())
	if not use_contact_damage and dist <= attack_range:
		_set_state(State.ATTACK)
		return

	_move_toward(_get_player_target_position(), chase_speed, delta)


func _process_attack(delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0

	if _player == null or _is_player_dead():
		_set_state(State.PATROL)
		return

	_face_position(_get_player_target_position(), delta)

	var dist := global_position.distance_to(_get_player_target_position())
	if dist > attack_range * 1.25 and not _is_winding_up:
		_set_state(State.CHASE)
		return

	if _is_winding_up:
		_state_timer -= delta
		if _state_timer <= 0.0:
			_finish_attack()
		return

	if not _can_attack:
		_attack_timer -= delta
		if _attack_timer <= 0.0:
			_can_attack = true
		return

	_start_attack()


func _start_attack() -> void:
	_is_winding_up = true
	_can_attack = false
	_attack_timer = attack_cooldown
	_state_timer = attack_windup
	AudioManager.play_3d("enemy_attack", global_position, -1.0, 0.95, 1.05)
	if _mesh.material_override != null:
		PsxMaterialHelper.set_albedo(_mesh.material_override, Color(0.9, 0.25, 0.2))


func _finish_attack() -> void:
	_is_winding_up = false
	if _mesh.material_override != null:
		PsxMaterialHelper.set_albedo(_mesh.material_override, _base_color)

	if _state != State.ATTACK:
		return

	if global_position.distance_to(_get_player_target_position()) <= attack_range * 1.15:
		_deal_attack_damage()

	if _can_see_player():
		_set_state(State.CHASE)
	else:
		_set_state(State.ALERT)


func _deal_attack_damage() -> void:
	if _player == null or not _player.has_method("take_damage"):
		return
	if _player.has_method("is_dead") and _player.is_dead():
		return
	_player.take_damage(attack_damage, self)


func _try_contact_damage() -> void:
	if _contact_damage_timer > 0.0:
		return
	if _player == null or _is_player_dead():
		return
	if _state not in [State.CHASE, State.ATTACK, State.ALERT]:
		return
	if _get_horizontal_distance_to_player() > contact_range:
		return

	_contact_damage_timer = contact_damage_cooldown
	AudioManager.play_3d("enemy_attack", global_position, -1.0, 0.95, 1.05)
	if _mesh.material_override != null:
		PsxMaterialHelper.set_albedo(_mesh.material_override, Color(0.9, 0.25, 0.2))
		get_tree().create_timer(0.1).timeout.connect(func() -> void:
			if is_instance_valid(self) and _mesh.material_override != null:
				PsxMaterialHelper.set_albedo(_mesh.material_override, _base_color)
		)
	_deal_attack_damage()


func _get_horizontal_distance_to_player() -> float:
	if _player == null:
		return INF
	var enemy_pos := Vector2(global_position.x, global_position.z)
	var player_pos := Vector2(_player.global_position.x, _player.global_position.z)
	return enemy_pos.distance_to(player_pos)


func _begin_chase() -> void:
	_last_known_position = _get_player_target_position()
	_lose_sight_timer = lose_sight_time
	_set_state(State.CHASE)


func _set_state(new_state: State) -> void:
	var previous := _state
	_state = new_state
	if (new_state == State.ALERT or new_state == State.CHASE) and previous in [State.IDLE, State.PATROL]:
		InnerVoiceManager.trigger("first_enemy")
		AudioManager.play_3d("enemy_alert", global_position, -1.0, 0.97, 1.03)
	match _state:
		State.IDLE:
			_state_timer = idle_duration
			velocity.x = 0.0
			velocity.z = 0.0
		State.PATROL:
			pass
		State.ALERT:
			pass
		State.CHASE:
			_lose_sight_timer = lose_sight_time
		State.ATTACK:
			velocity.x = 0.0
			velocity.z = 0.0
			_is_winding_up = false


func _move_toward(target: Vector3, speed: float, delta: float) -> void:
	var flat_target := Vector3(target.x, global_position.y, target.z)
	var offset := flat_target - global_position
	var distance := offset.length()
	if distance < 0.05:
		velocity.x = 0.0
		velocity.z = 0.0
		return

	var direction := offset / distance
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	_face_direction(direction, delta)


func _face_position(target: Vector3, delta: float) -> void:
	var offset := Vector3(target.x - global_position.x, 0.0, target.z - global_position.z)
	if offset.length_squared() < 0.001:
		return
	_face_direction(offset.normalized(), delta)


func _face_direction(direction: Vector3, delta: float) -> void:
	var target_yaw := atan2(direction.x, direction.z)
	_mesh_pivot.rotation.y = lerp_angle(_mesh_pivot.rotation.y, target_yaw, rotation_speed * delta)


func _can_see_player() -> bool:
	if _player == null or _is_player_dead():
		return false

	var target := _get_player_target_position()
	var offset := target - _get_eye_position()
	var distance := offset.length()
	if distance > detection_range:
		return false

	var forward := -_mesh_pivot.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var to_player := offset.normalized()
	if forward.dot(to_player) < _fov_cos:
		return false

	return _has_line_of_sight(target)


func _has_line_of_sight(target: Vector3) -> bool:
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(_get_eye_position(), target)
	query.exclude = [get_rid()]
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return true
	return _is_player_node(hit.collider as Node)


func _is_player_node(node: Node) -> bool:
	var current := node
	while current:
		if current == _player:
			return true
		if current.is_in_group("player"):
			return true
		current = current.get_parent()
	return false


func _is_player_dead() -> bool:
	return _player.has_method("is_dead") and _player.is_dead()


func _get_eye_position() -> Vector3:
	return global_position + Vector3(0.0, eye_height, 0.0)


func _get_player_target_position() -> Vector3:
	if _player == null:
		return global_position
	return _player.global_position + Vector3(0.0, 1.2, 0.0)


func _on_damaged(_amount: float, _source: Node) -> void:
	AudioManager.play_3d("enemy_hurt", global_position, -2.0, 0.95, 1.08)
	if _state != State.ATTACK and _player != null and not _is_player_dead():
		_begin_chase()

	if _mesh.material_override != null:
		PsxMaterialHelper.set_albedo(_mesh.material_override, Color(1.0, 0.35, 0.35))
	await get_tree().create_timer(0.08).timeout
	if is_instance_valid(self) and _mesh.material_override != null:
		PsxMaterialHelper.set_albedo(_mesh.material_override, _base_color)


func _on_died() -> void:
	velocity = Vector3.ZERO
	set_physics_process(false)
	AudioManager.play_3d("enemy_death", global_position, 0.0, 0.92, 1.0)
	queue_free()


func get_save_id() -> String:
	return name


func get_save_data() -> Dictionary:
	return {
		"save_id": get_save_id(),
		"alive": not _health.is_dead(),
		"position": [global_position.x, global_position.y, global_position.z],
		"rotation_y": _mesh_pivot.rotation.y,
		"health": _health.health,
		"state": _state,
	}


func apply_save_data(data: Dictionary) -> void:
	if not bool(data.get("alive", true)):
		queue_free()
		return

	var pos: Array = data.get("position", [])
	if pos.size() >= 3:
		global_position = Vector3(float(pos[0]), float(pos[1]), float(pos[2]))

	_mesh_pivot.rotation.y = float(data.get("rotation_y", _mesh_pivot.rotation.y))
	_health.set_health(float(data.get("health", _health.health)))
	_state = int(data.get("state", _state)) as State
