class_name GameUI
extends Control
## All screens, built in code with the UIKit visual language: menu, HUD,
## pause, settings, hangar, results. Touch targets >= 48 dp; layout respects
## the display safe area. During a run only score/distance, essential status,
## pause and the roll buttons are shown.

signal launch_pressed
signal retry_pressed
signal menu_pressed
signal pause_pressed
signal resume_pressed
signal roll_pressed(dir: int)
signal recalibrate_pressed
signal hangar_toggled(open: bool)
signal livery_selected(id: String)
signal setting_changed(key: String, value: Variant)

const CYAN := UIKit.CYAN
const GOLD := UIKit.GOLD
const PINK := UIKit.PINK

var _theme: Theme
var _safe: MarginContainer
var menu: Control
var hud: Control
var pause_panel: Control
var settings_panel: Control
var hangar_panel: Control
var results: Control
var flash_rect: ColorRect
var _dim: ColorRect

var _score: Label
var _distance: Label
var _speed: Label
var _gauge: UIKit.SpeedGauge
var _pips: UIKit.ComboPips
var _combo: Label
var _combo_box: Control
var _popup: Label
var _popup_box: Control
var _banner_box: Control
var _banner_top: Label
var _banner: Label
var _countdown: Label
var _hint: Control
var _menu_best: Label
var _menu_credits: Label
var _tap: Control
var _title_box: Control
var _roll_l: UIKit.RollButton
var _roll_r: UIKit.RollButton
var _res_title: Label
var _res_reason: Label
var _res_best: Label
var _res_score: Label
var _res_cells: Dictionary = {}
var _res_target: int = 0
var _res_shown: float = 0.0
var _hangar_name: Label
var _hangar_status: Label
var _hangar_action: Button
var _hangar_index: int = 0
var _toggles: Dictionary = {}
## Set by the game each frame: whether a motion sensor is delivering data.
var tilt_available: bool = false
var _tilt_note: Label
var _tilt_row: Control
var _recal_btn: Button
var _hint_main: Label
var _hint_sub: Label
## Every interactive control, keyed "screen:label" (used by the dev harness to click them).
var buttons: Dictionary = {}
var _building: String = ""
var _settings_from_pause: bool = false
var _current: String = ""
var _t: float = 0.0
var _popup_t: float = 0.0
var _banner_t: float = 0.0
var _countdown_t: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_theme = UIKit.build_theme()
	theme = _theme
	flash_rect = ColorRect.new()
	flash_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash_rect.color = Color(1, 1, 1, 0)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash_rect)
	_dim = ColorRect.new()
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.color = Color(0.0, 0.01, 0.03, 0.55)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dim)
	_safe = MarginContainer.new()
	_safe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_safe)
	_apply_safe_area()
	get_viewport().size_changed.connect(_apply_safe_area)
	_build_hud()
	_build_menu()
	_build_pause()
	_build_settings()
	_build_hangar()
	_build_results()
	show_screen("menu")


func _apply_safe_area() -> void:
	var m := 28
	var left := m
	var right := m
	var top := m
	var bottom := m
	if OS.has_feature("mobile"):
		var safe := DisplayServer.get_display_safe_area()
		var screen := DisplayServer.screen_get_size()
		var vp := get_viewport_rect().size
		if screen.x > 0 and safe.size.x > 0:
			var sx := vp.x / screen.x
			var sy := vp.y / screen.y
			left = maxi(m, int(safe.position.x * sx) + 8)
			top = maxi(m, int(safe.position.y * sy) + 8)
			right = maxi(m, int((screen.x - safe.end.x) * sx) + 8)
			bottom = maxi(m, int((screen.y - safe.end.y) * sy) + 8)
	_safe.add_theme_constant_override("margin_left", left)
	_safe.add_theme_constant_override("margin_right", right)
	_safe.add_theme_constant_override("margin_top", top)
	_safe.add_theme_constant_override("margin_bottom", bottom)


# --- small builders ----------------------------------------------------------------

