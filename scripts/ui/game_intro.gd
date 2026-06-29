# NEW GAME açılış sekansı — konum kartı + bölüm başlığı.
extends CanvasLayer

signal finished

const TITLE_SLAM_SCALE := Vector2(1.32, 1.32)

@onready var _black: ColorRect = $Root/Black
@onready var _location: Control = $Root/LocationAnchor/LocationVBox
@onready var _chapter_root: Control = $Root/ChapterRoot
@onready var _part_label: Label = $Root/ChapterRoot/VBox/PartLabel
@onready var _subtitle_label: Label = $Root/ChapterRoot/VBox/SubtitleLabel

var _playing: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_reset_visuals()


func play() -> void:
	if _playing:
		return
	_playing = true
	_reset_visuals()
	visible = true
	await _run_sequence()
	_playing = false
	visible = false
	finished.emit()


func _reset_visuals() -> void:
	_black.color = Color(0.0, 0.0, 0.0, 1.0)
	_location.modulate.a = 0.0
	_chapter_root.modulate.a = 0.0
	_part_label.scale = Vector2.ONE
	_part_label.modulate = Color(1.0, 1.0, 1.0, 1.0)
	_subtitle_label.modulate.a = 0.0


func _run_sequence() -> void:
	# Aşama 1 — konum kartı
	var fade_in := create_tween()
	fade_in.set_ease(Tween.EASE_OUT)
	fade_in.set_trans(Tween.TRANS_SINE)
	fade_in.tween_property(_location, "modulate:a", 1.0, 1.0)
	await fade_in.finished
	await get_tree().create_timer(3.0).timeout

	var fade_location := create_tween()
	fade_location.set_ease(Tween.EASE_IN)
	fade_location.set_trans(Tween.TRANS_SINE)
	fade_location.tween_property(_location, "modulate:a", 0.0, 0.6)

	var fade_black := create_tween()
	fade_black.set_ease(Tween.EASE_IN_OUT)
	fade_black.set_trans(Tween.TRANS_SINE)
	fade_black.tween_property(_black, "color:a", 0.0, 1.2)
	await fade_black.finished

	# Aşama 2 — kalın nota + PART I impact
	await _play_chapter_title()


func _play_chapter_title() -> void:
	await get_tree().process_frame
	_cache_title_pivots()

	_black.color = Color(0.0, 0.0, 0.0, 0.78)
	_chapter_root.modulate.a = 1.0
	_part_label.scale = TITLE_SLAM_SCALE
	_subtitle_label.modulate.a = 0.0

	AudioManager.play_chapter_sting()

	var slam := create_tween()
	slam.set_ease(Tween.EASE_OUT)
	slam.set_trans(Tween.TRANS_EXPO)
	slam.tween_property(_part_label, "scale", Vector2.ONE, 0.55)

	var subtitle_in := create_tween()
	subtitle_in.set_ease(Tween.EASE_OUT)
	subtitle_in.set_trans(Tween.TRANS_SINE)
	subtitle_in.tween_property(_subtitle_label, "modulate:a", 1.0, 0.5).set_delay(0.45)

	await get_tree().create_timer(3.2).timeout

	var title_out := create_tween()
	title_out.set_ease(Tween.EASE_IN)
	title_out.set_trans(Tween.TRANS_SINE)
	title_out.parallel().tween_property(_chapter_root, "modulate:a", 0.0, 1.0)
	title_out.parallel().tween_property(_black, "color:a", 0.0, 1.0)
	await title_out.finished


func _cache_title_pivots() -> void:
	_part_label.pivot_offset = _part_label.size * 0.5
	_subtitle_label.pivot_offset = _subtitle_label.size * 0.5
