# Oyun açılışında ana menüden önce — yapımcı kartı.
extends Control

const MAIN_MENU_SCENE := "res://scenes/ui/main_menu.tscn"

@onready var _credits: VBoxContainer = $Center/CreditsVBox
@onready var _fade_layer: ColorRect = $FadeLayer

var _skippable: bool = false
var _finished: bool = false


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_credits.modulate.a = 0.0
	_fade_layer.color.a = 1.0
	await get_tree().process_frame
	await _run_splash()


func _run_splash() -> void:
	var black_out := create_tween()
	black_out.set_ease(Tween.EASE_OUT)
	black_out.set_trans(Tween.TRANS_SINE)
	black_out.tween_property(_fade_layer, "color:a", 0.0, 0.8)
	await black_out.finished

	var fade_in := create_tween()
	fade_in.set_ease(Tween.EASE_OUT)
	fade_in.set_trans(Tween.TRANS_SINE)
	fade_in.tween_property(_credits, "modulate:a", 1.0, 1.1)
	await fade_in.finished

	_skippable = true
	await get_tree().create_timer(2.8).timeout
	if not _finished:
		await _exit_to_menu()


func _exit_to_menu() -> void:
	if _finished:
		return
	_finished = true
	_skippable = false

	var fade_out := create_tween()
	fade_out.set_ease(Tween.EASE_IN)
	fade_out.set_trans(Tween.TRANS_SINE)
	fade_out.parallel().tween_property(_credits, "modulate:a", 0.0, 0.9)
	fade_out.parallel().tween_property(_fade_layer, "color:a", 1.0, 0.9)
	await fade_out.finished
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func _unhandled_input(event: InputEvent) -> void:
	if not _skippable or _finished:
		return
	if event is InputEventMouseButton and event.pressed:
		_exit_to_menu()
		get_viewport().set_input_as_handled()
	elif event.is_pressed() and not event.is_echo:
		_exit_to_menu()
		get_viewport().set_input_as_handled()
