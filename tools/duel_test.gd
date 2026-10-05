extends SceneTree

## Protocol test of the two-device duel without any UI: a host and a guest
## Duel node in one process, connected over LAN loopback (ENet on 127.0.0.1) —
## or, with `-- online <ws-url>`, through a running relay.
##   godot --headless --audio-driver Dummy --path . --script res://tools/duel_test.gd
##   godot ... --script res://tools/duel_test.gd -- online ws://127.0.0.1:8765
## Exit code 0 = all checks passed.

var host: Duel
var guest: Duel
var t := 0.0
var stage := 0
var stage_t := 0.0
var fails := 0
var online := false
var seeds := []
var cfgs := []
var ended_text := ""
var code := ""

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	online = args.size() >= 2 and args[0] == "online"
	if online:
		OS.set_environment("CENTIPEDE_RELAY", args[1])
	host = Duel.new()
	guest = Duel.new()
	root.add_child(host)
	root.add_child(guest)
	host.round_started.connect(func(s, c): seeds.append(["h", s]); cfgs.append(c))
	guest.round_started.connect(func(s, c): seeds.append(["g", s]); cfgs.append(c))
	host.ended.connect(func(txt): ended_text = txt)
	host.room_ready.connect(func(c): code = c)
	var cfg := {"lives": 3, "movement_zone": 1, "difficulty": 1, "extra_life": 12000}
	var err := OK
	if online:
		err = host.host_online(cfg)
	else:
		err = host.host_lan(cfg)
	_expect(err == OK, "host opens (err %d)" % err)
	if not online:
		err = guest.join_lan("127.0.0.1")
		_expect(err == OK, "guest connects (err %d)" % err)

func _process(delta: float) -> bool:
	t += delta
	stage_t += delta
	if stage_t > 20.0:
		_expect(false, "stage %d timed out" % stage)
		return _finish()
	match stage:
		0:
			if online and code != "" and not guest.is_active():
				_expect(guest.join_online(code) == OK, "guest joins room %s" % code)
			if seeds.size() >= 2:
				_expect(seeds[0][1] == seeds[1][1], "both sides get the same seed")
				_expect(cfgs[0] == cfgs[1] and int(cfgs[1].lives) == 3, "both sides get the host's settings")
				_expect(host.in_round and guest.in_round, "both are in a round")
				host.report(120, 2, 1)
				guest.report(300, 3, 2)
				_next()
		1:
			if stage_t > 1.0:
				_expect(guest.opp_score == 120 and guest.opp_lives == 2, "guest sees the host's numbers (%d / %d)" % [guest.opp_score, guest.opp_lives])
				_expect(host.opp_score == 300 and host.opp_wave == 2, "host sees the guest's numbers (%d / w%d)" % [host.opp_score, host.opp_wave])
				host.finish(500, 3)
				_next()
		2:
			if stage_t > 0.7:
				_expect(guest.opp_over and guest.opp_score == 500, "guest learns the host is done")
				_expect(guest.result() == 0 and host.result() == 0, "no result while one is still playing")
				guest.finish(300, 2)
				_next()
		3:
			if stage_t > 0.7:
				_expect(host.result() == 1 and guest.result() == 2, "result: host wins 500:300 (%d/%d)" % [host.result(), guest.result()])
				_expect(host.wins == 1 and guest.losses == 1, "tally counted once")
				seeds.clear()
				host.want_rematch()
				guest.want_rematch()
				_next()
		4:
			if seeds.size() >= 2:
				_expect(seeds[0][1] == seeds[1][1], "rematch: same new seed on both")
				_expect(host.result() == 0 and not host.my_over and not host.opp_over, "rematch: round state reset")
				_expect(host.wins == 1, "rematch: tally survives")
				host.finish(100, 1)
				guest.finish(100, 1)
				_next()
		5:
			if stage_t > 0.7:
				_expect(host.result() == 3 and guest.result() == 3, "equal scores: draw")
				_expect(host.draws == 1, "draw counted")
				guest.leave()
				_next()
		6:
			if ended_text != "":
				_expect(ended_text.contains("left"), "host is told the guest left: '%s'" % ended_text.replace("\n", " "))
				host.leave()
				return _finish()
	return false

func _next() -> void:
	stage += 1
	stage_t = 0.0

func _finish() -> bool:
	if fails == 0:
		print("duel_test: all checks passed")
	else:
		printerr("duel_test: %d check(s) FAILED" % fails)
	quit(1 if fails > 0 else 0)
	return true

func _expect(cond: bool, label: String) -> void:
	if cond:
		print("  ok  ", label)
	else:
		printerr("  FAIL ", label)
		fails += 1
