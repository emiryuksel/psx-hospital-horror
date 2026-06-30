# Part I — Lobby + Patient Wing + Utility Closet
# Görev: sigortayı bul (koridor jumpscare), lobby breaker'a tak (tek zombi pusu).
extends Node3D

const GENERATED_GROUP := "generated_part1"

const FLOOR_COLOR := Color(0.28, 0.30, 0.29)
const WALL_COLOR := Color(0.62, 0.60, 0.56)
const CEILING_COLOR := Color(0.48, 0.47, 0.45)
const TRIM_COLOR := Color(0.38, 0.36, 0.34)
const RECEPTION_COLOR := Color(0.32, 0.24, 0.18)
const CHAIR_COLOR := Color(0.42, 0.18, 0.15)
const DEBRIS_COLOR := Color(0.30, 0.28, 0.26)
const MIST_COLOR := Color(0.13, 0.15, 0.20, 0.85)
const ELEVATOR_COLOR := Color(0.25, 0.27, 0.30)
const GURNEY_COLOR := Color(0.55, 0.58, 0.60)
const UTILITY_COLOR := Color(0.34, 0.36, 0.38)
const BLOOD_COLOR := Color(0.45, 0.12, 0.10)

const LOBBY_SIZE := Vector3(14.0, 3.2, 12.0)
const WALL_THICK := 0.35
const CORRIDOR_WIDTH := 3.2
const CORRIDOR_LENGTH := 24.0
const UTILITY_SIZE := Vector3(5.0, 3.2, 5.0)
const PATIENT_ROOM_SIZE := Vector3(4.0, 3.2, 3.5)

# Hasta odasi yerlesim bilgileri: [z-konumu, koridorun hangi tarafi (1=sag, -1=sol)]
# Sira: index 0 = girise (guney ucu) en yakin oda.
const ROOM_DEFS := [
	{"z_offset": 8.0, "side": 1},    # Room A — sag, GIRISE EN YAKIN: kanli mezbaha odasi (bicak burada)
	{"z_offset": 8.0, "side": -1},   # Room B — sol, terk edilmis bekleme/gozlem odasi
	{"z_offset": 2.5, "side": 1},    # Room C — sag, ammo odasi
	{"z_offset": 2.5, "side": -1},   # Room D — sol, depo odasi (herb)
	{"z_offset": -3.0, "side": 1},   # Room E — sag, kan izleri (fuse burada)
	{"z_offset": -3.0, "side": -1},  # Room F — sol, karanlik oda
	{"z_offset": -8.5, "side": 1},   # Room G — sag, ek hasta odasi
	{"z_offset": -8.5, "side": -1},  # Room H — sol, ek hasta odasi
]

# Kapı boşluklarının yan duvardaki z konumları
const EXIT_DOOR_Z := 2.6
const BASEMENT_DOOR_Z := -3.0
const DOOR_OPENING_W := 1.6
const EXIT_OPENING_W := 1.7

# Z-fighting onleme — zemin ust yuzu y=0'dan hafif asagi, seal katmanlari daha da asagi.
const SURFACE_JOIN_EPS := 0.01
const SURFACE_JOIN_LAYER_EPS := 0.024

# Prop yerlestirme — yuzey ustune oturtma
const PROP_SURFACE_EPS := 0.01
const FLOOR_TOP := 0.0
const BED_MATTRESS_TOP := 0.63
const BED_MATTRESS_TOP_BLOODY := 0.67
const RECEPTION_DESK_TOP := 1.1
const RECEPTION_DESK_CENTER := Vector3(0.0, 0.0, -1.5)
const FUSE_INSTALL_AMBUSH_SPAWN := RECEPTION_DESK_CENTER + Vector3(0.0, 0.0, -0.95)
const CART_TOP := 0.54
const WORKBENCH_TOP := 0.9

var _corridor_center_z: float = 0.0
var _utility_center: Vector3 = Vector3.ZERO
var _power_lights: Array[Light3D] = []

@onready var _lobby_omni: OmniLight3D = $OmniLight3D
@onready var _entrance_omni: OmniLight3D = $OmniLight3D_Entrance


func _ready() -> void:
	_corridor_center_z = -LOBBY_SIZE.z * 0.5 - WALL_THICK - CORRIDOR_LENGTH * 0.5
	_utility_center = Vector3(
		0.0,
		0.0,
		_corridor_center_z - CORRIDOR_LENGTH * 0.5 - UTILITY_SIZE.z * 0.5 - WALL_THICK
	)

	if not Engine.is_editor_hint():
		_apply_fog_settings()
		PsxSettings.settings_changed.connect(_apply_fog_settings)
		QuestManager.power_restored.connect(_on_power_restored)
		QuestManager.fuse_install_ambush_requested.connect(_on_fuse_install_ambush_requested)
		InventoryManager.item_added.connect(_on_item_picked_up)

	_rebuild_geometry()

	if not Engine.is_editor_hint():
		if SaveManager.has_pending_load():
			call_deferred("_try_apply_save")
		else:
			if QuestManager.power_on:
				_on_power_restored()
			else:
				_apply_low_power_lighting()
			_fuse_pickup_creature_spawned = QuestManager.fuse_pickup_creature_done
			_fuse_install_creature_spawned = QuestManager.fuse_ambush_done
		QuestManager.refresh_objective()
		if GameSession.intro_pending:
			GameSession.intro_completed.connect(_start_ambient_drone, CONNECT_ONE_SHOT)
		else:
			_start_ambient_drone()


func _try_apply_save() -> void:
	if not SaveManager.has_pending_load():
		return
	await get_tree().process_frame
	SaveManager.apply_to_current_scene()
	_fuse_pickup_creature_spawned = QuestManager.fuse_pickup_creature_done
	_fuse_install_creature_spawned = QuestManager.fuse_ambush_done
	if QuestManager.power_on:
		_on_power_restored()
	else:
		_apply_low_power_lighting()


func _start_ambient_drone() -> void:
	AudioManager.start_ambient("ambient_drone", -16.0)


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
		world_env.environment.fog_density = PsxSettings.fog_density
		world_env.environment.fog_light_color = PsxSettings.fog_color


func _on_power_restored() -> void:
	_apply_full_power_lighting()
	for light in _power_lights:
		if is_instance_valid(light):
			light.visible = true


func _on_fuse_install_ambush_requested() -> void:
	call_deferred("spawn_fuse_install_creature")


func _apply_low_power_lighting() -> void:
	# Güç yok — zifiri karanlık, sadece flashlight iş görür.
	if _lobby_omni:
		_lobby_omni.light_energy = 0.0
	if _entrance_omni:
		_entrance_omni.light_energy = 0.0
	for light in _power_lights:
		if is_instance_valid(light):
			light.visible = false


func _apply_full_power_lighting() -> void:
	# Güç geldi — loş, titrek acil aydınlatma (yine de korkutucu).
	if _lobby_omni:
		_lobby_omni.light_energy = 0.35
		_lobby_omni.light_color = Color(0.85, 0.70, 0.50)
	if _entrance_omni:
		_entrance_omni.light_energy = 0.18
	for light in _power_lights:
		if is_instance_valid(light):
			light.visible = true
			light.light_energy = light.get_meta("power_energy", light.light_energy)


