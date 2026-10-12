# NEON RUN — headless smoke test for the Godot port (analog of ../tools/smoke.js).
# Run: XDG_DATA_HOME=.godot-data godot --headless --path godot res://tests/smoke.tscn
# Exits 0 on all-pass, 1 on any failure.

extends Node

var fails := 0

func ok(cond: bool, msg: String) -> void:
	print(("PASS" if cond else "FAIL") + " - " + msg)
	if not cond:
		fails += 1


# Minimal fake UI so RunManager logic can be driven without a scene.
class FakeUI:
	var choice_count := 0
	var dead_calls := []
	var complete_calls := []
	var record_calls := []
	var last_choice := []
	func hide_screens() -> void: pass
	func hud_show(_b: bool) -> void: pass
	func banner(_t: String, _s: String = "") -> void: pass
	func tut(_t = null) -> void: pass
	func show_menu() -> void: pass
	func show_choice(list, cb) -> void:
		choice_count += 1
		last_choice = []
		last_choice.append(list)
		cb.call(list[0])
	func show_dead(d) -> void: dead_calls.append(d)
	func show_complete(d) -> void: complete_calls.append(d)
	func show_record(s, cb) -> void:
		record_calls.append(s)
		cb.call()
	func show_ad(_kind: String, _secs: int, cb) -> void: cb.call(true)


