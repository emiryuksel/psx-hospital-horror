# Görev durumu — 3 part yapısının Part I akışı.
extends Node

signal quest_updated(objective: String)
signal power_restored

enum Part1State { SEEK_WEAPON, SEEK_FUSE, RETURN_FUSE, COMPLETE }

const FUSE_ITEM_ID := "generator_fuse"
const WEAPON_ITEM_ID := "pistol"

var part1_state: Part1State = Part1State.SEEK_WEAPON
var power_on: bool = false


func _ready() -> void:
	InventoryManager.item_added.connect(_on_item_added)


func reset_part1() -> void:
	part1_state = Part1State.SEEK_WEAPON
	power_on = false
	refresh_objective()


func on_fuse_installed() -> void:
	power_on = true
	part1_state = Part1State.COMPLETE
	power_restored.emit()
	refresh_objective()
	HudManager.show_message("Power restored — head to the red EXIT")


func get_objective_text() -> String:
	match part1_state:
		Part1State.SEEK_WEAPON:
			# Silah alinana kadar objective gosterilmez — oyuncu kesfetsin.
			return ""
		Part1State.SEEK_FUSE:
			return "Part I — Find the generator fuse"
		Part1State.RETURN_FUSE:
			return "Part I — Install fuse at lobby breaker panel"
		Part1State.COMPLETE:
			return "Part I — Reach the red EXIT door"
	return ""


func get_save_data() -> Dictionary:
	return {
		"part1_state": part1_state,
		"power_on": power_on,
	}


func apply_save_data(data: Dictionary) -> void:
	part1_state = int(data.get("part1_state", Part1State.SEEK_WEAPON)) as Part1State
	power_on = bool(data.get("power_on", false))
	_sync_state_from_inventory()
	refresh_objective()
	if power_on:
		power_restored.emit()


func _sync_state_from_inventory() -> void:
	if power_on:
		part1_state = Part1State.COMPLETE
	elif InventoryManager.has_item(FUSE_ITEM_ID):
		part1_state = Part1State.RETURN_FUSE
	elif InventoryManager.has_item(WEAPON_ITEM_ID):
		part1_state = Part1State.SEEK_FUSE
	else:
		part1_state = Part1State.SEEK_WEAPON


func _on_item_added(item: Item, _slot_index: int, _count: int) -> void:
	if item == null:
		return
	# Silah alindi — sigorta arama asamasina gec
	if item.id == WEAPON_ITEM_ID and part1_state == Part1State.SEEK_WEAPON:
		part1_state = Part1State.SEEK_FUSE
		refresh_objective()
		return
	# Sigorta alindi — takma asamasina gec
	if item.id == FUSE_ITEM_ID and part1_state == Part1State.SEEK_FUSE:
		part1_state = Part1State.RETURN_FUSE
		refresh_objective()


func refresh_objective() -> void:
	var text := get_objective_text()
	quest_updated.emit(text)
	HudManager.update_objective(text)
