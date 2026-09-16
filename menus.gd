class_name Menus
extends Control

## Start / Settings (+Sound sub-page) / Pause / Game-Over / Help screens.
## Every screen is built on demand into one shared glass-backed panel — see
## global CLAUDE.md's "Menü-Optik" convention (frosted glass, framed panel,
## 56px touch targets, D-pad/gamepad-aware help, mute button visible in the
## help illustration).

signal play_pressed
signal resume_pressed
signal restart_pressed
signal quit_to_menu_pressed
signal settings_changed(cfg: Dictionary)

enum Screen { NONE, START, SETTINGS, SOUND, PAUSE, GAMEOVER, HELP }

const DESIGN_WIDTH := FieldGrid.DESIGN_WIDTH
const DESIGN_HEIGHT := FieldGrid.DESIGN_HEIGHT
const PANEL_W := 460.0
const BTN_H := 56.0
const GAP := 12

var screen: int = Screen.NONE
var _return_screen: int = Screen.START
var _touch := false
var _cfg := {}
var _help_page := 0
const HELP_PAGES := 2

var _panel: PanelContainer
var _vbox: VBoxContainer

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var g := UiStyle.make_glass_backdrop()
	add_child(g.backbuffer)
	add_child(g.glass)
	g.glass.visible = false
	set_meta("glass", g.glass)

	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.add_theme_stylebox_override("panel", UiStyle.panel_style())
	_panel.custom_minimum_size = Vector2(PANEL_W, 0)
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	_panel.add_child(margin)

	_vbox = VBoxContainer.new()
	_vbox.add_theme_constant_override("separation", GAP)
	margin.add_child(_vbox)

	_cfg = GameSettings.load_all()
	hide_all()

func set_touch_context(t: bool) -> void:
	_touch = t

func set_cabinet_lane(active: bool, offset_x: float) -> void:
	if active:
		set_anchors_preset(Control.PRESET_TOP_LEFT)
		size = Vector2(DESIGN_WIDTH, DESIGN_HEIGHT)
		position = Vector2(offset_x, 0.0)
	else:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		position = Vector2.ZERO

func is_open() -> bool:
	return screen != Screen.NONE

func hide_all() -> void:
	screen = Screen.NONE
	visible = false
	get_meta("glass").visible = false
	var snd := get_node_or_null("/root/Snd")
	if snd:
		snd.stop_preview()

func _show_screen(s: int) -> void:
	screen = s
	visible = true
	get_meta("glass").visible = true
	for c in _vbox.get_children():
		c.queue_free()
	match s:
		Screen.START:
			_build_start()
		Screen.SETTINGS:
			_build_settings()
		Screen.SOUND:
			_build_sound()
		Screen.PAUSE:
			_build_pause()
		Screen.GAMEOVER:
			_build_gameover()
		Screen.HELP:
			_build_help()
	_recenter_panel.call_deferred()
	_focus_first.call_deferred()

func _recenter_panel() -> void:
	var sz: Vector2 = _panel.get_combined_minimum_size()
	sz.x = maxf(sz.x, PANEL_W)
	_panel.size = sz
	var y := maxf(10.0, (DESIGN_HEIGHT - sz.y) * 0.5)
	_panel.position = Vector2((DESIGN_WIDTH - sz.x) * 0.5, y)

func _focus_first() -> void:
	for c in _vbox.get_children():
		if c is Button:
			c.grab_focus()
			return

func show_start() -> void:
	_show_screen(Screen.START)

func show_pause() -> void:
	_show_screen(Screen.PAUSE)

func show_gameover(score: int, is_highscore: bool) -> void:
	set_meta("go_score", score)
	set_meta("go_hi", is_highscore)
	_show_screen(Screen.GAMEOVER)

# ---------------------------------------------------------------- widgets --
func _heading(text: String) -> Label:
	var l := UiStyle.heading(text, 30)
	UiStyle.impact_label(l)
	return l

func _button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, BTN_H)
	b.focus_mode = Control.FOCUS_ALL
	UiStyle.style_button(b)
	return b

func _hint(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 16)
	l.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	return l

func _row(label_text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, BTN_H)
	var l := Label.new()
	l.text = label_text
	l.custom_minimum_size = Vector2(180, 0)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", Color.WHITE)
	row.add_child(l)
	return row

func _stepper(row: HBoxContainer, get_val: Callable, set_val: Callable, fmt: Callable) -> void:
	var minus := _button("-")
	minus.custom_minimum_size = Vector2(BTN_H, BTN_H)
	var val_l := Label.new()
	val_l.custom_minimum_size = Vector2(110, 0)
	val_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	val_l.add_theme_color_override("font_color", UiStyle.ACCENT)
	var plus := _button("+")
	plus.custom_minimum_size = Vector2(BTN_H, BTN_H)
	var refresh := func():
		val_l.text = fmt.call(get_val.call())
	minus.pressed.connect(func():
		set_val.call(-1)
		refresh.call())
	plus.pressed.connect(func():
		set_val.call(1)
		refresh.call())
	refresh.call()
	row.add_child(minus)
	row.add_child(val_l)
	row.add_child(plus)

