class_name Menus
extends Control

## Start / Settings (+Sound sub-page) / Pause / Game-Over / High Scores / Help
## screens. Every screen is built on demand into one shared glass-backed
## panel — see global CLAUDE.md's "Menü-Optik" convention (frosted glass,
## framed panel, 56px touch targets, D-pad/gamepad-aware help) and its
## "Menü-Navigations-Konventionen" point (cancel-button tagging, focus wrap,
## help-page paging/wheel/dots, ScrollContainer for long lists), both first
## proven in galaga's menus.gd and generalized from there.

signal play_pressed(players: int)
signal resume_pressed
signal restart_pressed
signal quit_to_menu_pressed
signal settings_changed(cfg: Dictionary)

enum Screen { NONE, START, PLAYERS, SETTINGS, SOUND, PAUSE, GAMEOVER, HELP, HIGHSCORES,
	NETMENU, ONLINEMENU, ONLINEJOIN, NETHOST, NETJOIN, NETWAIT, INFO }

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
	{"file": "players", "h": "2 Players"},
	{"file": "network", "h": "LAN & Online"},
	{"file": "goal", "h": "Goal & Scoring"},
]
const HELP_TOUCH := [
	{"file": "touch", "h": "Controls — Touch"},
	{"file": "players", "h": "2 Players"},
	{"file": "network", "h": "LAN & Online"},
	{"file": "goal", "h": "Goal & Scoring"},
]

var _panel: PanelContainer
var _vbox: VBoxContainer
var _help_back_btn: Button
var _name_edits: Array[LineEdit] = []

## The two-device duel (LAN / online) — set by game.gd. duel_game is true while
## a duel round is on (the pause menu then has no Settings/Restart, only Leave).
var duel: Duel
var duel_game := false
var _net_online := false
var _room_code := ""
var _found := {}                    ## LAN guest: ip -> device name
var _hosts_box: VBoxContainer      ## NETJOIN: one button per host found, refilled in place
var _hosts_hint: Label
var _edit_dirty := false           ## the player typed into the address field
var _ip_edit: LineEdit
var _ip_submit := Callable()
var _info := ["", ""]
var _duel_head: Label
var _duel_opp: Label
var _duel_tally: Label
var _duel_btn: Button
var _duel_note: Label

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
	_name_edits.clear()
	_help_back_btn = null
	_ip_edit = null
	_hosts_box = null
	_hosts_hint = null
	_duel_head = null
	_duel_btn = null
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
		Screen.PLAYERS:
			_build_players()
		Screen.NETMENU:
			_build_netmenu()
		Screen.ONLINEMENU:
			_build_onlinemenu()
		Screen.ONLINEJOIN:
			_build_onlinejoin()
		Screen.NETHOST:
			_build_nethost()
		Screen.NETJOIN:
			_build_netjoin()
		Screen.NETWAIT:
			_build_netwait()
		Screen.INFO:
			_build_info()
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
		# would land on the "<" button here) — see the global CLAUDE.md's
		# "Menü-Navigations-Konventionen": a focused button consumes
		# ui_left/ui_right for Godot's own focus-neighbor navigation before
		# _unhandled_input()'s paging ever sees the event, so landing on
		# "<" would make the first D-pad-right press only move focus to
		# ">" instead of actually turning the page. Back has no focus
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

## info: {mode: "solo"|"turns", scores: [..], waves: [..]} (one entry per
## player).
func show_gameover(info: Dictionary) -> void:
	set_meta("go_info", info)
	set_meta("go_committed", false)
	set_meta("go_highlight", [])
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
	_vbox.add_child(_button("Play", func(): _show_screen(Screen.PLAYERS)))
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

# --------------------------------------------------------------- players --
## Like mario-clone's PLAYERS screen: one player, two taking turns on this
## device, or two devices (LAN / Wi-Fi, online) each playing their own game at
## the same time.
## LAN needs UDP (not in a browser); online needs the relay's address.
static func wifi_possible() -> bool:
	return NetLink.lan_possible()

static func online_possible() -> bool:
	return NetLink.relay_url() != ""

