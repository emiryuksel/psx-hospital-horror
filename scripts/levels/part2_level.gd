# Part II — The Basement (Morgue + Pump/Boiler + Generator)
# Akış: asansörden in -> anahtar bul (Cold Storage) -> valfi aç (Pump Room)
#       -> jeneratörü çalıştır (Generator Room) -> asansöre dön (yukarı çık).
extends Node3D

const GENERATED_GROUP := "generated_part2"

# --- Renk paleti (Part 1'den koyu/soğuk türev) ---
const FLOOR_COLOR := Color(0.18, 0.19, 0.20)
const WALL_COLOR := Color(0.30, 0.31, 0.32)
const CEILING_COLOR := Color(0.14, 0.15, 0.16)
const TRIM_COLOR := Color(0.24, 0.25, 0.26)
const MORGUE_COLOR := Color(0.55, 0.58, 0.60)
const PIPE_COLOR := Color(0.26, 0.24, 0.22)
const ELEVATOR_COLOR := Color(0.22, 0.24, 0.27)
const WATER_COLOR := Color(0.10, 0.14, 0.16, 0.6)
const MIST_COLOR := Color(0.11, 0.13, 0.17, 0.85)
const BLOOD_COLOR := Color(0.40, 0.10, 0.09)

const WALL_THICK := 0.35
const ROOM_H := 3.0

# --- Oda boyutları ---
const CABIN_SIZE := Vector3(3.0, 3.0, 3.0)
const LANDING_SIZE := Vector3(7.0, 3.0, 6.0)
const HALL_WIDTH := 3.2
const MORGUE_HALL_LEN := 18.0
const COLD_STORAGE_SIZE := Vector3(7.0, 3.0, 6.0)
const PUMP_ROOM_SIZE := Vector3(8.0, 3.0, 7.0)
const JUNCTION_SIZE := Vector3(8.0, 3.0, 6.0)
const GENERATOR_ROOM_SIZE := Vector3(9.0, 3.2, 7.0)

# --- Z-fighting önleme (Part 1 ile aynı) ---
const SURFACE_JOIN_EPS := 0.01
const SURFACE_JOIN_LAYER_EPS := 0.024
const PROP_SURFACE_EPS := 0.01
const FLOOR_TOP := 0.0

# --- Anahtar konum referansları (runtime'da _ready'de hesaplanır) ---
var _cabin_center: Vector3 = Vector3.ZERO
var _landing_center: Vector3 = Vector3.ZERO
var _morgue_hall_center: Vector3 = Vector3.ZERO
var _cold_storage_center: Vector3 = Vector3.ZERO
var _pump_room_center: Vector3 = Vector3.ZERO
var _junction_center: Vector3 = Vector3.ZERO
var _generator_room_center: Vector3 = Vector3.ZERO

var _power_lights: Array[Light3D] = []

# --- Yaratık spawn takibi ---
var _morgue_creature_spawned: bool = false
var _stalker_spawned: bool = false
var _junction_ambush_spawned: bool = false
var _return_patrol_spawned: bool = false


func _ready() -> void:
	_compute_layout()

	if not Engine.is_editor_hint():
		_apply_fog_settings()
		PsxSettings.settings_changed.connect(_apply_fog_settings)
		QuestManager.basement_power_restored.connect(_on_basement_power_restored)
		QuestManager.junction_ambush_requested.connect(_on_junction_ambush_requested)
		InventoryManager.item_added.connect(_on_item_picked_up)

	_rebuild_geometry()

	if not Engine.is_editor_hint():
		if SaveManager.has_pending_load():
			call_deferred("_try_apply_save")
		else:
			_apply_lighting_for_power_state()
			_morgue_creature_spawned = QuestManager.morgue_creature_done
			_stalker_spawned = QuestManager.cold_storage_stalker_done
			_junction_ambush_spawned = QuestManager.junction_ambush_done
		QuestManager.refresh_objective()
		_start_ambient()
		InnerVoiceManager.trigger("basement_arrive")


func _try_apply_save() -> void:
	if not SaveManager.has_pending_load():
		return
	for _attempt in 4:
		await get_tree().process_frame
		if SaveManager.try_apply_to_current_scene():
			break
	if not SaveManager.has_pending_load():
		_morgue_creature_spawned = QuestManager.morgue_creature_done
		_stalker_spawned = QuestManager.cold_storage_stalker_done
		_junction_ambush_spawned = QuestManager.junction_ambush_done
		_apply_lighting_for_power_state()


func _start_ambient() -> void:
	AudioManager.start_ambient("ambient_drone", -14.0)


func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var key: Key = event.keycode
	if key == KEY_NONE:
		key = event.physical_keycode
	if key == KEY_F5 or key == KEY_F6:
		_mark_input_handled()
		SaveManager.save_game()
	elif key == KEY_F9:
		_mark_input_handled()
		SaveManager.load_game()


func _mark_input_handled() -> void:
	var vp := get_viewport()
	if vp:
		vp.set_input_as_handled()


func _apply_fog_settings() -> void:
	var world_env: WorldEnvironment = get_node_or_null("WorldEnvironment")
	if world_env and world_env.environment:
		world_env.environment.fog_enabled = PsxSettings.fog_enabled
		# Bodrum daha yoğun sisli
		world_env.environment.fog_density = PsxSettings.fog_density * 1.6
		world_env.environment.fog_light_color = PsxSettings.fog_color


func _compute_layout() -> void:
	# Güney ucu: asansör kabini. Kuzeye doğru landing, sonra kollar.
	# Kabin, landing'in güney kenarına BİTİŞİK olmalı (arada boşluk kalmasın).
	_landing_center = Vector3(0.0, 0.0, 4.0)
	var landing_south_edge := _landing_center.z + LANDING_SIZE.z * 0.5
	_cabin_center = Vector3(0.0, 0.0, landing_south_edge + CABIN_SIZE.z * 0.5)
	# Doğu kol (morgue) — landing'in doğusundan uzanır
	_morgue_hall_center = Vector3(
		LANDING_SIZE.x * 0.5 + WALL_THICK + MORGUE_HALL_LEN * 0.5,
		0.0,
		_landing_center.z
	)
	_cold_storage_center = Vector3(
		_morgue_hall_center.x + MORGUE_HALL_LEN * 0.5 + WALL_THICK + COLD_STORAGE_SIZE.x * 0.5,
		0.0,
		_landing_center.z
	)
	# Batı kol (pump room) — landing'in batısından
	_pump_room_center = Vector3(
		-(LANDING_SIZE.x * 0.5 + WALL_THICK + 6.0 + PUMP_ROOM_SIZE.x * 0.5),
		0.0,
		_landing_center.z
	)
	# Kuzey birleşim (junction) — landing'in kuzeyinde
	_junction_center = Vector3(0.0, 0.0, _landing_center.z - LANDING_SIZE.z * 0.5 - WALL_THICK - 5.0 - JUNCTION_SIZE.z * 0.5)
	# Generator room — junction'ın kuzeyinde
	_generator_room_center = Vector3(0.0, 0.0, _junction_center.z - JUNCTION_SIZE.z * 0.5 - WALL_THICK - GENERATOR_ROOM_SIZE.z * 0.5)


# --- Güç / aydınlatma ---
func _apply_lighting_for_power_state() -> void:
	if QuestManager.basement_power_on:
		_on_basement_power_restored()
	else:
		_apply_low_power_lighting()


func _apply_low_power_lighting() -> void:
	for light in _power_lights:
		if is_instance_valid(light):
			light.visible = false


func _on_basement_power_restored() -> void:
	for light in _power_lights:
		if is_instance_valid(light):
			light.visible = true
			light.light_energy = light.get_meta("power_energy", light.light_energy)
	_spawn_return_patrol()


