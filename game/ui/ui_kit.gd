class_name UIKit
extends RefCounted
## Void Runner HUD visual language: cut-corner glass panels, skewed buttons,
## letter-spaced type, segmented gauges. Everything is drawn in code.

const CYAN := Color(0.36, 0.93, 1.0)
const CYAN_DIM := Color(0.36, 0.93, 1.0, 0.45)
const PINK := Color(1.0, 0.3, 0.66)
const GOLD := Color(1.0, 0.8, 0.36)
const RED := Color(1.0, 0.36, 0.3)
const INK := Color(0.015, 0.03, 0.065, 0.82)
const INK_SOLID := Color(0.02, 0.04, 0.08, 0.94)
const TEXT := Color(0.9, 0.97, 1.0)
const TEXT_DIM := Color(0.62, 0.76, 0.86)

static var _fonts: Dictionary = {}


## Default engine font with tracking / weight variations.
static func font(spacing: int = 0, embolden: float = 0.0) -> Font:
	var key := "%d:%.2f" % [spacing, embolden]
	if _fonts.has(key):
		return _fonts[key]
	var fv := FontVariation.new()
	fv.base_font = ThemeDB.fallback_font
	fv.spacing_glyph = spacing
	fv.variation_embolden = embolden
	_fonts[key] = fv
	return fv


static func label(text: String, size: int, color: Color = TEXT, spacing: int = 0, embolden: float = 0.0, glow: Color = Color(0, 0, 0, 0)) -> Label:
	var l := Label.new()
	l.text = text
	var ls := LabelSettings.new()
	ls.font = font(spacing, embolden)
	ls.font_size = size
	ls.font_color = color
	ls.outline_size = maxi(2, size / 12)
	ls.outline_color = Color(0.0, 0.02, 0.05, 0.9)
	ls.shadow_color = glow if glow.a > 0.0 else Color(0, 0, 0, 0.45)
	ls.shadow_size = 12 if glow.a > 0.0 else 4
	ls.shadow_offset = Vector2.ZERO if glow.a > 0.0 else Vector2(0, 2)
	l.label_settings = ls
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func box(bg: Color, border: Color, skew: float, left_accent: Color = Color(0, 0, 0, 0)) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	if left_accent.a > 0.0:
		sb.border_width_left = 5
	sb.skew = Vector2(skew, 0.0)
	sb.set_corner_radius_all(2)
	sb.content_margin_left = 30
	sb.content_margin_right = 30
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	sb.anti_aliasing = true
	return sb


static func build_theme() -> Theme:
	var t := Theme.new()
	t.default_font = font(2, 0.15)
	t.default_font_size = 24
	var normal := box(Color(0.02, 0.05, 0.1, 0.78), Color(CYAN, 0.55), 0.22)
	normal.border_width_left = 5
	normal.border_color = Color(CYAN, 0.55)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.05, 0.13, 0.2, 0.9)
	hover.border_color = CYAN
	hover.shadow_color = Color(CYAN, 0.3)
	hover.shadow_size = 10
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(CYAN, 0.85)
	pressed.border_color = Color.WHITE
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(0.02, 0.03, 0.06, 0.92)
	disabled.border_color = Color(GOLD, 0.7)
	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("pressed", "Button", pressed)
	t.set_stylebox("hover_pressed", "Button", pressed)
	t.set_stylebox("disabled", "Button", disabled)
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Color(0.02, 0.05, 0.1))
	t.set_color("font_hover_pressed_color", "Button", Color(0.02, 0.05, 0.1))
	t.set_color("font_disabled_color", "Button", GOLD)
	t.set_font("font", "Button", font(5, 0.35))
	t.set_font_size("font_size", "Button", 24)
	# toggles: flat rows with a drawn switch
	var row := box(Color(0.02, 0.05, 0.1, 0.55), Color(CYAN, 0.18), 0.0)
	row.content_margin_left = 18
	row.content_margin_right = 14
	var row_hover := row.duplicate() as StyleBoxFlat
	row_hover.bg_color = Color(0.05, 0.12, 0.18, 0.75)
	row_hover.border_color = Color(CYAN, 0.5)
	for st in ["normal", "pressed", "hover_pressed", "disabled"]:
		t.set_stylebox(st, "CheckButton", row)
	t.set_stylebox("hover", "CheckButton", row_hover)
	t.set_stylebox("hover_pressed", "CheckButton", row_hover)
	t.set_stylebox("focus", "CheckButton", StyleBoxEmpty.new())
	t.set_icon("checked", "CheckButton", switch_texture(true))
	t.set_icon("unchecked", "CheckButton", switch_texture(false))
	t.set_icon("checked_disabled", "CheckButton", switch_texture(true))
	t.set_icon("unchecked_disabled", "CheckButton", switch_texture(false))
	t.set_font("font", "CheckButton", font(2, 0.2))
	t.set_font_size("font_size", "CheckButton", 22)
	t.set_color("font_color", "CheckButton", TEXT_DIM)
	t.set_color("font_pressed_color", "CheckButton", TEXT)
	t.set_color("font_hover_color", "CheckButton", Color.WHITE)
	t.set_color("font_hover_pressed_color", "CheckButton", Color.WHITE)
	# slider
	var track := StyleBoxFlat.new()
	track.bg_color = Color(1, 1, 1, 0.12)
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	var fill := StyleBoxFlat.new()
	fill.bg_color = CYAN
	fill.content_margin_top = 3
	fill.content_margin_bottom = 3
	t.set_stylebox("slider", "HSlider", track)
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	t.set_icon("grabber", "HSlider", knob_texture(CYAN))
	t.set_icon("grabber_highlight", "HSlider", knob_texture(Color.WHITE))
	return t