func _build_players() -> void:
	_vbox.add_child(_heading("PLAYERS"))
	_vbox.add_child(_button("1 Player", func():
		hide_all()
		play_pressed.emit(1)))
	_vbox.add_child(_button("2 Players - take turns", func():
		hide_all()
		play_pressed.emit(2)))
	if wifi_possible() and duel != null:
		_vbox.add_child(_button("2 Players - LAN / Wi-Fi", func(): _show_screen(Screen.NETMENU)))
	if online_possible() and duel != null:
		_vbox.add_child(_button("2 Players - Online", func(): _show_screen(Screen.ONLINEMENU)))
	var h := _hint("Take turns: one device, player 1 until a life is lost,\nthen player 2 - each with their own field.\nLAN / Online: two devices, both play at the same\ntime on the same fields - the higher score wins.")
	h.add_theme_color_override("font_color", UiStyle.ACCENT)
	_vbox.add_child(h)
	_vbox.add_child(_button("Back", func(): _show_screen(Screen.START), true))

# ----------------------------------------------------------------- pause --
func _build_pause() -> void:
	_vbox.add_child(_heading("PAUSED"))
	if duel_game:
		_vbox.add_child(_button("Resume", func():
			hide_all()
			resume_pressed.emit()))
		_vbox.add_child(_button("How to Play", func():
			_return_screen = Screen.PAUSE
			_help_page = 0
			_show_screen(Screen.HELP)))
		_vbox.add_child(_button("Leave game", func():
			hide_all()
			quit_to_menu_pressed.emit()))
		_vbox.add_child(_hint("Your opponent keeps playing."))
		return
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
func _go_info() -> Dictionary:
	return get_meta("go_info", {"mode": "solo", "scores": [0], "waves": [1]})

func _build_gameover() -> void:
	var info := _go_info()
	if info.mode == "duel":
		_build_gameover_duel()
		return
	var scores: Array = info.scores
	var waves: Array = info.waves
	var turns: bool = scores.size() > 1
	var committed: bool = get_meta("go_committed", false)

	_vbox.add_child(_heading("GAME OVER"))
	if not turns:
		var score_l := Label.new()
		score_l.text = "SCORE %06d    ·    WAVE %d" % [scores[0], waves[0]]
		score_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		score_l.add_theme_font_size_override("font_size", 20)
		score_l.add_theme_color_override("font_color", Color.WHITE)
		_vbox.add_child(score_l)
	else:
		var best := 0 if int(scores[0]) >= int(scores[1]) else 1
		var tie: bool = int(scores[0]) == int(scores[1])
		for i in scores.size():
			var l := Label.new()
			l.text = "P%d    %06d    ·    WAVE %d" % [i + 1, scores[i], waves[i]]
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			l.add_theme_font_size_override("font_size", 20)
			l.add_theme_color_override("font_color", UiStyle.ACCENT if (i == best and not tie) else Color.WHITE)
			_vbox.add_child(l)
		var w := _hint("DRAW!" if tie else "PLAYER %d WINS!" % (best + 1))
		w.add_theme_font_size_override("font_size", 22)
		w.add_theme_color_override("font_color", UiStyle.ACCENT)
		_vbox.add_child(w)
	_vbox.add_child(_spacer(4))

	if not committed:
		for i in scores.size():
			if HallOfFame.qualifies(int(scores[i])):
				var e := LineEdit.new()
				e.placeholder_text = "Name" if not turns else "Name P%d" % (i + 1)
				e.max_length = 8
				e.alignment = HORIZONTAL_ALIGNMENT_CENTER
				e.custom_minimum_size = Vector2(180, BTN_H)
				e.add_theme_font_size_override("font_size", 20)
				e.set_meta("player", i)
				e.text_submitted.connect(func(_t: String): _commit_score())
				_name_edits.append(e)
		if not _name_edits.is_empty():
			var entry := VBoxContainer.new()
			entry.add_theme_constant_override("separation", 8)
			var row := HBoxContainer.new()
			row.alignment = BoxContainer.ALIGNMENT_CENTER
			row.add_theme_constant_override("separation", 8)
			for e in _name_edits:
				row.add_child(e)
			if _name_edits.size() == 1:
				row.add_child(_button("Enter", func(): _commit_score()))
			entry.add_child(row)
			if _name_edits.size() > 1:
				entry.add_child(_button("Enter", func(): _commit_score()))
			_vbox.add_child(entry)
			_vbox.add_child(_spacer(4))

	var hof_box := GridContainer.new()
	hof_box.columns = 4
	hof_box.add_theme_constant_override("h_separation", 10)
	hof_box.add_theme_constant_override("v_separation", 2)
	_vbox.add_child(hof_box)
	_render_hof(hof_box, HallOfFame.load_list(), get_meta("go_highlight", []))
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