func _button(text: String, cb: Callable, min_size: Vector2 = Vector2(240, 66), key: String = "") -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	var on_pressed := func() -> void:
		Sfx.play("click")
		cb.call()
	b.pressed.connect(on_pressed)
	buttons["%s:%s" % [_building, key if key != "" else text]] = b
	return b


## Filled cyan call-to-action button.
func _primary(b: Button) -> Button:
	var sb := UIKit.box(Color(UIKit.CYAN, 0.9), Color.WHITE, 0.22)
	sb.shadow_color = Color(UIKit.CYAN, 0.45)
	sb.shadow_size = 14
	var hv := sb.duplicate() as StyleBoxFlat
	hv.bg_color = Color(0.6, 0.98, 1.0)
	var pr := sb.duplicate() as StyleBoxFlat
	pr.bg_color = Color.WHITE
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", hv)
	b.add_theme_stylebox_override("pressed", pr)
	b.add_theme_stylebox_override("hover_pressed", pr)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(c, Color(0.01, 0.04, 0.08))
	return b


func _layer() -> Control:
	var c := Control.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_safe.add_child(c)
	return c


func _place(parent: Control, child: Control, preset: int) -> Control:
	parent.add_child(child)
	child.set_anchors_and_offsets_preset(preset, Control.PRESET_MODE_MINSIZE)
	match preset:
		Control.PRESET_CENTER_TOP, Control.PRESET_CENTER_BOTTOM, Control.PRESET_CENTER:
			child.grow_horizontal = Control.GROW_DIRECTION_BOTH
		Control.PRESET_TOP_RIGHT, Control.PRESET_BOTTOM_RIGHT, Control.PRESET_CENTER_RIGHT:
			child.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	match preset:
		Control.PRESET_CENTER, Control.PRESET_CENTER_RIGHT, Control.PRESET_CENTER_LEFT:
			child.grow_vertical = Control.GROW_DIRECTION_BOTH
		Control.PRESET_CENTER_BOTTOM, Control.PRESET_BOTTOM_LEFT, Control.PRESET_BOTTOM_RIGHT:
			child.grow_vertical = Control.GROW_DIRECTION_BEGIN
	return child


func _vbox(sep: int = 14) -> VBoxContainer:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", sep)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return vb


func _centered(parent: Control, panel: Control) -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(center)
	center.add_child(panel)


func _header(text: String, color: Color = CYAN) -> VBoxContainer:
	var vb := _vbox(4)
	var l := UIKit.label(text, 40, UIKit.TEXT, 10, 0.5, Color(color, 0.5))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(l)
	vb.add_child(UIKit.Divider.new(color))
	return vb


## Translucent slanted plate behind HUD readouts.
func _plate(child: Control, accent: Color = CYAN) -> PanelContainer:
	var pc := PanelContainer.new()
	var sb := UIKit.box(Color(0.01, 0.025, 0.05, 0.5), Color(accent, 0.0), 0.18)
	sb.border_width_left = 4
	sb.border_color = Color(accent, 0.9)
	sb.content_margin_left = 22
	sb.content_margin_right = 26
	sb.content_margin_top = 6
	sb.content_margin_bottom = 8
	pc.add_theme_stylebox_override("panel", sb)
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.add_child(child)
	return pc


# --- HUD ---------------------------------------------------------------------------