func _on_junction_ambush_requested() -> void:
	call_deferred("spawn_junction_ambush")


# --- Geometri inşa orchestrator ---
func _rebuild_geometry() -> void:
	_clear_generated()
	_build_safety_floor()
	_build_underlay_floor()
	_build_elevator_cabin()
	_build_landing()
	_build_morgue_hall()
	_build_cold_storage()
	_build_pump_room()
	_build_junction()
	_build_generator_room()
	_build_lights()
	_build_interactables()
	_build_pickups()
	_build_triggers()
	PsxMaterialHelper.fix_culling_tree(self)


# Tüm bölümün altına yayılan TEK görünmez collision tabanı. Odalar/koridorlar
# uç uca döşendiğinden dikiş yerlerinde mikro boşluklar oluşabiliyor; bu taban
# oyuncunun herhangi bir birleşim yerinde düşmesini engeller. Mesh'i olmadığı
# için hiçbir yüzey çakışması / z-fighting yaratmaz.
func _build_safety_floor() -> void:
	var min_x := _pump_room_center.x - PUMP_ROOM_SIZE.x * 0.5 - WALL_THICK
	var max_x := _cold_storage_center.x + COLD_STORAGE_SIZE.x * 0.5 + WALL_THICK
	var min_z := _generator_room_center.z - GENERATOR_ROOM_SIZE.z * 0.5 - WALL_THICK
	var max_z := _cabin_center.z + CABIN_SIZE.z * 0.5 + WALL_THICK
	# Kenarlara güvenlik payı ekle — bounding box tüm oda/koridorları kapsasın.
	var margin := 1.0
	min_x -= margin
	max_x += margin
	min_z -= margin
	max_z += margin
	var size_x := max_x - min_x
	var size_z := max_z - min_z
	var center_x := (min_x + max_x) * 0.5
	var center_z := (min_z + max_z) * 0.5
	# Üst yüzü, görünen zeminlerin üst yüzüyle TAM aynı hizada olsun (y = -SURFACE_JOIN_EPS).
	# Böylece dikiş boşluğuna denk gelen oyuncu 1-2 cm bile düşmez; kesintisiz yürür.
	# Mesh'i olmadığı için z-fighting imkânsız. Kalınlığı bol tutup derine indiriyoruz.
	var thickness := 2.0
	var top_y := -SURFACE_JOIN_EPS
	var center_y := top_y - thickness * 0.5
	_add_floor_bridge("SafetyFloor", Vector3(center_x, center_y, center_z), Vector3(size_x, thickness, size_z))


# Tüm bölümün altına yayılan GÖRÜNÜR taban kaplaması. Odalar/koridorlar uç uca
# döşendiğinden dikiş yerlerinde ince görsel boşluklar (siyah delikler) oluşabiliyor;
# bu alt zemin, görünen zeminlerin biraz altında durur ve boşluklardan siyahlık
# yerine zemin dokusu görünmesini sağlar. Görünen zeminlerin altında kaldığı için
# normal alanlarda z-fighting yaratmaz.
func _build_underlay_floor() -> void:
	var min_x := _pump_room_center.x - PUMP_ROOM_SIZE.x * 0.5 - WALL_THICK
	var max_x := _cold_storage_center.x + COLD_STORAGE_SIZE.x * 0.5 + WALL_THICK
	var min_z := _generator_room_center.z - GENERATOR_ROOM_SIZE.z * 0.5 - WALL_THICK
	var max_z := _cabin_center.z + CABIN_SIZE.z * 0.5 + WALL_THICK
	var margin := 1.0
	min_x -= margin
	max_x += margin
	min_z -= margin
	max_z += margin
	var size_x := max_x - min_x
	var size_z := max_z - min_z
	var center_x := (min_x + max_x) * 0.5
	var center_z := (min_z + max_z) * 0.5
	# İnce görünür plaka; üst yüzü görünen zeminlerin hemen altında (birkaç cm)
	# kalsın ki dikiş boşluklarını doldursun ama düz zeminlerde çakışmasın.
	var thickness := 0.2
	var top_y := -0.04
	var center_y := top_y - thickness * 0.5
	var mi := MeshInstance3D.new()
	mi.name = "UnderlayFloor"
	mi.position = Vector3(center_x, center_y, center_z)
	mi.add_to_group(GENERATED_GROUP)
	var box := BoxMesh.new()
	box.size = Vector3(size_x, thickness, size_z)
	mi.mesh = box
	mi.material_override = PsxSurfaceTextures.make_prop_surface_material(
		PsxSurfaceTextures.Surface.FLOOR, box.size, FLOOR_COLOR * 0.8
	)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _clear_generated() -> void:
	for child in get_children():
		if child.is_in_group(GENERATED_GROUP):
			child.queue_free()
	_power_lights.clear()


# ============================================================
#  ORTAK GEOMETRİ YARDIMCILARI (Part 1 deseninin aynısı)
# ============================================================

func _add_solid_box(node_name: String, pos: Vector3, box_size: Vector3, color: Color, surface: int = -1) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = pos
	body.add_to_group(GENERATED_GROUP)

	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = box_size
	mesh_instance.mesh = box

	if surface >= 0:
		mesh_instance.material_override = PsxSurfaceTextures.make_prop_surface_material(
			surface as PsxSurfaceTextures.Surface, box_size, color
		)
	else:
		mesh_instance.material_override = PsxMaterialHelper.create_material(color)

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = box_size
	collision.shape = shape

	body.add_child(mesh_instance)
	body.add_child(collision)
	add_child(body)


func _add_floor_box(node_name: String, pos: Vector3, box_size: Vector3, color: Color, join_layer: bool = false) -> void:
	var y_eps := SURFACE_JOIN_LAYER_EPS if join_layer else SURFACE_JOIN_EPS
	_add_solid_box(node_name, Vector3(pos.x, pos.y - y_eps, pos.z), box_size, color, PsxSurfaceTextures.Surface.FLOOR)


