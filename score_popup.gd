class_name ScorePopup
extends Node2D

## Small "+N" text that appears at a kill's position, fades in/out over
## DURATION seconds while drifting up a little, then frees itself. Spawned by
## game.gd only for the "big" kills the player should notice at a glance
## (centipede heads, spider, scorpion) — not for mushroom hits or body
## segments, which happen too often to flash every time without becoming
## visual noise.

const DURATION := 0.5
const RISE := 16.0
const FONT_SIZE := 22

var _text := ""
var _t := 0.0
var _rise_speed := 0.0

func setup(score: int) -> void:
	_text = "+%d" % score
	_rise_speed = RISE / DURATION
	modulate.a = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE

func _process(delta: float) -> void:
	_t += delta
	position.y -= _rise_speed * delta
	var half := DURATION * 0.5
	modulate.a = clampf((_t / half) if _t < half else (1.0 - (_t - half) / half), 0.0, 1.0)
	queue_redraw()
	if _t >= DURATION:
		queue_free()

func _draw() -> void:
	var f := ThemeDB.fallback_font
	var w := f.get_string_size(_text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	var pos := Vector2(-w * 0.5, 0.0)
	draw_string_outline(f, pos, _text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, 4, Color.BLACK)
	draw_string(f, pos, _text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, UiStyle.ACCENT)