# ----------------------------------------------------------------- start --
func _build_start() -> void:
	_vbox.add_child(_heading("CENTIPEDE"))
	_vbox.add_child(_hint("Shoot the centipede as it winds down\nthrough the mushroom field."))
	var play := _button("Play")
	play.pressed.connect(func():
		hide_all()
		play_pressed.emit())
	_vbox.add_child(play)
	var settings := _button("Settings")
	settings.pressed.connect(func():
		_return_screen = Screen.START
		_show_screen(Screen.SETTINGS))
	_vbox.add_child(settings)
	var help := _button("How to Play")
	help.pressed.connect(func():
		_return_screen = Screen.START
		_help_page = 0
		_show_screen(Screen.HELP))
	_vbox.add_child(help)
	if not OS.has_feature("web"):
		var quit := _button("Exit")
		quit.pressed.connect(func(): get_tree().quit())
		_vbox.add_child(quit)

# ----------------------------------------------------------------- pause --
func _build_pause() -> void:
	_vbox.add_child(_heading("PAUSED"))
	var resume := _button("Resume")
	resume.pressed.connect(func():
		hide_all()
		resume_pressed.emit())
	_vbox.add_child(resume)
	var settings := _button("Settings")
	settings.pressed.connect(func():
		_return_screen = Screen.PAUSE
		_show_screen(Screen.SETTINGS))
	_vbox.add_child(settings)
	var help := _button("How to Play")
	help.pressed.connect(func():
		_return_screen = Screen.PAUSE
		_help_page = 0
		_show_screen(Screen.HELP))
	_vbox.add_child(help)
	var restart := _button("Restart")
	restart.pressed.connect(func():
		hide_all()
		restart_pressed.emit())
	_vbox.add_child(restart)
	var menu := _button("Main Menu")
	menu.pressed.connect(func():
		hide_all()
		quit_to_menu_pressed.emit())
	_vbox.add_child(menu)
	if not OS.has_feature("web"):
		var quit := _button("Exit")
		quit.pressed.connect(func(): get_tree().quit())
		_vbox.add_child(quit)

# -------------------------------------------------------------- gameover --
func _build_gameover() -> void:
	var score: int = get_meta("go_score", 0)
	var hi: bool = get_meta("go_hi", false)
	_vbox.add_child(_heading("GAME OVER"))
	var score_l := Label.new()
	score_l.text = ("New High Score: %06d!" % score) if hi else ("Score: %06d" % score)
	score_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_l.add_theme_font_size_override("font_size", 22)
	score_l.add_theme_color_override("font_color", UiStyle.ACCENT if hi else Color.WHITE)
	_vbox.add_child(score_l)
	var again := _button("Play Again")
	again.pressed.connect(func():
		hide_all()
		restart_pressed.emit())
	_vbox.add_child(again)
	var menu := _button("Main Menu")
	menu.pressed.connect(func():
		hide_all()
		quit_to_menu_pressed.emit())
	_vbox.add_child(menu)
	if not OS.has_feature("web"):
		var quit := _button("Exit")
		quit.pressed.connect(func(): get_tree().quit())
		_vbox.add_child(quit)

# -------------------------------------------------------------- settings --
func _build_settings() -> void:
	_vbox.add_child(_heading("SETTINGS"))

	var lives_row := _row("Lives")
	_stepper(lives_row,
		func(): return _cfg.lives,
		func(d): _set_cfg("lives", clampi(_cfg.lives + d, GameSettings.LIVES_MIN, GameSettings.LIVES_MAX)),
		func(v): return str(v))
	_vbox.add_child(lives_row)

	var zone_row := _row("Movement area")
	_stepper(zone_row,
		func(): return _cfg.movement_zone,
		func(d): _set_cfg("movement_zone", posmod(_cfg.movement_zone + d, GameSettings.ZONE_NAMES.size())),
		func(v): return GameSettings.ZONE_NAMES[v])
	_vbox.add_child(zone_row)

	var diff_row := _row("Difficulty")
	_stepper(diff_row,
		func(): return _cfg.difficulty,
		func(d): _set_cfg("difficulty", posmod(_cfg.difficulty + d, GameSettings.DIFF_NAMES.size())),
		func(v): return GameSettings.DIFF_NAMES[v])
	_vbox.add_child(diff_row)

	var sound := _button("Sound")
	sound.pressed.connect(func(): _show_screen(Screen.SOUND))
	_vbox.add_child(sound)

	var back := _button("Back")
	back.pressed.connect(func(): _show_screen(_return_screen))
	_vbox.add_child(back)

