# Native çözünürlükte HUD — statlar, crosshair, ammo (SubViewport dışında).
extends CanvasLayer

@onready var _prompt_label: Label = $PromptLabel
@onready var _crosshair: Label = $Crosshair
@onready var _ammo_label: Label = $WeaponPanel/Margin/VBox/AmmoLabel
@onready var _weapon_label: Label = $WeaponPanel/Margin/VBox/WeaponLabel
@onready var _weapon_panel: PanelContainer = $WeaponPanel
@onready var _reload_bar: ProgressBar = $ReloadBar
@onready var _game_over_panel: PanelContainer = $GameOverPanel
@onready var _game_over_load_btn: Button = $GameOverPanel/Center/VBox/BtnLoadSave
@onready var _game_over_retry_btn: Button = $GameOverPanel/Center/VBox/BtnRetry
@onready var _game_over_hint: Label = $GameOverPanel/Center/VBox/Hint
@onready var _health_row: HBoxContainer = $StatsPanel/Margin/VBox/HealthRow
@onready var _stamina_row: HBoxContainer = $StatsPanel/Margin/VBox/StaminaRow
@onready var _battery_row: HBoxContainer = $StatsPanel/Margin/VBox/BatteryRow
@onready var _stats_panel: PanelContainer = $StatsPanel
@onready var _inner_voice_panel: PanelContainer = $InnerVoicePanel
@onready var _inner_voice_label: Label = $InnerVoicePanel/Margin/InnerVoiceLabel
@onready var _objective_panel: PanelContainer = $ObjectivePanel
@onready var _objective_label: Label = $ObjectivePanel/Margin/ObjectiveLabel

const WEAPON_IDLE_TEX := "res://assets/textures/weapons/pistol_idle.png"
const WEAPON_FIRE_TEX := "res://assets/textures/weapons/pistol_fire.png"
const KNIFE_IDLE_TEX := "res://assets/textures/weapons/knife_idle.png"
const KNIFE_FIRE_TEX := "res://assets/textures/weapons/knife_fire.png"
const MUZZLE_TEX := "res://assets/textures/fx/muzzle_flash.png"
const VIGNETTE_TEX := "res://assets/textures/fx/damage_vignette.png"

# --- Piksel HUD gosterge ikonlari ---
const HUD_DIR := "res://assets/textures/hud/"
const HEART_COUNT := 5   # toplam kalp adedi (her kalp = max can / 5)
const BOLT_COUNT := 5    # toplam stamina simsegi
# Her kalp dolu/yarim/bos uc duruma sahip; ikon dokulari:
var _tex_heart_full: Texture2D = null
var _tex_heart_half: Texture2D = null
var _tex_heart_empty: Texture2D = null
var _tex_bolt_full: Texture2D = null
var _tex_bolt_empty: Texture2D = null
var _tex_battery := {}   # cells (0..3) -> Texture2D
var _heart_icons: Array[TextureRect] = []
var _bolt_icons: Array[TextureRect] = []
var _battery_icon: TextureRect = null

var _weapon_sprite: TextureRect
var _muzzle_flash: TextureRect
var _damage_overlay: ColorRect
var _vignette_overlay: TextureRect
var _weapon_idle_tex: Texture2D = null
var _weapon_fire_tex: Texture2D = null
var _knife_idle_tex: Texture2D = null
var _knife_fire_tex: Texture2D = null
var _active_weapon_mode: int = 1
var _weapon_base_pos: Vector2 = Vector2.ZERO
var _weapon_visible: bool = false
var _bob_time: float = 0.0
var _fire_tween: Tween = null
var _damage_tween: Tween = null
var _low_health: bool = false
var _weapon_anim_lock: bool = false
var _objective_tween: Tween = null
const _OBJECTIVE_REST_X := 10.0


func _ready() -> void:
	HudManager.register(self)
	_build_stat_icons()
	_build_weapon_viewmodel()
	_build_damage_overlay()
	_set_mouse_ignore(self, _game_over_panel)
	_configure_game_over_mouse()
	hide_prompt()
	_inner_voice_panel.visible = false
	_reload_bar.visible = false
	_game_over_panel.visible = false
	if _objective_panel:
		_objective_panel.visible = false
	if _game_over_load_btn:
		_game_over_load_btn.pressed.connect(_on_game_over_load_save)
	if _game_over_retry_btn:
		_game_over_retry_btn.pressed.connect(_on_game_over_retry)
	_weapon_panel.visible = false
	update_weapon_label(1)
	if GameSession.intro_pending:
		set_gameplay_hud_visible(false)
	call_deferred("_sync_initial_values")
	call_deferred("_sync_objective")


