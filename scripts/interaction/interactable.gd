# Etkileşilebilir obje taban sınıfı — prompt metni, highlight ve billboard etiket desteği.
class_name Interactable
extends Node3D

signal interacted(actor: Node3D)

@export var prompt_text: String = "Interact"
@export var highlight_strength: float = 0.35
@export var label_height: float = 0.3          # etiketin obje origin'i uzerindeki yukseklik (m)
@export var label_text_height: float = 0.085   # etiket yazi yuksekligi (dunya birimi)
@export var label_show_distance: float = 3.5   # etiketin gorundugu max mesafe (m)

var _mesh: MeshInstance3D = null
var _base_color: Color = Color.WHITE
var _is_highlighted: bool = false
var _label_node: MeshInstance3D = null
var _player_ref: Node3D = null


func _ready() -> void:
	_mesh = _find_mesh(self)
	if _mesh and _mesh.material_override != null:
		_base_color = PsxMaterialHelper.get_albedo(_mesh.material_override)
	_setup_label.call_deferred()
	set_process(false)
	call_deferred("_find_player")


func _find_player() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		_player_ref = players[0]
	# Etiket varsa process baslatip mesafe kontrol
	if _label_node != null:
		set_process(true)


func _process(_delta: float) -> void:
	if _label_node == null:
		set_process(false)
		return
	if _player_ref == null or not is_instance_valid(_player_ref):
		return
	var dist := global_position.distance_to(_player_ref.global_position)
	_label_node.visible = dist <= label_show_distance


# Alt siniflar override eder: etiket bos donerse etiket gosterilmez.
func get_label_text() -> String:
	return ""


# Obje uzerinde oyuncuya donuk pixel etiket olustur (varsa).
func _setup_label() -> void:
	var text := get_label_text()
	if text.is_empty():
		return
	if not is_instance_valid(self):
		return
	_label_node = PixelLabel.make_billboard(text, label_text_height)
	_label_node.position = Vector3(0.0, label_height, 0.0)
	_label_node.visible = false
	add_child(_label_node)


# Etiket metnini guncelle (orn. envanter dolu -> farkli yazi)
func update_label(text: String) -> void:
	if _label_node and is_instance_valid(_label_node):
		_label_node.queue_free()
		_label_node = null
	if text.is_empty():
		return
	_label_node = PixelLabel.make_billboard(text, label_text_height)
	_label_node.position = Vector3(0.0, label_height, 0.0)
	add_child(_label_node)


func get_prompt() -> String:
	return prompt_text


func set_highlighted(enabled: bool) -> void:
	if _is_highlighted == enabled:
		return
	_is_highlighted = enabled
	if _mesh and _mesh.material_override != null:
		if enabled:
			PsxMaterialHelper.set_albedo(_mesh.material_override, _base_color.lightened(highlight_strength))
		else:
			PsxMaterialHelper.set_albedo(_mesh.material_override, _base_color)


func interact(actor: Node3D) -> void:
	interacted.emit(actor)


func _find_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node as MeshInstance3D
	for child in node.get_children():
		var found := _find_mesh(child)
		if found:
			return found
	return null
