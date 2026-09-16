class_name Flea
extends Node2D

## Bonus enemy that drops straight down a single column, seeding new
## mushrooms behind it as it falls. Spawns when the player's own movement
## zone is running low on mushrooms (game.gd's _maybe_spawn_flea()) — its job
## is to replenish cover, not to threaten by itself, though touching it still
## costs a life like every other field hazard.

const SPEED := 220.0
const RADIUS := 12.0
const DROP_CHANCE := 0.35   # per row crossed
const DROP_COOLDOWN := 0.12 # min seconds between drop rolls, so speed can't be farmed

var col := 0
var add_mushroom: Callable = func(_c: int, _r: int) -> void: pass
var has_mushroom: Callable = func(_c: int, _r: int) -> bool: return false

var _last_row := -1
var _drop_t := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE

func setup(start_col: int) -> void:
	col = start_col
	position = Vector2(FieldGrid.cell_to_pixel(col, 0).x, FieldGrid.FIELD_TOP - RADIUS)
	_last_row = -1

func _process(delta: float) -> void:
	position.y += SPEED * delta
	_drop_t = maxf(0.0, _drop_t - delta)

	var row := FieldGrid.pixel_to_cell(position).y
	if row != _last_row and row >= 0 and row < FieldGrid.ROWS:
		_last_row = row
		if _drop_t <= 0.0 and randf() < DROP_CHANCE and not has_mushroom.call(col, row):
			add_mushroom.call(col, row)
			_drop_t = DROP_COOLDOWN

	if position.y > FieldGrid.FIELD_TOP + FieldGrid.ROWS * FieldGrid.CELL + RADIUS:
		queue_free()
	queue_redraw()

func _draw() -> void:
	var r := RADIUS
	draw_circle(Vector2.ZERO, r * 0.7, Color.WHITE)
	draw_arc(Vector2.ZERO, r * 0.7, 0.0, TAU, 16, UiStyle.ACCENT, 2.0)
	# little zig-zag legs, purely decorative — reads as "falling bug"
	for s in [-1.0, 1.0]:
		draw_line(Vector2(s * r * 0.5, -r * 0.1), Vector2(s * r * 1.1, -r * 0.6), Color.WHITE, 2.0)
		draw_line(Vector2(s * r * 0.5, r * 0.3), Vector2(s * r * 1.1, r * 0.8), Color.WHITE, 2.0)
