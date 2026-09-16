class_name Menus
extends Control

## Start / Settings (+Sound sub-page) / Pause / Game-Over / High Scores / Help
## screens. Every screen is built on demand into one shared glass-backed
## panel — see global CLAUDE.md's "Menü-Optik" convention (frosted glass,
## framed panel, 56px touch targets, D-pad/gamepad-aware help) and its
## "Menü-Navigations-Konventionen" point (cancel-button tagging, focus wrap,
## help-page paging/wheel/dots, ScrollContainer for long lists), both first
## proven in galaga's menus.gd and generalized from there.

signal play_pressed
signal resume_pressed
signal restart_pressed
signal quit_to_menu_pressed
signal settings_changed(cfg: Dictionary)

enum Screen { NONE, START, SETTINGS, SOUND, PAUSE, GAMEOVER, HELP, HIGHSCORES }

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

## Image-based How-to-Play (like tetris'/galaga's ui.gd/menus.gd) — each page
## is a full illustration rendered from assets/help_src/<file>.svg (see that
## folder's render.sh) to assets/graphics/help/<file>.png, in centipede's own
## black/toxic-green/white palette. Two sets, matched to how the player is
## actually driving right now (see set_touch_context()): desktop gets
## separate keyboard/mouse pages, touch gets one combined drag/fire page —
## both share the "goal" page, which doesn't depend on input method.
const HELP_DIR := "res://assets/graphics/help/"
const HELP_DESKTOP := [
	{"file": "keyboard", "h": "Controls — Keyboard/Gamepad"},
	{"file": "mouse", "h": "Controls — Mouse"},
	{"file": "goal", "h": "Goal & Scoring"},
]
const HELP_TOUCH := [
	{"file": "touch", "h": "Controls — Touch"},
	{"file": "goal", "h": "Goal & Scoring"},
]

var _panel: PanelContainer
var _vbox: VBoxContainer
var _help_back_btn: Button
var _name_edit: LineEdit

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
	_rebuild()

## Re-populates _vbox for the CURRENT `screen` without touching visibility —
## used both by _show_screen() (screen just changed) and by in-place
## refreshes that must keep the same screen open (help paging, hall-of-fame
## name commit).
func _rebuild() -> void:
	_name_edit = null
	_help_back_btn = null
	# remove_child() (not just queue_free()) so the node is gone from the
	# tree IMMEDIATELY — otherwise a freshly-freed-but-not-yet-collected old
	# control could still turn up in this same frame's _focusable_controls()
	# scan (queue_free() only actually frees at end-of-frame idle time), get
	# grabbed as "first focusable", and then get freed out from under that
	# focus a moment later — which Godot resolves by clearing focus to null.
	# That silent clear was hard to tell apart from a genuine engine/window
	# focus-loss until traced with a live node count.
	for c in _vbox.get_children():
		_vbox.remove_child(c)
		c.queue_free()
	match screen:
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
		Screen.HIGHSCORES:
			_build_highscores()
	_recenter_panel.call_deferred()
	if screen == Screen.HELP:
		# Deliberately NOT the generic first-focusable-control default (which
		# would land on the "< Prev" button here) — see the global CLAUDE.md's
		# "Menü-Navigations-Konventionen": a focused button consumes
		# ui_left/ui_right for Godot's own focus-neighbor navigation before
		# _unhandled_input()'s paging ever sees the event, so landing on
		# "Prev" would make the first D-pad-right press only move focus to
		# "Next" instead of actually turning the page. Back has no focus
		# neighbor to its right, so paging works on the very first press.
		_help_back_btn.grab_focus.call_deferred()
	else:
		_focus_first.call_deferred()
	if screen != Screen.SOUND:
		_wrap_focus_vertically.call_deferred()