func _ready() -> void:
	Save.reset()
	Utils.seed(0xC0FFEE)
	var rm := RunManager.new()
	rm.ui = FakeUI.new()
	var fake = rm.ui

	# ---- Test 1: 60s run completes, endless unlocks ----
	rm.start_run("run60")
	ok(rm.state == "playing", "start_run -> playing")
	# keep the ship alive for the full run
	rm.player.inv = 1e9
	var energy_seen := false
	var steps := 0
	while rm.state == "playing" and steps < 4000:
		steps += 1
		rm.advance(0.033, 720, 1280)
		if rm.run.energy > 5.0:
			energy_seen = true
	ok(energy_seen, "energy accumulates during run")
	ok(fake.choice_count >= 1, "upgrade choice triggered (x%d)" % fake.choice_count)
	ok(rm.state == "complete", "60s run -> complete, state=%s" % rm.state)
	ok(Save.data.endless_unlocked == true, "endless unlocked after completion")
	print("  [dbg] record_calls=%s complete_calls=%s" % [fake.record_calls, fake.complete_calls])
	ok(fake.complete_calls.size() == 1 and fake.complete_calls[0].credits > 0, "complete w/ credits: %s" % [fake.complete_calls])
	if fake.complete_calls.size() == 1:
		ok(int(Save.data.best_score) == int(fake.complete_calls[0].score), "best_score saved")

	# ---- Test 2: death -> run over -> continue ----
	rm.start_run("endless")
	ok(rm.state == "playing", "endless run started")
	rm.player.inv = 0.0
	rm.player.shieldT = 0.0
	rm.player.shield = 0
	rm.player.hp = 1
	rm.on_hit("mine")
	ok(rm.state == "dead", "hp 0 -> dead")
	# advance deathWait to show the run-over screen
	rm.advance(1.0, 720, 1280)
	ok(fake.dead_calls.size() == 1, "RUN OVER shown: %s" % [fake.dead_calls])
	ok(fake.dead_calls[0].canContinue == true, "continue offered once")
	rm.continue_run()
	ok(rm.state == "playing", "continue (mock rewarded) -> playing")
	ok(rm.player.hp >= 1 and rm.player.inv > 0, "respawn has hp + grace invulnerability")
	ok(rm.run.continued == true, "continued flag set")

	# ---- Test 3: multiplier tiers + damage reset ----
	rm.start_run("run60")
	rm.run.crystals = 71
	rm.advance(0.016, 720, 1280)
	ok(rm.run.mult == 5.0 and rm.run.multIdx == 4, "multiplier reaches x5.0")
	rm.player.inv = 0.0
	rm.player.shieldT = 0.0
	rm.player.shield = 2
	rm.on_hit("wall")
	ok(rm.run.mult == 5.0, "shield block keeps multiplier")
	rm.player.shield = 0
	rm.player.inv = 0.0
	rm.player.shieldT = 0.0
	rm.player.hp = rm.player.maxHp
	rm.on_hit("wall")
	ok(rm.run.mult == 1.0 and rm.run.crystals == 0, "damage resets multiplier")

	# ---- Test 4: pattern integrity ----
	ok(Patterns.PATTERNS.size() >= 26, "has 26+ patterns: %d" % Patterns.PATTERNS.size())
	var rows_ok := true
	for p in Patterns.PATTERNS:
		for row in p.rows:
			if row.length() != 7:
				rows_ok = false
	ok(rows_ok, "all pattern rows are 7 columns wide")

	# ---- Test 5: new obstacle types spawn at VOID ----
	var e2 := Entities.new()
	var g2 := Generator.new(e2)
	g2.reset()
	var seen := {}
	var cfg5: Dictionary = Gamedata.LEVELS[4]
	for i in range(400):
		g2.update(0.033, 690.0, cfg5, 720.0, 1280.0)
		for e in e2.pool:
			if e.active:
				seen[e.type] = seen.get(e.type, 0) + 1
	ok(seen.get("seeker", 0) > 0, "VOID spawns seekers: %d" % seen.get("seeker", 0))
	ok(seen.get("vlaser", 0) > 0, "VOID spawns column lasers: %d" % seen.get("vlaser", 0))
	ok(seen.get("rift", 0) > 0, "VOID spawns rifts: %d" % seen.get("rift", 0))

	# ---- Test 6: orb & shield economy ----
	# (JS-терит maxed-апгрейды до этого, поэтому здесь уже уровень 5 → cap 6)
	Save.data.upgrade_hp = 5
	Save.data.upgrade_energy = 5
	Save.data.upgrade_shield = 5
	rm.start_run("run60")
	var P := rm.player
	ok(P.maxHp == 1 and P.shieldCap == 6, "HP fixed 1, SLOTS cap 6 (got %d/%d)" % [P.maxHp, P.shieldCap])
	P.shield = 0
	P.inv = 1e9
	var oe = rm.entities.spawn("orb", 3, P.y - Gamedata.CELLH / 2.0)
	oe.cx = P.x
	rm.advance(0.016, 720, 1280)
	ok(P.shield == 1, "orb charges a shield slot (got %d)" % P.shield)
	P.shield = P.shieldCap
	var s0: float = rm.run.score
	var oe3 = rm.entities.spawn("orb", 3, P.y - Gamedata.CELLH / 2.0)
	oe3.cx = P.x
	rm.advance(0.016, 720, 1280)
	ok(P.shield == P.shieldCap and rm.run.score > s0, "orb over capacity grants score")

	# ---- Test 7: maxed permanent upgrades must not break the player ----
	Save.data.upgrade_hp = 5
	Save.data.upgrade_energy = 5
	Save.data.upgrade_shield = 5
	rm.start_run("endless")
	ok(rm.player.maxHp == 1, "HP stays 1 with maxed SLOTS (got %d)" % rm.player.maxHp)
	ok(rm.player.shieldCap == 6, "maxed SLOTS -> shield capacity 6 (got %d)" % rm.player.shieldCap)
	ok(rm.player.energyMult > 1.0, "maxed ENERGY -> mult finite (got %.2f)" % rm.player.energyMult)

	# ---- Test 8: endless speed monotonic across L5->L1 wrap ----
	var prev := -1.0
	var dropped := false
	var t := 0.0
	while t <= 300.0:
		var idx: int = int(t / 18.0) % Gamedata.LEVELS.size()
		var cfg: Dictionary = Gamedata.LEVELS[idx]
		var cyc: int = int(t / 90.0)
		var sp: float = Gamedata.speed_at(cfg, t, cyc)
		if sp < prev:
			dropped = true
			break
		prev = sp
		t += 0.5
	ok(not dropped, "endless speed never drops over 300s")
	ok(prev > 420.0, "speed keeps climbing in long endless runs (t=300 -> %.0f)" % prev)

	print("")
	print(("ALL SMOKE TESTS PASSED" if fails == 0 else str(fails) + " FAILURES"))
	get_tree().quit(0 if fails == 0 else 1)
