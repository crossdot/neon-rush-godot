# NEON RUN — pooled entities: wall, mine, seeker, walker, laser, vlaser, gate, rift, crystal, orb.
# Port of js/entities.js. Pool of Dictionaries; all update logic here; drawing via
# a single CanvasItem draw pass (no per-entity nodes) for performance.
class_name Entities

const MAX := 260

var pool: Array = []
var _cw: float = Gamedata.W / Gamedata.COLS


func _init() -> void:
	for i in range(MAX):
		pool.append({ "active": false, "type": "" })


func _grab() -> Variant:
	for e in pool:
		if not e.active:
			return e
	return null


func spawn(type: String, col: int, rowY: float, extra: Dictionary = {}):
	var e = _grab()
	if e == null:
		return null
	var cw: float = _cw
	e.active = true
	e.type = type
	e.dead = false
	e.col = col
	e.timer = 0.0
	e.seed = Utils.frand(0.0, TAU)
	e.state = 0
	e.taken = false
	e.cc = 0
	e.cx = (col + 0.5) * cw
	e.x = col * cw
	e.y = rowY
	e.w = cw
	e.h = Gamedata.CELLH
	e.r = 0.0
	match type:
		"wall":
			e.w = cw * 0.92
			e.h = Gamedata.CELLH * 0.5
			e.x = e.cx - e.w / 2.0
			e.y = rowY + (Gamedata.CELLH - e.h) / 2.0
		"mine":
			e.r = 24.0
		"walker":
			e.w = cw * 0.95
			e.h = Gamedata.CELLH * 0.42
			e.baseCx = e.cx
			e.amp = cw * (extra.get("amp", 1.1))
			e.freq = 1.6
		"laser":
			e.cols = extra.cols
			e.y = rowY + Gamedata.CELLH / 2.0
			e.phase = "warn"
			e.armed = 0
		"gate":
			e.h = 26.0
			e.y = rowY + Gamedata.CELLH * 0.45
		"crystal":
			e.r = 13.0
		"seeker":
			e.r = 20.0
			e.spd = 150.0
		"vlaser":
			e.phase = "warn"
			e.armed = 0
		"rift":
			e.r = 210.0
		"orb":
			e.r = 17.0
	return e


func reset() -> void:
	for e in pool:
		e.active = false


func update(dt: float, scroll: float, player, magnetR: float, W: float, H: float) -> void:
	var cw: float = _cw
	for e in pool:
		if not e.active:
			continue
		e.timer += dt
		e.y += scroll * dt
		match e.type:
			"walker":
				e.cx = W / 2.0 + sin(e.timer * e.freq + e.seed) * e.amp * 0.5 + (e.baseCx - W / 2.0) * 0.55
				e.x = e.cx - e.w / 2.0
			"laser":
				if e.y < -10.0 and not e.armed:
					continue
				if not e.armed:
					e.armed = 1
					e.timer = 0.0
				if e.phase == "warn" and e.timer > 0.9:
					e.phase = "fire"
					e.timer = 0.0
				elif e.phase == "fire" and e.timer > 1.4:
					e.phase = "off"
			"seeker":
				if player != null:
					var dx: float = player.x - e.cx
					e.cx += clampf(dx, -e.spd * dt, e.spd * dt)
			"vlaser":
				if e.y < -10.0 and not e.armed:
					continue
				if not e.armed:
					e.armed = 1
					e.timer = 0.0
				if e.phase == "warn" and e.timer > 0.5:
					e.phase = "fire"
					e.timer = 0.0
					Audio.sfx("vlaser")
				elif e.phase == "fire" and e.timer > 0.45:
					e.phase = "idle"
					e.timer = 0.0
				elif e.phase == "idle" and e.timer > 1.5:
					e.phase = "warn"
					e.timer = 0.0
			"crystal":
				if player != null and magnetR > 0.0:
					var mdx: float = player.x - e.cx
					var mdy: float = player.y - (e.y + Gamedata.CELLH / 2.0)
					var d2: float = mdx * mdx + mdy * mdy
					if d2 < magnetR * magnetR and d2 > 1.0:
						var d: float = sqrt(d2)
						var pull: float = 420.0 * dt
						e.cx += mdx / d * pull
						e.y += mdy / d * pull
		if e.y > H + 160.0:
			e.active = false