func _rebuild_geometry() -> void:
	_clear_generated()
	_build_lobby_shell()
	_build_patient_wing_corridor()
	_build_utility_room()
	_build_patient_rooms()
	_build_reception()
	_seal_section_junctions()
	_build_mist_windows()
	_build_lights()
	_build_interactables()
	_build_pickups()
	PsxMaterialHelper.fix_culling_tree(self)
	if not Engine.is_editor_hint():
		pass


func _clear_generated() -> void:
	for child in get_children():
		if child.is_in_group(GENERATED_GROUP):
			child.queue_free()
	_power_lights.clear()


func _build_lobby_shell() -> void:
	var half := LOBBY_SIZE * 0.5
	var h := LOBBY_SIZE.y
	var wt := WALL_THICK

	_add_floor_box("Floor", Vector3(0, -wt * 0.5, 0), Vector3(LOBBY_SIZE.x, wt, LOBBY_SIZE.z), FLOOR_COLOR)
	_add_ceil_box("Ceiling", Vector3(0, h, 0), Vector3(LOBBY_SIZE.x, wt, LOBBY_SIZE.z), CEILING_COLOR)

	var door_w := 4.0
	var side_w := (LOBBY_SIZE.x - door_w) * 0.5
	_add_wall_box("WallSouthLeft", Vector3(-half.x + side_w * 0.5, h * 0.5, half.z), Vector3(side_w, h, wt), WALL_COLOR)
	_add_wall_box("WallSouthRight", Vector3(half.x - side_w * 0.5, h * 0.5, half.z), Vector3(side_w, h, wt), WALL_COLOR)
	_add_wall_box("WallSouthHeader", Vector3(0, h - 0.4, half.z), Vector3(door_w, 0.8, wt), WALL_COLOR)
	# Ana giriş mühürlü — boşluğu kapatan metal panjur (dışarı düşmeyi önler)
	_add_solid_box("MainEntranceSeal", Vector3(0, (h - 0.8) * 0.5, half.z), Vector3(door_w, h - 0.8, wt), Color(0.20, 0.21, 0.23), PsxSurfaceTextures.Surface.METAL)

	var north_gap := CORRIDOR_WIDTH
	var north_side := (LOBBY_SIZE.x - north_gap) * 0.5
	_add_wall_box("WallNorthLeft", Vector3(-half.x + north_side * 0.5, h * 0.5, -half.z), Vector3(north_side, h, wt), WALL_COLOR)
	_add_wall_box("WallNorthRight", Vector3(half.x - north_side * 0.5, h * 0.5, -half.z), Vector3(north_side, h, wt), WALL_COLOR)
	_add_wall_box("WallNorthHeader", Vector3(0, h - 0.35, -half.z), Vector3(north_gap, 0.7, wt), WALL_COLOR)

	# East wall — EXIT kapısı boşluğu
	_add_wall_z_with_opening("WallEast", half.x, LOBBY_SIZE.z, h, wt, EXIT_DOOR_Z, EXIT_OPENING_W, WALL_COLOR * 0.95)
	# West wall — bodrum kapısı boşluğu
	_add_wall_z_with_opening("WallWest", -half.x, LOBBY_SIZE.z, h, wt, BASEMENT_DOOR_Z, DOOR_OPENING_W, WALL_COLOR * 0.92)

	# Asansör — kuzeydoğu köşede mühürlü metal kapılar (duvara gömülü)
	_add_solid_box("ElevatorDoors", Vector3(half.x - wt * 0.5 - 0.06, h * 0.5 - 0.2, -3.6), Vector3(0.12, h - 0.4, 2.0), ELEVATOR_COLOR, PsxSurfaceTextures.Surface.METAL)
	_add_solid_box("ElevatorFrameL", Vector3(half.x - wt * 0.5 - 0.1, h * 0.5, -4.7), Vector3(0.2, h, 0.2), TRIM_COLOR, PsxSurfaceTextures.Surface.METAL)
	_add_solid_box("ElevatorFrameR", Vector3(half.x - wt * 0.5 - 0.1, h * 0.5, -2.5), Vector3(0.2, h, 0.2), TRIM_COLOR, PsxSurfaceTextures.Surface.METAL)


func _build_patient_wing_corridor() -> void:
	var h := LOBBY_SIZE.y
	var wt := WALL_THICK
	var cz := _corridor_center_z

	_add_floor_box("CorridorFloor", Vector3(0, -wt * 0.5, cz), Vector3(CORRIDOR_WIDTH, wt, CORRIDOR_LENGTH), FLOOR_COLOR * 0.92)
	_add_ceil_box("CorridorCeil", Vector3(0, h, cz), Vector3(CORRIDOR_WIDTH, wt, CORRIDOR_LENGTH), CEILING_COLOR)

	# Lobby ile koridor arasındaki zemin/tavan boşluğunu kapatan eşik (düşmeyi önler)
	var lobby_north_edge := -LOBBY_SIZE.z * 0.5
	var corridor_south_edge := cz + CORRIDOR_LENGTH * 0.5
	var conn_z0 := corridor_south_edge - 0.1
	var conn_z1 := lobby_north_edge + 0.3
	var conn_center := (conn_z0 + conn_z1) * 0.5
	var conn_len := absf(conn_z1 - conn_z0)
	_add_floor_box("LobbyCorridorThreshold", Vector3(0, -wt * 0.5, conn_center), Vector3(CORRIDOR_WIDTH, wt, conn_len), FLOOR_COLOR * 0.9, true)
	_add_ceil_box("LobbyCorridorCeilJoin", Vector3(0, h, conn_center), Vector3(CORRIDOR_WIDTH, wt, conn_len), CEILING_COLOR, true)

	var north_end_z := cz - CORRIDOR_LENGTH * 0.5
	var south_end_z := cz + CORRIDOR_LENGTH * 0.5

	# Koridor duvarları — her iki tarafta hasta odası kapı boşlukları var
	# Sağ duvar (x+)
	_build_corridor_wall_segments("CorridorWallR", CORRIDOR_WIDTH * 0.5, cz, north_end_z, south_end_z, 1)
	# Sol duvar (x-)
	_build_corridor_wall_segments("CorridorWallL", -CORRIDOR_WIDTH * 0.5, cz, north_end_z, south_end_z, -1)

	var utility_door_w := 2.2
	_add_wall_box(
		"CorridorEndLeft",
		Vector3(-(utility_door_w * 0.5 + 0.3), h * 0.5, north_end_z),
		Vector3(CORRIDOR_WIDTH * 0.5 - utility_door_w * 0.5, h, wt),
		WALL_COLOR
	)
	_add_wall_box(
		"CorridorEndRight",
		Vector3(utility_door_w * 0.5 + 0.3, h * 0.5, north_end_z),
		Vector3(CORRIDOR_WIDTH * 0.5 - utility_door_w * 0.5, h, wt),
		WALL_COLOR
	)
	_add_wall_box("CorridorEndHeader", Vector3(0, h - 0.35, north_end_z), Vector3(utility_door_w, 0.7, wt), WALL_COLOR)

	# Kan izleri — zeminin hemen üstünde düz decal (z-fighting yapmaz)
	_add_blood_decal("BloodTrailA", Vector3(0.3, 0.0, south_end_z - 2.0), Vector2(1.4, 1.7))
	_add_blood_decal("BloodTrailB", Vector3(-0.2, 0.0, cz), Vector2(1.1, 1.3))
	_add_blood_decal("BloodTrailC", Vector3(0.1, 0.0, north_end_z + 1.5), Vector2(1.0, 1.1))


