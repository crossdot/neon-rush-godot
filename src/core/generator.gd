# NEON RUN — pattern-based obstacle generator (ТЗ §21–23). Port of js/generator.js.
# World scrolls downward; cursor nextY = screen-y of the top edge of the next block.
class_name Generator

var entities: Entities = null
var nextY: float = 0.0
var patternsSpawned: int = 0


func _init(ent: Entities) -> void:
	entities = ent


func reset() -> void:
	nextY = -Gamedata.CELLH * 1.5
	patternsSpawned = 0


func pick_pattern(max_d: int) -> Dictionary:
	var lo: int = maxi(1, max_d - 1)
	var pool := []
	for p in Patterns.PATTERNS:
		if p.d <= max_d and p.d >= lo:
			pool.append(p)
	if pool.is_empty():
		for p in Patterns.PATTERNS:
			if p.d <= max_d:
				pool.append(p)
	return Utils.choice(pool)


func update(dt: float, scroll: float, level_cfg: Dictionary, W: float, H: float) -> void:
	var E := entities
	nextY += scroll * dt
	var guard: int = 0
	while guard < 3:
		guard += 1
		var pat := pick_pattern(level_cfg.maxD)
		var h: float = pat.rows.size() * Gamedata.CELLH
		if nextY + h < -30.0:
			break
		var base_y: float = nextY
		for r in range(pat.rows.size()):
			var row: String = pat.rows[r]
			var row_y: float = base_y + r * Gamedata.CELLH
			var c: int = 0
			var cols: int = Gamedata.COLS
			while c < cols:
				var ch: String = row[c]
				if ch == "L":
					var c2: int = c
					while c2 + 1 < cols and row[c2 + 1] == "L":
						c2 += 1
					if level_cfg.types.get("laser", 0):
						E.spawn("laser", c, row_y, { "cols": [c, c2] })
					else:
						E.spawn("wall", int((c + c2) / 2.0), row_y)
					c = c2 + 1
					continue
				var type: String = ""
				match ch:
					"#":
						type = "wall"
					"M":
						type = "mine" if level_cfg.types.get("mine", 0) else "wall"
					">", "<":
						type = "walker" if level_cfg.types.get("walker", 0) else "wall"
					"S":
						type = "seeker" if level_cfg.types.get("seeker", 0) else "mine"
					"V":
						type = "vlaser" if level_cfg.types.get("vlaser", 0) else "wall"
					"R":
						type = "rift" if level_cfg.types.get("rift", 0) else "crystal"
					"E":
						type = "crystal"
					"G":
						type = "gate" if level_cfg.types.get("gate", 0) else "crystal"
					"H":
						type = "orb"
				if type != "":
					E.spawn(type, c, row_y)
				c += 1
		var gap: float = maxf(level_cfg.gapMin, scroll * 0.4) + Utils.frand(0.0, 90.0)
		if Utils.frand(0.0, 1.0) < 0.5:
			var col: int = Utils.irand(Gamedata.COLS)
			var n: int = Utils.irand(3) + 2
			for k in range(n):
				E.spawn("crystal", col, base_y - gap + 30.0 + k * 58.0)
		elif Utils.frand(0.0, 1.0) < 0.16:
			E.spawn("orb", Utils.irand(Gamedata.COLS), base_y - gap + 40.0)
		nextY = base_y - h - gap
		patternsSpawned += 1
