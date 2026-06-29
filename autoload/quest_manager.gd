# Görev durumu — 3 part yapısının Part I akışı.
extends Node

signal quest_updated(objective: String)
signal power_restored

enum Part1State { EXPLORE, SEEK_FUSE, RETURN_FUSE, SEEK_ELEVATOR }

const FUSE_ITEM_ID := "generator_fuse"
const FLASHLIGHT_ITEM_ID := "flashlight"

var part1_state: Part1State = Part1State.EXPLORE
var power_on: bool = false
var show_chapter_objective: bool = false
var fuse_pickup_creature_done: bool = false
var fuse_ambush_done: bool = false
var _pending_fuse_ambush: bool = false


func _ready() -> void:
	InventoryManager.item_added.connect(_on_item_added)


func reset_part1() -> void:
	part1_state = Part1State.EXPLORE
	power_on = false
	show_chapter_objective = false
	fuse_pickup_creature_done = false
	fuse_ambush_done = false
	_pending_fuse_ambush = false
	refresh_objective()


func complete_intro() -> void:
	show_chapter_objective = true
	refresh_objective(true)


func on_fuse_installed() -> void:
	power_on = true
	part1_state = Part1State.SEEK_ELEVATOR
	if not fuse_ambush_done:
		_pending_fuse_ambush = true
	power_restored.emit()
	refresh_objective(true)
	HudManager.show_message("Power restored — take the elevator downstairs")


func consume_fuse_ambush() -> bool:
	if not _pending_fuse_ambush:
		return false
	_pending_fuse_ambush = false
	return true


func mark_fuse_pickup_creature_done() -> void:
	fuse_pickup_creature_done = true


func mark_fuse_ambush_done() -> void:
	fuse_ambush_done = true
	_pending_fuse_ambush = false


func get_objective_text() -> String:
	match part1_state:
		Part1State.EXPLORE:
			if show_chapter_objective:
				return "Part I — Unaware"
			return ""
		Part1State.SEEK_FUSE:
			return "Find generator fuse — patient wing"
		Part1State.RETURN_FUSE:
			return "Install fuse — lobby breaker panel"
		Part1State.SEEK_ELEVATOR:
			return "Take the elevator — Part II below"
	return ""


func get_save_data() -> Dictionary:
	return {
		"part1_state": part1_state,
		"power_on": power_on,
		"show_chapter_objective": show_chapter_objective,
		"fuse_pickup_creature_done": fuse_pickup_creature_done,
		"fuse_ambush_done": fuse_ambush_done,
	}


func apply_save_data(data: Dictionary) -> void:
	part1_state = _migrate_part1_state(int(data.get("part1_state", Part1State.EXPLORE)))
	power_on = bool(data.get("power_on", false))
	fuse_ambush_done = bool(data.get("fuse_ambush_done", power_on))
	fuse_pickup_creature_done = bool(
		data.get(
			"fuse_pickup_creature_done",
			InventoryManager.has_item(FUSE_ITEM_ID) or power_on
		)
	)
	_pending_fuse_ambush = false
	_sync_state_from_inventory()
	if data.has("show_chapter_objective"):
		show_chapter_objective = bool(data.get("show_chapter_objective", false))
	elif part1_state == Part1State.EXPLORE and not InventoryManager.has_item(FLASHLIGHT_ITEM_ID):
		show_chapter_objective = true
	refresh_objective()
	if power_on:
		power_restored.emit()


func _migrate_part1_state(raw: int) -> Part1State:
	# Eski save: SEEK_WEAPON(0), SEEK_FUSE(1), RETURN_FUSE(2), COMPLETE(3)
	match raw:
		0:
			return Part1State.EXPLORE
		3:
			return Part1State.SEEK_ELEVATOR
		1, 2:
			return raw as Part1State
	return Part1State.EXPLORE


func _sync_state_from_inventory() -> void:
	if power_on:
		part1_state = Part1State.SEEK_ELEVATOR
	elif InventoryManager.has_item(FUSE_ITEM_ID):
		part1_state = Part1State.RETURN_FUSE
	elif InventoryManager.has_item(FLASHLIGHT_ITEM_ID):
		part1_state = Part1State.SEEK_FUSE
	else:
		part1_state = Part1State.EXPLORE


func _on_item_added(item: Item, _slot_index: int, _count: int) -> void:
	if item == null:
		return
	if item.id == FLASHLIGHT_ITEM_ID and part1_state == Part1State.EXPLORE:
		part1_state = Part1State.SEEK_FUSE
		refresh_objective(true)
		return
	if item.id == FUSE_ITEM_ID and part1_state == Part1State.SEEK_FUSE:
		part1_state = Part1State.RETURN_FUSE
		refresh_objective(true)


func refresh_objective(animated: bool = false) -> void:
	var text := get_objective_text()
	quest_updated.emit(text)
	HudManager.update_objective(text, animated)
