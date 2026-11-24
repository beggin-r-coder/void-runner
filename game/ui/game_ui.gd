class_name GameUI
extends Control
## All screens, built in code: menu, HUD, pause, settings, hangar, results.
## Touch targets are at least 48 dp; layout respects the display safe area.
## During a run only score/distance, essential status and pause are shown.

signal launch_pressed
signal retry_pressed
signal menu_pressed
signal pause_pressed
signal resume_pressed
signal livery_selected(id: String)
signal setting_changed(key: String, value: Variant)

const CYAN := Color(0.45, 0.95, 1.0)
const GOLD := Color(1.0, 0.8, 0.35)
const PINK := Color(1.0, 0.35, 0.7)

var _theme: Theme
var _safe: MarginContainer
var menu: Control
var hud: Control
var pause_panel: Control
var settings_panel: Control
var hangar_panel: Control
var results: Control
var flash_rect: ColorRect

var _score: Label
var _distance: Label
var _speed: Label
var _combo: Label
var _combo_bar: ProgressBar
var _popup: Label
var _banner: Label
var _countdown: Label
var _hint: Label
var _menu_stats: Label
var _tap: Label
var _res_title: Label
var _res_reason: Label
var _res_stats: Label
var _res_best: Label
var _hangar_name: Label
var _hangar_action: Button
var _hangar_index: int = 0
var _toggles: Dictionary = {}
var _settings_from_pause: bool = false
var _t: float = 0.0
var _popup_t: float = 0.0
var _banner_t: float = 0.0
var _countdown_t: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_theme = _make_theme()
	theme = _theme
	flash_rect = ColorRect.new()
	flash_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash_rect.color = Color(1, 1, 1, 0)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash_rect)
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


func _make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 26
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.03, 0.05, 0.1, 0.72)
	normal.border_color = Color(CYAN, 0.75)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(14)
	normal.content_margin_left = 26
	normal.content_margin_right = 26
	normal.content_margin_top = 12
	normal.content_margin_bottom = 12
	normal.shadow_color = Color(CYAN, 0.25)
	normal.shadow_size = 8
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.08, 0.14, 0.22, 0.85)
	hover.border_color = CYAN
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(CYAN, 0.35)
	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("pressed", "Button", pressed)
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", Color(0.92, 0.98, 1.0))
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_font_size("font_size", "Button", 28)
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.02, 0.03, 0.07, 0.86)
	panel.border_color = Color(CYAN, 0.45)
	panel.set_border_width_all(2)
	panel.set_corner_radius_all(20)
	panel.content_margin_left = 40
	panel.content_margin_right = 40
	panel.content_margin_top = 30
	panel.content_margin_bottom = 30
	t.set_stylebox("panel", "PanelContainer", panel)
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(1, 1, 1, 0.12)
	bar_bg.set_corner_radius_all(4)
	var bar_fg := StyleBoxFlat.new()
	bar_fg.bg_color = PINK
	bar_fg.set_corner_radius_all(4)
	t.set_stylebox("background", "ProgressBar", bar_bg)
	t.set_stylebox("fill", "ProgressBar", bar_fg)
	t.set_font_size("font_size", "CheckButton", 26)
	return t


func _label(text: String, size: int, color: Color = Color.WHITE, outline: int = 6, glow: Color = Color(0, 0, 0, 0.6)) -> Label:
	var l := Label.new()
	l.text = text
	var ls := LabelSettings.new()
	ls.font_size = size
	ls.font_color = color
	ls.outline_size = outline
	ls.outline_color = Color(0.0, 0.02, 0.06, 0.85)
	ls.shadow_color = glow
	ls.shadow_size = 10
	ls.shadow_offset = Vector2.ZERO
	l.label_settings = ls
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _button(text: String, cb: Callable, min_size: Vector2 = Vector2(220, 72)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.pressed.connect(func() -> void:
		Sfx.play("click")
		cb.call())
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
		Control.PRESET_TOP_RIGHT, Control.PRESET_BOTTOM_RIGHT:
			child.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	match preset:
		Control.PRESET_CENTER:
			child.grow_vertical = Control.GROW_DIRECTION_BOTH
		Control.PRESET_CENTER_BOTTOM, Control.PRESET_BOTTOM_LEFT, Control.PRESET_BOTTOM_RIGHT:
			child.grow_vertical = Control.GROW_DIRECTION_BEGIN
	return child


func _center_panel(parent: Control) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(center)
	var pc := PanelContainer.new()
	center.add_child(pc)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 16)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	pc.add_child(vb)
	return vb


