extends Control

## Drawn on its own Control, sitting right on top of hud.gd's MuteButton in
## the tree (see hud.gd::_add_mute_glass()) — NOT drawn as part of the HUD
## parent's own _draw() like a first attempt did, because a Button's own
## StyleBoxFlat background draws AFTER (on top of) whatever its parent drew,
## so an icon painted by the parent sits BEHIND the button and gets
## partially or fully hidden depending on the button's current hover/pressed
## alpha (confirmed live: visible at rest, invisible once hovered/pressed).
## A separate Control positioned after the button in the tree draws on top
## of it instead, with mouse_filter=IGNORE so clicks still reach the button
## underneath.

var muted := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_muted(m: bool) -> void:
	muted = m
	queue_redraw()

## Same vector speaker-cone icon as originally sketched — see hud.gd's
## former _draw_mute_icon() history for why it's hand-drawn rather than a
## font glyph. Sound-wave arcs when unmuted, a diagonal cross when muted.
func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var c := r.get_center()
	var s := minf(r.size.x, r.size.y) * 0.34
	var col := Color.WHITE  # matches the Pause button's white "II" glyph
	# -4.0: the sound-wave arcs' outer radius otherwise pokes a few px past
	# the button's right edge (56px wide, icon reaches ~60px without this).
	var cone_x := c.x - s * 0.25 - 4.0
	var body_w := s * 0.45
	var pts := PackedVector2Array([
		Vector2(cone_x - body_w, c.y - s * 0.35),
		Vector2(cone_x, c.y - s * 0.35),
		Vector2(cone_x + s * 0.6, c.y - s),
		Vector2(cone_x + s * 0.6, c.y + s),
		Vector2(cone_x, c.y + s * 0.35),
		Vector2(cone_x - body_w, c.y + s * 0.35),
	])
	draw_colored_polygon(pts, col)
	if muted:
		var d := s * 0.95
		draw_line(Vector2(c.x - d * 0.1, c.y - d), Vector2(c.x + d, c.y + d), col, 3.0, true)
		draw_line(Vector2(c.x - d * 0.1, c.y + d), Vector2(c.x + d, c.y - d), col, 3.0, true)
	else:
		for i: int in [1, 2]:
			var rad: float = s * (0.55 + i * 0.4)
			draw_arc(Vector2(cone_x + s * 0.6, c.y), rad, -PI * 0.3, PI * 0.3, 10, col, 2.0, true)
