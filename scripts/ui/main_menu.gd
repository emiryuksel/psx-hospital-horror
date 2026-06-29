# PSX tarzi ana menu — CRT scanline hissi, titreyen baslik, minimalist butonlar.
extends Control

const GAME_SCENE := "res://scenes/main.tscn"

@onready var _title: Label = $VBox/Title
@onready var _subtitle: Label = $VBox/Subtitle
@onready var _btn_start: Button = $VBox/BtnStart
@onready var _btn_continue: Button = $VBox/BtnContinue
@onready var _btn_quit: Button = $VBox/BtnQuit
@onready var _scanlines: ColorRect = $Scanlines
@onready var _flicker_timer: Timer = $FlickerTimer
@onready var _version_label: Label = $VersionLabel

var _title_base_color := Color(0.85, 0.12, 0.10, 1.0)
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_btn_start.pressed.connect(_on_start)
	_btn_continue.pressed.connect(_on_continue)
	_btn_quit.pressed.connect(_on_quit)
	_flicker_timer.timeout.connect(_on_flicker)

	_btn_continue.visible = SaveManager.has_save()

	_btn_start.grab_focus()
	AudioManager.play("ui_open", -8.0)


func _on_start() -> void:
	AudioManager.play("ui_paper", -4.0)
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_continue() -> void:
	AudioManager.play("ui_paper", -4.0)
	SaveManager.request_load()
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_quit() -> void:
	AudioManager.play("ui_close", -4.0)
	await get_tree().create_timer(0.15).timeout
	get_tree().quit()


func _on_flicker() -> void:
	var jitter := _rng.randf_range(-0.06, 0.06)
	_title.modulate = _title_base_color + Color(jitter, jitter * 0.3, 0.0, 0.0)
	var offset := _rng.randf_range(-0.4, 0.4)
	_title.position.x = offset
