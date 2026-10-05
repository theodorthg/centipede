extends SceneTree

## Plays the guest side of a duel against a real game window, headless:
##   godot --headless --audio-driver Dummy --path . --script res://tools/duelbot.gd -- lan 127.0.0.1
##   godot ... --script res://tools/duelbot.gd -- online ABCD [ws://127.0.0.1:8765]
## or hosts (so the window under test can be the guest):
##   godot ... --script res://tools/duelbot.gd -- hostlan
##   godot ... --script res://tools/duelbot.gd -- hostonline - ws://127.0.0.1:8765
## It joins, steers the blaster left/right while shooting, loses its lives
## after PLAY_SECONDS, asks for a rematch once and then leaves.

const PLAY_SECONDS := 14.0

var g: Node
var t := 0.0
var round_t := 0.0
var phase := 0
var rounds := 0
var mode := ""
var target := ""
var next_kill := 0.0

func _initialize() -> void:
	# The godot-mcp-pro autoloads would register this headless process as "the
	# game" at the MCP server and steal the screenshots meant for the real window.
	for n in ["MCPGameInspector", "MCPInputService", "MCPScreenshot"]:
		var node := root.get_node_or_null(n)
		if node:
			root.remove_child(node)
			node.free()
	var args := OS.get_cmdline_user_args()
	mode = args[0]
	target = args[1] if args.size() > 1 else ""
	if mode == "online" and args.size() > 2:
		OS.set_environment("CENTIPEDE_RELAY", args[2])
	if mode == "hostonline" and args.size() > 2:
		OS.set_environment("CENTIPEDE_RELAY", args[2])
	g = load("res://game.tscn").instantiate()
	root.add_child(g)

func _process(delta: float) -> bool:
	t += delta
	if phase == 0 and t > 0.5:
		for c in g.get_children():
			if c is Splash:
				c.queue_free()                     # its "done" would send us to the title screen later
		g._to_title(false)
		g._menus.hide_all()
		var err := OK
		var cfg := {"lives": 3, "movement_zone": 1, "difficulty": 1, "extra_life": 12000}
		match mode:
			"lan":
				err = g._duel.join_lan(target)
			"online":
				err = g._duel.join_online(target)
			"hostlan":
				err = g._duel.host_lan(cfg)
			"hostonline":
				err = g._duel.host_online(cfg)
				g._duel.room_ready.connect(func(c): print("bot: room code ", c))
		print("bot: %s %s -> %d" % [mode, target, err])
		g._duel.round_started.connect(func(s, _c): print("bot: round started, seed %d" % s); round_t = 0.0; rounds += 1)
		g._duel.ended.connect(func(txt): print("bot: duel ended: ", txt.replace("\n", " ")); quit(0))
		phase = 1
	elif phase == 1:
		if g._mode == 2 and g._state != 3:        # Mode.DUEL, not game over
			round_t += delta
			g._player.position.x = 270.0 + 200.0 * sin(round_t * 2.0)
			g._player.fire_held = true
			if round_t > PLAY_SECONDS and g._state == 1 and round_t > next_kill:
				next_kill = round_t + 1.2
				g._player.invulnerable = false
				g._kill_player()
		elif g._state == 3 and g._duel.my_over:
			if int(t * 2) % 8 == 0:
				pass
			if g._duel.result() != 0:
				print("bot: round over, result %d (1 = bot wins), me %d : opp %d" % [g._duel.result(), g._duel.my_score, g._duel.opp_score])
				if rounds < 2:
					g._duel.want_rematch()
					phase = 2
				else:
					g._duel.leave()
					quit(0)
	elif phase == 2:
		if g._state != 3:
			phase = 1
	if t > 240.0:
		print("bot: timeout")
		quit(1)
	return false
