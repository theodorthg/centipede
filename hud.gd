class_name Hud
extends Control

## In-play HUD: score (top-left), wave (top-center), remaining-lives reserve
## icons (bottom-left, drawn), and a top-right Pause + Mute button pair
## (frosted glass, always visible). Title/Settings/Pause/Game-Over screens
## live in menus.gd.

const DESIGN_WIDTH := FieldGrid.DESIGN_WIDTH
const DESIGN_HEIGHT := FieldGrid.DESIGN_HEIGHT

## Lives are shown as the RESERVE (active ship doesn't count) — global
## convention, see the learn-path CLAUDE.md's "Leben-/Schiffs-Anzeige".
const MANY_THRESHOLD := 5
const ICON_H := 22.0
const ICON_GAP := 8.0

const BTN_SIZE := 56.0
const BTN_MARGIN := 12.0

var _score: Label
var _wave: Label
var _pause_btn: Button
var _mute_btn: Button

var _mute_icon: Control
var _lives := 0

signal pause_pressed
signal mute_pressed

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(queue_redraw)

	_score = Label.new()
	_score.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_score.position = Vector2(14, 10)
	_score.add_theme_font_size_override("font_size", 22)
	add_child(_score)
	UiStyle.impact_label(_score)

	_wave = Label.new()
	_wave.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_wave.position = Vector2(0, 10)
	_wave.size = Vector2(DESIGN_WIDTH, 30)
	_wave.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wave.add_theme_font_size_override("font_size", 18)
	add_child(_wave)

	_pause_btn = Button.new()
	_pause_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_pause_btn.position = Vector2(DESIGN_WIDTH - BTN_MARGIN - BTN_SIZE, BTN_MARGIN)
	_pause_btn.size = Vector2(BTN_SIZE, BTN_SIZE)
	_pause_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_pause_btn.focus_mode = Control.FOCUS_NONE
	_pause_btn.text = "II"
	add_child(_pause_btn)
	_pause_btn.pressed.connect(func(): pause_pressed.emit())
	UiStyle.style_button(_pause_btn)
	_add_glass(_pause_btn)

	_mute_btn = Button.new()
	_mute_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_mute_btn.position = Vector2(DESIGN_WIDTH - BTN_MARGIN * 2 - BTN_SIZE * 2, BTN_MARGIN)
	_mute_btn.size = Vector2(BTN_SIZE, BTN_SIZE)
	_mute_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_mute_btn.focus_mode = Control.FOCUS_NONE
	_mute_btn.text = ""
	add_child(_mute_btn)
	_mute_btn.pressed.connect(func(): mute_pressed.emit())
	UiStyle.style_button(_mute_btn)
	_add_glass(_mute_btn)
	_mute_icon = Control.new()
	_mute_icon.set_script(load("res://mute_icon.gd"))
	_mute_icon.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_mute_icon.offset_left = _mute_btn.offset_left
	_mute_icon.offset_top = _mute_btn.offset_top
	_mute_icon.offset_right = _mute_btn.offset_right
	_mute_icon.offset_bottom = _mute_btn.offset_bottom
	add_child(_mute_icon)

	UiStyle.impact_label(_wave)

func set_score(n: int) -> void:
	_score.text = "%06d" % n

func set_wave(n: int) -> void:
	_wave.text = "WAVE %d" % n

func set_lives(n: int) -> void:
	_lives = maxi(n, 0)
	queue_redraw()

func set_muted(m: bool) -> void:
	_mute_icon.set_muted(m)

func set_cabinet_lane(active: bool, offset_x: float) -> void:
	if active:
		set_anchors_preset(Control.PRESET_TOP_LEFT)
		size = Vector2(DESIGN_WIDTH, DESIGN_HEIGHT)
		position = Vector2(offset_x, 0.0)
	else:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		position = Vector2.ZERO

func _add_glass(btn: Button) -> void:
	var g := UiStyle.make_glass_backdrop()
	var idx := btn.get_index()
	add_child(g.backbuffer)
	move_child(g.backbuffer, idx)
	add_child(g.glass)
	move_child(g.glass, idx + 1)
	g.glass.visible = true
	g.glass.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	g.glass.offset_left = btn.offset_left
	g.glass.offset_top = btn.offset_top
	g.glass.offset_right = btn.offset_right
	g.glass.offset_bottom = btn.offset_bottom

func _draw() -> void:
	var reserve := maxi(_lives - 1, 0)
	var y := DESIGN_HEIGHT - ICON_H - 10.0
	if reserve < MANY_THRESHOLD:
		for i in range(reserve):
			_draw_ship_icon(Vector2(14.0 + i * (ICON_H + ICON_GAP) + ICON_H * 0.5, y + ICON_H * 0.5))
	elif reserve > 0:
		_draw_ship_icon(Vector2(14.0 + ICON_H * 0.5, y + ICON_H * 0.5))
		var f := ThemeDB.fallback_font
		draw_string(f, Vector2(14.0 + ICON_H + 8.0, y + ICON_H * 0.8), "x %d" % reserve,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)

func _draw_ship_icon(center: Vector2) -> void:
	var r := ICON_H * 0.5
	var pts := PackedVector2Array([
		center + Vector2(0, -r), center + Vector2(r * 0.85, r * 0.8),
		center + Vector2(0, r * 0.35), center + Vector2(-r * 0.85, r * 0.8),
	])
	draw_colored_polygon(pts, Color.WHITE)
	draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), UiStyle.ACCENT, 2.0, true)
