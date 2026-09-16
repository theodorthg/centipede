class_name UiStyle

## Shared menu chrome — used by menus.gd and hud.gd so every screen/button
## looks like one system instead of bare default-theme controls.
## Palette: black background, toxic-green (giftgrün) accent, white text/ink.

const ACCENT := Color("39ff14")
const PANEL_BG := Color(0.0, 0.0, 0.0, 0.92)
const PANEL_BORDER := Color("39ff14")

## Bordered, slightly raised panel — the frame every menu screen sits in.
static func panel_style(margin: int = 24) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL_BG
	sb.border_color = PANEL_BORDER
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(margin)
	sb.shadow_color = Color(0, 0, 0, 0.6)
	sb.shadow_size = 12
	return sb

## Per-state StyleBoxFlat instead of the flat default Button skin.
static func style_button(b: Button) -> void:
	var alphas := {"normal": 0.12, "hover": 0.28, "pressed": 0.08, "disabled": 0.05}
	for state in alphas:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(ACCENT.r, ACCENT.g, ACCENT.b, alphas[state])
		sb.set_corner_radius_all(10)
		sb.set_border_width_all(2)
		sb.border_color = ACCENT if state == "hover" else Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.55)
		b.add_theme_stylebox_override(state, sb)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", ACCENT)
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.4))
	# Buttons are focusable (gamepad/keyboard menu navigation) — without this
	# override Godot draws its plain default-theme focus rectangle on top of
	# the "normal" stylebox above, which clashes with the glass look.
	var focus_sb := StyleBoxFlat.new()
	focus_sb.bg_color = Color(ACCENT.r, ACCENT.g, ACCENT.b, alphas["normal"])
	focus_sb.set_corner_radius_all(10)
	focus_sb.set_border_width_all(3)
	focus_sb.border_color = ACCENT
	b.add_theme_stylebox_override("focus", focus_sb)

## Outlined heading label — flat colored text on a dark panel reads muddy;
## a dark outline gives it arcade-marquee pop.
static func heading(text: String, size: int, color := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 6)
	return l

## "Marquee" treatment for big impact moments (GAME OVER, "READY", wave
## banner, every menu heading via heading()) — white fill with a green
## outline plus a soft drop shadow for an embossed pop.
static func impact_label(l: Label, fill := Color.WHITE, outline := ACCENT) -> void:
	l.add_theme_color_override("font_color", fill)
	l.add_theme_color_override("font_outline_color", outline)
	l.add_theme_constant_override("outline_size", 9)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	l.add_theme_constant_override("shadow_offset_x", 3)
	l.add_theme_constant_override("shadow_offset_y", 4)
	l.add_theme_constant_override("shadow_outline_size", 2)

## Frosted-glass backdrop: BackBufferCopy + a ColorRect running
## frosted_glass.gdshader. GL Compatibility needs the explicit BackBufferCopy —
## SCREEN_TEXTURE isn't available for free there. Caller adds both to a
## CanvasLayer above the game and toggles the ColorRect's visibility.
static func make_glass_backdrop() -> Dictionary:
	var bbc := BackBufferCopy.new()
	bbc.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	var glass := ColorRect.new()
	glass.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glass.visible = false
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/ui/frosted_glass.gdshader")
	mat.set_shader_parameter("blur", 3.0)
	mat.set_shader_parameter("tint", Color(0.0, 0.0, 0.0, 1.0))
	mat.set_shader_parameter("tint_amount", 0.55)
	glass.material = mat
	return {"backbuffer": bbc, "glass": glass}
