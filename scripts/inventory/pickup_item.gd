# Yerden veya sahneden toplanabilir item — E ile envantere ekler.
extends Interactable

@export var item_id: String = "green_herb"
@export var pickup_count: int = 1
@export var pickup_color: Color = Color(0.3, 0.75, 0.35)
@export var save_id: String = ""

var _collected: bool = false


func _ready() -> void:
	add_to_group("save_pickup")
	if save_id.is_empty():
		save_id = name
	# Pistol/knife gibi silahlar yatay quad olarak gosterilir; etiket yukarida durur.
	if item_id == "pistol" or item_id == "knife":
		label_height = 0.32
	super._ready()
	prompt_text = "Pick up"
	if item_id == "pistol":
		_setup_weapon_visual("res://assets/textures/props/pistol.png")
	elif item_id == "knife":
		_setup_weapon_visual("res://assets/textures/props/knife.png")
	elif _mesh:
		_mesh.material_override = PsxSurfaceTextures.make_prop_material(item_id, pickup_color)
		_base_color = pickup_color


# Etiket metni — item turune gore "TAKE X" (silah/eşya) okunabilir kisa form.
func get_label_text() -> String:
	match item_id:
		"pistol":
			return "TAKE PISTOL"
		"knife":
			return "TAKE KNIFE"
		"flashlight":
			return "TAKE FLASHLIGHT"
		"generator_fuse":
			return "TAKE FUSE"
		"pistol_ammo", "loaded_mag":
			return "TAKE AMMO"
		"green_herb":
			return "TAKE HERB"
	# Genel durum: item adindan turet
	var item := ItemDatabase.create_item(item_id)
	if item:
		return "TAKE %s" % item.display_name.to_upper()
	return "PICK UP"


# Silah pickup'i: kutu yerine masaya yatay duran silah quad'i (ustten siluet).
func _setup_weapon_visual(tex_path: String) -> void:
	if _mesh == null:
		return
	var quad := QuadMesh.new()
	quad.size = Vector2(0.5, 0.32)
	_mesh.mesh = quad
	_mesh.rotation_degrees = Vector3(-90.0, 0.0, 0.0)   # masaya yatir
	_mesh.position = Vector3(0.0, 0.02, 0.0)
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var mat: StandardMaterial3D
	if ResourceLoader.exists(tex_path):
		mat = PsxMaterialHelper.create_transparent_textured_material(tex_path, Color(0.7, 0.74, 0.82), Vector3.ONE)
	else:
		mat = PsxMaterialHelper.create_material(pickup_color, true)
	mat.emission_enabled = true
	mat.emission = Color(0.45, 0.5, 0.62)
	mat.emission_energy_multiplier = 0.5
	_mesh.material_override = mat
	_base_color = Color(0.7, 0.74, 0.82)


func get_prompt() -> String:
	var item := ItemDatabase.create_item(item_id)
	if item:
		return "Pick up %s" % item.display_name
	return "Pick up"


func interact(actor: Node3D) -> void:
	if _collected:
		return

	var item := ItemDatabase.create_item(item_id)
	if item == null:
		return

	if InventoryManager.add_item(item, pickup_count):
		_collected = true
		HudManager.hide_prompt()
		interacted.emit(actor)
		queue_free()
	else:
		prompt_text = "Inventory full"


func get_save_id() -> String:
	return save_id
