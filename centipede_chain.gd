class_name CentipedeChain
extends RefCounted

## One independent centipede train: a follow-the-leader chain of
## CentipedeSegment nodes stepping across the mushroom-field grid.
##
## Movement model: only the head decides where to go, once per grid "tick"
## (tick_interval seconds). Every step's head cell is pushed onto the front
## of _path (trimmed to segments.size()); segment i is simply assigned
## _path[i] each tick — the classic "everyone follows the exact cell the one
## ahead was in" snake-following trick, which also makes splitting trivial
## (see hit()): re-seed _path from each segment's own current cell and both
## halves keep following correctly from that point on, no position jumps.
##
## Head rule: step sideways in `dir` if the next cell is in bounds and free
## of a mushroom; otherwise drop one row (clamped to the field's bottom row)
## and reverse `dir`. Blocked() is supplied by game.gd (mushroom lookup).

var segments: Array[CentipedeSegment] = []
var dir := -1
var tick_interval := 0.13
var blocked: Callable = func(_c: int, _r: int) -> bool: return false
var reached_player: Callable = func(_c: int, _r: int) -> bool: return false

var _path: Array[Vector2i] = []
var _tick_t := 0.0

## Spawns a fresh chain lined up in a single row (start_col is the head's
## cell; the rest of the train trails behind it against `dir`, i.e. off to
## the opposite side, matching the arcade's "solid line marches in" look).
func setup(new_segments: Array[CentipedeSegment], start_col: int, start_row: int,
		start_dir: int, interval: float) -> void:
	segments = new_segments
	dir = start_dir
	tick_interval = interval
	_path.clear()
	for i in range(segments.size()):
		var c: int = start_col - dir * i
		_path.append(Vector2i(c, start_row))
		segments[i].place_instant(c, start_row)
		segments[i].is_head = (i == 0)

func step(delta: float) -> void:
	if segments.is_empty():
		return
	_tick_t += delta
	while _tick_t >= tick_interval and not segments.is_empty():
		_tick_t -= tick_interval
		_advance()

func _advance() -> void:
	var head := _path[0]
	var next_col := head.x + dir
	var new_cell: Vector2i
	if next_col >= 0 and next_col < FieldGrid.COLS and not blocked.call(next_col, head.y):
		new_cell = Vector2i(next_col, head.y)
	else:
		var new_row: int = mini(head.y + 1, FieldGrid.field_bottom_row())
		dir = -dir
		new_cell = Vector2i(head.x, new_row)
	_path.push_front(new_cell)
	if _path.size() > segments.size():
		_path.resize(segments.size())
	for i in range(segments.size()):
		if i < _path.size():
			segments[i].move_to(_path[i].x, _path[i].y, tick_interval)

func _reseed_path() -> void:
	_path.clear()
	for s in segments:
		_path.append(Vector2i(s.col, s.row))

## Removes the segment at `index`. Returns a Dictionary:
##   cell        -> Vector2i the destroyed segment occupied (spawn a mushroom there)
##   new_chain   -> a second CentipedeChain if the train split, else null
##   empty       -> true if this chain has no segments left at all
func hit(index: int) -> Dictionary:
	var seg := segments[index]
	var cell := Vector2i(seg.col, seg.row)
	var tail: Array[CentipedeSegment] = []
	if index + 1 < segments.size():
		tail = segments.slice(index + 1, segments.size())
	segments = segments.slice(0, index)
	seg.queue_free()

	var new_chain: CentipedeChain = null
	if not tail.is_empty():
		new_chain = CentipedeChain.new()
		new_chain.segments = tail
		new_chain.dir = dir
		new_chain.tick_interval = tick_interval
		new_chain.blocked = blocked
		new_chain.reached_player = reached_player
		for s in tail:
			s.is_head = false
		tail[0].is_head = true
		new_chain._reseed_path()

	if not segments.is_empty():
		segments[0].is_head = true
		_reseed_path()

	return {"cell": cell, "new_chain": new_chain, "empty": segments.is_empty()}

func free_all() -> void:
	for s in segments:
		if is_instance_valid(s):
			s.queue_free()
	segments.clear()
