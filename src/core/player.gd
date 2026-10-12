# NEON RUN — player controller: movement, HP, shields, phase (ТЗ §4, §24).
# Port of js/player.js.
class_name Player

var x: float = 360.0
var tx: float = 360.0
var y: float = 1020.0
var r: float = 17.0

var hp: int = 1
var maxHp: int = 1
var shield: int = 0
var shieldCap: int = 1
var shieldT: float = 0.0
var inv: float = 0.0

var magnet: float = 0.0
var energyMult: float = 1.0
var crystalMult: float = 1.0
var scoreMult: float = 1.0
var phaseEvery: float = 0.0
var phaseT: float = 0.0
var slowDur: float = 0.0

var W: float = Gamedata.W
var H: float = 1280.0


func reset() -> void:
	maxHp = 1  # HP не прокачивается: одно чистое попадание = смерть, запас = щиты
	hp = maxHp
	shieldCap = Upgrades.PERM_UPGRADES[0].vals[Upgrades.perm_level("upgrade_hp")]
	energyMult = 1.0 + float(Upgrades.PERM_UPGRADES[1].vals[Upgrades.perm_level("upgrade_energy")]) / 100.0
	shieldT = float(Upgrades.PERM_UPGRADES[2].vals[Upgrades.perm_level("upgrade_shield")])
	tx = W / 2.0
	x = tx
	y = roundf(H * Gamedata.SHIP_Y)
	shield = 0
	inv = maxf(1.0, shieldT)
	magnet = 0.0
	crystalMult = 1.0
	scoreMult = 1.0
	phaseEvery = 0.0
	phaseT = 0.0
	slowDur = 0.0


func protected() -> bool:
	return inv > 0.0 or shieldT > 0.0


# Returns "blocked" | "hit". Visuals/audio handled by the RunManager.
func take_hit() -> String:
	if shield > 0:
		shield -= 1
		inv = maxf(inv, 0.9)
		return "blocked"
	if shieldT > 0.0:
		return "blocked"
	hp -= 1
	inv = 1.3
	return "hit"


func respawn() -> void:
	hp = maxHp
	shieldT = 3.0
	inv = 3.0
	tx = W / 2.0
	x = tx
	y = roundf(H * Gamedata.SHIP_Y)


func update(dt: float) -> void:
	var k: float = minf(1.0, dt * 15.0)
	x = Utils.lerpf(x, tx, k)
	x = Utils.clampf(x, 24.0, W - 24.0)
	if inv > 0.0:
		inv -= dt
	if shieldT > 0.0:
		shieldT -= dt
	if phaseEvery > 0.0:
		phaseT += dt
		if phaseT >= phaseEvery:
			phaseT = 0.0
			inv = maxf(inv, 0.5)


func draw(ci: CanvasItem) -> void:
	var col := Color("#00eaff")
	Utils.draw_glow(ci, col, x, y, 46.0)
	# engine flame pulses
	ci.draw_circle(Vector2(x, y + 18), absf(sin(Time.get_ticks_msec() / 80.0)) * 5.0 + 2.0, Color(1.0, 0.88, 0.3, 0.5))
	ci.draw_colored_polygon(PackedVector2Array([
		Vector2(x, y - 22), Vector2(x + 15, y + 16), Vector2(x, y + 8), Vector2(x - 15, y + 16)
	]), Color("#eafcff"))
	ci.draw_polyline(PackedVector2Array([
		Vector2(x, y - 22), Vector2(x + 15, y + 16), Vector2(x, y + 8), Vector2(x - 15, y + 16), Vector2(x, y - 22)
	]), col, 2.0)
	ci.draw_rect(Rect2(x - 3, y - 8, 6, 10), col)
	if shieldT > 0.0 or shield > 0:
		var a: float = 0.5 + sin(Time.get_ticks_msec() / 90.0) * 0.25 if shieldT > 0.0 else 0.35
		ci.draw_arc(Vector2(x, y), 30.0, 0.0, TAU, 40, Color(0.35, 1.0, 0.69, a), 2.0)