# Koridor yan duvarini, bu taraftaki hasta odasi kapilarini keserek insa eder.
func _build_corridor_wall_segments(base_name: String, wall_x: float, cz: float, north_end_z: float, south_end_z: float, side: int) -> void:
	var h := LOBBY_SIZE.y
	var wt := WALL_THICK
	var door_w := 1.4

	# Bu taraftaki oda kapılarının z pozisyonlarını topla
	var openings: Array[float] = []
	for def in ROOM_DEFS:
		if int(def["side"]) == side:
			openings.append(cz + float(def["z_offset"]))
	openings.sort()

	# Boşluklar arasındaki duvar segmentlerini oluştur
	var edges: Array[float] = [south_end_z]
	for oz in openings:
		edges.append(oz + door_w * 0.5)
		edges.append(oz - door_w * 0.5)
	edges.append(north_end_z)
	edges.sort()
	edges.reverse()

	var seg_idx := 0
	var i := 0
	while i < edges.size() - 1:
		var top_z: float = edges[i]
		var bot_z: float = edges[i + 1]
		var seg_len := top_z - bot_z
		# Kapı boşluğu aralığı mı kontrol et
		var is_opening := false
		for oz in openings:
			if absf((top_z + bot_z) * 0.5 - oz) < door_w * 0.4:
				is_opening = true
				break
		if not is_opening and seg_len > 0.1:
			_add_wall_box(
				"%s_Seg%d" % [base_name, seg_idx],
				Vector3(wall_x, h * 0.5, (top_z + bot_z) * 0.5),
				Vector3(wt, h, seg_len),
				WALL_COLOR
			)
			seg_idx += 1
		i += 1


func _build_utility_room() -> void:
	var h := UTILITY_SIZE.y
	var wt := WALL_THICK
	var c := _utility_center
	var half := UTILITY_SIZE * 0.5

	_add_floor_box("UtilityFloor", Vector3(c.x, -wt * 0.5, c.z), Vector3(UTILITY_SIZE.x, wt, UTILITY_SIZE.z), FLOOR_COLOR * 0.85)
	_add_ceil_box("UtilityCeil", Vector3(c.x, h, c.z), Vector3(UTILITY_SIZE.x, wt, UTILITY_SIZE.z), CEILING_COLOR)

	var south_z := c.z + half.z
	_add_wall_box("UtilityWallN", Vector3(c.x, h * 0.5, c.z - half.z), Vector3(UTILITY_SIZE.x, h, wt), UTILITY_COLOR)
	_add_wall_box("UtilityWallE", Vector3(c.x + half.x, h * 0.5, c.z), Vector3(wt, h, UTILITY_SIZE.z), UTILITY_COLOR)
	_add_wall_box("UtilityWallW", Vector3(c.x - half.x, h * 0.5, c.z), Vector3(wt, h, UTILITY_SIZE.z), UTILITY_COLOR)

	var door_w := 2.2
	_add_wall_box(
		"UtilitySouthLeft",
		Vector3(c.x - door_w * 0.5 - 0.8, h * 0.5, south_z),
		Vector3(half.x - door_w * 0.5, h, wt),
		UTILITY_COLOR
	)
	_add_wall_box(
		"UtilitySouthRight",
		Vector3(c.x + door_w * 0.5 + 0.8, h * 0.5, south_z),
		Vector3(half.x - door_w * 0.5, h, wt),
		UTILITY_COLOR
	)

	# Sigorta dolabı — kuzey duvarına gömülü metal kabin
	_add_solid_box("FuseCabinet", Vector3(c.x - 1.2, 1.1, c.z - half.z + wt * 0.5 + 0.21), Vector3(0.9, 1.8, 0.4), UTILITY_COLOR * 0.9, PsxSurfaceTextures.Surface.METAL)
	# Çalışma tezgahı — doğu duvarına dayalı alçak metal tezgah
	_add_solid_box("Workbench", Vector3(c.x + half.x - 0.5 - wt * 0.5, 0.45, c.z + 0.3), Vector3(0.9, 0.9, 2.0), TRIM_COLOR, PsxSurfaceTextures.Surface.METAL)


func _build_patient_rooms() -> void:
	var h := PATIENT_ROOM_SIZE.y
	var wt := WALL_THICK
	var cz := _corridor_center_z

	for i in ROOM_DEFS.size():
		var def: Dictionary = ROOM_DEFS[i]
		var side: int = def["side"]
		var room_z: float = cz + def["z_offset"]
		var room_x: float = side * (CORRIDOR_WIDTH * 0.5 + PATIENT_ROOM_SIZE.x * 0.5 + wt)
		var room_name := "PatientRoom%s" % char(65 + i)

		_build_single_patient_room(room_name, room_x, room_z, side, i)
		_seal_patient_room_junction(room_name, room_x, room_z, side)
		_add_corridor_wall_for_room(room_name, room_z, side)


func _build_single_patient_room(room_name: String, room_x: float, room_z: float, side: int, index: int) -> void:
	var h := PATIENT_ROOM_SIZE.y
	var wt := WALL_THICK
	var rs := PATIENT_ROOM_SIZE

	_add_floor_box(room_name + "Floor", Vector3(room_x, -wt * 0.5, room_z), Vector3(rs.x, wt, rs.z), FLOOR_COLOR * 0.88)
	_add_ceil_box(room_name + "Ceil", Vector3(room_x, h, room_z), Vector3(rs.x, wt, rs.z), CEILING_COLOR)
	_add_wall_box(room_name + "WallN", Vector3(room_x, h * 0.5, room_z - rs.z * 0.5), Vector3(rs.x, h, wt), WALL_COLOR)
	_add_wall_box(room_name + "WallS", Vector3(room_x, h * 0.5, room_z + rs.z * 0.5), Vector3(rs.x, h, wt), WALL_COLOR)
	_add_wall_box(room_name + "WallFar", Vector3(room_x + side * rs.x * 0.5, h * 0.5, room_z), Vector3(wt, h, rs.z), WALL_COLOR)

	# Yatak
	var bed_x := room_x + side * (rs.x * 0.5 - 0.6)
	_add_solid_box(room_name + "BedFrame", Vector3(bed_x, 0.28, room_z - 0.4), Vector3(0.95, 0.4, 2.0), Color(0.32, 0.34, 0.36), PsxSurfaceTextures.Surface.METAL)
	_add_solid_box(room_name + "BedMattress", Vector3(bed_x, 0.55, room_z - 0.4), Vector3(0.85, 0.16, 1.85), Color(0.62, 0.60, 0.56))
	_add_solid_box(room_name + "BedHead", Vector3(bed_x, 0.6, room_z - 1.3), Vector3(0.95, 0.7, 0.1), Color(0.30, 0.32, 0.34), PsxSurfaceTextures.Surface.METAL)

	# Index 0 (girise en yakin sag oda) = kanli mezbaha odasi
	if index == 0:
		_furnish_carnage_room(room_name, room_x, room_z, side)
	elif index == 4 or index == 5:
		# Fuse/karanlik oda — orta seviye kan izi
		_add_blood_decal(room_name + "Blood", Vector3(room_x - side * 0.5, 0.0, room_z + 0.6), Vector2(1.0, 0.9))


