# SubViewportContainer yöneticisi — düşük çözünürlük, dither viewport içinde.
extends Control

@export var internal_width: int = 320
@export var internal_height: int = 180

var _sub_viewport: SubViewport
var _dither_material: ShaderMaterial


func _ready() -> void:
	_sub_viewport = get_node_or_null("SubViewportContainer/GameViewport")
	var container: SubViewportContainer = get_node_or_null("SubViewportContainer")
	var dither_rect: ColorRect = get_node_or_null(
		"SubViewportContainer/GameViewport/DitherLayer/DitherRect"
	)

	if _sub_viewport == null or container == null:
		push_error("PsxViewportSetup: GameViewport veya SubViewportContainer bulunamadı.")
		return

	container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Container üzerinde material kullanma — beyaz artefakt kaynağıydı.
	container.material = null

	_sub_viewport.transparent_bg = false

	if dither_rect:
		_dither_material = dither_rect.material as ShaderMaterial

	_apply_settings_from_autoload()
	PsxSettings.settings_changed.connect(_apply_settings_from_autoload)

	if GameSession.consume_new_game_intro():
		call_deferred("_start_new_game_intro")


func _start_new_game_intro() -> void:
	GameSession.intro_active = true
	HudManager.set_gameplay_hud_visible(false)
	_set_player_input_locked(true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	var intro: CanvasLayer = get_node_or_null("GameIntro")
	if intro == null or not intro.has_method("play"):
		_on_intro_finished()
		return

	if not intro.finished.is_connected(_on_intro_finished):
		intro.finished.connect(_on_intro_finished, CONNECT_ONE_SHOT)
	intro.play()


func _on_intro_finished() -> void:
	GameSession.finish_intro()
	HudManager.set_gameplay_hud_visible(true)
	_set_player_input_locked(false)
	QuestManager.complete_intro()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _set_player_input_locked(locked: bool) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_method("set_input_locked"):
		player.set_input_locked(locked)


func _apply_settings_from_autoload() -> void:
	if _sub_viewport == null:
		return

	internal_width = PsxSettings.internal_width
	internal_height = PsxSettings.internal_height
	_sub_viewport.size = Vector2i(internal_width, internal_height)

	if _dither_material:
		_dither_material.set_shader_parameter("color_depth", PsxSettings.color_depth)
		_dither_material.set_shader_parameter("dither_strength", PsxSettings.dither_strength)


func get_game_viewport() -> SubViewport:
	return _sub_viewport
