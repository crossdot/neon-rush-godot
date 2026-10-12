# NEON RUN — audio (ТЗ §26). Port of js/audio.js.
# SFX + looping music are pre-synthesized into AudioStreamWAV (no external assets).
# Music crossfades between the 5 tracks; a low ambient drone sits underneath.
extends Node

const SR := 22050

var _sfx_cache := {}
var _music_cache := {}
var _drone_cache := {}

var _sfx_pool: Array[AudioStreamPlayer] = []
var _sidx := 0
var _mus: Array[AudioStreamPlayer] = []
var _mus_idx := 0
var _cur_track := "drive"
var _amb: AudioStreamPlayer
var _bg_paused := false

const TRACKS := {
	"drive": { "every": 0.210, "bassType": "triangle", "bassVol": 0.16, "bass": [55.0, 55.0, 82.4, 55.0, 65.4, 55.0, 82.4, 98.0],
		"leadType": "square", "leadVol": 0.04, "leadDecay": 0.14, "lead": [440.0, 0.0, 523.0, 0.0, 659.0, 523.0, 0.0, 392.0], "gateN": 16.0, "gateP": 8.0 },
	"pulse": { "every": 0.178, "bassType": "sawtooth", "bassVol": 0.11, "bass": [73.4, 73.4, 87.3, 98.0, 73.4, 110.0, 98.0, 87.3],
		"leadType": "square", "leadVol": 0.05, "leadDecay": 0.10, "lead": [587.0, 659.0, 0.0, 880.0, 659.0, 0.0, 587.0, 440.0], "gateN": 8.0, "gateP": 4.0 },
	"ember": { "every": 0.190, "bassType": "sawtooth", "bassVol": 0.12, "bass": [73.4, 0.0, 73.4, 87.3, 0.0, 87.3, 98.0, 110.0],
		"leadType": "sawtooth", "leadVol": 0.045, "leadDecay": 0.12, "lead": [587.0, 0.0, 698.0, 880.0, 0.0, 698.0, 0.0, 587.0], "gateN": 12.0, "gateP": 6.0 },
	"echo": { "every": 0.250, "bassType": "sine", "bassVol": 0.20, "bass": [55.0, 0.0, 55.0, 0.0, 73.4, 0.0, 49.0, 0.0],
		"leadType": "triangle", "leadVol": 0.07, "leadDecay": 0.30, "lead": [440.0, 0.0, 0.0, 523.0, 0.0, 0.0, 392.0, 0.0], "gateN": 24.0, "gateP": 16.0 },
	"abyss": { "every": 0.260, "bassType": "sine", "bassVol": 0.22, "bass": [43.7, 0.0, 0.0, 43.7, 0.0, 58.3, 0.0, 49.0],
		"leadType": "triangle", "leadVol": 0.06, "leadDecay": 0.35, "lead": [880.0, 0.0, 0.0, 0.0, 659.0, 0.0, 0.0, 987.0], "gateN": 32.0, "gateP": 20.0 },
}

const AMB := [55.0, 49.0, 58.3, 61.7, 43.7]
const MUS_VOL := -10.0
const AMB_VOL := -26.0


func _ready() -> void:
	for i in range(6):
		var p := AudioStreamPlayer.new()
		add_child(p)
		_sfx_pool.append(p)
	for i in range(2):
		var m := AudioStreamPlayer.new()
		add_child(m)
		_mus.append(m)
	_amb = AudioStreamPlayer.new()
	_amb.volume_db = AMB_VOL
	add_child(_amb)


# ---------- synthesis helpers ----------
func _osc(phase: float, type: String) -> float:
	match type:
		"sine":
			return sin(phase)
		"square":
			return 1.0 if sin(phase) >= 0.0 else -1.0
		"sawtooth":
			return (phase / PI) - 1.0
		"triangle":
			return (2.0 / PI) * asin(sin(phase))
	return sin(phase)


func _add_tone(buf: PackedFloat32Array, freq: float, dur: float, type: String, vol: float, slide_to: float, offset: float) -> void:
	var n0: int = int(offset * SR)
	var n: int = int(dur * SR)
	for i in range(n):
		var idx: int = n0 + i
		if idx >= buf.size():
			break
		var t: float = float(i) / float(SR)
		# integrated phase for a linear freq ramp (freq -> slide_to)
		var ph: float
		if slide_to > 0.0 and dur > 0.0:
			ph = TAU * (freq * t + (slide_to - freq) * t * t / (2.0 * dur))
		else:
			ph = TAU * freq * t
		# envelope: quick linear decay from vol -> ~0
		var env: float = vol * (1.0 - float(i) / float(n))
		buf[idx] += _osc(ph, type) * env


