# Asansör paneli — güç geldikten sonra Part II'ye geçiş noktası.
extends Interactable

var _descending: bool = false


func _ready() -> void:
	super._ready()
	prompt_text = "Check elevator"
	interacted.connect(_on_interacted)


func _on_interacted(_actor: Node3D) -> void:
	if QuestManager.part1_state == QuestManager.Part1State.SEEK_ELEVATOR:
		if _descending:
			return
		_descending = true
		AudioManager.play_3d("exit_open", global_position, -1.0)
		HudManager.show_message("The elevator descends...")
		_play_descent()
		return

	if QuestManager.power_on:
		InventoryManager.note_requested.emit(
			"Elevator motors online. Basement access should be available now.",
			"Elevator Panel"
		)
	else:
		InventoryManager.note_requested.emit(
			"DEAD — NO POWER\n\nCheck the breaker panel on the west wall.",
			"Elevator Panel"
		)


# Asansör iniş sekansı — kısa kamera sarsıntısı + fade ile Part II'ye geçiş.
func _play_descent() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_method("play_camera_shake"):
		player.play_camera_shake(0.12, 1.4)
	AudioManager.play_3d("enemy_growl", global_position, -12.0, 0.6, 0.7)
	get_tree().create_timer(0.9).timeout.connect(func() -> void:
		QuestManager.begin_part2()
		GameSession.transition_to_level(GameSession.PART2_SCENE, 1.0, 1.2, "PART II", "T H E   B A S E M E N T")
	, CONNECT_ONE_SHOT)