# Belirgin, asiri kanli "mezbaha" odasi — bicak burada bulunur.
func _furnish_carnage_room(room_name: String, room_x: float, room_z: float, side: int) -> void:
	var rs := PATIENT_ROOM_SIZE
	# Mattress'i kana bula
	_add_solid_box(room_name + "BloodyMattress", Vector3(room_x + side * (rs.x * 0.5 - 0.6), 0.64, room_z - 0.4), Vector3(0.86, 0.06, 1.86), Color(0.32, 0.05, 0.05))

	# Zemini birden cok kan birikintisiyle kapla
	_add_blood_decal(room_name + "Pool1", Vector3(room_x, 0.0, room_z), Vector2(2.6, 2.4))
	_add_blood_decal(room_name + "Pool2", Vector3(room_x - side * 0.9, 0.0, room_z + 1.0), Vector2(1.6, 1.5))
	_add_blood_decal(room_name + "Pool3", Vector3(room_x + side * 0.7, 0.0, room_z - 1.0), Vector2(1.4, 1.3))
	# Kapidan odaya uzanan, surukleme izi gibi kan — girisi belli etsin
	_add_blood_decal(room_name + "Drag", Vector3(room_x - side * 1.4, 0.0, room_z), Vector2(1.0, 1.2))

	# Duvarda kan sicramasi (dikey decal — far duvar)
	_add_wall_blood(room_name + "WallSplat", Vector3(room_x + side * (rs.x * 0.5 - wt_eps()), 1.4, room_z - 0.5), Vector2(1.6, 1.8), side)

	# Devrilmis tekerlekli sehpa (kanli alet masasi)
	_add_solid_box(room_name + "CartTop", Vector3(room_x - side * 0.8, 0.5, room_z + 0.9), Vector3(0.9, 0.08, 0.6), Color(0.5, 0.1, 0.1), PsxSurfaceTextures.Surface.METAL)
	_add_solid_box(room_name + "CartLeg1", Vector3(room_x - side * 0.55, 0.25, room_z + 0.7), Vector3(0.06, 0.5, 0.06), Color(0.3, 0.32, 0.34), PsxSurfaceTextures.Surface.METAL)
	_add_solid_box(room_name + "CartLeg2", Vector3(room_x - side * 1.05, 0.25, room_z + 1.1), Vector3(0.06, 0.5, 0.06), Color(0.3, 0.32, 0.34), PsxSurfaceTextures.Surface.METAL)

	# Kirmizimsi, alcak bir oda isigi — kanli atmosfer
	var glow := OmniLight3D.new()
	glow.name = room_name + "GoreGlow"
	glow.position = Vector3(room_x, 1.9, room_z)
	glow.light_color = Color(0.85, 0.22, 0.18)
	glow.light_energy = 1.3
	glow.omni_range = 4.2
	glow.add_to_group(GENERATED_GROUP)
	add_child(glow)


# Dikey duvar kan decal'i (far duvarin ic yuzune yapisik)
func _add_wall_blood(node_name: String, pos: Vector3, plane_size: Vector2, side: int) -> void:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	# Far duvar x+side yonunde; decal duvarin biraz icinde, odaya bakar
	mi.position = pos - Vector3(side * 0.02, 0.0, 0.0)
	mi.add_to_group(GENERATED_GROUP)
	var plane := PlaneMesh.new()
	plane.size = plane_size
	plane.orientation = PlaneMesh.FACE_X
	mi.mesh = plane
	# Decal odaya (-side) baksin
	if side > 0:
		mi.rotation_degrees = Vector3(0, 180, 0)
	mi.material_override = PsxMaterialHelper.create_transparent_textured_material(
		PsxSurfaceTextures.BLOOD_PATH, BLOOD_COLOR, Vector3.ONE
	)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func wt_eps() -> float:
	return WALL_THICK * 0.5 + 0.03


func _y_on_surface(surface_top: float, prop_height: float) -> float:
	return surface_top + prop_height * 0.5 + PROP_SURFACE_EPS


func _bed_x(room_x: float, side: int) -> float:
	return room_x + float(side) * (PATIENT_ROOM_SIZE.x * 0.5 - 0.6)


func _seal_patient_room_junction(room_name: String, room_x: float, room_z: float, side: int) -> void:
	var h := PATIENT_ROOM_SIZE.y
	var wt := WALL_THICK
	var door_w := 1.4
	var join_x := side * (CORRIDOR_WIDTH * 0.5 + wt * 0.5)
	var join_w := wt + 0.2

	_add_wall_box(room_name + "JambN", Vector3(join_x, h * 0.5, room_z - door_w * 0.5), Vector3(join_w, h, wt), WALL_COLOR)
	_add_wall_box(room_name + "JambS", Vector3(join_x, h * 0.5, room_z + door_w * 0.5), Vector3(join_w, h, wt), WALL_COLOR)
	_add_floor_box(room_name + "FloorJoin", Vector3(join_x, -wt * 0.5, room_z), Vector3(join_w, wt, PATIENT_ROOM_SIZE.z), FLOOR_COLOR * 0.86, true)
	_add_ceil_box(room_name + "CeilJoin", Vector3(join_x, h, room_z), Vector3(join_w, wt, PATIENT_ROOM_SIZE.z), CEILING_COLOR, true)


func _add_corridor_wall_for_room(room_name: String, room_z: float, side: int) -> void:
	var h := PATIENT_ROOM_SIZE.y
	var wt := WALL_THICK
	var wall_x := side * CORRIDOR_WIDTH * 0.5
	var door_w := 1.4

	_add_wall_box(
		room_name + "DoorHeader",
		Vector3(wall_x, h - 0.35, room_z),
		Vector3(wt, 0.7, door_w),
		WALL_COLOR
	)


func _build_reception() -> void:
	# Resepsiyon — L şeklinde ahşap banko + üstte tezgah
	_add_solid_box("ReceptionMain", Vector3(0, 0.5, -1.5), Vector3(3.6, 1.0, 0.7), RECEPTION_COLOR, PsxSurfaceTextures.Surface.WOOD)
	_add_solid_box("ReceptionSide", Vector3(1.5, 0.5, -0.7), Vector3(0.7, 1.0, 1.9), RECEPTION_COLOR * 0.9, PsxSurfaceTextures.Surface.WOOD)
	_add_solid_box("ReceptionTop", Vector3(0, 1.05, -1.5), Vector3(3.85, 0.1, 0.9), RECEPTION_COLOR * 1.15, PsxSurfaceTextures.Surface.WOOD)
	_add_solid_box("ReceptionTopSide", Vector3(1.5, 1.05, -0.7), Vector3(0.9, 0.1, 2.05), RECEPTION_COLOR * 1.15, PsxSurfaceTextures.Surface.WOOD)


# Bölümlerin (lobby/koridor/utility/hasta odası) birleştiği kapı ağızlarındaki
# köşe dikey duvar boşluklarını ve zemin/tavan deliklerini kapatır.
# Odalar ayrı kutular olarak kurulduğundan, her geçişte WALL_THICK kadar boşluk kalıyordu.
func _seal_section_junctions() -> void:
	var h := LOBBY_SIZE.y
	var wt := WALL_THICK
	var cz := _corridor_center_z
	var north_end_z := cz - CORRIDOR_LENGTH * 0.5
	var c := _utility_center

	# A) Lobby ↔ Koridor ağzı — iki köşe söve (jamb)
	var a_z := -LOBBY_SIZE.z * 0.5 - 0.18
	_add_wall_box("JambLobbyCorridorL", Vector3(-CORRIDOR_WIDTH * 0.5, h * 0.5, a_z), Vector3(wt, h, 0.7), WALL_COLOR)
	_add_wall_box("JambLobbyCorridorR", Vector3(CORRIDOR_WIDTH * 0.5, h * 0.5, a_z), Vector3(wt, h, 0.7), WALL_COLOR)

	# B) Koridor ↔ Utility ağzı — söveler + zemin/tavan eşiği
	var util_door_w := 2.2
	var b_z := north_end_z - 0.175
	_add_wall_box("JambCorridorUtilityL", Vector3(-util_door_w * 0.5, h * 0.5, b_z), Vector3(wt, h, 0.7), WALL_COLOR)
	_add_wall_box("JambCorridorUtilityR", Vector3(util_door_w * 0.5, h * 0.5, b_z), Vector3(wt, h, 0.7), WALL_COLOR)
	_add_floor_box("UtilityCorridorThreshold", Vector3(c.x, -wt * 0.5, b_z), Vector3(util_door_w, wt, 0.85), FLOOR_COLOR * 0.86, true)
	_add_ceil_box("UtilityCorridorCeilJoin", Vector3(c.x, h, b_z), Vector3(util_door_w, wt, 0.85), CEILING_COLOR, true)