func _build_hud() -> void:
	_building = "hud"
	hud = _layer()
	# score block
	var sb := _vbox(-6)
	sb.add_child(UIKit.label("SCORE", 15, Color(CYAN, 0.85), 6, 0.3))
	_score = UIKit.label("0", 52, UIKit.TEXT, 2, 0.45, Color(CYAN, 0.45))
	sb.add_child(_score)
	_distance = UIKit.label("0 M", 20, UIKit.TEXT_DIM, 4, 0.2)
	sb.add_child(_distance)
	_place(hud, _plate(sb), Control.PRESET_TOP_LEFT)

	# pause + speed (top right)
	var tr := HBoxContainer.new()
	tr.add_theme_constant_override("separation", 18)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sp := _vbox(2)
	var sp_row := HBoxContainer.new()
	sp_row.alignment = BoxContainer.ALIGNMENT_END
	sp_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_speed = UIKit.label("0", 30, UIKit.TEXT, 2, 0.4)
	sp_row.add_child(_speed)
	var unit := UIKit.label(" KM/H", 15, Color(CYAN, 0.85), 4, 0.3)
	unit.size_flags_vertical = Control.SIZE_SHRINK_END
	sp_row.add_child(unit)
	sp.add_child(sp_row)
	_gauge = UIKit.SpeedGauge.new()
	sp.add_child(_gauge)
	tr.add_child(_plate(sp))
	var pause_btn := _button("", func() -> void: pause_pressed.emit(), Vector2(74, 74), "II")
	pause_btn.add_child(UIKit.PauseGlyph.new())
	var psb := UIKit.box(Color(0.01, 0.025, 0.05, 0.6), Color(CYAN, 0.7), 0.0)
	psb.set_border_width_all(2)
	pause_btn.add_theme_stylebox_override("normal", psb)
	tr.add_child(pause_btn)
	_place(hud, tr, Control.PRESET_TOP_RIGHT)

	# combo (top centre)
	_combo_box = _vbox(4)
	_combo = UIKit.label("", 22, PINK, 6, 0.45, Color(PINK, 0.5))
	_combo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_combo_box.add_child(_combo)
	_pips = UIKit.ComboPips.new()
	_combo_box.add_child(_pips)
	_place(hud, _combo_box, Control.PRESET_CENTER_TOP)

	# near-miss popup under the combo
	_popup = UIKit.label("", 30, CYAN, 6, 0.55, Color(CYAN, 0.6))
	_popup.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_popup_box = _plate(_popup, CYAN)
	_place(hud, _popup_box, Control.PRESET_CENTER_TOP)
	_popup_box.position.y += 70
	_popup_box.modulate.a = 0.0

	# sector banner
	_banner_box = _vbox(0)
	_banner_top = UIKit.label("", 16, Color(CYAN, 0.9), 10, 0.3)
	_banner_top.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner = UIKit.label("", 38, UIKit.TEXT, 12, 0.5, Color(CYAN, 0.45))
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_box.add_child(_banner_top)
	_banner_box.add_child(_banner)
	_banner_box.add_child(UIKit.Flourish.new(520))
	_place(hud, _banner_box, Control.PRESET_CENTER_TOP)
	_banner_box.position.y += 135
	_banner_box.modulate.a = 0.0

	# countdown
	_countdown = UIKit.label("", 150, UIKit.TEXT, 8, 0.6, Color(CYAN, 0.8))
	_countdown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(hud, _countdown, Control.PRESET_CENTER)
	_countdown.position.y -= 40

	# tutorial hint
	var hv := _vbox(2)
	var h1 := UIKit.label("DRAG ANYWHERE TO STEER", 26, UIKit.TEXT, 6, 0.45)
	_hint_main = h1
	h1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var h2 := UIKit.label("TAP  ROLL  TO DODGE SIDEWAYS", 16, Color(CYAN, 0.9), 6, 0.3)
	_hint_sub = h2
	h2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hv.add_child(h1)
	hv.add_child(h2)
	_hint = _plate(hv)
	_place(hud, _hint, Control.PRESET_CENTER_TOP)
	_hint.position.y += 235
	_hint.visible = false

	# barrel-roll thumb buttons
	_roll_l = UIKit.RollButton.new(-1)
	_roll_r = UIKit.RollButton.new(1)
	for rb in [_roll_l, _roll_r]:
		(rb as UIKit.RollButton).triggered.connect(func(d: int) -> void: roll_pressed.emit(d))
	_place(hud, _roll_l, Control.PRESET_BOTTOM_LEFT)
	_place(hud, _roll_r, Control.PRESET_BOTTOM_RIGHT)
	buttons["hud:roll_left"] = _roll_l
	buttons["hud:roll_right"] = _roll_r


