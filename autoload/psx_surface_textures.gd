# Hastane + prop texture yolları — tools/generate_psx_textures.ps1 ile üretilir.
extends Node

enum Surface { WALL, FLOOR, CEILING, DOOR, EXIT_DOOR, METAL, WOOD, DEBRIS, BLOOD }

const TEX_DIR := "res://assets/textures/hospital/"
const PROP_DIR := "res://assets/textures/props/"

const WALL_PATH := TEX_DIR + "wall.png"
const FLOOR_PATH := TEX_DIR + "floor.png"
const CEILING_PATH := TEX_DIR + "ceiling.png"
const DOOR_PATH := TEX_DIR + "door.png"
const EXIT_DOOR_PATH := TEX_DIR + "exit_door.png"
const METAL_PATH := TEX_DIR + "metal.png"
const WOOD_PATH := TEX_DIR + "wood.png"
const DEBRIS_PATH := PROP_DIR + "debris.png"
const BLOOD_PATH := PROP_DIR + "blood.png"

const TILE_SIZE_M := 2.5

const PROP_TEXTURES: Dictionary = {
	"generator_fuse": PROP_DIR + "fuse.png",
	"rusty_key": PROP_DIR + "key.png",
	"green_herb": PROP_DIR + "herb.png",
	"pistol_ammo": PROP_DIR + "ammo.png",
	"pistol": PROP_DIR + "pistol.png",
	"knife": PROP_DIR + "knife.png",
	"note_diary": PROP_DIR + "note.png",
}


func make_material(surface: Surface, box_size: Vector3, fallback: Color) -> Material:
	var path := _path_for_surface(surface)
	var uv := _uv_for_surface(surface, box_size)

	if surface == Surface.BLOOD:
		return PsxMaterialHelper.create_transparent_textured_material(path, fallback, uv)
	# Kapilar StandardMaterial3D kalir (exit_door.gd emission set ediyor).
	if surface == Surface.DOOR or surface == Surface.EXIT_DOOR:
		return PsxMaterialHelper.create_textured_material(path, fallback, uv)
	# Buyuk duz yuzeyler: PSX vertex jitter + affine warp shader'i.
	return PsxMaterialHelper.create_psx_surface_material(path, fallback, uv)


# Kucuk 3D prop'lar (masa, yatak, metal dolap vb.) — vertex snap shader yuzeyleri
# uzaktan dejenere edip kaybettiginden StandardMaterial3D kullanilir.
func make_prop_surface_material(surface: Surface, box_size: Vector3, fallback: Color) -> StandardMaterial3D:
	var path := _path_for_surface(surface)
	var uv := _uv_for_surface(surface, box_size)
	return PsxMaterialHelper.create_textured_material(path, fallback, uv)


func make_prop_material(item_id: String, fallback: Color) -> StandardMaterial3D:
	var path: String = PROP_TEXTURES.get(item_id, "")
	var mat: StandardMaterial3D
	if path.is_empty() or not ResourceLoader.exists(path):
		mat = PsxMaterialHelper.create_material(fallback, true)
	else:
		mat = PsxMaterialHelper.create_textured_material(path, fallback, Vector3.ONE)
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	# Karanlıkta bulunabilsin diye hafif öz-ışıma (pickup affordance).
	mat.emission_enabled = true
	# Silah pickup'i: texture'i var, beyaza patlamasin — soguk-mavi sonuk parilti.
	if item_id == "pistol":
		mat.emission = Color(0.4, 0.45, 0.6)
		mat.emission_energy_multiplier = 0.45
	else:
		mat.emission = fallback
		mat.emission_energy_multiplier = 0.35
	return mat


func get_prop_texture_path(item_id: String) -> String:
	return PROP_TEXTURES.get(item_id, "")


func has_textures() -> bool:
	return ResourceLoader.exists(WALL_PATH)


func _path_for_surface(surface: Surface) -> String:
	match surface:
		Surface.WALL:
			return WALL_PATH
		Surface.FLOOR:
			return FLOOR_PATH
		Surface.CEILING:
			return CEILING_PATH
		Surface.DOOR:
			return DOOR_PATH
		Surface.EXIT_DOOR:
			return EXIT_DOOR_PATH
		Surface.METAL:
			return METAL_PATH
		Surface.WOOD:
			return WOOD_PATH
		Surface.DEBRIS:
			return DEBRIS_PATH
		Surface.BLOOD:
			return BLOOD_PATH
	return ""


func _uv_for_surface(surface: Surface, box_size: Vector3) -> Vector3:
	match surface:
		Surface.DOOR, Surface.EXIT_DOOR:
			# Tek kapı görseli yüzeye tam otursun (tile etme).
			return Vector3.ONE
		Surface.WALL:
			var span := maxf(box_size.x, box_size.z)
			return Vector3(span / TILE_SIZE_M, box_size.y / TILE_SIZE_M, 1.0)
		Surface.FLOOR, Surface.CEILING, Surface.DEBRIS:
			return Vector3(box_size.x / TILE_SIZE_M, box_size.z / TILE_SIZE_M, 1.0)
		Surface.METAL, Surface.WOOD:
			return Vector3(box_size.x / TILE_SIZE_M, box_size.y / TILE_SIZE_M, 1.0)
		Surface.BLOOD:
			return Vector3(box_size.x / 1.0, box_size.z / 1.0, 1.0)
	return Vector3.ONE