# --- HUD ---------------------------------------------------------------------

func _build_hud() -> void:
	hud = _layer()
	var tl := VBoxContainer.new()
	tl.add_theme_constant_override("separation", -6)
	tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_score = _label("0", 54, Color.WHITE, 8, Color(CYAN, 0.5))
	_distance = _label("0 m", 26, Color(0.75, 0.9, 1.0))
	tl.add_child(_score)
	tl.add_child(_distance)
	_place(hud, tl, Control.PRESET_TOP_LEFT)

	var pause_btn := _button("II", func() -> void: pause_pressed.emit(), Vector2(76, 76))
	pause_btn.add_theme_font_size_override("font_size", 30)
	_place(hud, pause_btn, Control.PRESET_TOP_RIGHT)

	var cb := VBoxContainer.new()
	cb.alignment = BoxContainer.ALIGNMENT_CENTER
	cb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_combo = _label("", 40, PINK, 8, Color(PINK, 0.6))
	_combo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_combo_bar = ProgressBar.new()
	_combo_bar.custom_minimum_size = Vector2(180, 8)
	_combo_bar.show_percentage = false
	_combo_bar.max_value = 1.0
	_combo_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cb.add_child(_combo)
	cb.add_child(_combo_bar)
	_place(hud, cb, Control.PRESET_CENTER_TOP)

	_speed = _label("0 KM/H", 28, Color(0.8, 0.95, 1.0))
	_place(hud, _speed, Control.PRESET_BOTTOM_RIGHT)

	_popup = _label("", 44, CYAN, 8, Color(CYAN, 0.7))
	_popup.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(hud, _popup, Control.PRESET_CENTER)
	_popup.position.y -= 120

	_banner = _label("", 34, Color(1, 1, 1, 0.9), 6, Color(CYAN, 0.4))
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(hud, _banner, Control.PRESET_CENTER_TOP)
	_banner.position.y += 110

	_countdown = _label("", 150, Color.WHITE, 12, Color(CYAN, 0.8))
	_countdown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(hud, _countdown, Control.PRESET_CENTER)

	_hint = _label("DRAG ANYWHERE TO STEER", 36, Color.WHITE, 8, Color(CYAN, 0.6))
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(hud, _hint, Control.PRESET_CENTER_BOTTOM)
	_hint.position.y -= 70
	_hint.visible = false


func set_hud(score: int, distance: float, speed: float, combo: int, combo_frac: float) -> void:
	_score.text = _fmt(score)
	_distance.text = "%s m" % _fmt(int(distance))
	_speed.text = "%d KM/H" % int(speed * 3.6)
	if combo > 0:
		_combo.text = "x%d COMBO" % combo
		_combo_bar.visible = true
		_combo_bar.value = combo_frac
	else:
		_combo.text = ""
		_combo_bar.visible = false


func popup(text: String, color: Color = CYAN) -> void:
	_popup.text = text
	_popup.label_settings.font_color = color
	_popup.label_settings.shadow_color = Color(color, 0.7)
	_popup_t = 1.0
	_popup.pivot_offset = _popup.size * 0.5
	_popup.scale = Vector2.ONE * 1.5


func banner(text: String) -> void:
	_banner.text = text
	_banner_t = 3.0


func set_countdown(text: String) -> void:
	_countdown.text = text
	_countdown_t = 0.6
	_countdown.pivot_offset = _countdown.size * 0.5
	_countdown.scale = Vector2.ONE * 1.4


func show_hint(v: bool) -> void:
	_hint.visible = v


func flash(color: Color, strength: float) -> void:
	flash_rect.color = Color(color, strength)


# --- Menu --------------------------------------------------------------------