func draw(ci: CanvasItem, pal: Dictionary, W: float, H: float) -> void:
	var cw: float = _cw
	var accent: Color = Color(pal.accent)
	var accent2: Color = Color(pal.accent2)
	for e in pool:
		if not e.active:
			continue
		match e.type:
			"wall":
				ci.draw_rect(Rect2(e.x, e.y, e.w, e.h), Color(accent.r, accent.g, accent.b, 0.16))
				ci.draw_rect(Rect2(e.x, e.y, e.w, e.h), accent, false, 2.0)
				Utils.draw_glow(ci, accent, e.x + e.w / 2.0, e.y + e.h / 2.0, maxf(e.w, e.h) * 0.8)
			"mine":
				var pul: float = 1.0 + sin(e.timer * 6.0) * 0.12
				var my: float = e.y + Gamedata.CELLH / 2.0
				Utils.draw_glow(ci, Color("#ff3d7f"), e.cx, my, e.r * 2.6 * pul)
				ci.draw_circle(Vector2(e.cx, my), e.r * pul, Color("#3a0a1e"))
				ci.draw_arc(Vector2(e.cx, my), e.r * pul, 0.0, TAU, 24, Color("#ff3d7f"), 2.5)
				ci.draw_set_transform(Vector2(e.cx, my), e.timer * 2.0, Vector2.ONE)
				for k in range(4):
					ci.draw_set_transform(Vector2(e.cx, my), e.timer * 2.0 + k * PI / 2.0, Vector2.ONE)
					ci.draw_line(Vector2(e.r * 0.5, 0), Vector2(e.r * 1.25, 0), Color("#ff9ab5"), 2.0)
				ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			"walker":
				ci.draw_rect(Rect2(e.x, e.y + Gamedata.CELLH * 0.25, e.w, e.h), Color(accent2.r, accent2.g, accent2.b, 0.2))
				ci.draw_rect(Rect2(e.x, e.y + Gamedata.CELLH * 0.25, e.w, e.h), accent2, false, 2.5)
			"laser":
				var x0: float = e.cols[0] * cw
				var x1: float = (e.cols[1] + 1) * cw
				ci.draw_rect(Rect2(x0 - 8, e.y - 6, 8, 12), accent2)
				ci.draw_rect(Rect2(x1, e.y - 6, 8, 12), accent2)
				if e.phase == "warn":
					var blink: float = 0.85 if sin(e.timer * 16.0) > 0.0 else 0.25
					var col: Color = Color(accent2.r, accent2.g, accent2.b, blink)
					ci.draw_dashed_line(Vector2(x0, e.y), Vector2(x1, e.y), col, 2.0, 10.0)
				elif e.phase == "fire":
					Utils.draw_glow(ci, Color("#ff2fd0"), (x0 + x1) / 2.0, e.y, (x1 - x0) * 0.55)
					ci.draw_line(Vector2(x0, e.y), Vector2(x1, e.y), Color("#ffd9f3"), 5.0)
					ci.draw_line(Vector2(x0, e.y), Vector2(x1, e.y), Color("#ff2fd0"), 2.0)
			"gate":
				var c: Color = Color("#31506b") if e.taken else accent
				ci.draw_line(Vector2(e.x + 4, e.y - 26), Vector2(e.x + 4, e.y + 26), c, 3.0)
				ci.draw_line(Vector2(e.x + e.w - 4, e.y - 26), Vector2(e.x + e.w - 4, e.y + 26), c, 3.0)
				var galpha: float = 0.2 if e.taken else 0.75
				ci.draw_rect(Rect2(e.x, e.y - 5, e.w, 10), Color(c.r, c.g, c.b, galpha))
			"crystal":
				var cy: float = e.y + Gamedata.CELLH / 2.0
				Utils.draw_glow(ci, Color("#00eaff"), e.cx, cy, e.r * 3.0)
				ci.draw_set_transform(Vector2(e.cx, cy), e.timer * 2.4, Vector2.ONE)
				var d := PackedVector2Array([
					Vector2(0, -e.r), Vector2(e.r * 0.72, 0), Vector2(0, e.r), Vector2(-e.r * 0.72, 0)
				])
				ci.draw_colored_polygon(d, Color("#d9f7ff"))
				ci.draw_polyline(d + PackedVector2Array([d[0]]), Color("#00eaff"), 1.5)
				ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			"seeker":
				var scy: float = e.y + Gamedata.CELLH / 2.0
				Utils.draw_glow(ci, Color("#ffb03d"), e.cx, scy, e.r * 2.8)
				ci.draw_set_transform(Vector2(e.cx, scy), sin(e.timer * 3.0) * 0.4, Vector2.ONE)
				var sd := PackedVector2Array([
					Vector2(0, -e.r), Vector2(e.r, 0), Vector2(0, e.r), Vector2(-e.r, 0)
				])
				ci.draw_colored_polygon(sd, Color("#3a2408"))
				ci.draw_polyline(sd + PackedVector2Array([sd[0]]), Color("#ffb03d"), 2.5)
				var pc: Color = Color("#ffe14d") if sin(e.timer * 8.0) > 0.0 else Color("#ff6a00")
				ci.draw_circle(Vector2.ZERO, 6.0, pc)
				ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			"vlaser":
				var blink: float = 0.8 if sin(e.timer * 18.0) > 0.0 else 0.2
				ci.draw_rect(Rect2(e.cx - 10, 0, 20, 8), accent2)
				if e.phase == "warn":
					ci.draw_dashed_line(Vector2(e.cx, 0), Vector2(e.cx, H), Color(1.0, 0.88, 0.3, blink), 2.0, 12.0)
				elif e.phase == "fire":
					ci.draw_rect(Rect2(e.cx - 30, 0, 60, H), Color(1.0, 0.88, 0.3, 0.35))
					ci.draw_line(Vector2(e.cx, 0), Vector2(e.cx, H), Color("#fff3b0"), 5.0)
					ci.draw_line(Vector2(e.cx, 0), Vector2(e.cx, H), Color("#ffe14d"), 2.0)
			"rift":
				var rcy: float = e.y + Gamedata.CELLH / 2.0
				Utils.draw_glow(ci, Color("#8a4dff"), e.cx, rcy, e.r * 0.9)
				ci.draw_set_transform(Vector2(e.cx, rcy), 0.0, Vector2.ONE)
				for k in range(3):
					ci.draw_arc(Vector2.ZERO, 26.0 + k * 30.0, 0.4, 3.6, 24, Color(0.7, 0.53, 1.0, 0.7 - k * 0.18), 3.0)
				ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			"orb":
				var ocy: float = e.y + Gamedata.CELLH / 2.0
				var opul: float = 1.0 + sin(e.timer * 5.0) * 0.15
				Utils.draw_glow(ci, Color("#59ffb0"), e.cx, ocy, e.r * 3.2 * opul)
				ci.draw_set_transform(Vector2(e.cx, ocy), PI / 4.0, Vector2.ONE)
				var s: float = e.r * opul * 1.3
				ci.draw_rect(Rect2(-s / 2.0, -s / 2.0, s, s), Color("#0a3320"))
				ci.draw_rect(Rect2(-s / 2.0, -s / 2.0, s, s), Color("#59ffb0"), false, 2.5)
				ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
