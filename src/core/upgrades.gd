# NEON RUN — Run upgrades (ТЗ §7–8, 7 types; DASH+ removed) + Permanent (ТЗ §19–20).
# Port of js/upgrades.js. apply_run mutates the Player for this run.
class_name Upgrades

const RUN_UPGRADES := [
	{ "id": "magnet",    "name": "MAGNET",     "color": "#00eaff", "max": 3, "desc": "Energy magnet radius +50" },
	{ "id": "shield",    "name": "SHIELD",     "color": "#59ffb0", "max": 3, "desc": "+1 shield slot (charged) for this run" },
	{ "id": "overdrive", "name": "OVERDRIVE",  "color": "#ffb03d", "max": 3, "desc": "+20% score gain" },
	{ "id": "phase",     "name": "PHASE",      "color": "#c86bff", "max": 2, "desc": "Every 8s → 0.5s invulnerability" },
	{ "id": "energy",    "name": "ENERGY+",    "color": "#ffe14d", "max": 3, "desc": "+25% energy per crystal" },
	{ "id": "slow",      "name": "SLOW TIME",  "color": "#7fe9ff", "max": 2, "desc": "On hit: time slows 1.5s" },
	{ "id": "core",      "name": "DOUBLE CORE", "color": "#ff3d7f", "max": 2, "desc": "Crystal score x2" },
]


static func apply_run(player, id: String) -> void:
	match id:
		"magnet":
			player.magnet += 50
		"shield":
			player.shieldCap += 1
			player.shield = mini(player.shieldCap, player.shield + 1)
		"overdrive":
			player.scoreMult *= 1.2
		"phase":
			player.phaseEvery = player.phaseEvery if player.phaseEvery else 8
		"energy":
			player.energyMult *= 1.25
		"slow":
			player.slowDur += 1.5
		"core":
			player.crystalMult *= 2


static func roll_choices(applied: Dictionary) -> Array:
	var avail := []
	for u in RUN_UPGRADES:
		var n: int = applied.get(u.id, 0)
		if n < u.max:
			avail.append(u)
	return Utils.shuffle(avail).slice(0, 3)


const PERM_UPGRADES := [
	{ "key": "upgrade_hp",     "name": "SHIELD SLOTS", "costs": [400, 1100, 2300, 4000, 6500],
	  "vals": [1, 2, 3, 4, 5, 6],
	  "desc": "Shield slots (HP stays 1)" },
	{ "key": "upgrade_energy", "name": "ENERGY",       "costs": [320, 950, 2000, 3500, 5400],
	  "vals": [0, 5, 10, 15, 20, 25],
	  "desc": "+% energy" },
	{ "key": "upgrade_shield", "name": "START SHIELD", "costs": [480, 1200, 2500, 4600, 7000],
	  "vals": [0, 1, 2, 3, 4, 5],
	  "desc": "Start shield seconds" },
]


static func perm_upgrade(key: String) -> Dictionary:
	for u in PERM_UPGRADES:
		if u.key == key:
			return u
	return {}


# Level helper: clamp to 0..5 (guard against corrupt saves).
static func perm_level(key: String) -> int:
	var lvl: int = Save.data.get(key, 0)
	return clampi(lvl, 0, 5)
