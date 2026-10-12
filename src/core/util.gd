# NEON RUN — utils / RNG / formatting. Port of js/utils.js.
class_name Utils

# Deterministic RNG for the whole game. Seed once (Utils.seed(x)); in tests,
# re-seed to make runs reproducible. Godot's global randi()/randf() draw from a
# shared, time-seeded stream, so we keep an explicit generator.
static var rng: RandomNumberGenerator = RandomNumberGenerator.new()


static func _static_init() -> void:
	rng.seed = 0xC0FFEE


static func seed(s: int) -> void:
	rng.seed = s


static func clampf(v: float, a: float, b: float) -> float:
	return v if v > a else (a if v < a else b)


static func lerpf(a: float, b: float, t: float) -> float:
	return a + (b - a) * t


static func frand(a: float, b: float) -> float:
	return rng.randf_range(a, b)


static func irand(n: int) -> int:
	return rng.randi_range(0, n - 1)


static func choice(arr: Array):
	return arr[rng.randi_range(0, arr.size() - 1)]


static func shuffle(arr: Array) -> Array:
	var a := arr.duplicate()
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t
	return a


static func fmt(n: int) -> String:
	return str(n)


static func hex_a(hex: String, a: float) -> Color:
	var r := ("0x" + hex.substr(1, 2)).hex_to_int()
	var g := ("0x" + hex.substr(3, 2)).hex_to_int()
	var b := ("0x" + hex.substr(5, 2)).hex_to_int()
	return Color(r / 255.0, g / 255.0, b / 255.0, a)


# Fake radial glow (no shadow blur). Concentric translucent circles; additive-ish.
static func draw_glow(ci: CanvasItem, color: Color, x: float, y: float, r: float) -> void:
	var steps := 4
	for i in range(steps, 0, -1):
		var rad: float = r * i / steps
		var a: float = 0.16 * (1.0 - (i - 1) / float(steps)) * 2.0
		ci.draw_circle(Vector2(x, y), rad, Color(color.r, color.g, color.b, a))