func set_gameplay_hud_visible(visible: bool) -> void:
	if _stats_panel:
		_stats_panel.visible = visible
	_crosshair.visible = visible
	_weapon_panel.visible = visible and _weapon_visible
	_reload_bar.visible = false
	if not visible:
		hide_prompt()
		if _objective_panel:
			_objective_panel.visible = false
		if _inner_voice_panel:
			_inner_voice_panel.visible = false
	elif _objective_label and not _objective_label.text.is_empty() and _objective_panel:
		_objective_panel.visible = true


# Sol-altta piksel gosterge ikonlari: kalpler (can), simsekler (stamina), pil (flashlight)
func _build_stat_icons() -> void:
	_tex_heart_full = _load_tex("heart_full.png")
	_tex_heart_half = _load_tex("heart_half.png")
	_tex_heart_empty = _load_tex("heart_empty.png")
	_tex_bolt_full = _load_tex("bolt_full.png")
	_tex_bolt_empty = _load_tex("bolt_empty.png")
	for cells in [0, 1, 2, 3]:
		_tex_battery[cells] = _load_tex("battery_%d.png" % cells)

	# Kalp satiri
	for i in HEART_COUNT:
		var heart := _make_icon(_tex_heart_full, Vector2(18, 18))
		_health_row.add_child(heart)
		_heart_icons.append(heart)

	# Stamina (simsek) satiri
	for i in BOLT_COUNT:
		var bolt := _make_icon(_tex_bolt_full, Vector2(14, 16))
		_stamina_row.add_child(bolt)
		_bolt_icons.append(bolt)

	# Pil (flashlight) satiri — tek ikon, dis sayisi degisir
	_battery_icon = _make_icon(_tex_battery.get(3, null), Vector2(40, 20))
	_battery_row.add_child(_battery_icon)


func _load_tex(file_name: String) -> Texture2D:
	var path := HUD_DIR + file_name
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null


func _make_icon(tex: Texture2D, size: Vector2) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	tr.custom_minimum_size = size
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if tex:
		tr.texture = tex
	return tr


# Ekranin sag-altinda elde tutulan silah sprite'i + muzzle flash (programatik, PSX nearest)
func _build_weapon_viewmodel() -> void:
	if ResourceLoader.exists(WEAPON_IDLE_TEX):
		_weapon_idle_tex = load(WEAPON_IDLE_TEX) as Texture2D
	if ResourceLoader.exists(WEAPON_FIRE_TEX):
		_weapon_fire_tex = load(WEAPON_FIRE_TEX) as Texture2D
	if ResourceLoader.exists(KNIFE_IDLE_TEX):
		_knife_idle_tex = load(KNIFE_IDLE_TEX) as Texture2D
	if ResourceLoader.exists(KNIFE_FIRE_TEX):
		_knife_fire_tex = load(KNIFE_FIRE_TEX) as Texture2D

	_weapon_sprite = TextureRect.new()
	_weapon_sprite.name = "WeaponSprite"
	_weapon_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_weapon_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_weapon_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	_weapon_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Sag-alt kose ankraji — orta boy, namlu ileriye-yukari acili
	_weapon_sprite.anchor_left = 1.0
	_weapon_sprite.anchor_top = 1.0
	_weapon_sprite.anchor_right = 1.0
	_weapon_sprite.anchor_bottom = 1.0
	_weapon_sprite.custom_minimum_size = Vector2(300, 216)
	_weapon_sprite.offset_left = -470.0
	_weapon_sprite.offset_top = -280.0
	_weapon_sprite.offset_right = -170.0
	_weapon_sprite.offset_bottom = -64.0
	if _weapon_idle_tex:
		_weapon_sprite.texture = _weapon_idle_tex
	else:
		# Fallback — placeholder sarimsi-gri renk modulate (asset gelene kadar)
		_weapon_sprite.modulate = Color(0.45, 0.45, 0.5, 0.0)
	_weapon_sprite.visible = false
	add_child(_weapon_sprite)
	_weapon_base_pos = Vector2(_weapon_sprite.offset_left, _weapon_sprite.offset_top)

	# Muzzle flash — namlu agzinda (sol-ust) kisa parlama
	_muzzle_flash = TextureRect.new()
	_muzzle_flash.name = "MuzzleFlash"
	_muzzle_flash.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_muzzle_flash.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_muzzle_flash.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	_muzzle_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_muzzle_flash.anchor_left = 1.0
	_muzzle_flash.anchor_top = 1.0
	_muzzle_flash.anchor_right = 1.0
	_muzzle_flash.anchor_bottom = 1.0
	_muzzle_flash.custom_minimum_size = Vector2(96, 96)
	_muzzle_flash.offset_left = -482.0
	_muzzle_flash.offset_top = -262.0
	_muzzle_flash.offset_right = -386.0
	_muzzle_flash.offset_bottom = -166.0
	if ResourceLoader.exists(MUZZLE_TEX):
		_muzzle_flash.texture = load(MUZZLE_TEX) as Texture2D
	else:
		# Fallback — duz parlak sari blok
		var ph := ColorRect.new()
		ph.color = Color(1.0, 0.92, 0.55)
		ph.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		ph.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_muzzle_flash.add_child(ph)
	_muzzle_flash.modulate.a = 0.0
	_muzzle_flash.visible = false
	add_child(_muzzle_flash)


