class_name Bullet
extends Node2D

const SPEED := 780.0
const LEN := 16.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE

func _process(delta: float) -> void:
	position.y -= SPEED * delta
	if position.y < FieldGrid.FIELD_TOP - LEN:
		queue_free()

func _draw() -> void:
	draw_line(Vector2.ZERO, Vector2(0, LEN), Color.WHITE, 3.0)
	draw_line(Vector2.ZERO, Vector2(0, LEN), UiStyle.ACCENT, 1.0)
