extends Control

## Illustrated control scheme for the Help screen (menus.gd) — a picture
## instead of pure text, per the learn-path CLAUDE.md's "Hilfetexte bildlich
## statt nur Worte", and includes the D-pad/gamepad legend since this project
## has gamepad support by default. page 0 = controls, page 1 = a small
## decorative recap of the three enemies.

var page := 0:
	set(v):
		page = v
		queue_redraw()

const INK := Color.WHITE
const ACC := Color("39ff14")

func _draw() -> void:
	if page == 0:
		_draw_controls()
	else:
		_draw_cast()

func _draw_controls() -> void:
	var w := size.x
	var col_w := w / 2.0
	_draw_keyboard(Vector2(col_w * 0.5, 42))
	_draw_mouse(Vector2(col_w * 1.5, 42))
	_draw_dpad(Vector2(col_w * 0.5, 168))
	_draw_touch(Vector2(col_w * 1.5, 168))

func _key(center: Vector2, w: float, label: String) -> void:
	var r := Rect2(center - Vector2(w, 14), Vector2(w * 2, 28))
	draw_rect(r, Color(0, 0, 0, 0), false)
	draw_rect(r, INK, false, 2.0)
	var f := ThemeDB.fallback_font
	draw_string(f, center + Vector2(-w + 6, 6), label, HORIZONTAL_ALIGNMENT_LEFT, w * 2 - 12, 14, INK)

func _draw_keyboard(c: Vector2) -> void:
	_key(c + Vector2(0, -18), 16, "W")
	_key(c + Vector2(-24, 12), 16, "A")
	_key(c + Vector2(0, 12), 16, "S")
	_key(c + Vector2(24, 12), 16, "D")
	_key(c + Vector2(0, 42), 40, "SPACE")
	_label_below(c, ["Keyboard", "Space = shoot"])

func _draw_mouse(c: Vector2) -> void:
	var body := Rect2(c + Vector2(-16, -28), Vector2(32, 48))
	draw_rect(body, INK, false, 2.0)
	draw_line(c + Vector2(0, -28), c + Vector2(0, -6), INK, 2.0)
	draw_rect(Rect2(c + Vector2(-16, -28), Vector2(15, 22)), ACC, false, 1.5)
	_label_below(c, ["Drag = move", "Click = shoot"])

func _draw_dpad(c: Vector2) -> void:
	var s := 14.0
	for d in [Vector2(0, -1), Vector2(0, 1), Vector2(-1, 0), Vector2(1, 0)]:
		var r := Rect2(c + d * s * 1.5 - Vector2(s, s), Vector2(s * 2, s * 2))
		draw_rect(r, INK, false, 2.0)
	draw_circle(c + Vector2(50, 0), 12, Color(0, 0, 0, 0))
	draw_arc(c + Vector2(50, 0), 12, 0, TAU, 16, ACC, 2.0)
	var f := ThemeDB.fallback_font
	draw_string(f, c + Vector2(45, 5), "A", HORIZONTAL_ALIGNMENT_CENTER, 20, 14, ACC)
	_label_below(c + Vector2(18, 0), ["D-pad + A", "A = shoot"])

func _draw_touch(c: Vector2) -> void:
	draw_arc(c, 22, 0, TAU, 20, INK, 2.0)
	draw_circle(c + Vector2(10, 10), 5, ACC)
	draw_line(c + Vector2(-14, -14), c + Vector2(6, 6), INK, 2.0)
	var arrow := c + Vector2(6, 6)
	draw_line(arrow, arrow + Vector2(-6, -1), INK, 2.0)
	draw_line(arrow, arrow + Vector2(-1, -6), INK, 2.0)
	_label_below(c, ["Drag = move", "Fire button = shoot"])

func _label_below(c: Vector2, lines: Array) -> void:
	var f := ThemeDB.fallback_font
	for i in range(lines.size()):
		draw_string(f, c + Vector2(-75, 44 + i * 15), lines[i],
			HORIZONTAL_ALIGNMENT_CENTER, 150, 13, Color(1, 1, 1, 0.85))

func _draw_cast() -> void:
	var y := size.y * 0.5
	var xs := [size.x * 0.2, size.x * 0.5, size.x * 0.8]
	var labels := ["Mushroom", "Centipede", "Spider"]
	for i in range(3):
		var c := Vector2(xs[i], y - 20)
		match i:
			0:
				draw_rect(Rect2(c + Vector2(-3, 6), Vector2(6, 18)), INK)
				draw_circle(c, 16, ACC)
				draw_arc(c, 16, 0, TAU, 20, INK, 2.0)
			1:
				draw_circle(c, 13, ACC)
				draw_arc(c, 13, 0, TAU, 16, INK, 2.0)
			2:
				draw_circle(c, 12, ACC)
				for a in range(8):
					var ang := (float(a) / 8.0) * TAU
					var dir := Vector2(cos(ang), sin(ang))
					draw_line(c + dir * 9, c + dir * 20, INK, 2.0)
		_label_below(c, [labels[i]])
