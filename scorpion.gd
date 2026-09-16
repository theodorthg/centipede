class_name Scorpion
extends Node2D

## Crawls in a straight line across a single row, poisoning every mushroom it
## crosses (mushroom.gd::poison()) — a centipede segment later blocked by a
## poisoned mushroom dives straight down instead of turning (see
## centipede_chain.gd's `poisoned` callback / `_diving`). Row is picked
## outside the player's own movement zone (game.gd's _spawn_scorpion()) so it
## never itself wanders into point-blank range.

const SPEED := 95.0
const RADIUS := 12.0

var row := 0
var dir := 1
var poison_mushroom: Callable = func(_c: int, _r: int) -> void: pass

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE

func setup(start_row: int, start_dir: int) -> void:
	row = start_row
	dir = start_dir
	var start_x: float = (FieldGrid.FIELD_LEFT - RADIUS * 2.0) if dir > 0 \
		else (FieldGrid.DESIGN_WIDTH + RADIUS * 2.0)
	position = Vector2(start_x, FieldGrid.cell_to_pixel(0, row).y)

func _process(delta: float) -> void:
	position.x += dir * SPEED * delta
	var cell := FieldGrid.pixel_to_cell(position)
	if FieldGrid.in_bounds(cell.x, row):
		poison_mushroom.call(cell.x, row)
	if position.x < FieldGrid.FIELD_LEFT - RADIUS * 3.0 \
			or position.x > FieldGrid.DESIGN_WIDTH + RADIUS * 3.0:
		queue_free()
	queue_redraw()

func _draw() -> void:
	var r := RADIUS
	# elongated body, mirrored to face the direction of travel
	var body := Rect2(Vector2(-r * 1.3, -r * 0.55), Vector2(r * 2.6, r * 1.1))
	draw_rect(body, Color.WHITE)
	draw_rect(body, Mushroom.POISON_COLOR, false, 2.0)
	var front := dir
	# pincers
	draw_line(Vector2(front * r * 1.3, -r * 0.5), Vector2(front * r * 1.9, -r * 1.1), Color.WHITE, 2.5)
	draw_line(Vector2(front * r * 1.3, r * 0.5), Vector2(front * r * 1.9, r * 1.1), Color.WHITE, 2.5)
	# curled tail behind
	draw_arc(Vector2(-front * r * 1.3, 0), r * 0.6, 0.0, PI, 10, Color.WHITE, 2.0)
