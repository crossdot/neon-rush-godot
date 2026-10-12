# NEON RUN — pooled particle system (ТЗ §39). Port of js/particles.js.
class_name Particles

const MAX := 420

var pool: Array = []


func _init() -> void:
	for i in range(MAX):
		pool.append({ "active": false })


func _grab() -> Variant:
	for p in pool:
		if not p.active:
			return p
	return null


func emit(x: float, y: float, color: Color, opts: Dictionary = {}) -> void:
	var n: int = opts.get("n", 8)
	var dir: float = opts.get("dir", -1.0)
	var sp_min: float = opts.get("spMin", 60.0)
	var sp_max: float = opts.get("spMax", 260.0)
	var life: float = opts.get("life", 0.6)
	var size: float = opts.get("size", 4.0)
	for i in range(n):
		var p = _grab()
		if p == null:
			return
		var a: float
		if opts.has("dir") and dir >= 0.0:
			a = dir + Utils.frand(-0.6, 0.6)
		else:
			a = Utils.frand(0.0, PI * 2.0)
		var sp: float = Utils.frand(sp_min, sp_max)
		p.active = true
		p.x = x
		p.y = y
		p.vx = cos(a) * sp
		p.vy = sin(a) * sp
		p.max = Utils.frand(0.25, life)
		p.life = p.max
		p.size = Utils.frand(1.5, size)
		p.color = color


func burst(x: float, y: float, color: Color, n: int, sp: float) -> void:
	emit(x, y, color, { "n": n, "spMin": (sp if sp > 0 else 200) * 0.3, "spMax": sp if sp > 0 else 200 })


func update(dt: float) -> void:
	for p in pool:
		if not p.active:
			continue
		p.life -= dt
		if p.life <= 0.0:
			p.active = false
			continue
		p.x += p.vx * dt
		p.y += p.vy * dt
		p.vx *= 0.98
		p.vy *= 0.98


func draw(ci: CanvasItem) -> void:
	for p in pool:
		if not p.active:
			continue
		var k: float = p.life / p.max
		ci.draw_rect(Rect2(p.x - p.size / 2.0, p.y - p.size / 2.0, p.size, p.size), Color(p.color.r, p.color.g, p.color.b, k))


func clear() -> void:
	for p in pool:
		p.active = false
