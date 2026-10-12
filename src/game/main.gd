# NEON RUN — main scene: drives the RunManager and renders the world (ТЗ §25, §36, §44).
# Port of js/game.js (render loop + input) into a Node2D.
extends Node2D

const GameUI := preload("res://src/ui/ui.gd")

var rm: RunManager
var ui
var ui_layer: CanvasLayer


func _ready() -> void:
	rm = RunManager.new()
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)
	ui = GameUI.new()
	ui.rm = rm
	ui_layer.add_child(ui)
	rm.ui = ui
	rm.to_menu()


func _process(delta: float) -> void:
	var vs: Vector2 = get_viewport().get_visible_rect().size
	var W: float = 720.0 if vs.x <= 0.0 else vs.x
	var H: float = 1280.0 if vs.y <= 0.0 else vs.y
	rm.advance(delta, W, H)
	if rm.state == "playing":
		ui.sync_hud(rm)
	queue_redraw()


func _input(event: InputEvent) -> void:
	if rm.state != "playing":
		return
	var p := event as InputEventMouseMotion
	if p:
		rm.set_player_target(p.position.x)
		return
	var sd := event as InputEventScreenDrag
	if sd:
		rm.set_player_target(sd.position.x)
		return
	var st := event as InputEventScreenTouch
	if st:
		if st.pressed:
			rm.set_player_target(st.position.x)
			rm.tap_to_resume()


func _draw() -> void:
	var vs: Vector2 = get_viewport().get_visible_rect().size
	var W: float = 720.0 if vs.x <= 0.0 else vs.x
	var H: float = 1280.0 if vs.y <= 0.0 else vs.y
	var fx: bool = Save.data.fx_enabled
	var p: Dictionary = rm.pal
	var shake: float = rm.shake if fx else 0.0
	if rm.shake > 0.0:
		rm.shake = maxf(0.0, rm.shake - 0.035)
	if rm.glitchT > 0.0:
		rm.glitchT = maxf(0.0, rm.glitchT - 0.016)
	if fx and shake > 0.0:
		var a: float = shake * shake * 18.0
		draw_set_transform(Vector2(Utils.frand(-a, a), Utils.frand(-a, a)), 0.0, Vector2.ONE)

	# background gradient
	var c0 := Color(p.bg0)
	var c1 := Color(p.bg1)
	var strips: int = 64
	for i in range(strips):
		var t: float = float(i) / float(strips - 1)
		var col := c1.lerp(c0, t)
		var y0: float = H * float(i) / float(strips)
		draw_rect(Rect2(-30, y0, W + 60, H / float(strips) + 2), col)

	if fx:
		_draw_parallax(W, H)
	_draw_stars(W, H)
	_draw_tunnel(W, H, Color(p.line), Color(p.accent))
	rm.entities.draw(self, p, W, H)
	if rm.state == "playing" or rm.state == "choice" or (rm.state == "dead" and rm.deathWait > 0.0 and rm.player.hp > 0):
		rm.player.draw(self)
	rm.particles.draw(self)
	_draw_floats()
	if rm.glitchT > 0.0 and fx:
		_draw_glitch(W, H, rm.glitchT)
	if rm.state == "playing" and (rm.tapHold or rm.freezeT > 0.0):
		_draw_pause(W, H)


func _draw_parallax(W: float, H: float) -> void:
	# §25: far silhouettes + speed streaks
	for t in rm.par_far:
		var y: float = fmod(t.off + rm.bgY * t.z, H + t.h) - t.h
		draw_rect(Rect2(t.x, y, t.w, t.h), Color(0, 0, 0, 0.55))
		draw_rect(Rect2(t.x, y, t.w, 2), Color(rm.pal.accent))
	for s in rm.par_near:
		var y2: float = fmod(s.off + rm.bgY * s.z, H + s.len) - s.len
		draw_rect(Rect2(s.x, y2, 2, s.len), Color(0.75, 0.91, 1.0, 0.08))


func _draw_stars(W: float, H: float) -> void:
	for s in rm.stars:
		var y: float = fmod(s.y + rm.bgY * s.z, H)
		var a: float = 0.25 + s.z * 0.5
		draw_rect(Rect2(s.x, y, 2, 2 + s.z * 2), Color(0.62, 0.85, 1.0, a))


func _draw_tunnel(W: float, H: float, linec: Color, accent: Color) -> void:
	var off: float = fmod(rm.bgY, 140.0)
	for y in range(int(off) - 140, int(H) + 140, 140):
		draw_line(Vector2(0, y), Vector2(W, y), Color(linec.r, linec.g, linec.b, 0.5), 1.0)
	for c in range(1, Gamedata.COLS):
		var x: float = c * W / float(Gamedata.COLS)
		draw_line(Vector2(x, 0), Vector2(x, H), Color(linec.r, linec.g, linec.b, 0.18), 1.0)
	draw_line(Vector2(2, 0), Vector2(2, H), Color(accent.r, accent.g, accent.b, 0.6), 3.0)
	draw_line(Vector2(W - 2, 0), Vector2(W - 2, H), Color(accent.r, accent.g, accent.b, 0.6), 3.0)


func _draw_floats() -> void:
	for f in rm.floats:
		var k: float = f.t / 0.9
		var fy: float = f.y - k * 76.0
		draw_string(ThemeDB.fallback_font, Vector2(f.x - 60, fy), f.txt,
			HORIZONTAL_ALIGNMENT_LEFT, 120, 30, Color(f.color.r, f.color.g, f.color.b, 1.0 - k * k))


func _draw_glitch(W: float, H: float, k: float) -> void:
	for i in range(6):
		if Utils.frand(0.0, 1.0) > 0.5:
			continue
		var a: float = 0.10 + Utils.frand(0.0, 0.2) * k
		var col: Color = Color("#ff2fd0") if Utils.frand(0.0, 1.0) < 0.5 else Color("#00eaff")
		col.a = a
		draw_rect(Rect2(Utils.frand(0, W * 0.3), Utils.frand(0, H), W * (0.5 + Utils.frand(0, 0.5)), 2 + Utils.frand(0, 9)), col)


func _draw_pause(W: float, H: float) -> void:
	draw_rect(Rect2(0, H * 0.28, W, H * 0.24), Color(0.008, 0.012, 0.04, 0.5))
	draw_string(ThemeDB.fallback_font, Vector2(W / 2, H * 0.44), "TAP TO CONTINUE",
		HORIZONTAL_ALIGNMENT_CENTER, 0, 52, Color("#eafcff"))
	if rm.freezeT > 0.0:
		var n: int = ceili(rm.freezeT)
		draw_string(ThemeDB.fallback_font, Vector2(W / 2, H * 0.50), str(n),
			HORIZONTAL_ALIGNMENT_CENTER, 0, 120, Color("#eafcff"))
