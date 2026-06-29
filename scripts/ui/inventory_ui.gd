# Envanter ekranı — slot grid, detay paneli, kullan/bırak/birleştir.
extends CanvasLayer

@onready var _panel: PanelContainer = $Panel
@onready var _slot_grid: GridContainer = $Panel/Margin/VBox/SlotGrid
@onready var _name_label: Label = $Panel/Margin/VBox/DetailPanel/NameLabel
@onready var _desc_label: Label = $Panel/Margin/VBox/DetailPanel/DescLabel
@onready var _use_button: Button = $Panel/Margin/VBox/DetailPanel/ButtonRow/UseButton
@onready var _drop_button: Button = $Panel/Margin/VBox/DetailPanel/ButtonRow/DropButton
@onready var _combine_button: Button = $Panel/Margin/VBox/DetailPanel/ButtonRow/CombineButton

var _slot_buttons: Array[Button] = []
var _selected_slot: int = -1
var _combine_source_slot: int = -1


func _ready() -> void:
	_build_slot_buttons()
	_panel.visible = false
	InventoryManager.inventory_changed.connect(_refresh_slots)
	InventoryManager.inventory_toggled.connect(_on_inventory_toggled)
	_use_button.pressed.connect(_on_use_pressed)
	_drop_button.pressed.connect(_on_drop_pressed)
	_combine_button.pressed.connect(_on_combine_pressed)
	InventoryManager.close_inventory()


func _build_slot_buttons() -> void:
	for i in InventoryManager.MAX_SLOTS:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(72, 72)
		btn.toggle_mode = true
		btn.text = "-"
		var slot_index := i
		btn.pressed.connect(func() -> void: _on_slot_pressed(slot_index))
		_slot_grid.add_child(btn)
		_slot_buttons.append(btn)


func _on_inventory_toggled(is_open: bool) -> void:
	_panel.visible = is_open
	if is_open:
		_refresh_slots()
		_clear_selection()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_slot_pressed(index: int) -> void:
	if _combine_source_slot >= 0 and _combine_source_slot != index:
		InventoryManager.combine_slots(_combine_source_slot, index)
		_combine_source_slot = -1
		_combine_button.text = "Combine"
		_select_slot(index)
		return

	_select_slot(index)


func _select_slot(index: int) -> void:
	_selected_slot = index
	for i in _slot_buttons.size():
		_slot_buttons[i].button_pressed = i == index

	var entry: Dictionary = InventoryManager.get_slot(index)
	if entry.is_empty():
		_name_label.text = "Empty"
		_desc_label.text = ""
		_use_button.disabled = true
		_drop_button.disabled = true
		_combine_button.disabled = true
		return

	var item: Item = entry["item"]
	var count: int = entry["count"]
	_name_label.text = "%s x%d" % [item.display_name, count] if count > 1 else item.display_name
	_desc_label.text = item.description
	_use_button.disabled = not _can_use(item)
	_drop_button.disabled = false
	_combine_button.disabled = false


func _can_use(item: Item) -> bool:
	return item.item_type in [
		Item.ItemType.HEAL,
		Item.ItemType.NOTE,
		Item.ItemType.KEY,
	]


func _clear_selection() -> void:
	_selected_slot = -1
	_combine_source_slot = -1
	_combine_button.text = "Combine"
	for btn in _slot_buttons:
		btn.button_pressed = false
	_name_label.text = ""
	_desc_label.text = ""


func _refresh_slots() -> void:
	for i in _slot_buttons.size():
		var entry: Dictionary = InventoryManager.get_slot(i)
		if entry.is_empty():
			_slot_buttons[i].text = "-"
			_slot_buttons[i].modulate = Color(0.55, 0.55, 0.55)
		else:
			var item: Item = entry["item"]
			var count: int = entry["count"]
			_slot_buttons[i].text = item.display_name.substr(0, 3).to_upper()
			if count > 1:
				_slot_buttons[i].text += "\n%d" % count
			_slot_buttons[i].modulate = item.icon_color

	if _selected_slot >= 0:
		_select_slot(_selected_slot)


func _on_use_pressed() -> void:
	if _selected_slot < 0:
		return
	InventoryManager.use_item(_selected_slot)
	_refresh_slots()
	_select_slot(_selected_slot)


func _on_drop_pressed() -> void:
	if _selected_slot < 0:
		return
	InventoryManager.drop_item(_selected_slot)
	_clear_selection()
	_refresh_slots()


func _on_combine_pressed() -> void:
	if _selected_slot < 0:
		return
	if _combine_source_slot < 0:
		_combine_source_slot = _selected_slot
		_combine_button.text = "Select 2nd"
	else:
		_combine_source_slot = -1
		_combine_button.text = "Combine"
