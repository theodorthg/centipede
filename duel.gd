class_name Duel
extends Node

## Two players, each on their own device (LAN / Wi-Fi, or online through the
## series' relay — see NetLink), each running their OWN game at the same time:
## the same mushroom fields (same seed) and the same rules (the host's
## settings), nothing of the other side is simulated. Whoever scores more
## when both games are over wins the round. What goes over the line:
##   hello {v}          both, on connect — major.minor must match
##   start {seed, cfg}  the host starts a round (cfg: lives, zone, difficulty, extra life)
##   st    {s, l, w}    my score / lives / wave, at most 5 times a second
##   over  {s, w}       my game is over (final score, wave)
##   again              I want a rematch (the host starts when both want one)
##   bye                I leave

signal room_ready(code: String)
signal round_started(seed: int, cfg: Dictionary)
signal opponent_changed                      ## their numbers, or the round result
signal rematch_changed(mine: bool, theirs: bool)
signal ended(text: String)                   ## connection gone / refused: back to the menu
signal lan_hosts_changed(hosts: Dictionary)  ## LAN guest: ip -> name

const STATUS_EVERY := 0.2
## Connecting (online server, or a LAN host) is given up after this long.
const CONNECT_TIMEOUT := 15.0
const FIREWALL_HINT := "Same network? A host PC with a firewall must allow UDP 47110-47111 — or play Online, that always works."

var link: NetLink
var discovery: NetLink.Discovery           ## LAN: host beacon / guest search
var wins := 0
var losses := 0
var draws := 0
var in_round := false
var my_over := false
var opp_over := false
var opp_score := 0
var opp_lives := 0
var opp_wave := 1
var my_score := 0
var my_wave := 1
var start_cfg := {}                         ## host: the rules of every round
var _hello_ok := false
var _again_mine := false
var _again_theirs := false
var _tallied := false
var _status_t := 0.0
var _status_dirty := false
var _my_lives := 0
var _watch := 0.0                           ## seconds spent connecting (0 = not watching)
var _watching := false
var _lan_ip := ""
var _online := false
var _hosts_seen := {}


func is_active() -> bool:
	return link != null or discovery != null


## 0 = not decided yet, 1 = I win, 2 = I lose, 3 = draw
func result() -> int:
	if not (my_over and opp_over):
		return 0
	if my_score == opp_score:
		return 3
	return 1 if my_score > opp_score else 2


# --- connecting ----------------------------------------------------------------

func host_online(cfg: Dictionary) -> int:
	_reset()
	start_cfg = cfg
	_online = true
	link = NetLink.new()
	_watching = true
	return link.host_online(NetLink.relay_url())


func join_online(code: String) -> int:
	_reset()
	_online = true
	link = NetLink.new()
	_watching = true
	return link.join_online(NetLink.relay_url(), code)


## LAN host: open the game port and answer searches (waits for a guest as
## long as it takes).
func host_lan(cfg: Dictionary) -> int:
	_reset()
	start_cfg = cfg
	link = NetLink.new()
	var err := link.host_lan()
	if err != OK:
		link = null
		return err
	discovery = NetLink.Discovery.new()
	discovery.start_host(NetLink.device_name())
	return OK


## LAN guest, step 1: look for hosts (lan_hosts_changed while searching).
func search_lan() -> void:
	_reset()
	_hosts_seen = {}
	discovery = NetLink.Discovery.new()
	discovery.start_search()


## LAN guest, step 2: connect to a host.
func join_lan(ip: String) -> int:
	_stop_discovery()
	if link:
		link.close()
	link = NetLink.new()
	_lan_ip = ip
	_watch = 0.0
	_watching = true
	return link.join_lan(ip)


func _stop_discovery() -> void:
	if discovery:
		discovery.stop()
	discovery = null


func _reset() -> void:
	_stop_discovery()
	if link:
		link.close()
	link = null
	wins = 0
	losses = 0
	draws = 0
	in_round = false
	my_over = false
	opp_over = false
	_hello_ok = false
	_again_mine = false
	_again_theirs = false
	_tallied = false
	_watching = false
	_watch = 0.0
	_online = false
	_lan_ip = ""


## Leave on purpose: tell the other side, close.
func leave() -> void:
	_stop_discovery()
	if link:
		link.send("bye", 0)
		link.close()
	link = null
	in_round = false
	_watching = false


