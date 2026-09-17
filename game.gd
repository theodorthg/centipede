extends Node2D

## Top-level game controller: state machine (title/playing/game-over),
## mushroom field, centipede chains, spider, score/lives, settings, and the
## landscape-cabinet desktop mode (see the learn-path CLAUDE.md's "Ausnahme
## Breitbild-/Querformat" — same technique as galaga's game.gd, minus the
## decorative side-margin artwork this project doesn't have yet: a black
## cabinet margin needs no art of its own since the whole background is
## already black).

const DESIGN_WIDTH := FieldGrid.DESIGN_WIDTH
const DESIGN_HEIGHT := FieldGrid.DESIGN_HEIGHT
const INITIAL_SEGMENTS := 12
const MUSHROOM_BASE_COUNT := 32
const SPIDER_INTERVAL_MIN := 9.0
const SPIDER_INTERVAL_MAX := 17.0
## Flea: replenishes cover once the player's own movement zone runs thin —
## checked periodically rather than every frame, threshold counted only over
## the zone's own rows (a sparse zone is what actually leaves the player
## exposed; mushrooms further up don't help with that).
const FLEA_CHECK_INTERVAL := 2.0
const FLEA_MUSHROOM_THRESHOLD := 5
const FLEA_SCORE := 200
## Scorpion: rarer than the spider, row picked outside the player's own zone
## (game.gd's _spawn_scorpion()) so it never itself wanders into point-blank
## range — see scorpion.gd / mushroom.gd's poison trail.
const SCORPION_INTERVAL_MIN := 16.0
const SCORPION_INTERVAL_MAX := 28.0
const SCORPION_SCORE := 1000
## How long the "CLEARED!" banner (+ fanfare) holds the game between waves —
## see hud.gd's show_wave_cleared_banner(), which fades in/out within it.
const WAVE_CLEAR_DELAY := 2.0

enum State { TITLE, PLAYING, WAVECLEAR, GAMEOVER }

const MushroomScene := preload("res://mushroom.tscn")
const BulletScene := preload("res://bullet.tscn")
const SegmentScene := preload("res://centipede_segment.tscn")
const SpiderScene := preload("res://spider.tscn")
const FleaScene := preload("res://flea.tscn")
const ScorpionScene := preload("res://scorpion.tscn")
const ScorePopupScene := preload("res://score_popup.tscn")

@onready var _hud_layer: CanvasLayer = $HUD
@onready var _hud: Hud = $HUD/Root
@onready var _menus: Menus = $Menus/Root
@onready var _touch_controls: TouchControls = $TouchLayer/Root
@onready var _player: Player = $Player

var _state := State.TITLE
var _cfg := {}
var _touch := false
var _paused := false
var _score := 0
var _lives := 0
var _wave := 1
var _next_extra := 0
var _mushrooms := {}          # Vector2i -> Mushroom
var _chains: Array[CentipedeChain] = []
var _spider: Spider = null
var _spider_t := 0.0
var _flea: Flea = null
var _flea_check_t := 0.0
var _scorpion: Scorpion = null
var _scorpion_t := 0.0
var _wave_clear_t := 0.0

var _last_window_size := Vector2i.ZERO
var _cabinet_cam: Camera2D

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("touch_layout_listeners")

	_cfg = GameSettings.load_all()

	_touch = false if Input.get_connected_joypads().size() > 0 \
		else (OS.has_feature("mobile") or DisplayServer.is_touchscreen_available())
	_menus.set_touch_context(_touch)

	_player.is_blocked = _is_blocked_at
	_player.fire_requested.connect(_on_fire_requested)
	_player.zone_top_row = FieldGrid.zone_top_row(_cfg.movement_zone)
	_player.visible = false

	_hud.pause_pressed.connect(_toggle_pause)
	_hud.mute_pressed.connect(_toggle_mute)
	_hud.set_muted(_snd_muted())

	_touch_controls.fire_down.connect(func(): _player.fire_held = true)
	_touch_controls.fire_up.connect(func(): _player.fire_held = false)

	_menus.play_pressed.connect(_start_game)
	_menus.resume_pressed.connect(_resume)
	_menus.restart_pressed.connect(_start_game)
	_menus.quit_to_menu_pressed.connect(_to_title)
	_menus.settings_changed.connect(_apply_settings)

	get_window().size_changed.connect(_apply_display_mode)
	_last_window_size = DisplayServer.window_get_size()
	_apply_display_mode()

	add_to_group("touch_layout_listeners")
	apply_touch_layout()

	_to_title()