# z ekseni boyunca uzanan yan duvar — ortasında kapı boşluğu bırakır (sol/sağ segment + üst kiriş)
func _add_wall_z_with_opening(node_name: String, x: float, total_len: float, h: float, wt: float, opening_z: float, opening_w: float, color: Color) -> void:
	var half_len := total_len * 0.5
	var south_start := opening_z + opening_w * 0.5
	var north_end := opening_z - opening_w * 0.5
	var south_len := half_len - south_start
	var north_len := north_end + half_len
	if south_len > 0.05:
		_add_wall_box(node_name + "_S", Vector3(x, h * 0.5, south_start + south_len * 0.5), Vector3(wt, h, south_len), color)
	if north_len > 0.05:
		_add_wall_box(node_name + "_N", Vector3(x, h * 0.5, -half_len + north_len * 0.5), Vector3(wt, h, north_len), color)
	_add_wall_box(node_name + "_H", Vector3(x, h - 0.35, opening_z), Vector3(wt, 0.7, opening_w), color)


# Kapı boşluğunun arkasını kapatan karanlık panel — void görünmesin
func _add_door_recess(node_name: String, x: float, z: float, opening_w: float, h: float, inward: float) -> void:
	_add_solid_box(node_name + "Back", Vector3(x + inward, (h - 0.7) * 0.5, z), Vector3(0.12, h - 0.7, opening_w + 0.1), Color(0.02, 0.02, 0.03))


# Yan duvardaki kapı boşluğuna iç yüzden gömme kapı kasası (iki dikme + lento)
func _add_door_frame(node_name: String, wall_x: float, z: float, opening_w: float, h: float, surface: int) -> void:
	var s := signf(wall_x)
	var ix := wall_x - s * 0.1
	var oh := h - 0.7
	_add_solid_box(node_name + "PostA", Vector3(ix, oh * 0.5, z - opening_w * 0.5 - 0.06), Vector3(0.14, oh + 0.1, 0.12), TRIM_COLOR, surface)
	_add_solid_box(node_name + "PostB", Vector3(ix, oh * 0.5, z + opening_w * 0.5 + 0.06), Vector3(0.14, oh + 0.1, 0.12), TRIM_COLOR, surface)
	_add_solid_box(node_name + "Lintel", Vector3(ix, oh + 0.05, z), Vector3(0.14, 0.14, opening_w + 0.24), TRIM_COLOR, surface)


func _build_mist_windows() -> void:
	var half_z := LOBBY_SIZE.z * 0.5
	var placements := [
		Vector3(-1.2, 1.4, half_z - 0.05),
		Vector3(1.2, 1.4, half_z - 0.05),
		Vector3(0.0, 2.1, half_z - 0.05),
	]
	for i in placements.size():
		_add_mist_plane("MistWindow%d" % i, placements[i], Vector2(1.6, 1.8))


func _build_lights() -> void:
	var cz := _corridor_center_z
	_add_power_light("CorridorLightSouth", Vector3(0, 2.6, cz + 7.0), 0.4, 9.0, Color(0.9, 0.82, 0.65))
	_add_power_light("CorridorLightMid", Vector3(0, 2.6, cz), 0.45, 10.0, Color(0.9, 0.82, 0.65))
	_add_power_light("CorridorLightNorth", Vector3(0, 2.6, cz - 7.0), 0.38, 9.0, Color(0.88, 0.8, 0.62))
	_add_power_light("UtilityLight", _utility_center + Vector3(0, 2.5, 0), 0.5, 7.0, Color(0.92, 0.86, 0.7))
	# Resepsiyon — guc olmasa da loş acil aydinlatma (masa giris noktasindan gorunsun).
	_add_ambient_fill_light("ReceptionFill", Vector3(0, 2.2, -1.5), 0.12, 7.0, Color(0.55, 0.50, 0.42))


func _add_power_light(node_name: String, pos: Vector3, energy: float, range: float, color: Color) -> void:
	var light := OmniLight3D.new()
	light.name = node_name
	light.position = pos
	light.light_energy = energy
	light.omni_range = range
	light.light_color = color
	light.set_meta("power_energy", energy)
	light.add_to_group(GENERATED_GROUP)
	add_child(light)
	_power_lights.append(light)


func _add_ambient_fill_light(node_name: String, pos: Vector3, energy: float, range: float, color: Color) -> void:
	var light := OmniLight3D.new()
	light.name = node_name
	light.position = pos
	light.light_energy = energy
	light.omni_range = range
	light.light_color = color
	light.add_to_group(GENERATED_GROUP)
	add_child(light)


