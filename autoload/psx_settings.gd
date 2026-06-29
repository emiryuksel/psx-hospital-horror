# Global PSX render ayarları — düşük çözünürlük ve efekt parametreleri.
extends Node

signal settings_changed

@export var internal_width: int = 320
@export var internal_height: int = 180
@export var vertex_snap: float = 320.0
@export var affine_strength: float = 0.0
@export var color_depth: int = 4
@export var dither_strength: float = 1.0
@export var fog_enabled: bool = true
@export var fog_density: float = 0.012
@export var fog_color: Color = Color(0.16, 0.17, 0.2)


func get_internal_resolution() -> Vector2i:
	return Vector2i(internal_width, internal_height)


func _ready() -> void:
	settings_changed.emit()