## Retroactive input-source flip (see player.gd/global CLAUDE.md #4): some
## browsers don't report touch synchronously at load, only once a real touch
## event arrives — re-checked via the "touch_layout_listeners" group.
func apply_touch_layout() -> void:
	_touch_controls.visible = _touch and _state == State.PLAYING
	_menus.set_touch_context(_touch)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		if not _touch:
			_touch = true
			get_tree().call_group("touch_layout_listeners", "apply_touch_layout")
	if event.is_action_pressed("pause") and (_state == State.PLAYING or _state == State.WAVECLEAR):
		_toggle_pause()
	elif event.is_action_pressed("mute"):
		_toggle_mute()

# ------------------------------------------------------------------- flow --
func _apply_settings(cfg: Dictionary) -> void:
	_cfg = cfg
	_player.zone_top_row = FieldGrid.zone_top_row(_cfg.movement_zone)

func _to_title() -> void:
	_state = State.TITLE
	get_tree().paused = false
	_paused = false
	_clear_field()
	_player.visible = false
	_hud_layer.visible = false
	_touch_controls.visible = false
	_menus.show_start()

func _start_game() -> void:
	_cfg = GameSettings.load_all()
	_score = 0
	_lives = _cfg.lives
	_wave = 1
	_next_extra = _cfg.extra_life if _cfg.extra_life > 0 else 0
	_hud_layer.visible = true
	_touch_controls.visible = _touch
	_hud.set_score(_score)
	_hud.set_lives(_lives)
	_hud.set_wave(_wave)
	_player.zone_top_row = FieldGrid.zone_top_row(_cfg.movement_zone)
	_clear_field()
	_spawn_wave()
	_player.reset(_spawn_point())
	_player.visible = true
	_player.input_enabled = true
	_state = State.PLAYING
	get_tree().paused = false
	_paused = false
	_spider_t = randf_range(SPIDER_INTERVAL_MIN, SPIDER_INTERVAL_MAX)
	_flea_check_t = FLEA_CHECK_INTERVAL
	_scorpion_t = randf_range(SCORPION_INTERVAL_MIN, SCORPION_INTERVAL_MAX)

func _spawn_point() -> Vector2:
	return Vector2(DESIGN_WIDTH * 0.5,
		FieldGrid.FIELD_TOP + FieldGrid.ROWS * FieldGrid.CELL - FieldGrid.CELL * 0.5)

func _spawn_wave() -> void:
	_clear_mushrooms()
	_scatter_mushrooms()
	_spawn_centipede()

func _scatter_mushrooms() -> void:
	var count: int = MUSHROOM_BASE_COUNT + (_wave - 1) * 2
	var placed := 0
	var attempts := 0
	while placed < count and attempts < count * 25:
		attempts += 1
		var col := randi_range(0, FieldGrid.COLS - 1)
		var row := randi_range(2, FieldGrid.ROWS - 5)
		var key := Vector2i(col, row)
		if _mushrooms.has(key):
			continue
		_add_mushroom(col, row)
		placed += 1

func _add_mushroom(col: int, row: int) -> void:
	var m: Mushroom = MushroomScene.instantiate()
	add_child(m)
	m.setup(col, row)
	_mushrooms[Vector2i(col, row)] = m

func _spawn_centipede() -> void:
	var segs: Array[CentipedeSegment] = []
	for i in range(INITIAL_SEGMENTS):
		var s: CentipedeSegment = SegmentScene.instantiate()
		add_child(s)
		segs.append(s)
	var chain := CentipedeChain.new()
	chain.blocked = _cell_blocked
	chain.poisoned = _cell_poisoned
	var interval: float = GameSettings.tick_interval(_cfg.difficulty) * pow(0.93, _wave - 1)
	chain.setup(segs, FieldGrid.COLS - 1, 0, -1, maxf(interval, 0.045))
	_chains.append(chain)

func _cell_blocked(col: int, row: int) -> bool:
	return _mushrooms.has(Vector2i(col, row))

func _cell_poisoned(col: int, row: int) -> bool:
	var key := Vector2i(col, row)
	return _mushrooms.has(key) and _mushrooms[key].poisoned

