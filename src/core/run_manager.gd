# NEON RUN — RunManager / run state / collisions / scoring / main loop logic.
# Port of js/game.js (update + collision + score). Rendering lives in Main.
class_name RunManager

signal run_state_changed(state: String)

var state: String = "menu"
var mode: String = "run60"

var player: Player = Player.new()
var entities: Entities = Entities.new()
var gen: Generator = Generator.new(entities)
var particles: Particles = Particles.new()

var run: Dictionary = {}
var floats: Array = []

var shake: float = 0.0
var deathWait: float = 0.0
var glitchT: float = 0.0
var bgY: float = 0.0
var pal: Dictionary = {}
var par_far: Array = []
var par_near: Array = []
var stars: Array = []
var freezeT: float = 0.0
var tapHold: bool = false
var tut = null

var ui = null   # injected UI controller; may be null (headless tests)


func _init() -> void:
	pal = Gamedata.LEVELS[0].pal.duplicate(true)
	_init_fx()


func _init_fx() -> void:
	# stars / parallax layers (ТЗ §25)
	stars.clear()
	for i in range(70):
		stars.append({ "x": Utils.frand(0, Gamedata.W), "y": Utils.frand(0, 1280.0), "z": Utils.frand(0.25, 0.9) })
	par_far.clear()
	for i in range(9):
		par_far.append({ "x": Utils.frand(0, Gamedata.W), "w": Utils.frand(26, 90), "h": Utils.frand(120, 420), "off": Utils.frand(0, 2000), "z": Utils.frand(0.12, 0.22) })
	par_near.clear()
	for i in range(14):
		par_near.append({ "x": Utils.frand(0, Gamedata.W), "len": Utils.frand(60, 160), "off": Utils.frand(0, 2000), "z": Utils.frand(1.5, 1.9) })


func circle_rect(cx: float, cy: float, r: float, x: float, y: float, w: float, h: float) -> bool:
	var nx: float = Utils.clampf(cx, x, x + w)
	var ny: float = Utils.clampf(cy, y, y + h)
	var dx: float = cx - nx
	var dy: float = cy - ny
	return dx * dx + dy * dy < r * r


func float_text(x: float, y: float, txt: String, color: Color) -> void:
	floats.append({ "x": x, "y": y, "txt": txt, "color": color, "t": 0.0 })


func level_cfg() -> Dictionary:
	if run.mode == "run60":
		return Gamedata.LEVELS[mini(4, int(run.t / 12.0))]
	return Gamedata.LEVELS[int(run.t / 18.0) % Gamedata.LEVELS.size()]


func start_run(m: String) -> void:
	Audio.sfx("start")
	Audio.set_level(0)
	Audio.music_start()
	mode = m
	state = "playing"
	shake = 0.0
	deathWait = 0.0
	bgY = 0.0
	floats.clear()
	freezeT = 0.0
	tapHold = false
	glitchT = 0.0
	run = {
		"mode": m, "t": 0.0, "score": 0.0, "distPx": 0.0,
		"mult": 1.0, "multIdx": 0, "crystals": 0,
		"energy": 0.0, "energyNeed": 16.0, "upgCount": 0, "applied": {}, "maxedNotified": false,
		"continued": false, "lastHit": "wall",
		"endlessCycle": 0, "levelIdx": -1, "slowT": 0.0,
		"newRecord": false, "credits": 0, "deadInfo": null,
	}
	player.reset()
	gen.reset()
	entities.reset()
	particles.clear()
	pal = Gamedata.LEVELS[0].pal.duplicate(true)
	if ui:
		ui.hide_screens()
		ui.hud_show(true)
	run.levelIdx = 0
	if ui:
		ui.banner(Gamedata.LEVELS[0].name, Gamedata.LEVELS[0].lore)
	# onboarding
	tut = null if Save.data.tutorial_done else { "step": 0, "t": 0.0 }
	if tut != null and ui:
		ui.tut("MOVE — hold and drag")
	run_state_changed.emit(state)


func to_menu() -> void:
	state = "menu"
	Audio.set_level(0)
	if ui:
		ui.hud_show(false)
		ui.tut(null)
		ui.show_menu()
	run_state_changed.emit(state)