func _build_menu() -> void:
	menu = _layer()
	var tap_area := Button.new()
	tap_area.flat = true
	tap_area.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tap_area.focus_mode = Control.FOCUS_NONE
	tap_area.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	tap_area.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	tap_area.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	tap_area.pressed.connect(func() -> void: launch_pressed.emit())
	menu.add_child(tap_area)

	var title_box := VBoxContainer.new()
	title_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_box.add_theme_constant_override("separation", -10)
	var title := _label("VOID RUNNER", 112, Color(0.95, 0.99, 1.0), 10, Color(CYAN, 0.9))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sub := _label("SPEED THROUGH THE UNKNOWN", 26, Color(0.7, 0.92, 1.0), 4, Color(CYAN, 0.4))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_box.add_child(title)
	title_box.add_child(sub)
	_place(menu, title_box, Control.PRESET_CENTER_TOP)
	title_box.position.y += 30

	_tap = _label("TAP TO LAUNCH", 40, Color.WHITE, 8, Color(CYAN, 0.7))
	_tap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(menu, _tap, Control.PRESET_CENTER_BOTTOM)
	_tap.position.y -= 40

	_menu_stats = _label("", 26, Color(0.85, 0.95, 1.0))
	_place(menu, _menu_stats, Control.PRESET_BOTTOM_LEFT)

	var buttons := VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 14)
	buttons.add_child(_button("HANGAR", func() -> void: show_screen("hangar")))
	buttons.add_child(_button("SETTINGS", func() -> void:
		_settings_from_pause = false
		show_screen("settings")))
	_place(menu, buttons, Control.PRESET_BOTTOM_RIGHT)


func set_menu_stats(best: int, credits: int) -> void:
	_menu_stats.text = "BEST  %s\nCREDITS  %s" % [_fmt(best), _fmt(credits)]


# --- Pause / settings / hangar ----------------------------------------------

func _build_pause() -> void:
	pause_panel = _layer()
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_panel.add_child(dim)
	var vb := _center_panel(pause_panel)
	var t := _label("PAUSED", 56, Color.WHITE, 8, Color(CYAN, 0.6))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(t)
	vb.add_child(_button("RESUME", func() -> void: resume_pressed.emit(), Vector2(320, 76)))
	vb.add_child(_button("RESTART", func() -> void: retry_pressed.emit(), Vector2(320, 76)))
	vb.add_child(_button("SETTINGS", func() -> void:
		_settings_from_pause = true
		show_screen("settings"), Vector2(320, 76)))
	vb.add_child(_button("MENU", func() -> void: menu_pressed.emit(), Vector2(320, 76)))


func _build_settings() -> void:
	settings_panel = _layer()
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	settings_panel.add_child(dim)
	var vb := _center_panel(settings_panel)
	var t := _label("SETTINGS", 48, Color.WHITE, 8, Color(CYAN, 0.6))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(t)
	for entry in [["reduced_motion", "Reduced motion"], ["invert_y", "Invert vertical"], ["high_quality", "High quality effects"], ["haptics", "Haptics"]]:
		var key: String = entry[0]
		var cbtn := CheckButton.new()
		cbtn.text = entry[1]
		cbtn.custom_minimum_size = Vector2(420, 56)
		cbtn.toggled.connect(func(on: bool) -> void:
			Sfx.play("click")
			setting_changed.emit(key, on))
		vb.add_child(cbtn)
		_toggles[key] = cbtn
	var row := HBoxContainer.new()
	row.add_child(_label("Effects volume", 24))
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.custom_minimum_size = Vector2(220, 48)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(func(v: float) -> void: setting_changed.emit("sfx_volume", v))
	row.add_child(slider)
	vb.add_child(row)
	_toggles["sfx_volume"] = slider
	vb.add_child(_button("DONE", func() -> void:
		show_screen("pause" if _settings_from_pause else "menu"), Vector2(320, 72)))


func sync_settings(s: Dictionary) -> void:
	(_toggles["reduced_motion"] as CheckButton).set_pressed_no_signal(bool(s.get("reduced_motion", false)))
	(_toggles["invert_y"] as CheckButton).set_pressed_no_signal(bool(s.get("invert_y", false)))
	(_toggles["high_quality"] as CheckButton).set_pressed_no_signal(str(s.get("quality", "high")) == "high")
	(_toggles["haptics"] as CheckButton).set_pressed_no_signal(bool(s.get("haptics", true)))
	(_toggles["sfx_volume"] as HSlider).set_value_no_signal(float(s.get("sfx_volume", 0.9)))


func _build_hangar() -> void:
	hangar_panel = _layer()
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 14)
	var t := _label("HANGAR", 44, Color.WHITE, 8, Color(CYAN, 0.6))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(t)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	row.add_child(_button("<", func() -> void: _cycle_livery(-1), Vector2(80, 76)))
	_hangar_name = _label("NOVA", 40, GOLD, 8, Color(GOLD, 0.5))
	_hangar_name.custom_minimum_size = Vector2(260, 0)
	_hangar_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(_hangar_name)
	row.add_child(_button(">", func() -> void: _cycle_livery(1), Vector2(80, 76)))
	vb.add_child(row)
	_hangar_action = _button("EQUIPPED", func() -> void: _hangar_act(), Vector2(320, 76))
	vb.add_child(_hangar_action)
	vb.add_child(_button("BACK", func() -> void: show_screen("menu"), Vector2(320, 72)))
	_place(hangar_panel, vb, Control.PRESET_CENTER_BOTTOM)


