# NEON RUN — UI: screens, HUD, upgrade choice, tutorial, mock ads (ТЗ §27–32, §17).
# Port of js/ui.js. Built programmatically (no hand-authored .tscn node trees).
class_name GameUI extends Control

var rm: RunManager = null

# retained node refs
var hud: Control
var lbl_score: Label
var lbl_best: Label
var lbl_timer: Label
var lbl_timer_lbl: Label
var lbl_dist: Label
var lbl_mult: Label
var energy_fill: ColorRect
var hp_row: HBoxContainer

var banner_lbl: Label
var banner_t: float = 0.0
var tut_lbl: Label

var screen_roots: Dictionary = {}   # name -> Control
var ad_box: Control
var ad_count: Label
var ad_remaining: int = -1
var ad_done: Callable = Callable()

const FONT: String = "res://icon.svg"   # placeholder (not used)


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_hud()
	_build_screens()
	_build_overlays()


func _process(delta: float) -> void:
	if banner_t > 0.0:
		banner_t -= delta
		if banner_t <= 0.0:
			banner_lbl.visible = false
	if ad_remaining > 0:
		ad_remaining -= 1
		ad_count.text = str(maxi(0, ad_remaining))
		if ad_remaining <= 0:
			ad_remaining = -1
			ad_box.visible = false
			if ad_done.is_valid():
				var d := ad_done
				ad_done = Callable()
				d.call()


# ---------- helpers ----------
func _label(text: String, size: int, color: Color, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	return l


func _btn(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 20)
	b.custom_minimum_size = Vector2(260, 52)
	b.pressed.connect(func(): cb.call())
	return b


func _full_screen() -> Control:
	var c := ColorRect.new()
	c.color = Color(0.008, 0.012, 0.05, 0.86)
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	return c


func _vbox() -> VBoxContainer:
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 16)
	return v


func _title(text: String, color: Color) -> Label:
	var l := _label(text, 30, color, HORIZONTAL_ALIGNMENT_CENTER)
	return l


func _screen(name: String) -> Control:
	var root := _full_screen()
	root.visible = false
	root.name = name
	add_child(root)
	screen_roots[name] = root
	return root


# ---------- HUD ----------
func _build_hud() -> void:
	hud = Control.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hud)

	lbl_score = _label("0", 30, Color("#eafcff"))
	lbl_score.position = Vector2(16, 10)
	hud.add_child(lbl_score)
	lbl_best = _label("BEST 0", 12, Color("#7fe9ff"))
	lbl_best.position = Vector2(16, 46)
	hud.add_child(lbl_best)

	lbl_timer_lbl = _label("TIME", 11, Color("#eafcff"), HORIZONTAL_ALIGNMENT_RIGHT)
	lbl_timer_lbl.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	lbl_timer_lbl.position = Vector2(-150, 10)
	hud.add_child(lbl_timer_lbl)
	lbl_timer = _label("60", 30, Color("#eafcff"), HORIZONTAL_ALIGNMENT_RIGHT)
	lbl_timer.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	lbl_timer.position = Vector2(-150, 26)
	hud.add_child(lbl_timer)
	lbl_dist = _label("", 12, Color("#7fe9ff"), HORIZONTAL_ALIGNMENT_RIGHT)
	lbl_dist.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	lbl_dist.position = Vector2(-150, 60)
	hud.add_child(lbl_dist)

	lbl_mult = _label("x1.0", 24, Color("#7fe9ff"), HORIZONTAL_ALIGNMENT_CENTER)
	lbl_mult.set_anchors_preset(Control.PRESET_TOP_WIDE)
	lbl_mult.position = Vector2(0, 78)
	hud.add_child(lbl_mult)

	var bottom := HBoxContainer.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.position = Vector2(16, -46)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(bottom)

	var bar_bg := ColorRect.new()
	bar_bg.color = Color(0, 0.08, 0.16, 0.6)
	bar_bg.custom_minimum_size = Vector2(300, 8)
	bottom.add_child(bar_bg)
	energy_fill = ColorRect.new()
	energy_fill.color = Color("#00eaff")
	energy_fill.custom_minimum_size = Vector2(0, 8)
	bar_bg.add_child(energy_fill)

	hp_row = HBoxContainer.new()
	hp_row.add_theme_constant_override("separation", 6)
	bottom.add_child(hp_row)

	banner_lbl = _label("", 40, Color("#eafcff"), HORIZONTAL_ALIGNMENT_CENTER)
	banner_lbl.set_anchors_preset(Control.PRESET_TOP_WIDE)
	banner_lbl.position = Vector2(0, 300)
	banner_lbl.visible = false
	hud.add_child(banner_lbl)

	tut_lbl = _label("", 14, Color("#aef2ff"), HORIZONTAL_ALIGNMENT_CENTER)
	tut_lbl.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	tut_lbl.position = Vector2(0, -120)
	tut_lbl.visible = false
	hud.add_child(tut_lbl)

	hud.visible = false