func _build_interactables() -> void:
	var cz := _corridor_center_z
	var wt := WALL_THICK

	_add_note_interactable(
		"ReceptionNote",
		Vector3(-0.6, _y_on_surface(RECEPTION_DESK_TOP, 0.05), -1.5),
		Vector3(0.5, 0.05, 0.35),
		Color(0.85, 0.82, 0.72),
		"Reception Log",
		"BLACKOUT — 03:14\n\nGenerator fuse blown in utility closet.\nReplace fuse at LOBBY BREAKER (west wall) before anything else.\n\n— Facilities",
		"lore_major"
	)
	_add_inner_voice_zone(
		"ReceptionSafeZone",
		Vector3(0, 1.2, -2.2),
		Vector3(4.0, 2.4, 3.0),
		"safe_zone"
	)

	# --- Hasta odası notları (The Mist esintili hastane hikayesi) ---
	# Notlar yatağın mattress üstünde — _y_on_surface ile oturtulur.
	# Room A — sag, z_offset=8.0 (girise en yakin KANLI mezbaha odasi)
	var roomA_x := CORRIDOR_WIDTH * 0.5 + PATIENT_ROOM_SIZE.x * 0.5 + wt
	var roomA_z := cz + 8.0
	var bedA_x := _bed_x(roomA_x, 1)
	_add_note_interactable(
		"NoteRoomA",
		Vector3(bedA_x - 0.15, _y_on_surface(BED_MATTRESS_TOP_BLOODY, 0.04), roomA_z - 0.15),
		Vector3(0.35, 0.04, 0.25),
		Color(0.82, 0.78, 0.68),
		"Triage Tag — Bed 1",
		"They dragged three of them in here at once.\nNo room left, so we worked on the floor.\n\nThe restraints didn't hold. None of them did.\nWe stopped calling it surgery after the second night.\n\nIf you're reading this and the lights are on —\ntake the blade off the tray. You'll need it\nlong before you find a gun.\n\n— N. Bradley, RN",
		"lore_major"
	)

	# Room E — sag, z_offset=-3.0 (fuse odasi)
	var roomB_x := CORRIDOR_WIDTH * 0.5 + PATIENT_ROOM_SIZE.x * 0.5 + wt
	var roomB_z := cz + (-3.0)
	var bedB_x := _bed_x(roomB_x, 1)
	_add_note_interactable(
		"NoteRoomB",
		Vector3(bedB_x - 0.2, _y_on_surface(BED_MATTRESS_TOP, 0.04), roomB_z - 0.55),
		Vector3(0.3, 0.04, 0.22),
		Color(0.75, 0.72, 0.62),
		"Torn Journal Page",
		"Day 4 after the mist rolled in.\n\nThey locked the doors 'for our safety.' The radios\nplay static. Phones dead. Generators failing.\n\nSomething moves in the fog outside the windows.\nIt presses against the glass.\nNot hands. Something else.\n\nNurse Bradley didn't come back from the supply run.\nWe heard her screaming for two minutes.\nThen nothing.",
		"memory_glitch"
	)

	# Room C — sag, z_offset=2.5 (ammo odasi)
	var roomC_x := CORRIDOR_WIDTH * 0.5 + PATIENT_ROOM_SIZE.x * 0.5 + wt
	var roomC_z := cz + 2.5
	var bedC_x := _bed_x(roomC_x, 1)
	_add_note_interactable(
		"NoteRoomC",
		Vector3(bedC_x - 0.15, _y_on_surface(BED_MATTRESS_TOP, 0.04), roomC_z - 0.35),
		Vector3(0.32, 0.04, 0.24),
		Color(0.8, 0.76, 0.66),
		"Doctor's Memo — URGENT",
		"TO ALL STAFF:\n\nDo NOT attempt to leave the building.\nThe mist is not weather. Repeat: NOT weather.\n\nPatients on Floor 3 have begun... changing.\nSymptoms: dilated pupils, skin discoloration,\naggression toward light sources.\n\nQuarantine Floor 3 immediately.\n\nIf they won't stay in their rooms—\nGod help us, just run.\n\n— Dr. Harrison Marsh",
		"lore_major"
	)

	# Room D — sol, z_offset=2.5 (herb odasi)
	var roomD_x := -(CORRIDOR_WIDTH * 0.5 + PATIENT_ROOM_SIZE.x * 0.5 + wt)
	var roomD_z := cz + 2.5
	var bedD_x := _bed_x(roomD_x, -1)
	_add_note_interactable(
		"NoteRoomD",
		Vector3(bedD_x + 0.15, _y_on_surface(BED_MATTRESS_TOP, 0.04), roomD_z - 0.25),
		Vector3(0.28, 0.04, 0.2),
		Color(0.72, 0.68, 0.58),
		"Scrawled Note (barely legible)",
		"it comes when the lights die\nit comes when you stop looking\nit ALREADY came\n\ni remember now — i was patient 312\ni checked in for insomnia\ni never checked out\n\nthe mist didn't bring them\nthe mist IS them\n\ndon't take the fuse\ndon't wake it up\n\n(please god don't let me be one of them)",
		"memory_glitch"
	)

	# Utility oda notu — sigorta dolabinin ön yüzüne yapışık sticker
	var util_cab_y := 1.1 + 0.9 * 0.55
	_add_note_interactable(
		"UtilityNote",
		_utility_center + Vector3(-1.2, util_cab_y, -UTILITY_SIZE.z * 0.5 + WALL_THICK * 0.5 + 0.44),
		Vector3(0.4, 0.05, 0.3),
		Color(0.82, 0.78, 0.65),
		"Maintenance Sticker",
		"SPARE FUSES — CABINET LEFT\n\nIf lobby is dark, check here first.",
		""
	)

	_add_fuse_panel(
		"LobbyBreakerPanel",
		Vector3(-LOBBY_SIZE.x * 0.5 + WALL_THICK * 0.5 + 0.09, 1.25, 0.0),
		Vector3(0.18, 0.55, 0.45),
		Color(0.42, 0.40, 0.36),
		PsxSurfaceTextures.Surface.METAL
	)
	_add_elevator_panel(
		"ElevatorPanel",
		Vector3(LOBBY_SIZE.x * 0.5 - WALL_THICK * 0.5 - 0.16, 1.2, -2.3),
		Vector3(0.12, 0.4, 0.3),
		Color(0.55, 0.50, 0.20),
		PsxSurfaceTextures.Surface.METAL
	)
	# Bodrum kapısı
	var bx := -LOBBY_SIZE.x * 0.5
	_add_door_frame("BasementFrame", bx, BASEMENT_DOOR_Z, DOOR_OPENING_W, LOBBY_SIZE.y, PsxSurfaceTextures.Surface.METAL)
	_add_door_recess("BasementRecess", bx + 0.05, BASEMENT_DOOR_Z, DOOR_OPENING_W, LOBBY_SIZE.y, -0.25)
	_add_locked_door(
		"BasementDoor",
		Vector3(bx + 0.05, 1.3, BASEMENT_DOOR_Z),
		Vector3(0.16, 2.6, DOOR_OPENING_W + 0.18),
		Color(0.40, 0.38, 0.35),
		PsxSurfaceTextures.Surface.DOOR
	)
	# EXIT kapısı
	var ex := LOBBY_SIZE.x * 0.5
	_add_door_frame("ExitFrame", ex, EXIT_DOOR_Z, EXIT_OPENING_W, LOBBY_SIZE.y, PsxSurfaceTextures.Surface.METAL)
	_add_door_recess("ExitRecess", ex - 0.05, EXIT_DOOR_Z, EXIT_OPENING_W, LOBBY_SIZE.y, 0.25)
	_add_exit_door(
		"ExitDoor",
		Vector3(ex - 0.05, 1.3, EXIT_DOOR_Z),
		Vector3(0.16, 2.6, EXIT_OPENING_W + 0.18)
	)


