# Merkezi ses yoneticisi — SFX havuzu, 3D konumlu sesler, ambient/loop ve global sinyal baglari.
extends Node

const SFX_DIR := "res://assets/audio/sfx/"
const AMB_DIR := "res://assets/audio/ambient/"

const POOL_SIZE := 16
const FOOTSTEPS := ["footstep_a", "footstep_b", "footstep_c", "footstep_d"]

var _streams: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _pool_index: int = 0
var _ambient: AudioStreamPlayer
var _heart: AudioStreamPlayer
var _rng := RandomNumberGenerator.new()
var _heart_active: bool = false


func _ready() -> void:
	_rng.randomize()
	_ensure_buses()

	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)

	_ambient = AudioStreamPlayer.new()
	_ambient.bus = "Ambient"
	add_child(_ambient)

	_heart = AudioStreamPlayer.new()
	_heart.bus = "SFX"
	add_child(_heart)

	_connect_signals()


func _ensure_buses() -> void:
	for bus_name in ["SFX", "Ambient", "Voice"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")


func _connect_signals() -> void:
	InventoryManager.item_added.connect(_on_item_added)
	InventoryManager.note_requested.connect(_on_note_requested)
	InventoryManager.inventory_toggled.connect(_on_inventory_toggled)
	InventoryManager.heal_requested.connect(_on_heal_requested)
	InventoryManager.combine_succeeded.connect(_on_combine_succeeded)
	QuestManager.power_restored.connect(_on_power_restored)


# ---------------- Public API ----------------

func play(sound_name: String, volume_db: float = 0.0, pitch_min: float = 1.0, pitch_max: float = 1.0) -> void:
	var s := _get_stream(sound_name)
	if s == null:
		return
	var p := _pool[_pool_index]
	_pool_index = (_pool_index + 1) % POOL_SIZE
	p.stream = s
	p.volume_db = volume_db
	p.pitch_scale = _rng.randf_range(pitch_min, pitch_max)
	p.play()


func play_varied(names: Array, volume_db: float = 0.0, pitch_min: float = 0.95, pitch_max: float = 1.05) -> void:
	if names.is_empty():
		return
	play(names[_rng.randi() % names.size()], volume_db, pitch_min, pitch_max)


func play_chapter_sting() -> void:
	# Bolum basligi — sabit pitch, tam guc (kalin nota).
	play("chapter_sting", 1.0, 1.0, 1.0)


func play_menu_sting() -> void:
	# Ana menu acilis — temiz kalin synth, sabit pitch.
	play("menu_sting", -1.0, 1.0, 1.0)


func play_pickup(volume_db: float = -2.0) -> void:
	# Esya alma — kalin nota, sabit pitch.
	play("pickup", volume_db, 1.0, 1.0)


func play_3d(sound_name: String, pos: Vector3, volume_db: float = 0.0, pitch_min: float = 1.0, pitch_max: float = 1.0, max_dist: float = 24.0) -> void:
	var s := _get_stream(sound_name)
	if s == null:
		return
	var root := get_tree().current_scene
	if root == null:
		return
	var p := AudioStreamPlayer3D.new()
	p.bus = "SFX"
	p.stream = s
	p.volume_db = volume_db
	p.pitch_scale = _rng.randf_range(pitch_min, pitch_max)
	p.max_distance = max_dist
	p.unit_size = 4.0
	p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	root.add_child(p)
	p.global_position = pos
	p.play()
	p.finished.connect(p.queue_free)


func footstep(running: bool = false) -> void:
	var vol := -3.0 if running else -7.0
	play_varied(FOOTSTEPS, vol, 0.9, 1.1)


func start_ambient(sound_name: String = "ambient_drone", volume_db: float = -14.0) -> void:
	var s := _get_stream(sound_name)
	if s == null:
		return
	_apply_loop(s)
	_ambient.stream = s
	_ambient.volume_db = volume_db
	_ambient.play()


func stop_ambient() -> void:
	_ambient.stop()


func start_heartbeat() -> void:
	if _heart_active:
		return
	var s := _get_stream("heartbeat")
	if s == null:
		return
	_apply_loop(s)
	_heart.stream = s
	_heart.volume_db = -4.0
	_heart.play()
	_heart_active = true


func stop_heartbeat() -> void:
	if not _heart_active:
		return
	_heart.stop()
	_heart_active = false


# ---------------- Internal ----------------

func _get_stream(sound_name: String) -> AudioStream:
	if _streams.has(sound_name):
		return _streams[sound_name]
	var path := SFX_DIR + sound_name + ".wav"
	if not ResourceLoader.exists(path):
		path = AMB_DIR + sound_name + ".wav"
	var s: AudioStream = null
	if ResourceLoader.exists(path):
		s = load(path)
	else:
		push_warning("AudioManager: ses bulunamadi '%s'" % sound_name)
	_streams[sound_name] = s
	return s


func _apply_loop(s: AudioStream) -> void:
	if s is AudioStreamWAV:
		var w := s as AudioStreamWAV
		if w.loop_mode == AudioStreamWAV.LOOP_DISABLED:
			w.loop_mode = AudioStreamWAV.LOOP_FORWARD
			w.loop_begin = 0
			w.loop_end = int(w.data.size() / 2)


# ---------------- Signal handlers ----------------

func _on_item_added(_item: Item, _slot_index: int, _count: int) -> void:
	play_pickup()


func _on_note_requested(_text: String, _title: String) -> void:
	play("ui_paper", -5.0, 0.98, 1.02)


func _on_inventory_toggled(is_open: bool) -> void:
	if is_open:
		play("ui_open", -6.0)
	else:
		play("ui_close", -6.0)


func _on_heal_requested(_amount: float) -> void:
	play("heal", -3.0)


func _on_combine_succeeded(_result_item: Item) -> void:
	play_pickup()


func _on_power_restored() -> void:
	play("power_on", -3.0)
