class_name FieldGrid

## Shared mushroom-field grid math. DESIGN_WIDTH/HEIGHT match project.godot's
## window/size/viewport_width/height (the fixed design canvas every gameplay
## coordinate is expressed in — see game.gd's cabinet-lane handling for how
## that canvas gets centered on wider/landscape windows).
const DESIGN_WIDTH := 540.0
const DESIGN_HEIGHT := 960.0

const CELL := 30.0
const COLS := 18          # DESIGN_WIDTH / CELL
const HUD_HEIGHT := 90.0  # reserved band at the top (score/lives/pause/mute)
const BOTTOM_MARGIN := 30.0
const ROWS := 28           # (DESIGN_HEIGHT - HUD_HEIGHT - BOTTOM_MARGIN) / CELL

const FIELD_LEFT := 0.0
const FIELD_TOP := HUD_HEIGHT

static func field_bottom_row() -> int:
	return ROWS - 1

static func cell_to_pixel(col: int, row: int) -> Vector2:
	return Vector2(FIELD_LEFT + (col + 0.5) * CELL, FIELD_TOP + (row + 0.5) * CELL)

static func pixel_to_cell(pos: Vector2) -> Vector2i:
	var col := int(floor((pos.x - FIELD_LEFT) / CELL))
	var row := int(floor((pos.y - FIELD_TOP) / CELL))
	return Vector2i(col, row)

static func in_bounds(col: int, row: int) -> bool:
	return col >= 0 and col < COLS and row >= 0 and row < ROWS

## Movement-zone presets for the player (row count counted from the field's
## bottom row upward) — configurable per the user's request, from the
## authentic tiny arcade strip up to full-field free movement.
enum Zone { ORIGINAL, HALF, FULL }
static func zone_rows(zone: int) -> int:
	match zone:
		Zone.ORIGINAL:
			return 4
		Zone.HALF:
			return int(ROWS / 2.0)
		_:
			return ROWS

static func zone_top_row(zone: int) -> int:
	return ROWS - zone_rows(zone)
