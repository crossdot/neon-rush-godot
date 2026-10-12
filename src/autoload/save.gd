# NEON RUN — save (ТЗ §37: local save on device).
# Port of js/save.js → Godot. Persisted as JSON in user://.
extends Node

var data: Dictionary = {}

const PATH := "user://neonrun_save.json"

const DEFAULTS := {
	"best_score": 0,
	"best_distance": 0,
	"credits": 0,
	"upgrade_hp": 0,          # permanent levels 0..5
	"upgrade_energy": 0,
	"upgrade_shield": 0,
	"unlocked_levels": 1,
	"endless_unlocked": false,
	"sound_enabled": true,
	"music_enabled": true,
	"fx_enabled": true,       # visual: parallax, shake, glitch
	"vib_enabled": true,      # haptics
	"tutorial_done": false,
	"runs_completed": 0,
	"since_ad": 0,
	"stats": {},
}


func _ready() -> void:
	load_save()


func load_save() -> void:
	var values := {}
	if FileAccess.file_exists(PATH):
		var f := FileAccess.open(PATH, FileAccess.READ)
		if f:
			var parsed = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				values = parsed
			f.close()
	data = DEFAULTS.duplicate(true)
	for k in values.keys():
		data[k] = values[k]
	if not (data.get("stats") is Dictionary):
		data["stats"] = {}


func save() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))
		f.close()


func reset() -> void:
	data = DEFAULTS.duplicate(true)
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(PATH)
	save()
