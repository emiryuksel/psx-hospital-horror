# Item tanımı — envanterdeki tüm eşyaların base Resource sınıfı.
class_name Item
extends Resource

enum ItemType {
	WEAPON,
	AMMO,
	HEAL,
	KEY,
	NOTE,
	MISC,
	COMBINABLE,
}

@export var id: String = ""
@export var display_name: String = "Item"
@export var description: String = ""
@export var item_type: ItemType = ItemType.MISC
@export var stackable: bool = false
@export var max_stack: int = 1
@export var combinable_with: Array[String] = []
@export var combine_result_id: String = ""
@export var note_text: String = ""
@export var heal_amount: float = 0.0
@export var icon_color: Color = Color(0.7, 0.7, 0.7)


func can_combine_with(other: Item) -> bool:
	return combine_result_id != "" and other != null and other.id in combinable_with


func duplicate_item() -> Item:
	return duplicate(true) as Item