## Procedural pill switch: cyan with knob right when on, slate with knob left when off.
static func switch_texture(on: bool) -> Texture2D:
	var w := 64
	var h := 32
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var r := h * 0.5
	var bg := Color(0.2, 0.75, 0.85, 1.0) if on else Color(0.16, 0.2, 0.26, 1.0)
	var knob_c := Vector2(w - r, r) if on else Vector2(r, r)
	for y in h:
		for x in w:
			var p := Vector2(x + 0.5, y + 0.5)
			var cx := clampf(p.x, r, w - r)
			var d := p.distance_to(Vector2(cx, r))
			var a := clampf(r - d, 0.0, 1.0)
			var c := bg
			var kd := p.distance_to(knob_c)
			var ka := clampf(r - 4.0 - kd, 0.0, 1.0)
			c = c.lerp(Color(0.98, 1.0, 1.0) if on else Color(0.55, 0.62, 0.7), ka)
			c.a = a
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


static func knob_texture(c: Color) -> Texture2D:
	var s := 22
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	for y in s:
		for x in s:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(Vector2(s, s) * 0.5)
			var col := c
			col.a = clampf(s * 0.5 - 1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)


static func chamfer(rect: Rect2, cut: float) -> PackedVector2Array:
	var a := rect.position
	var b := rect.end
	return PackedVector2Array([
		Vector2(a.x + cut, a.y), Vector2(b.x, a.y), Vector2(b.x, b.y - cut),
		Vector2(b.x - cut, b.y), Vector2(a.x, b.y), Vector2(a.x, a.y + cut),
	])


## Cut-corner glass panel with bright corner brackets. Use as a container parent.
class SciPanel:
	extends PanelContainer
	var accent: Color = UIKit.CYAN
	var fill: Color = UIKit.INK
	var cut: float = 22.0
	var header_line: bool = true

	func _init(p_accent: Color = UIKit.CYAN, padding: int = 38) -> void:
		accent = p_accent
		mouse_filter = Control.MOUSE_FILTER_STOP
		var sb := StyleBoxEmpty.new()
		sb.content_margin_left = padding
		sb.content_margin_right = padding
		sb.content_margin_top = padding * 0.75
		sb.content_margin_bottom = padding * 0.75
		add_theme_stylebox_override("panel", sb)

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var poly := UIKit.chamfer(r, cut)
		draw_colored_polygon(poly, fill)
		# soft inner gradient band at the top
		var band := UIKit.chamfer(Rect2(Vector2(2, 2), Vector2(size.x - 4, minf(70.0, size.y * 0.3))), cut - 2)
		draw_colored_polygon(band, Color(accent, 0.05))
		var outline := poly.duplicate()
		outline.append(poly[0])
		draw_polyline(outline, Color(accent, 0.35), 1.5, true)
		# corner brackets
		var L := 34.0
		draw_line(Vector2(cut, 0), Vector2(cut + L, 0), accent, 3.0)
		draw_line(Vector2(0, cut), Vector2(cut, 0), accent, 3.0)
		draw_line(Vector2(0, cut), Vector2(0, cut + L), accent, 3.0)
		draw_line(Vector2(size.x - cut, size.y), Vector2(size.x - cut - L, size.y), accent, 3.0)
		draw_line(Vector2(size.x, size.y - cut), Vector2(size.x - cut, size.y), accent, 3.0)
		draw_line(Vector2(size.x, size.y - cut), Vector2(size.x, size.y - cut - L), accent, 3.0)
		# tick marks top-right
		for i in 4:
			var x := size.x - 18.0 - i * 9.0
			draw_line(Vector2(x, 8), Vector2(x - 5, 16), Color(accent, 0.6), 2.0)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			queue_redraw()


