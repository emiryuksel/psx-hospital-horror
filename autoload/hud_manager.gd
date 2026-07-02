# HUD köprüsü — SubViewport dışındaki native UI ile player sistemlerini bağlar.
extends Node

var _hud: CanvasLayer = null

# Son kullanılan input cihazı: false = klavye/fare, true = gamepad.
# Prompt ve ipuçlarında doğru tuş etiketini (E vs A, TAB vs MENU) göstermek için.
var using_gamepad: bool = false
var _last_prompt_text: String = ""
var _prompt_active: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _input(event: InputEvent) -> void:
	var was_gamepad := using_gamepad
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		# Küçük stick/trigger gürültüsünü yok say.
		if event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) < 0.5:
			return
		using_gamepad = true
	elif event is InputEventKey or event is InputEventMouseButton or event is InputEventMouseMotion:
		using_gamepad = false
	if was_gamepad != using_gamepad and _prompt_active:
		# Aktif prompt varken cihaz değişirse etiketi güncelle.
		show_prompt(_last_prompt_text)


# Etkileşim tuşu etiketi — gamepad'de "A", klavyede "E".
func interact_hint() -> String:
	return "A" if using_gamepad else "E"


# Envanter tuşu etiketi — gamepad'de "MENU", klavyede "TAB".
func inventory_hint() -> String:
	return "MENU" if using_gamepad else "TAB"


func register(hud: CanvasLayer) -> void:
	_hud = hud


func show_prompt(text: String) -> void:
	_last_prompt_text = text
	_prompt_active = true
	if _hud:
		_hud.show_prompt(text, interact_hint())


func show_message(text: String) -> void:
	if _hud:
		_hud.show_message(text)


func show_hint(text: String, duration: float = 4.5) -> void:
	if _hud and _hud.has_method("show_hint"):
		_hud.show_hint(text, duration)
	elif _hud:
		_hud.show_message(text)


func hide_prompt() -> void:
	_prompt_active = false
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


func update_objective(text: String, animated: bool = false) -> void:
	if _hud:
		_hud.update_objective(text, animated)


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


func set_gameplay_hud_visible(visible: bool) -> void:
	if _hud and _hud.has_method("set_gameplay_hud_visible"):
		_hud.set_gameplay_hud_visible(visible)


func fade_to_black(duration: float = 0.9, done: Callable = Callable()) -> void:
	if _hud and _hud.has_method("fade_to_black"):
		_hud.fade_to_black(duration, done)
	elif done.is_valid():
		done.call()


func fade_from_black(duration: float = 0.9, done: Callable = Callable()) -> void:
	if _hud and _hud.has_method("fade_from_black"):
		_hud.fade_from_black(duration, done)
	elif done.is_valid():
		done.call()


func show_end_card(done: Callable = Callable()) -> void:
	if _hud and _hud.has_method("show_end_card"):
		_hud.show_end_card(done)
	elif done.is_valid():
		done.call()
