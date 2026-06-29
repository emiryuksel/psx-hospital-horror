# Imported model kökü — editor/runtime PSX material + collision uygular.
@tool
extends Node3D

@export_group("PSX Setup")
@export var apply_psx_materials: bool = true
@export var generate_collision: bool = true
@export var collision_mode: PsxCollisionHelper.CollisionMode = PsxCollisionHelper.CollisionMode.TRIMESH
@export var run_on_ready: bool = true


func _ready() -> void:
	if not run_on_ready:
		return
	apply_psx_pipeline()


@export_tool_button("Apply PSX Pipeline")
func apply_psx_pipeline() -> void:
	if apply_psx_materials:
		PsxMaterialHelper.apply_to_tree(self)
	if generate_collision:
		PsxCollisionHelper.ensure_collision_tree(self, collision_mode)