func _is_blocked_at(pos: Vector2) -> bool:
	var cell := FieldGrid.pixel_to_cell(pos)
	return _mushrooms.has(Vector2i(cell.x, cell.y))

func _clear_field() -> void:
	_hud.hide_wave_cleared_banner()
	_clear_mushrooms()
	for c in _chains:
		c.free_all()
	_chains.clear()
	if is_instance_valid(_spider):
		_spider.queue_free()
	_spider = null
	if is_instance_valid(_flea):
		_flea.queue_free()
	_flea = null
	if is_instance_valid(_scorpion):
		_scorpion.queue_free()
	_scorpion = null
	for b in get_tree().get_nodes_in_group("bullet"):
		b.queue_free()

func _clear_mushrooms() -> void:
	for m in _mushrooms.values():
		if is_instance_valid(m):
			m.queue_free()
	_mushrooms.clear()

# ---------------------------------------------------------------- combat --
func _on_fire_requested(from_pos: Vector2) -> void:
	var b: Bullet = BulletScene.instantiate()
	add_child(b)
	b.add_to_group("bullet")
	b.position = from_pos
	_snd_play("shoot")

func _process(delta: float) -> void:
	var win_now := DisplayServer.window_get_size()
	if win_now != _last_window_size:
		_last_window_size = win_now
		_apply_display_mode()

	if _state == State.WAVECLEAR:
		if not _paused:
			_wave_clear_t -= delta
			if _wave_clear_t <= 0.0:
				_finish_wave_clear()
		return

	if _state != State.PLAYING or _paused:
		return

	for chain in _chains.duplicate():
		chain.step(delta)

	if not is_instance_valid(_spider):
		_spider_t -= delta
		if _spider_t <= 0.0:
			_spawn_spider()
			_spider_t = randf_range(SPIDER_INTERVAL_MIN, SPIDER_INTERVAL_MAX)

	if not is_instance_valid(_scorpion):
		_scorpion_t -= delta
		if _scorpion_t <= 0.0:
			_spawn_scorpion()
			_scorpion_t = randf_range(SCORPION_INTERVAL_MIN, SCORPION_INTERVAL_MAX)

	_flea_check_t -= delta
	if _flea_check_t <= 0.0:
		_flea_check_t = FLEA_CHECK_INTERVAL
		_maybe_spawn_flea()

	_check_bullet_collisions()
	_check_player_collisions()
	_check_wave_clear()

func _spawn_spider() -> void:
	_spider = SpiderScene.instantiate()
	add_child(_spider)
	_spider.eat_mushroom = _spider_eat
	var top: float = FieldGrid.cell_to_pixel(0, FieldGrid.zone_top_row(_cfg.movement_zone)).y - FieldGrid.CELL
	var bottom: float = FieldGrid.FIELD_TOP + FieldGrid.ROWS * FieldGrid.CELL
	var start_x: float = FieldGrid.FIELD_LEFT if randf() < 0.5 else FieldGrid.DESIGN_WIDTH
	_spider.setup(Vector2(start_x, (top + bottom) * 0.5), top, bottom)

func _spider_eat(col: int, row: int) -> void:
	var key := Vector2i(col, row)
	if _mushrooms.has(key):
		var m: Mushroom = _mushrooms[key]
		_mushrooms.erase(key)
		m.queue_free()

func _maybe_spawn_flea() -> void:
	if is_instance_valid(_flea):
		return
	var zone_top: int = FieldGrid.zone_top_row(_cfg.movement_zone)
	var count := 0
	for key in _mushrooms:
		if key.y >= zone_top:
			count += 1
	if count >= FLEA_MUSHROOM_THRESHOLD:
		return
	_flea = FleaScene.instantiate()
	add_child(_flea)
	_flea.add_mushroom = _add_mushroom
	_flea.has_mushroom = func(c: int, r: int) -> bool: return _mushrooms.has(Vector2i(c, r))
	_flea.setup(randi_range(0, FieldGrid.COLS - 1))

func _spawn_scorpion() -> void:
	_scorpion = ScorpionScene.instantiate()
	add_child(_scorpion)
	_scorpion.poison_mushroom = _poison_mushroom_at
	var zone_top: int = FieldGrid.zone_top_row(_cfg.movement_zone)
	var row := randi_range(2, maxi(2, zone_top - 2))
	var dir := 1 if randf() < 0.5 else -1
	_scorpion.setup(row, dir)

