# Not / anahtar okuma paneli — hikaye parçalarını gösterir.
extends CanvasLayer

@onready var _panel: PanelContainer = $Panel
@onready var _title_label: Label = $Panel/Margin/VBox/TitleLabel
@onready var _body_label: Label = $Panel/Margin/VBox/BodyLabel

# Panel acildigi frame'de ayni E/ESC girisinin paneli hemen kapatmasini engeller.
var _input_guard: bool = false


func _ready() -> void:
	add_to_group("note_reader")
	_panel.visible = false
	InventoryManager.note_requested.connect(_show_note)


func is_reading() -> bool:
	return _panel.visible


# _input kullaniyoruz: panel acikken ESC/E'yi pause_menu gibi diger
# _unhandled_input dinleyicilerinden ONCE yakalayip tuketmeli (cakisma onlenir).
func _input(event: InputEvent) -> void:
	if not _panel.visible:
		return
	if _input_guard:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("interact"):
		_close()
		get_viewport().set_input_as_handled()


func _show_note(text: String, title: String) -> void:
	_title_label.text = title
	_body_label.text = text
	_panel.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# Aciliş frame'inde tekrar tetiklenmeyi engelle (ayni tus basisi)
	_input_guard = true
	_clear_guard.call_deferred()


func _clear_guard() -> void:
	# Bir sonraki frame'de guard'i kaldir
	await get_tree().process_frame
	_input_guard = false


func _close() -> void:
	_panel.visible = false
	if not InventoryManager.is_open:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
