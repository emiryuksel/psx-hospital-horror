# Oturum bayrakları — NEW GAME intro, input kilidi durumu, level geçişi.
extends Node

signal intro_completed

const PART1_SCENE := "res://scenes/levels/lobby.tscn"
const PART2_SCENE := "res://scenes/levels/part2_level.tscn"
const MAIN_MENU_SCENE := "res://scenes/ui/main_menu.tscn"
const END_CREDITS_SCENE := "res://scenes/ui/end_credits.tscn"

# MVP: Part 2 bitince credits/thank you kartı göster. Kapatmak için false yap.
var show_end_credits: bool = true

var pending_new_game_intro: bool = false
var intro_pending: bool = false
var intro_active: bool = false

# Aktif level takibi — save/load ve viewport swap için.
# Boşsa main.tscn'in gömülü default level'i (Part 1) geçerlidir.
var active_level_path: String = PART1_SCENE
var _transitioning: bool = false


func request_new_game_intro() -> void:
	cancel_new_game_request()
	pending_new_game_intro = true
	intro_pending = true
	_reset_runtime_state()


func retry_from_death() -> void:
	cancel_new_game_request()
	_reset_runtime_state()
	QuestManager.complete_intro()
	get_tree().call_deferred("reload_current_scene")


func cancel_new_game_request() -> void:
	pending_new_game_intro = false
	intro_pending = false
	intro_active = false


func _reset_runtime_state() -> void:
	SaveManager.prepare_new_game()
	InventoryManager.reset_for_new_game()
	InnerVoiceManager.reset_for_new_game()
	QuestManager.reset_part1()
	HudManager.hide_game_over()
	HudManager.hide_weapon_viewmodel()
	HudManager.set_weapon_acquired(false)
	AudioManager.stop_heartbeat()
	active_level_path = PART1_SCENE
	_transitioning = false


func consume_new_game_intro() -> bool:
	if not pending_new_game_intro:
		return false
	pending_new_game_intro = false
	return true


func finish_intro() -> void:
	intro_pending = false
	intro_active = false
	intro_completed.emit()


# --- Level geçiş altyapısı (viewport child swap) ---
# main.tscn'deki GameViewport altındaki mevcut level'i kaldırıp yeni level.tscn
# instance eder. HUD/pause/dither katmanları main.tscn'de kaldığı için korunur.
func get_game_viewport() -> SubViewport:
	var tree := get_tree()
	if tree == null:
		return null
	return tree.root.find_child("GameViewport", true, false) as SubViewport


func _find_current_level(viewport: SubViewport) -> Node3D:
	if viewport == null:
		return null
	for child in viewport.get_children():
		if child is Node3D:
			return child as Node3D
	return null


# Asansör vb. tarafından çağrılır: fade → level swap → fade-in.
# chapter_title verilirse, level açıldıktan sonra Part I'deki gibi bölüm başlığı
# "slam" efekti gösterilir.
func transition_to_level(scene_path: String, fade_out: float = 1.0, fade_in: float = 1.1, chapter_title: String = "", chapter_subtitle: String = "") -> void:
	if _transitioning:
		return
	_transitioning = true

	# Oyuncu inputunu kilitle ve fade-to-black başlat.
	_set_player_input_locked(true)
	AudioManager.stop_heartbeat()
	HudManager.fade_to_black(fade_out, func() -> void:
		_do_level_swap(scene_path)
		# Yeni level bir frame otursun, sonra aç.
		await get_tree().process_frame
		await get_tree().process_frame
		HudManager.fade_from_black(fade_in, func() -> void:
			if not chapter_title.is_empty():
				await _play_chapter_title(chapter_title, chapter_subtitle)
			_set_player_input_locked(false)
			_transitioning = false
		)
	)


func _play_chapter_title(part_text: String, subtitle_text: String) -> void:
	var intro := _find_game_intro()
	if intro == null or not intro.has_method("play_chapter_only"):
		return
	await intro.play_chapter_only(part_text, subtitle_text)


func _find_game_intro() -> Node:
	var tree := get_tree()
	if tree == null:
		return null
	return tree.root.find_child("GameIntro", true, false)


func _do_level_swap(scene_path: String) -> void:
	var viewport := get_game_viewport()
	if viewport == null:
		push_error("GameSession: GameViewport bulunamadı, level swap iptal.")
		_transitioning = false
		return

	var packed := load(scene_path) as PackedScene
	if packed == null:
		push_error("GameSession: level yüklenemedi: %s" % scene_path)
		_transitioning = false
		return

	var old_level := _find_current_level(viewport)
	if old_level:
		old_level.name = "__old_level"
		old_level.queue_free()
		viewport.remove_child(old_level)

	var new_level := packed.instantiate()
	viewport.add_child(new_level)
	viewport.move_child(new_level, 0)
	active_level_path = scene_path


func _set_player_input_locked(locked: bool) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_method("set_input_locked"):
		player.set_input_locked(locked)


# Part 2 tamamlandıktan sonra çağrılır. Ekran zaten karartılmış olmalı.
# show_end_credits açıksa kayan jenerik sahnesine geçer, kapalıysa direkt menüye döner.
func finish_part2_to_menu() -> void:
	_set_player_input_locked(true)
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	AudioManager.stop_heartbeat()
	_reset_runtime_state()
	if show_end_credits:
		get_tree().change_scene_to_file(END_CREDITS_SCENE)
	else:
		_return_to_main_menu()


func _return_to_main_menu() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
