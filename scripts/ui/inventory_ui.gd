# Envanter ekranı — slot grid, detay paneli, kullan/bırak/birleştir.
extends CanvasLayer

@onready var _panel: PanelContainer = $Panel
@onready var _slot_grid: GridContainer = $Panel/Margin/VBox/SlotGrid
@onready var _name_label: Label = $Panel/Margin/VBox/DetailPanel/NameLabel
@onready var _desc_label: Label = $Panel/Margin/VBox/DetailPanel/DescLabel
@onready var _use_button: Button = $Panel/Margin/VBox/DetailPanel/ButtonRow/UseButton
@onready var _combine_button: Button = $Panel/Margin/VBox/DetailPanel/ButtonRow/CombineButton

var _slot_buttons: Array[Button] = []
var _selected_slot: int = -1
var _combine_source_slot: int = -1

# Çift tıklama / çift-A ile kullan algılaması.
const DOUBLE_PRESS_WINDOW := 0.4
var _last_press_slot: int = -1
var _last_press_time: float = 0.0


func _ready() -> void:
	_build_slot_buttons()
	_setup_focus_chain()
	_panel.visible = false
	InventoryManager.inventory_changed.connect(_refresh_slots)
	InventoryManager.inventory_toggled.connect(_on_inventory_toggled)
	_use_button.pressed.connect(_on_use_pressed)
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
		# Gamepad/klavye ile slotlar arası gezerken odaklanınca hemen seç
		# ki detay paneli güncellensin (fare hover'ının karşılığı).
		btn.focus_entered.connect(func() -> void: _on_slot_focused(slot_index))
		_slot_grid.add_child(btn)
		_slot_buttons.append(btn)


# Odak (gamepad/klavye gezinme) slotu seçer ama toggle-combine akışını tetiklemez.
func _on_slot_focused(index: int) -> void:
	_select_slot(index)


# Grid ile detay butonları arasında gamepad/klavye ile geçişi garanti et.
func _setup_focus_chain() -> void:
	var columns := _slot_grid.columns
	var total := _slot_buttons.size()
	if total == 0 or columns <= 0:
		return
	# Grid'in son satırındaki butonlardan aşağıya Use butonuna geç.
	var remainder := total % columns
	var last_row_count := remainder if remainder != 0 else columns
	var last_row_start := total - last_row_count
	for i in range(last_row_start, total):
		_slot_buttons[i].focus_neighbor_bottom = _use_button.get_path()
	# Use/Combine'dan yukarı grid'in son satırına dön.
	var up_target := _slot_buttons[last_row_start]
	_use_button.focus_neighbor_top = up_target.get_path()
	_combine_button.focus_neighbor_top = up_target.get_path()
	_use_button.focus_neighbor_right = _combine_button.get_path()
	_combine_button.focus_neighbor_left = _use_button.get_path()


func _on_inventory_toggled(is_open: bool) -> void:
	_panel.visible = is_open
	if is_open:
		_refresh_slots()
		_clear_selection()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		# Kontrolcü ile gezinmenin başlaması için ilk slota odaklan.
		if not _slot_buttons.is_empty():
			_slot_buttons[0].grab_focus()
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_slot_pressed(index: int) -> void:
	if _combine_source_slot >= 0 and _combine_source_slot != index:
		InventoryManager.combine_slots(_combine_source_slot, index)
		_combine_source_slot = -1
		_combine_button.text = "Combine"
		_select_slot(index)
		_last_press_slot = -1
		return

	# Aynı slota kısa süre içinde ikinci basış = kullan (fare çift tıklama / çift-A).
	var now := Time.get_ticks_msec() / 1000.0
	var is_double := index == _last_press_slot and (now - _last_press_time) <= DOUBLE_PRESS_WINDOW
	_last_press_slot = index
	_last_press_time = now

	_select_slot(index)

	if is_double:
		_last_press_slot = -1
		_try_use_slot(index)


# Seçili slottaki item kullanılabilirse kullan.
func _try_use_slot(index: int) -> void:
	var entry: Dictionary = InventoryManager.get_slot(index)
	if entry.is_empty():
		return
	var item: Item = entry["item"]
	if not _can_use(item):
		return
	InventoryManager.use_item(index)
	_refresh_slots()
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
		_combine_button.disabled = true
		return

	var item: Item = entry["item"]
	var count: int = entry["count"]
	_name_label.text = "%s x%d" % [item.display_name, count] if count > 1 else item.display_name
	_desc_label.text = item.description
	_use_button.disabled = not _can_use(item)
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
	_try_use_slot(_selected_slot)


func _on_combine_pressed() -> void:
	if _selected_slot < 0:
		return
	if _combine_source_slot < 0:
		_combine_source_slot = _selected_slot
		_combine_button.text = "Select 2nd"
	else:
		_combine_source_slot = -1
		_combine_button.text = "Combine"