func _poison_mushroom_at(col: int, row: int) -> void:
	var key := Vector2i(col, row)
	if _mushrooms.has(key):
		var m: Mushroom = _mushrooms[key]
		m.poison()

func _check_bullet_collisions() -> void:
	for b in get_tree().get_nodes_in_group("bullet"):
		if not is_instance_valid(b):
			continue
		if _bullet_vs_mushroom(b):
			continue
		if _bullet_vs_centipede(b):
			continue
		if _bullet_vs_spider(b):
			continue
		if _bullet_vs_flea(b):
			continue
		_bullet_vs_scorpion(b)

func _bullet_vs_mushroom(b: Node2D) -> bool:
	var cell := FieldGrid.pixel_to_cell(b.position)
	var key := Vector2i(cell.x, cell.y)
	if not _mushrooms.has(key):
		return false
	var m: Mushroom = _mushrooms[key]
	if b.position.distance_to(m.position) >= FieldGrid.CELL * 0.5:
		return false
	var destroyed := m.hit()
	b.queue_free()
	if destroyed:
		_mushrooms.erase(key)
		m.queue_free()
		_add_score(1)
		_snd_play("mushroom-break")
	else:
		_snd_play("mushroom-hit")
	return true

func _bullet_vs_centipede(b: Node2D) -> bool:
	for chain in _chains.duplicate():
		for i in range(chain.segments.size()):
			var seg: CentipedeSegment = chain.segments[i]
			if not is_instance_valid(seg):
				continue
			if b.position.distance_to(seg.position) >= FieldGrid.CELL * 0.45:
				continue
			var was_head: bool = seg.is_head
			var result: Dictionary = chain.hit(i)
			b.queue_free()
			_add_mushroom_from_hit(result.cell)
			var pts := 100 if was_head else 10
			_add_score(pts)
			_snd_play("segment-kill")
			if was_head:
				_spawn_score_popup(FieldGrid.cell_to_pixel(result.cell.x, result.cell.y), pts)
			if result.new_chain != null:
				_chains.append(result.new_chain)
			if result.empty:
				_chains.erase(chain)
			return true
	return false

func _bullet_vs_spider(b: Node2D) -> bool:
	if not is_instance_valid(_spider) or b.position.distance_to(_spider.position) >= 16.0:
		return false
	var pts := Spider.score_for_distance(_spider.position.distance_to(_player.position))
	_add_score(pts)
	_spawn_score_popup(_spider.position, pts)
	b.queue_free()
	_spider.queue_free()
	_spider = null
	_snd_play("spider-kill")
	return true

func _bullet_vs_flea(b: Node2D) -> bool:
	if not is_instance_valid(_flea) or b.position.distance_to(_flea.position) >= Flea.RADIUS + 4.0:
		return false
	_add_score(FLEA_SCORE)
	b.queue_free()
	_flea.queue_free()
	_flea = null
	_snd_play("flea-kill")
	return true

func _bullet_vs_scorpion(b: Node2D) -> bool:
	if not is_instance_valid(_scorpion) or b.position.distance_to(_scorpion.position) >= Scorpion.RADIUS * 1.6:
		return false
	_add_score(SCORPION_SCORE)
	_spawn_score_popup(_scorpion.position, SCORPION_SCORE)
	b.queue_free()
	_scorpion.queue_free()
	_scorpion = null
	_snd_play("scorpion-kill")
	return true

func _add_mushroom_from_hit(cell: Vector2i) -> void:
	if not _mushrooms.has(cell) and FieldGrid.in_bounds(cell.x, cell.y):
		_add_mushroom(cell.x, cell.y)

## Small floating "+N" — only for the kills worth calling out at a glance
## (centipede heads, spider, scorpion), not mushroom hits or body segments,
## which happen far too often to flash every single time.
func _spawn_score_popup(pos: Vector2, score: int) -> void:
	var p: ScorePopup = ScorePopupScene.instantiate()
	add_child(p)
	p.position = pos
	p.setup(score)

func _check_player_collisions() -> void:
	if not _player.alive:
		return
	for chain in _chains:
		for seg in chain.segments:
			if is_instance_valid(seg) and seg.position.distance_to(_player.position) < FieldGrid.CELL * 0.4:
				_kill_player()
				return
	if is_instance_valid(_spider) and _spider.position.distance_to(_player.position) < 20.0:
		_kill_player()
		return
	if is_instance_valid(_flea) and _flea.position.distance_to(_player.position) < Flea.RADIUS + 8.0:
		_kill_player()
		return
	if is_instance_valid(_scorpion) and _scorpion.position.distance_to(_player.position) < Scorpion.RADIUS + 8.0:
		_kill_player()