func _recenter_panel() -> void:
	var sz: Vector2 = _panel.get_combined_minimum_size()
	sz.x = maxf(sz.x, PANEL_W)
	_panel.size = sz
	var y := maxf(10.0, (DESIGN_HEIGHT - sz.y) * 0.5)
	_panel.position = Vector2((DESIGN_WIDTH - sz.x) * 0.5, y)

## Every enabled, focusable Control currently in the screen, in tree order
## (recursive — stepper rows and the help nav row nest their buttons inside
## an HBoxContainer, not directly under _vbox).
func _focusable_controls() -> Array[Control]:
	var list: Array[Control] = []
	for n in _vbox.find_children("*", "", true, false):
		if n is Control and n.visible and n.focus_mode != Control.FOCUS_NONE \
				and not (n is BaseButton and n.disabled):
			list.append(n)
	return list

func _focus_first() -> void:
	var list := _focusable_controls()
	if not list.is_empty():
		list[0].grab_focus()

## D-pad up on the first control / down on the last one WRAPS to the other
## end instead of Godot's built-in focus-neighbor system finding no
## geometric neighbor there and doing nothing. Skipped for Screen.SOUND (a
## long scrollable list where "first/last" isn't a stable, meaningful pair)
## and for screens with 2 or fewer controls (already each other's neighbor).
func _wrap_focus_vertically() -> void:
	var list := _focusable_controls()
	if list.size() <= 2:
		return
	var first := list[0]
	var last := list[-1]
	first.focus_neighbor_top = first.get_path_to(last)
	last.focus_neighbor_bottom = last.get_path_to(first)

func show_start() -> void:
	_show_screen(Screen.START)

func show_pause() -> void:
	_show_screen(Screen.PAUSE)

func show_gameover(score: int, wave: int) -> void:
	set_meta("go_score", score)
	set_meta("go_wave", wave)
	set_meta("go_committed", false)
	set_meta("go_highlight", -1)
	_show_screen(Screen.GAMEOVER)

func show_highscores(from: int) -> void:
	_return_screen = from
	_show_screen(Screen.HIGHSCORES)

# ---------------------------------------------------------------- widgets --
func _heading(text: String) -> Label:
	var l := UiStyle.heading(text, 30)
	UiStyle.impact_label(l)
	return l

## `is_cancel`: tags this button as the screen's "back"/"cancel" target for
## the gamepad's B (ui_cancel) — see _unhandled_input() below. Focusable
## (Godot's own Button default) so D-pad navigation and ui_accept work on it
## like any other button.
func _button(text: String, cb: Callable, is_cancel := false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, BTN_H)
	b.focus_mode = Control.FOCUS_ALL
	b.pressed.connect(cb)
	UiStyle.style_button(b)
	if is_cancel:
		b.set_meta("is_cancel", true)
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
	var val_l := Label.new()
	val_l.custom_minimum_size = Vector2(110, 0)
	val_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	val_l.add_theme_color_override("font_color", UiStyle.ACCENT)
	var refresh := func(): val_l.text = fmt.call(get_val.call())
	var minus := _button("-", func(): set_val.call(-1); refresh.call())
	minus.custom_minimum_size = Vector2(BTN_H, BTN_H)
	var plus := _button("+", func(): set_val.call(1); refresh.call())
	plus.custom_minimum_size = Vector2(BTN_H, BTN_H)
	refresh.call()
	row.add_child(minus)
	row.add_child(val_l)
	row.add_child(plus)

func _spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c

# ----------------------------------------------------------------- start --
func _build_start() -> void:
	_vbox.add_child(_heading("CENTIPEDE"))
	_vbox.add_child(_hint("Shoot the centipede as it winds down\nthrough the mushroom field."))
	_vbox.add_child(_button("Play", func():
		hide_all()
		play_pressed.emit()))
	_vbox.add_child(_button("Settings", func():
		_return_screen = Screen.START
		_show_screen(Screen.SETTINGS)))
	_vbox.add_child(_button("High Scores", func(): show_highscores(Screen.START)))
	_vbox.add_child(_button("How to Play", func():
		_return_screen = Screen.START
		_help_page = 0
		_show_screen(Screen.HELP)))
	if not OS.has_feature("web"):
		_vbox.add_child(_button("Exit", func(): get_tree().quit()))

