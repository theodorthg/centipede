extends SceneTree

## Headless smoke test. Run:
##   godot --headless --path . --script res://_selftest.gd
##
## Checks that every script compiles (see _all_scripts()) and
## sanity-checks the field-grid math + centipede chain step/split logic that
## the whole game relies on.

## Every game script, found automatically — a hand-kept list silently goes
## stale. Walks res:// recursively, skipping addons/, tools/, android/ (Godot's
## build template), hidden and .gdignore'd folders and _-prefixed dev scripts
## (_selftest.gd itself, local helpers like _capture.gd).
## A script only counts if it also COMPILES: in Godot 4 load() returns the
## resource even when compilation failed (incl. a broken dependency), so check
## can_instantiate() (found in mario-clone v1.1, where `load() != null` let a
## type-inference error through with "all checks passed" and exit 0).
const SKIP_DIRS := ["addons", "tools", "android"]

func _all_scripts(dir := "res://") -> Array[String]:
	var out: Array[String] = []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd") and not f.begins_with("_"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		var sub := dir.path_join(d)
		if d.begins_with(".") or d in SKIP_DIRS or FileAccess.file_exists(sub.path_join(".gdignore")):
			continue
		out.append_array(_all_scripts(sub))
	return out

func _init() -> void:
	var fails := 0

	var scripts := _all_scripts()
	fails += _expect(scripts.size() >= 15, "found %d scripts (expect >= 15)" % scripts.size())
	for path in scripts:
		var s: Script = load(path)
		fails += _expect(s != null and s.can_instantiate(), "compiles: %s" % path)

	# --- project config -----------------------------------------------------
	var canvas := Vector2(
		ProjectSettings.get_setting("display/window/size/viewport_width"),
		ProjectSettings.get_setting("display/window/size/viewport_height"))
	fails += _expect(canvas.y > canvas.x, "design canvas is portrait (%dx%d)" % [canvas.x, canvas.y])
	fails += _expect(ProjectSettings.get_setting("display/window/stretch/mode") == "canvas_items",
		"stretch mode = canvas_items")
	for action in ["move_left", "move_right", "move_up", "move_down", "shoot", "pause", "mute", "ui_accept", "ui_cancel"]:
		fails += _expect(InputMap.has_action(action), "input action present: %s" % action)

	# --- field grid ---------------------------------------------------------
	var px := FieldGrid.cell_to_pixel(3, 5)
	var back := FieldGrid.pixel_to_cell(px)
	fails += _expect(back == Vector2i(3, 5), "cell_to_pixel/pixel_to_cell round-trip")
	fails += _expect(FieldGrid.in_bounds(0, 0), "cell (0,0) in bounds")
	fails += _expect(not FieldGrid.in_bounds(-1, 0), "cell (-1,0) out of bounds")
	fails += _expect(FieldGrid.zone_rows(FieldGrid.Zone.FULL) == FieldGrid.ROWS,
		"FULL zone covers every row")
	fails += _expect(FieldGrid.zone_rows(FieldGrid.Zone.ORIGINAL) < FieldGrid.zone_rows(FieldGrid.Zone.HALF),
		"ORIGINAL zone is smaller than HALF")

	# --- centipede chain: spawn, step, split --------------------------------
	var segs: Array[CentipedeSegment] = []
	for i in range(4):
		segs.append(CentipedeSegment.new())
	var chain := CentipedeChain.new()
	chain.blocked = func(_c, _r): return false
	chain.setup(segs, 5, 0, -1, 0.01)
	fails += _expect(segs[0].col == 5 and segs[0].row == 0, "head starts at spawn cell")
	fails += _expect(segs[1].col == 6, "second segment trails behind the head")

	chain.step(0.011)  # forces exactly one tick at interval 0.01
	fails += _expect(segs[0].col == 4, "head advanced one cell left")

	var result: Dictionary = chain.hit(1)
	fails += _expect(chain.segments.size() == 1, "front chain keeps only the segments before the hit")
	fails += _expect(result.new_chain != null, "hitting a body segment splits the train")
	fails += _expect(result.new_chain.segments.size() == 2, "split-off chain keeps the trailing segments")
	fails += _expect(not result.empty, "front chain is not empty after the split")

	# --- poison dive ---------------------------------------------------------
	var dsegs: Array[CentipedeSegment] = [CentipedeSegment.new(), CentipedeSegment.new()]
	var dchain := CentipedeChain.new()
	dchain.blocked = func(c, r): return c == 1 and r == 0
	dchain.poisoned = func(c, r): return c == 1 and r == 0
	dchain.setup(dsegs, 2, 0, -1, 0.01)
	dchain.step(0.011)
	fails += _expect(dsegs[0].col == 2 and dsegs[0].row == 1,
		"a poisoned mushroom triggers a straight dive instead of a turn")
	fails += _expect(dchain.dir == -1, "dir stays unchanged while diving")
	dchain.step(0.011)
	fails += _expect(dsegs[0].row == 2, "the dive continues straight down on the next tick")

	# --- stuck-at-bottom auto-timeout (any chain size) ----------------------
	var lsegs: Array[CentipedeSegment] = [CentipedeSegment.new()]
	var lchain := CentipedeChain.new()
	lchain.blocked = func(_c, _r): return false
	lchain.setup(lsegs, 5, FieldGrid.field_bottom_row(), -1, 0.01)
	lchain.step(1.0)
	fails += _expect(not lchain.is_stuck(), "a lone head at the bottom isn't stuck yet before the timeout")
	lchain.step(CentipedeChain.STUCK_AT_BOTTOM_TIMEOUT)
	fails += _expect(lchain.is_stuck(), "a lone head at the bottom for too long reports stuck")

	# A chain with a body still attached must ALSO report stuck once its
	# head has sat at the bottom row long enough — a full train stuck there
	# is exactly as unescapable as a bare head (2026-09-18 fix: this used to
	# be scoped to segments.size() == 1 only, leaving multi-segment trains
	# with no safety net at all).
	var fsegs: Array[CentipedeSegment] = [CentipedeSegment.new(), CentipedeSegment.new(), CentipedeSegment.new()]
	var fchain := CentipedeChain.new()
	fchain.blocked = func(_c, _r): return false
	fchain.setup(fsegs, 5, FieldGrid.field_bottom_row(), -1, 0.01)
	fchain.step(1.0)
	fails += _expect(not fchain.is_stuck(), "a multi-segment chain at the bottom isn't stuck yet before the timeout")
	fchain.step(CentipedeChain.STUCK_AT_BOTTOM_TIMEOUT)
	fails += _expect(fchain.is_stuck(), "a multi-segment chain at the bottom for too long ALSO reports stuck")

	# --- snapshot / restore (2 players taking turns park their field) -------
	var rsegs: Array[CentipedeSegment] = [CentipedeSegment.new(), CentipedeSegment.new(), CentipedeSegment.new()]
	var rchain := CentipedeChain.new()
	rchain.blocked = func(_c, _r): return false
	rchain.setup(rsegs, 7, 3, 1, 0.01)
	rchain.step(0.031)                      # a few ticks so the shape isn't a straight line
	var snap: Dictionary = rchain.snapshot()
	var nsegs: Array[CentipedeSegment] = [CentipedeSegment.new(), CentipedeSegment.new(), CentipedeSegment.new()]
	var nchain := CentipedeChain.new()
	nchain.blocked = func(_c, _r): return false
	nchain.restore(nsegs, snap)
	var same := true
	for i in 3:
		same = same and nsegs[i].col == rsegs[i].col and nsegs[i].row == rsegs[i].row
	fails += _expect(same, "a restored chain sits on exactly the saved cells")
	fails += _expect(nsegs[0].is_head and not nsegs[1].is_head, "restored chain: only the first segment is the head")
	fails += _expect(nchain.dir == rchain.dir, "restored chain keeps its direction")
	rchain.step(0.011)
	nchain.step(0.011)
	same = true
	for i in 3:
		same = same and nsegs[i].col == rsegs[i].col and nsegs[i].row == rsegs[i].row
	fails += _expect(same, "restored chain keeps moving exactly like the original")

	if fails == 0:
		print("_selftest: all checks passed")
	else:
		printerr("_selftest: %d check(s) FAILED" % fails)
	quit(1 if fails > 0 else 0)

func _expect(cond: bool, label: String) -> int:
	if cond:
		print("  ok  ", label)
		return 0
	printerr("  FAIL ", label)
	return 1