# Görünmez collision-only zemin köprüsü (mesh yok -> z-fighting imkânsız).
func _add_floor_bridge(node_name: String, pos: Vector3, box_size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = pos
	body.add_to_group(GENERATED_GROUP)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = box_size
	collision.shape = shape
	body.add_child(collision)
	add_child(body)


func _add_wall_box(node_name: String, pos: Vector3, box_size: Vector3, color: Color) -> void:
	_add_solid_box(node_name, pos, box_size, color, PsxSurfaceTextures.Surface.WALL)


func _add_ceil_box(node_name: String, pos: Vector3, box_size: Vector3, color: Color, join_layer: bool = false) -> void:
	var y_eps := SURFACE_JOIN_LAYER_EPS if join_layer else SURFACE_JOIN_EPS
	_add_solid_box(node_name, Vector3(pos.x, pos.y + y_eps, pos.z), box_size, color, PsxSurfaceTextures.Surface.CEILING)


func _material_for_box(box_size: Vector3, color: Color, surface: int, double_sided: bool = false) -> Material:
	if surface >= 0:
		return PsxSurfaceTextures.make_prop_surface_material(surface as PsxSurfaceTextures.Surface, box_size, color)
	return PsxMaterialHelper.create_material(color, double_sided)


func _y_on_surface(surface_top: float, prop_height: float) -> float:
	return surface_top + prop_height * 0.5 + PROP_SURFACE_EPS


# Dört duvarlı bir oda kabuğu (zemin+tavan+4 duvar) — kapı boşlukları ayrıca açılır.
func _add_room_shell(base_name: String, center: Vector3, box_size: Vector3, floor_color: Color, wall_color: Color) -> void:
	var wt := WALL_THICK
	var h := box_size.y
	var half := box_size * 0.5
	_add_floor_box(base_name + "Floor", Vector3(center.x, -wt * 0.5, center.z), Vector3(box_size.x, wt, box_size.z), floor_color)
	_add_ceil_box(base_name + "Ceil", Vector3(center.x, h, center.z), Vector3(box_size.x, wt, box_size.z), CEILING_COLOR)
	_add_wall_box(base_name + "WallN", Vector3(center.x, h * 0.5, center.z - half.z), Vector3(box_size.x, h, wt), wall_color)
	_add_wall_box(base_name + "WallS", Vector3(center.x, h * 0.5, center.z + half.z), Vector3(box_size.x, h, wt), wall_color)
	_add_wall_box(base_name + "WallE", Vector3(center.x + half.x, h * 0.5, center.z), Vector3(wt, h, box_size.z), wall_color)
	_add_wall_box(base_name + "WallW", Vector3(center.x - half.x, h * 0.5, center.z), Vector3(wt, h, box_size.z), wall_color)


# Zemin su birikintisi — yarı saydam yatay plane (mist material benzeri).
func _add_water_plane(node_name: String, pos: Vector3, plane_size: Vector2) -> void:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.position = Vector3(pos.x, 0.03, pos.z)
	mi.add_to_group(GENERATED_GROUP)
	var plane := PlaneMesh.new()
	plane.size = plane_size
	mi.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = WATER_COLOR
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


# Kan decal — zeminin hemen üstünde yatay plane (Part 1 ile aynı).
func _add_blood_decal(node_name: String, pos: Vector3, plane_size: Vector2) -> void:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.position = Vector3(pos.x, 0.02, pos.z)
	mi.add_to_group(GENERATED_GROUP)
	var plane := PlaneMesh.new()
	plane.size = plane_size
	mi.mesh = plane
	mi.material_override = PsxMaterialHelper.create_transparent_textured_material(
		PsxSurfaceTextures.BLOOD_PATH, BLOOD_COLOR, Vector3.ONE
	)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


# Tavana yatay boru dizisi — atmosfer (basınç boruları).
func _add_pipe(node_name: String, pos: Vector3, box_size: Vector3) -> void:
	_add_solid_box(node_name, pos, box_size, PIPE_COLOR, PsxSurfaceTextures.Surface.METAL)


# ============================================================
#  ODA İNŞASI
# ============================================================

# Kapı boşluklu düz duvar (X boyunca uzanan, ortada boşluk).
func _add_wall_x_with_opening(node_name: String, z: float, x_center: float, total_len: float, h: float, opening_x: float, opening_w: float, color: Color) -> void:
	var half := total_len * 0.5
	var left_end := opening_x - opening_w * 0.5
	var right_start := opening_x + opening_w * 0.5
	var west_edge := x_center - half
	var east_edge := x_center + half
	var left_seg := left_end - west_edge
	var right_seg := east_edge - right_start
	if left_seg > 0.05:
		_add_wall_box(node_name + "_L", Vector3(west_edge + left_seg * 0.5, h * 0.5, z), Vector3(left_seg, h, WALL_THICK), color)
	if right_seg > 0.05:
		_add_wall_box(node_name + "_R", Vector3(right_start + right_seg * 0.5, h * 0.5, z), Vector3(right_seg, h, WALL_THICK), color)
	_add_wall_box(node_name + "_H", Vector3(opening_x, h - 0.35, z), Vector3(opening_w, 0.7, WALL_THICK), color)


# Kapı boşluklu düz duvar (Z boyunca uzanan, ortada boşluk).
func _add_wall_z_with_opening(node_name: String, x: float, z_center: float, total_len: float, h: float, opening_z: float, opening_w: float, color: Color) -> void:
	var half := total_len * 0.5
	var south_edge := z_center + half
	var north_edge := z_center - half
	var south_start := opening_z + opening_w * 0.5
	var north_start := opening_z - opening_w * 0.5
	var south_seg := south_edge - south_start
	var north_seg := north_start - north_edge
	if south_seg > 0.05:
		_add_wall_box(node_name + "_S", Vector3(x, h * 0.5, south_start + south_seg * 0.5), Vector3(WALL_THICK, h, south_seg), color)
	if north_seg > 0.05:
		_add_wall_box(node_name + "_N", Vector3(x, h * 0.5, north_edge + north_seg * 0.5), Vector3(WALL_THICK, h, north_seg), color)
	_add_wall_box(node_name + "_H", Vector3(x, h - 0.35, opening_z), Vector3(WALL_THICK, 0.7, opening_w), color)


func _build_elevator_cabin() -> void:
	var c := _cabin_center
	var wt := WALL_THICK
	var h := CABIN_SIZE.y
	var half := CABIN_SIZE * 0.5

	_add_floor_box("CabinFloor", Vector3(c.x, -wt * 0.5, c.z), Vector3(CABIN_SIZE.x, wt, CABIN_SIZE.z), Color(0.24, 0.25, 0.27))
	_add_ceil_box("CabinCeil", Vector3(c.x, h, c.z), Vector3(CABIN_SIZE.x, wt, CABIN_SIZE.z), CEILING_COLOR)
	_add_wall_box("CabinWallS", Vector3(c.x, h * 0.5, c.z + half.z), Vector3(CABIN_SIZE.x, h, wt), ELEVATOR_COLOR)
	_add_wall_box("CabinWallE", Vector3(c.x + half.x, h * 0.5, c.z), Vector3(wt, h, CABIN_SIZE.z), ELEVATOR_COLOR)
	_add_wall_box("CabinWallW", Vector3(c.x - half.x, h * 0.5, c.z), Vector3(wt, h, CABIN_SIZE.z), ELEVATOR_COLOR)
	# Kabin ile landing arasındaki TEK duvar landing'in güney duvarıdır (daha geniş,
	# kabini tamamen kapsar). Kabinin kendi kuzey duvarı yok -> çift duvar/z-fighting yok.
	# Kabin arkasındaki asansör kapısı — kapalı metal panel (geri dönüş engeli)
	_add_solid_box("CabinDoorSeal", Vector3(c.x, h * 0.5 - 0.15, c.z + half.z - wt * 0.5 - 0.06), Vector3(1.6, h - 0.3, 0.12), Color(0.20, 0.22, 0.25), PsxSurfaceTextures.Surface.METAL)


func _build_landing() -> void:
	var c := _landing_center
	var wt := WALL_THICK
	var h := LANDING_SIZE.y
	var half := LANDING_SIZE * 0.5

	_add_floor_box("LandingFloor", Vector3(c.x, -wt * 0.5, c.z), Vector3(LANDING_SIZE.x, wt, LANDING_SIZE.z), FLOOR_COLOR)
	_add_ceil_box("LandingCeil", Vector3(c.x, h, c.z), Vector3(LANDING_SIZE.x, wt, LANDING_SIZE.z), CEILING_COLOR)
	# Güney duvar (kabine açılır) — kapı boşluğu
	_add_wall_x_with_opening("LandingWallS", c.z + half.z, c.x, LANDING_SIZE.x, h, c.x, 1.6, WALL_COLOR)
	# Doğu duvar (morgue hall'a) — kapı boşluğu
	_add_wall_z_with_opening("LandingWallE", c.x + half.x, c.z, LANDING_SIZE.z, h, c.z, HALL_WIDTH, WALL_COLOR)
	# Batı duvar (pump koridoruna) — kapı boşluğu
	_add_wall_z_with_opening("LandingWallW", c.x - half.x, c.z, LANDING_SIZE.z, h, c.z, HALL_WIDTH, WALL_COLOR)
	# Kuzey duvar (junction koridoruna) — kapı boşluğu
	_add_wall_x_with_opening("LandingWallN", c.z - half.z, c.x, LANDING_SIZE.x, h, c.x, HALL_WIDTH, WALL_COLOR)

	_add_pipe("LandingPipe", Vector3(c.x, h - 0.25, c.z + 1.0), Vector3(LANDING_SIZE.x - 1.0, 0.25, 0.25))
	_add_blood_decal("LandingBlood", Vector3(c.x + 1.0, 0.0, c.z - 1.2), Vector2(1.4, 1.6))


func _build_morgue_hall() -> void:
	var c := _morgue_hall_center
	var wt := WALL_THICK
	var h := ROOM_H
	var half_len := MORGUE_HALL_LEN * 0.5

	_add_floor_box("MorgueFloor", Vector3(c.x, -wt * 0.5, c.z), Vector3(MORGUE_HALL_LEN, wt, HALL_WIDTH), FLOOR_COLOR * 0.92)
	_add_ceil_box("MorgueCeil", Vector3(c.x, h, c.z), Vector3(MORGUE_HALL_LEN, wt, HALL_WIDTH), CEILING_COLOR)
	# Kuzey/güney uzun duvarlar
	_add_wall_box("MorgueWallN", Vector3(c.x, h * 0.5, c.z - HALL_WIDTH * 0.5), Vector3(MORGUE_HALL_LEN, h, wt), WALL_COLOR)
	_add_wall_box("MorgueWallS", Vector3(c.x, h * 0.5, c.z + HALL_WIDTH * 0.5), Vector3(MORGUE_HALL_LEN, h, wt), WALL_COLOR)

	# Morg çekmeceleri — kuzey duvar boyunca dizili metal çekmeceler
	var drawer_count := 6
	for i in drawer_count:
		var dx := c.x - half_len + 2.0 + i * ((MORGUE_HALL_LEN - 4.0) / float(drawer_count - 1))
		var open := (i % 2 == 0)
		_add_morgue_drawer("MorgueDrawer%d" % i, Vector3(dx, 0.7, c.z - HALL_WIDTH * 0.5 + 0.45), open)

	# Kan izleri + tavan boruları
	_add_blood_decal("MorgueBlood1", Vector3(c.x - 3.0, 0.0, c.z), Vector2(1.6, 1.8))
	_add_blood_decal("MorgueBlood2", Vector3(c.x + 2.5, 0.0, c.z + 0.4), Vector2(1.4, 1.5))
	_add_pipe("MorguePipe", Vector3(c.x, h - 0.2, c.z + 1.0), Vector3(MORGUE_HALL_LEN - 1.0, 0.22, 0.22))


# Morg çekmecesi — kapalı ya da yarı açık paslanmaz çelik çekmece.
func _add_morgue_drawer(node_name: String, pos: Vector3, open: bool) -> void:
	_add_solid_box(node_name + "Body", pos, Vector3(0.9, 0.7, 0.85), MORGUE_COLOR, PsxSurfaceTextures.Surface.METAL)
	if open:
		# Dışarı çekilmiş tabla + hafif kan
		_add_solid_box(node_name + "Tray", Vector3(pos.x, pos.y, pos.z + 0.75), Vector3(0.8, 0.12, 0.9), MORGUE_COLOR * 0.9, PsxSurfaceTextures.Surface.METAL)
		_add_blood_decal(node_name + "Drip", Vector3(pos.x, 0.0, pos.z + 0.9), Vector2(0.8, 1.0))


func _build_cold_storage() -> void:
	var c := _cold_storage_center
	var wt := WALL_THICK
	var h := COLD_STORAGE_SIZE.y
	var half := COLD_STORAGE_SIZE * 0.5

	_add_floor_box("ColdFloor", Vector3(c.x, -wt * 0.5, c.z), Vector3(COLD_STORAGE_SIZE.x, wt, COLD_STORAGE_SIZE.z), FLOOR_COLOR * 0.85)
	_add_ceil_box("ColdCeil", Vector3(c.x, h, c.z), Vector3(COLD_STORAGE_SIZE.x, wt, COLD_STORAGE_SIZE.z), CEILING_COLOR)
	_add_wall_box("ColdWallN", Vector3(c.x, h * 0.5, c.z - half.z), Vector3(COLD_STORAGE_SIZE.x, h, wt), WALL_COLOR)
	_add_wall_box("ColdWallS", Vector3(c.x, h * 0.5, c.z + half.z), Vector3(COLD_STORAGE_SIZE.x, h, wt), WALL_COLOR)
	_add_wall_box("ColdWallE", Vector3(c.x + half.x, h * 0.5, c.z), Vector3(wt, h, COLD_STORAGE_SIZE.z), WALL_COLOR)
	# Batı duvar (morgue hall'a) — kapı boşluğu
	_add_wall_z_with_opening("ColdWallW", c.x - half.x, c.z, COLD_STORAGE_SIZE.z, h, c.z, HALL_WIDTH, WALL_COLOR)

	# Anahtarın durduğu paslı masa
	_add_solid_box("ColdTable", Vector3(c.x + 1.5, 0.45, c.z - 1.2), Vector3(1.4, 0.9, 0.8), TRIM_COLOR, PsxSurfaceTextures.Surface.METAL)
	# Duvarda kan sıçraması hissi için zemin havuzları
	_add_blood_decal("ColdPool1", Vector3(c.x, 0.0, c.z + 0.5), Vector2(2.2, 2.0))
	_add_blood_decal("ColdPool2", Vector3(c.x - 1.5, 0.0, c.z - 1.0), Vector2(1.3, 1.4))


# ============================================================
#  IŞIKLAR / PICKUP / INTERACTABLE / TRIGGER — sonraki bölümde
# ============================================================


func _build_pump_room() -> void:
	var c := _pump_room_center
	var wt := WALL_THICK
	var h := PUMP_ROOM_SIZE.y
	var half := PUMP_ROOM_SIZE * 0.5

	# Landing ile pump room arasındaki bağlantı koridoru
	var land_w_edge := _landing_center.x - LANDING_SIZE.x * 0.5
	var pump_e_edge := c.x + half.x
	var cor_center := (land_w_edge + pump_e_edge) * 0.5
	var cor_len := land_w_edge - pump_e_edge
	_add_floor_box("PumpCorFloor", Vector3(cor_center, -wt * 0.5, c.z), Vector3(cor_len, wt, HALL_WIDTH), FLOOR_COLOR * 0.9)
	_add_ceil_box("PumpCorCeil", Vector3(cor_center, h, c.z), Vector3(cor_len, wt, HALL_WIDTH), CEILING_COLOR)
	_add_wall_box("PumpCorWallN", Vector3(cor_center, h * 0.5, c.z - HALL_WIDTH * 0.5), Vector3(cor_len, h, wt), WALL_COLOR)
	_add_wall_box("PumpCorWallS", Vector3(cor_center, h * 0.5, c.z + HALL_WIDTH * 0.5), Vector3(cor_len, h, wt), WALL_COLOR)

	# Pump room kabuğu — doğu duvarında (koridora) kapı boşluğu
	_add_floor_box("PumpFloor", Vector3(c.x, -wt * 0.5, c.z), Vector3(PUMP_ROOM_SIZE.x, wt, PUMP_ROOM_SIZE.z), FLOOR_COLOR * 0.82)
	_add_ceil_box("PumpCeil", Vector3(c.x, h, c.z), Vector3(PUMP_ROOM_SIZE.x, wt, PUMP_ROOM_SIZE.z), CEILING_COLOR)
	_add_wall_box("PumpWallN", Vector3(c.x, h * 0.5, c.z - half.z), Vector3(PUMP_ROOM_SIZE.x, h, wt), WALL_COLOR)
	_add_wall_box("PumpWallS", Vector3(c.x, h * 0.5, c.z + half.z), Vector3(PUMP_ROOM_SIZE.x, h, wt), WALL_COLOR)
	_add_wall_box("PumpWallW", Vector3(c.x - half.x, h * 0.5, c.z), Vector3(wt, h, PUMP_ROOM_SIZE.z), WALL_COLOR)
	_add_wall_z_with_opening("PumpWallE", c.x + half.x, c.z, PUMP_ROOM_SIZE.z, h, c.z, HALL_WIDTH, WALL_COLOR)

	# Kazan/pompa blokları + borular
	_add_solid_box("BoilerTank", Vector3(c.x - 1.8, 1.1, c.z - 1.6), Vector3(1.6, 2.2, 1.6), Color(0.30, 0.28, 0.26), PsxSurfaceTextures.Surface.METAL)
	_add_solid_box("PumpUnit", Vector3(c.x + 1.4, 0.6, c.z + 1.8), Vector3(1.4, 1.2, 1.2), Color(0.28, 0.30, 0.30), PsxSurfaceTextures.Surface.METAL)
	_add_pipe("PumpPipeV", Vector3(c.x - 1.8, 2.4, c.z - 1.6), Vector3(0.22, 1.2, 0.22))
	_add_pipe("PumpPipeH", Vector3(c.x - 0.5, h - 0.3, c.z), Vector3(PUMP_ROOM_SIZE.x - 1.5, 0.22, 0.22))
	_add_water_plane("PumpWater", Vector3(c.x, 0.0, c.z + 0.5), Vector2(4.0, 3.0))


func _build_junction() -> void:
	var c := _junction_center
	var wt := WALL_THICK
	var h := JUNCTION_SIZE.y
	var half := JUNCTION_SIZE * 0.5

	# Landing ile junction arasındaki bağlantı koridoru (güney tarafı)
	var land_n_edge := _landing_center.z - LANDING_SIZE.z * 0.5
	var junc_s_edge := c.z + half.z
	var cor_center := (land_n_edge + junc_s_edge) * 0.5
	var cor_len := land_n_edge - junc_s_edge
	_add_floor_box("JuncCorFloor", Vector3(c.x, -wt * 0.5, cor_center), Vector3(HALL_WIDTH, wt, cor_len), FLOOR_COLOR * 0.9)
	_add_ceil_box("JuncCorCeil", Vector3(c.x, h, cor_center), Vector3(HALL_WIDTH, wt, cor_len), CEILING_COLOR)
	_add_wall_box("JuncCorWallE", Vector3(c.x + HALL_WIDTH * 0.5, h * 0.5, cor_center), Vector3(wt, h, cor_len), WALL_COLOR)
	_add_wall_box("JuncCorWallW", Vector3(c.x - HALL_WIDTH * 0.5, h * 0.5, cor_center), Vector3(wt, h, cor_len), WALL_COLOR)

	# Junction kabuğu — güney (koridora) ve kuzey (generator'a) kapı boşlukları
	_add_floor_box("JuncFloor", Vector3(c.x, -wt * 0.5, c.z), Vector3(JUNCTION_SIZE.x, wt, JUNCTION_SIZE.z), FLOOR_COLOR * 0.8)
	_add_ceil_box("JuncCeil", Vector3(c.x, h, c.z), Vector3(JUNCTION_SIZE.x, wt, JUNCTION_SIZE.z), CEILING_COLOR)
	_add_wall_box("JuncWallE", Vector3(c.x + half.x, h * 0.5, c.z), Vector3(wt, h, JUNCTION_SIZE.z), WALL_COLOR)
	_add_wall_box("JuncWallW", Vector3(c.x - half.x, h * 0.5, c.z), Vector3(wt, h, JUNCTION_SIZE.z), WALL_COLOR)
	_add_wall_x_with_opening("JuncWallS", c.z + half.z, c.x, JUNCTION_SIZE.x, h, c.x, HALL_WIDTH, WALL_COLOR)
	_add_wall_x_with_opening("JuncWallN", c.z - half.z, c.x, JUNCTION_SIZE.x, h, c.x, HALL_WIDTH, WALL_COLOR)

	# Su basmış zemin + yoğun sis hissi
	_add_water_plane("JuncWater1", Vector3(c.x, 0.0, c.z), Vector2(JUNCTION_SIZE.x - 1.0, JUNCTION_SIZE.z - 1.0))
	_add_blood_decal("JuncBlood", Vector3(c.x - 1.5, 0.0, c.z + 1.0), Vector2(1.6, 1.5))
	_add_pipe("JuncPipe", Vector3(c.x, h - 0.25, c.z), Vector3(0.24, 0.24, JUNCTION_SIZE.z - 1.0))


func _build_generator_room() -> void:
	var c := _generator_room_center
	var wt := WALL_THICK
	var h := GENERATOR_ROOM_SIZE.y
	var half := GENERATOR_ROOM_SIZE * 0.5

	_add_floor_box("GenFloor", Vector3(c.x, -wt * 0.5, c.z), Vector3(GENERATOR_ROOM_SIZE.x, wt, GENERATOR_ROOM_SIZE.z), FLOOR_COLOR * 0.85)
	_add_ceil_box("GenCeil", Vector3(c.x, h, c.z), Vector3(GENERATOR_ROOM_SIZE.x, wt, GENERATOR_ROOM_SIZE.z), CEILING_COLOR)
	_add_wall_box("GenWallN", Vector3(c.x, h * 0.5, c.z - half.z), Vector3(GENERATOR_ROOM_SIZE.x, h, wt), WALL_COLOR)
	_add_wall_box("GenWallE", Vector3(c.x + half.x, h * 0.5, c.z), Vector3(wt, h, GENERATOR_ROOM_SIZE.z), WALL_COLOR)
	_add_wall_box("GenWallW", Vector3(c.x - half.x, h * 0.5, c.z), Vector3(wt, h, GENERATOR_ROOM_SIZE.z), WALL_COLOR)
	# Güney duvar (junction'a) — kapı boşluğu
	_add_wall_x_with_opening("GenWallS", c.z + half.z, c.x, GENERATOR_ROOM_SIZE.x, h, c.x, HALL_WIDTH, WALL_COLOR)

	# Büyük jeneratör bloğu
	_add_solid_box("GenBlock", Vector3(c.x, 0.8, c.z - 1.8), Vector3(3.2, 1.6, 2.0), Color(0.26, 0.27, 0.24), PsxSurfaceTextures.Surface.METAL)
	_add_pipe("GenPipe1", Vector3(c.x - 1.8, h - 0.3, c.z), Vector3(0.24, 0.24, GENERATOR_ROOM_SIZE.z - 1.0))
	_add_pipe("GenPipe2", Vector3(c.x + 1.8, h - 0.3, c.z), Vector3(0.24, 0.24, GENERATOR_ROOM_SIZE.z - 1.0))
	_add_blood_decal("GenBlood", Vector3(c.x + 2.0, 0.0, c.z + 1.5), Vector2(1.3, 1.4))


# ============================================================
#  IŞIKLAR
# ============================================================

func _build_lights() -> void:
	# Güç gelmeden görünmez; on_basement_power_restored ile açılır.
	_add_power_light("LandingLight", _landing_center + Vector3(0, 2.6, 0), 0.4, 8.0, Color(0.85, 0.8, 0.7))
	_add_power_light("MorgueLightW", _morgue_hall_center + Vector3(-4.0, 2.6, 0), 0.35, 7.0, Color(0.8, 0.82, 0.85))
	_add_power_light("MorgueLightE", _morgue_hall_center + Vector3(4.0, 2.6, 0), 0.35, 7.0, Color(0.8, 0.82, 0.85))
	_add_power_light("ColdLight", _cold_storage_center + Vector3(0, 2.6, 0), 0.4, 7.0, Color(0.72, 0.82, 0.9))
	_add_power_light("PumpLight", _pump_room_center + Vector3(0, 2.6, 0), 0.45, 8.0, Color(0.9, 0.82, 0.6))
	_add_power_light("JuncLight", _junction_center + Vector3(0, 2.6, 0), 0.38, 8.0, Color(0.75, 0.8, 0.85))
	_add_power_light("GenLight", _generator_room_center + Vector3(0, 2.8, 0), 0.5, 9.0, Color(0.92, 0.86, 0.7))

	# Kabin — güçten bağımsız loş acil ışığı (oyuncu başlangıçta görsün)
	_add_ambient_fill_light("CabinFill", _cabin_center + Vector3(0, 2.2, 0), 0.2, 5.0, Color(0.6, 0.55, 0.5))


func _add_power_light(node_name: String, pos: Vector3, energy: float, light_range: float, color: Color) -> void:
	var light := OmniLight3D.new()
	light.name = node_name
	light.position = pos
	light.light_energy = energy
	light.omni_range = light_range
	light.light_color = color
	light.set_meta("power_energy", energy)
	light.visible = false
	light.add_to_group(GENERATED_GROUP)
	add_child(light)
	_power_lights.append(light)


func _add_ambient_fill_light(node_name: String, pos: Vector3, energy: float, light_range: float, color: Color) -> void:
	var light := OmniLight3D.new()
	light.name = node_name
	light.position = pos
	light.light_energy = energy
	light.omni_range = light_range
	light.light_color = color
	light.add_to_group(GENERATED_GROUP)
	add_child(light)


# ============================================================
#  INTERACTABLE'LAR (note / valve / generator / elevator / kilitli kapı)
# ============================================================

func _build_interactables() -> void:
	# Landing bakım levhası — kuzey duvara (junction kapısının yanına) yaslı pano.
	var landing_n_inner := _landing_center.z - LANDING_SIZE.z * 0.5 + WALL_THICK * 0.5 + 0.03
	_add_note(
		"LandingNote",
		Vector3(_landing_center.x - 2.0, 1.5, landing_n_inner),
		Vector3(0.5, 0.6, 0.06),
		Color(0.8, 0.78, 0.68),
		"Maintenance Board",
		"SUB-LEVEL B — LAYOUT\n\nEAST: Morgue / Cold Storage\nWEST: Pump & Boiler\nNORTH: Generator\n\nElevator runs on the sub-generator.\nGenerator won't crank until the COOLANT VALVE\nis open — PUMP ROOM, west wing.",
		""
	)
	_add_inner_voice_zone("LandingSafe", _landing_center + Vector3(0, 1.2, 0), Vector3(4.0, 2.4, 4.0), "safe_zone")

	# Morgue kayıt defteri — kuzey duvara tam yaslı, göz hizasına yakın.
	var morgue_n_inner := _morgue_hall_center.z - HALL_WIDTH * 0.5 + WALL_THICK * 0.5 + 0.03
	_add_note(
		"MorgueNote",
		Vector3(_morgue_hall_center.x - 2.0, 1.4, morgue_n_inner),
		Vector3(0.45, 0.35, 0.06),
		Color(0.78, 0.74, 0.62),
		"Cold Storage Log",
		"Intake exceeded capacity on the 11th.\nWe stacked them two to a drawer.\n\nBy the 13th the drawers were opening on their own.\nWe stopped logging after that.\n\nWhatever the mist does to the living,\nit does something worse to the dead.",
		"morgue_dread"
	)

	# Cold Storage anahtar etiketi — masanın (ColdTable) üstüne tam oturur.
	# ColdTable: merkez (c.x+1.5, 0.45, c.z-1.2), üst yüzü y=0.9.
	_add_note(
		"ColdNote",
		Vector3(_cold_storage_center.x + 1.5, 0.93, _cold_storage_center.z - 1.2),
		Vector3(0.3, 0.04, 0.22),
		Color(0.75, 0.7, 0.6),
		"Grease-Stained Tag",
		"PUMP ROOM KEY\nReturn to maintenance after use.\n\n(Someone scratched under it:)\n'it doesn't want the water moving'",
		""
	)

	# Pump Room kapısı — koridordan girişte kilitli (maintenance_key gerekir)
	var pump_e_edge := _pump_room_center.x + PUMP_ROOM_SIZE.x * 0.5
	_add_locked_door(
		"PumpDoor",
		Vector3(pump_e_edge - 0.05, 1.3, _pump_room_center.z),
		Vector3(0.16, 2.6, HALL_WIDTH + 0.1),
		Color(0.34, 0.36, 0.34),
		"maintenance_key",
		"Locked — Maintenance Key required (Cold Storage)"
	)

	# Coolant valfi — Pump Room içinde, pompa ünitesinin üstünde
	_add_valve(
		"CoolantValve",
		_pump_room_center + Vector3(1.4, 1.35, 1.8),
		Vector3(0.5, 0.5, 0.2),
		Color(0.55, 0.42, 0.25)
	)

	# Jeneratör paneli — Generator Room, jeneratör bloğunun ön yüzünde
	_add_generator_panel(
		"GeneratorPanel",
		_generator_room_center + Vector3(0.0, 1.2, -0.75),
		Vector3(0.5, 0.5, 0.18),
		Color(0.45, 0.42, 0.3)
	)

	# Dönüş asansörü paneli — kabin duvarında
	_add_elevator_return_panel(
		"ElevatorReturn",
		_cabin_center + Vector3(CABIN_SIZE.x * 0.5 - 0.12, 1.2, -0.6),
		Vector3(0.12, 0.4, 0.3),
		Color(0.5, 0.48, 0.2)
	)


# --- Interactable node factory'leri ---

func _make_interactable_body(node: Node3D, box_size: Vector3, color: Color, surface: int, double_sided: bool) -> void:
	var body := StaticBody3D.new()
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = box_size
	mesh_instance.mesh = box
	mesh_instance.material_override = _material_for_box(box_size, color, surface, double_sided)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = box_size
	collision.shape = shape
	body.add_child(mesh_instance)
	body.add_child(collision)
	node.add_child(body)


func _add_note(node_name: String, pos: Vector3, box_size: Vector3, color: Color, title: String, body_text: String, inner_voice: String = "") -> void:
	var node := Node3D.new()
	node.name = node_name
	node.position = pos
	node.add_to_group(GENERATED_GROUP)
	node.set_script(load("res://scripts/interaction/note_placeholder.gd"))
	node.set("note_title", title)
	node.set("note_body", body_text)
	if not inner_voice.is_empty():
		node.set("inner_voice_trigger", inner_voice)
	_make_interactable_body(node, box_size, color, -1, true)
	add_child(node)


func _add_inner_voice_zone(node_name: String, pos: Vector3, box_size: Vector3, trigger_id: String) -> void:
	var area := Area3D.new()
	area.name = node_name
	area.position = pos
	area.add_to_group(GENERATED_GROUP)
	area.set_script(load("res://scripts/components/inner_voice_zone.gd"))
	area.set("trigger_id", trigger_id)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = box_size
	collision.shape = shape
	area.add_child(collision)
	add_child(area)


func _add_locked_door(node_name: String, pos: Vector3, box_size: Vector3, color: Color, key_id: String, message: String) -> void:
	var node := Node3D.new()
	node.name = node_name
	node.position = pos
	node.add_to_group(GENERATED_GROUP)
	node.set_script(load("res://scripts/interaction/locked_door.gd"))
	node.set("required_key_id", key_id)
	node.set("locked_message", message)
	_make_interactable_body(node, box_size, color, PsxSurfaceTextures.Surface.DOOR, true)
	add_child(node)


func _add_valve(node_name: String, pos: Vector3, box_size: Vector3, color: Color) -> void:
	var node := Node3D.new()
	node.name = node_name
	node.position = pos
	node.add_to_group(GENERATED_GROUP)
	node.set_script(load("res://scripts/interaction/valve_wheel.gd"))
	_make_interactable_body(node, box_size, color, PsxSurfaceTextures.Surface.METAL, true)
	add_child(node)


func _add_generator_panel(node_name: String, pos: Vector3, box_size: Vector3, color: Color) -> void:
	var node := Node3D.new()
	node.name = node_name
	node.position = pos
	node.add_to_group(GENERATED_GROUP)
	node.set_script(load("res://scripts/interaction/generator_panel.gd"))
	_make_interactable_body(node, box_size, color, PsxSurfaceTextures.Surface.METAL, true)
	add_child(node)


func _add_elevator_return_panel(node_name: String, pos: Vector3, box_size: Vector3, color: Color) -> void:
	var node := Node3D.new()
	node.name = node_name
	node.position = pos
	node.add_to_group(GENERATED_GROUP)
	node.set_script(load("res://scripts/interaction/elevator_return_panel.gd"))
	_make_interactable_body(node, box_size, color, PsxSurfaceTextures.Surface.METAL, true)
	add_child(node)


# ============================================================
#  PICKUP'LAR
# ============================================================

func _build_pickups() -> void:
	# Antechamber (landing) — oyuncu bodruma iner inmez ölü bir bekçinin yanında
	# yerde parlayan silahı bulur. Part 1'de silah yok; ilk ateşli silah burada.
	var corpse_pos := _landing_center + Vector3(-1.8, 0.0, 1.6)
	_add_corpse("LandingCorpse", corpse_pos, -0.6)
	var pistol_pos := corpse_pos + Vector3(0.75, _y_on_surface(FLOOR_TOP, 0.2) - corpse_pos.y, 0.35)
	_add_pickup("PickupPistol", "pistol", 1, Vector3(pistol_pos.x, _y_on_surface(FLOOR_TOP, 0.2), pistol_pos.z), Vector3(0.42, 0.2, 0.26), Color(0.55, 0.58, 0.66))
	_add_pickup_spotlight("PistolSpot", Vector3(pistol_pos.x, 1.9, pistol_pos.z), Color(0.72, 0.82, 1.0), 2.6, 2.6)
	_add_blood_decal("LandingCorpseBlood", Vector3(corpse_pos.x + 0.2, 0.0, corpse_pos.z), Vector2(1.8, 1.6))

	# Landing — herb + ammo (Part 1'den yaralı/az mermili gelen oyuncuya)
	_add_pickup("PickupHerbLanding", "green_herb", 1, _landing_center + Vector3(2.2, _y_on_surface(FLOOR_TOP, 0.28), 1.5), Vector3(0.28, 0.28, 0.28), Color(0.2, 0.72, 0.3))
	_add_pickup("PickupAmmoLanding", "pistol_ammo", 6, _landing_center + Vector3(2.4, _y_on_surface(FLOOR_TOP, 0.15), -1.5), Vector3(0.22, 0.15, 0.18), Color(0.8, 0.75, 0.2))

	# Cold Storage — MAINTENANCE KEY (masada) + spot
	_add_pickup("PickupKey", "maintenance_key", 1, _cold_storage_center + Vector3(1.5, _y_on_surface(0.9, 0.12), -1.2), Vector3(0.3, 0.12, 0.18), Color(0.7, 0.6, 0.3))
	_add_pickup_spotlight("KeySpot", _cold_storage_center + Vector3(1.5, 1.9, -1.2), Color(0.7, 0.85, 1.0), 2.2, 2.4)

	# Pump Room — ambush öncesi hazırlık (herb + ammo)
	_add_pickup("PickupHerbPump", "green_herb", 1, _pump_room_center + Vector3(-2.5, _y_on_surface(FLOOR_TOP, 0.28), 2.0), Vector3(0.28, 0.28, 0.28), Color(0.2, 0.72, 0.3))
	_add_pickup("PickupAmmoPump", "pistol_ammo", 6, _pump_room_center + Vector3(2.8, _y_on_surface(FLOOR_TOP, 0.15), -2.0), Vector3(0.22, 0.15, 0.18), Color(0.8, 0.75, 0.2))

	# Generator Room — final gerginlik için ekstra mermi
	_add_pickup("PickupAmmoGen", "pistol_ammo", 8, _generator_room_center + Vector3(-2.5, _y_on_surface(FLOOR_TOP, 0.15), 1.8), Vector3(0.22, 0.15, 0.18), Color(0.8, 0.75, 0.2))


# Yere yığılmış ölü beden — kutulardan basit PSX ceset. yaw radyan cinsinden
# gövdenin dönüşünü belirler (bedenin uzandığı yön).
func _add_corpse(node_name: String, pos: Vector3, yaw: float) -> void:
	var root := Node3D.new()
	root.name = node_name
	root.position = pos
	root.rotation.y = yaw
	root.add_to_group(GENERATED_GROUP)
	add_child(root)

	var skin := Color(0.62, 0.58, 0.52)
	var cloth := Color(0.24, 0.22, 0.24)

	# Yere uzanmış gövde (alçak, yatay)
	_add_corpse_box(root, "Torso", Vector3(0.0, 0.18, 0.0), Vector3(0.5, 0.32, 0.9), cloth)
	# Baş — gövdenin bir ucunda
	_add_corpse_box(root, "Head", Vector3(0.0, 0.16, 0.62), Vector3(0.26, 0.26, 0.26), skin)
	# Bacaklar — diğer uçta, hafif yana devrik
	_add_corpse_box(root, "Legs", Vector3(0.08, 0.14, -0.7), Vector3(0.42, 0.24, 0.7), cloth)
	# Yana açılmış kol (silahın uzandığı taraf)
	_add_corpse_box(root, "Arm", Vector3(0.42, 0.12, 0.2), Vector3(0.5, 0.18, 0.2), skin)


func _add_corpse_box(parent: Node3D, node_name: String, local_pos: Vector3, box_size: Vector3, color: Color) -> void:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.position = local_pos
	var box := BoxMesh.new()
	box.size = box_size
	mi.mesh = box
	mi.material_override = PsxMaterialHelper.create_material(color)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)