func set_hud(score: int, distance: float, speed: float, combo: int, combo_frac: float, speed_t: float = -1.0) -> void:
	_score.text = _fmt(score)
	_distance.text = "%s M" % _fmt(int(distance))
	_speed.text = str(int(speed * 3.6))
	_gauge.set_value(speed_t if speed_t >= 0.0 else clampf((speed - 30.0) / 35.0, 0.0, 1.0))
	_pips.set_state(combo, combo_frac)
	_combo.text = ("COMBO  x%d" % combo) if combo > 0 else "COMBO"
	_combo_box.modulate.a = 1.0 if combo > 0 else 0.18


func set_roll_ready(frac: float) -> void:
	_roll_l.set_ready(frac)
	_roll_r.set_ready(frac)


func popup(text: String, color: Color = CYAN) -> void:
	_popup.text = text
	_popup.label_settings.font_color = color
	_popup.label_settings.shadow_color = Color(color, 0.6)
	var sb := _popup_box.get_theme_stylebox("panel") as StyleBoxFlat
	sb.border_color = color
	_popup_t = 1.0
	_popup_box.pivot_offset = _popup_box.size * 0.5
	_popup_box.scale = Vector2.ONE * 1.35


func banner(text: String) -> void:
	var parts := text.split("  -  ")
	_banner_top.text = parts[0] if parts.size() > 1 else ""
	_banner.text = parts[parts.size() - 1]
	_banner_t = 3.2


func set_countdown(text: String) -> void:
	_countdown.text = text
	_countdown_t = 0.6
	_countdown.pivot_offset = _countdown.size * 0.5
	_countdown.scale = Vector2.ONE * 1.5
	_countdown.label_settings.font_color = CYAN if text == "GO" else UIKit.TEXT


func show_hint(v: bool) -> void:
	var tilt_on := bool(Save.setting("tilt")) and tilt_available
	_hint_main.text = "TILT YOUR PHONE TO STEER" if tilt_on else "DRAG ANYWHERE TO STEER"
	_hint.visible = v


func flash(color: Color, strength: float) -> void:
	flash_rect.color = Color(color, strength)


# --- Menu --------------------------------------------------------------------------

func _build_menu() -> void:
	_building = "menu"
	menu = _layer()
	var tap_area := Button.new()
	tap_area.flat = true
	tap_area.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tap_area.focus_mode = Control.FOCUS_NONE
	for st in ["normal", "hover", "pressed", "hover_pressed"]:
		tap_area.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	tap_area.pressed.connect(func() -> void: launch_pressed.emit())
	menu.add_child(tap_area)
	buttons["menu:tap"] = tap_area

	_title_box = _vbox(-4)
	var kicker := UIKit.label("DASHPANDA STUDIOS", 14, Color(CYAN, 0.75), 7, 0.3)
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var title := UIKit.label("VOID RUNNER", 104, Color(0.96, 0.99, 1.0), 14, 0.7, Color(CYAN, 0.75))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var flo := UIKit.Flourish.new(760)
	var sub := UIKit.label("SPEED THROUGH THE UNKNOWN", 18, Color(0.75, 0.93, 1.0), 7, 0.3)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_box.add_child(kicker)
	_title_box.add_child(title)
	_title_box.add_child(flo)
	_title_box.add_child(sub)
	_place(menu, _title_box, Control.PRESET_CENTER_TOP)
	_title_box.position.y += 18

	# launch call-to-action
	var tap_row := HBoxContainer.new()
	tap_row.add_theme_constant_override("separation", 18)
	tap_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l1 := UIKit.label(">>", 26, CYAN, 0, 0.5, Color(CYAN, 0.6))
	var lt := UIKit.label("TAP TO LAUNCH", 30, UIKit.TEXT, 8, 0.55, Color(CYAN, 0.55))
	var l2 := UIKit.label("<<", 26, CYAN, 0, 0.5, Color(CYAN, 0.6))
	tap_row.add_child(l1)
	tap_row.add_child(lt)
	tap_row.add_child(l2)
	_tap = _plate(tap_row)
	_place(menu, _tap, Control.PRESET_CENTER_BOTTOM)

	# pilot record card
	var card := UIKit.SciPanel.new(GOLD, 20)
	card.cut = 14.0
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 34)
	grid.add_theme_constant_override("v_separation", 0)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.add_child(UIKit.label("BEST", 14, UIKit.TEXT_DIM, 6, 0.3))
	grid.add_child(UIKit.label("CREDITS", 14, UIKit.TEXT_DIM, 6, 0.3))
	_menu_best = UIKit.label("0", 30, UIKit.TEXT, 2, 0.45)
	_menu_best.custom_minimum_size = Vector2(110, 0)
	_menu_credits = UIKit.label("0", 30, GOLD, 2, 0.45, Color(GOLD, 0.35))
	_menu_credits.custom_minimum_size = Vector2(110, 0)
	grid.add_child(_menu_best)
	grid.add_child(_menu_credits)
	card.add_child(grid)
	_place(menu, card, Control.PRESET_BOTTOM_LEFT)

	var col := _vbox(12)
	var open_settings := func() -> void:
		_settings_from_pause = false
		show_screen("settings")
	col.add_child(_button("HANGAR", func() -> void: show_screen("hangar"), Vector2(230, 62)))
	col.add_child(_button("SETTINGS", open_settings, Vector2(230, 62)))
	_place(menu, col, Control.PRESET_BOTTOM_RIGHT)