## Thin horizontal divider with a bright centre segment.
class Divider:
	extends Control
	var color: Color = UIKit.CYAN

	func _init(c: Color = UIKit.CYAN, w: float = 0.0) -> void:
		color = c
		custom_minimum_size = Vector2(w, 10)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_horizontal = Control.SIZE_EXPAND_FILL

	func _draw() -> void:
		var y := size.y * 0.5
		draw_line(Vector2(0, y), Vector2(size.x, y), Color(color, 0.22), 1.0)
		var c := size.x * 0.5
		draw_line(Vector2(c - 40, y), Vector2(c + 40, y), color, 2.0)
		draw_rect(Rect2(Vector2(c - 3, y - 3), Vector2(6, 6)), color)


## Title flourish: lines that fade out to both sides.
class Flourish:
	extends Control
	var color: Color = UIKit.CYAN

	func _init(w: float) -> void:
		custom_minimum_size = Vector2(w, 14)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var y := size.y * 0.5
		var c := size.x * 0.5
		for i in 24:
			var t := float(i) / 24.0
			var a := (1.0 - t) * 0.9
			var x0 := c + 30 + t * (c - 30)
			var x1 := c + 30 + (t + 1.0 / 24.0) * (c - 30)
			draw_line(Vector2(x0, y), Vector2(x1, y), Color(color, a), 2.0)
			draw_line(Vector2(size.x - x0, y), Vector2(size.x - x1, y), Color(color, a), 2.0)
		var d := PackedVector2Array([Vector2(c, y - 6), Vector2(c + 8, y), Vector2(c, y + 6), Vector2(c - 8, y)])
		draw_colored_polygon(d, color)


## Segmented speed gauge (slanted bars) filled by `value` 0..1.
class SpeedGauge:
	extends Control
	var value: float = 0.0
	var segments: int = 20

	func _init() -> void:
		custom_minimum_size = Vector2(250, 22)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_value(v: float) -> void:
		if absf(v - value) > 0.004:
			value = v
			queue_redraw()

	func _draw() -> void:
		var w := size.x / segments
		var lit := value * segments
		for i in segments:
			var x := i * w
			var h := size.y * (0.45 + 0.55 * float(i) / (segments - 1))
			var poly := PackedVector2Array([Vector2(x + 4, size.y - h), Vector2(x + w - 1, size.y - h), Vector2(x + w - 5, size.y), Vector2(x, size.y)])
			var t := float(i) / (segments - 1)
			var on := clampf(lit - i, 0.0, 1.0)
			var col := UIKit.CYAN.lerp(UIKit.PINK, smoothstep(0.55, 1.0, t))
			draw_colored_polygon(poly, Color(col, 0.14 + 0.86 * on))


