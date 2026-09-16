class_name Mushroom
extends Node2D

## A single mushroom-field cell. Takes MAX_HP player-bullet hits before it's
## cleared; each hit chips visible chunks off the cap (_draw() reads hp).
## Blocks both the player's movement and a centipede segment's path — see
## game.gd's _mushroom_at()/_step_chain().
const MAX_HP := 4

var col := 0
var row := 0
var hp := MAX_HP

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE

func setup(c: int, r: int) -> void:
	col = c
	row = r
	position = FieldGrid.cell_to_pixel(c, r)

## Returns true if the mushroom was fully destroyed.
func hit() -> bool:
	hp -= 1
	queue_redraw()
	return hp <= 0

func _draw() -> void:
	var radius := FieldGrid.CELL * 0.5 - 3.0
	var shade := float(hp) / float(MAX_HP)
	var cap := UiStyle.ACCENT.lerp(Color(0.15, 0.25, 0.12), 1.0 - shade)
	# stem
	draw_rect(Rect2(Vector2(-4, radius * 0.15), Vector2(8, radius * 0.85)), Color.WHITE)
	# cap
	draw_circle(Vector2(0, -radius * 0.35), radius, cap)
	draw_arc(Vector2(0, -radius * 0.35), radius, 0.0, TAU, 24, Color.WHITE, 2.0)
	# damage notches — chunks missing from the cap as hp drops
	var notches := MAX_HP - hp
	for i in range(notches):
		var ang := (float(i) / MAX_HP) * TAU + 0.6
		var bite := Vector2(cos(ang), sin(ang)) * radius * 0.75 + Vector2(0, -radius * 0.35)
		draw_circle(bite, radius * 0.32, Color(0, 0, 0, 0.85))
