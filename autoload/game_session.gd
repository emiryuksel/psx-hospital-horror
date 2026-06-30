# Oturum bayrakları — NEW GAME intro, input kilidi durumu.
extends Node

signal intro_completed

var pending_new_game_intro: bool = false
var intro_pending: bool = false
var intro_active: bool = false


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


func consume_new_game_intro() -> bool:
	if not pending_new_game_intro:
		return false
	pending_new_game_intro = false
	return true


func finish_intro() -> void:
	intro_pending = false
	intro_active = false
	intro_completed.emit()