func _add_pickup(node_name: String, item_id: String, count: int, pos: Vector3, box_size: Vector3, color: Color) -> void:
	var pickup := Node3D.new()
	pickup.name = node_name
	pickup.position = pos
	pickup.add_to_group(GENERATED_GROUP)
	pickup.set_script(load("res://scripts/inventory/pickup_item.gd"))
	pickup.set("item_id", item_id)
	pickup.set("pickup_count", count)
	pickup.set("pickup_color", color)

	var body := StaticBody3D.new()
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = box_size
	mesh_instance.mesh = box

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(maxf(box_size.x, 0.6), maxf(box_size.y, 0.6), maxf(box_size.z, 0.6))
	collision.shape = shape
	collision.position = Vector3(0, maxf(0.0, 0.3 - box_size.y * 0.5), 0)

	body.add_child(mesh_instance)
	body.add_child(collision)
	pickup.add_child(body)
	add_child(pickup)


func _add_pickup_spotlight(node_name: String, pos: Vector3, color: Color, energy: float, light_range: float) -> void:
	var light := OmniLight3D.new()
	light.name = node_name
	light.position = pos
	light.light_color = color
	light.light_energy = energy
	light.omni_range = light_range
	light.add_to_group(GENERATED_GROUP)
	add_child(light)


