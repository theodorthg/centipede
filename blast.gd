class_name Blast
extends Node2D

## The flash of a DDT bomb: an amber ring that grows to the blast radius and
## fades, then frees itself. Pure decoration — game.gd's _detonate() already
## did the damage.

const DURATION := 0.4

var _t := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if _t >= DURATION:
		queue_free()

func _draw() -> void:
	var k := clampf(_t / DURATION, 0.0, 1.0)
	var r := Waves.BLAST_RADIUS * FieldGrid.CELL * (0.25 + 0.75 * k)
	var a := 1.0 - k
	draw_circle(Vector2.ZERO, r, Color(1.0, 0.82, 0.25, 0.28 * a))
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 40, Color(1.0, 0.9, 0.5, a), 4.0)
	draw_circle(Vector2.ZERO, r * 0.35 * (1.0 - k * 0.5), Color(1, 1, 1, 0.8 * a))