# ---------- screens ----------
func _build_screens() -> void:
	# Menu
	var menu := _screen("menu")
	var mv := _vbox()
	menu.add_child(mv)
	mv.add_child(_title("NEON RUN", Color("#eafcff")))
	mv.add_child(_label("— LAST SIGNAL —", 14, Color("#7fe9ff"), HORIZONTAL_ALIGNMENT_CENTER))
	mv.add_child(_label("The city went dark after the Core fell.\nYou are the last drone carrying the final pulse home.", 12, Color("#9fd8ff"), HORIZONTAL_ALIGNMENT_CENTER))
	mv.add_child(_btn("PLAY", Callable(self, "_on_play")))
	mv.add_child(_btn("ENDLESS", Callable(self, "_on_endless")))
	mv.add_child(_btn("UPGRADES", Callable(self, "_on_upgrades")))
	mv.add_child(_btn("SETTINGS", Callable(self, "_on_settings")))
	var ver := _label("NEON RUN · Godot port", 10, Color("#55708f"), HORIZONTAL_ALIGNMENT_CENTER)
	ver.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	ver.position = Vector2(0, -30)
	menu.add_child(ver)

	# Mode select
	var mode := _screen("mode")
	var mdv := _vbox()
	mode.add_child(mdv)
	mdv.add_child(_title("SELECT MODE", Color("#eafcff")))
	mdv.add_child(_btn("RUN — 60 SECOND", Callable(self, "_on_mode_run")))
	var endless_btn := _btn("ENDLESS", Callable(self, "_on_mode_endless"))
	var endless_desc := _label("", 12, Color("#9fd8ff"), HORIZONTAL_ALIGNMENT_CENTER)
	mdv.add_child(endless_btn)
	mdv.add_child(endless_desc)
	mdv.add_child(_btn("BACK", Callable(rm, "to_menu")))
	screen_roots["endless_btn"] = endless_btn
	screen_roots["endless_desc"] = endless_desc

	# Upgrades
	var upg := _screen("upgrades")
	var uv := _vbox()
	upg.add_child(uv)
	var upg_title := _title("UPGRADES", Color("#eafcff"))
	uv.add_child(upg_title)
	var credits := _label("", 16, Color("#ffe14d"), HORIZONTAL_ALIGNMENT_CENTER)
	uv.add_child(credits)
	screen_roots["upg_credits"] = credits
	var cards := VBoxContainer.new()
	cards.add_theme_constant_override("separation", 10)
	uv.add_child(cards)
	screen_roots["upg_cards"] = cards
	uv.add_child(_btn("UPGRADE", Callable(self, "_on_upg_buy")))
	uv.add_child(_btn("BACK", Callable(self, "_on_upgrades_back")))

	# Settings
	var set := _screen("settings")
	var sv := _vbox()
	set.add_child(sv)
	sv.add_child(_title("SETTINGS", Color("#eafcff")))
	var snd := _btn("SOUND: ON", Callable(self, "_toggle_sound"))
	var mus := _btn("MUSIC: ON", Callable(self, "_toggle_music"))
	var fxb := _btn("EFFECTS: ON", Callable(self, "_toggle_fx"))
	var vib := _btn("VIBRATION: ON", Callable(self, "_toggle_vib"))
	sv.add_child(snd)
	sv.add_child(mus)
	sv.add_child(fxb)
	sv.add_child(vib)
	sv.add_child(_btn("RESET SAVE", Callable(self, "_on_reset")))
	sv.add_child(_btn("BACK", Callable(self, "_on_settings_back")))
	screen_roots["btn_snd"] = snd
	screen_roots["btn_mus"] = mus
	screen_roots["btn_fx"] = fxb
	screen_roots["btn_vib"] = vib

	# Dead
	var dead := _screen("dead")
	var dv := _vbox()
	dead.add_child(dv)
	dv.add_child(_title("RUN OVER", Color("#ff3d7f")))
	var ds := _label("SCORE 0", 20, Color("#eafcff"), HORIZONTAL_ALIGNMENT_CENTER)
	dv.add_child(ds)
	var dd := _label("DISTANCE 0 m", 16, Color("#eafcff"), HORIZONTAL_ALIGNMENT_CENTER)
	dv.add_child(dd)
	var db := _label("BEST 0", 14, Color("#9fd8ff"), HORIZONTAL_ALIGNMENT_CENTER)
	dv.add_child(db)
	var dc := _label("+0 CREDITS", 18, Color("#ffe14d"), HORIZONTAL_ALIGNMENT_CENTER)
	dv.add_child(dc)
	var cont := _btn("CONTINUE ▶ ad", Callable(self, "_on_continue"))
	var retry := _btn("TRY AGAIN", Callable(self, "_on_retry"))
	dv.add_child(cont)
	dv.add_child(retry)
	dv.add_child(_btn("MENU", Callable(rm, "to_menu")))
	screen_roots["dead_score"] = ds
	screen_roots["dead_dist"] = dd
	screen_roots["dead_best"] = db
	screen_roots["dead_credits"] = dc
	screen_roots["btn_continue"] = cont

	# Record
	var rec := _screen("record")
	var rv := _vbox()
	rec.add_child(rv)
	rv.add_child(_title("NEW RECORD!", Color("#ffe14d")))
	var rs := _label("0", 60, Color("#ffe14d"), HORIZONTAL_ALIGNMENT_CENTER)
	rv.add_child(rs)
	rv.add_child(_btn("CONTINUE", Callable(self, "_on_record_cont")))
	screen_roots["record_score"] = rs

	# Complete
	var comp := _screen("complete")
	var cv := _vbox()
	comp.add_child(cv)
	cv.add_child(_title("RUN COMPLETE", Color("#59ffb0")))
	var cs := _label("SCORE 0", 20, Color("#eafcff"), HORIZONTAL_ALIGNMENT_CENTER)
	cv.add_child(cs)
	var cb := _label("BEST 0", 14, Color("#9fd8ff"), HORIZONTAL_ALIGNMENT_CENTER)
	cv.add_child(cb)
	var cu := _label("◆ ENDLESS UNLOCKED ◆", 16, Color("#ffe14d"), HORIZONTAL_ALIGNMENT_CENTER)
	cv.add_child(cu)
	var cc := _label("+0 CREDITS", 18, Color("#ffe14d"), HORIZONTAL_ALIGNMENT_CENTER)
	cv.add_child(cc)
	cv.add_child(_btn("TRY AGAIN", Callable(self, "_on_complete_again")))
	cv.add_child(_btn("MENU", Callable(rm, "to_menu")))
	screen_roots["comp_score"] = cs
	screen_roots["comp_best"] = cb
	screen_roots["comp_unlock"] = cu
	screen_roots["comp_credits"] = cc