func set_menu_stats(best: int, credits: int) -> void:
	_menu_best.text = _fmt(best)
	_menu_credits.text = _fmt(credits)


# --- Pause / settings / hangar -----------------------------------------------------

func _build_pause() -> void:
	_building = "pause"
	pause_panel = _layer()
	var panel := UIKit.SciPanel.new()
	var vb := _vbox(14)
	vb.add_child(_header("PAUSED"))
	vb.add_child(_primary(_button("RESUME", func() -> void: resume_pressed.emit(), Vector2(340, 70))))
	_recal_btn = _button("RECALIBRATE TILT", func() -> void: recalibrate_pressed.emit(), Vector2(340, 62))
	vb.add_child(_recal_btn)
	vb.add_child(_button("RESTART", func() -> void: retry_pressed.emit(), Vector2(340, 62)))
	var open_settings := func() -> void:
		_settings_from_pause = true
		show_screen("settings")
	vb.add_child(_button("SETTINGS", open_settings, Vector2(340, 62)))
	vb.add_child(_button("MENU", func() -> void: menu_pressed.emit(), Vector2(340, 62)))
	panel.add_child(vb)
	_centered(pause_panel, panel)


func _build_settings() -> void:
	_building = "settings"
	settings_panel = _layer()
	var panel := UIKit.SciPanel.new()
	var vb := _vbox(10)
	vb.add_child(_header("SETTINGS"))
	for entry in [["tilt", "TILT STEERING"], ["reduced_motion", "REDUCED MOTION"], ["invert_y", "INVERT VERTICAL"], ["high_quality", "HIGH QUALITY EFFECTS"], ["haptics", "HAPTICS"]]:
		var key: String = entry[0]
		var cbtn := CheckButton.new()
		cbtn.text = entry[1]
		cbtn.custom_minimum_size = Vector2(460, 48)
		var on_toggled := func(on: bool) -> void:
			Sfx.play("click")
			setting_changed.emit(key, on)
			if key == "tilt":
				_refresh_tilt_rows(on)
		cbtn.toggled.connect(on_toggled)
		vb.add_child(cbtn)
		_toggles[key] = cbtn
		buttons["settings:" + key] = cbtn
		if key == "tilt":
			_tilt_row = HBoxContainer.new()
			_tilt_row.add_theme_constant_override("separation", 18)
			var tl := UIKit.label("TILT SENSITIVITY", 16, UIKit.TEXT_DIM, 3, 0.2)
			_tilt_row.add_child(tl)
			var ts := HSlider.new()
			ts.min_value = 0.0
			ts.max_value = 1.0
			ts.step = 0.05
			ts.custom_minimum_size = Vector2(200, 40)
			ts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			ts.value_changed.connect(func(v: float) -> void: setting_changed.emit("tilt_sensitivity", v))
			_tilt_row.add_child(ts)
			vb.add_child(_tilt_row)
			_toggles["tilt_sensitivity"] = ts
			buttons["settings:tilt_sensitivity"] = ts
			_tilt_note = UIKit.label("NO MOTION SENSOR FOUND - USING TOUCH", 13, UIKit.GOLD, 3, 0.2)
			vb.add_child(_tilt_note)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	var vl := UIKit.label("EFFECTS VOLUME", 18, UIKit.TEXT_DIM, 3, 0.2)
	row.add_child(vl)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.custom_minimum_size = Vector2(200, 40)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(func(v: float) -> void: setting_changed.emit("sfx_volume", v))
	row.add_child(slider)
	vb.add_child(row)
	_toggles["sfx_volume"] = slider
	var done := func() -> void:
		show_screen("pause" if _settings_from_pause else "menu")
	vb.add_child(_primary(_button("DONE", done, Vector2(460, 64))))
	panel.add_child(vb)
	_centered(settings_panel, panel)


