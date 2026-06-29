# Oturum bayrakları — NEW GAME intro, input kilidi durumu.
extends Node

signal intro_completed

var pending_new_game_intro: bool = false
var intro_pending: bool = false
var intro_active: bool = false


func request_new_game_intro() -> void:
	pending_new_game_intro = true
	intro_pending = true


func consume_new_game_intro() -> bool:
	if not pending_new_game_intro:
		return false
	pending_new_game_intro = false
	return true


func finish_intro() -> void:
	intro_pending = false
	intro_active = false
	intro_completed.emit()
