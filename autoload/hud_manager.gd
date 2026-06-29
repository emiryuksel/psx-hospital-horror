# HUD köprüsü — SubViewport dışındaki native UI ile player sistemlerini bağlar.
extends Node

var _hud: CanvasLayer = null


func register(hud: CanvasLayer) -> void:
	_hud = hud


func show_prompt(text: String) -> void:
	if _hud:
		_hud.show_prompt(text)


func show_message(text: String) -> void:
	if _hud:
		_hud.show_message(text)


func hide_prompt() -> void:
	if _hud:
		_hud.hide_prompt()


func update_health(current: float, maximum: float) -> void:
	if _hud:
		_hud.update_health(current, maximum)


func update_stamina(current: float, maximum: float) -> void:
	if _hud:
		_hud.update_stamina(current, maximum)


func update_battery(current: float, maximum: float) -> void:
	if _hud:
		_hud.update_battery(current, maximum)


func update_ammo(in_mag: int, reserve: int, weapon_mode: int) -> void:
	if _hud:
		_hud.update_ammo(in_mag, reserve, weapon_mode)


func update_weapon_label(weapon_mode: int) -> void:
	if _hud:
		_hud.update_weapon_label(weapon_mode)


func set_crosshair_state(weapon_mode: int, is_aiming: bool, is_reloading: bool) -> void:
	if _hud:
		_hud.set_crosshair_state(weapon_mode, is_aiming, is_reloading)


func show_reload_progress(progress: float) -> void:
	if _hud:
		_hud.show_reload_progress(progress)


func hide_reload_progress() -> void:
	if _hud:
		_hud.hide_reload_progress()


func show_game_over() -> void:
	if _hud:
		_hud.show_game_over()


func hide_game_over() -> void:
	if _hud:
		_hud.hide_game_over()


func show_inner_voice(text: String) -> void:
	if _hud:
		_hud.show_inner_voice(text)


func hide_inner_voice() -> void:
	if _hud:
		_hud.hide_inner_voice()


func update_objective(text: String) -> void:
	if _hud:
		_hud.update_objective(text)


func show_weapon_viewmodel(weapon_mode: int) -> void:
	if _hud:
		_hud.show_weapon_viewmodel(weapon_mode)


func hide_weapon_viewmodel() -> void:
	if _hud:
		_hud.hide_weapon_viewmodel()


func set_weapon_acquired(acquired: bool) -> void:
	if _hud and _hud.has_method("set_weapon_acquired"):
		_hud.set_weapon_acquired(acquired)


func play_fire_animation() -> void:
	if _hud:
		_hud.play_fire_animation()


func play_melee_animation() -> void:
	if _hud and _hud.has_method("play_melee_animation"):
		_hud.play_melee_animation()


func play_damage_feedback(intensity: float = 1.0) -> void:
	if _hud:
		_hud.play_damage_feedback(intensity)


func play_jumpscare(intensity: float = 1.0) -> void:
	if _hud and _hud.has_method("play_jumpscare"):
		_hud.play_jumpscare(intensity)