func sync_settings(s: Dictionary) -> void:
	(_toggles["reduced_motion"] as CheckButton).set_pressed_no_signal(bool(s.get("reduced_motion", false)))
	(_toggles["invert_y"] as CheckButton).set_pressed_no_signal(bool(s.get("invert_y", false)))
	(_toggles["high_quality"] as CheckButton).set_pressed_no_signal(str(s.get("quality", "high")) == "high")
	(_toggles["haptics"] as CheckButton).set_pressed_no_signal(bool(s.get("haptics", true)))
	(_toggles["sfx_volume"] as HSlider).set_value_no_signal(float(s.get("sfx_volume", 0.9)))
	(_toggles["tilt"] as CheckButton).set_pressed_no_signal(bool(s.get("tilt", false)))
	(_toggles["tilt_sensitivity"] as HSlider).set_value_no_signal(float(s.get("tilt_sensitivity", 0.5)))
	_refresh_tilt_rows(bool(s.get("tilt", false)))


func _refresh_tilt_rows(on: bool) -> void:
	_tilt_row.visible = on
	_tilt_note.visible = on and not tilt_available
	_recal_btn.visible = on and tilt_available


func _build_hangar() -> void:
	_building = "hangar"
	hangar_panel = _layer()
	var panel := UIKit.SciPanel.new(GOLD, 30)
	var vb := _vbox(12)
	vb.add_child(_header("HANGAR", GOLD))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	row.add_child(_button("<", func() -> void: _cycle_livery(-1), Vector2(70, 66)))
	var names := _vbox(0)
	_hangar_name = UIKit.label("NOVA", 36, GOLD, 8, 0.55, Color(GOLD, 0.45))
	_hangar_name.custom_minimum_size = Vector2(220, 0)
	_hangar_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hangar_status = UIKit.label("", 15, UIKit.TEXT_DIM, 5, 0.3)
	_hangar_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	names.add_child(_hangar_name)
	names.add_child(_hangar_status)
	row.add_child(names)
	row.add_child(_button(">", func() -> void: _cycle_livery(1), Vector2(70, 66)))
	vb.add_child(row)
	var note := UIKit.label("SAME HITBOX ON EVERY HULL", 13, Color(UIKit.TEXT_DIM, 0.8), 4, 0.2)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(note)
	_hangar_action = _button("EQUIPPED", func() -> void: _hangar_act(), Vector2(380, 66), "action")
	vb.add_child(_hangar_action)
	vb.add_child(_button("BACK", func() -> void: show_screen("menu"), Vector2(380, 60)))
	panel.add_child(vb)
	_place(hangar_panel, panel, Control.PRESET_CENTER_RIGHT)


