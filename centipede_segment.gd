class_name CentipedeSegment
extends Node2D

## One visual body part of a centipede train. Movement is driven entirely by
## CentipedeChain (a plain RefCounted, not a Node) — this script only
## interpolates smoothly between the grid cells the chain assigns it and
## draws itself. col/row always reflect the cell it is CURRENTLY heading to
## (used by CentipedeChain._reseed_path() when a chain splits).

var is_head := false
var col := 0
var row := 0

var _prev_pixel := Vector2.ZERO
var _target_pixel := Vector2.ZERO
var _t := 1.0
var _tick_interval := 0.13
const RADIUS_PAD := 2.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE

func place_instant(c: int, r: int) -> void:
	col = c
	row = r
	_prev_pixel = FieldGrid.cell_to_pixel(c, r)
	_target_pixel = _prev_pixel
	position = _prev_pixel
	_t = 1.0

func move_to(c: int, r: int, tick_interval: float) -> void:
	col = c
	row = r
	_prev_pixel = position
	_target_pixel = FieldGrid.cell_to_pixel(c, r)
	_tick_interval = tick_interval
	_t = 0.0

func _process(delta: float) -> void:
	if _t < 1.0:
		_t = minf(1.0, _t + delta / maxf(_tick_interval, 0.001))
		position = _prev_pixel.lerp(_target_pixel, _t)
	queue_redraw()

func _draw() -> void:
	var r := FieldGrid.CELL * 0.5 - RADIUS_PAD
	var body_color := UiStyle.ACCENT if is_head else Color.WHITE
	var ring_color := Color.WHITE if is_head else UiStyle.ACCENT
	draw_circle(Vector2.ZERO, r, body_color)
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 20, ring_color, 2.0)
	if is_head:
		draw_circle(Vector2(-r * 0.35, -r * 0.2), 2.5, Color.BLACK)
		draw_circle(Vector2(r * 0.35, -r * 0.2), 2.5, Color.BLACK)
