class_name GameSettings

## Gameplay settings — persisted in user://settings.cfg section [s], shared by
## the start-screen and pause Settings menu. (Sound volumes are a separate
## section owned by sound_manager.gd.)

const CFG_PATH := "user://settings.cfg"

const DEF := {
	"lives": 3,            # LIVES_MIN..LIVES_MAX
	"movement_zone": 1,    # FieldGrid.Zone — ORIGINAL=0 / HALF=1 / FULL=2,
	                       # configurable per user request: how tall the
	                       # player's movement strip at the bottom is.
	"difficulty": 1,       # 0 easy, 1 normal, 2 hard — centipede base speed
	"extra_life": 12000,   # 0 = off, sonst EXTRA_STEP..EXTRA_MAX
}

const LIVES_MIN := 2
const LIVES_MAX := 9
const EXTRA_MAX := 50000
const EXTRA_STEP := 2000
const DIFF_NAMES := ["Easy", "Normal", "Hard"]
const ZONE_NAMES := ["Original", "Half", "Full"]

static func load_all() -> Dictionary:
	var out := DEF.duplicate()
	var c := ConfigFile.new()
	if c.load(CFG_PATH) == OK:
		for k in DEF:
			out[k] = c.get_value("s", k, DEF[k])
	return out

static func save(data: Dictionary) -> void:
	var c := ConfigFile.new()
	c.load(CFG_PATH)
	for k in data:
		c.set_value("s", k, data[k])
	c.save(CFG_PATH)

## difficulty -> centipede tick interval (seconds per grid step, lower=faster)
static func tick_interval(difficulty: int) -> float:
	match difficulty:
		0:
			return 0.16
		2:
			return 0.095
		_:
			return 0.13
