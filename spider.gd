class_name Spider
extends Node2D

## Bonus enemy: bounces erratically through the lower field (roughly the
## player's own movement zone, plus a little headroom), eating any mushroom
## it crosses. Costs the player a life on contact, same as a centipede
## segment. Worth more points the closer it is to the player when killed —
## see SCORE_TIERS.

const RADIUS := 13.0
const BASE_SPEED := 150.0
const SCORE_TIERS := [ [60.0, 900], [140.0, 600], [240.0, 300] ]
const SCORE_FAR := 100

var eat_mushroom: Callable = func(_c: int, _r: int) -> void: pass
var box_top := 0.0
var box_bottom := 0.0

var _vel := Vector2.ZERO
var _turn_t := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE

func setup(start_pos: Vector2, top_y: float, bottom_y: float) -> void:
	position = start_pos
	box_top = top_y
	box_bottom = bottom_y
	var ang := randf_range(0.0, TAU)
	_vel = Vector2(cos(ang), sin(ang)) * BASE_SPEED
	_turn_t = randf_range(0.3, 0.7)

static func score_for_distance(dist: float) -> int:
	for tier in SCORE_TIERS:
		if dist <= tier[0]:
			return tier[1]
	return SCORE_FAR

func _process(delta: float) -> void:
	position += _vel * delta

	if position.x < FieldGrid.FIELD_LEFT + RADIUS:
		position.x = FieldGrid.FIELD_LEFT + RADIUS
		_vel.x = absf(_vel.x)
	elif position.x > FieldGrid.DESIGN_WIDTH - RADIUS:
		position.x = FieldGrid.DESIGN_WIDTH - RADIUS
		_vel.x = -absf(_vel.x)
	if position.y < box_top + RADIUS:
		position.y = box_top + RADIUS
		_vel.y = absf(_vel.y)
	elif position.y > box_bottom - RADIUS:
		position.y = box_bottom - RADIUS
		_vel.y = -absf(_vel.y)

	_turn_t -= delta
	if _turn_t <= 0.0:
		_turn_t = randf_range(0.25, 0.6)
		_vel = _vel.rotated(randf_range(-0.9, 0.9))
		_vel = _vel.normalized() * BASE_SPEED

	var cell := FieldGrid.pixel_to_cell(position)
	eat_mushroom.call(cell.x, cell.y)
	queue_redraw()

func _draw() -> void:
	draw_circle(Vector2.ZERO, RADIUS * 0.75, UiStyle.ACCENT)
	draw_arc(Vector2.ZERO, RADIUS * 0.75, 0.0, TAU, 16, Color.WHITE, 2.0)
	for i in range(8):
		var ang := (float(i) / 8.0) * TAU
		var dir := Vector2(cos(ang), sin(ang))
		draw_line(dir * RADIUS * 0.6, dir * RADIUS * 1.35, Color.WHITE, 2.0)
