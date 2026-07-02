# Görev durumu — 3 part yapısının Part I + Part II akışı.
extends Node

signal quest_updated(objective: String)
signal power_restored
signal fuse_install_ambush_requested

# Part II sinyalleri
signal basement_power_restored
signal junction_ambush_requested

enum Part1State { EXPLORE, SEEK_FUSE, RETURN_FUSE, SEEK_ELEVATOR }
enum Part2State { ARRIVE, SEEK_KEY, SEEK_VALVE, START_GENERATOR, RETURN_ELEVATOR, COMPLETE }
enum ActivePart { PART1, PART2 }

const FUSE_ITEM_ID := "generator_fuse"
const FLASHLIGHT_ITEM_ID := "flashlight"
const MAINTENANCE_KEY_ID := "maintenance_key"

var part1_state: Part1State = Part1State.EXPLORE
var power_on: bool = false
var show_chapter_objective: bool = false
var fuse_pickup_creature_done: bool = false
var fuse_ambush_done: bool = false

# --- Part II durumu ---
var active_part: ActivePart = ActivePart.PART1
var part2_state: Part2State = Part2State.ARRIVE
var basement_power_on: bool = false
var valve_open: bool = false
var cold_storage_stalker_done: bool = false
var junction_ambush_done: bool = false
var morgue_creature_done: bool = false


func _ready() -> void:
	InventoryManager.item_added.connect(_on_item_added)


func reset_part1() -> void:
	part1_state = Part1State.EXPLORE
	power_on = false
	show_chapter_objective = false
	fuse_pickup_creature_done = false
	fuse_ambush_done = false
	active_part = ActivePart.PART1
	reset_part2()
	refresh_objective()


func reset_part2() -> void:
	part2_state = Part2State.ARRIVE
	basement_power_on = false
	valve_open = false
	cold_storage_stalker_done = false
	junction_ambush_done = false
	morgue_creature_done = false


func complete_intro() -> void:
	show_chapter_objective = true
	refresh_objective(true)


func on_fuse_installed() -> void:
	power_on = true
	part1_state = Part1State.SEEK_ELEVATOR
	power_restored.emit()
	if not fuse_ambush_done:
		fuse_install_ambush_requested.emit()
	refresh_objective(true)
	HudManager.show_message("Power restored — take the elevator downstairs")


func mark_fuse_pickup_creature_done() -> void:
	fuse_pickup_creature_done = true


func mark_fuse_ambush_done() -> void:
	fuse_ambush_done = true


# --- Part II akışı ---

# Part I asansöründen bodruma inildiğinde çağrılır.
func begin_part2() -> void:
	active_part = ActivePart.PART2
	part2_state = Part2State.ARRIVE
	basement_power_on = false
	valve_open = false
	cold_storage_stalker_done = false
	junction_ambush_done = false
	morgue_creature_done = false
	refresh_objective(true)


# Cold Storage'daki bakım anahtarı alındığında.
func on_maintenance_key_found() -> void:
	if part2_state == Part2State.ARRIVE or part2_state == Part2State.SEEK_KEY:
		part2_state = Part2State.SEEK_VALVE
		refresh_objective(true)


func mark_morgue_creature_done() -> void:
	morgue_creature_done = true


func mark_cold_storage_stalker_done() -> void:
	cold_storage_stalker_done = true


func mark_junction_ambush_done() -> void:
	junction_ambush_done = true


# Pump Room'daki soğutucu valfi açıldığında.
func on_valve_opened() -> void:
	valve_open = true
	if part2_state == Part2State.SEEK_VALVE or part2_state == Part2State.SEEK_KEY:
		part2_state = Part2State.START_GENERATOR
	if not junction_ambush_done:
		junction_ambush_requested.emit()
	refresh_objective(true)
	HudManager.show_message("Coolant flowing — start the generator")


# Generator Room'daki jeneratör çalıştırıldığında.
func on_generator_started() -> void:
	basement_power_on = true
	part2_state = Part2State.RETURN_ELEVATOR
	basement_power_restored.emit()
	refresh_objective(true)
	HudManager.show_message("Power restored — return to the elevator")


# Part II tamamlandığında (asansöre geri dönüş).
func complete_part2() -> void:
	part2_state = Part2State.COMPLETE
	refresh_objective(true)


func get_objective_text() -> String:
	if active_part == ActivePart.PART2:
		return _get_part2_objective_text()
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
			return "Take the elevator down — East wall"
	return ""


func _get_part2_objective_text() -> String:
	match part2_state:
		Part2State.ARRIVE:
			return "Part II — The Basement"
		Part2State.SEEK_KEY:
			return "Find a way to restart the generator"
		Part2State.SEEK_VALVE:
			return "Open the coolant valve — Pump Room"
		Part2State.START_GENERATOR:
			return "Start the generator — Generator Room"
		Part2State.RETURN_ELEVATOR:
			return "Return to the elevator"
		Part2State.COMPLETE:
			return "Part II complete"
	return ""


func get_save_data() -> Dictionary:
	return {
		"part1_state": part1_state,
		"power_on": power_on,
		"show_chapter_objective": show_chapter_objective,
		"fuse_pickup_creature_done": fuse_pickup_creature_done,
		"fuse_ambush_done": fuse_ambush_done,
		"active_part": active_part,
		"part2_state": part2_state,
		"basement_power_on": basement_power_on,
		"valve_open": valve_open,
		"cold_storage_stalker_done": cold_storage_stalker_done,
		"junction_ambush_done": junction_ambush_done,
		"morgue_creature_done": morgue_creature_done,
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

	# Part II durumu
	active_part = int(data.get("active_part", ActivePart.PART1)) as ActivePart
	part2_state = int(data.get("part2_state", Part2State.ARRIVE)) as Part2State
	basement_power_on = bool(data.get("basement_power_on", false))
	valve_open = bool(data.get("valve_open", false))
	cold_storage_stalker_done = bool(data.get("cold_storage_stalker_done", false))
	junction_ambush_done = bool(data.get("junction_ambush_done", false))
	morgue_creature_done = bool(data.get("morgue_creature_done", false))

	if active_part == ActivePart.PART1:
		_sync_state_from_inventory()
	if data.has("show_chapter_objective"):
		show_chapter_objective = bool(data.get("show_chapter_objective", false))
	elif part1_state == Part1State.EXPLORE and not InventoryManager.has_item(FLASHLIGHT_ITEM_ID):
		show_chapter_objective = true
	refresh_objective()
	if power_on and active_part == ActivePart.PART1:
		power_restored.emit()
	if basement_power_on and active_part == ActivePart.PART2:
		basement_power_restored.emit()


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