# ============================================================
#  YAKLAŞMA TETİKLEYİCİLERİ
# ============================================================

func _build_triggers() -> void:
	# Morgue Hall ortasında — ilk yaratık ("The Patient") tetikleyici
	_add_proximity_trigger("MorgueTrigger", _morgue_hall_center + Vector3(-1.0, 1.2, 0), Vector3(HALL_WIDTH, 2.4, 3.0), "morgue_creature")
	# Cold Storage — anahtar alındığında Stalker tetiklenir (item_added ile ele alınır)


func _add_proximity_trigger(node_name: String, pos: Vector3, box_size: Vector3, trigger_id: String) -> void:
	var area := Area3D.new()
	area.name = node_name
	area.position = pos
	area.add_to_group(GENERATED_GROUP)
	area.set_script(load("res://scripts/components/proximity_trigger.gd"))
	area.set("trigger_id", trigger_id)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = box_size
	collision.shape = shape
	area.add_child(collision)
	area.connect("player_entered", _on_proximity_trigger)
	add_child(area)


func _on_proximity_trigger(trigger_id: String) -> void:
	match trigger_id:
		"morgue_creature":
			spawn_morgue_creature()


# ============================================================
#  YARATIK SPAWN
# ============================================================

const ENEMY_SCENE := "res://scenes/enemies/test_enemy.tscn"


