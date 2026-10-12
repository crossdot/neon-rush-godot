# NEON RUN — obstacle patterns (ТЗ §21–22). Port of js/patterns.js.
# Grid: 7 columns, each row CELLH px tall.
# Legend: # wall, M mine, S seeker (homing), E energy crystal, G energy gate,
# > walker (moving), L laser beam, V column laser (periodic), R rift (side current),
# H shield orb.
class_name Patterns

const COLS := 7

const PATTERNS := [
	{ "id": 1,  "d": 1, "rows": [".......", "#.....#", "...E...", "#.....#"] },
	{ "id": 2,  "d": 1, "rows": ["...#...", "..E#E..", "......."] },
	{ "id": 3,  "d": 1, "rows": ["#E....#", ".#...#.", "..E.E..", "......."] },
	{ "id": 4,  "d": 2, "rows": ["MM..MM.", "...E...", "..E.E.."] },
	{ "id": 5,  "d": 2, "rows": ["LL.LLL.", ".......", "...M..."] },
	{ "id": 6,  "d": 2, "rows": [">.....<", "...E..."] },
	{ "id": 7,  "d": 2, "rows": ["#M...M#", "..E.E.."] },
	{ "id": 8,  "d": 3, "rows": [".L.LLL.", ".......", "M..E..M"] },
	{ "id": 9,  "d": 3, "rows": ["##...##", "##.E.##", "...#..."] },
	{ "id": 10, "d": 3, "rows": ["G.....G", "M..#..M"] },
	{ "id": 11, "d": 4, "rows": ["MM...MM", ".L...L.", "..E.E..", "##.#.##"] },
	{ "id": 12, "d": 4, "rows": ["LL...LL", ".......", "LL...LL"] },
	{ "id": 13, "d": 4, "rows": [">.E.E.<", "##...##", "M..E..M"] },
	{ "id": 14, "d": 5, "rows": ["#L.L.L#", ".M...M.", "##.#.##", "..E.E.."] },
	{ "id": 15, "d": 5, "rows": ["MM.M.MM", "L.....L", ".M#.#M.", "...G..."] },
	{ "id": 16, "d": 4, "rows": ["V..E..V", ".......", "..###.."] },
	{ "id": 17, "d": 4, "rows": ["S.....S", "...E...", "##...##"] },
	{ "id": 18, "d": 4, "rows": ["R..#..R", ".......", "R..E..R"] },
	{ "id": 19, "d": 5, "rows": ["V.M.M.V", "...E...", "S..#..S"] },
	{ "id": 20, "d": 5, "rows": ["V##.##V", "..S.S..", "...E...", "R.....R"] },
	{ "id": 21, "d": 3, "rows": ["...E...", ".S.....", "..H...."] },
	{ "id": 22, "d": 3, "rows": ["R..E..R", "##...##"] },
	{ "id": 23, "d": 4, "rows": ["#.V.V.#", "...E...", "M..#..M"] },
	{ "id": 24, "d": 4, "rows": ["V..E..S", "..##...", "...H..."] },
	{ "id": 25, "d": 5, "rows": ["S.R.R.S", "##...##", "V..E..V"] },
	{ "id": 26, "d": 5, "rows": ["M.S.S.M", "L.....L", "..R.R.."] },
]