# Tam ekran hasar overlay (kirmizi) + opsiyonel kenar vinyet
func _build_damage_overlay() -> void:
	_damage_overlay = ColorRect.new()
	_damage_overlay.name = "DamageOverlay"
	_damage_overlay.color = Color(0.6, 0.0, 0.0, 0.0)
	_damage_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_damage_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_damage_overlay)

	if ResourceLoader.exists(VIGNETTE_TEX):
		_vignette_overlay = TextureRect.new()
		_vignette_overlay.name = "DamageVignette"
		_vignette_overlay.texture = load(VIGNETTE_TEX) as Texture2D
		_vignette_overlay.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_vignette_overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_vignette_overlay.stretch_mode = TextureRect.STRETCH_SCALE
		_vignette_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_vignette_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_vignette_overlay.modulate = Color(1.0, 1.0, 1.0, 0.0)
		add_child(_vignette_overlay)


func _process(delta: float) -> void:
	if not _weapon_visible or _weapon_sprite == null or _weapon_anim_lock:
		return
	# Hafif idle bob — sinus salinim (oyun duraklatildiginda calismaz)
	_bob_time += delta
	var bob_x := sin(_bob_time * 1.8) * 4.0
	var bob_y := sin(_bob_time * 3.6) * 3.0
	_weapon_sprite.offset_left = _weapon_base_pos.x + bob_x
	_weapon_sprite.offset_top = _weapon_base_pos.y + bob_y


func _current_idle_tex() -> Texture2D:
	if _active_weapon_mode == 0:
		return _knife_idle_tex if _knife_idle_tex else _weapon_idle_tex
	return _weapon_idle_tex


func _current_fire_tex() -> Texture2D:
	if _active_weapon_mode == 0:
		return _knife_fire_tex if _knife_fire_tex else _weapon_fire_tex
	return _weapon_fire_tex


func show_weapon_viewmodel(weapon_mode: int) -> void:
	if _weapon_sprite == null:
		return
	_active_weapon_mode = weapon_mode
	_weapon_visible = true
	_weapon_sprite.visible = true
	var idle := _current_idle_tex()
	if idle:
		_weapon_sprite.texture = idle
		_weapon_sprite.modulate.a = 1.0
	else:
		_weapon_sprite.modulate.a = 0.85


func hide_weapon_viewmodel() -> void:
	_weapon_visible = false
	if _weapon_sprite:
		_weapon_sprite.visible = false


# Silah edinildiginde sag-alt mermi panelini goster, kaybedilince gizle.
func set_weapon_acquired(acquired: bool) -> void:
	if _weapon_panel:
		_weapon_panel.visible = acquired