func _spawn_enemy(enemy_name: String, pos: Vector3, initial_state: int, chase_speed: float, chase_delay: float = 0.0) -> EnemyAI:
	var enemy_scene: PackedScene = load(ENEMY_SCENE)
	var enemy: EnemyAI = enemy_scene.instantiate() as EnemyAI
	enemy.name = enemy_name
	enemy.position = pos
	enemy.detection_range = 26.0
	enemy.patrol_speed = 1.2
	enemy.chase_speed = chase_speed
	enemy.attack_damage = 30.0
	enemy.use_contact_damage = true
	enemy.contact_range = 1.15
	enemy.contact_damage_cooldown = 0.65
	enemy.start_state = initial_state as EnemyAI.State
	enemy.add_to_group(GENERATED_GROUP)
	add_child(enemy)
	if chase_delay > 0.0:
		get_tree().create_timer(chase_delay).timeout.connect(func() -> void:
			if is_instance_valid(enemy):
				enemy.force_state(EnemyAI.State.CHASE)
		, CONNECT_ONE_SHOT)
	else:
		AudioManager.play_3d("enemy_growl", enemy.global_position, -2.0, 0.82, 0.92)
	return enemy


# Morgue Hall — açık bir çekmecenin önünde beliren yavaş "The Patient".
func spawn_morgue_creature() -> void:
	if Engine.is_editor_hint() or _morgue_creature_spawned or QuestManager.morgue_creature_done:
		return
	_morgue_creature_spawned = true
	QuestManager.mark_morgue_creature_done()
	# Part 1'de landing'ten sonra bu ilk state (SEEK_KEY)
	if QuestManager.part2_state == QuestManager.Part2State.ARRIVE:
		QuestManager.part2_state = QuestManager.Part2State.SEEK_KEY
		QuestManager.refresh_objective(true)

	var spawn_pos := _morgue_hall_center + Vector3(MORGUE_HALL_LEN * 0.35, 0.0, -0.4)
	var enemy := _spawn_enemy("MorgueCrawler", spawn_pos, EnemyAI.State.IDLE, 3.4, 1.1)
	_play_jumpscare(1.1)
	AudioManager.play("enemy_alert", 1.5)
	InnerVoiceManager.trigger("first_enemy")

	var tween := create_tween()
	tween.tween_interval(14.0)
	tween.tween_callback(func() -> void:
		if is_instance_valid(enemy):
			AudioManager.play_3d("enemy_death", enemy.global_position, -3.0, 0.8, 0.9)
			enemy.queue_free()
	)