## Enters every score that got a name field (an empty field = "YOU" for one
## player, "P1"/"P2" for two), then redraws the list with those rows lit up.
func _commit_score() -> void:
	var info := _go_info()
	var turns: bool = info.scores.size() > 1
	var added := []
	for e in _name_edits:
		if not is_instance_valid(e):
			continue
		var i: int = e.get_meta("player", 0)
		var who := e.text.strip_edges()
		if who == "":
			who = "P%d" % (i + 1) if turns else "YOU"
		who = who.to_upper()
		var score := int(info.scores[i])
		HallOfFame.insert(who, score, int(info.waves[i]))
		added.append([who, score])
	var list := HallOfFame.load_list()
	var hl := []
	for a in added:
		for k in list.size():
			if k not in hl and list[k].name == a[0] and int(list[k].score) == a[1]:
				hl.append(k)
				break
	set_meta("go_committed", true)
	set_meta("go_highlight", hl)
	_rebuild()

## A qualifying score that's never actually entered (the player leaves via
## Play Again/Main Menu/Exit without typing a name) would otherwise just be
## lost — commit it under the default name automatically, same as pressing
## "Enter" with an empty field would.
func _maybe_auto_commit() -> void:
	if not _name_edits.is_empty() and not get_meta("go_committed", false):
		_commit_score()

func _render_hof(grid: GridContainer, list: Array, highlights: Array) -> void:
	if list.is_empty():
		# one wide cell — in a narrow 4-column cell the autowrapped hint broke
		# after every few characters
		grid.columns = 1
		grid.add_child(_hint("— no entries yet —"))
		return
	for i in list.size():
		var e = list[i]
		var col := UiStyle.ACCENT if i in highlights else Color.WHITE
		var rank_l := Label.new()
		rank_l.text = "%d." % (i + 1)
		rank_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		rank_l.add_theme_color_override("font_color", col)
		var name_l := Label.new()
		name_l.text = str(e.name).to_upper()
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_l.add_theme_color_override("font_color", col)
		# Shown alongside score (not used for ranking — score alone still
		# decides order, the classic-arcade convention) so a high score from
		# a long fight on an early wave doesn't read as mysteriously
		# outranking a run that reached a later wave — see the project
		# CLAUDE.md's "Hall of Fame" section for the full reasoning.
		var wave_l := Label.new()
		wave_l.text = "W%d" % int(e.get("wave", 1))
		wave_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		wave_l.add_theme_color_override("font_color", Color(col.r, col.g, col.b, 0.75))
		var score_l := Label.new()
		score_l.text = "%06d" % int(e.score)
		score_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		score_l.add_theme_color_override("font_color", col)
		grid.add_child(rank_l)
		grid.add_child(name_l)
		grid.add_child(wave_l)
		grid.add_child(score_l)

# ------------------------------------------------------- duel / network --
func show_info(title: String, text: String) -> void:
	_info = [title, text]
	_show_screen(Screen.INFO)

func _build_info() -> void:
	_vbox.add_child(_heading(_info[0]))
	_vbox.add_child(_hint(_info[1]))
	_vbox.add_child(_button("OK", func(): _show_screen(Screen.START), true))

## Menus gets its Duel from game.gd — the signals feed the waiting / joining /
## game-over screens.
func set_duel(d: Duel) -> void:
	duel = d
	d.room_ready.connect(_on_room_ready)
	d.lan_hosts_changed.connect(_on_lan_hosts)
	d.opponent_changed.connect(_refresh_duel_gameover)
	d.rematch_changed.connect(func(_m: bool, _t: bool): _refresh_duel_gameover())

