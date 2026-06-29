# PSX material oluşturucu — StandardMaterial3D (custom spatial shader artefakt üretmez).
class_name PsxMaterialHelper
extends RefCounted


static func _make_lit_base() -> StandardMaterial3D:
	# Lit ama matte PSX yüzey — flashlight/ışıklara tepki verir, parlama yapmaz.
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	# PSX: mipmapsiz nearest — sig acilarda texture detayi kaybolmaz (mip-collapse yok).
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.roughness = 1.0
	mat.metallic = 0.0
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return mat


static func create_material(albedo: Color = Color.WHITE, double_sided: bool = false) -> StandardMaterial3D:
	var mat := _make_lit_base()
	mat.albedo_color = albedo
	if double_sided:
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


static func create_unshaded_material(albedo: Color = Color.WHITE) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = albedo
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.disable_ambient_light = true
	return mat


static func create_textured_material(
	texture_path: String,
	fallback: Color = Color.WHITE,
	uv_scale: Vector3 = Vector3.ONE
) -> StandardMaterial3D:
	var mat := _make_lit_base()
	mat.uv1_scale = uv_scale

	if ResourceLoader.exists(texture_path):
		var tex: Texture2D = load(texture_path) as Texture2D
		if tex:
			mat.albedo_texture = tex
			mat.albedo_color = Color.WHITE
			return mat

	mat.albedo_color = fallback
	return mat


static func create_transparent_textured_material(
	texture_path: String,
	fallback: Color = Color.WHITE,
	uv_scale: Vector3 = Vector3.ONE
) -> StandardMaterial3D:
	var mat := create_textured_material(texture_path, fallback, uv_scale)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.alpha_scissor_threshold = 0.4
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


const PSX_LIT_SHADER := preload("res://shaders/psx_lit.gdshader")


# PSX yüzey materyali: vertex jitter + affine warp + gerçek ışıklandırma.
# Büyük seviye yüzeyleri (duvar/zemin/tavan/metal/ahşap/kapı) için.
static func create_psx_surface_material(
	texture_path: String,
	fallback: Color = Color.WHITE,
	uv_scale: Vector3 = Vector3.ONE
) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = PSX_LIT_SHADER
	mat.set_shader_parameter("uv_scale", uv_scale)
	mat.set_shader_parameter("vertex_snap", PsxSettings.vertex_snap)

	var has_tex := false
	if ResourceLoader.exists(texture_path):
		var tex: Texture2D = load(texture_path) as Texture2D
		if tex:
			mat.set_shader_parameter("albedo_texture", tex)
			mat.set_shader_parameter("albedo_color", Color.WHITE)
			has_tex = true
	mat.set_shader_parameter("use_texture", has_tex)
	if not has_tex:
		mat.set_shader_parameter("albedo_color", fallback)
	return mat


static func bake_flat_shade(albedo: Color) -> Color:
	return Color(
		clampf(albedo.r * 0.72, 0.05, 1.0),
		clampf(albedo.g * 0.68, 0.05, 1.0),
		clampf(albedo.b * 0.64, 0.05, 1.0),
		albedo.a
	)


static func get_albedo(mat: Material) -> Color:
	if mat is StandardMaterial3D:
		return (mat as StandardMaterial3D).albedo_color
	if mat is ShaderMaterial:
		return mat.get_shader_parameter("albedo_color")
	return Color.WHITE


static func set_albedo(mat: Material, color: Color) -> void:
	if mat is StandardMaterial3D:
		(mat as StandardMaterial3D).albedo_color = color
	elif mat is ShaderMaterial:
		mat.set_shader_parameter("albedo_color", color)


static func apply_to_tree(root: Node) -> void:
	for mesh_instance in _find_mesh_instances(root):
		apply_to_mesh_instance(mesh_instance)


# Frustum culling'i gevseterek "kameraya yaklasinca beliren / cevirince yanip sonen"
# (erken cull edilen) yuzeyleri onler. Buyuk seviye kutularinda PSX vertex-snap
# shader'i POSITION'i kaydirdigi icin Godot'un AABB tabanli culling'i yuzeyleri
# erken atabiliyor; genis bir cull margin bunu engeller.
static func fix_culling_tree(root: Node, margin: float = 4.0) -> void:
	for mesh_instance in _find_mesh_instances(root):
		mesh_instance.extra_cull_margin = margin
		mesh_instance.ignore_occlusion_culling = true


static func apply_to_mesh_instance(mesh_instance: MeshInstance3D) -> void:
	if mesh_instance.mesh == null:
		return

	var source := _resolve_source_material(mesh_instance)
	var albedo_tex: Texture2D = null
	var albedo_color := Color(0.72, 0.70, 0.68)

	if source:
		albedo_tex = _get_albedo_texture(source)
		albedo_color = _get_albedo_color(source)

	var mat := _make_lit_base()

	if albedo_tex:
		mat.albedo_texture = albedo_tex
		mat.albedo_color = Color.WHITE
	else:
		mat.albedo_color = albedo_color

	mesh_instance.material_override = mat


static func _resolve_source_material(mesh_instance: MeshInstance3D) -> Material:
	if mesh_instance.material_override:
		return mesh_instance.material_override
	for i in mesh_instance.mesh.get_surface_count():
		var override_mat := mesh_instance.get_surface_override_material(i)
		if override_mat:
			return override_mat
		var surface_mat := mesh_instance.mesh.surface_get_material(i)
		if surface_mat:
			return surface_mat
	return null


static func _get_albedo_texture(material: Material) -> Texture2D:
	if material is StandardMaterial3D:
		return (material as StandardMaterial3D).albedo_texture
	if material is ShaderMaterial:
		var tex: Texture2D = material.get_shader_parameter("albedo_texture")
		if tex:
			return tex
	return null


static func _get_albedo_color(material: Material) -> Color:
	if material is StandardMaterial3D:
		return (material as StandardMaterial3D).albedo_color
	if material is ShaderMaterial:
		var col: Variant = material.get_shader_parameter("albedo_color")
		if col is Color:
			return col
	return Color(0.72, 0.70, 0.68)


static func _find_mesh_instances(node: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		result.append(node as MeshInstance3D)
	for child in node.get_children():
		result.append_array(_find_mesh_instances(child))
	return result
