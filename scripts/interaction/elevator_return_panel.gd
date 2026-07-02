# Part II bitiş asansörü — bodrum gücü geldikten sonra yukarı çıkış / Part III köprüsü.
extends Interactable

var _leaving: bool = false


func _ready() -> void:
	super._ready()
	prompt_text = "Call elevator"
	interacted.connect(_on_interacted)


func _on_interacted(_actor: Node3D) -> void:
	if _leaving:
		return

	if not QuestManager.basement_power_on:
		AudioManager.play_3d("door_locked", global_position, -2.0, 0.95, 1.0)
		InventoryManager.note_requested.emit(
			"The call button is dead.\nRestart the sub-generator to bring the car back.",
			"Elevator"
		)
		return

	_leaving = true
	AudioManager.play_3d("exit_open", global_position, -1.0)
	HudManager.show_message("The elevator rises...")
	QuestManager.complete_part2()

	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_method("play_camera_shake"):
		player.play_camera_shake(0.12, 1.4)

	get_tree().create_timer(1.0).timeout.connect(_finish, CONNECT_ONE_SHOT)


func _finish() -> void:
	# Ekranı karart, ardından credits/thank you kartı -> ana menü.
	HudManager.fade_to_black(1.2, func() -> void:
		GameSession.finish_part2_to_menu()
	)
