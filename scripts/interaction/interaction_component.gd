# Raycast tabanlı etkileşim — bakılan Interactable objeyi algılar ve E ile tetikler.
extends Node

signal focus_changed(interactable: Interactable)

@export var interact_distance: float = 3.4

@onready var _ray: RayCast3D = $"../Head/Camera3D/InteractionRay"

var current_target: Interactable = null


func _physics_process(_delta: float) -> void:
	if InventoryManager.is_open:
		if current_target:
			current_target.set_highlighted(false)
			current_target = null
			focus_changed.emit(null)
		return

	_update_focus()

	if Input.is_action_just_pressed("interact") and current_target:
		current_target.interact(get_parent())


func _update_focus() -> void:
	var new_target: Interactable = null

	if _ray.is_colliding():
		new_target = _find_interactable(_ray.get_collider())

	if new_target != current_target:
		if current_target:
			current_target.set_highlighted(false)
		current_target = new_target
		if current_target:
			current_target.set_highlighted(true)
		focus_changed.emit(current_target)


func _find_interactable(node: Node) -> Interactable:
	var current: Node = node
	while current:
		if current is Interactable:
			return current as Interactable
		current = current.get_parent()
	return null
