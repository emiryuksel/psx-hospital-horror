# Oyuncu savaş sistemi — bıçak, tabanca, raycast hasar, şarjör yönetimi.
extends Node

enum WeaponMode { KNIFE, PISTOL }

signal ammo_changed(in_mag: int, reserve: int)
signal weapon_changed(mode: int)
signal fired
signal reloaded

@export_group("Melee")
@export var knife_damage: float = 40.0
@export var knife_range: float = 1.9
@export var knife_cooldown: float = 0.55

@export_group("Pistol")
@export var pistol_damage: float = 28.0
@export var pistol_range: float = 28.0
@export var magazine_size: int = 6
@export var fire_cooldown: float = 0.32
@export var reload_time: float = 1.3
@export var aim_spread: float = 0.01
@export var hip_spread: float = 0.04

@onready var _player: CharacterBody3D = get_parent()
@onready var _camera: Camera3D = $"../Head/Camera3D"

const ZOMBIE_HIT_BLOOD := "res://assets/textures/fx/blood_splat.png"

var current_weapon: WeaponMode = WeaponMode.KNIFE
var ammo_in_mag: int = 6
var ammo_reserve: int = 0
var _attack_timer: float = 0.0
var _reload_timer: float = 0.0
var _is_reloading: bool = false
var _is_aiming: bool = false
var _has_pistol: bool = false
var _has_knife: bool = false


func _ready() -> void:
	ammo_in_mag = magazine_size
	_sync_reserve_from_inventory()
	InventoryManager.inventory_changed.connect(_sync_reserve_from_inventory)
	InventoryManager.item_added.connect(_on_item_added)
	call_deferred("_check_weapon_from_inventory")
	call_deferred("_emit_ammo")


# Silah envanterde varsa (load veya pickup sonrasi) kullanima ac
func _check_weapon_from_inventory() -> void:
	if InventoryManager.has_item("knife"):
		_grant_knife()
	if InventoryManager.has_item("pistol"):
		_grant_pistol()
	if not _has_knife and not _has_pistol:
		HudManager.set_weapon_acquired(false)
		HudManager.hide_weapon_viewmodel()


func _on_item_added(item: Item, _slot_index: int, _count: int) -> void:
	if item == null:
		return
	if item.id == "knife":
		_grant_knife()
	elif item.id == "pistol":
		_grant_pistol()


func _grant_knife() -> void:
	if _has_knife:
		return
	_has_knife = true
	# Henuz pistol yoksa aktif silah bicak olsun
	if not _has_pistol:
		current_weapon = WeaponMode.KNIFE
	HudManager.set_weapon_acquired(true)
	HudManager.update_weapon_label(current_weapon)
	HudManager.show_weapon_viewmodel(current_weapon)
	_emit_ammo()


func _grant_pistol() -> void:
	if _has_pistol:
		return
	_has_pistol = true
	current_weapon = WeaponMode.PISTOL
	HudManager.set_weapon_acquired(true)
	HudManager.update_weapon_label(current_weapon)
	HudManager.show_weapon_viewmodel(current_weapon)
	_emit_ammo()


func _physics_process(delta: float) -> void:
	if InventoryManager.is_open:
		return

	if _player.has_method("is_dead") and _player.is_dead():
		return

	# Hicbir silah yoksa combat input islenmesin (oyuncu silahsiz baslar)
	if not _has_knife and not _has_pistol:
		return

	_attack_timer = maxf(0.0, _attack_timer - delta)

	if _is_reloading:
		_reload_timer -= delta
		HudManager.show_reload_progress(1.0 - (_reload_timer / reload_time))
		if _reload_timer <= 0.0:
			_finish_reload()
		return

	_is_aiming = Input.is_action_pressed("aim") and current_weapon == WeaponMode.PISTOL
	HudManager.set_crosshair_state(current_weapon, _is_aiming, _is_reloading)

	if Input.is_action_just_pressed("reload"):
		_start_reload()

	if Input.is_action_just_pressed("weapon_melee"):
		_switch_weapon(WeaponMode.KNIFE)

	if Input.is_action_just_pressed("weapon_ranged"):
		_switch_weapon(WeaponMode.PISTOL)

	if Input.is_action_pressed("fire"):
		_try_attack()


func _try_attack() -> void:
	if not _has_knife and not _has_pistol:
		return
	if _attack_timer > 0.0 or _is_reloading:
		return

	match current_weapon:
		WeaponMode.KNIFE:
			_melee_attack()
		WeaponMode.PISTOL:
			_pistol_attack()


func _melee_attack() -> void:
	_attack_timer = knife_cooldown
	AudioManager.play("knife_swing", -4.0, 0.95, 1.05)
	HudManager.play_melee_animation()
	var hit := _raycast_attack(knife_range, 0.0)
	if not hit.is_empty():
		AudioManager.play("knife_hit", -2.0, 0.95, 1.05)
		if _apply_damage(hit.collider, knife_damage):
			_spawn_blood_splat(hit.get("position", Vector3.ZERO))


func _pistol_attack() -> void:
	if ammo_in_mag <= 0:
		AudioManager.play("gun_empty", -4.0)
		_start_reload()
		return

	_attack_timer = fire_cooldown
	ammo_in_mag -= 1
	_emit_ammo()
	fired.emit()
	AudioManager.play("gun_fire", -1.0, 0.96, 1.04)
	HudManager.play_fire_animation()

	var spread := aim_spread if _is_aiming else hip_spread
	var hit := _raycast_attack(pistol_range, spread)
	if not hit.is_empty():
		if _apply_damage(hit.collider, pistol_damage):
			_spawn_blood_splat(hit.get("position", Vector3.ZERO))


