# NEON RUN — level & difficulty configs (ТЗ §12). Port of js/gamedata.js.
class_name Gamedata

const W := 720
const SHIP_Y := 0.75
const COLS := 7
const CELLH := 120

const LEVELS := [
	{ "name": "LEVEL 1 — CITY", "music": "drive", "dur": 12, "speed": 420, "gapMin": 170, "maxD": 1,
	  "lore": "Sector 01 — the towers still hum with dead light.",
	  "types": { "wall": 1, "crystal": 1, "gate": 1, "walker": 0, "mine": 0, "laser": 0, "seeker": 0, "vlaser": 0, "rift": 0 },
	  "pal": { "bg0": "#04060f", "bg1": "#0b1030", "line": "#1b2a6b", "accent": "#00eaff", "accent2": "#ff2fd0" } },
	{ "name": "LEVEL 2 — GRID", "music": "pulse", "dur": 12, "speed": 480, "gapMin": 160, "maxD": 2,
	  "lore": "Sector 02 — the grid hunts anything that moves.",
	  "types": { "wall": 1, "crystal": 1, "gate": 1, "walker": 1, "mine": 1, "laser": 0, "seeker": 0, "vlaser": 0, "rift": 0 },
	  "pal": { "bg0": "#050a06", "bg1": "#0a2416", "line": "#1e5a3a", "accent": "#59ffb0", "accent2": "#ff2fd0" } },
	{ "name": "LEVEL 3 — REACTOR", "music": "ember", "dur": 12, "speed": 545, "gapMin": 150, "maxD": 3,
	  "lore": "Sector 03 — the old reactor still bleeds fire.",
	  "types": { "wall": 1, "crystal": 1, "gate": 1, "walker": 1, "mine": 1, "laser": 1, "seeker": 0, "vlaser": 0, "rift": 0 },
	  "pal": { "bg0": "#0f0602", "bg1": "#2e1305", "line": "#7a3a12", "accent": "#ffb03d", "accent2": "#ff2fd0" } },
	{ "name": "LEVEL 4 — CORE", "music": "echo", "dur": 12, "speed": 615, "gapMin": 140, "maxD": 4,
	  "lore": "Sector 04 — the Core answers your pulse.",
	  "types": { "wall": 1, "crystal": 1, "gate": 1, "walker": 1, "mine": 1, "laser": 1, "seeker": 1, "vlaser": 1, "rift": 1 },
	  "pal": { "bg0": "#0c0316", "bg1": "#280a44", "line": "#5a1e8a", "accent": "#c86bff", "accent2": "#ffe14d" } },
	{ "name": "LEVEL 5 — VOID", "music": "abyss", "dur": 12, "speed": 690, "gapMin": 132, "maxD": 5,
	  "lore": "Sector 05 — beyond the map. Deliver the last signal.",
	  "types": { "wall": 1, "crystal": 1, "gate": 1, "walker": 1, "mine": 1, "laser": 1, "seeker": 1, "vlaser": 1, "rift": 1 },
	  "pal": { "bg0": "#02030a", "bg1": "#12031f", "line": "#46186b", "accent": "#ff3d7f", "accent2": "#00eaff" } },
]

const MULT_TIERS := [
	{ "need": 0,  "v": 1.0 }, { "need": 8, "v": 1.5 }, { "need": 20, "v": 2.0 },
	{ "need": 40, "v": 3.0 }, { "need": 70, "v": 5.0 },
]


static func speed_at(level_cfg: Dictionary, t: float, cycle: int) -> float:
	var spread: float = float(LEVELS[LEVELS.size() - 1].speed) - float(LEVELS[0].speed)   # 270
	return float(level_cfg.speed) + cycle * spread + minf(t, 120) * 1.4