func play_fire_animation() -> void:
	if _weapon_sprite == null or not _weapon_visible:
		return

	# Frame swap — fire frame'ine gec
	var fire_tex := _current_fire_tex()
	if fire_tex:
		_weapon_sprite.texture = fire_tex

	# Muzzle flash sadece ates eden silah (pistol) icin
	if _muzzle_flash:
		_muzzle_flash.visible = _active_weapon_mode == 1
		_muzzle_flash.modulate.a = 1.0

	# Hafif recoil — sprite'i yukari/geri kaydir
	_weapon_base_pos.y += -14.0

	if _fire_tween and is_instance_valid(_fire_tween):
		_fire_tween.kill()
	_fire_tween = create_tween()
	_fire_tween.tween_interval(0.05)
	_fire_tween.tween_callback(func() -> void:
		if _muzzle_flash:
			_muzzle_flash.modulate.a = 0.0
			_muzzle_flash.visible = false
	)
	# Recoil'den idle pozisyona yumusak donus
	_fire_tween.tween_callback(func() -> void:
		_weapon_base_pos.y += 14.0
		var idle := _current_idle_tex()
		if idle:
			_weapon_sprite.texture = idle
	)


func play_melee_animation() -> void:
	if _weapon_sprite == null or not _weapon_visible:
		return

	var fire_tex := _current_fire_tex()
	if fire_tex:
		_weapon_sprite.texture = fire_tex

	if _fire_tween and is_instance_valid(_fire_tween):
		_fire_tween.kill()

	_weapon_anim_lock = true
	var base_x := _weapon_base_pos.x
	var base_y := _weapon_base_pos.y
	var thrust_x := 62.0
	var thrust_y := -26.0

	_weapon_sprite.offset_left = base_x + thrust_x
	_weapon_sprite.offset_top = base_y + thrust_y
	_weapon_sprite.rotation_degrees = -10.0

	_fire_tween = create_tween()
	_fire_tween.tween_interval(0.06)
	_fire_tween.tween_property(_weapon_sprite, "offset_left", base_x, 0.16).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_fire_tween.parallel().tween_property(_weapon_sprite, "offset_top", base_y, 0.16).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_fire_tween.parallel().tween_property(_weapon_sprite, "rotation_degrees", 0.0, 0.14)
	_fire_tween.tween_callback(func() -> void:
		_weapon_anim_lock = false
		var idle := _current_idle_tex()
		if idle and _weapon_sprite:
			_weapon_sprite.texture = idle
	)


func play_damage_feedback(intensity: float = 1.0) -> void:
	if _damage_overlay == null:
		return
	var peak := clampf(0.35 * intensity, 0.1, 0.6)
	if _damage_tween and is_instance_valid(_damage_tween):
		_damage_tween.kill()
	_damage_overlay.color.a = peak
	if _vignette_overlay:
		_vignette_overlay.modulate.a = clampf(0.7 * intensity, 0.2, 0.9)

	# Dusuk canda kalici hafif kirmizi ton, aksi halde 0'a in
	var rest_alpha := 0.16 if _low_health else 0.0
	var vig_rest := 0.28 if _low_health else 0.0
	_damage_tween = create_tween()
	_damage_tween.tween_property(_damage_overlay, "color:a", rest_alpha, 0.45)
	if _vignette_overlay:
		_damage_tween.parallel().tween_property(_vignette_overlay, "modulate:a", vig_rest, 0.45)


func play_jumpscare(intensity: float = 1.0) -> void:
	if _damage_overlay == null:
		return
	if _damage_tween and is_instance_valid(_damage_tween):
		_damage_tween.kill()

	var rest_alpha := 0.16 if _low_health else 0.0
	var vig_rest := 0.28 if _low_health else 0.0
	var peak := clampf(0.65 * intensity, 0.4, 0.85)

	# Beyaz flash — hasar kirmizisi kullanma, tamamen sönünce ekran normale dönsün.
	_damage_overlay.color = Color(0.92, 0.9, 0.86, peak)
	if _vignette_overlay:
		_vignette_overlay.modulate.a = clampf(0.45 * intensity, 0.25, 0.65)

	_damage_tween = create_tween()
	if intensity >= 1.4:
		_damage_tween.tween_property(_damage_overlay, "color:a", peak, 0.05)
		_damage_tween.tween_property(_damage_overlay, "color:a", peak * 0.25, 0.07)
		_damage_tween.tween_property(_damage_overlay, "color:a", peak * 0.92, 0.05)
	_damage_tween.tween_property(_damage_overlay, "color:a", rest_alpha, 0.42).set_ease(Tween.EASE_OUT)
	if _vignette_overlay:
		_damage_tween.parallel().tween_property(_vignette_overlay, "modulate:a", vig_rest, 0.48)
	_damage_tween.tween_callback(func() -> void:
		if _damage_overlay:
			_damage_overlay.color = Color(0.6, 0.0, 0.0, rest_alpha)
	)