func open_choice() -> void:
	var list := Upgrades.roll_choices(run.applied)
	if list.is_empty():
		return
	state = "choice"
	if ui:
		ui.show_choice(list, func(u):
			Upgrades.apply_run(player, u.id)
			run.applied[u.id] = (run.applied.get(u.id, 0) as int) + 1
			run.upgCount += 1
			run.energy = 0.0
			run.energyNeed += 5.0
			state = "playing"
			freezeT = 2.0
			tapHold = false
			run_state_changed.emit(state)
		)
	run_state_changed.emit(state)


func on_hit(source: String) -> void:
	var res := player.take_hit()
	if res == "blocked":
		if Save.data.fx_enabled:
			shake = maxf(shake, 0.25)
		float_text(player.x, player.y - 52, "SHIELD — x%.1f KEPT" % run.mult, Color("#59ffb0"))
		Audio.sfx("gate")
		return
	run.lastHit = source
	if run.mult > 1.0:
		float_text(player.x, player.y - 52, "x%.1f LOST" % run.mult, Color("#ff3d7f"))
	run.crystals = 0
	run.multIdx = 0
	run.mult = 1.0
	if player.slowDur > 0.0:
		run.slowT = player.slowDur
	if Save.data.fx_enabled:
		shake = maxf(shake, 0.6)
	Audio.sfx("hit")
	if player.hp <= 0:
		die()


func die() -> void:
	state = "dead"
	deathWait = 0.9
	if Save.data.fx_enabled:
		shake = 1.0
	Audio.sfx("death")
	particles.burst(player.x, player.y, Color("#00eaff"), 40, 420)
	particles.burst(player.x, player.y, Color("#ff3d7f"), 30, 300)
	var S := Save.data
	run.credits = int(run.score / 40.0) + (0 if run.mode == "run60" else 10)
	S.credits = int(S.credits) + run.credits
	var dist: int = int(run.distPx / 22.0)
	run.newRecord = run.score > float(S.best_score)
	if run.newRecord:
		S.best_score = int(run.score)
	if dist > int(S.best_distance):
		S.best_distance = dist
	S.runs_completed = int(S.runs_completed)
	Save.save()
	run.deadInfo = {
		"score": int(run.score), "dist": dist, "best": int(S.best_score),
		"credits": run.credits, "canContinue": not run.continued,
	}
	run_state_changed.emit(state)


func after_death_screen() -> void:
	if run.newRecord and ui:
		ui.show_record(run.deadInfo.score, func(): ui.show_dead(run.deadInfo))
	elif ui:
		ui.show_dead(run.deadInfo)


func continue_run() -> void:
	if ui:
		ui.show_ad("rewarded", 5, func(rewarded):
			if rewarded == false:
				ui.show_dead(run.deadInfo)
				return
			player.respawn()
			run.continued = true
			run.multIdx = 0
			run.mult = 1.0
			ui.hide_screens()
			state = "playing"
			ui.banner("RESPAWN")
			run_state_changed.emit(state)
		)


func finish_run() -> void:
	var S := Save.data
	state = "complete"
	Audio.sfx("complete")
	run.credits = int(run.score / 40.0) + 60
	S.credits = int(S.credits) + run.credits
	S.runs_completed = int(S.runs_completed) + 1
	S.since_ad = int(S.since_ad) + 1
	var dist: int = int(run.distPx / 22.0)
	var rec: bool = run.score > float(S.best_score)
	if rec:
		S.best_score = int(run.score)
	if dist > int(S.best_distance):
		S.best_distance = dist
	var unlocked: bool = false
	if not S.endless_unlocked:
		S.endless_unlocked = true
		unlocked = true
	Save.save()
	if ui:
		ui.hud_show(false)
		ui.tut(null)
	var info := { "score": int(run.score), "best": int(S.best_score), "credits": run.credits, "unlocked": unlocked }
	var show := func():
		if rec and ui:
			ui.show_record(info.score, func(): ui.show_complete(info))
		elif ui:
			ui.show_complete(info)
	if int(S.since_ad) >= 3:
		S.since_ad = 0
		Save.save()
		if ui:
			ui.show_ad("interstitial", 3, show)
	else:
		show.call()
	run_state_changed.emit(state)


