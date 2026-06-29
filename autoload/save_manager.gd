# Kayıt/yükleme yöneticisi — JSON dosyasına oyun durumu yazar/okur.
extends Node

signal save_completed(success: bool)
signal load_completed(success: bool)

const SAVE_PATH := "user://savegame.json"
const SAVE_VERSION := 1

var _pending_load: Dictionary = {}
var _load_requested: bool = false


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func request_load() -> void:
	_load_requested = true


func consume_load_request() -> bool:
	if _load_requested:
		_load_requested = false
		return true
	return false


func save_game() -> bool:
	var data := _collect_save_data()
	var json := JSON.stringify(data, "\t")
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		_show_message("Save failed")
		save_completed.emit(false)
		return false

	file.store_string(json)
	file.close()

	if not FileAccess.file_exists(SAVE_PATH):
		_show_message("Save failed")
		save_completed.emit(false)
		return false

	_show_message("Game saved")
	AudioManager.play_pickup(-6.0)
	save_completed.emit(true)
	return true


func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		_show_message("No save file")
		load_completed.emit(false)
		return false

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		_show_message("Load failed")
		load_completed.emit(false)
		return false

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		_show_message("Corrupt save")
		load_completed.emit(false)
		return false

	_pending_load = parsed as Dictionary
	call_deferred("_reload_current_scene")
	load_completed.emit(true)
	return true


func _reload_current_scene() -> void:
	get_tree().reload_current_scene()


func has_pending_load() -> bool:
	return not _pending_load.is_empty()


func apply_to_current_scene() -> void:
	if _pending_load.is_empty():
		return

	var data := _pending_load
	_pending_load = {}

	if data.get("version", 0) != SAVE_VERSION:
		push_warning("SaveManager: farklı save versiyonu, kısmi yükleme deneniyor.")

	InventoryManager.close_inventory()

	_apply_player_state(data.get("player", {}))
	InventoryManager.import_slots(data.get("inventory", []))
	_apply_combat_state(data.get("combat", {}))
	_apply_flashlight_state(data.get("flashlight", {}))
	InnerVoiceManager.apply_save_data(data.get("inner_voice", {}))
	QuestManager.apply_save_data(data.get("quest", {}))
	_apply_world_state(data.get("world", {}))
	_restore_input_state()
	_show_message("Game loaded")


func _collect_save_data() -> Dictionary:
	var scene_path := ""
	var current_scene := get_tree().current_scene
	if current_scene:
		scene_path = current_scene.scene_file_path

	return {
		"version": SAVE_VERSION,
		"scene": scene_path,
		"timestamp": Time.get_unix_time_from_system(),
		"player": _get_player_state(),
		"inventory": InventoryManager.export_slots(),
		"combat": _get_combat_state(),
		"flashlight": _get_flashlight_state(),
		"inner_voice": InnerVoiceManager.get_save_data(),
		"quest": QuestManager.get_save_data(),
		"world": _collect_world_state(),
	}


func _get_player_state() -> Dictionary:
	var player := _find_player()
	if player == null or not player.has_method("get_save_data"):
		return {}
	return player.get_save_data()


func _get_combat_state() -> Dictionary:
	var combat := _find_combat()
	if combat == null or not combat.has_method("get_save_data"):
		return {}
	return combat.get_save_data()


func _get_flashlight_state() -> Dictionary:
	var flashlight := _find_flashlight()
	if flashlight == null or not flashlight.has_method("get_save_data"):
		return {}
	return flashlight.get_save_data()


func _apply_player_state(data: Dictionary) -> void:
	var player := _find_player()
	if player == null or not player.has_method("apply_save_data"):
		return
	player.apply_save_data(data)


func _apply_combat_state(data: Dictionary) -> void:
	var combat := _find_combat()
	if combat == null or not combat.has_method("apply_save_data"):
		return
	combat.apply_save_data(data)


func _apply_flashlight_state(data: Dictionary) -> void:
	var flashlight := _find_flashlight()
	if flashlight == null or not flashlight.has_method("apply_save_data"):
		return
	flashlight.apply_save_data(data)


func _collect_world_state() -> Dictionary:
	var active_pickups: Array[String] = []
	for pickup in get_tree().get_nodes_in_group("save_pickup"):
		if pickup.has_method("get_save_id"):
			active_pickups.append(pickup.get_save_id())

	var interactables: Dictionary = {}
	for node in get_tree().get_nodes_in_group("save_interactable"):
		if node.has_method("get_save_data"):
			var entry: Dictionary = node.get_save_data()
			interactables[entry.get("save_id", node.name)] = entry

	var enemies: Array = []
	for enemy in get_tree().get_nodes_in_group("save_enemy"):
		if enemy.has_method("get_save_data"):
			enemies.append(enemy.get_save_data())

	return {
		"active_pickups": active_pickups,
		"interactables": interactables,
		"enemies": enemies,
	}


func _apply_world_state(data: Dictionary) -> void:
	var active_pickups: Array = data.get("active_pickups", [])
	for pickup in get_tree().get_nodes_in_group("save_pickup"):
		if not pickup.has_method("get_save_id"):
			continue
		if pickup.get_save_id() in active_pickups:
			continue
		pickup.queue_free()

	var interactables: Dictionary = data.get("interactables", {})
	for node in get_tree().get_nodes_in_group("save_interactable"):
		if not node.has_method("apply_save_data"):
			continue
		var save_id: String = node.get_save_id() if node.has_method("get_save_id") else node.name
		if interactables.has(save_id):
			node.apply_save_data(interactables[save_id])

	var saved_enemies: Array = data.get("enemies", [])
	var saved_by_id: Dictionary = {}
	for entry in saved_enemies:
		if entry is Dictionary:
			saved_by_id[entry.get("save_id", "")] = entry

	for enemy in get_tree().get_nodes_in_group("save_enemy"):
		if not enemy.has_method("apply_save_data"):
			continue
		var save_id: String = enemy.get_save_id() if enemy.has_method("get_save_id") else enemy.name
		if saved_by_id.has(save_id):
			enemy.apply_save_data(saved_by_id[save_id])
		else:
			enemy.queue_free()


func _find_player() -> CharacterBody3D:
	return get_tree().get_first_node_in_group("player") as CharacterBody3D


func _find_combat() -> Node:
	var player := _find_player()
	if player == null:
		return null
	return player.get_node_or_null("CombatComponent")


func _find_flashlight() -> Node:
	var player := _find_player()
	if player == null:
		return null
	return player.get_node_or_null("Head/Flashlight")


func _restore_input_state() -> void:
	var player := _find_player()
	if player and player.has_method("is_dead") and not player.is_dead():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _show_message(text: String) -> void:
	HudManager.show_message(text)
	var timer := get_tree().create_timer(1.8)
	timer.timeout.connect(func() -> void: HudManager.hide_prompt(), CONNECT_ONE_SHOT)