func _build_pickups() -> void:
	var cz := _corridor_center_z
	var wt := WALL_THICK
	var room_x_off := CORRIDOR_WIDTH * 0.5 + PATIENT_ROOM_SIZE.x * 0.5 + wt

	# Bicak — Room A (girise en yakin sag oda): kanli alet sehpasinin ustunde
	var knife_room_x := room_x_off
	var knife_room_z := cz + 8.0
	# Bıçak alet masasının (CartTop) üstünde — ayrı stand gerekmez
	_add_pickup(
		"PickupKnife",
		"knife",
		1,
		Vector3(knife_room_x - 0.8, _y_on_surface(CART_TOP, 0.16), knife_room_z + 0.9),
		Vector3(0.4, 0.16, 0.24),
		Color(0.5, 0.52, 0.56)
	)
	_add_pickup_spotlight("KnifeSpot", Vector3(knife_room_x - 0.8, 1.4, knife_room_z + 0.9), Color(0.95, 0.55, 0.5), 2.2, 2.2)

	# Flashlight — resepsiyon bankosunun ustunde (oyuncunun ilk hedefi)
	_add_pickup(
		"PickupFlashlight",
		"flashlight",
		1,
		Vector3(0.15, _y_on_surface(RECEPTION_DESK_TOP, 0.14), -1.35),
		Vector3(0.32, 0.14, 0.14),
		Color(0.75, 0.78, 0.4)
	)
	_add_pickup_spotlight("FlashlightSpot", Vector3(0.15, 1.75, -1.35), Color(0.9, 0.92, 0.55), 2.6, 2.4)

	# Silah — Room G (sag, z_offset=-8.5): koridorun kuzey ucuna yakin, gec bulunan oda
	var pistol_room_x := room_x_off
	var pistol_room_z := cz + (-8.5)
	var pistol_bed_x := _bed_x(pistol_room_x, 1)
	_add_pickup(
		"PickupPistol",
		"pistol",
		1,
		Vector3(pistol_bed_x - 0.1, _y_on_surface(BED_MATTRESS_TOP, 0.2), pistol_room_z - 0.35),
		Vector3(0.42, 0.2, 0.26),
		Color(0.55, 0.58, 0.66)
	)
	_add_pickup_spotlight("PistolSpot", Vector3(pistol_bed_x - 0.1, 1.6, pistol_room_z - 0.35), Color(0.75, 0.82, 1.0), 2.4, 2.2)

	# Fuse — Room E (sag, z_offset=-3.0) yatak üstünde, notun yanında
	var fuse_room_x := room_x_off
	var fuse_room_z := cz - 3.0
	var fuse_bed_x := _bed_x(fuse_room_x, 1)
	var fuse_size := Vector3(0.2, 0.06, 0.1)
	_add_pickup(
		"PickupFuse",
		"generator_fuse",
		1,
		Vector3(fuse_bed_x + 0.15, _y_on_surface(BED_MATTRESS_TOP, fuse_size.y), fuse_room_z - 0.25),
		fuse_size,
		Color(0.82, 0.72, 0.35)
	)

	# Ammo — Room C (sag, z_offset=2.5) zeminde
	var ammoA_x := room_x_off
	var ammoA_z := cz + 2.5
	_add_pickup(
		"PickupAmmoRoomA",
		"pistol_ammo",
		6,
		Vector3(ammoA_x - 0.8, _y_on_surface(FLOOR_TOP, 0.15), ammoA_z + 0.5),
		Vector3(0.22, 0.15, 0.18),
		Color(0.8, 0.75, 0.2)
	)

	# Herb — Room D (sol, z_offset=2.5) icinde
	var herb_room_x := -room_x_off
	var herb_room_z := cz + 2.5
	_add_pickup(
		"PickupHerb",
		"green_herb",
		1,
		Vector3(herb_room_x + 0.5, _y_on_surface(FLOOR_TOP, 0.28), herb_room_z + 0.8),
		Vector3(0.28, 0.28, 0.28),
		Color(0.2, 0.75, 0.3)
	)

	# Ammo — utility room tezgah üstünde
	_add_pickup(
		"PickupAmmo",
		"pistol_ammo",
		4,
		_utility_center + Vector3(1.8, _y_on_surface(WORKBENCH_TOP, 0.18), 0.3),
		Vector3(0.22, 0.18, 0.22),
		Color(0.8, 0.75, 0.2)
	)


# Pickup uzerine kucuk yonlendirme spot isigi
func _add_pickup_spotlight(node_name: String, pos: Vector3, color: Color, energy: float, light_range: float) -> void:
	var light := OmniLight3D.new()
	light.name = node_name
	light.position = pos
	light.light_color = color
	light.light_energy = energy
	light.omni_range = light_range
	light.add_to_group(GENERATED_GROUP)
	add_child(light)


func _build_enemies() -> void:
	pass


var _fuse_pickup_creature_spawned: bool = false
var _fuse_install_creature_spawned: bool = false


func _on_item_picked_up(item: Item, _slot_index: int, _count: int) -> void:
	if item == null:
		return
	if item.id == "flashlight":
		InnerVoiceManager.trigger("found_flashlight")
		return
	if item.id == "pistol":
		InnerVoiceManager.trigger("found_weapon")
		return
	if item.id != "generator_fuse":
		return
	if _fuse_pickup_creature_spawned or QuestManager.fuse_pickup_creature_done:
		return
	_fuse_pickup_creature_spawned = true
	QuestManager.mark_fuse_pickup_creature_done()
	InnerVoiceManager.trigger("first_enemy")
	call_deferred("spawn_fuse_pickup_creature")


# Fuse alındığında — koridorun karanlık ucundan tek zombi + jumpscare.
func spawn_fuse_pickup_creature() -> void:
	if Engine.is_editor_hint():
		return
	var enemy_scene: PackedScene = load("res://scenes/enemies/test_enemy.tscn")
	var enemy: EnemyAI = enemy_scene.instantiate() as EnemyAI
	enemy.name = "MistCrawler"
	enemy.position = Vector3(0.0, 0.0, _corridor_center_z - CORRIDOR_LENGTH * 0.4)
	enemy.detection_range = 24.0
	enemy.patrol_speed = 0.0
	enemy.chase_speed = 6.4
	enemy.attack_damage = 34.0
	enemy.use_contact_damage = true
	enemy.contact_range = 1.15
	enemy.contact_damage_cooldown = 0.65
	enemy.start_state = EnemyAI.State.CHASE
	enemy.add_to_group(GENERATED_GROUP)
	add_child(enemy)

	AudioManager.play("enemy_alert", 2.0)
	AudioManager.play_3d("enemy_growl", enemy.global_position, 0.0, 0.85, 0.95)
	call_deferred("_play_creature_jumpscare", 1.15)

	var tween := create_tween()
	tween.tween_interval(12.0)
	tween.tween_callback(func() -> void:
		if is_instance_valid(enemy):
			AudioManager.play_3d("enemy_death", enemy.global_position, -2.0, 0.8, 0.9)
			enemy.queue_free()
	)


# Fuse takıldığında — resepsiyon masasının arkasından tek zombi belirir.
func spawn_fuse_install_creature() -> void:
	if Engine.is_editor_hint() or _fuse_install_creature_spawned or QuestManager.fuse_ambush_done:
		return
	_fuse_install_creature_spawned = true
	QuestManager.mark_fuse_ambush_done()

	var spawn_pos := FUSE_INSTALL_AMBUSH_SPAWN
	var enemy := _spawn_ambush_enemy("MistCrawlerInstall", spawn_pos)

	var player := get_tree().get_first_node_in_group("player") as CharacterBody3D
	if player:
		var look_target := player.global_position
		look_target.y = enemy.global_position.y
		enemy.look_at(look_target, Vector3.UP)

	_play_creature_jumpscare(1.25)
	AudioManager.play("enemy_alert", 2.0, 0.9, 1.0)
	AudioManager.play_3d("enemy_growl", enemy.global_position, -1.0, 0.85, 0.95)

	var tween := create_tween()
	tween.tween_interval(15.0)
	tween.tween_callback(func() -> void:
		if is_instance_valid(enemy):
			AudioManager.play_3d("enemy_death", enemy.global_position, -2.0, 0.8, 0.9)
			enemy.queue_free()
	)


func _spawn_ambush_enemy(enemy_name: String, spawn_pos: Vector3) -> EnemyAI:
	var enemy_scene: PackedScene = load("res://scenes/enemies/test_enemy.tscn")
	var enemy: EnemyAI = enemy_scene.instantiate() as EnemyAI
	enemy.name = enemy_name
	enemy.position = spawn_pos
	enemy.detection_range = 28.0
	enemy.patrol_speed = 0.0
	enemy.chase_speed = 6.8
	enemy.attack_damage = 34.0
	enemy.use_contact_damage = true
	enemy.contact_range = 1.2
	enemy.contact_damage_cooldown = 0.6
	enemy.start_state = EnemyAI.State.CHASE
	enemy.add_to_group(GENERATED_GROUP)
	add_child(enemy)
	AudioManager.play_3d("enemy_growl", enemy.global_position, -2.0, 0.85, 0.95)
	return enemy