func tap_to_resume() -> void:
	if tapHold:
		tapHold = false
		freezeT = 2.0


func set_player_target(x: float) -> void:
	player.tx = x


func advance(dt: float, W: float, H: float) -> void:
	player.W = W
	player.H = H
	if state == "playing":
		update_playing(dt, W, H)
	elif state == "dead" and deathWait > 0.0:
		deathWait -= dt
		particles.update(dt)
		if deathWait <= 0.0:
			after_death_screen()
	# floats live across states
	for i in range(floats.size() - 1, -1, -1):
		var f = floats[i]
		f.t += dt
		if f.t > 0.9:
			floats.remove_at(i)


func update_playing(dt: float, W: float, H: float) -> void:
	player.W = W
	player.H = H
	if tapHold or freezeT > 0.0:
		if freezeT > 0.0:
			freezeT -= dt
			if freezeT <= 0.0:
				tapHold = false
		particles.update(dt)
		return
	var r := run
	var ts: float = 1.0
	if r.slowT > 0.0:
		r.slowT -= dt
		ts = 0.35
	var dtw: float = dt * ts

	r.t += dtw
	if r.mode == "endless":
		r.endlessCycle = int(r.t / 90.0)
	var cfg := level_cfg()
	var idx: int = Gamedata.LEVELS.find(cfg)
	if idx != r.levelIdx:
		r.levelIdx = idx
		pal = cfg.pal.duplicate(true)
		if ui:
			ui.banner(cfg.name, cfg.lore)
		Audio.set_level(idx)
		if Save.data.fx_enabled:
			glitchT = 0.6
			shake = maxf(shake, 0.3)

	var scroll: float = Gamedata.speed_at(cfg, r.t, r.endlessCycle)

	if Input.is_action_pressed("move_left"):
		player.tx -= 640.0 * dt
	if Input.is_action_pressed("move_right"):
		player.tx += 640.0 * dt

	player.update(dtw)
	gen.update(dtw, scroll, cfg, W, H)
	entities.update(dtw, scroll, player, player.magnet, W, H)
	particles.update(dtw)
	bgY += scroll * dtw

	var P := player
	var E := entities
	var CH: float = Gamedata.CELLH
	var cw: float = W / float(Gamedata.COLS)
	for e in E.pool:
		if not e.active:
			continue
		match e.type:
			"crystal":
				var cy: float = e.y + CH / 2.0
				var dx: float = P.x - e.cx
				var dy: float = P.y - cy
				if dx * dx + dy * dy < 34.0 * 34.0:
					e.active = false
					r.crystals += 1
					r.energy += 2.0 * P.energyMult
					r.score += 25.0 * r.mult * P.crystalMult * P.scoreMult
					Audio.sfx("pickup")
					particles.burst(e.cx, cy, Color("#00eaff"), 6, 140)
			"gate":
				if not e.taken and absf(P.y - e.y) < 24.0 and absf(P.x - e.cx) < e.w / 2.0:
					e.taken = true
					r.energy += 10.0 * P.energyMult
					r.score += 150.0 * r.mult * P.scoreMult
					Audio.sfx("gate")
					particles.burst(e.cx, e.y, Color(pal.accent), 14, 220)
			"laser":
				if e.phase != "fire":
					continue
				var x0: float = e.cols[0] * cw
				var x1: float = (e.cols[1] + 1) * cw
				if not P.protected() and circle_rect(P.x, P.y, P.r, x0, e.y - 7.0, x1 - x0, 14.0):
					on_hit("laser")
			"wall", "walker":
				var yy: float = e.y if e.type == "wall" else e.y + CH * 0.25
				if circle_rect(P.x, P.y, P.r, e.x, yy, e.w, e.h):
					if not P.protected():
						on_hit(e.type)
			"mine":
				var my: float = e.y + CH / 2.0
				var mdx: float = P.x - e.cx
				var mdy: float = P.y - my
				var mrr: float = P.r + e.r
				if mdx * mdx + mdy * mdy < mrr * mrr:
					if not P.protected():
						e.active = false
						on_hit("mine")
			"seeker":
				var sy: float = e.y + CH / 2.0
				var sdx: float = P.x - e.cx
				var sdy: float = P.y - sy
				var srr: float = P.r + e.r
				if sdx * sdx + sdy * sdy < srr * srr:
					if not P.protected():
						e.active = false
						on_hit("seeker")
			"vlaser":
				if e.phase == "fire" and not P.protected() and circle_rect(P.x, P.y, P.r, e.cx - 26.0, 0.0, 52.0, H):
					on_hit("vlaser")
			"orb":
				var ocy: float = e.y + CH / 2.0
				var odx: float = P.x - e.cx
				var ody: float = P.y - ocy
				if odx * odx + ody * ody < 34.0 * 34.0:
					e.active = false
					if P.shield < P.shieldCap:
						P.shield += 1
						Audio.sfx("heal")
						float_text(P.x, P.y - 52, "+SHIELD", Color("#59ffb0"))
					else:
						r.score += 100.0 * r.mult
						Audio.sfx("pickup")
						float_text(P.x, P.y - 52, "+%d" % int(100.0 * r.mult), Color("#ffe14d"))
					particles.burst(e.cx, ocy, Color("#59ffb0"), 16, 240)
			"rift":
				var rcy: float = e.y + CH / 2.0
				var rdx: float = e.cx - P.x
				var rdy: float = rcy - P.y
				var rd2: float = rdx * rdx + rdy * rdy
				if rd2 < e.r * e.r and rd2 > 100.0:
					var rd: float = sqrt(rd2)
					P.tx += (rdx / rd) * 150.0 * dtw
		# close call (risk bonus)
		if not e.cc and e.active and not P.protected() and (e.type in ["wall", "walker", "mine", "seeker"]):
			var rc: float = (e.y + e.h / 2.0) if e.type == "wall" else (e.y + CH * 0.25 + e.h / 2.0) if e.type == "walker" else e.y + CH / 2.0
			var rp: float = rc - scroll * dtw
			if rp < P.y and rc >= P.y:
				var ddx: float = absf(e.cx - P.x)
				if ddx > 34.0 and ddx < 82.0:
					e.cc = 1
					r.energy += 1.0 * P.energyMult
					r.score += 15.0 * r.mult
					particles.emit(P.x, P.y - 26, Color("#ffe14d"), { "n": 4, "spMin": 40, "spMax": 130, "life": 0.3, "size": 2 })

	if state != "playing":
		return
	r.score += scroll * dtw * 0.12 * r.mult * P.scoreMult
	r.distPx += scroll * dtw
	var ti: int = 0
	for k in range(Gamedata.MULT_TIERS.size()):
		if r.crystals >= int(Gamedata.MULT_TIERS[k].need):
			ti = k
	if ti != r.multIdx:
		r.multIdx = ti
		r.mult = Gamedata.MULT_TIERS[ti].v
		if ti > 0:
			particles.burst(P.x, P.y - 30, Color("#ffe14d"), 10, 200)

	if r.energy >= r.energyNeed:
		if not Upgrades.roll_choices(run.applied).is_empty():
			open_choice()
		elif not r.maxedNotified:
			r.maxedNotified = true
			float_text(P.x, P.y - 60, "ALL UPGRADES MAXED", Color("#ffe14d"))
			r.energy = r.energyNeed
		return

	if r.mode == "run60" and r.t >= 60.0:
		finish_run()
		return

	if tut != null:
		tut.t += dt
		if tut.step == 0 and absf(P.tx - W / 2.0) > 130.0:
			tut.step = 1
			if ui:
				ui.tut("AVOID — obstacles are coming. Survive.")
		if tut.step == 1 and gen.patternsSpawned >= 2:
			tut.step = 2
			Save.data.tutorial_done = true
			Save.save()
			if ui:
				ui.tut(null)
		if tut.t > 30.0 and tut.step < 2:
			tut.step = 2
			Save.data.tutorial_done = true
			Save.save()
			if ui:
				ui.tut(null)
