# Açılışta motor logosu — siyah zeminde Godot logosu fade-in, ~1.5 sn beklet,
# ardından yapımcı kartına (studio_splash) yumuşak geçiş. Flash yapmaz.
extends Control

const NEXT_SCENE := "res://scenes/ui/studio_splash.tscn"

const FADE_IN := 0.7
const HOLD := 1.5
const FADE_OUT := 0.7

@onready var _logo: TextureRect = $Center/Logo
@onready var _fade_layer: ColorRect = $FadeLayer

var _skippable: bool = false
var _finished: bool = false


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_logo.modulate.a = 0.0
	_fade_layer.color.a = 0.0
	await get_tree().process_frame
	await _run()


func _run() -> void:
	var fade_in := create_tween()
	fade_in.set_ease(Tween.EASE_OUT)
	fade_in.set_trans(Tween.TRANS_SINE)
	fade_in.tween_property(_logo, "modulate:a", 1.0, FADE_IN)
	await fade_in.finished

	_skippable = true
	await get_tree().create_timer(HOLD).timeout
	if not _finished:
		await _exit()


func _exit() -> void:
	if _finished:
		return
	_finished = true
	_skippable = false

	var fade_out := create_tween()
	fade_out.set_ease(Tween.EASE_IN)
	fade_out.set_trans(Tween.TRANS_SINE)
	fade_out.parallel().tween_property(_logo, "modulate:a", 0.0, FADE_OUT)
	fade_out.parallel().tween_property(_fade_layer, "color:a", 1.0, FADE_OUT)
	await fade_out.finished
	get_tree().change_scene_to_file(NEXT_SCENE)


func _unhandled_input(event: InputEvent) -> void:
	if not _skippable or _finished:
		return
	var skip := false
	if event is InputEventMouseButton and event.pressed:
		skip = true
	elif event.is_pressed() and not event.is_echo():
		skip = true
	if skip:
		get_viewport().set_input_as_handled()
		_exit()
