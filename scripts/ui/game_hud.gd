# Etkileşim prompt, crosshair, ammo ve game over UI.
extends CanvasLayer

@onready var _prompt_label: Label = $PromptLabel
@onready var _crosshair: Label = $Crosshair
@onready var _ammo_label: Label = $AmmoLabel
@onready var _weapon_label: Label = $WeaponLabel
@onready var _reload_bar: ProgressBar = $ReloadBar
@onready var _game_over_panel: PanelContainer = $GameOverPanel
@onready var _stamina_bar: ProgressBar = $MarginContainer/VBox/StaminaBar
@onready var _battery_bar: ProgressBar = $MarginContainer/VBox/BatteryBar
@onready var _health_bar: ProgressBar = $MarginContainer/VBox/HealthBar


func _ready() -> void:
	if not _validate_nodes():
		return
	hide_prompt()
	_reload_bar.visible = false
	_game_over_panel.visible = false
	update_weapon_label(1)


func _validate_nodes() -> bool:
	var ok := true
	if _ammo_label == null:
		push_error("GameHUD: AmmoLabel bulunamadı.")
		ok = false
	if _crosshair == null:
		push_error("GameHUD: Crosshair bulunamadı.")
		ok = false
	return ok


func show_prompt(text: String, key_label: String = "E") -> void:
	_prompt_label.text = "[%s] %s" % [key_label, text]
	_prompt_label.visible = true


func hide_prompt() -> void:
	_prompt_label.visible = false


func set_crosshair_state(weapon_mode: int, is_aiming: bool, is_reloading: bool) -> void:
	if is_reloading:
		_crosshair.modulate = Color(0.6, 0.6, 0.6)
		_crosshair.add_theme_font_size_override("font_size", 10)
		return

	match weapon_mode:
		0:
			_crosshair.text = "×"
			_crosshair.add_theme_font_size_override("font_size", 14)
			_crosshair.modulate = Color(0.9, 0.85, 0.7, 0.9)
		1:
			if is_aiming:
				_crosshair.text = "+"
				_crosshair.add_theme_font_size_override("font_size", 10)
				_crosshair.modulate = Color(1.0, 0.95, 0.8, 0.95)
			else:
				_crosshair.text = "·"
				_crosshair.add_theme_font_size_override("font_size", 12)
				_crosshair.modulate = Color(1.0, 0.95, 0.8, 0.75)


func update_ammo(in_mag: int, reserve: int, weapon_mode: int) -> void:
	if _ammo_label == null:
		return
	if weapon_mode == 0:
		_ammo_label.text = "Knife"
	else:
		_ammo_label.text = "%d / %d" % [in_mag, reserve]


func update_weapon_label(weapon_mode: int) -> void:
	if _weapon_label == null:
		return
	_weapon_label.text = "Knife [1]" if weapon_mode == 0 else "Pistol [2]"


func show_reload_progress(progress: float) -> void:
	_reload_bar.visible = true
	_reload_bar.value = clampf(progress, 0.0, 1.0) * 100.0


func hide_reload_progress() -> void:
	_reload_bar.visible = false


func show_game_over() -> void:
	_game_over_panel.visible = true
	_crosshair.visible = false


func update_stamina(current: float, maximum: float) -> void:
	_stamina_bar.max_value = maximum
	_stamina_bar.value = current


func update_battery(current: float, maximum: float) -> void:
	_battery_bar.max_value = maximum
	_battery_bar.value = current


func update_health(current: float, maximum: float) -> void:
	_health_bar.max_value = maximum
	_health_bar.value = current
