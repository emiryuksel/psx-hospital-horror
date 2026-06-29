# PSX tarzi pause menu — ESC ile acilir, oyun dondurulur.
extends CanvasLayer

const MAIN_MENU_SCENE := "res://scenes/ui/main_menu.tscn"

@onready var _panel: PanelContainer = $Panel
@onready var _btn_resume: Button = $Panel/VBox/BtnResume
@onready var _btn_save: Button = $Panel/VBox/BtnSave
@onready var _btn_menu: Button = $Panel/VBox/BtnMenu
@onready var _btn_quit: Button = $Panel/VBox/BtnQuit
@onready var _scanlines: ColorRect = $Scanlines

var _is_paused: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_btn_resume.pressed.connect(_resume)
	_btn_save.pressed.connect(_save)
	_btn_menu.pressed.connect(_main_menu)
	_btn_quit.pressed.connect(_quit)
	_hide_menu()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		# Not okuyucu acikken pause acma — onun kendi _input'u kapatir.
		var reader := get_tree().get_first_node_in_group("note_reader")
		if reader and reader.has_method("is_reading") and reader.is_reading():
			return
		if _is_paused:
			_resume()
		else:
			_pause()
		get_viewport().set_input_as_handled()


func _pause() -> void:
	if InventoryManager.is_open:
		return
	_is_paused = true
	get_tree().paused = true
	_panel.visible = true
	_scanlines.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_btn_resume.grab_focus()
	AudioManager.play("ui_open", -6.0)


func _resume() -> void:
	_is_paused = false
	get_tree().paused = false
	_hide_menu()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	AudioManager.play("ui_close", -6.0)


func _save() -> void:
	_resume()
	SaveManager.save_game()


func _main_menu() -> void:
	_is_paused = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func _quit() -> void:
	AudioManager.play("ui_close", -4.0)
	await get_tree().create_timer(0.15).timeout
	get_tree().quit()


func _hide_menu() -> void:
	_panel.visible = false
	_scanlines.visible = false