func _add_noise(buf: PackedFloat32Array, dur: float, vol: float, offset: float) -> void:
	var n0: int = int(offset * SR)
	var n: int = int(dur * SR)
	for i in range(n):
		var idx: int = n0 + i
		if idx >= buf.size():
			break
		var env: float = vol * (1.0 - float(i) / float(n))
		buf[idx] += (randf() * 2.0 - 1.0) * env


func _wav(buf: PackedFloat32Array, loop: bool = false) -> AudioStreamWAV:
	var pcm := PackedByteArray()
	for s in buf:
		var v: int = int(clampf(s, -1.0, 1.0) * 32767.0)
		pcm.append(0xFF & v)
		pcm.append(0xFF & (v >> 8))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = SR
	w.stereo = false
	w.data = pcm
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = buf.size()
	return w


# ---------- SFX ----------
func _sfx_wave(name: String) -> PackedFloat32Array:
	var buf := PackedFloat32Array()
	buf.resize(int(SR * 0.6))
	match name:
		"start":
			_add_tone(buf, 220.0, 0.12, "square", 0.18, 440.0, 0.0)
			_add_tone(buf, 330.0, 0.18, "square", 0.14, 660.0, 0.0)
		"pickup":
			_add_tone(buf, 880.0, 0.07, "square", 0.12, 1320.0, 0.0)
		"gate":
			_add_tone(buf, 660.0, 0.10, "triangle", 0.18, 990.0, 0.0)
			_add_tone(buf, 990.0, 0.16, "triangle", 0.12, 1480.0, 0.0)
		"upgrade":
			_add_tone(buf, 523.0, 0.09, "square", 0.16, 0.0, 0.0)
			_add_tone(buf, 659.0, 0.09, "square", 0.16, 0.0, 0.08)
			_add_tone(buf, 784.0, 0.16, "square", 0.16, 0.0, 0.16)
		"hit":
			_add_tone(buf, 160.0, 0.18, "sawtooth", 0.30, 50.0, 0.0)
			_add_noise(buf, 0.15, 0.30, 0.0)
		"death":
			_add_tone(buf, 320.0, 0.50, "sawtooth", 0.28, 40.0, 0.0)
			_add_noise(buf, 0.40, 0.35, 0.0)
			_add_tone(buf, 160.0, 0.70, "square", 0.16, 45.0, 0.0)
			_add_tone(buf, 208.0, 0.25, "triangle", 0.15, 247.0, 0.18)
			_add_tone(buf, 233.0, 0.60, "sawtooth", 0.12, 55.0, 0.38)
		"record":
			for i in 4:
				_add_tone(buf, [523.0, 659.0, 784.0, 1047.0][i], 0.18, "square", 0.16, 0.0, i * 0.11)
		"click":
			_add_tone(buf, 660.0, 0.05, "square", 0.10, 0.0, 0.0)
		"heal":
			_add_tone(buf, 523.0, 0.12, "triangle", 0.20, 784.0, 0.0)
			_add_tone(buf, 784.0, 0.20, "triangle", 0.20, 1046.0, 0.10)
		"vlaser":
			_add_tone(buf, 1200.0, 0.12, "sawtooth", 0.14, 200.0, 0.0)
			_add_tone(buf, 600.0, 0.18, "square", 0.08, 100.0, 0.0)
		"seeker":
			_add_tone(buf, 300.0, 0.25, "sawtooth", 0.25, 60.0, 0.0)
			_add_noise(buf, 0.18, 0.22, 0.0)
		"complete":
			for i in 5:
				_add_tone(buf, [392.0, 523.0, 659.0, 784.0, 1047.0][i], 0.22, "triangle", 0.18, 0.0, i * 0.12)
			_add_tone(buf, 523.0, 0.80, "triangle", 0.13, 0.0, 0.62)
			_add_tone(buf, 659.0, 0.80, "triangle", 0.11, 0.0, 0.62)
			_add_tone(buf, 784.0, 0.90, "sine", 0.12, 0.0, 0.62)
			_add_tone(buf, 1568.0, 0.50, "sine", 0.07, 2093.0, 0.70)
	return buf