# Cold Storage — anahtar alınınca kapı çarpar + hızlı Stalker kovalar.
func spawn_cold_storage_stalker() -> void:
	if Engine.is_editor_hint() or _stalker_spawned or QuestManager.cold_storage_stalker_done:
		return
	_stalker_spawned = true
	QuestManager.mark_cold_storage_stalker_done()

	var spawn_pos := _cold_storage_center + Vector3(COLD_STORAGE_SIZE.x * 0.5 - 1.0, 0.0, 1.8)
	var enemy := _spawn_enemy("ColdStalker", spawn_pos, EnemyAI.State.CHASE, 5.5)
	enemy.chase_speed = 5.5
	_play_jumpscare(1.25)
	AudioManager.play("enemy_alert", 2.0, 0.9, 1.0)
	AudioManager.play_3d("exit_sealed", _cold_storage_center + Vector3(-COLD_STORAGE_SIZE.x * 0.5, 1.0, 0), -2.0)

	var tween := create_tween()
	tween.tween_interval(16.0)
	tween.tween_callback(func() -> void:
		if is_instance_valid(enemy):
			AudioManager.play_3d("enemy_death", enemy.global_position, -3.0, 0.8, 0.9)
			enemy.queue_free()
	)


# Flooded Junction — valf açılınca iki yönlü pusu (önden + arkadan gecikmeli).
func spawn_junction_ambush() -> void:
	if Engine.is_editor_hint() or _junction_ambush_spawned or QuestManager.junction_ambush_done:
		return
	_junction_ambush_spawned = true
	QuestManager.mark_junction_ambush_done()

	var front := _spawn_enemy("JunctionFront", _junction_center + Vector3(0, 0, -JUNCTION_SIZE.z * 0.4), EnemyAI.State.IDLE, 5.0, 0.9)
	var back := _spawn_enemy("JunctionBack", _junction_center + Vector3(0, 0, JUNCTION_SIZE.z * 0.4), EnemyAI.State.IDLE, 5.0, 1.6)
	_play_jumpscare(1.15)
	AudioManager.play("enemy_alert", 2.0, 0.9, 1.05)

	var tween := create_tween()
	tween.tween_interval(20.0)
	tween.tween_callback(func() -> void:
		for e in [front, back]:
			if is_instance_valid(e):
				AudioManager.play_3d("enemy_death", e.global_position, -3.0, 0.8, 0.9)
				e.queue_free()
	)