func _on_room_ready(code: String) -> void:
	_room_code = code
	if screen == Screen.NETHOST:
		_rebuild()

func _on_lan_hosts(hosts: Dictionary) -> void:
	_found = hosts
	if screen == Screen.NETJOIN:
		_fill_hosts(true)

func _cancel_net() -> void:
	if duel:
		duel.leave()
	_show_screen(Screen.START)

func _lan_cfg() -> Dictionary:
	return GameSettings.load_all()

func _build_netmenu() -> void:
	_vbox.add_child(_heading("LAN / WI-FI"))
	_vbox.add_child(_button("Host a game", func(): _start_hosting(false)))
	_vbox.add_child(_button("Join a game", func():
		_found = {}
		duel.search_lan()
		_show_screen(Screen.NETJOIN)))
	var h := _hint("Both devices in the same network (cable or Wi-Fi). Both play at the same time on the same fields. The host's settings (lives, difficulty, movement area) apply to both. Same game version on both.")
	h.add_theme_color_override("font_color", UiStyle.ACCENT)
	_vbox.add_child(h)
	_vbox.add_child(_hint("Host is a PC with a firewall: allow UDP ports 47110-47111. No admin rights (school network)? Online always works."))
	_vbox.add_child(_button("Back", func(): _show_screen(Screen.PLAYERS), true))

func _build_onlinemenu() -> void:
	_vbox.add_child(_heading("ONLINE"))
	_vbox.add_child(_button("Host a game", func(): _start_hosting(true)))
	_vbox.add_child(_button("Join a game", func(): _show_screen(Screen.ONLINEJOIN)))
	var h := _hint("Play from anywhere: the host gets a room code and tells it to the other player. Both play at the same time on the same fields - works in the browser, too. The host's settings apply to both. Same game version.")
	h.add_theme_color_override("font_color", UiStyle.ACCENT)
	_vbox.add_child(h)
	_vbox.add_child(_button("Back", func(): _show_screen(Screen.PLAYERS), true))

func _start_hosting(online: bool) -> void:
	if duel == null:
		return
	_net_online = online
	_room_code = ""
	var err := duel.host_online(_lan_cfg()) if online else duel.host_lan(_lan_cfg())
	if err != OK:
		if online:
			show_info("ONLINE", "Could not reach the online server (error %d)." % err)
		else:
			show_info("LAN / WI-FI", "Could not open the game for the network (error %d).\nIs another copy of the game already hosting?\nOnline always works." % err)
		return
	_show_screen(Screen.NETHOST)

func _build_nethost() -> void:
	_vbox.add_child(_heading("WAITING FOR PLAYER 2"))
	if _net_online:
		if _room_code == "":
			_vbox.add_child(_hint("Opening a room on the online server ..."))
		else:
			_vbox.add_child(_hint("Tell the other player this room code:"))
			var code := _heading(_room_code)
			code.add_theme_font_size_override("font_size", 40)
			code.add_theme_color_override("font_color", UiStyle.ACCENT)
			_vbox.add_child(code)
			_vbox.add_child(_hint("On their device: Play > 2 Players - Online > Join a game."))
	else:
		var ips := NetLink.local_ips()
		var addr := ", ".join(ips) if not ips.is_empty() else "no network address found"
		_vbox.add_child(_hint("On the other device: Play > 2 Players - LAN / Wi-Fi > Join a game. This game shows up there by itself, or type its address:"))
		var a := _hint(addr)
		a.add_theme_color_override("font_color", UiStyle.ACCENT)
		_vbox.add_child(a)
	_vbox.add_child(_button("Cancel", _cancel_net, true))

func _make_edit(placeholder: String, max_len: int, w: float) -> LineEdit:
	var e := LineEdit.new()
	e.placeholder_text = placeholder
	e.max_length = max_len
	e.alignment = HORIZONTAL_ALIGNMENT_CENTER
	e.custom_minimum_size = Vector2(w, BTN_H)
	e.add_theme_font_size_override("font_size", 20)
	return e