func refresh_hangar() -> void:
	var id: String = ShipBuilder.ORDER[_hangar_index]
	var lv: Dictionary = ShipBuilder.LIVERIES[id]
	_hangar_name.text = lv["name"]
	var unlocked: Array = Save.data["unlocked_liveries"]
	if id == Save.data["livery"]:
		_hangar_action.text = "EQUIPPED"
		_hangar_action.disabled = true
	elif id in unlocked:
		_hangar_action.text = "EQUIP"
		_hangar_action.disabled = false
	else:
		_hangar_action.text = "UNLOCK  %d CR" % int(lv["cost"])
		_hangar_action.disabled = int(Save.data["credits"]) < int(lv["cost"])


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


# --- Results -----------------------------------------------------------------

func _build_results() -> void:
	results = _layer()
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.35)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	results.add_child(dim)
	var vb := _center_panel(results)
	_res_title = _label("HULL BREACH", 64, Color(1.0, 0.45, 0.35), 8, Color(1.0, 0.3, 0.2, 0.7))
	_res_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_res_title)
	_res_reason = _label("", 26, Color(1.0, 0.85, 0.75))
	_res_reason.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_res_reason)
	_res_best = _label("", 30, GOLD, 6, Color(GOLD, 0.6))
	_res_best.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_res_best)
	_res_stats = _label("", 28)
	_res_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_res_stats)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	var retry := _button("RETRY", func() -> void: retry_pressed.emit(), Vector2(300, 84))
	retry.add_theme_font_size_override("font_size", 36)
	row.add_child(retry)
	row.add_child(_button("MENU", func() -> void: menu_pressed.emit(), Vector2(200, 84)))
	vb.add_child(row)


func show_results(score: int, distance: float, near_misses: int, credits: int, reason: String, new_best: bool, best: int) -> void:
	_res_reason.text = reason
	_res_best.text = "NEW BEST!" if new_best else "BEST  %s" % _fmt(best)
	_res_stats.text = "SCORE  %s\nDISTANCE  %s m     NEAR MISSES  %d\n+%d CREDITS" % [_fmt(score), _fmt(int(distance)), near_misses, credits]
	show_screen("results")


# --- Screen management ---------------------------------------------------------

func show_screen(screen_name: String) -> void:
	menu.visible = screen_name == "menu"
	hud.visible = screen_name == "hud" or screen_name == "pause"
	pause_panel.visible = screen_name == "pause"
	settings_panel.visible = screen_name == "settings"
	hangar_panel.visible = screen_name == "hangar"
	results.visible = screen_name == "results"
	if screen_name == "hangar":
		_hangar_index = maxi(ShipBuilder.ORDER.find(Save.data["livery"]), 0)
		refresh_hangar()
	if screen_name == "settings":
		sync_settings(Save.data["settings"])
	if screen_name != "hud":
		_countdown.text = ""


func _process(delta: float) -> void:
	_t += delta
	if _tap and menu.visible:
		_tap.modulate.a = 0.55 + 0.45 * sin(_t * 3.0)
	if _popup_t > 0.0:
		_popup_t = maxf(_popup_t - delta * 1.2, 0.0)
		_popup.modulate.a = clampf(_popup_t * 2.0, 0.0, 1.0)
		_popup.scale = _popup.scale.lerp(Vector2.ONE, 1.0 - exp(-14.0 * delta))
	if _banner_t > 0.0:
		_banner_t = maxf(_banner_t - delta, 0.0)
		_banner.modulate.a = clampf(_banner_t, 0.0, 1.0)
	_countdown.scale = _countdown.scale.lerp(Vector2.ONE, 1.0 - exp(-10.0 * delta))
	if _countdown_t > 0.0:
		_countdown_t -= delta
		if _countdown_t <= 0.0:
			_countdown.text = ""
	if flash_rect.color.a > 0.0:
		flash_rect.color.a = move_toward(flash_rect.color.a, 0.0, delta * 2.5)


static func _fmt(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out
