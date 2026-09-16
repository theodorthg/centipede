class_name HallOfFame

## Top-10 score board, persisted in user://hall_of_fame.cfg.

const PATH := "user://hall_of_fame.cfg"
const MAX := 10

static func load_list() -> Array:
	var c := ConfigFile.new()
	if c.load(PATH) != OK:
		return []
	var raw = c.get_value("hof", "entries", [])
	return raw if raw is Array else []

static func _save_list(list: Array) -> void:
	var c := ConfigFile.new()
	c.set_value("hof", "entries", list)
	c.save(PATH)

static func qualifies(score: int) -> bool:
	if score <= 0:
		return false
	var list := load_list()
	if list.size() < MAX:
		return true
	return score > int(list[list.size() - 1].get("score", 0))

static func insert(who: String, score: int, wave: int) -> Array:
	var list := load_list()
	list.append({"name": who, "score": score, "wave": wave})
	list.sort_custom(func(a, b): return int(a.get("score", 0)) > int(b.get("score", 0)))
	if list.size() > MAX:
		list = list.slice(0, MAX)
	_save_list(list)
	return list