func _build_onlinejoin() -> void:
	_vbox.add_child(_heading("JOIN ONLINE"))
	_vbox.add_child(_hint("Type the room code the host's screen shows:"))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	_ip_edit = _make_edit("CODE", 4, 120)
	var ed := _ip_edit
	_ip_edit.text_changed.connect(func(t: String):
		var up := t.to_upper()
		if up != t:
			ed.text = up
			ed.caret_column = up.length())
	_ip_submit = func(): _join_code(ed.text)
	_ip_edit.text_submitted.connect(func(_t: String): _ip_submit.call())
	row.add_child(_ip_edit)
	var join_btn := _button("Join", func(): _ip_submit.call())
	join_btn.custom_minimum_size = Vector2(110, BTN_H)
	row.add_child(join_btn)
	_vbox.add_child(row)
	_vbox.add_child(_button("Back", func(): _show_screen(Screen.ONLINEMENU), true))

func _join_code(code: String) -> void:
	code = NetLink.clean_code(code)
	if code.length() != 4 or duel == null:
		return
	set_meta("net_ip", "room " + code)
	if duel.join_online(code) != OK:
		show_info("ONLINE", "Could not reach the online server.")
		return
	_show_screen(Screen.NETWAIT)

func _build_netjoin() -> void:
	_vbox.add_child(_heading("JOIN A GAME"))
	_hosts_hint = _hint("Looking for games in this network ... Not found? The host's firewall may block UDP 47110-47111 - or use Online, it always works.")
	_vbox.add_child(_hosts_hint)
	_hosts_box = VBoxContainer.new()
	_hosts_box.add_theme_constant_override("separation", GAP)
	_vbox.add_child(_hosts_box)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	_ip_edit = _make_edit("192.168.x.x", 15, 200)
	var ed := _ip_edit
	_ip_edit.text = str(GameSettings.load_all().get("last_host", ""))
	_edit_dirty = false
	_ip_edit.text_changed.connect(func(_t: String): _edit_dirty = true)
	_ip_submit = func(): _connect_to(ed.text.strip_edges())
	_ip_edit.text_submitted.connect(func(_t: String): _ip_submit.call())
	row.add_child(_ip_edit)
	var go := _button("Connect", func(): _ip_submit.call())
	go.custom_minimum_size = Vector2(120, BTN_H)
	row.add_child(go)
	_vbox.add_child(row)
	_vbox.add_child(_button("Back", func():
		duel.leave()
		_show_screen(Screen.NETMENU), true))
	_fill_hosts(false)

## The hosts found so far, refilled in place: a rebuild would reset the address
## field the player may be typing in. A host showing up while nothing was typed
## gets the focus (gamepad / keyboard: one press to join).
func _fill_hosts(focus_first: bool) -> void:
	if _hosts_box == null or not is_instance_valid(_hosts_box):
		return
	for c in _hosts_box.get_children():
		_hosts_box.remove_child(c)
		c.queue_free()
	_hosts_hint.visible = _found.is_empty()
	for ip in _found:
		_hosts_box.add_child(_button("%s  (%s)" % [_found[ip], ip], _connect_to.bind(ip)))
	if focus_first and not _edit_dirty and _hosts_box.get_child_count() > 0:
		_hosts_box.get_child(0).grab_focus.call_deferred()
	_recenter_panel.call_deferred()

func _connect_to(ip: String) -> void:
	if ip == "" or duel == null:
		return
	var c := GameSettings.load_all()
	c["last_host"] = ip
	GameSettings.save(c)
	set_meta("net_ip", ip)
	if duel.join_lan(ip) != OK:
		show_info("LAN / WI-FI", "Could not connect to %s.\nHost PC: allow UDP 47110-47111 - or use Online." % ip)
		return
	_show_screen(Screen.NETWAIT)

func _build_netwait() -> void:
	_vbox.add_child(_heading("CONNECTING"))
	var t: String = get_meta("net_ip", "")
	_vbox.add_child(_hint("to the game %s ... This can take up to 15 seconds." % (t if t.begins_with("room") else "at " + t)))
	_vbox.add_child(_button("Cancel", _cancel_net, true))

