class_name TouchControls
extends Control

## Touch-only overlay: a translucent "Fire" button, bottom-right, so a finger
## dragging the ship (Player._unhandled_input's ScreenDrag handling) and a
## second finger/thumb tapping Fire don't fight over the same touch. Movement
## itself needs no on-screen control — dragging anywhere in the player's zone
## already works via Player.

const DESIGN_WIDTH := FieldGrid.DESIGN_WIDTH
const DESIGN_HEIGHT := FieldGrid.DESIGN_HEIGHT
const BTN_D := 84.0
const MARGIN := 22.0

signal fire_down
signal fire_up

var _btn: Button

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_btn = Button.new()
	_btn.custom_minimum_size = Vector2(BTN_D, BTN_D)
	_btn.size = Vector2(BTN_D, BTN_D)
	_btn.position = Vector2(DESIGN_WIDTH - MARGIN - BTN_D, DESIGN_HEIGHT - MARGIN - BTN_D)
	_btn.text = "FIRE"
	_btn.focus_mode = Control.FOCUS_NONE
	_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb_n := StyleBoxFlat.new()
	sb_n.bg_color = Color(UiStyle.ACCENT.r, UiStyle.ACCENT.g, UiStyle.ACCENT.b, 0.22)
	sb_n.set_corner_radius_all(int(BTN_D * 0.5))
	sb_n.set_border_width_all(2)
	sb_n.border_color = UiStyle.ACCENT
	var sb_p := sb_n.duplicate()
	sb_p.bg_color = Color(UiStyle.ACCENT.r, UiStyle.ACCENT.g, UiStyle.ACCENT.b, 0.5)
	_btn.add_theme_stylebox_override("normal", sb_n)
	_btn.add_theme_stylebox_override("hover", sb_n)
	_btn.add_theme_stylebox_override("pressed", sb_p)
	_btn.add_theme_color_override("font_color", Color.WHITE)
	add_child(_btn)
	_btn.button_down.connect(func(): fire_down.emit())
	_btn.button_up.connect(func(): fire_up.emit())

func set_cabinet_lane(active: bool, offset_x: float) -> void:
	if active:
		set_anchors_preset(Control.PRESET_TOP_LEFT)
		size = Vector2(DESIGN_WIDTH, DESIGN_HEIGHT)
		position = Vector2(offset_x, 0.0)
	else:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		position = Vector2.ZERO
