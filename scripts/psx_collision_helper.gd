# Imported mesh'lere otomatik StaticBody3D + collision ekler.
class_name PsxCollisionHelper
extends RefCounted

enum CollisionMode { TRIMESH, CONVEX, BOX_AABB }


static func ensure_collision_tree(root: Node, mode: CollisionMode = CollisionMode.TRIMESH) -> void:
	for mesh in _find_mesh_instances(root):
		ensure_collision_for_mesh(mesh, mode)


static func ensure_collision_for_mesh(mesh_instance: MeshInstance3D, mode: CollisionMode = CollisionMode.TRIMESH) -> StaticBody3D:
	if mesh_instance.mesh == null:
		return null

	var existing := _find_collision_body(mesh_instance)
	if existing:
		_ensure_shape(existing, mesh_instance, mode)
		return existing

	var body := StaticBody3D.new()
	body.name = "%s_Body" % mesh_instance.name
	mesh_instance.get_parent().add_child(body)
	body.owner = _get_owner(mesh_instance)
	body.position = mesh_instance.position
	body.rotation = mesh_instance.rotation
	body.scale = mesh_instance.scale

	mesh_instance.reparent(body)
	mesh_instance.position = Vector3.ZERO
	mesh_instance.rotation = Vector3.ZERO
	mesh_instance.scale = Vector3.ONE

	_ensure_shape(body, mesh_instance, mode)
	return body


static func _ensure_shape(body: StaticBody3D, mesh_instance: MeshInstance3D, mode: CollisionMode) -> void:
	var collision := body.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision == null:
		collision = CollisionShape3D.new()
		collision.name = "CollisionShape3D"
		body.add_child(collision)
		collision.owner = body.owner

	var shape: Shape3D = _create_shape(mesh_instance.mesh, mode)
	if shape:
		collision.shape = shape


static func _create_shape(mesh: Mesh, mode: CollisionMode) -> Shape3D:
	match mode:
		CollisionMode.TRIMESH:
			return mesh.create_trimesh_shape()
		CollisionMode.CONVEX:
			return mesh.create_convex_shape()
		CollisionMode.BOX_AABB:
			var box := BoxShape3D.new()
			box.size = mesh.get_aabb().size
			return box
	return null


static func _find_collision_body(mesh_instance: MeshInstance3D) -> StaticBody3D:
	var parent := mesh_instance.get_parent()
	if parent is StaticBody3D:
		return parent as StaticBody3D
	return null


static func _find_mesh_instances(node: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		result.append(node as MeshInstance3D)
	for child in node.get_children():
		result.append_array(_find_mesh_instances(child))
	return result


static func _get_owner(node: Node) -> Node:
	var current := node
	while current:
		if current.owner:
			return current.owner
		current = current.get_parent()
	return null