func _play_creature_jumpscare(intensity: float = 1.15) -> void:
	HudManager.play_jumpscare(intensity)
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_method("play_camera_shake"):
		var shake := 0.2 if intensity < 1.3 else 0.32 * intensity
		player.play_camera_shake(shake, 0.45 if intensity < 1.3 else 0.55)


func _add_solid_box(
	node_name: String,
	pos: Vector3,
	box_size: Vector3,
	color: Color,
	surface: int = -1
) -> void:
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
			surface as PsxSurfaceTextures.Surface,
			box_size,
			color
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
	_add_solid_box(
		node_name,
		Vector3(pos.x, pos.y - y_eps, pos.z),
		box_size,
		color,
		PsxSurfaceTextures.Surface.FLOOR
	)


func _add_wall_box(node_name: String, pos: Vector3, box_size: Vector3, color: Color) -> void:
	_add_solid_box(node_name, pos, box_size, color, PsxSurfaceTextures.Surface.WALL)


func _add_ceil_box(node_name: String, pos: Vector3, box_size: Vector3, color: Color, join_layer: bool = false) -> void:
	var y_eps := SURFACE_JOIN_LAYER_EPS if join_layer else SURFACE_JOIN_EPS
	_add_solid_box(
		node_name,
		Vector3(pos.x, pos.y + y_eps, pos.z),
		box_size,
		color,
		PsxSurfaceTextures.Surface.CEILING
	)


func _material_for_box(box_size: Vector3, color: Color, surface: int, double_sided: bool = false) -> Material:
	if surface >= 0:
		return PsxSurfaceTextures.make_prop_surface_material(
			surface as PsxSurfaceTextures.Surface,
			box_size,
			color
		)
	return PsxMaterialHelper.create_material(color, double_sided)


# Zemin kan decal'i — tek yüzlü yatay plane, zeminin hemen üstünde (z-fighting yapmaz)
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


func _add_mist_plane(node_name: String, pos: Vector3, plane_size: Vector2) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = pos
	body.add_to_group(GENERATED_GROUP)

	var mesh_instance := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = plane_size
	plane.orientation = PlaneMesh.FACE_Z
	mesh_instance.mesh = plane
	mesh_instance.material_override = _create_mist_material()

	body.add_child(mesh_instance)
	add_child(body)


func _create_mist_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = MIST_COLOR
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	return mat


func _add_note_interactable(
	node_name: String,
	pos: Vector3,
	box_size: Vector3,
	color: Color,
	title: String,
	body_text: String,
	inner_voice: String = ""
) -> void:
	var node := Node3D.new()
	node.name = node_name
	node.position = pos
	node.add_to_group(GENERATED_GROUP)
	node.set_script(load("res://scripts/interaction/note_placeholder.gd"))
	node.set("note_title", title)
	node.set("note_body", body_text)
	if not inner_voice.is_empty():
		node.set("inner_voice_trigger", inner_voice)

	var body := StaticBody3D.new()
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = box_size
	mesh_instance.mesh = box
	mesh_instance.material_override = PsxMaterialHelper.create_material(color, true)

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = box_size
	collision.shape = shape

	body.add_child(mesh_instance)
	body.add_child(collision)
	node.add_child(body)
	add_child(node)


func _add_inner_voice_zone(
	node_name: String,
	pos: Vector3,
	box_size: Vector3,
	trigger_id: String
) -> void:
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


func _add_fuse_panel(
	node_name: String,
	pos: Vector3,
	box_size: Vector3,
	color: Color,
	surface: int = -1
) -> void:
	var node := Node3D.new()
	node.name = node_name
	node.position = pos
	node.add_to_group(GENERATED_GROUP)
	node.set_script(load("res://scripts/interaction/fuse_panel.gd"))

	var body := StaticBody3D.new()
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = box_size
	mesh_instance.mesh = box
	mesh_instance.material_override = _material_for_box(box_size, color, surface, true)

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = box_size
	collision.shape = shape

	body.add_child(mesh_instance)
	body.add_child(collision)
	node.add_child(body)
	add_child(node)


func _add_elevator_panel(
	node_name: String,
	pos: Vector3,
	box_size: Vector3,
	color: Color,
	surface: int = -1
) -> void:
	var node := Node3D.new()
	node.name = node_name
	node.position = pos
	node.add_to_group(GENERATED_GROUP)
	node.set_script(load("res://scripts/interaction/elevator_panel.gd"))

	var body := StaticBody3D.new()
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = box_size
	mesh_instance.mesh = box
	mesh_instance.material_override = _material_for_box(box_size, color, surface, true)

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = box_size
	collision.shape = shape

	body.add_child(mesh_instance)
	body.add_child(collision)
	node.add_child(body)
	add_child(node)


func _add_locked_door(
	node_name: String,
	pos: Vector3,
	box_size: Vector3,
	color: Color,
	surface: int = -1
) -> void:
	var node := Node3D.new()
	node.name = node_name
	node.position = pos
	node.add_to_group(GENERATED_GROUP)
	node.set_script(load("res://scripts/interaction/locked_door.gd"))

	var body := StaticBody3D.new()
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = box_size
	mesh_instance.mesh = box
	mesh_instance.material_override = _material_for_box(box_size, color, surface, true)

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = box_size
	collision.shape = shape

	body.add_child(mesh_instance)
	body.add_child(collision)
	node.add_child(body)
	add_child(node)


func _add_exit_door(node_name: String, pos: Vector3, box_size: Vector3) -> void:
	var node := Node3D.new()
	node.name = node_name
	node.position = pos
	node.add_to_group(GENERATED_GROUP)
	node.set_script(load("res://scripts/interaction/exit_door.gd"))

	var body := StaticBody3D.new()
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = box_size
	mesh_instance.mesh = box
	mesh_instance.material_override = _material_for_box(box_size, Color(0.6, 0.14, 0.12), PsxSurfaceTextures.Surface.EXIT_DOOR, true)

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = box_size
	collision.shape = shape

	body.add_child(mesh_instance)
	body.add_child(collision)
	node.add_child(body)

	# Acil çıkış feneri — karanlıkta kırmızı işaret olarak çeker (güçten bağımsız).
	var beacon := OmniLight3D.new()
	beacon.name = "ExitBeacon"
	beacon.position = Vector3(-0.6, 0.9, 0)
	beacon.light_color = Color(0.95, 0.16, 0.12)
	beacon.light_energy = 0.6
	beacon.omni_range = 4.0
	node.add_child(beacon)

	add_child(node)


func _add_pickup(
	node_name: String,
	item_id: String,
	count: int,
	pos: Vector3,
	box_size: Vector3,
	color: Color
) -> void:
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

	# Görsel küçük kalsın ama hedeflenmesi kolay olsun diye etkileşim çarpışması büyütülür.
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(
		maxf(box_size.x, 0.6),
		maxf(box_size.y, 0.6),
		maxf(box_size.z, 0.6)
	)
	collision.shape = shape
	collision.position = Vector3(0, maxf(0.0, 0.3 - box_size.y * 0.5), 0)

	body.add_child(mesh_instance)
	body.add_child(collision)
	pickup.add_child(body)
	add_child(pickup)
