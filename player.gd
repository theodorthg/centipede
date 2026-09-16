class_name Player
extends Node2D

## Player "blaster". Movement is constrained to a configurable strip at the
## bottom of the mushroom field (GameSettings.movement_zone / FieldGrid.Zone)
## — the classic-arcade trackball feel by default, widenable up to full-field
## free movement per the user's request. Every input method drives the same
## position: keyboard/gamepad give a continuous SPEED-capped direction vector
## (expected — digital input has no "current position" of its own), mouse/
## touch instead SNAP directly to the input's world position every frame
## (see _snap_to()) — the same fix already applied in galaga's ship.gd:
## chasing the mouse/touch point with a speed-limited move_toward() reads as
## input lag/"Nachziehen" the instant the pointer moves faster than that cap,
## even though nothing is actually delayed. Direct assignment has no such
## ceiling. Only obstacle-blocking (mushrooms) still limits it, per axis.
## Activated only once an actual event of that kind is seen (not polled), so
## the input sources never fight each other.

signal fire_requested(from_pos: Vector2)

const SPEED := 300.0
const RADIUS := 11.0
const FIRE_COOLDOWN := 0.22

var zone_top_row := FieldGrid.zone_top_row(FieldGrid.Zone.HALF)
var is_blocked: Callable = func(_p: Vector2) -> bool: return false
var alive := true
var input_enabled := true
var fire_held := false

var _fire_t := 0.0
var _mouse_target := Vector2.ZERO
var _mouse_active := false
var _touch_target := Vector2.ZERO
var _touch_active := false

func _ready() -> void:
	# PAUSABLE, not the parent Game node's ALWAYS — the player (like every
	# other gameplay entity) must actually freeze while the pause/settings
	# menu is open, even though Game itself stays ALWAYS so its own
	# _process()/_unhandled_input() (resize polling, pause/mute keys) keep
	# running and the Menus/HUD CanvasLayers stay clickable.
	process_mode = Node.PROCESS_MODE_PAUSABLE

func reset(start_pos: Vector2) -> void:
	position = start_pos
	alive = true
	_fire_t = 0.0
	_mouse_active = false
	_touch_active = false

func _process(delta: float) -> void:
	queue_redraw()
	if not (alive and input_enabled):
		return
	_handle_movement(delta)
	_handle_fire(delta)

func _handle_movement(delta: float) -> void:
	var dir := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	)
	if dir.length() > 0.05:
		_mouse_active = false
		_touch_active = false
		_try_move(dir.normalized() * SPEED * delta)
	elif _touch_active:
		_snap_to(_touch_target)
	elif _mouse_active:
		_snap_to(_mouse_target)
	_clamp_to_zone()

func _try_move(step: Vector2) -> void:
	if step.x != 0.0:
		var next := position + Vector2(step.x, 0)
		if not is_blocked.call(next):
			position.x = next.x
	if step.y != 0.0:
		var next := position + Vector2(0, step.y)
		if not is_blocked.call(next):
			position.y = next.y

## Direct 1:1 tracking (no speed cap — see the class doc comment above for
## why) — jumps straight to the target's x, then y, each independently
## skipped if that would land inside a mushroom, so an obstacle still stops
## the player on that axis without reintroducing any chase-lag on the other.
func _snap_to(target: Vector2) -> void:
	var tx := Vector2(target.x, position.y)
	if not is_blocked.call(tx):
		position.x = target.x
	var ty := Vector2(position.x, target.y)
	if not is_blocked.call(ty):
		position.y = target.y

func _clamp_to_zone() -> void:
	var min_x := FieldGrid.FIELD_LEFT + RADIUS
	var max_x := FieldGrid.DESIGN_WIDTH - RADIUS
	var min_y := FieldGrid.cell_to_pixel(0, zone_top_row).y - FieldGrid.CELL * 0.5 + RADIUS
	var max_y := FieldGrid.FIELD_TOP + FieldGrid.ROWS * FieldGrid.CELL - RADIUS
	position.x = clamp(position.x, min_x, max_x)
	position.y = clamp(position.y, min_y, max_y)

func _handle_fire(delta: float) -> void:
	_fire_t = maxf(0.0, _fire_t - delta)
	if (Input.is_action_pressed("shoot") or fire_held) and _fire_t <= 0.0:
		_fire_t = FIRE_COOLDOWN
		fire_requested.emit(position + Vector2(0, -RADIUS))

func _to_world(viewport_pos: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * viewport_pos

func _unhandled_input(event: InputEvent) -> void:
	if not (alive and input_enabled):
		return
	if event is InputEventMouseMotion:
		_mouse_target = _to_world(event.position)
		_mouse_active = true
		_touch_active = false
	elif event is InputEventMouseButton and event.pressed:
		_mouse_target = _to_world(event.position)
		_mouse_active = true
		_touch_active = false
	elif event is InputEventScreenDrag:
		_touch_target = _to_world(event.position)
		_touch_active = true
		_mouse_active = false
	elif event is InputEventScreenTouch and event.pressed:
		_touch_target = _to_world(event.position)
		_touch_active = true
		_mouse_active = false
	elif (event is InputEventJoypadMotion and absf(event.axis_value) > 0.3) \
			or event is InputEventJoypadButton \
			or (event is InputEventKey and event.pressed):
		_mouse_active = false
		_touch_active = false

func _draw() -> void:
	if not alive:
		return
	var r := RADIUS
	var pts := PackedVector2Array([
		Vector2(0, -r), Vector2(r * 0.85, r * 0.8),
		Vector2(0, r * 0.35), Vector2(-r * 0.85, r * 0.8),
	])
	draw_colored_polygon(pts, Color.WHITE)
	draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), UiStyle.ACCENT, 2.5, true)