## Five combo pips (chevrons) with a timer bar underneath.
class ComboPips:
	extends Control
	var combo: int = 0
	var timer: float = 0.0
	var max_combo: int = 5

	func _init() -> void:
		custom_minimum_size = Vector2(230, 30)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_state(c: int, t: float) -> void:
		if c != combo or absf(t - timer) > 0.01:
			combo = c
			timer = t
			queue_redraw()

	func _draw() -> void:
		var w := size.x / max_combo
		for i in max_combo:
			var x := i * w
			var poly := PackedVector2Array([Vector2(x + 2, 0), Vector2(x + w - 12, 0), Vector2(x + w - 2, 9), Vector2(x + w - 12, 18), Vector2(x + 2, 18), Vector2(x + 12, 9)])
			var col := UIKit.CYAN.lerp(UIKit.PINK, float(i) / (max_combo - 1))
			draw_colored_polygon(poly, Color(col, 0.95) if i < combo else Color(1, 1, 1, 0.1))
		draw_rect(Rect2(Vector2(2, 25), Vector2(size.x - 4, 3)), Color(1, 1, 1, 0.1))
		if combo > 0:
			draw_rect(Rect2(Vector2(2, 25), Vector2((size.x - 4) * timer, 3)), UIKit.PINK)


## Two-bar pause glyph drawn over a button.
class PauseGlyph:
	extends Control

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	func _draw() -> void:
		var c := size * 0.5
		draw_rect(Rect2(c + Vector2(-11, -13), Vector2(7, 26)), UIKit.TEXT)
		draw_rect(Rect2(c + Vector2(4, -13), Vector2(7, 26)), UIKit.TEXT)


## Barrel-roll thumb button. Handles touches itself (works as a second finger
## while the first finger steers) and ignores emulated duplicates.
class RollButton:
	extends Control
	signal triggered(dir: int)
	var dir: int = 1
	var ready_frac: float = 1.0
	var _flash: float = 0.0

	func _init(p_dir: int) -> void:
		dir = p_dir
		custom_minimum_size = Vector2(124, 124)
		mouse_filter = Control.MOUSE_FILTER_STOP

	func set_ready(f: float) -> void:
		if absf(f - ready_frac) > 0.01:
			ready_frac = f
			queue_redraw()

	func press() -> void:
		_flash = 1.0
		triggered.emit(dir)
		queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed and event.device != InputEvent.DEVICE_ID_EMULATION:
			press()
			accept_event()
		elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT and event.device != InputEvent.DEVICE_ID_EMULATION:
			press()
			accept_event()
		elif event is InputEventScreenTouch or event is InputEventMouseButton:
			accept_event()

	func _process(delta: float) -> void:
		if _flash > 0.0:
			_flash = maxf(_flash - delta * 4.0, 0.0)
			queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		var r := size.x * 0.42
		var ok := ready_frac >= 1.0
		var hex := PackedVector2Array()
		for i in 6:
			var a := TAU * i / 6.0 + PI / 6.0
			hex.append(c + Vector2(cos(a), sin(a)) * r)
		draw_colored_polygon(hex, Color(UIKit.CYAN, 0.25 + 0.5 * _flash) if ok else Color(0.02, 0.04, 0.08, 0.6))
		var outline := hex.duplicate()
		outline.append(hex[0])
		draw_polyline(outline, Color(UIKit.CYAN, 0.9 if ok else 0.3), 2.5, true)
		if not ok:
			draw_arc(c, r * 0.82, -PI * 0.5, -PI * 0.5 + TAU * ready_frac, 32, Color(UIKit.CYAN, 0.8), 4.0, true)
		# curved arrow showing the roll direction
		var col := UIKit.TEXT if ok else Color(UIKit.TEXT, 0.4)
		var a0 := PI * 1.15
		var a1 := PI * 1.85
		if dir < 0:
			draw_arc(c + Vector2(0, 8), r * 0.5, a0, a1, 24, col, 5.0, true)
			var tip := c + Vector2(0, 8) + Vector2(cos(a0), sin(a0)) * r * 0.5
			draw_colored_polygon(PackedVector2Array([tip + Vector2(-10, 4), tip + Vector2(8, 4), tip + Vector2(-2, 18)]), col)
		else:
			draw_arc(c + Vector2(0, 8), r * 0.5, a0, a1, 24, col, 5.0, true)
			var tip2 := c + Vector2(0, 8) + Vector2(cos(a1), sin(a1)) * r * 0.5
			draw_colored_polygon(PackedVector2Array([tip2 + Vector2(-8, 4), tip2 + Vector2(10, 4), tip2 + Vector2(2, 18)]), col)
		var f := UIKit.font(3, 0.3)
		var txt := "ROLL"
		var ts := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15)
		draw_string(f, Vector2(c.x - ts.x * 0.5, c.y + r * 0.55), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, col)
