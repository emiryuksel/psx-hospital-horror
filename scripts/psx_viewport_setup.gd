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

	if SaveManager.consume_load_request():
		call_deferred("_deferred_load")


func _deferred_load() -> void:
	SaveManager.load_game()


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