func refresh_hangar() -> void:
	var id: String = ShipBuilder.ORDER[_hangar_index]
	var lv: Dictionary = ShipBuilder.LIVERIES[id]
	_hangar_name.text = lv["name"]
	var unlocked: Array = Save.data["unlocked_liveries"]
	var credits := int(Save.data["credits"])
	if id == Save.data["livery"]:
		_hangar_action.text = "EQUIPPED"
		_hangar_action.disabled = true
		_hangar_status.text = "IN SERVICE"
	elif id in unlocked:
		_hangar_action.text = "EQUIP"
		_hangar_action.disabled = false
		_hangar_status.text = "OWNED"
	else:
		_hangar_action.text = "UNLOCK  %s CR" % _fmt(int(lv["cost"]))
		_hangar_action.disabled = credits < int(lv["cost"])
		_hangar_status.text = "LOCKED  -  YOU HAVE %s CR" % _fmt(credits)


func _cycle_livery(dir: int) -> void:
	_hangar_index = posmod(_hangar_index + dir, ShipBuilder.ORDER.size())
	refresh_hangar()
	livery_selected.emit("preview:" + ShipBuilder.ORDER[_hangar_index])


func _hangar_act() -> void:
	var id: String = ShipBuilder.ORDER[_hangar_index]
	var unlocked: Array = Save.data["unlocked_liveries"]
	if not id in unlocked:
		var cost := int(ShipBuilder.LIVERIES[id]["cost"])
		if not Save.spend(cost):
			return
		unlocked.append(id)
	Save.data["livery"] = id
	Save.commit()
	Sfx.play("chime")
	refresh_hangar()
	livery_selected.emit(id)


# --- Results -----------------------------------------------------------------------

func _build_results() -> void:
	_building = "results"
	results = _layer()
	var panel := UIKit.SciPanel.new(UIKit.RED, 34)
	var vb := _vbox(10)
	_res_title = UIKit.label("HULL BREACH", 50, UIKit.RED, 12, 0.6, Color(UIKit.RED, 0.55))
	_res_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_res_title)
	_res_reason = UIKit.label("", 19, Color(1.0, 0.86, 0.78), 2, 0.15)
	_res_reason.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_res_reason)
	vb.add_child(UIKit.Divider.new(UIKit.RED))
	var score_box := _vbox(-6)
	var sl := UIKit.label("FINAL SCORE", 15, UIKit.TEXT_DIM, 8, 0.3)
	sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_res_score = UIKit.label("0", 64, UIKit.TEXT, 4, 0.6, Color(CYAN, 0.45))
	_res_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_box.add_child(sl)
	score_box.add_child(_res_score)
	vb.add_child(score_box)
	_res_best = UIKit.label("", 18, GOLD, 8, 0.45, Color(GOLD, 0.5))
	_res_best.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_res_best)
	var cells := HBoxContainer.new()
	cells.add_theme_constant_override("separation", 10)
	cells.alignment = BoxContainer.ALIGNMENT_CENTER
	for c in [["distance", "DISTANCE", UIKit.TEXT], ["near", "NEAR MISSES", PINK], ["credits", "CREDITS", GOLD]]:
		var cell := _vbox(-2)
		var cl := UIKit.label(c[1], 13, UIKit.TEXT_DIM, 5, 0.3)
		cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var cv := UIKit.label("0", 28, c[2], 2, 0.45)
		cv.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.add_child(cl)
		cell.add_child(cv)
		var plate := PanelContainer.new()
		var psb := UIKit.box(Color(1, 1, 1, 0.04), Color(1, 1, 1, 0.08), 0.0)
		psb.content_margin_left = 18
		psb.content_margin_right = 18
		plate.add_theme_stylebox_override("panel", psb)
		plate.custom_minimum_size = Vector2(170, 0)
		plate.add_child(cell)
		cells.add_child(plate)
		_res_cells[c[0]] = cv
	vb.add_child(cells)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	var retry := _primary(_button("RETRY", func() -> void: retry_pressed.emit(), Vector2(300, 74)))
	retry.add_theme_font_size_override("font_size", 30)
	row.add_child(retry)
	row.add_child(_button("MENU", func() -> void: menu_pressed.emit(), Vector2(200, 74)))
	vb.add_child(row)
	panel.add_child(vb)
	_centered(results, panel)