func _build_overlays() -> void:
	# choice overlay
	var choice := _full_screen()
	choice.visible = false
	choice.name = "choice"
	add_child(choice)
	screen_roots["choice"] = choice
	var cv := _vbox()
	choice.add_child(cv)
	cv.add_child(_title("ENERGY FULL — CHOOSE", Color("#eafcff")))
	screen_roots["choice_cards"] = cv

	# ad overlay
	var ad := _full_screen()
	ad.visible = false
	ad.name = "ad"
	add_child(ad)
	ad_box = ad
	var av := _vbox()
	ad.add_child(av)
	av.add_child(_label("REWARDED AD — DEMO", 14, Color("#ffe14d"), HORIZONTAL_ALIGNMENT_CENTER))
	ad_count = _label("5", 70, Color("#ffe14d"), HORIZONTAL_ALIGNMENT_CENTER)
	av.add_child(ad_count)


# ---------- public API used by RunManager ----------
func hide_screens() -> void:
	for name in screen_roots:
		screen_roots[name].visible = false


func hud_show(b: bool) -> void:
	hud.visible = b


func show_menu() -> void:
	hide_screens()
	screen_roots["menu"].visible = true
	_refresh_menu()
	_refresh_all()


func show_mode() -> void:
	hide_screens()
	screen_roots["mode"].visible = true
	var un: bool = Save.data.endless_unlocked
	var eb = screen_roots["endless_btn"]
	var ed = screen_roots["endless_desc"]
	eb.disabled = not un
	if un:
		eb.text = "PLAY"
		ed.text = "Distance is the score. Best: %d m" % int(Save.data.best_distance)
	else:
		eb.text = "LOCKED"
		ed.text = "Complete a 60s run to unlock."