# ----------------------------------------------------------------- pause --
func _build_pause() -> void:
	_vbox.add_child(_heading("PAUSED"))
	_vbox.add_child(_button("Resume", func():
		hide_all()
		resume_pressed.emit()))
	_vbox.add_child(_button("Settings", func():
		_return_screen = Screen.PAUSE
		_show_screen(Screen.SETTINGS)))
	_vbox.add_child(_button("High Scores", func(): show_highscores(Screen.PAUSE)))
	_vbox.add_child(_button("How to Play", func():
		_return_screen = Screen.PAUSE
		_help_page = 0
		_show_screen(Screen.HELP)))
	_vbox.add_child(_button("Restart", func():
		hide_all()
		restart_pressed.emit()))
	_vbox.add_child(_button("Main Menu", func():
		hide_all()
		quit_to_menu_pressed.emit()))
	if not OS.has_feature("web"):
		_vbox.add_child(_button("Exit", func(): get_tree().quit()))

# -------------------------------------------------------------- gameover --
func _build_gameover() -> void:
	var score: int = get_meta("go_score", 0)
	var wave: int = get_meta("go_wave", 1)
	var committed: bool = get_meta("go_committed", false)

	_vbox.add_child(_heading("GAME OVER"))
	var score_l := Label.new()
	score_l.text = "SCORE %06d   WAVE %d" % [score, wave]
	score_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_l.add_theme_font_size_override("font_size", 20)
	score_l.add_theme_color_override("font_color", Color.WHITE)
	_vbox.add_child(score_l)
	_vbox.add_child(_spacer(4))

	if HallOfFame.qualifies(score) and not committed:
		_name_edit = LineEdit.new()
		_name_edit.placeholder_text = "Name"
		_name_edit.max_length = 8
		_name_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
		_name_edit.custom_minimum_size = Vector2(180, BTN_H)
		_name_edit.add_theme_font_size_override("font_size", 20)
		_name_edit.text_submitted.connect(func(_t: String): _commit_score())
		var entry := HBoxContainer.new()
		entry.alignment = BoxContainer.ALIGNMENT_CENTER
		entry.add_theme_constant_override("separation", 8)
		entry.add_child(_name_edit)
		entry.add_child(_button("Enter", func(): _commit_score()))
		_vbox.add_child(entry)
		_vbox.add_child(_spacer(4))

	var hof_box := GridContainer.new()
	hof_box.columns = 3
	hof_box.add_theme_constant_override("h_separation", 10)
	hof_box.add_theme_constant_override("v_separation", 2)
	_vbox.add_child(hof_box)
	_render_hof(hof_box, HallOfFame.load_list(), get_meta("go_highlight", -1))
	_vbox.add_child(_spacer(6))

	_vbox.add_child(_button("Play Again", func():
		_maybe_auto_commit()
		hide_all()
		restart_pressed.emit()))
	_vbox.add_child(_button("Main Menu", func():
		_maybe_auto_commit()
		hide_all()
		quit_to_menu_pressed.emit()))
	if not OS.has_feature("web"):
		_vbox.add_child(_button("Exit", func():
			_maybe_auto_commit()
			get_tree().quit()))

func _commit_score() -> void:
	var who := (_name_edit.text if _name_edit else "").strip_edges()
	if who == "":
		who = "YOU"
	who = who.to_upper()
	var score: int = get_meta("go_score", 0)
	var wave: int = get_meta("go_wave", 1)
	var list := HallOfFame.insert(who, score, wave)
	set_meta("go_committed", true)
	var idx := -1
	for i in list.size():
		if list[i].name == who and int(list[i].score) == score:
			idx = i
			break
	set_meta("go_highlight", idx)
	_rebuild()