func show_results(score: int, distance: float, near_misses: int, credits: int, reason: String, new_best: bool, best: int) -> void:
	_res_reason.text = reason.to_upper()
	_res_best.text = "NEW PERSONAL BEST" if new_best else "BEST  %s" % _fmt(best)
	_res_target = score
	_res_shown = 0.0
	_res_score.text = "0"
	(_res_cells["distance"] as Label).text = "%s M" % _fmt(int(distance))
	(_res_cells["near"] as Label).text = str(near_misses)
	(_res_cells["credits"] as Label).text = "+%d" % credits
	show_screen("results")


# --- Screen management -------------------------------------------------------------

func show_screen(screen_name: String) -> void:
	var prev := _current
	_current = screen_name
	menu.visible = screen_name == "menu"
	hud.visible = screen_name == "hud" or screen_name == "pause"
	pause_panel.visible = screen_name == "pause"
	settings_panel.visible = screen_name == "settings"
	hangar_panel.visible = screen_name == "hangar"
	results.visible = screen_name == "results"
	_dim.visible = screen_name in ["pause", "settings", "results"]
	if screen_name == "hangar":
		_hangar_index = maxi(ShipBuilder.ORDER.find(Save.data["livery"]), 0)
		refresh_hangar()
	if screen_name == "settings" or screen_name == "pause":
		sync_settings(Save.data["settings"])
	if screen_name != "hud":
		_countdown.text = ""
	if (prev == "hangar") != (screen_name == "hangar"):
		hangar_toggled.emit(screen_name == "hangar")
	# entrance animation
	var layer: Control = {"menu": menu, "hud": hud, "pause": pause_panel, "settings": settings_panel, "hangar": hangar_panel, "results": results}.get(screen_name)
	if layer and prev != screen_name and not (prev == "pause" and screen_name == "hud"):
		layer.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_property(layer, "modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_SINE)


## Esc / P / Android back toggles pause. Lives here because the UI keeps
## processing while the tree is paused (the game root does not).
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_game") or event.is_action_pressed("ui_cancel"):
		_back()


## Android back button arrives as a notification (quit_on_go_back is off).
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_back()


func _back() -> void:
	if pause_panel.visible:
		resume_pressed.emit()
	elif hud.visible:
		pause_pressed.emit()
	elif settings_panel.visible or hangar_panel.visible:
		show_screen("pause" if settings_panel.visible and _settings_from_pause else "menu")
	get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_t += delta
	if menu.visible:
		_tap.modulate.a = 0.78 + 0.22 * sin(_t * 3.2)
	if _popup_t > 0.0:
		_popup_t = maxf(_popup_t - delta * 1.1, 0.0)
		_popup_box.modulate.a = clampf(_popup_t * 2.5, 0.0, 1.0)
		_popup_box.scale = _popup_box.scale.lerp(Vector2.ONE, 1.0 - exp(-16.0 * delta))
	if _banner_t > 0.0:
		_banner_t = maxf(_banner_t - delta, 0.0)
		_banner_box.modulate.a = clampf(minf(_banner_t, 3.2 - _banner_t) * 3.0, 0.0, 1.0)
	_countdown.scale = _countdown.scale.lerp(Vector2.ONE, 1.0 - exp(-10.0 * delta))
	if _countdown_t > 0.0:
		_countdown_t -= delta
		if _countdown_t <= 0.0:
			_countdown.text = ""
	if results.visible and _res_shown < float(_res_target):
		_res_shown = minf(float(_res_target), _res_shown + maxf(float(_res_target) * delta * 1.6, 40.0 * delta))
		_res_score.text = _fmt(int(_res_shown))
	if flash_rect.color.a > 0.0:
		flash_rect.color.a = move_toward(flash_rect.color.a, 0.0, delta * 2.5)


static func _fmt(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out