func show_upgrades() -> void:
	hide_screens()
	screen_roots["upgrades"].visible = true
	_render_upg_cards()


func show_settings() -> void:
	hide_screens()
	screen_roots["settings"].visible = true
	_refresh_toggles()


func show_dead(d: Dictionary) -> void:
	hide_screens()
	screen_roots["dead_score"].text = "SCORE %d" % d.score
	screen_roots["dead_dist"].text = "DISTANCE %d m" % d.dist
	screen_roots["dead_best"].text = "BEST %d" % d.best
	screen_roots["dead_credits"].text = "+%d CREDITS" % d.credits
	screen_roots["btn_continue"].visible = true if d.canContinue else false
	screen_roots["dead"].visible = true


func show_complete(d: Dictionary) -> void:
	hide_screens()
	screen_roots["comp_score"].text = "SCORE %d" % d.score
	screen_roots["comp_best"].text = "BEST %d" % d.best
	screen_roots["comp_credits"].text = "+%d CREDITS" % d.credits
	screen_roots["comp_unlock"].visible = d.unlocked
	screen_roots["complete"].visible = true


func show_record(score: int, cb: Callable) -> void:
	hide_screens()
	screen_roots["record_score"].text = str(score)
	screen_roots["record"].visible = true
	ad_done = cb   # reuse done slot to continue after CONTINUE matches record flow


func show_choice(list: Array, cb: Callable) -> void:
	var cards: VBoxContainer = screen_roots["choice_cards"]
	for child in cards.get_children():
		child.queue_free()
	for u in list:
		var card := ColorRect.new()
		card.color = Color(0.016, 0.04, 0.11, 0.9)
		card.custom_minimum_size = Vector2(300, 64)
		var vb := VBoxContainer.new()
		vb.set_anchors_preset(Control.PRESET_FULL_RECT)
		card.add_child(vb)
		var name_l := _label(u.name, 20, Color(u.color), HORIZONTAL_ALIGNMENT_CENTER)
		var desc_l := _label(u.desc, 12, Color("#cfe9ff"), HORIZONTAL_ALIGNMENT_CENTER)
		vb.add_child(name_l)
		vb.add_child(desc_l)
		card.gui_input.connect(func(ev): if ev is InputEventMouseButton and ev.pressed: cb.call(u))
		cards.add_child(card)
	screen_roots["choice"].visible = true


func show_ad(kind: String, secs: int, cb: Callable) -> void:
	ad_count.text = str(secs)
	ad_remaining = secs
	ad_done = cb
	ad_box.visible = true


func banner(text: String, sub: String = "") -> void:
	banner_lbl.text = text + ("\n" + sub if sub != "" else "")
	banner_lbl.visible = true
	banner_t = 2.2


func tut(text) -> void:
	if text == null:
		tut_lbl.visible = false
	else:
		tut_lbl.text = str(text)
		tut_lbl.visible = true


func sync_hud(rm_: RunManager) -> void:
	lbl_score.text = str(int(rm_.run.score))
	lbl_best.text = "BEST %d" % maxi(int(Save.data.best_score), int(rm_.run.score))
	lbl_mult.text = "x%.1f" % rm_.run.mult
	var pct: float = clampf(rm_.run.energy / rm_.run.energyNeed, 0.0, 1.0)
	energy_fill.size = Vector2(300 * pct, 8)
	# hp / shields
	for child in hp_row.get_children():
		child.queue_free()
	for i in range(rm_.player.maxHp):
		var hb := ColorRect.new()
		hb.color = Color("#00eaff")
		hb.custom_minimum_size = Vector2(14, 14)
		hb.rotation = PI / 4.0
		hp_row.add_child(hb)
	for i in range(rm_.player.shieldCap):
		var sb := ColorRect.new()
		sb.color = Color("#59ffb0") if i < rm_.player.shield else Color(0.08, 0.22, 0.17)
		sb.custom_minimum_size = Vector2(14, 14)
		sb.rotation = PI / 4.0
		hp_row.add_child(sb)
	if rm_.run.mode == "run60":
		lbl_timer_lbl.text = "TIME"
		lbl_timer.text = str(maxi(0, ceili(60.0 - rm_.run.t)))
		lbl_dist.text = "%d m" % int(rm_.run.distPx / 22.0)
	else:
		lbl_timer_lbl.text = "DISTANCE"
		lbl_timer.text = "%d m" % int(rm_.run.distPx / 22.0)
		lbl_dist.text = "BEST %d m" % int(Save.data.best_distance)


