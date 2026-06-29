# İç ses / monolog sistemi — tek seferlik trigger'lar + subtitle (FAZ 7).
extends Node

const DISPLAY_DURATION := 5.5

const POOLS: Dictionary = {
	"wake_up": [
		"Where— no. I know this hallway. I don't know how.",
		"My head feels like a tape rewound too far. Names won't stick.",
		"The air tastes like copper and rain. When did hospitals smell like that?",
		"Lights are on. Nobody's here. That's worse than darkness.",
		"I should leave. The doors are right there. …Why can't I remember leaving before?",
	],
	"first_enemy": [
		"The mist — it's inside now. It brought something with it.",
		"That shape isn't human anymore. Was it ever?",
		"Run. Don't look back. It doesn't need eyes to find you.",
		"The note said 'don't take the fuse.' Now I know why.",
		"It smells like copper and ozone. Like the air before lightning.",
	],
	"found_weapon": [
		"Someone's pistol… this'll help. If anything still bleeds in here.",
		"Six rounds, maybe. Against whatever's in the mist, it'll have to do.",
		"The grip's still warm. I don't want to know why.",
	],
	"found_flashlight": [
		"A flashlight. Still has charge. Now I can see what's out there.",
		"Finally, some light. Though maybe I don't want to see what's hiding.",
	],
	"exit_locked": [
		"Locked. No power — I need to restore the breaker.",
		"Dead bolt won't budge. The whole building's run dry. Find the fuse.",
		"No current, no exit. The breaker downstairs… that's my way out.",
	],
	"lore_major": [
		"This name on the chart… that's not possible. I was never admitted.",
		"The dates don't line up. Nothing here lines up— except my handwriting.",
		"Someone wanted this found. Or someone wanted me to find it.",
		"If I remember this place, why does the map feel new?",
		"The note says 'deceased.' The ink's still wet. Which is the lie?",
	],
	"health_critical": [
		"Breathe. Just breathe. You don't need much blood to keep moving.",
		"Not here. Not in a hallway I might've died in already.",
		"Cold starting at the edges. Is that shock— or the mist?",
		"If I fall, will I wake up in another room with no memory?",
		"Hurts. Good. Pain means the story isn't finished yet.",
	],
	"safe_zone": [
		"Quiet. Too quiet. Like the building's holding its breath.",
		"I could rest here. I shouldn't trust anywhere that feels safe.",
		"Coffee's still warm. Someone was here seconds ago. Or years.",
		"Lock the door. Locks never held anything in this place.",
		"For a second, I almost remember why I came back.",
	],
	"memory_glitch": [
		"I remember her voice. I don't remember her face. Which did I lose first?",
		"I wasn't here. I was here. Both feel true and both feel like lies.",
		"The photo proves I was standing right there. I don't remember the camera.",
		"They said I died on the 13th. Today's the 14th. …Is it?",
		"Maybe I'm not trying to escape. Maybe I'm trying to remember how to stay.",
	],
}

var _fired: Dictionary = {}
var _active_tween: Tween = null


func trigger(trigger_id: String, force: bool = false) -> void:
	if not force and _fired.get(trigger_id, false):
		return
	if not POOLS.has(trigger_id):
		push_warning("InnerVoiceManager: bilinmeyen trigger '%s'" % trigger_id)
		return

	_fired[trigger_id] = true
	var lines: Array = POOLS[trigger_id]
	var line: String = lines[randi() % lines.size()]
	_show_line(line)


func has_fired(trigger_id: String) -> bool:
	return _fired.get(trigger_id, false)


func get_save_data() -> Dictionary:
	return {"fired": _fired.keys()}


func apply_save_data(data: Dictionary) -> void:
	_fired.clear()
	for trigger_id in data.get("fired", []):
		_fired[str(trigger_id)] = true


func _show_line(text: String) -> void:
	if _active_tween and is_instance_valid(_active_tween):
		_active_tween.kill()

	HudManager.show_inner_voice(text)
	_active_tween = create_tween()
	_active_tween.tween_interval(DISPLAY_DURATION)
	_active_tween.tween_callback(func() -> void: HudManager.hide_inner_voice())