## The duel's own game-over: both scores, the round result once both games are
## over, the tally of rounds, Rematch / Leave. No high-score entry — the two
## sides can play different settings only through the host, but a duel is
## about beating the other player, not the list (same convention as tetris'
## versus rounds).
func _build_gameover_duel() -> void:
	_duel_head = _heading("GAME OVER")
	_vbox.add_child(_duel_head)
	var mine := Label.new()
	mine.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mine.add_theme_font_size_override("font_size", 20)
	mine.add_theme_color_override("font_color", Color.WHITE)
	mine.text = "YOU    %06d    ·    WAVE %d" % [duel.my_score, duel.my_wave]
	_vbox.add_child(mine)
	_duel_opp = Label.new()
	_duel_opp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_duel_opp.add_theme_font_size_override("font_size", 20)
	_duel_opp.add_theme_color_override("font_color", Color.WHITE)
	_vbox.add_child(_duel_opp)
	_duel_note = _hint("")
	_duel_note.add_theme_color_override("font_color", UiStyle.ACCENT)
	_vbox.add_child(_duel_note)
	_duel_tally = _hint("")
	_vbox.add_child(_duel_tally)
	_vbox.add_child(_spacer(6))
	_duel_btn = _button("Rematch", func():
		duel.want_rematch())
	_vbox.add_child(_duel_btn)
	_vbox.add_child(_button("Leave game", func():
		hide_all()
		quit_to_menu_pressed.emit()))
	_refresh_duel_gameover()

## Updates the duel game-over screen in place (the opponent's numbers arrive
## several times a second — a rebuild would reset focus and flicker).
func _refresh_duel_gameover() -> void:
	if screen != Screen.GAMEOVER or _duel_head == null or not is_instance_valid(_duel_head) or duel == null:
		return
	var res := duel.result()
	_duel_head.text = ["GAME OVER", "YOU WIN!", "YOU LOSE", "DRAW!"][res]
	_duel_opp.text = "OPP    %06d    ·    WAVE %d" % [duel.opp_score, duel.opp_wave]
	_duel_note.text = "Your opponent is still playing ..." if res == 0 else ""
	_duel_tally.text = "Rounds:  You %d : %d Opponent%s" % [duel.wins, duel.losses,
		("   (%d draw)" % duel.draws) if duel.draws > 0 else ""]
	var was_disabled := _duel_btn.disabled
	if res == 0:
		_duel_btn.disabled = true
		_duel_btn.text = "Rematch"
	elif duel.rematch_wanted():
		_duel_btn.disabled = true
		_duel_btn.text = "Waiting for opponent ..."
	else:
		_duel_btn.disabled = false
		_duel_btn.text = "Rematch"
		if was_disabled:
			_duel_btn.grab_focus.call_deferred()

# ---------------------------------------------------------- high scores --
func _build_highscores() -> void:
	_vbox.add_child(_heading("HIGH SCORES"))
	_vbox.add_child(_spacer(4))
	var hof_box := GridContainer.new()
	hof_box.columns = 4
	hof_box.add_theme_constant_override("h_separation", 10)
	hof_box.add_theme_constant_override("v_separation", 2)
	_vbox.add_child(hof_box)
	_render_hof(hof_box, HallOfFame.load_list(), [])
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
	var prev_btn := _button("<", func(): _turn_help(-1))
	prev_btn.custom_minimum_size = Vector2(BTN_H, BTN_H)
	nav.add_child(prev_btn)
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
	var next_btn := _button(">", func(): _turn_help(1))
	next_btn.custom_minimum_size = Vector2(BTN_H, BTN_H)
	nav.add_child(next_btn)
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
	if event.is_action_pressed("ui_accept"):
		if _ip_edit != null and is_instance_valid(_ip_edit) and _ip_edit.has_focus() and _ip_submit.is_valid():
			_ip_submit.call()
			get_viewport().set_input_as_handled()
			return
		for e in _name_edits:
			if is_instance_valid(e) and e.has_focus():
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