# Güç geldikten sonra dönüş yolunda gezinen tek patrol yaratık.
func _spawn_return_patrol() -> void:
	if Engine.is_editor_hint() or _return_patrol_spawned:
		return
	_return_patrol_spawned = true
	var enemy := _spawn_enemy("ReturnPatrol", _landing_center + Vector3(0, 0, -1.5), EnemyAI.State.PATROL, 3.2)
	var pts: Array[Vector3] = [
		Vector3(2.0, 0, 1.5),
		Vector3(-2.0, 0, 1.5),
		Vector3(-2.0, 0, -1.5),
		Vector3(2.0, 0, -1.5),
	]
	enemy.set_patrol_points_local(pts)


func _play_jumpscare(intensity: float = 1.15) -> void:
	HudManager.play_jumpscare(intensity)
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_method("play_camera_shake"):
		var shake := 0.2 if intensity < 1.3 else 0.32 * intensity
		player.play_camera_shake(shake, 0.45 if intensity < 1.3 else 0.55)


# ============================================================
#  ITEM PICKUP TETİKLEYİCİLERİ
# ============================================================

func _on_item_picked_up(item: Item, _slot_index: int, _count: int) -> void:
	if item == null:
		return
	if item.id == "pistol":
		InnerVoiceManager.trigger("found_weapon")
	if item.id == "maintenance_key":
		QuestManager.on_maintenance_key_found()
		call_deferred("spawn_cold_storage_stalker")

