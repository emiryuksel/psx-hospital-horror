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


func request_load() -> bool:
	GameSession.cancel_new_game_request()
	return _read_save_into_pending()


func consume_load_request() -> bool:
	if _load_requested:
		_load_requested = false
		return true
	return false


func prepare_new_game() -> void:
	_pending_load.clear()
	_load_requested = false


func save_game() -> bool:
	var player := _find_player()
	if player and player.has_method("is_dead") and player.is_dead():
		_show_message("Cannot save while dead")
		save_completed.emit(false)
		return false

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

	if not _read_save_into_pending():
		_show_message("Load failed")
		load_completed.emit(false)
		return false

	call_deferred("_reload_current_scene")
	load_completed.emit(true)
	return true


func _read_save_into_pending() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return false

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return false

	_pending_load = parsed as Dictionary
	_load_requested = true
	# Kaydedilen aktif level'i GameSession'a bildir — reload sonrası doğru level yüklenir.
	var saved_level: String = str(_pending_load.get("level", GameSession.PART1_SCENE))
	if not saved_level.is_empty():
		GameSession.active_level_path = saved_level
	return true


# Pending load'daki level, main.tscn'in gömülü default'undan (Part 1) farklı mı?
func pending_level_needs_swap() -> bool:
	if _pending_load.is_empty():
		return false
	var saved_level: String = str(_pending_load.get("level", GameSession.PART1_SCENE))
	return saved_level != GameSession.PART1_SCENE and not saved_level.is_empty()


func pending_level_path() -> String:
	return str(_pending_load.get("level", GameSession.PART1_SCENE))


func _reload_current_scene() -> void:
	get_tree().reload_current_scene()


func has_pending_load() -> bool:
	return not _pending_load.is_empty()


func try_apply_to_current_scene() -> bool:
	if _pending_load.is_empty():
		return false
	if _find_player() == null:
		return false
	apply_to_current_scene()
	return true


func apply_to_current_scene() -> void:
	if _pending_load.is_empty():
		return

	var data := _pending_load
	_pending_load = {}
	_load_requested = false

	if data.get("version", 0) != SAVE_VERSION:
		push_warning("SaveManager: farklı save versiyonu, kısmi yükleme deneniyor.")

	InventoryManager.close_inventory()
	HudManager.hide_game_over()
	AudioManager.stop_heartbeat()

	var player_data: Dictionary = _sanitize_player_load_data(data.get("player", {}))
	_apply_player_state(player_data)
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
		"level": GameSession.active_level_path,
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


func _sanitize_player_load_data(data: Dictionary) -> Dictionary:
	if data.is_empty():
		return data

	var out := data.duplicate()
	out["is_dead"] = false
	var max_h := float(out.get("max_health", 100.0))
	var health := float(out.get("health", max_h))
	if health <= 0.0:
		health = max_h
	out["health"] = health
	out["max_health"] = max_h
	var max_s := float(out.get("max_stamina", 50.0))
	out["stamina"] = clampf(float(out.get("stamina", max_s)), 0.0, max_s)
	out["max_stamina"] = max_s
	return out


func _find_player() -> CharacterBody3D:
	var vp := get_tree().root.find_child("GameViewport", true, false) as SubViewport
	if vp:
		for node in vp.find_children("*", "CharacterBody3D", true, false):
			if node.is_in_group("player"):
				return node as CharacterBody3D

	for node in get_tree().get_nodes_in_group("player"):
		if node is CharacterBody3D:
			return node
	return null


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
