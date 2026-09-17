extends SceneTree

## Headless smoke test. Run:
##   godot --headless --path . --script res://_selftest.gd
##
## Parse-checks the class_name scripts (a parse error makes load() fail) and
## sanity-checks the field-grid math + centipede chain step/split logic that
## the whole game relies on.

const SCRIPTS := [
	"res://field_grid.gd",
	"res://ui_style.gd",
	"res://game_settings.gd",
	"res://hall_of_fame.gd",
	"res://sound_manager.gd",
	"res://mushroom.gd",
	"res://bullet.gd",
	"res://player.gd",
	"res://centipede_segment.gd",
	"res://centipede_chain.gd",
	"res://spider.gd",
	"res://flea.gd",
	"res://scorpion.gd",
	"res://score_popup.gd",
	"res://hud.gd",
	"res://mute_icon.gd",
	"res://menus.gd",
	"res://touch_controls.gd",
	"res://game.gd",
]

func _init() -> void:
	var fails := 0

	for path in SCRIPTS:
		fails += _expect(load(path) != null, "parses: %s" % path)

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

	# --- lone-head-stuck-at-bottom auto-timeout -----------------------------
	var lsegs: Array[CentipedeSegment] = [CentipedeSegment.new()]
	var lchain := CentipedeChain.new()
	lchain.blocked = func(_c, _r): return false
	lchain.setup(lsegs, 5, FieldGrid.field_bottom_row(), -1, 0.01)
	lchain.step(1.0)
	fails += _expect(not lchain.is_stuck(), "a lone head at the bottom isn't stuck yet before the timeout")
	lchain.step(CentipedeChain.LONE_HEAD_TIMEOUT)
	fails += _expect(lchain.is_stuck(), "a lone head at the bottom for too long reports stuck")

	var fsegs: Array[CentipedeSegment] = [CentipedeSegment.new(), CentipedeSegment.new()]
	var fchain := CentipedeChain.new()
	fchain.blocked = func(_c, _r): return false
	fchain.setup(fsegs, 5, FieldGrid.field_bottom_row(), -1, 0.01)
	fchain.step(CentipedeChain.LONE_HEAD_TIMEOUT + 1.0)
	fails += _expect(not fchain.is_stuck(), "a chain with a body left never counts as a stuck lone head")

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