func _process(delta: float) -> void:
	if discovery:
		discovery.poll(delta)
		if not discovery.hosting:
			var now := {}
			for ip in discovery.found:
				now[ip] = str(discovery.found[ip].name)
			if now != _hosts_seen:
				_hosts_seen = now
				lan_hosts_changed.emit(now)
	if link == null:
		return
	if _watching:
		_watch += delta
		if _watch >= CONNECT_TIMEOUT:
			if _online:
				_end("The online server did not answer in time.\nPlease try again.")
			else:
				_end("No answer from %s.\n%s" % [_lan_ip, FIREWALL_HINT])
			return
	for ev in link.poll():
		match ev[0]:
			"room":
				_watching = false        # the server is there; now it's up to the guest
				room_ready.emit(ev[1])
			"connect":
				_watching = false
				_stop_discovery()
				link.send("hello", {"v": NetLink.version()})
			"disconnect":
				if link.ever_connected:
					_end("Your opponent left the game.")
				else:
					_end("No answer from %s.\n%s" % [_lan_ip, FIREWALL_HINT])
				return
			"error", "closed":
				_end(ev[1])
				return
			"msg":
				_on_msg(str(ev[1]), ev[2])
				if link == null:
					return
	if in_round and _status_dirty:
		_status_t -= delta
		if _status_t <= 0.0:
			_send_status()


func _send_status() -> void:
	_status_dirty = false
	_status_t = STATUS_EVERY
	if link:
		link.send("st", {"s": my_score, "l": _my_lives, "w": my_wave})


func _end(text: String) -> void:
	_stop_discovery()
	if link:
		link.close()
	link = null
	in_round = false
	_watching = false
	ended.emit(text)


static func _major_minor(v: String) -> String:
	var p := v.split(".")
	return ".".join(p.slice(0, 2))


func _on_msg(type: String, d) -> void:
	match type:
		"hello":
			var theirs := str((d as Dictionary).get("v", "")) if d is Dictionary else ""
			if _major_minor(theirs) != _major_minor(NetLink.version()):
				link.send("bye", 0)
				_end("Different game versions (%s here, %s there) — please update both." \
					% [NetLink.version(), theirs])
				return
			_hello_ok = true
			if link.is_host:
				_start_round()
		"start":
			if d is Dictionary:
				_begin_round(int(d.seed), d.get("cfg", {}))
		"st":
			if d is Dictionary and in_round:
				opp_score = int(d.get("s", 0))
				opp_lives = int(d.get("l", 0))
				opp_wave = int(d.get("w", 1))
				opponent_changed.emit()
		"over":
			if d is Dictionary and in_round:
				opp_over = true
				opp_score = int(d.get("s", 0))
				opp_wave = int(d.get("w", 1))
				opp_lives = 0
				_check_round_end()
				opponent_changed.emit()
		"again":
			_again_theirs = true
			rematch_changed.emit(_again_mine, _again_theirs)
			_maybe_rematch()
		"bye":
			_end("Your opponent left the game.")


func _start_round() -> void:
	var seed := randi() & 0x7fffffff
	link.send("start", {"seed": seed, "cfg": start_cfg})
	_begin_round(seed, start_cfg)


func _begin_round(seed: int, cfg: Dictionary) -> void:
	_again_mine = false
	_again_theirs = false
	in_round = true
	my_over = false
	opp_over = false
	_tallied = false
	my_score = 0
	my_wave = 1
	opp_score = 0
	opp_wave = 1
	opp_lives = int(cfg.get("lives", 3))
	_my_lives = opp_lives
	_status_dirty = true
	_status_t = 0.0
	round_started.emit(seed, cfg)


## Both games over: who won (counted once per round).
func _check_round_end() -> void:
	if _tallied or not (my_over and opp_over):
		return
	_tallied = true
	match result():
		1:
			wins += 1
		2:
			losses += 1
		_:
			draws += 1


# --- called by the game ------------------------------------------------------------

## My numbers changed (score, a life lost, next wave).
func report(score: int, lives: int, wave: int) -> void:
	my_score = score
	_my_lives = lives
	my_wave = wave
	_status_dirty = true


## My game is over for good.
func finish(score: int, wave: int) -> void:
	if not in_round or my_over:
		return
	my_score = score
	my_wave = wave
	my_over = true
	if link:
		link.send("st", {"s": score, "l": 0, "w": wave})
		link.send("over", {"s": score, "w": wave})
	_check_round_end()


func want_rematch() -> void:
	_again_mine = true
	if link:
		link.send("again", 0)
	rematch_changed.emit(_again_mine, _again_theirs)
	_maybe_rematch()


func rematch_wanted() -> bool:
	return _again_mine


func _maybe_rematch() -> void:
	if link and link.is_host and _again_mine and _again_theirs and _hello_ok:
		_start_round()