# Dusuk can durumunu ayarla — kalici hafif kirmizi ton (heartbeat sistemiyle uyumlu)
func set_low_health(is_low: bool) -> void:
	if _low_health == is_low:
		return
	_low_health = is_low
	if _damage_overlay == null:
		return
	if _damage_tween and is_instance_valid(_damage_tween):
		return
	var rest_alpha := 0.16 if _low_health else 0.0
	var t := create_tween()
	t.tween_property(_damage_overlay, "color:a", rest_alpha, 0.5)
	if _vignette_overlay:
		var vig_rest := 0.28 if _low_health else 0.0
		t.parallel().tween_property(_vignette_overlay, "modulate:a", vig_rest, 0.5)


func _sync_objective() -> void:
	update_objective(QuestManager.get_objective_text())


func _set_mouse_ignore(node: Node, skip_root: Node = null) -> void:
	if _is_under_mouse_skip_root(node, skip_root):
		return
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_set_mouse_ignore(child, skip_root)


func _is_under_mouse_skip_root(node: Node, skip_root: Node) -> bool:
	if skip_root == null:
		return false
	var current: Node = node
	while current:
		if current == skip_root:
			return true
		current = current.get_parent()
	return false


func _configure_game_over_mouse() -> void:
	if _game_over_panel:
		_game_over_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	if _game_over_load_btn:
		_game_over_load_btn.mouse_filter = Control.MOUSE_FILTER_STOP
		_game_over_load_btn.focus_mode = Control.FOCUS_ALL
	if _game_over_retry_btn:
		_game_over_retry_btn.mouse_filter = Control.MOUSE_FILTER_STOP
		_game_over_retry_btn.focus_mode = Control.FOCUS_ALL


func _sync_initial_values() -> void:
	update_health(100.0, 100.0)
	update_stamina(50.0, 50.0)
	update_battery(100.0, 100.0)


func show_prompt(text: String) -> void:
	_prompt_label.text = "[E] %s" % text
	_prompt_label.visible = true


func show_message(text: String) -> void:
	_prompt_label.text = text
	_prompt_label.visible = true


func hide_prompt() -> void:
	_prompt_label.visible = false


func set_crosshair_state(weapon_mode: int, is_aiming: bool, is_reloading: bool) -> void:
	if is_reloading:
		_crosshair.modulate = Color(0.65, 0.65, 0.65)
		_crosshair.add_theme_font_size_override("font_size", 18)
		return

	match weapon_mode:
		0:
			_crosshair.text = "×"
			_crosshair.add_theme_font_size_override("font_size", 22)
			_crosshair.modulate = Color(0.92, 0.88, 0.72, 0.9)
		1:
			if is_aiming:
				_crosshair.text = "+"
				_crosshair.add_theme_font_size_override("font_size", 16)
				_crosshair.modulate = Color(1.0, 0.95, 0.82, 0.95)
			else:
				_crosshair.text = "·"
				_crosshair.add_theme_font_size_override("font_size", 20)
				_crosshair.modulate = Color(1.0, 0.95, 0.82, 0.8)


func update_ammo(in_mag: int, reserve: int, weapon_mode: int) -> void:
	if weapon_mode == 0:
		# Bicak — mermi yok
		_ammo_label.text = "—"
		_ammo_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.66))
	else:
		_ammo_label.text = "%d / %d" % [in_mag, reserve]
		# Sarjor bosken kirmizi uyari, dolu altin sari
		if in_mag <= 0:
			_ammo_label.add_theme_color_override("font_color", Color(0.9, 0.35, 0.3))
		else:
			_ammo_label.add_theme_color_override("font_color", Color(0.95, 0.78, 0.42))


func update_weapon_label(weapon_mode: int) -> void:
	_weapon_label.text = "KNIFE" if weapon_mode == 0 else "PISTOL"


func show_reload_progress(progress: float) -> void:
	_reload_bar.visible = true
	_reload_bar.value = clampf(progress, 0.0, 1.0) * 100.0


func hide_reload_progress() -> void:
	_reload_bar.visible = false