func _raycast_attack(range_dist: float, spread: float) -> Dictionary:
	var origin := _camera.global_position
	var direction := -_camera.global_transform.basis.z.normalized()

	if spread > 0.0:
		direction = direction.rotated(Vector3.UP, randf_range(-spread, spread))
		direction = direction.rotated(_camera.global_transform.basis.x, randf_range(-spread, spread))
		direction = direction.normalized()

	var space := _player.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * range_dist)
	query.collide_with_areas = true
	query.exclude = [_player.get_rid()]

	return space.intersect_ray(query)


func _apply_damage(collider: Object, damage: float) -> bool:
	var node: Node = collider as Node
	while node:
		var health: HealthComponent = node.get_node_or_null("HealthComponent") as HealthComponent
		if health:
			health.take_damage(damage, _player)
			return true
		if node is HealthComponent:
			(node as HealthComponent).take_damage(damage, _player)
			return true
		node = node.get_parent()
	return false


# Isabet noktasinda kisa omurlu PSX kan-sicrama billboard'u — alpha scissor, nearest, fade-out.
func _spawn_blood_splat(world_pos: Vector3) -> void:
	if world_pos == Vector3.ZERO:
		return
	var root := _player.get_tree().current_scene
	if root == null:
		return

	var mi := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.55, 0.55)
	mi.mesh = quad
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var mat: StandardMaterial3D
	if ResourceLoader.exists(ZOMBIE_HIT_BLOOD):
		mat = PsxMaterialHelper.create_transparent_textured_material(ZOMBIE_HIT_BLOOD, Color(0.6, 0.05, 0.05), Vector3.ONE)
	else:
		# Fallback — kirmizi unshaded quad
		mat = PsxMaterialHelper.create_unshaded_material(Color(0.55, 0.06, 0.05, 1.0))
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.billboard_keep_scale = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = mat

	root.add_child(mi)
	mi.global_position = world_pos
	mi.scale = Vector3.ONE * randf_range(0.8, 1.3)

	# Kisa fade-out sonra queue_free
	var tween := mi.create_tween()
	tween.tween_interval(0.12)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.35)
	tween.tween_callback(mi.queue_free)


func _start_reload() -> void:
	if _is_reloading or current_weapon != WeaponMode.PISTOL:
		return
	if ammo_in_mag >= magazine_size:
		return
	if ammo_reserve <= 0:
		return

	_is_reloading = true
	_reload_timer = reload_time
	AudioManager.play("reload", -3.0)
	HudManager.show_reload_progress(0.0)


func _finish_reload() -> void:
	_is_reloading = false
	HudManager.hide_reload_progress()

	var needed := magazine_size - ammo_in_mag
	var loaded := mini(needed, ammo_reserve)
	ammo_in_mag += loaded
	ammo_reserve -= loaded
	_consume_reserve_from_inventory(loaded)
	_emit_ammo()
	reloaded.emit()


func _sync_reserve_from_inventory() -> void:
	ammo_reserve = 0
	for i in InventoryManager.MAX_SLOTS:
		var entry: Dictionary = InventoryManager.get_slot(i)
		if entry.is_empty():
			continue
		var item: Item = entry["item"]
		var count: int = entry["count"]
		if item.id == "pistol_ammo":
			ammo_reserve += count
		elif item.id == "loaded_mag":
			ammo_reserve += count * magazine_size
	_emit_ammo()


func _consume_reserve_from_inventory(rounds: int) -> void:
	var remaining := rounds
	for i in InventoryManager.MAX_SLOTS:
		if remaining <= 0:
			break
		var entry: Dictionary = InventoryManager.get_slot(i)
		if entry.is_empty():
			continue
		var item: Item = entry["item"]
		if item.id == "pistol_ammo":
			var take := mini(remaining, entry["count"])
			InventoryManager.remove_from_slot(i, take)
			remaining -= take
		elif item.id == "loaded_mag":
			InventoryManager.remove_from_slot(i, 1)
			remaining -= magazine_size


func _switch_weapon(mode: WeaponMode) -> void:
	if current_weapon == mode:
		return
	# Sadece sahip olunan silaha gec
	if mode == WeaponMode.KNIFE and not _has_knife:
		return
	if mode == WeaponMode.PISTOL and not _has_pistol:
		return
	current_weapon = mode
	weapon_changed.emit(mode)
	HudManager.update_weapon_label(mode)
	HudManager.show_weapon_viewmodel(mode)


func _emit_ammo() -> void:
	ammo_changed.emit(ammo_in_mag, ammo_reserve)
	HudManager.update_ammo(ammo_in_mag, ammo_reserve, current_weapon)


func get_save_data() -> Dictionary:
	return {
		"weapon": current_weapon,
		"ammo_in_mag": ammo_in_mag,
		"ammo_reserve": ammo_reserve,
		"has_pistol": _has_pistol,
		"has_knife": _has_knife,
	}


func apply_save_data(data: Dictionary) -> void:
	if data.is_empty():
		return

	current_weapon = int(data.get("weapon", current_weapon)) as WeaponMode
	ammo_in_mag = int(data.get("ammo_in_mag", ammo_in_mag))
	ammo_reserve = int(data.get("ammo_reserve", ammo_reserve))
	_has_pistol = bool(data.get("has_pistol", false))
	_has_knife = bool(data.get("has_knife", false))
	_is_reloading = false
	_reload_timer = 0.0
	HudManager.hide_reload_progress()
	HudManager.update_weapon_label(current_weapon)
	if _has_pistol or _has_knife:
		HudManager.set_weapon_acquired(true)
		HudManager.show_weapon_viewmodel(current_weapon)
	else:
		HudManager.set_weapon_acquired(false)
		HudManager.hide_weapon_viewmodel()
	_emit_ammo()