## A qualifying score that's never actually entered (the player leaves via
## Play Again/Main Menu/Exit without typing a name) would otherwise just be
## lost — commit it as "YOU" automatically, same as pressing "Enter" with an
## empty field would.
func _maybe_auto_commit() -> void:
	if _name_edit != null and not get_meta("go_committed", false):
		_commit_score()

func _render_hof(grid: GridContainer, list: Array, highlight: int) -> void:
	if list.is_empty():
		grid.add_child(_hint("— no entries yet —"))
		return
	for i in list.size():
		var e = list[i]
		var col := UiStyle.ACCENT if i == highlight else Color.WHITE
		var rank_l := Label.new()
		rank_l.text = "%d." % (i + 1)
		rank_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		rank_l.add_theme_color_override("font_color", col)
		var name_l := Label.new()
		name_l.text = str(e.name).to_upper()
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_l.add_theme_color_override("font_color", col)
		var score_l := Label.new()
		score_l.text = "%06d" % int(e.score)
		score_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		score_l.add_theme_color_override("font_color", col)
		grid.add_child(rank_l)
		grid.add_child(name_l)
		grid.add_child(score_l)

# ---------------------------------------------------------- high scores --
func _build_highscores() -> void:
	_vbox.add_child(_heading("HIGH SCORES"))
	_vbox.add_child(_spacer(4))
	var hof_box := GridContainer.new()
	hof_box.columns = 3
	hof_box.add_theme_constant_override("h_separation", 10)
	hof_box.add_theme_constant_override("v_separation", 2)
	_vbox.add_child(hof_box)
	_render_hof(hof_box, HallOfFame.load_list(), -1)
	_vbox.add_child(_spacer(6))
	_vbox.add_child(_button("Back", func(): _show_screen(_return_screen), true))

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

	_vbox.add_child(_button("Sound", func(): _show_screen(Screen.SOUND)))
	_vbox.add_child(_button("Back", func(): _show_screen(_return_screen), true))

func _set_cfg(key: String, value) -> void:
	_cfg[key] = value
	GameSettings.save(_cfg)
	settings_changed.emit(_cfg)

# ----------------------------------------------------------------- sound --
## 10 rows + a mute row no longer fit the design canvas at once alongside the
## heading and Back — scrollable, same as galaga's _build_sound() once it
## grew past ~7 rows. Back stays OUTSIDE the ScrollContainer so it's always
## reachable without scrolling.
func _build_sound() -> void:
	_vbox.add_child(_heading("SOUND"))
	var snd := get_node_or_null("/root/Snd")
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 420)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", GAP)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	if snd == null:
		list.add_child(_hint("Sound manager unavailable."))
	else:
		var mute_row := _row("Mute all")
		var mute_btn: Button
		mute_btn = _button("Muted" if snd.is_muted() else "On", func():
			var m: bool = snd.toggle_mute()
			mute_btn.text = "Muted" if m else "On")
		mute_btn.custom_minimum_size = Vector2(140, BTN_H)
		mute_row.add_child(mute_btn)
		list.add_child(mute_row)
		for key in snd.ORDER:
			list.add_child(_sound_row(snd, key))
	_vbox.add_child(scroll)
	_vbox.add_child(_button("Back", func(): _show_screen(Screen.SETTINGS), true))

func _sound_row(snd: Node, key: String) -> HBoxContainer:
	var display: String = snd.SOUNDS[key][0]
	var row := _row(display)
	var val_l := Label.new()
	val_l.custom_minimum_size = Vector2(60, 0)
	val_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	val_l.add_theme_color_override("font_color", UiStyle.ACCENT)
	var refresh := func(): val_l.text = "%d%%" % snd.get_volume(key)
	var change := func(d: int):
		snd.set_volume(key, snd.get_volume(key) + d)
		refresh.call()
		snd.preview_exclusive(key)
	var minus := _button("-", func(): change.call(-10))
	minus.custom_minimum_size = Vector2(BTN_H, BTN_H)
	var plus := _button("+", func(): change.call(10))
	plus.custom_minimum_size = Vector2(BTN_H, BTN_H)
	refresh.call()
	row.add_child(minus)
	row.add_child(val_l)
	row.add_child(plus)
	return row

