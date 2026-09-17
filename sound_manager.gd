extends Node

## Autoload "Snd". One AudioStreamPlayer per sound key. Per-sound volume 0–100
## lives in user://settings.cfg [sound]. Clips are expected at
## res://assets/sounds/<key>.ogg (or .wav) — a missing file just makes that
## key silent, which is fine until the user supplies audio (see global
## CLAUDE.md #12). base_db calibration is a neutral 0.0 for every key for now
## — there is nothing to listen to and tune against yet; re-calibrate (and
## bump CALIB_VERSION) once real clips land, same way galaga did.
##
## Access from class_name scripts via get_node_or_null("/root/Snd") — the bare
## "Snd" identifier does not resolve under `godot --script` (breaks _selftest).

const CFG_PATH := "user://settings.cfg"
const CALIB_VERSION := 1

const EXTS := [".wav", ".ogg"]

# key -> [display name, default %, base_db calibration]
const SOUNDS := {
	"menu-music":     ["Menu music", 50, 0.0],
	"shoot":          ["Shot", 50, 0.0],
	"mushroom-hit":   ["Mushroom hit", 50, 0.0],
	"mushroom-break": ["Mushroom destroyed", 50, 0.0],
	"segment-kill":   ["Centipede segment hit", 50, 0.0],
	"spider-kill":    ["Spider killed", 50, 0.0],
	"flea-kill":      ["Flea killed", 50, 0.0],
	"scorpion-kill":  ["Scorpion killed", 50, 0.0],
	"player-death":   ["Player destroyed", 50, 0.0],
	"extra-life":     ["Extra life", 50, 0.0],
	"get-ready":      ["Get ready", 50, 0.0],
	"wave-cleared":   ["Wave cleared", 50, 0.0],
	"game-over":      ["Game over", 50, 0.0],
}
const ORDER := [
	"menu-music", "shoot", "mushroom-hit", "mushroom-break", "segment-kill",
	"spider-kill", "flea-kill", "scorpion-kill", "player-death", "extra-life",
	"get-ready", "wave-cleared", "game-over",
]

const LOOPING_KEYS := ["menu-music"]
var _wanted := {}

var _muted := false
var _players := {}
var _vol := {}
var _previewing := ""

func _ready() -> void:
	_load()
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), _muted)
	for key in SOUNDS:
		var p := AudioStreamPlayer.new()
		p.name = key
		var stream := _find_stream(key)
		if stream:
			p.stream = stream
		add_child(p)
		_players[key] = p
		_apply(key)
	for key in LOOPING_KEYS:
		_wanted[key] = false
		var p: AudioStreamPlayer = _players[key]
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		p.finished.connect(func() -> void:
			if _wanted.get(key, false):
				p.play())

func _find_stream(key: String) -> AudioStream:
	for ext in EXTS:
		var path := "res://assets/sounds/%s%s" % [key, ext]
		if ResourceLoader.exists(path):
			return load(path)
	return null

func play(key: String) -> void:
	if key in LOOPING_KEYS:
		_wanted[key] = true
	var p = _players.get(key)
	if p and p.stream:
		p.play()

func stop(key: String) -> void:
	if key in LOOPING_KEYS:
		_wanted[key] = false
	var p = _players.get(key)
	if p:
		p.stop()

func is_muted() -> bool:
	return _muted

func toggle_mute() -> bool:
	set_muted(not _muted)
	return _muted

func set_muted(m: bool) -> void:
	_muted = m
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), m)
	_save()

func has_clip(key: String) -> bool:
	var p = _players.get(key)
	return p != null and p.stream != null

func get_volume(key: String) -> int:
	return int(_vol.get(key, SOUNDS[key][1]))

func set_volume(key: String, pct: int) -> void:
	_vol[key] = clampi(pct, 0, 100)
	_apply(key)
	_save()

func preview_exclusive(key: String) -> void:
	stop_preview()
	var p = _players.get(key)
	if p and p.stream:
		p.play()
		_previewing = key

func stop_preview() -> void:
	if _previewing == "":
		return
	var p = _players.get(_previewing)
	if p:
		p.stop()
	_previewing = ""

func _apply(key: String) -> void:
	var p = _players.get(key)
	if not p:
		return
	var pct := get_volume(key)
	if pct <= 0:
		p.volume_db = -80.0
	else:
		p.volume_db = float(SOUNDS[key][2]) + linear_to_db(pct / 100.0)

func _load() -> void:
	var c := ConfigFile.new()
	if c.load(CFG_PATH) != OK:
		return
	_muted = c.get_value("sound", "muted", false)
	if c.get_value("sound", "calib_version", 0) != CALIB_VERSION:
		return
	for key in SOUNDS:
		_vol[key] = c.get_value("sound", key, SOUNDS[key][1])

func _save() -> void:
	var c := ConfigFile.new()
	c.load(CFG_PATH)
	c.set_value("sound", "calib_version", CALIB_VERSION)
	c.set_value("sound", "muted", _muted)
	for key in _vol:
		c.set_value("sound", key, _vol[key])
	c.save(CFG_PATH)
