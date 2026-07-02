# Item fabrikası — test ve runtime item örnekleri oluşturur.
extends Node

const _ITEM_SCRIPT := preload("res://resources/items/item.gd")


func create_item(item_id: String) -> Item:
	match item_id:
		"green_herb":
			return _make_item(
				"green_herb", "Green Herb", "Restores a small amount of health.",
				Item.ItemType.HEAL, false, 1, [], "", "", 35.0, Color(0.2, 0.7, 0.25)
			)
		"rusty_key":
			return _make_item(
				"rusty_key", "Rusty Key", "A corroded key. Might open something downstairs.",
				Item.ItemType.KEY, false, 1, [], "", "", 0.0, Color(0.75, 0.55, 0.2)
			)
		"note_diary":
			return _make_item(
				"note_diary", "Torn Diary", "A blood-stained diary page.",
				Item.ItemType.NOTE, false, 1, [], "",
				"The power went out at midnight. Something is in the walls. Do not open the basement door.",
				0.0, Color(0.85, 0.8, 0.65)
			)
		"empty_mag":
			return _make_item(
				"empty_mag", "Empty Magazine", "A pistol magazine with no rounds.",
				Item.ItemType.COMBINABLE, false, 1, ["pistol_ammo"], "loaded_mag", "", 0.0, Color(0.35, 0.35, 0.4)
			)
		"pistol_ammo":
			return _make_item(
				"pistol_ammo", "Pistol Ammo", "9mm rounds. Stackable.",
				Item.ItemType.AMMO, true, 5, ["empty_mag"], "loaded_mag", "", 0.0, Color(0.8, 0.75, 0.2)
			)
		"loaded_mag":
			return _make_item(
				"loaded_mag", "Loaded Magazine", "A magazine filled with 9mm rounds.",
				Item.ItemType.AMMO, false, 1, [], "", "", 0.0, Color(0.5, 0.5, 0.55)
			)
		"generator_fuse":
			return _make_item(
				"generator_fuse", "Generator Fuse", "A heavy ceramic fuse from the utility closet. Fits the lobby breaker.",
				Item.ItemType.KEY, false, 1, [], "", "", 0.0, Color(0.82, 0.72, 0.35)
			)
		"maintenance_key":
			return _make_item(
				"maintenance_key", "Maintenance Key", "A grease-stained key tagged 'PUMP'. Opens the basement pump room.",
				Item.ItemType.KEY, false, 1, [], "", "", 0.0, Color(0.7, 0.6, 0.3)
			)
		"pistol":
			return _make_item(
				"pistol", "Service Pistol", "A scratched 9mm sidearm. The grip is still warm. Whoever held it last isn't far.",
				Item.ItemType.WEAPON, false, 1, [], "", "", 0.0, Color(0.32, 0.32, 0.36)
			)
		"knife":
			return _make_item(
				"knife", "Combat Knife", "A worn utility knife. Quiet, reliable, and it never runs out of rounds.",
				Item.ItemType.WEAPON, false, 1, [], "", "", 0.0, Color(0.38, 0.4, 0.44)
			)
		"flashlight":
			return _make_item(
				"flashlight", "Flashlight", "A heavy-duty emergency flashlight. The battery indicator blinks green.",
				Item.ItemType.KEY, false, 1, [], "", "", 0.0, Color(0.75, 0.78, 0.4)
			)
		_:
			return null


func _make_item(
	id: String,
	display_name: String,
	description: String,
	item_type: Item.ItemType,
	stackable: bool,
	max_stack: int,
	combinable_with: Array[String],
	combine_result_id: String,
	note_text: String,
	heal_amount: float,
	icon_color: Color
) -> Item:
	var item := _ITEM_SCRIPT.new()
	item.id = id
	item.display_name = display_name
	item.description = description
	item.item_type = item_type
	item.stackable = stackable
	item.max_stack = max_stack
	item.combinable_with = combinable_with
	item.combine_result_id = combine_result_id
	item.note_text = note_text
	item.heal_amount = heal_amount
	item.icon_color = icon_color
	return item