# ------------------------------------------------------------------ help --
func _help_pages() -> Array:
	return HELP_TOUCH if _touch else HELP_DESKTOP

## Widened past the standard PANEL_W (like galaga's/tetris' _build_help()) so
## the illustration has real room — matches _build_sound()'s own widening.
func _build_help() -> void:
	var pages := _help_pages()
	var p: Dictionary = pages[_help_page]

	var head := _heading(p.h)
	head.add_theme_font_size_override("font_size", 24)
	_vbox.add_child(head)
	_vbox.add_child(_spacer(4))

	var img := TextureRect.new()
	img.custom_minimum_size = Vector2(430, 468)
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var path: String = HELP_DIR + str(p.file) + ".png"
	if ResourceLoader.exists(path):
		img.texture = load(path)
	_vbox.add_child(img)
	_vbox.add_child(_spacer(6))

	var nav := HBoxContainer.new()
	nav.alignment = BoxContainer.ALIGNMENT_CENTER
	nav.add_theme_constant_override("separation", 10)
	nav.add_child(_button("< Prev", func(): _turn_help(-1)))
	var dots := HBoxContainer.new()
	dots.alignment = BoxContainer.ALIGNMENT_CENTER
	dots.add_theme_constant_override("separation", 8)
	dots.custom_minimum_size = Vector2(60, 0)
	for i in range(pages.size()):
		var d := ColorRect.new()
		d.custom_minimum_size = Vector2(10, 10)
		d.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		d.color = UiStyle.ACCENT if i == _help_page else Color(1, 1, 1, 0.22)
		dots.add_child(d)
	nav.add_child(dots)
	nav.add_child(_button("Next >", func(): _turn_help(1)))
	_vbox.add_child(nav)

	_help_back_btn = _button("Back", func(): _show_screen(_return_screen), true)
	_vbox.add_child(_help_back_btn)

## Wraps at both ends (like galaga's _help_go()) — page-dot indicator shows
## position, "Next" past the last page looping back to the first reads as
## natural browsing rather than a dead end.
func _turn_help(d: int) -> void:
	_help_page = wrapi(_help_page + d, 0, _help_pages().size())
	_rebuild()

# ---------------------------------------------------------------- input --
func _unhandled_input(event: InputEvent) -> void:
	if not is_open():
		return

	# Hall of Fame name entry: a LineEdit only submits on Enter/Kp-Enter (its
	# own internal check), never on the generic ui_accept a gamepad's A sends.
	if _name_edit != null and is_instance_valid(_name_edit) and _name_edit.has_focus() \
			and event.is_action_pressed("ui_accept"):
		_commit_score()
		get_viewport().set_input_as_handled()
		return

	# B (ui_cancel) always triggers whichever button on the current screen is
	# tagged "is_cancel" (see _button()), independent of what has focus.
	if event.is_action_pressed("ui_cancel"):
		for b in _vbox.find_children("*", "Button", true, false):
			if b.visible and b.get_meta("is_cancel", false):
				b.pressed.emit()
				get_viewport().set_input_as_handled()
				return
		return

	if screen != Screen.HELP:
		return
	# ui_left/right rather than move_left/right — those fire during actual
	# gameplay steering too, not just here.
	if event.is_action_pressed("ui_right"):
		_turn_help(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_left"):
		_turn_help(-1)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		# Same direction sense as the ‹/› buttons: wheel down advances, wheel
		# up goes back. Godot reports each notch as its own pressed-then-
		# released pair — only act on the press half, or one notch pages twice.
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_turn_help(1)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_turn_help(-1)
			get_viewport().set_input_as_handled()