# ---------- internal refresh ----------
func _refresh_menu() -> void:
	if screen_roots.has("menu"):
		pass


func _refresh_all() -> void:
	_refresh_toggles()


func _refresh_toggles() -> void:
	(screen_roots["btn_snd"] as Button).text = "SOUND: " + ("ON" if Save.data.sound_enabled else "OFF")
	(screen_roots["btn_mus"] as Button).text = "MUSIC: " + ("ON" if Save.data.music_enabled else "OFF")
	(screen_roots["btn_fx"] as Button).text = "EFFECTS: " + ("ON" if Save.data.fx_enabled else "OFF")
	(screen_roots["btn_vib"] as Button).text = "VIBRATION: " + ("ON" if Save.data.vib_enabled else "OFF")


func _render_upg_cards() -> void:
	var S := Save.data
	(screen_roots["upg_credits"] as Label).text = "CREDITS %d" % int(S.credits)
	var cards: VBoxContainer = screen_roots["upg_cards"]
	for child in cards.get_children():
		child.queue_free()
	for u in Upgrades.PERM_UPGRADES:
		var lvl: int = int(S.get(u.key, 0))
		var cost: int = 0 if lvl >= 5 else u.costs[lvl]
		var l := _label("%s  Lv%d/5  %s" % [u.name, lvl, ("MAXED" if lvl >= 5 else "%d CR" % cost)], 14, Color("#eafcff"), HORIZONTAL_ALIGNMENT_CENTER)
		cards.add_child(l)


# ---------- button handlers ----------
func _on_play() -> void:
	show_mode()


func _on_endless() -> void:
	if Save.data.endless_unlocked:
		rm.start_run("endless")
	else:
		show_mode()


func _on_upgrades() -> void:
	show_upgrades()


func _on_settings() -> void:
	show_settings()


func _on_mode_run() -> void:
	rm.start_run("run60")


func _on_mode_endless() -> void:
	if Save.data.endless_unlocked:
		rm.start_run("endless")


func _on_upgrades_back() -> void:
	rm.to_menu()


func _on_upg_buy() -> void:
	# buy the first affordable, non-maxed permanent upgrade
	for u in Upgrades.PERM_UPGRADES:
		var lvl: int = int(Save.data.get(u.key, 0))
		if lvl >= 5:
			continue
		var cost: int = u.costs[lvl]
		if int(Save.data.credits) >= cost:
			Save.data.credits = int(Save.data.credits) - cost
			Save.data[u.key] = lvl + 1
			Save.save()
			_render_upg_cards()
			return


func _on_settings_back() -> void:
	rm.to_menu()


func _on_reset() -> void:
	Save.reset()
	_refresh_toggles()


func _toggle_sound() -> void:
	Save.data.sound_enabled = not Save.data.sound_enabled
	Save.save()
	_refresh_toggles()


func _toggle_music() -> void:
	Save.data.music_enabled = not Save.data.music_enabled
	Save.save()
	if Save.data.music_enabled:
		Audio.music_start()
	else:
		Audio.music_stop()
	_refresh_toggles()


func _toggle_fx() -> void:
	Save.data.fx_enabled = not Save.data.fx_enabled
	Save.save()
	_refresh_toggles()


func _toggle_vib() -> void:
	Save.data.vib_enabled = not Save.data.vib_enabled
	Save.save()
	_refresh_toggles()


func _on_continue() -> void:
	rm.continue_run()


func _on_retry() -> void:
	rm.start_run(rm.mode)


func _on_record_cont() -> void:
	# ad_done held the record continuation callback
	if ad_done.is_valid():
		var d := ad_done
		ad_done = Callable()
		d.call()


func _on_complete_again() -> void:
	rm.start_run("run60")
