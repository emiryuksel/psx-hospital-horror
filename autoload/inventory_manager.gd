# Envanter yöneticisi — slot tabanlı RE tarzı sınırlı envanter.
extends Node

signal inventory_changed
signal item_added(item: Item, slot_index: int, count: int)
signal item_removed(item: Item, slot_index: int, count: int)
signal item_used(item: Item, slot_index: int)
signal heal_requested(amount: float)
signal combine_succeeded(result_item: Item)
signal note_requested(text: String, title: String)
signal inventory_toggled(is_open: bool)

const MAX_SLOTS: int = 8

var slots: Array = []
var is_open: bool = false


func _ready() -> void:
	_reset_slots()


func _reset_slots() -> void:
	slots.clear()
	for i in MAX_SLOTS:
		slots.append(null)


func toggle_inventory() -> void:
	is_open = not is_open
	inventory_toggled.emit(is_open)


func close_inventory() -> void:
	if not is_open:
		return
	is_open = false
	inventory_toggled.emit(false)


func get_slot(index: int) -> Dictionary:
	if index < 0 or index >= slots.size():
		return {}
	var entry: Variant = slots[index]
	if entry == null:
		return {}
	return entry as Dictionary


func has_item(item_id: String) -> bool:
	for entry in slots:
		if entry != null and entry.get("item") != null:
			if (entry["item"] as Item).id == item_id:
				return true
	return false


func add_item(item: Item, count: int = 1) -> bool:
	if item == null or count <= 0:
		return false

	if item.stackable:
		for i in slots.size():
			var entry: Variant = slots[i]
			if entry != null and entry["item"].id == item.id:
				var new_count: int = mini(entry["count"] + count, item.max_stack)
				var added: int = new_count - entry["count"]
				if added > 0:
					entry["count"] = new_count
					slots[i] = entry
					inventory_changed.emit()
					item_added.emit(item, i, added)
					return added == count
				break

	for i in slots.size():
		if slots[i] == null:
			slots[i] = {"item": item.duplicate_item(), "count": count}
			inventory_changed.emit()
			item_added.emit(item, i, count)
			return true

	return false


func remove_from_slot(slot_index: int, count: int = 1) -> bool:
	var entry: Dictionary = get_slot(slot_index)
	if entry.is_empty():
		return false

	var item: Item = entry["item"]
	entry["count"] -= count
	if entry["count"] <= 0:
		slots[slot_index] = null
	else:
		slots[slot_index] = entry

	inventory_changed.emit()
	item_removed.emit(item, slot_index, count)
	return true


func remove_item_by_id(item_id: String, count: int = 1) -> bool:
	if count <= 0:
		return true

	var remaining := count
	for i in slots.size():
		var entry: Dictionary = get_slot(i)
		if entry.is_empty():
			continue
		var item: Item = entry["item"]
		if item.id != item_id:
			continue
		var take := mini(remaining, int(entry["count"]))
		remove_from_slot(i, take)
		remaining -= take
		if remaining <= 0:
			return true
	return remaining <= 0


func use_item(slot_index: int) -> void:
	var entry: Dictionary = get_slot(slot_index)
	if entry.is_empty():
		return

	var item: Item = entry["item"]
	match item.item_type:
		Item.ItemType.HEAL:
			heal_requested.emit(item.heal_amount)
			item_used.emit(item, slot_index)
			remove_from_slot(slot_index, 1)
		Item.ItemType.NOTE:
			note_requested.emit(item.note_text, item.display_name)
		Item.ItemType.KEY:
			note_requested.emit(item.description, item.display_name)
		_:
			item_used.emit(item, slot_index)


func combine_slots(slot_a: int, slot_b: int) -> bool:
	var entry_a: Dictionary = get_slot(slot_a)
	var entry_b: Dictionary = get_slot(slot_b)
	if entry_a.is_empty() or entry_b.is_empty():
		return false

	var item_a: Item = entry_a["item"]
	var item_b: Item = entry_b["item"]
	if not item_a.can_combine_with(item_b) and not item_b.can_combine_with(item_a):
		return false

	var result_id: String = item_a.combine_result_id if item_a.can_combine_with(item_b) else item_b.combine_result_id
	var result_item: Item = ItemDatabase.create_item(result_id)
	if result_item == null:
		return false

	remove_from_slot(slot_a, 1)
	remove_from_slot(slot_b, 1)
	add_item(result_item, 1)
	combine_succeeded.emit(result_item)
	return true


func drop_item(slot_index: int) -> Item:
	var entry: Dictionary = get_slot(slot_index)
	if entry.is_empty():
		return null

	var item: Item = (entry["item"] as Item).duplicate_item()
	remove_from_slot(slot_index, 1)
	return item


func export_slots() -> Array:
	var result: Array = []
	for entry in slots:
		if entry == null:
			result.append(null)
		else:
			result.append({
				"id": (entry["item"] as Item).id,
				"count": entry["count"],
			})
	return result


func import_slots(data: Array) -> void:
	_reset_slots()
	for i in mini(data.size(), MAX_SLOTS):
		var entry: Variant = data[i]
		if entry == null:
			continue
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var item := ItemDatabase.create_item(entry.get("id", ""))
		if item == null:
			continue
		slots[i] = {"item": item, "count": int(entry.get("count", 1))}
	inventory_changed.emit()
