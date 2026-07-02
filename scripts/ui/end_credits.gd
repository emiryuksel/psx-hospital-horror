# Oyun sonu kayan jeneriği — Part II bittikten sonra ayrı sahne olarak gösterilir.
# Metinler alttan yukarı kayar, biter bitmez karararak ana menüye döner.
extends Control

const MAIN_MENU_SCENE := "res://scenes/ui/main_menu.tscn"

const SCROLL_SPEED := 42.0
const START_PAD := 120.0
const END_PAD := 160.0
const HOLD_AFTER := 1.6

@onready var _scroll_clip: Control = $ScrollClip
@onready var _credits: VBoxContainer = $ScrollClip/CreditsVBox
@onready var _fade_layer: ColorRect = $FadeLayer

var _scrolling: bool = false
var _scroll_y: float = 0.0
var _scroll_end: float = 0.0
var _skippable: bool = false
var _finished: bool = false


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false
	_fade_layer.color.a = 1.0
	_credits.modulate.a = 0.0
	# VBox'u manuel konumlandıracağız; container'ın kendi layout'unun
	# position.y'yi ezmesini engellemek için top-anchor'a sabitle.
	_credits.set_anchors_preset(Control.PRESET_TOP_WIDE, true)
	await _run_credits()


func _run_credits() -> void:
	# Layout'un oturması için boyutlar geçerli olana kadar bekle.
	var clip_h := 0.0
	var content_h := 0.0
	for _i in 30:
		await get_tree().process_frame
		clip_h = _scroll_clip.size.y
		content_h = _credits.get_combined_minimum_size().y
		if content_h <= 0.0:
			content_h = _credits.size.y
		if clip_h > 0.0 and content_h > 0.0:
			break

	# Yine de 0 geldiyse güvenli varsayılanlar kullan.
	if clip_h <= 0.0:
		clip_h = float(get_viewport().get_visible_rect().size.y)
	if content_h <= 0.0:
		content_h = clip_h

	_scroll_y = clip_h + START_PAD
	_scroll_end = -(content_h + END_PAD)
	_credits.position.y = _scroll_y
	_credits.modulate.a = 1.0

	var black_out := create_tween()
	black_out.set_ease(Tween.EASE_OUT)
	black_out.set_trans(Tween.TRANS_SINE)
	black_out.tween_property(_fade_layer, "color:a", 0.0, 1.2)
	await black_out.finished

	_skippable = true
	_scrolling = true


func _process(delta: float) -> void:
	if not _scrolling or _finished:
		return
	_scroll_y -= SCROLL_SPEED * delta
	_credits.position.y = _scroll_y
	if _scroll_y <= _scroll_end:
		_scrolling = false
		_hold_then_exit()


func _hold_then_exit() -> void:
	await get_tree().create_timer(HOLD_AFTER).timeout
	await _exit_to_menu()


func _exit_to_menu() -> void:
	if _finished:
		return
	_finished = true
	_scrolling = false
	_skippable = false

	var fade_out := create_tween()
	fade_out.set_ease(Tween.EASE_IN)
	fade_out.set_trans(Tween.TRANS_SINE)
	fade_out.tween_property(_fade_layer, "color:a", 1.0, 1.0)
	await fade_out.finished
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


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
		_exit_to_menu()