func sfx(name: String) -> void:
	if not Save.data.sound_enabled:
		return
	if not _sfx_cache.has(name):
		_sfx_cache[name] = _wav(_sfx_wave(name))
	var p := _sfx_pool[_sidx]
	_sidx = (_sidx + 1) % _sfx_pool.size()
	p.stream = _sfx_cache[name]
	p.play()


# ---------- music ----------
func _gate(track: Dictionary, step: int) -> bool:
	return float(step % int(track.gateN)) >= track.gateP


func _track_wave(key: String) -> PackedFloat32Array:
	var tr: Dictionary = TRACKS[key]
	var steps: int = int(tr.gateN)   # bake one full gate period (>=8)
	var every: float = tr.every
	var total: int = int(steps * every * SR) + int(SR * 0.3)
	var buf := PackedFloat32Array()
	buf.resize(total)
	for s in range(steps):
		var bass: float = tr.bass[s % 8]
		if bass > 0.0:
			_add_tone(buf, bass, 0.18, tr.bassType, tr.bassVol, 0.0, s * every)
		var lead: float = tr.lead[s % 8]
		if lead > 0.0 and _gate(tr, s):
			_add_tone(buf, lead, tr.leadDecay, tr.leadType, tr.leadVol, 0.0, s * every)
	return buf


func _play_track(key: String) -> void:
	if not TRACKS.has(key):
		key = "drive"
	if key == _cur_track and _mus[_mus_idx].playing:
		return
	if not _music_cache.has(key):
		_music_cache[key] = _wav(_track_wave(key), true)
	var other: int = 1 - _mus_idx
	var np := _mus[other]
	np.stream = _music_cache[key]
	np.volume_db = -60.0
	if not np.playing:
		np.play()
	var tween := np.create_tween()
	tween.tween_property(np, "volume_db", MUS_VOL, 0.4)
	var old := _mus[_mus_idx]
	if old != np and old.playing:
		var t2 := old.create_tween()
		t2.tween_property(old, "volume_db", -60.0, 0.4)
		t2.tween_callback(func(): old.stop())
	_mus_idx = other
	_cur_track = key


func _drone_wave(freq: float) -> PackedFloat32Array:
	var dur := 2.0
	var buf := PackedFloat32Array()
	buf.resize(int(dur * SR))
	for i in range(buf.size()):
		var t: float = float(i) / float(SR)
		var ph: float = TAU * freq * t
		var ph2: float = TAU * freq * 1.008 * t
		var ph3: float = TAU * freq * 2.0 * t
		var s: float = 0.6 * sin(ph) + 0.6 * sin(ph2) + 0.25 * _osc(ph3, "triangle")
		buf[i] = s * 0.12
	return buf


func _set_drone(idx: int) -> void:
	var freq: float = AMB[idx % AMB.size()]
	if not _drone_cache.has(freq):
		_drone_cache[freq] = _wav(_drone_wave(freq), true)
	if _amb.stream != _drone_cache[freq]:
		_amb.stream = _drone_cache[freq]
		_amb.volume_db = AMB_VOL
		if not _amb.playing:
			_amb.play()


func set_level(idx: int) -> void:
	var cfg: Dictionary = Gamedata.LEVELS[maxi(0, mini(idx, Gamedata.LEVELS.size() - 1))]
	var key: String = cfg.music if TRACKS.has(cfg.music) else "drive"
	_cur_track = key
	_set_drone(idx)
	if _music_should_play():
		_play_track(key)


func set_music(key: String) -> void:
	if TRACKS.has(key):
		_play_track(key)


func _music_should_play() -> bool:
	return Save.data.music_enabled


func music_start() -> void:
	if not Save.data.music_enabled:
		return
	if _mus[_mus_idx].playing:
		return
	_play_track(_cur_track)
	_set_drone(0)


func music_stop() -> void:
	for m in _mus:
		if m.playing:
			var t := m.create_tween()
			t.tween_property(m, "volume_db", -60.0, 0.4)
			t.tween_callback(func(): m.stop())
	if _amb.playing:
		var t := _amb.create_tween()
		t.tween_property(_amb, "volume_db", -60.0, 0.4)
		t.tween_callback(func(): _amb.stop())


func bg_pause() -> void:
	if _bg_paused:
		return
	_bg_paused = true
	for m in _mus:
		if m.playing:
			m.stream_paused = true
	if _amb.playing:
		_amb.stream_paused = true


func bg_resume() -> void:
	if not _bg_paused:
		return
	_bg_paused = false
	for m in _mus:
		m.stream_paused = false
	_amb.stream_paused = false


func ensure() -> bool:
	return true