func _kill_player() -> void:
	if not _player.alive:
		return
	_player.alive = false
	_player.input_enabled = false
	_snd_play("player-death")
	_lives -= 1
	_hud.set_lives(_lives)
	if _lives <= 0:
		_game_over()
		return
	await get_tree().create_timer(1.0).timeout
	if _state != State.PLAYING:
		return
	_player.reset(_spawn_point())
	_player.input_enabled = true

## Wave just cleared: hold PLAYING's per-frame logic (chain stepping, enemy
## spawns, collisions) for WAVE_CLEAR_DELAY seconds while the "CLEARED!"
## banner + fanfare play, THEN advance the wave counter and spawn the next
## one — see _finish_wave_clear() and the State.WAVECLEAR branch in _process().
func _check_wave_clear() -> void:
	if _chains.is_empty():
		_state = State.WAVECLEAR
		_wave_clear_t = WAVE_CLEAR_DELAY
		_snd_play("wave-cleared")
		_hud.show_wave_cleared_banner(WAVE_CLEAR_DELAY)

func _finish_wave_clear() -> void:
	_wave += 1
	_hud.set_wave(_wave)
	_spawn_wave()
	_state = State.PLAYING

func _add_score(n: int) -> void:
	_score += n
	_hud.set_score(_score)
	if _next_extra > 0 and _score >= _next_extra:
		_lives = mini(_lives + 1, 99)
		_hud.set_lives(_lives)
		_next_extra += _cfg.extra_life
		_snd_play("extra-life")

func _game_over() -> void:
	_state = State.GAMEOVER
	_snd_play("game-over")
	_menus.show_gameover(_score, _wave)

# ------------------------------------------------------------------ pause --
func _toggle_pause() -> void:
	if _state != State.PLAYING and _state != State.WAVECLEAR:
		return
	_paused = not _paused
	get_tree().paused = _paused
	if _paused:
		_menus.show_pause()
	else:
		_menus.hide_all()

func _resume() -> void:
	_paused = false
	get_tree().paused = false

func _toggle_mute() -> void:
	var snd := get_node_or_null("/root/Snd")
	if snd:
		_hud.set_muted(snd.toggle_mute())

func _snd_muted() -> bool:
	var snd := get_node_or_null("/root/Snd")
	return snd.is_muted() if snd else false

func _snd_play(key: String) -> void:
	var snd := get_node_or_null("/root/Snd")
	if snd:
		snd.play(key)

# --------------------------------------------------- landscape cabinet mode --
func _wants_cabinet_overlay() -> bool:
	var win := DisplayServer.window_get_size()
	return win.x > win.y

func _apply_display_mode() -> void:
	var cabinet := _wants_cabinet_overlay()
	get_window().content_scale_aspect = (
		Window.CONTENT_SCALE_ASPECT_EXPAND if cabinet
		else Window.CONTENT_SCALE_ASPECT_KEEP_WIDTH if _touch
		else Window.CONTENT_SCALE_ASPECT_KEEP)
	_set_cabinet_camera_active(cabinet)
	_center_canvas_layers(cabinet)

func _set_cabinet_camera_active(cabinet: bool) -> void:
	if cabinet and not is_instance_valid(_cabinet_cam):
		_cabinet_cam = Camera2D.new()
		_cabinet_cam.position = Vector2(DESIGN_WIDTH * 0.5, DESIGN_HEIGHT * 0.5)
		add_child(_cabinet_cam)
	if is_instance_valid(_cabinet_cam):
		_cabinet_cam.enabled = cabinet
		if cabinet:
			_cabinet_cam.make_current()

func _center_canvas_layers(cabinet: bool) -> void:
	var offset_x := 0.0
	if cabinet:
		offset_x = maxf(get_viewport_rect().size.x - DESIGN_WIDTH, 0.0) * 0.5
	_hud.set_cabinet_lane(cabinet, offset_x)
	_menus.set_cabinet_lane(cabinet, offset_x)
	_touch_controls.set_cabinet_lane(cabinet, offset_x)