func show_game_over() -> void:
	_configure_game_over_mouse()
	if _game_over_panel.get_index() < get_child_count() - 1:
		move_child(_game_over_panel, -1)
	_game_over_panel.visible = true
	_crosshair.visible = false
	hide_prompt()
	_inner_voice_panel.visible = false
	_reload_bar.visible = false
	if _weapon_sprite:
		_weapon_sprite.visible = false
	if _weapon_panel:
		_weapon_panel.visible = false
	if _objective_label:
		_objective_label.visible = false
	if _objective_panel:
		_objective_panel.visible = false

	var has_save := SaveManager.has_save()
	if _game_over_load_btn:
		_game_over_load_btn.visible = has_save
		_game_over_load_btn.disabled = not has_save
	if _game_over_hint:
		_game_over_hint.text = (
			"Restore your last save to continue."
			if has_save
			else "No save found. Retry from the beginning of this scene."
		)
	if _game_over_load_btn and has_save:
		_game_over_load_btn.grab_focus()
	elif _game_over_retry_btn:
		_game_over_retry_btn.grab_focus()


func hide_game_over() -> void:
	_game_over_panel.visible = false
	_crosshair.visible = true
	if _objective_panel:
		_objective_panel.visible = true
	if _objective_label:
		_objective_label.visible = true


func _on_game_over_load_save() -> void:
	if not SaveManager.has_save():
		return
	AudioManager.play("ui_paper", -4.0)
	SaveManager.load_game()


func _on_game_over_retry() -> void:
	AudioManager.play("ui_paper", -4.0)
	get_tree().reload_current_scene()


func update_stamina(current: float, maximum: float) -> void:
	if _bolt_icons.is_empty():
		return
	var ratio := 0.0 if maximum <= 0.0 else clampf(current / maximum, 0.0, 1.0)
	# Stamina yarim simsek gostermez — esik tabanli dolu/sonuk
	var filled := int(ceil(ratio * BOLT_COUNT))
	for i in _bolt_icons.size():
		_bolt_icons[i].texture = _tex_bolt_full if i < filled else _tex_bolt_empty


func update_battery(current: float, maximum: float) -> void:
	if _battery_icon == null:
		return
	var ratio := 0.0 if maximum <= 0.0 else clampf(current / maximum, 0.0, 1.0)
	# 3 dis -> ust 3 esik: >%66 = 3, >%33 = 2, >%5 = 1, aksi 0
	var cells := 0
	if ratio > 0.66:
		cells = 3
	elif ratio > 0.33:
		cells = 2
	elif ratio > 0.05:
		cells = 1
	var tex: Texture2D = _tex_battery.get(cells, null)
	if tex:
		_battery_icon.texture = tex


func update_health(current: float, maximum: float) -> void:
	if not _heart_icons.is_empty() and maximum > 0.0:
		# Her kalp = max/HEART_COUNT can; sirayla full/half/empty
		var per_heart := maximum / float(HEART_COUNT)
		for i in _heart_icons.size():
			var heart_min := per_heart * i
			var fill := clampf((current - heart_min) / per_heart, 0.0, 1.0)
			if fill >= 0.75:
				_heart_icons[i].texture = _tex_heart_full
			elif fill >= 0.25:
				_heart_icons[i].texture = _tex_heart_half
			else:
				_heart_icons[i].texture = _tex_heart_empty
	# Dusuk can esigi — kalici hafif kirmizi overlay tonu
	set_low_health(maximum > 0.0 and current <= maximum * 0.25)


func show_inner_voice(text: String) -> void:
	_inner_voice_label.text = text
	_inner_voice_panel.visible = true
	_inner_voice_panel.modulate.a = 1.0


func hide_inner_voice() -> void:
	_inner_voice_panel.visible = false


func update_objective(text: String, animated: bool = false) -> void:
	if _objective_tween and is_instance_valid(_objective_tween):
		_objective_tween.kill()

	_objective_label.text = text
	if _objective_panel:
		_objective_panel.reset_size()
	if text.is_empty():
		if _objective_panel:
			_objective_panel.visible = false
		return

	if _objective_panel:
		_objective_panel.visible = true

	if not animated:
		if _objective_panel:
			_objective_panel.modulate.a = 1.0
			_objective_panel.position.x = _OBJECTIVE_REST_X
		return

	if _objective_panel:
		_objective_panel.modulate.a = 0.0
		_objective_panel.position.x = _OBJECTIVE_REST_X - 48.0
	_objective_tween = create_tween()
	_objective_tween.set_parallel(true)
	_objective_tween.tween_property(_objective_panel, "modulate:a", 1.0, 0.38)
	_objective_tween.tween_property(
		_objective_panel, "position:x", _OBJECTIVE_REST_X, 0.42
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