func _set_cfg(key: String, value) -> void:
	_cfg[key] = value
	GameSettings.save(_cfg)
	settings_changed.emit(_cfg)

# ----------------------------------------------------------------- sound --
func _build_sound() -> void:
	_vbox.add_child(_heading("SOUND"))
	var snd := get_node_or_null("/root/Snd")
	if snd == null:
		_vbox.add_child(_hint("Sound manager unavailable."))
	else:
		var mute_row := _row("Mute all")
		var mute_btn := _button("Muted" if snd.is_muted() else "On")
		mute_btn.custom_minimum_size = Vector2(140, BTN_H)
		mute_btn.pressed.connect(func():
			var m: bool = snd.toggle_mute()
			mute_btn.text = "Muted" if m else "On")
		mute_row.add_child(mute_btn)
		_vbox.add_child(mute_row)
		for key in snd.ORDER:
			_vbox.add_child(_sound_row(snd, key))
	var back := _button("Back")
	back.pressed.connect(func(): _show_screen(Screen.SETTINGS))
	_vbox.add_child(back)

func _sound_row(snd: Node, key: String) -> HBoxContainer:
	var display: String = snd.SOUNDS[key][0]
	var row := _row(display)
	var minus := _button("-")
	minus.custom_minimum_size = Vector2(BTN_H, BTN_H)
	var val_l := Label.new()
	val_l.custom_minimum_size = Vector2(60, 0)
	val_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	val_l.add_theme_color_override("font_color", UiStyle.ACCENT)
	var plus := _button("+")
	plus.custom_minimum_size = Vector2(BTN_H, BTN_H)
	var refresh := func(): val_l.text = "%d%%" % snd.get_volume(key)
	var change := func(d: int):
		snd.set_volume(key, snd.get_volume(key) + d)
		refresh.call()
		snd.preview_exclusive(key)
	minus.pressed.connect(func(): change.call(-10))
	plus.pressed.connect(func(): change.call(10))
	refresh.call()
	row.add_child(minus)
	row.add_child(val_l)
	row.add_child(plus)
	return row

# ------------------------------------------------------------------ help --
func _build_help() -> void:
	_vbox.add_child(_heading("HOW TO PLAY"))
	var diagram := Control.new()
	diagram.custom_minimum_size = Vector2(PANEL_W - 40, 240)
	diagram.set_script(load("res://help_diagram.gd"))
	diagram.set("page", _help_page)
	_vbox.add_child(diagram)

	if _help_page == 0:
		_vbox.add_child(_hint(
			"Move: arrows / WASD / D-pad / drag with mouse or finger.\n" +
			"Shoot: Space / left click / gamepad A / Fire button.\n" +
			"Pause: P or Esc. Mute: M or gamepad Select."))
	else:
		_vbox.add_child(_hint(
			"Clear the centipede as it zig-zags down through the\n" +
			"mushrooms. Shooting a body segment splits the train and\n" +
			"leaves a mushroom behind. The spider bounces through the\n" +
			"lower field — shoot it for a big bonus, but don't let it\n" +
			"(or the centipede) touch you.\n" +
			"Tip: mute/unmute with the speaker button next to Pause,\n" +
			"or press M / D-pad Select."))

	var nav := HBoxContainer.new()
	nav.alignment = BoxContainer.ALIGNMENT_CENTER
	var prev := _button("< Prev")
	prev.disabled = _help_page == 0
	prev.pressed.connect(func(): _turn_help(-1))
	var next := _button("Next >")
	next.disabled = _help_page >= HELP_PAGES - 1
	next.pressed.connect(func(): _turn_help(1))
	nav.add_child(prev)
	nav.add_child(next)
	_vbox.add_child(nav)

	var back := _button("Back")
	back.pressed.connect(func(): _show_screen(_return_screen))
	_vbox.add_child(back)

func _turn_help(d: int) -> void:
	_help_page = clampi(_help_page + d, 0, HELP_PAGES - 1)
	for c in _vbox.get_children():
		c.queue_free()
	_build_help()
	_recenter_panel.call_deferred()
	_focus_first.call_deferred()

# ---------------------------------------------------------------- input --
func _unhandled_input(event: InputEvent) -> void:
	if not is_open():
		return
	if event.is_action_pressed("ui_cancel"):
		match screen:
			Screen.SETTINGS, Screen.HELP:
				_show_screen(_return_screen)
			Screen.SOUND:
				_show_screen(Screen.SETTINGS)
			Screen.PAUSE:
				hide_all()
				resume_pressed.emit()
		get_viewport().set_input_as_handled()
	elif screen == Screen.HELP:
		if event.is_action_pressed("ui_right"):
			_turn_help(1)
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_left"):
			_turn_help(-1)
			get_viewport().set_input_as_handled()
